import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { makePlayer, makeCreature, stats, settle, beginBattle, turn, finishBattle, defeatedEnemyXp, view, catalogue, enemyCatalogue, species, regionEnemies, TICK_MS, AFK_CAP, heartbeat, startExpedition, endExpedition, returnFromExpedition, syncExpeditionBattle, type Player } from '../server/engine.ts';
import { goldToMilli, goldFromMilli, changeGoldMilli } from '../server/progression.ts';
import { createGameServer } from '../server/index.ts';

test('mesma espécie varia por individuais, mas liga normaliza nível, raridade e IVs',()=>{
 const a=makeCreature('ember',true),b=makeCreature('ember',true);
 a.iv.attack=0;b.iv.attack=15;b.level=20;b.rarity='epic';
 assert.ok(stats(b).attack>stats(a).attack);assert.deepEqual(stats(a,true),stats(b,true));
});
test('sessão ativa entrega descobertas, nunca moedas ou XP por tempo, sem duplicar intervalo',()=>{
 const p=makePlayer('Teste','moss',1000);p.expedition={last:1000,ticks:0};p.active_until=1000+AFK_CAP;
 settle(p,1000+TICK_MS*3);assert.equal(p.gold,30);assert.equal(p.collection.length,2);assert.equal(p.team.length,2);assert.ok(p.collection.every(c=>c.level===1&&c.xp===0));
 const before=JSON.stringify(p);settle(p,1000+TICK_MS*3);assert.equal(JSON.stringify(p),before);
});
test('simulação ativa longa respeita limite de processamento e coleção',()=>{
 const p=makePlayer('Teste','luna',1000);p.expedition={last:1000,ticks:0};p.active_until=1000+AFK_CAP*4;
 settle(p,1000+AFK_CAP*4);assert.equal(p.gold,30);assert.equal(p.collection.length,80);
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
  assert.equal((await request('/api/action',a.token,{op:'train',id:a.player.team[0]})).status,400);
  const key='repeat_route_123';const first=await request('/api/action',a.token,{op:'route',region:0},key);
  const second=await request('/api/action',a.token,{op:'route',region:0},key);
  assert.deepEqual(first.json,second.json);assert.equal(first.json.player.gold,30);assert.equal(first.json.player.collection[0].level,1);
  await request('/api/action',a.token,{op:'route',region:0});for(let i=0;i<24;i++){now+=2500;await request("/api/state",a.token);}
  const afk=await request('/api/state',a.token);assert.equal(afk.json.player.collection.length,2);assert.ok(afk.json.player.collection.every((c:any)=>c.level===1&&c.xp===0));
  assert.equal((await request('/api/action',a.token,{op:'route',region:2})).status,400);
  let duel=await request('/api/action',a.token,{op:'duel',opponent:b.player.id});assert.equal(duel.status,200);
  while(!duel.json.player.battle.result)duel=await request('/api/action',a.token,{op:'turn',command:'auto',xp:999999,gold:999999,result:'win',enemies:[{hp:0}]});
  assert.equal(duel.status,200);
  assert.ok(duel.json.player.gold<40);assert.ok(duel.json.player.collection.every((c:any)=>c.xp<100&&c.level<=2));
  const rank=(await request('/api/leaderboard',a.token)).json;
  assert.equal(rank.players.length,2);assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.wins,0),1);assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.losses,0),1);
  assert.equal(rank.players.reduce((sum:number,p:any)=>sum+p.rating,0),2000);
  assert.equal((await request('/api/action',a.token,{op:'turn',command:'auto'})).status,409);
  await request('/api/action',a.token,{op:'close_battle'});
  assert.equal((await request('/api/action',a.token,{op:'duel',opponent:b.player.id})).status,429);
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));}
});
test('banco persistente recupera conta e não recompensa tempo com jogo fechado',async()=>{
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
  assert.equal(state.player.id,account.player.id);assert.equal(state.player.gold,30);assert.equal(state.player.collection.length,1);
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

// TaskMon economy and timed progression regressions.
import { grantLoot, upgradeCreature, upgradeCost, expandInventory, claimLoot, migrate } from '../server/progression.ts';
import { gearScore } from '../server/engine.ts';

test('loot empilha em quatro espaços e guarda excesso sem perda; expansão resgata',()=>{
 const p=makePlayer('Mochila','ember');grantLoot(p,{essence:2,fibre:3,pearl:4,shard:5,core:2,sigil:1});
 assert.equal(Object.keys(p.inventory!).length,4);assert.deepEqual(p.pending_loot,{core:2,sigil:1});
 grantLoot(p,{essence:2,core:1});assert.equal(p.inventory!.essence,4);assert.equal(p.pending_loot!.core,3);
 claimLoot(p);assert.equal(p.pending_loot!.core,3);p.gold=60;expandInventory(p);
 assert.equal(p.gold,0);assert.equal(p.inventory_capacity,6);assert.equal(p.inventory!.core,3);assert.equal(p.inventory!.sigil,1);assert.deepEqual(p.pending_loot,{});
});
test('aprimoramento consome materiais uma vez, mantém XP e espera tempo do servidor',()=>{
 const p=makePlayer('Artesao','ember');const c=p.collection[0];const before=stats(c);grantLoot(p,{essence:2,fibre:3});
 upgradeCreature(p,c.id,1000);assert.equal(c.upgrade,0);assert.equal(c.level,1);assert.equal(c.xp,0);assert.equal(p.gold,10);
 assert.deepEqual(p.inventory,{});assert.equal(c.upgrade_job!.ready_at,61000);assert.throws(()=>upgradeCreature(p,c.id,2000));
 const recovered=JSON.parse(JSON.stringify(p)) as Player;settle(recovered,60999);assert.equal(recovered.collection[0].upgrade,0);
 settle(recovered,61000);assert.equal(recovered.collection[0].upgrade,1);assert.equal(recovered.collection[0].upgrade_job,undefined);
 assert.ok(stats(recovered.collection[0]).attack>before.attack);assert.ok(gearScore(recovered.collection[0])>gearScore(c));
 const serialized=JSON.stringify(recovered);settle(recovered,61000);assert.equal(JSON.stringify(recovered),serialized);
});
test('custos e duração crescem, valida ownership, materiais, nível, combate e limite',()=>{
 const p=makePlayer('Validacao','moss');const c=p.collection[0];
 assert.throws(()=>upgradeCreature(p,'inexistente'));assert.throws(()=>upgradeCreature(p,c.id));
 c.upgrade=1;assert.equal(upgradeCost(c).seconds,240);assert.throws(()=>upgradeCreature(p,c.id));
 c.level=20;c.upgrade=9;assert.equal(upgradeCost(c).seconds,6000);assert.ok(upgradeCost(c).materials.core>0);
 c.upgrade=10;assert.throws(()=>upgradeCreature(p,c.id));
 p.gold=1000;p.inventory_capacity=20;assert.throws(()=>expandInventory(p));
 c.upgrade=0;p.battle=beginBattle(p,'wild');assert.throws(()=>upgradeCreature(p,c.id));
});
test('prêmios PvE são idempotentes; derrota sem abates e treino não dão loot',()=>{
 const p=makePlayer('Loot','ember');const b=beginBattle(p,'wild');b.enemies[0].hp=0;b.result='win';finishBattle(p,b,1000);
 assert.equal(p.inventory!.essence,2);assert.equal(p.inventory!.fibre,3);assert.equal(b.rewards!.xp,defeatedEnemyXp(b.enemies[0],b));
 const saved=JSON.stringify(p);finishBattle(p,b,1000);assert.equal(JSON.stringify(p),saved);
 for(const kind of ['training','wild']){p.battle=null;const other=beginBattle(p,kind);other.result=kind==='wild'?'loss':'win';const bag=JSON.stringify(p.inventory);finishBattle(p,other);assert.equal(JSON.stringify(p.inventory),bag);}
});
test('Arena recompensa até cinco vitórias por dia; poder de aprimoramento é normalizado',()=>{
 const p=makePlayer('Duelista','ember'),o=makePlayer('Defesa','moss');
 for(let i=0;i<6;i++){p.battle=null;const b=beginBattle(p,'duel',o);b.enemies[0].hp=0;b.result='win';finishBattle(p,b,1000);}
 assert.equal(p.inventory!.sigil,5);assert.equal(p.pvp_loot_wins,5);
 p.battle=null;const next=beginBattle(p,'duel',o);next.enemies[0].hp=0;next.result='win';finishBattle(p,next,86401000);assert.equal(p.inventory!.sigil,6);
 const c=p.collection[0],base=stats(c,true);c.upgrade=10;c.level=20;assert.deepEqual(stats(c,true),base);
 p.battle=null;const duel=beginBattle(p,'duel',o);assert.equal(duel.allies[0].upgrade,0);
});
test('perfis legados migram sem perder coleção, progresso ou moedas',()=>{
 const p=makePlayer('Legado','moss');const id=p.collection[0].id;delete p.inventory;delete p.inventory_capacity;delete p.collection[0].upgrade;
 migrate(p);const snapshot=view(p);assert.equal(p.collection[0].id,id);assert.equal(p.gold,30);assert.equal(p.inventory_capacity,4);assert.ok(Number(snapshot.gear_score)>0);
});
test('API real: loot, upgrade temporizado, idempotência, persistência e GS sem confiar no cliente',async()=>{
 let now=1000000;const server=createGameServer({dataPath:':memory:',clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
 const a=server.address();assert.ok(a&&typeof a==='object');const base=`http://127.0.0.1:${a.port}`;
 let token='';const req=async(op?:Record<string,unknown>,key=randomBytes(10).toString('hex'))=>{const r=await fetch(base+(op?'/api/action':'/api/state'),{method:op?'POST':'GET',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json','Idempotency-Key':key},...(op?{body:JSON.stringify(op)}:{})});return {status:r.status,body:await r.json() as any};};
 try{
  const r=await fetch(base+'/api/register',{method:'POST',body:JSON.stringify({name:'Fluxo',starter:'ember'})});const account=await r.json() as any;token=account.token;
  assert.equal((await req({op:'upgrade',id:'outro',gold:9999,materials:{essence:999}})).status,400);
  let result=await req({op:'battle',kind:'wild'});while(!result.body.player.battle.result)result=await req({op:'turn',command:'auto'});
  assert.equal(result.body.player.battle.result,'win');await req({op:'close_battle'});
  const id=account.player.team[0];const key='timed_upgrade_repeat';const started=await req({op:'upgrade',id,seconds:0},key);assert.equal(started.status,200);
  const again=await req({op:'upgrade',id,seconds:0},key);assert.deepEqual(again.body,started.body);
  assert.equal(started.body.player.collection[0].upgrade,0);assert.equal(started.body.player.collection[0].upgrade_job.ready_at,now+60000);
  now+=59999;assert.equal((await req()).body.player.collection[0].upgrade,0);now++;
  const done=(await req()).body.player;assert.equal(done.collection[0].upgrade,1);assert.ok(done.gear_score>started.body.player.gear_score);assert.ok(done.achievements.some((x:any)=>x.id==='craft'&&x.unlocked));
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));}
});

test('progresso AFK exige heartbeat com jogo aberto e descarta período offline',()=>{
 const p=makePlayer('Presenca','moss',1000);p.expedition={last:1000,ticks:0};heartbeat(p,1000);
 for(let t=3500;t<=61000;t+=2500)heartbeat(p,t);
 assert.equal(p.gold,30);assert.equal(p.collection.length,2);const xp=p.collection[0].xp;assert.equal(xp,0);
 settle(p,3600000);assert.equal(p.gold,30);assert.equal(p.collection[0].xp,xp);
 heartbeat(p,3600000);for(let i=1;i<=8;i++)heartbeat(p,3600000+i*2500);
 assert.equal(p.gold,30);assert.equal(p.collection[0].xp,xp);
});

test('identidade de batalha fica estável enquanto a seed avança e muda no próximo encontro',()=>{
 const p=makePlayer('Encontro','ember');const b=beginBattle(p,'wild');const id=b.id;assert.ok(id);turn(b,'auto');assert.equal(b.id,id);
 p.battle=null;assert.notEqual(beginBattle(p,'wild').id,id);
});

test('XP vem só de inimigos derrotados e só dos participantes; derrota parcial paga uma vez',()=>{
 const p=makePlayer('Participantes','ember');const second=makeCreature('moss',true),reserve=makeCreature('luna',true);p.collection.push(second,reserve);p.team.push(second.id);p.region=1;
 const b=beginBattle(p,'wild');b.enemies[0].hp=0;b.allies[0].hp=0;b.result='loss';
 const expected=defeatedEnemyXp(b.enemies[0],b);const gold=p.gold;finishBattle(p,b);
 assert.equal(b.rewards!.xp,expected);assert.equal(b.rewards!.defeated!.length,1);assert.equal(b.rewards!.defeated![0].id,b.enemies[0].id);
 assert.equal(p.collection[0].xp,expected);assert.equal(second.xp,expected);assert.equal(reserve.xp,0);assert.ok(p.gold>gold);assert.deepEqual(p.inventory,{essence:2,pearl:3});
 assert.deepEqual(b.rewards!.xp_by_creature,{[p.team[0]]:expected,[second.id]:expected});const saved=JSON.stringify(p);finishBattle(p,b);assert.equal(JSON.stringify(p),saved);
});

test('resultado sem abates, batalha incompleta e treino nunca concedem XP',()=>{
 for(const kind of ['wild','boss','training']){
  const p=makePlayer('SemAbates','ember');const b=beginBattle(p,kind);finishBattle(p,b);assert.equal(p.collection[0].xp,0);assert.equal(b.rewarded,undefined);
  b.result='win';if(kind==='training')for(const enemy of b.enemies)enemy.hp=0;
  finishBattle(p,b);assert.equal(p.collection[0].xp,0);assert.equal(b.rewards!.xp,0);
 }
});

test('XP por inimigo cresce com nível e atributos; chefe concede bônus; legado infere nível',()=>{
 const p=makePlayer('Escala','ember');const b=beginBattle(p,'wild');const normal=b.enemies[0];const base=defeatedEnemyXp(normal,b);
 assert.ok(base>=3&&base<=5);normal.level=10;assert.ok(defeatedEnemyXp(normal,b)>base);
 normal.stats={hp:300,attack:70,defense:50,speed:35};assert.ok(defeatedEnemyXp(normal,b)>base*2);
 p.battle=null;const boss=beginBattle(p,'boss');assert.ok(defeatedEnemyXp(boss.enemies[0],boss)>defeatedEnemyXp(boss.enemies[1],boss));
 delete boss.enemies[0].level;assert.ok(Number.isSafeInteger(defeatedEnemyXp(boss.enemies[0],boss)));
});

test('XP respeita limite de nível e rewards relata ganho efetivamente aceito',()=>{
 const p=makePlayer('Limite','ember');const c=p.collection[0];c.level=19;c.xp=759;const b=beginBattle(p,'wild');b.enemies[0].hp=0;b.result='win';finishBattle(p,b);
 assert.equal(c.level,20);assert.equal(c.xp,0);assert.equal(b.rewards!.xp_by_creature![c.id],1);
 p.battle=null;const next=beginBattle(p,'wild');next.enemies[0].hp=0;next.result='win';finishBattle(p,next);assert.equal(next.rewards!.xp_by_creature![c.id],0);
});

test('duelo usa snapshots normalizados e abates; limite diário evita farm ilimitado de XP',()=>{
 const p=makePlayer('PvPXP','ember'),other=makePlayer('DefesaXP','moss');other.collection[0].level=20;
 for(let i=0;i<6;i++){
  p.battle=null;const b=beginBattle(p,'duel',other);assert.equal(b.enemies[0].level,5);b.enemies[0].hp=0;b.result='win';const expected=defeatedEnemyXp(b.enemies[0],b);finishBattle(p,b,1000);
  assert.equal(b.rewards!.xp,i<5?expected:0);
 }
});

test('moedas usam milésimos inteiros sem deriva e migram saldo legado com três casas',()=>{
 const balance={gold:0};for(let i=0;i<10000;i++)changeGoldMilli(balance,1);assert.equal(balance.gold,10);
 changeGoldMilli(balance,100);changeGoldMilli(balance,200);assert.equal(balance.gold,10.3);changeGoldMilli(balance,-101);assert.equal(balance.gold,10.199);
 assert.equal(goldToMilli(balance.gold),10199);assert.equal(goldFromMilli(1001),1.001);assert.throws(()=>changeGoldMilli(balance,0.1));assert.throws(()=>changeGoldMilli(balance,-99999));
 const p=makePlayer('Arredonda','ember');p.gold=12.345678;migrate(p);assert.equal(p.gold,12.346);
 const q=makePlayer('TickDecimal','moss',1000);q.expedition={last:1000,ticks:0};q.active_until=201000;for(let t=21000;t<=201000;t+=20000)settle(q,t);assert.equal(q.gold,30);assert.equal(q.collection[0].xp,0);
 const r=makePlayer('TickAgrupado','moss',1000);r.expedition={last:1000,ticks:0};r.active_until=201000;settle(r,201000);assert.equal(r.gold,q.gold);
});

test('HP permanece por exemplar entre encontros; upgrades e nova formação não ressuscitam caídos',()=>{
 const p=makePlayer('PersistHP','ember',1000),tank=makeCreature('moss',true);p.collection.push(tank);p.team.push(tank.id);startExpedition(p,0,1000);
 const first=beginBattle(p,'wild');first.allies[0].hp=0;first.allies[1].hp=61;first.enemies[0].hp=0;first.result='win';finishBattle(p,first,4000);
 assert.equal(p.expedition!.hp![p.team[0]],0);assert.equal(p.expedition!.hp![tank.id],61);p.battle=null;
 const recovered=JSON.parse(JSON.stringify(p)) as Player;recovered.collection[0].upgrade=5;tank.level=5;
 const second=beginBattle(recovered,'wild');assert.equal(second.allies[0].hp,0);assert.equal(second.allies[1].hp,61);
 const reserve=makeCreature('luna',true);recovered.collection.push(reserve);recovered.battle=null;recovered.team=[tank.id,reserve.id];const third=beginBattle(recovered,'wild');assert.equal(third.allies[0].hp,61);assert.equal(third.allies[1].hp,stats(reserve).hp);
});

test('queda da equipe encerra expedição e resumo reflete recompensas reais uma única vez',()=>{
 const p=makePlayer('Wipe','ember',1000),tank=makeCreature('moss',true);p.collection.push(tank);p.team.push(tank.id);startExpedition(p,1,1000);
 const b=beginBattle(p,'wild');b.allies.forEach(a=>a.hp=0);b.enemies[0].hp=0;b.result='loss';const before=p.gold;finishBattle(p,b,12500);
 assert.equal(p.expedition,null);const summary=p.last_expedition_summary!;assert.equal(summary.outcome,'defeat');assert.equal(summary.region,1);assert.equal(summary.name,catalogue.regions[1].name);assert.equal(summary.duration_ms,11500);assert.equal(summary.duration,11);
 assert.equal(summary.gold,b.rewards!.gold);assert.equal(goldToMilli(p.gold)-goldToMilli(before),goldToMilli(summary.gold));assert.deepEqual(summary.items,b.rewards!.items);assert.equal(summary.kills,1);assert.equal(summary.battles,1);
 assert.equal(summary.enemy_xp,b.rewards!.xp);assert.equal(summary.xp,Object.values(b.rewards!.xp_by_creature!).reduce((sum,n)=>sum+n,0));assert.deepEqual(summary.xp_by_creature,b.rewards!.xp_by_creature);
 const saved=JSON.stringify(p);finishBattle(p,b,13000);endExpedition(p,'returned',14000);assert.equal(JSON.stringify(p),saved);
});

test('saída voluntária fecha batalha parcial, preserva loot pendente e não duplica resumo',()=>{
 const p=makePlayer('Volta','ember',1000);p.inventory={fibre:1,shard:1,core:1,sigil:1};startExpedition(p,1,1000);
 const b=beginBattle(p,'wild');b.enemies[0].hp=0;b.allies[0].hp=15;syncExpeditionBattle(p,b);assert.equal(p.expedition!.hp![p.team[0]],15);
 returnFromExpedition(p,8100);assert.equal(p.battle,null);assert.equal(p.expedition,null);assert.equal(p.last_expedition_summary!.outcome,'returned');assert.deepEqual(p.last_expedition_summary!.items,{essence:2,pearl:3});assert.deepEqual(p.pending_loot,{essence:2,pearl:3});
 const snapshot=JSON.stringify(p);returnFromExpedition(p,9000);assert.equal(JSON.stringify(p),snapshot);
});

test('nova expedição restaura HP uma vez; coleta e avanço não restauram HP',()=>{
 const p=makePlayer('NovaRota','moss',1000);startExpedition(p,0,1000);const original=p.expedition!.id;p.expedition!.hp![p.team[0]]=7;
 heartbeat(p,2000);view(p,2000);assert.equal(p.expedition!.hp![p.team[0]],7);
 startExpedition(p,0,3000);assert.notEqual(p.expedition!.id,original);assert.equal(p.last_expedition_summary!.id,original);assert.equal(p.last_expedition_summary!.outcome,'changed_route');assert.equal(p.expedition!.hp![p.team[0]],stats(p.collection[0]).hp);
 const b=beginBattle(p,'wild');b.allies[0].hp=9;b.enemies[0].hp=0;b.result='win';finishBattle(p,b,4000);p.battle=null;assert.equal(beginBattle(p,'wild').allies[0].hp,9);
});

test('PvP e treino não alteram HP ou totais da expedição; batalha fora de rota tem vida completa',()=>{
 const p=makePlayer('Isolado','ember',1000),other=makePlayer('Defesa','moss');startExpedition(p,0,1000);p.expedition!.hp![p.team[0]]=5;
 for(const kind of ['duel','training']){const b=beginBattle(p,kind,kind==='duel'?other:undefined);assert.equal(b.expedition_id,undefined);assert.equal(b.allies[0].hp,b.allies[0].stats.hp);b.allies[0].hp=0;b.enemies.forEach(e=>e.hp=0);b.result='win';syncExpeditionBattle(p,b);finishBattle(p,b,2000);p.battle=null;assert.equal(p.expedition!.hp![p.team[0]],5);assert.equal(p.expedition!.totals!.battles,0);}
 endExpedition(p,'returned',3000);assert.equal(beginBattle(p,'wild').allies[0].hp,stats(p.collection[0]).hp);
});

test('tempo aberto não gera moedas ou XP e vitória sem abates não fabrica prêmios',()=>{
 const p=makePlayer('SomenteAbates','ember',1000);startExpedition(p,0,1000);for(let t=1000;t<=121000;t+=2500)heartbeat(p,t);assert.equal(p.gold,30);assert.ok(p.collection.every(c=>c.xp===0&&c.level===1));
 const b=beginBattle(p,'wild');b.result='win';finishBattle(p,b,122000);assert.equal(p.gold,30);assert.deepEqual(b.rewards!.items,{});assert.equal(b.rewards!.xp,0);assert.equal(p.expedition!.totals!.kills,0);
});

test('papéis preservam identidade: atacantes dano, tanques defesa, suportes cura',()=>{
 for(const spec of catalogue.species){
  if(spec.role==='Atacante')assert.equal(spec.skill.kind,'strike');
  if(spec.role==='Tanque'){assert.equal(spec.skill.kind,'shield');assert.equal(spec.passive?.stat,'defense');}
  if(spec.role==='Suporte')assert.equal(spec.skill.kind,'heal');
 }
});

test('resultado legado com wipe encerra rota na reconexão sem repetir recompensas',()=>{
 const p=makePlayer('WipeLegado','ember',1000);p.expedition={last:1000,ticks:0};const b=beginBattle(p,'wild');delete b.expedition_id;b.allies[0].hp=0;b.result='loss';b.rewarded=true;
 heartbeat(p,3000);assert.equal(p.expedition,null);assert.equal(p.gold,30);assert.equal(p.last_expedition_summary!.outcome,'defeat');assert.equal(p.last_expedition_summary!.gold,0);
});

test('API/SQLite mantém HP entre encontros e reinício; pause produz resumo idempotente sem curar rota',async()=>{
 const directory=mkdtempSync(join(tmpdir(),'taskmon-journey-')),file=join(directory,'save.sqlite');let now=1000000;
 let server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');let token='';
 const req=async(data?:Record<string,unknown>,key=randomBytes(10).toString('hex'))=>{const address=server.address();assert.ok(address&&typeof address==='object');const response=await fetch(`http://127.0.0.1:${address.port}`+(data?'/api/action':'/api/state'),{method:data?'POST':'GET',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json','Idempotency-Key':key},...(data?{body:JSON.stringify(data)}:{})});assert.equal(response.status,200);return await response.json() as any;};
 try{
  const address=server.address();assert.ok(address&&typeof address==='object');const r=await fetch(`http://127.0.0.1:${address.port}/api/register`,{method:'POST',body:JSON.stringify({name:'RotaPersistente',starter:'ember'})});const account=await r.json() as any;token=account.token;
  await req({op:'route',region:0});let state=await req({op:'battle',kind:'wild'});
  while(!state.player.battle.result){now+=1000;state=await req({op:'turn',command:'attack'});if(state.player.expedition)assert.equal(state.player.expedition.hp[account.player.team[0]],state.player.battle.allies[0].hp);}
  assert.equal(state.player.battle.result,'win');const hp=state.player.battle.allies[0].hp;assert.ok(hp>0&&hp<state.player.battle.allies[0].stats.hp);assert.equal(state.player.expedition.hp[account.player.team[0]],hp);
  const reward=state.player.battle.rewards;await req({op:'close_battle'});
  await new Promise<void>(resolve=>server.close(()=>resolve()));now+=1000;server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
  const restored=await req();assert.equal(restored.player.collection[0].current_hp,hp);state=await req({op:'battle',kind:'wild'});assert.equal(state.player.battle.allies[0].hp,hp);
  const ended=await req({op:'pause'},'journey_finish_once');assert.equal(ended.player.expedition,null);assert.equal(ended.player.battle,null);const summary=ended.player.last_expedition_summary;assert.equal(summary.outcome,'returned');assert.equal(summary.battles,2);assert.equal(summary.kills,1);assert.equal(summary.gold,reward.gold);assert.deepEqual(summary.items,reward.items);
  assert.deepEqual((await req({op:'pause'},'journey_finish_once')).player.last_expedition_summary,summary);assert.deepEqual((await req({op:'pause'})).player.last_expedition_summary,summary);
  const fresh=await req({op:'route',region:0});assert.notEqual(fresh.player.expedition.id,summary.id);assert.equal(fresh.player.collection[0].current_hp,fresh.player.collection[0].stats.hp);assert.equal(fresh.player.gold,ended.player.gold);
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));rmSync(directory,{recursive:true,force:true});}
});
test('aprimoramento sobrevive no SQLite e conclui após reinício sem conceder XP offline',async()=>{
 const directory=mkdtempSync(join(tmpdir(),'taskmon-timer-')),file=join(directory,'save.sqlite');let now=1000000;
 let server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');let token='';
 const req=async(op?:Record<string,unknown>)=>{const address=server.address();assert.ok(address&&typeof address==='object');const response=await fetch(`http://127.0.0.1:${address.port}`+(op?'/api/action':'/api/state'),{method:op?'POST':'GET',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json','Idempotency-Key':randomBytes(10).toString('hex')},...(op?{body:JSON.stringify(op)}:{})});assert.equal(response.status,200);return await response.json() as any;};
 try{
  const address=server.address();assert.ok(address&&typeof address==='object');const response=await fetch(`http://127.0.0.1:${address.port}/api/register`,{method:'POST',body:JSON.stringify({name:'Persistente',starter:'ember'})});const account=await response.json() as any;token=account.token;
  let state=await req({op:'battle',kind:'wild'});while(!state.player.battle.result)state=await req({op:'turn',command:'auto'});await req({op:'close_battle'});
  const started=await req({op:'upgrade',id:account.player.team[0]});const xp=started.player.collection[0].xp,gs=started.player.gear_score;
  await new Promise<void>(resolve=>server.close(()=>resolve()));now+=60001;
  server=createGameServer({dataPath:file,clock:()=>now});server.listen(0,'127.0.0.1');await once(server,'listening');
  const restored=(await req()).player;assert.equal(restored.collection[0].upgrade,1);assert.equal(restored.collection[0].xp,xp);assert.ok(restored.gear_score>gs);assert.equal(restored.collection[0].upgrade_job,undefined);
 }finally{await new Promise<void>(resolve=>server.close(()=>resolve()));rmSync(directory,{recursive:true,force:true});}
});
