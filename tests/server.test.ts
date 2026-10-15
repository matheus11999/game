import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { makePlayer, makeCreature, stats, settle, beginBattle, turn, finishBattle, view, catalogue, enemyCatalogue, species, regionEnemies, TICK_MS, AFK_CAP, type Player } from '../server/engine.ts';
import { createGameServer } from '../server/index.ts';

test('mesma espécie varia por individuais, mas liga normaliza nível, raridade e IVs',()=>{
 const a=makeCreature('ember',true),b=makeCreature('ember',true);
 a.iv.attack=0;b.iv.attack=15;b.level=20;b.rarity='epic';
 assert.ok(stats(b).attack>stats(a).attack);assert.deepEqual(stats(a,true),stats(b,true));
});
test('AFK entrega XP, moedas, descobertas e não duplica o mesmo intervalo',()=>{
 const p=makePlayer('Teste','moss',1000);p.expedition={last:1000,ticks:0};
 settle(p,1000+TICK_MS*3);assert.equal(p.gold,39);assert.equal(p.collection.length,2);assert.equal(p.team.length,2);
 const before=JSON.stringify(p);settle(p,1000+TICK_MS*3);assert.equal(JSON.stringify(p),before);
});
test('AFK limita ausência a 8h e descarta excedente em vez de permitir nova coleta',()=>{
 const p=makePlayer('Teste','luna',1000);p.expedition={last:1000,ticks:0};
 settle(p,1000+AFK_CAP*4);assert.equal(p.gold,30+AFK_CAP/TICK_MS*3);assert.equal(p.collection.length,80);
 const before=p.gold;settle(p,1000+AFK_CAP*4);assert.equal(p.gold,before);
 assert.ok(p.collection.every(c=>c.level<=20));
});
test('relógio anterior não gera recompensa',()=>{
 const p=makePlayer('Teste','ember',1000);p.expedition={last:1000,ticks:0};settle(p,500);assert.equal(p.gold,30);
});
test('suporte cura e tanque aplica escudo com recarga',()=>{
 const p=makePlayer('Teste','luna');const tank=makeCreature('moss',true);p.collection.push(tank);p.team.push(tank.id);
 const b=beginBattle(p,'wild');b.allies[0].hp=20;turn(b,'skill');
 assert.ok(b.allies[0].hp>20);assert.ok(b.allies.some(a=>a.shield>0));assert.ok(b.allies.every(a=>a.cooldown>0));
});
test('combate automático termina em até 60 turnos e resultados são determinísticos',()=>{
 const p=makePlayer('Teste','ember');const b=beginBattle(p,'training');const copy=structuredClone(b);
 while(!b.result)turn(b,'auto');while(!copy.result)turn(copy,'auto');
 assert.ok(b.round<=60);assert.deepEqual(b,copy);assert.throws(()=>turn(b,'attack'));
});
test('servidor real valida autenticação, ownership, idempotência e ranking entre duas contas',async()=>{
 let now=1_000_000;const server=createGameServer({dataPath:':memory:',clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
 const address=server.address();assert.ok(address&&typeof address==='object');const base=`http://127.0.0.1:${address.port}`;
 const request=async(path:string,token='',data?:unknown,key=randomBytes(12).toString('hex'))=>{
  const r=await fetch(base+path,{method:data?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),'Idempotency-Key':key},...(data?{body:JSON.stringify(data)}:{})});return {status:r.status,json:await r.json() as any};
 };
 try{
  assert.equal((await request('/health')).status,200);assert.equal((await request('/api/state')).status,401);
  const a=(await request('/api/register','',{name:'Alice',starter:'ember'})).json;
  const b=(await request('/api/register','',{name:'Bruno',starter:'moss'})).json;
  assert.equal((await request('/api/action',a.token,{op:'team',ids:b.player.team})).status,400);
  const key='repeat_training_123';const first=await request('/api/action',a.token,{op:'train',id:a.player.team[0]},key);
  const second=await request('/api/action',a.token,{op:'train',id:a.player.team[0]},key);
  assert.deepEqual(first.json,second.json);assert.equal(first.json.player.gold,15);assert.equal(first.json.player.collection[0].level,2);
  await request('/api/action',a.token,{op:'route',region:0});now+=TICK_MS*3;
  const afk=await request('/api/state',a.token);assert.equal(afk.json.player.collection.length,2);
  assert.equal((await request('/api/action',a.token,{op:'route',region:2})).status,400);
  let duel=await request('/api/action',a.token,{op:'duel',opponent:b.player.id});assert.equal(duel.status,200);
  while(!duel.json.player.battle.result)duel=await request('/api/action',a.token,{op:'turn',command:'auto'});
  assert.equal(duel.status,200);
  const rank=(await request('/api/leaderboard',a.token)).json;
  assert.equal(rank.players.length,2);assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.wins,0),1);assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.losses,0),1);
  assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.rating,0),2000);
  assert.equal((await request('/api/action',a.token,{op:'turn',command:'auto'})).status,409);
  await request('/api/action',a.token,{op:'close_battle'});
  assert.equal((await request('/api/action',a.token,{op:'duel',opponent:b.player.id})).status,429);
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));}
});
test('banco persistente recupera conta e recompensa AFK após reinício do servidor',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'brumora-test-'));const file=join(dir,'test.sqlite');let now=10_000;
 let server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
 async function url(){const a=server.address();assert.ok(a&&typeof a==='object');return `http://127.0.0.1:${a.port}`;}
 try{
  const register=await fetch((await url())+'/api/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:'Persistente',starter:'luna'})});
  const account=await register.json() as any;
  await fetch((await url())+'/api/action',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+account.token,'Idempotency-Key':'persistent_route'},body:JSON.stringify({op:'route',region:0})});
  await new Promise<void>(resolve=>server.close(()=>resolve()));now+=60_000;
  server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
  const r=await fetch((await url())+'/api/state',{headers:{Authorization:'Bearer '+account.token}});const state=await r.json() as any;
  assert.equal(state.player.id,account.player.id);assert.equal(state.player.gold,39);assert.equal(state.player.collection.length,2);
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));rmSync(dir,{recursive:true,force:true});}
});


