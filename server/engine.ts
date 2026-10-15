import { readFileSync } from 'node:fs';
import { randomBytes, randomInt } from 'node:crypto';
import { migrate, materials, upgradeCost, inventoryCost, grantLoot, completeUpgrades, goldToMilli, goldFromMilli, changeGoldMilli } from './progression.ts';

export interface Stats { hp:number; attack:number; defense:number; speed:number }
export interface Species { id:string; name:string; role:string; element:string; description:string; sprite:number; sprite_atlas?:string; color?:string; boss?:boolean; starter:boolean; base:Stats; passive?:{name:string;stat:keyof Stats;power:number;description:string}; skill:{name:string;kind:string;power:number;cooldown:number;description:string} }
export interface Region { id:number; name:string; level:number; boss_level:number; gold:number; xp:number; pool:string[]; boss:string }
export interface Creature { id:string; species:string; level:number; xp:number; rarity:string; shiny:boolean; iv:Stats; upgrade?:number; upgrade_job?:{target:number;started_at:number;ready_at:number} }
export interface Fighter { id:string; species:string; name:string; side:string; stats:Stats; hp:number; shield:number; cooldown:number; shiny:boolean; upgrade?:number; level?:number }
export interface CombatEvent { actor:string; target:string; species:string; kind:'attack'|'heal'|'shield'|'guard'; value:number; skill:boolean; critical?:boolean }
export interface BattleRewards { gold:number; xp:number; items:Record<string,number>; defeated?:{id:string;species:string;level:number;xp:number}[]; xp_by_creature?:Record<string,number> }
export interface Battle { id?:string; kind:string; region:number; opponent?:string; seed:number; round:number; allies:Fighter[]; enemies:Fighter[]; messages:string[]; events?:CombatEvent[]; result:string|null; rated:boolean; rewarded?:boolean; rewards?:BattleRewards; expedition_id?:string }
export interface ExpeditionTotals { gold:number; xp:number; enemy_xp:number; xp_by_creature:Record<string,number>; items:Record<string,number>; kills:number; battles:number }
export interface Expedition { last:number; ticks:number; id?:string; started_at?:number; region?:number; hp?:Record<string,number>; totals?:ExpeditionTotals }
export interface ExpeditionSummary extends ExpeditionTotals { id:string; region:number; name:string; started_at:number; ended_at:number; duration:number; duration_seconds:number; duration_ms:number; outcome:'defeat'|'returned'|'changed_route' }
export interface Player { id:string; name:string; gold:number; collection:Creature[]; team:string[]; region:number; unlocked:number; expedition:Expedition|null; last_expedition_summary?:ExpeditionSummary; battle:Battle|null; rating:number; wins:number; losses:number; bosses:number[]; log:string[]; last_duels:Record<string,number>; created:number; distance?:number; encounters?:number; inventory?:Record<string,number>; pending_loot?:Record<string,number>; inventory_capacity?:number; loot_day?:string; pvp_loot_wins?:number; active_until?:number }

