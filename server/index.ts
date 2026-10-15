import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash, randomBytes } from 'node:crypto';
import { catalogue, makePlayer, settle, view, beginBattle, turn, finishBattle, log, addXp, type Player } from './engine.ts';

class ApiError extends Error {status:number;constructor(status:number,message:string){super(message);this.status=status;}}
const hash=(s:string)=>createHash('sha256').update(s).digest('hex');
export function createGameServer(options:{dataPath?:string;clock?:()=>number}={}) {
  const dbPath=options.dataPath??resolve(dirname(fileURLToPath(import.meta.url)),'data','brumora.sqlite');
  if(dbPath!==':memory:')mkdirSync(dirname(dbPath),{recursive:true});
  const db=new DatabaseSync(dbPath);
  db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; CREATE TABLE IF NOT EXISTS players(id TEXT PRIMARY KEY,token_hash TEXT UNIQUE NOT NULL,profile TEXT NOT NULL); CREATE TABLE IF NOT EXISTS requests(player TEXT NOT NULL,request_id TEXT NOT NULL,response TEXT NOT NULL,created INTEGER NOT NULL,PRIMARY KEY(player,request_id));');
  const clock=options.clock??Date.now;
  const limits=new Map<string,{start:number;count:number}>();
  const lookup=db.prepare('SELECT id,profile FROM players WHERE token_hash=?');
  const getById=db.prepare('SELECT profile FROM players WHERE id=?');
  const save=(p:Player)=>db.prepare('UPDATE players SET profile=? WHERE id=?').run(JSON.stringify(p),p.id);
  function rate(key:string,max:number){
    const now=clock();let window=limits.get(key);
    if(!window||now-window.start>=60_000){window={start:now,count:0};limits.set(key,window);}
    if(++window.count>max)throw new ApiError(429,'Muitas solicitações. Aguarde um minuto.');
    if(limits.size>10_000)for(const [k,v] of limits)if(now-v.start>60_000)limits.delete(k);
  }
  async function body(req:IncomingMessage):Promise<Record<string,unknown>> {
    let raw='';for await(const chunk of req){raw+=chunk.toString();if(Buffer.byteLength(raw)>8192)throw new ApiError(413,'Solicitação muito grande.');}
    try{const parsed=JSON.parse(raw||'{}');if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw new Error();return parsed;}catch{throw new ApiError(400,'JSON inválido.');}
  }
  function respond(res:ServerResponse,status:number,data:unknown){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(JSON.stringify(data));}
  const server=createServer(async(req,res)=>{
    try{
      const path=new URL(req.url??'/', 'http://localhost').pathname;
      const ip=req.socket.remoteAddress??'local';rate(ip,600);
      if(req.method==='GET'&&path==='/health'){respond(res,200,{ok:true,game:'Brumora',version:'0.1.0',time:clock()});return;}
      if(req.method==='POST'&&path==='/api/register'){
        rate('register:'+ip,8);const data=await body(req);
        const name=typeof data.name==='string'?data.name.trim():'';
        if(!/^[\p{L}\p{N} _-]{2,20}$/u.test(name))throw new ApiError(400,'Nome: 2–20 letras, números, espaços, _ ou -.');
        const starter=typeof data.starter==='string'?data.starter:'';
        if(!catalogue.species.some(s=>s.id===starter&&s.starter))throw new ApiError(400,'Criatura inicial inválida.');
        const token=randomBytes(32).toString('hex');const p=makePlayer(name,starter,clock());
        db.prepare('INSERT INTO players VALUES(?,?,?)').run(p.id,hash(token),JSON.stringify(p));
        respond(res,201,{ok:true,token,player:view(p,clock())});return;
      }
      const auth=req.headers.authorization??'';
      if(!/^Bearer [a-f0-9]{64}$/.test(auth))throw new ApiError(401,'Entre na sua caravana para continuar.');
      const row=lookup.get(hash(auth.slice(7))) as {id:string;profile:string}|undefined;
      if(!row)throw new ApiError(401,'Sessão não encontrada neste servidor.');
      rate('player:'+row.id,120);
      if(req.method==='GET'&&path==='/api/leaderboard'){
        const players=(db.prepare('SELECT profile FROM players').all() as unknown as {profile:string}[]).map(r=>JSON.parse(r.profile) as Player);
        players.sort((a,b)=>b.rating-a.rating||b.wins-a.wins||a.created-b.created);
        respond(res,200,{ok:true,players:players.slice(0,30).map((p,i)=>({rank:i+1,id:p.id,name:p.name,rating:p.rating,wins:p.wins,losses:p.losses,bosses:p.bosses.length,team:p.team.map(id=>p.collection.find(c=>c.id===id)?.species)})),hall:players.filter(p=>p.bosses.length>0).sort((a,b)=>b.bosses.length-a.bosses.length||b.rating-a.rating).slice(0,10).map(p=>({name:p.name,bosses:p.bosses.length,rating:p.rating}))});return;
      }
      if(req.method==='GET'&&path==='/api/state'){
        const p=JSON.parse(row.profile) as Player;settle(p,clock());save(p);respond(res,200,{ok:true,player:view(p,clock())});return;
      }
      if(req.method!=='POST'||path!=='/api/action')throw new ApiError(404,'Rota não encontrada.');
      const data=await body(req);
      const requestId=req.headers['idempotency-key'];
      if(typeof requestId!=='string'||!/^[a-zA-Z0-9_-]{8,80}$/.test(requestId))throw new ApiError(400,'Identificador da ação ausente.');
      db.exec('BEGIN IMMEDIATE');
      try{
        const previous=db.prepare('SELECT response FROM requests WHERE player=? AND request_id=?').get(row.id,requestId) as {response:string}|undefined;
        if(previous){db.exec('COMMIT');respond(res,200,JSON.parse(previous.response));return;}
        const p=JSON.parse((getById.get(row.id) as {profile:string}).profile) as Player;
        settle(p,clock());
        const op=data.op;
        if(op==='route'){
          if(p.battle)throw new ApiError(409,'Conclua a batalha antes de trocar de rota.');
          const region=Number(data.region);if(!Number.isInteger(region)||region<0||region>p.unlocked)throw new ApiError(400,'Rota ainda bloqueada. Vença o chefe anterior.');
          p.region=region;p.expedition={last:clock(),ticks:0};log(p,`Expedição iniciada: ${catalogue.regions[region].name}.`);
        }else if(op==='pause'){p.expedition=null;log(p,'Caravana em repouso.');}
        else if(op==='team'){
          if(p.battle)throw new ApiError(409,'Não é possível mudar a equipe durante uma batalha.');
          const ids=data.ids;
          if(!Array.isArray(ids)||ids.length<1||ids.length>3||new Set(ids).size!==ids.length||ids.some(id=>typeof id!=='string'||!p.collection.some(c=>c.id===id)))throw new ApiError(400,'Escolha de uma a três criaturas da sua coleção, sem repetir.');
          p.team=ids as string[];log(p,'Nova formação preparada.');
        }else if(op==='train'){
          if(p.battle)throw new ApiError(409,'Treine fora da batalha.');
          const c=p.collection.find(c=>c.id===data.id);if(!c)throw new ApiError(400,'Criatura não encontrada.');
          if(c.level>=20)throw new ApiError(400,'Nível máximo atingido.');
          const cost=c.level*15;if(p.gold<cost)throw new ApiError(400,`São necessárias ${cost} moedas.`);
          p.gold-=cost;addXp(c,c.level*40-c.xp);log(p,'Treino concluído: nível '+c.level+'.');
        }else if(op==='battle'){
          if(!['wild','boss','training'].includes(String(data.kind)))throw new ApiError(400,'Tipo de batalha inválido.');
          beginBattle(p,String(data.kind));
        }else if(op==='duel'){
          if(typeof data.opponent!=='string'||data.opponent===p.id)throw new ApiError(400,'Escolha outra caravana.');
          const target=getById.get(data.opponent) as {profile:string}|undefined;
          if(!target)throw new ApiError(404,'Caravana não encontrada.');
          if(clock()-(p.last_duels[data.opponent]??0)<60_000)throw new ApiError(429,'Aguarde um minuto para repetir este desafio.');
          beginBattle(p,'duel',JSON.parse(target.profile));p.last_duels[data.opponent]=clock();
        }else if(op==='turn'){
          if(!p.battle)throw new ApiError(409,'Nenhuma batalha em andamento.');
          if(p.battle.result)throw new ApiError(409,'Feche o resultado antes de continuar.');
          turn(p.battle,String(data.command));
          if(p.battle.result){
            finishBattle(p,p.battle);
            if(p.battle.rated&&p.battle.opponent){
              const target=getById.get(p.battle.opponent) as {profile:string}|undefined;
              if(target){
                const other=JSON.parse(target.profile) as Player;
                const won=p.battle.result==='win';const expected=1/(1+10**((other.rating-p.rating)/400));
                const delta=Math.round(24*((won?1:0)-expected));p.rating=Math.max(100,p.rating+delta);other.rating=Math.max(100,other.rating-delta);
                if(won){p.wins++;other.losses++;}else{p.losses++;other.wins++;}
                log(other,`${p.name} desafiou sua defesa: ${won?'derrota':'vitória'} (${-delta>=0?'+':''}${-delta} pontos).`);save(other);
                p.battle.messages.push(`Liga: ${delta>=0?'+':''}${delta} pontos. Poder e atributos normalizados.`);
              }
            }
          }
        }else if(op==='close_battle'){
          if(p.battle&&!p.battle.result)throw new ApiError(409,'Conclua a batalha primeiro.');p.battle=null;
        }else if(op==='retreat'){
          if(p.battle?.rated)throw new ApiError(409,'Duelos da liga precisam ser concluídos.');p.battle=null;log(p,'A caravana voltou ao acampamento.');
        }else throw new ApiError(400,'Ação desconhecida.');
        save(p);const response={ok:true,player:view(p,clock())};
        db.prepare('INSERT INTO requests VALUES(?,?,?,?)').run(p.id,requestId,JSON.stringify(response),clock());
        db.prepare('DELETE FROM requests WHERE created < ?').run(clock()-24*60*60*1000);
        db.exec('COMMIT');respond(res,200,response);
      }catch(error){db.exec('ROLLBACK');throw error;}
    }catch(error){
      const e=error as Error;
      if(e instanceof ApiError)respond(res,e.status,{ok:false,error:e.message});
      else {console.error('Falha no servidor:',e.message);respond(res,400,{ok:false,error:'A operação não pôde ser concluída.'});}
    }
  });
  server.requestTimeout=10_000;server.headersTimeout=10_000;
  server.on('close',()=>db.close());
  return server;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
  const port=Number(process.env.BRUMORA_PORT??8787);
  const host=process.env.BRUMORA_HOST??'127.0.0.1';
  const server=createGameServer();
  server.on('error',e=>{console.error('Não foi possível iniciar o servidor:',e.message);process.exitCode=1;});
  server.listen(port,host,()=>console.log(`Brumora local: ${host}:${port} — Ctrl+C para encerrar. Dados em server/data.`));
  for(const signal of ['SIGINT','SIGTERM'] as const)process.on(signal,()=>server.close());
}