test('nove inimigos originais usam atlas próprio e permanecem fora da coleção AFK',()=>{
 assert.equal(enemyCatalogue.species.length,9);
 assert.equal(new Set(enemyCatalogue.species.map(s=>s.id)).size,9);
 assert.deepEqual(enemyCatalogue.species.map(s=>s.sprite),[0,1,2,3,4,5,6,7,8]);
 for(const e of enemyCatalogue.species){assert.equal(species(e.id),e);assert.equal(e.sprite_atlas,'enemy');assert.equal(e.starter,false);assert.ok(!catalogue.species.some(s=>s.id===e.id));assert.throws(()=>makePlayer('Inválido',e.id));}
 const p=makePlayer('Colecionador','ember',1000);p.expedition={last:1000,ticks:0};settle(p,1000+AFK_CAP);
 assert.ok(p.collection.every(c=>catalogue.species.some(s=>s.id===c.species)));
});
test('encontros usam fauna regional e chefes têm uma escolta de dois',()=>{
 const p=makePlayer('Explorador','moss');
 for(let region=0;region<3;region++){
  p.region=region;p.battle=null;const wild=beginBattle(p,'wild');assert.equal(wild.enemies.length,region+1);assert.ok(wild.enemies.every(e=>regionEnemies[region].wild.includes(e.species)));
  p.battle=null;const boss=beginBattle(p,'boss');assert.equal(boss.enemies.length,3);assert.equal(boss.enemies[0].species,regionEnemies[region].boss);assert.equal(species(boss.enemies[0].species).boss,true);assert.ok(boss.enemies.slice(1).every(e=>regionEnemies[region].wild.includes(e.species)));assert.ok(boss.enemies.reduce((s,e)=>s+e.stats.hp,0)>wild.enemies.reduce((s,e)=>s+e.stats.hp,0));
 }
});
test('todas as iniciais vencem encontros de abertura em diferentes seeds',()=>{
 for(const starter of ['ember','moss','luna'])for(const enemy of regionEnemies[0].wild)for(let seed=1;seed<=12;seed++){
  const p=makePlayer('Iniciante',starter);const b=beginBattle(p,'wild');const st=stats(makeCreature(enemy,true));Object.assign(b.enemies[0],{species:enemy,name:species(enemy).name,stats:st,hp:st.hp});b.seed=seed;while(!b.result)turn(b,'auto');assert.equal(b.result,'win',`${starter} vs ${enemy} seed ${seed}`);
 }
});
test('PvE vencido avança caravana; derrota e treino não; perfis legados têm defaults',()=>{
 const p=makePlayer('Viajante','ember');delete p.distance;delete p.encounters;assert.equal(view(p).distance,0);assert.equal(view(p).encounters,0);
 const wild=beginBattle(p,'wild');wild.result='win';finishBattle(p,wild);assert.equal(p.distance,120);assert.equal(p.encounters,1);
 p.battle=null;const lost=beginBattle(p,'wild');lost.result='loss';finishBattle(p,lost);assert.equal(p.distance,120);
 p.battle=null;const train=beginBattle(p,'training');train.result='win';finishBattle(p,train);assert.equal(p.distance,120);assert.equal(p.encounters,1);
 p.battle=null;const boss=beginBattle(p,'boss');boss.result='win';finishBattle(p,boss);assert.equal(p.distance,420);assert.equal(p.encounters,2);assert.equal(p.unlocked,1);assert.deepEqual(p.bosses,[0]);assert.ok(p.collection.every(c=>catalogue.species.some(s=>s.id===c.species)));
});
test('chefe inicial exige preparação e equipe treinada equilibrada pode vencer',()=>{
 const solo=makePlayer('Sozinho','ember');const hard=beginBattle(solo,'boss');hard.seed=71;while(!hard.result)turn(hard,'auto');assert.equal(hard.result,'loss');
 const p=makePlayer('Preparado','ember');for(const id of ['moss','luna']){const c=makeCreature(id,true);p.collection.push(c);p.team.push(c.id);}for(const c of p.collection)c.level=5;
 const boss=beginBattle(p,'boss');boss.seed=71;while(!boss.result)turn(boss,'auto');assert.equal(boss.result,'win');
});