export const catalogue=JSON.parse(readFileSync(new URL('../assets/species.json',import.meta.url),'utf8')) as {species:Species[];regions:Region[];rarities:{id:string;name:string;weight:number;bonus:number;color:string}[]};
export const enemyCatalogue=JSON.parse(readFileSync(new URL('../assets/enemies.json',import.meta.url),'utf8')) as {species:Species[]};
export const speciesById=new Map([...catalogue.species,...enemyCatalogue.species].map(s=>[s.id,s]));
export const regionEnemies=[
  {wild:['thornbud','pebblebug'],boss:'rootelder'},
  {wild:['reefclaw','tidejelly'],boss:'abyssmaw'},
  {wild:['runewisp','shardguard'],boss:'moonwarden'}
];
export const TICK_MS=20_000;
export const AFK_CAP=8*60*60*1000;
export function species(id:string):Species { const s=speciesById.get(id);if(!s)throw new Error('Criatura desconhecida.');return s; }
export function stats(c:Creature,normalized=false):Stats {
  const spec=species(c.species);const base=spec.base;const rank=normalized?0:(c.upgrade??0);
  const level=normalized?5:c.level;
  const rarity=normalized?1:(catalogue.rarities.find(r=>r.id===c.rarity)?.bonus??1);
  return Object.fromEntries(Object.entries(base).map(([k,v])=>[k,Math.round(v*(1+0.075*(level-1))*rarity*(1+rank*0.04)*(spec.passive?.stat===k?1+spec.passive.power+rank*0.01:1)*(normalized?1:0.94+c.iv[k as keyof Stats]*0.008))])) as unknown as Stats;
}
export function makeCreature(id:string,starter=false):Creature {
  species(id);
  let rarity='common';
  if(!starter){let roll=randomInt(100);for(const r of catalogue.rarities){roll-=r.weight;if(roll<0){rarity=r.id;break;}}}
  return {id:randomBytes(8).toString('hex'),species:id,level:1,xp:0,upgrade:0,rarity,shiny:!starter&&randomInt(100)<3,iv:{hp:starter?8:randomInt(16),attack:starter?8:randomInt(16),defense:starter?8:randomInt(16),speed:starter?8:randomInt(16)}};
}
export function makePlayer(name:string,starter:string,now=Date.now()):Player {
  if(!species(starter).starter)throw new Error('Escolha uma criatura inicial.');
  const c=makeCreature(starter,true);
  return {id:randomBytes(5).toString('hex'),name,gold:30,collection:[c],team:[c.id],region:0,unlocked:0,expedition:null,battle:null,rating:1000,wins:0,losses:0,bosses:[],log:['Bem-vindo à caravana. Escolha uma rota e parta!'],last_duels:{},created:now,distance:0,encounters:0};
}
export function log(p:Player,line:string):void {p.log.unshift(line);p.log=p.log.slice(0,16);}
export function addXp(c:Creature,amount:number):void {
  if(c.level>=20){c.xp=0;return;}
  c.xp+=amount;
  while(c.level<20&&c.xp>=c.level*40){c.xp-=c.level*40;c.level++;}
  if(c.level>=20)c.xp=0;
}
function ensureExpedition(p:Player,now:number):Expedition|null {
  const e=p.expedition;if(!e)return null;
  e.id??=randomBytes(8).toString('hex');e.started_at??=Math.min(now,e.last);e.region??=p.region;e.hp??={};
  e.totals??={gold:0,xp:0,enemy_xp:0,xp_by_creature:{},items:{},kills:0,battles:0};
  for(const c of p.collection)if(e.hp[c.id]!==undefined)e.hp[c.id]=Math.max(0,Math.min(stats(c).hp,e.hp[c.id]));
  for(const id of p.team){const c=p.collection.find(c=>c.id===id);if(c)e.hp[id]=Math.max(0,Math.min(stats(c).hp,e.hp[id]??stats(c).hp));}
  if(p.battle&&['wild','boss'].includes(p.battle.kind)&&!p.battle.expedition_id){p.battle.expedition_id=e.id;syncExpeditionBattle(p,p.battle);}
  return e;
}
export function startExpedition(p:Player,region:number,now=Date.now()):void {
  if(p.battle)throw new Error('Conclua a batalha antes de trocar de rota.');
  if(p.expedition)endExpedition(p,'changed_route',now);
  p.region=region;p.expedition={last:now,ticks:0,id:randomBytes(8).toString('hex'),started_at:now,region,hp:{}};
  ensureExpedition(p,now);log(p,`Expedição iniciada: ${catalogue.regions[region].name}.`);
}
export function syncExpeditionBattle(p:Player,b:Battle):void {
  const e=p.expedition;if(!e||!b.expedition_id||e.id!==b.expedition_id)return;
  e.hp??={};
  for(const ally of b.allies){const c=p.collection.find(c=>c.id===ally.id);if(c)e.hp[ally.id]=Math.max(0,Math.min(stats(c).hp,ally.hp));}
}
export function endExpedition(p:Player,outcome:ExpeditionSummary['outcome']='returned',now=Date.now()):ExpeditionSummary|undefined {
  const e=ensureExpedition(p,now);if(!e)return p.last_expedition_summary;
  const durationMs=Math.max(0,now-e.started_at!);
  p.last_expedition_summary={...structuredClone(e.totals!),id:e.id!,region:e.region!,name:catalogue.regions[e.region!].name,started_at:e.started_at!,ended_at:now,duration:Math.floor(durationMs/1000),duration_seconds:Math.floor(durationMs/1000),duration_ms:durationMs,outcome};
  p.expedition=null;
  log(p,outcome==='defeat'?'A equipe caiu. Expedição encerrada.':'Expedição encerrada. Os recursos coletados foram preservados.');
  return p.last_expedition_summary;
}
export function returnFromExpedition(p:Player,now=Date.now()):void {
  const b=p.battle;
  if(b?.expedition_id&&b.expedition_id===p.expedition?.id){
    if(!b.result){b.result='loss';finishBattle(p,b,now);}
    else syncExpeditionBattle(p,b);
    p.battle=null;
  }
  endExpedition(p,'returned',now);
}
export function settle(p:Player,now=Date.now()):void {
  migrate(p);completeUpgrades(p,now);
  if(!p.expedition)return;
  ensureExpedition(p,now);
  const activeUntil=p.active_until??0;
  const elapsed=Math.max(0,Math.min(now,activeUntil)-p.expedition.last);
  const ticks=Math.floor(Math.min(elapsed,AFK_CAP)/TICK_MS);
  if(ticks<=0){if(now>activeUntil)p.expedition.last=now;return;}
  const region=catalogue.regions[p.region];
  const before=p.expedition.ticks;
  p.expedition.ticks+=ticks;
  p.expedition.last=elapsed>AFK_CAP?now: p.expedition.last+ticks*TICK_MS;
  const discoveries=Math.floor(p.expedition.ticks/3)-Math.floor(before/3);
  let found=0;
  const availableDiscoveries=Math.min(discoveries,80-p.collection.length);
  for(let i=0;i<availableDiscoveries;i++){
    const c=makeCreature(region.pool[randomInt(region.pool.length)]);p.collection.push(c);found++;
    if(p.team.length<3)p.team.push(c.id);
    log(p,`${species(c.species).name} ${c.shiny?'✦ luminoso ':''}encontrado! ${catalogue.rarities.find(r=>r.id===c.rarity)?.name}.`);
  }
  ensureExpedition(p,now);
  if(now>activeUntil)p.expedition.last=now;
  if(ticks>1&&found)log(p,`Expedição: ${found} descoberta(s).`);
}
export function heartbeat(p:Player,now=Date.now()):void {
  settle(p,now);
  // An older saved result can predate expedition HP persistence. Reconcile a
  // completed wipe without paying its already-credited rewards again.
  if(p.expedition&&p.battle?.result&&p.battle.expedition_id===p.expedition.id&&p.battle.allies.every(a=>a.hp<=0)){
    if(!p.battle.rewarded)finishBattle(p,p.battle,now);else endExpedition(p,'defeat',now);
  }
  p.active_until=now+8000;
}
export function gearScore(c:Creature):number {const st=stats(c);return Math.round(st.hp*0.35+st.attack*2+st.defense*1.5+st.speed);}
export function achievements(p:Player):{id:string;name:string;description:string;progress:number;target:number;unlocked:boolean}[]{
 const list:[string,string,string,number,number][]=[['first','Primeiro passo','Vença um encontro PvE',p.encounters??0,1],['trail','Desbravador','Percorra 1200 metros',p.distance??0,1200],['collector','Companheiros','Colecione 6 criaturas',p.collection.length,6],['guardian','Quebra-guardião','Vença os 3 chefes',p.bosses.length,3],['arena','Duelista','Vença 5 duelos',p.wins,5],['craft','Artífice','Conclua um aprimoramento',Math.max(...p.collection.map(c=>c.upgrade??0)),1],['master','Veterano','Alcance nível 10',Math.max(...p.collection.map(c=>c.level)),10]];
 return list.map(([id,name,description,progress,target])=>({id,name,description,progress:Math.min(progress,target),target,unlocked:progress>=target}));
}
export function view(p:Player,now=Date.now()):Record<string,unknown> {
  migrate(p);ensureExpedition(p,now);return {...p,gear_score:p.team.reduce((sum,id)=>{const c=p.collection.find(c=>c.id===id);return sum+(c?gearScore(c):0);},0),achievements:achievements(p),inventory_cost:inventoryCost(p),materials_catalogue:materials,distance:p.distance??0,encounters:p.encounters??0,collection:p.collection.map(c=>({...c,current_hp:p.expedition?.hp?.[c.id]??stats(c).hp,upgrade:c.upgrade??0,gear_score:gearScore(c),upgrade_cost:upgradeCost(c),stats:stats(c),next_xp:c.level*40})),server_time:now,afk_open_only:true,presence_grace_seconds:8,afk_cap_hours:0,tick_seconds:20,next_tick:p.expedition?Math.max(0,Math.ceil((p.expedition.last+TICK_MS-now)/1000)):0};
}
function fighter(c:Creature,side:string,normalized=false):Fighter {const st=stats(c,normalized);return {id:c.id,species:c.species,name:species(c.species).name,side,stats:st,hp:st.hp,shield:0,cooldown:0,shiny:c.shiny,upgrade:normalized?0:(c.upgrade??0),level:normalized?5:c.level};}
function rng(b:Battle):number {let x=b.seed|0;x^=x<<13;x^=x>>>17;x^=x<<5;b.seed=x>>>0;return b.seed/4294967296;}
export function beginBattle(p:Player,kind:string,opponent?:Player):Battle {
  if(p.battle)throw new Error('Conclua a batalha atual.');
  const region=catalogue.regions[p.region];
  const allies=p.team.map(id=>p.collection.find(c=>c.id===id)).filter((c):c is Creature=>!!c).map(c=>fighter(c,'ally',kind==='duel'||kind==='training'));
  if(!allies.length)throw new Error('Selecione uma equipe.');
  const expedition=['wild','boss'].includes(kind)?ensureExpedition(p,Date.now()):null;
  if(expedition){for(const ally of allies)ally.hp=expedition.hp![ally.id];if(allies.every(a=>a.hp<=0))throw new Error('Equipe sem vida. Inicie uma nova expedição.');}
  let enemies:Fighter[];
  if(opponent){enemies=opponent.team.map(id=>opponent.collection.find(c=>c.id===id)).filter((c):c is Creature=>!!c).map(c=>fighter(c,'enemy',true));}
  else{
    const count=kind==='boss'||kind==='training'?3:Math.min(3,Math.max(1,p.region+1));
    enemies=Array.from({length:count},(_,i)=>{
      const encounter=regionEnemies[p.region];
      const id=kind==='training'?catalogue.species[(i+1)%3].id:kind==='boss'&&i===0?encounter.boss:encounter.wild[kind==='wild'?randomInt(encounter.wild.length):(i-1+encounter.wild.length)%encounter.wild.length];
      const c=makeCreature(id,true);c.level=kind==='boss'?region.boss_level:region.level;
      return fighter(c,'enemy',kind==='training');
    });
  }
  p.battle={id:randomBytes(8).toString('hex'),kind,region:p.region,opponent:opponent?.id,seed:randomInt(1,0x7fffffff),round:0,allies,enemies,messages:[kind==='boss'?`${region.boss} bloqueia o caminho!`:kind==='duel'?`Desafio contra ${opponent?.name}. Poder normalizado.`:'Sua equipe encontrou um desafio!'],events:[],result:null,rated:kind==='duel',...(expedition?{expedition_id:expedition.id}:{})};
  return p.battle;
}
function living(units:Fighter[]):Fighter[]{return units.filter(u=>u.hp>0);}
export function turn(b:Battle,command:string):void {
  if(b.result)throw new Error('A batalha já terminou.');
  if(!['attack','skill','guard','auto'].includes(command))throw new Error('Comando inválido.');
  b.round++;b.messages=[];b.events=[];
  const order=[...living(b.allies),...living(b.enemies)].sort((a,c)=>c.stats.speed-a.stats.speed);
  for(const actor of order){
    if(actor.hp<=0)continue;
    const friends=living(actor.side==='ally'?b.allies:b.enemies);
    const foes=living(actor.side==='ally'?b.enemies:b.allies);
    if(!foes.length||!friends.length)break;
    const original=species(actor.species).skill;const skill={...original,power:original.power*(1+(actor.upgrade??0)*0.03)};
    const lowest=[...friends].sort((a,c)=>a.hp/a.stats.hp-c.hp/c.stats.hp)[0];
    const automatic=actor.side==='enemy'||command==='auto';
    const useSkill=actor.cooldown===0&&(automatic?(skill.kind!=='heal'||lowest.hp<lowest.stats.hp*0.8):command==='skill');
    if(actor.cooldown>0)actor.cooldown--;
    if(actor.side==='ally'&&command==='guard'){
      const before=actor.shield;
      actor.shield=Math.min(actor.stats.hp*0.6,actor.shield+Math.round(actor.stats.hp*0.18));
      b.events.push({actor:actor.id,target:actor.id,species:actor.species,kind:'guard',value:actor.shield-before,skill:false});
      b.messages.push(`${actor.name} se protege.`);continue;
    }
    if(useSkill&&skill.kind==='heal'){
      const amount=Math.min(lowest.stats.hp-lowest.hp,Math.round(lowest.stats.hp*skill.power));lowest.hp+=amount;
      b.events.push({actor:actor.id,target:lowest.id,species:actor.species,kind:'heal',value:amount,skill:true});
      actor.cooldown=skill.cooldown;b.messages.push(`${actor.name}: ${skill.name}, +${amount} vida em ${lowest.name}.`);continue;
    }
    if(useSkill&&skill.kind==='shield'){
      for(const friend of friends){
        const before=friend.shield;
        friend.shield=Math.min(Math.round(friend.stats.hp*0.6),friend.shield+Math.round(friend.stats.hp*skill.power));
        b.events.push({actor:actor.id,target:friend.id,species:actor.species,kind:'shield',value:friend.shield-before,skill:true});
      }
      actor.cooldown=skill.cooldown;b.messages.push(`${actor.name}: ${skill.name} protege a equipe.`);continue;
    }
    const tank=foes.find(x=>species(x.species).role==='Tanque');
    const target=tank&&rng(b)<0.6?tank:foes[Math.floor(rng(b)*foes.length)];
    const crit=rng(b)<0.1;
    const damage=Math.max(3,Math.round((actor.stats.attack*(useSkill?skill.power:1)*(crit?1.35:1)-target.stats.defense*0.48)*(0.94+rng(b)*0.12)));
    const absorbed=Math.min(target.shield,damage);target.shield-=absorbed;target.hp=Math.max(0,target.hp-damage+absorbed);
    if(useSkill)actor.cooldown=skill.cooldown;
    b.events.push({actor:actor.id,target:target.id,species:actor.species,kind:'attack',value:damage-absorbed,skill:useSkill,critical:crit});
    b.messages.push(`${actor.name} ${useSkill?skill.name:'ataca'} → ${target.name}: ${damage-absorbed}${crit?' crítico':''}${absorbed?` (${absorbed} bloqueado)`:''}.`);
  }
  if(!living(b.enemies).length)b.result='win';
  else if(!living(b.allies).length)b.result='loss';
  else if(b.round>=60){
    const score=(units:Fighter[])=>units.reduce((sum,u)=>sum+u.hp/u.stats.hp,0)/units.length;
    b.result=score(b.allies)>score(b.enemies)?'win':'loss';b.messages.push('Limite de turnos: decide a vida proporcional restante.');
  }
}
/** Enemy progression uses immutable server-side fighter snapshots, never client
 * payloads. Legacy saved battles infer level from their authoritative region. */
