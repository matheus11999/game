import { readFileSync } from 'node:fs';
import { randomBytes, randomInt } from 'node:crypto';

export interface Stats { hp:number; attack:number; defense:number; speed:number }
export interface Species { id:string; name:string; role:string; element:string; description:string; sprite:number; sprite_atlas?:string; color?:string; boss?:boolean; starter:boolean; base:Stats; skill:{name:string;kind:string;power:number;cooldown:number;description:string} }
export interface Region { id:number; name:string; level:number; boss_level:number; gold:number; xp:number; pool:string[]; boss:string }
export interface Creature { id:string; species:string; level:number; xp:number; rarity:string; shiny:boolean; iv:Stats }
export interface Fighter { id:string; species:string; name:string; side:string; stats:Stats; hp:number; shield:number; cooldown:number; shiny:boolean }
export interface CombatEvent { actor:string; target:string; species:string; kind:'attack'|'heal'|'shield'|'guard'; value:number; skill:boolean; critical?:boolean }
export interface Battle { kind:string; region:number; opponent?:string; seed:number; round:number; allies:Fighter[]; enemies:Fighter[]; messages:string[]; events?:CombatEvent[]; result:string|null; rated:boolean }
export interface Player { id:string; name:string; gold:number; collection:Creature[]; team:string[]; region:number; unlocked:number; expedition:{last:number;ticks:number}|null; battle:Battle|null; rating:number; wins:number; losses:number; bosses:number[]; log:string[]; last_duels:Record<string,number>; created:number; distance?:number; encounters?:number }

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
  const base=species(c.species).base;
  const level=normalized?5:c.level;
  const rarity=normalized?1:(catalogue.rarities.find(r=>r.id===c.rarity)?.bonus??1);
  return Object.fromEntries(Object.entries(base).map(([k,v])=>[k,Math.round(v*(1+0.075*(level-1))*rarity*(normalized?1:0.94+c.iv[k as keyof Stats]*0.008))])) as unknown as Stats;
}
export function makeCreature(id:string,starter=false):Creature {
  species(id);
  let rarity='common';
  if(!starter){let roll=randomInt(100);for(const r of catalogue.rarities){roll-=r.weight;if(roll<0){rarity=r.id;break;}}}
  return {id:randomBytes(8).toString('hex'),species:id,level:1,xp:0,rarity,shiny:!starter&&randomInt(100)<3,iv:{hp:starter?8:randomInt(16),attack:starter?8:randomInt(16),defense:starter?8:randomInt(16),speed:starter?8:randomInt(16)}};
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
export function settle(p:Player,now=Date.now()):void {
  if(!p.expedition)return;
  const elapsed=Math.max(0,now-p.expedition.last);
  const ticks=Math.floor(Math.min(elapsed,AFK_CAP)/TICK_MS);
  if(ticks<=0)return;
  const region=catalogue.regions[p.region];
  const before=p.expedition.ticks;
  p.expedition.ticks+=ticks;
  p.expedition.last=elapsed>AFK_CAP?now: p.expedition.last+ticks*TICK_MS;
  p.gold+=ticks*region.gold;
  for(const id of p.team){const c=p.collection.find(x=>x.id===id);if(c)addXp(c,ticks*region.xp);}
  const discoveries=Math.floor(p.expedition.ticks/3)-Math.floor(before/3);
  let found=0;
  const availableDiscoveries=Math.min(discoveries,80-p.collection.length);
  for(let i=0;i<availableDiscoveries;i++){
    const c=makeCreature(region.pool[randomInt(region.pool.length)]);p.collection.push(c);found++;
    if(p.team.length<3)p.team.push(c.id);
    log(p,`${species(c.species).name} ${c.shiny?'✦ luminoso ':''}encontrado! ${catalogue.rarities.find(r=>r.id===c.rarity)?.name}.`);
  }
  if(ticks>1)log(p,`Retorno AFK: +${ticks*region.gold} moedas, +${ticks*region.xp} XP por membro${found?`, ${found} descoberta(s)`:''}.`);
}
export function view(p:Player,now=Date.now()):Record<string,unknown> {
  return {...p,distance:p.distance??0,encounters:p.encounters??0,collection:p.collection.map(c=>({...c,stats:stats(c),next_xp:c.level*40})),server_time:now,afk_cap_hours:8,tick_seconds:20,next_tick:p.expedition?Math.max(0,Math.ceil((p.expedition.last+TICK_MS-now)/1000)):0};
}
function fighter(c:Creature,side:string,normalized=false):Fighter {const st=stats(c,normalized);return {id:c.id,species:c.species,name:species(c.species).name,side,stats:st,hp:st.hp,shield:0,cooldown:0,shiny:c.shiny};}
function rng(b:Battle):number {let x=b.seed|0;x^=x<<13;x^=x>>>17;x^=x<<5;b.seed=x>>>0;return b.seed/4294967296;}
export function beginBattle(p:Player,kind:string,opponent?:Player):Battle {
  if(p.battle)throw new Error('Conclua a batalha atual.');
  const region=catalogue.regions[p.region];
  const allies=p.team.map(id=>p.collection.find(c=>c.id===id)).filter((c):c is Creature=>!!c).map(c=>fighter(c,'ally',kind==='duel'||kind==='training'));
  if(!allies.length)throw new Error('Selecione uma equipe.');
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
  p.battle={kind,region:p.region,opponent:opponent?.id,seed:randomInt(1,0x7fffffff),round:0,allies,enemies,messages:[kind==='boss'?`${region.boss} bloqueia o caminho!`:kind==='duel'?`Desafio contra ${opponent?.name}. Poder normalizado.`:'Sua equipe encontrou um desafio!'],events:[],result:null,rated:kind==='duel'};
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
    const skill=species(actor.species).skill;
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
export function finishBattle(p:Player,b:Battle):void {
  if(!b.result)return;
  if(b.kind==='duel'||b.kind==='training'){log(p,`${b.kind==='training'?'Treino':'Duelo'}: ${b.result==='win'?'vitória':'derrota'}.`);return;}
  const region=catalogue.regions[b.region];
  if(b.result==='win'){
    p.encounters=(p.encounters??0)+1;
    p.distance=(p.distance??0)+(b.kind==='boss'?300:120);
    const reward=b.kind==='boss'?region.gold*30:region.gold*5;p.gold+=reward;
    for(const id of p.team){const c=p.collection.find(x=>x.id===id);if(c)addXp(c,b.kind==='boss'?45:15);}
    if(b.kind==='boss'){
      p.unlocked=Math.min(2,Math.max(p.unlocked,b.region+1));
      if(!p.bosses.includes(b.region)){
        p.bosses.push(b.region);
        if(p.collection.length<80)p.collection.push(makeCreature(catalogue.species[(b.region+3)%6].id));
        log(p,`${region.boss} vencido! Nova rota e criatura desbloqueadas.`);
      }
    }
    log(p,`Vitória! +${reward} moedas.`);
  }else log(p,'A caravana recuou. Treine e ajuste sua equipe; nenhuma criatura foi perdida.');
}
