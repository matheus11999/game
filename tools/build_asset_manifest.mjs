// Canonical asset inventory: hashes identify the approved version of each asset.
import {readFileSync,readdirSync,writeFileSync,statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,relative,join} from 'node:path';
const root=resolve(new URL('..',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'));
const canonical={
 'ember-locomotion-v2.png':'Fagulim canonical 4x3 RGBA sheet: upright, eight walk phases, rise/sit, blink, hurt',
 'ember-attack.png':'Fagulim four authored attack poses, 2x2 RGBA sheet',
 'creatures-taskmon.png':'Six collection species, approved 3x2 RGBA atlas',
 'enemies.png':'Nine enemy species, original RGBA atlas',
 'world-forest.png':'Lantern Forest high-resolution illustrated background',
 'world-coast.png':'Glass Coast high-resolution illustrated background',
 'world-ruins.png':'Moon Ruins high-resolution illustrated background',
 'ground-taskmon.png':'Detailed terrain, three biome strips',
};
const files=[];
function scan(dir){for(const entry of readdirSync(dir,{withFileTypes:true})){const path=join(dir,entry.name);if(entry.isDirectory())scan(path);else if(/\.(png|svg|wav|ttf)$/.test(entry.name)){const data=readFileSync(path);const record={path:relative(root,path).replaceAll('\\','/'),sha256:createHash('sha256').update(data).digest('hex'),bytes:statSync(path).size};if(entry.name.endsWith('.png')){record.width=data.readUInt32BE(16);record.height=data.readUInt32BE(20);}if(canonical[entry.name])record.role=canonical[entry.name];files.push(record);}}}
scan(join(root,'assets'));files.sort((a,b)=>a.path.localeCompare(b.path));writeFileSync(join(root,'assets','art-manifest.json'),JSON.stringify({version:1,game:'TaskMon',instruction:'Consult docs/ASSET_REGISTRY.md before generating images. Reuse stable material icons and species identities. Procedural-world experiment is disabled.',canonical,files},null,2)+'\n');
console.log(`Recorded ${files.length} asset hashes`);
