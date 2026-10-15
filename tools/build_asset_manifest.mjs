// Canonical asset inventory: hashes identify the approved version of each asset.
import {readFileSync,readdirSync,writeFileSync,statSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,relative,join} from 'node:path';
const root=resolve(new URL('..',import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1'));
const canonical={
 'ember-locomotion-v2.png':'Historical ordinary-fox poses; superseded by authored botanical ember monster rig',
 'ember-attack.png':'Historical ordinary-fox attack poses; superseded in production',
 'ember-taskmon.png':'Fagulim redesigned botanical ember monster: canonical concept and portrait, user-requested redesign pending artistic review',
 'ember-parts.png':'Fagulim redesigned twelve authored rig parts: botanical leaf armor and seedpod ember tail',
 'creatures-taskmon.png':'Collection atlas: five active identities plus historical ordinary-fox ember reference',
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
