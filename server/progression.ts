import { readFileSync } from 'node:fs';
import type { Player, Creature } from './engine.ts';

/** Persisted/API balances stay compatible numbers; arithmetic uses integer
 * thousandths, never repeated binary floating-point coin additions. */
export const GOLD_SCALE=1000;
export function goldToMilli(value:number):number {
  if(!Number.isFinite(value))throw new ProgressionError('Saldo inválido.');
  const milli=Math.round(value*GOLD_SCALE);
  if(!Number.isSafeInteger(milli))throw new ProgressionError('Saldo fora do limite.');
  return milli;
}
export function goldFromMilli(milli:number):number {
  if(!Number.isSafeInteger(milli))throw new ProgressionError('Valor monetário inválido.');
  return milli/GOLD_SCALE;
}
export function changeGoldMilli(player:{gold:number},delta:number):number {
  if(!Number.isSafeInteger(delta))throw new ProgressionError('Variação monetária inválida.');
  const balance=goldToMilli(player.gold)+delta;
  if(!Number.isSafeInteger(balance)||balance<0)throw new ProgressionError('Saldo insuficiente ou fora do limite.');
  player.gold=goldFromMilli(balance);
  return player.gold;
}

export const materials=JSON.parse(readFileSync(new URL('../assets/materials.json',import.meta.url),'utf8')) as {id:string;name:string;color:string;icon:string;source:string}[];
const ids=new Set(materials.map(m=>m.id));
export class ProgressionError extends Error {}
export const MAX_UPGRADE=10;
export function migrate(p:Player):void {
  p.gold=goldFromMilli(goldToMilli(p.gold));
  p.inventory??={};p.pending_loot??={};p.inventory_capacity??=4;p.loot_day??='';p.pvp_loot_wins??=0;
  for(const c of p.collection)c.upgrade??=0;
}
export function grantLoot(p:Player,drops:Record<string,number>):void {
  migrate(p);
  for(const [id,amount] of Object.entries(drops)){
    if(!ids.has(id)||!Number.isSafeInteger(amount)||amount<=0)throw new ProgressionError('Material inválido.');
    const bag=p.inventory!;
    if((bag[id]??0)>0||Object.keys(bag).length<p.inventory_capacity!)bag[id]=(bag[id]??0)+amount;
    else p.pending_loot![id]=(p.pending_loot![id]??0)+amount;
  }
}
export function claimLoot(p:Player):void {
  migrate(p);const pending={...p.pending_loot};p.pending_loot={};grantLoot(p,pending);
}
export function inventoryCost(p:Player):number {return 60+(p.inventory_capacity!-4)*40;}
export function expandInventory(p:Player):void {
  migrate(p);if(p.battle)throw new ProgressionError('Expanda fora do combate.');
  if(p.inventory_capacity!>=20)throw new ProgressionError('Inventário no limite.');
  const cost=inventoryCost(p);if(p.gold<cost)throw new ProgressionError(`São necessárias ${cost} moedas.`);
  changeGoldMilli(p,-goldToMilli(cost));p.inventory_capacity!+=2;claimLoot(p);
}
const affinity:Record<string,string>={ember:'fibre',moss:'fibre',luna:'shard',tide:'pearl',crag:'shard',cloud:'pearl'};
export function upgradeCost(c:Creature):{gold:number;level:number;seconds:number;materials:Record<string,number>} {
  const rank=c.upgrade??0;
  const cost:Record<string,number>={essence:2+rank,[rank<3?'fibre':(affinity[c.species]??'fibre')]:3+rank*2};
  if(rank>=3)cost.core=1+Math.floor(rank/3);
  if(rank>=6)cost.sigil=1;
  return {gold:20+rank*25,level:1+rank*2,seconds:60*(rank+1)**2,materials:cost};
}
export function completeUpgrades(p:Player,now:number):void {
  for(const c of p.collection){
    if(c.upgrade_job&&now>=c.upgrade_job.ready_at){c.upgrade=c.upgrade_job.target;delete c.upgrade_job;}
  }
}
export function upgradeCreature(p:Player,id:unknown,now=Date.now()):void {
  migrate(p);if(p.battle)throw new ProgressionError('Aprimore fora do combate.');
  const c=p.collection.find(c=>c.id===id);if(!c)throw new ProgressionError('Criatura não encontrada.');
  if(c.upgrade!>=MAX_UPGRADE)throw new ProgressionError('Aprimoramento máximo.');
  if(c.upgrade_job)throw new ProgressionError('Esta criatura já está aprimorando.');
  const cost=upgradeCost(c);
  if(c.level<cost.level)throw new ProgressionError(`Requer nível ${cost.level}. Ganhe XP em jogo.`);
  if(p.gold<cost.gold)throw new ProgressionError(`São necessárias ${cost.gold} moedas.`);
  if(Object.entries(cost.materials).some(([id,n])=>(p.inventory![id]??0)<n))throw new ProgressionError('Materiais insuficientes. Vença batalhas para coletar.');
  changeGoldMilli(p,-goldToMilli(cost.gold));
  for(const [id,n] of Object.entries(cost.materials)){p.inventory![id]-=n;if(p.inventory![id]===0)delete p.inventory![id];}
  c.upgrade_job={target:c.upgrade!+1,started_at:now,ready_at:now+cost.seconds*1000};claimLoot(p);
}