export function defeatedEnemyXp(enemy:Fighter,battle:Battle):number {
  const spec=species(enemy.species);
  const region=catalogue.regions[battle.region];
  const level=enemy.level??(battle.rated||battle.kind==='training'?5:battle.kind==='boss'?region.boss_level:region.level);
  const power=enemy.stats.hp*0.35+enemy.stats.attack*2+enemy.stats.defense*1.5+enemy.stats.speed;
  const roleBonus=spec.role==='Tanque'?0.5:spec.role==='Suporte'?0.35:0;
  return Math.max(1,Math.round((2+level*0.6+power/110+roleBonus)*(spec.boss?2.5:1)));
}
function creditDefeatedXp(p:Player,b:Battle):void {
  const rewards=b.rewards!;
  rewards.defeated=b.enemies.filter(e=>e.hp<=0).map(e=>({id:e.id,species:e.species,level:e.level??(b.rated?5:b.kind==='boss'?catalogue.regions[b.region].boss_level:catalogue.regions[b.region].level),xp:defeatedEnemyXp(e,b)}));
  rewards.xp=rewards.defeated.reduce((sum,e)=>sum+e.xp,0);
  rewards.xp_by_creature={};
  for(const id of new Set(b.allies.map(a=>a.id))){
    const c=p.collection.find(c=>c.id===id);
    if(!c)continue;
    const before=(c.level>=20?0:c.xp)+20*c.level*(c.level-1);
    addXp(c,rewards.xp);
    // Level 20 discards overflow; report only XP actually accepted.
    const after=c.level>=20?20*20*19:c.xp+20*c.level*(c.level-1);
    rewards.xp_by_creature[id]=Math.max(0,after-before);
  }
}
export function finishBattle(p:Player,b:Battle,now=Date.now()):void {
  if(!b.result||b.rewarded)return;
  migrate(p);b.rewarded=true;b.rewards={gold:0,xp:0,items:{},defeated:[],xp_by_creature:{}};
  if(b.kind==='duel'&&b.result==='win'){
    const day=new Date(now).toISOString().slice(0,10);if(p.loot_day!==day){p.loot_day=day;p.pvp_loot_wins=0;}
    if(p.pvp_loot_wins!<5){p.pvp_loot_wins!++;creditDefeatedXp(p,b);const kills=b.rewards.defeated!.length;if(kills){b.rewards.gold=goldFromMilli(kills*250);b.rewards.items={essence:kills*2,sigil:1};changeGoldMilli(p,kills*250);grantLoot(p,b.rewards.items);}}
  }
  if(b.kind==='duel'||b.kind==='training'){log(p,`${b.kind==='training'?'Treino':'Duelo'}: ${b.result==='win'?'vitória':'derrota'}.`);return;}
  creditDefeatedXp(p,b);
  const region=catalogue.regions[b.region];
  const defeated=b.rewards.defeated!;
  const killMilli=defeated.reduce((sum,e)=>sum+(125+e.level*35+e.xp*20)*(species(e.species).boss?3:1),0);
  b.rewards.gold=goldFromMilli(killMilli);changeGoldMilli(p,killMilli);
  const items:Record<string,number>={};
  for(const enemy of defeated){
    const boss=species(enemy.species).boss;
    items.essence=(items.essence??0)+(boss?5:2);
    const material=['fibre','pearl','shard'][b.region];items[material]=(items[material]??0)+(boss?8:3);
    if(boss){items.core=(items.core??0)+2;items.sigil=(items.sigil??0)+1;}
  }
  grantLoot(p,items);b.rewards.items=items;
  if(b.result==='win'){
    p.encounters=(p.encounters??0)+1;
    p.distance=(p.distance??0)+(b.kind==='boss'?300:120);
    if(b.kind==='boss'){
      p.unlocked=Math.min(2,Math.max(p.unlocked,b.region+1));
      if(!p.bosses.includes(b.region)){
        p.bosses.push(b.region);
        if(p.collection.length<80)p.collection.push(makeCreature(catalogue.species[(b.region+3)%6].id));
        log(p,`${region.boss} vencido! Nova rota e criatura desbloqueadas.`);
      }
    }
    log(p,`Vitória! +${b.rewards.gold} moedas.`);
  }else log(p,'A caravana recuou. Ajuste sua equipe; nenhuma criatura foi perdida.');
  recordExpeditionResult(p,b,now);
}

function recordExpeditionResult(p:Player,b:Battle,now:number):void {
  const e=ensureExpedition(p,now);
  if(!e||!b.expedition_id||b.expedition_id!==e.id)return;
  syncExpeditionBattle(p,b);
  const total=e.totals!,reward=b.rewards!;
  total.gold=goldFromMilli(goldToMilli(total.gold)+goldToMilli(reward.gold));
  total.enemy_xp+=reward.xp;total.kills+=reward.defeated!.length;total.battles++;
  for(const [id,xp] of Object.entries(reward.xp_by_creature!)){total.xp+=xp;total.xp_by_creature[id]=(total.xp_by_creature[id]??0)+xp;}
  for(const [id,n] of Object.entries(reward.items))total.items[id]=(total.items[id]??0)+n;
  if(b.allies.every(ally=>ally.hp<=0))endExpedition(p,'defeat',now);
}