test('eventos de combate identificam ator, alvo, espécie e efeitos de cada ação',()=>{
 const p=makePlayer('Efeitos','luna');const tank=makeCreature('moss',true);p.collection.push(tank);p.team.push(tank.id);
 const b=beginBattle(p,'wild');const events=()=>b.events??[];assert.equal(b.events?.length,0);b.allies[0].hp=20;b.enemies[0].cooldown=1;
 turn(b,'skill');assert.ok(b.events?.some(e=>e.kind==='heal'&&e.actor===p.team[0]&&e.target===p.team[0]&&e.value>0&&e.skill));assert.equal(b.events?.filter(e=>e.kind==='shield'&&e.actor===tank.id).length,2);assert.ok(b.events?.some(e=>e.kind==='attack'));
 const units=[...b.allies,...b.enemies];
 for(const e of b.events??[]){assert.ok(units.some(u=>u.id===e.actor&&u.species===e.species));assert.ok(units.some(u=>u.id===e.target));assert.ok(e.value>=0&&Number.isFinite(e.value));}
 const previous=b.events;turn(b,'guard');assert.notEqual(b.events,previous);assert.equal(b.events?.filter(e=>e.kind==='guard').length,2);assert.ok(b.events?.filter(e=>e.kind==='guard').every(e=>e.actor===e.target&&!e.skill));
 // Old persisted battles may lack events; the next turn still produces them.
 delete b.events;turn(b,'attack');assert.ok(Array.isArray(events()));assert.ok(events().filter(e=>e.kind==='attack').every(e=>!e.skill||units.find(u=>u.id===e.actor)?.side==='enemy'));
});
test('escudo absorvido é descontado do valor visual de dano',()=>{
 const p=makePlayer('Protegido','moss');const b=beginBattle(p,'wild');b.allies[0].shield=1000;b.enemies[0].cooldown=1;
 turn(b,'guard');const incoming=b.events?.filter(e=>e.kind==='attack'&&e.target===b.allies[0].id);assert.ok(incoming?.length);assert.ok(incoming?.every(e=>e.value===0));
});
