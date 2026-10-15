// Deterministic, original sound synthesis. No third-party samples.
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
const root=new URL('../assets/audio/',import.meta.url);mkdirSync(root,{recursive:true});
const all=[...JSON.parse(readFileSync(new URL('../assets/species.json',import.meta.url))).species,...JSON.parse(readFileSync(new URL('../assets/enemies.json',import.meta.url))).species];
const profiles={ember:[220,'fire'],moss:[145,'wood'],luna:[660,'chime'],tide:[390,'water'],crag:[310,'crystal'],cloud:[520,'wind'],thornbud:[175,'wood'],pebblebug:[115,'crystal'],reefclaw:[270,'water'],tidejelly:[470,'water'],runewisp:[740,'chime'],shardguard:[350,'crystal'],rootelder:[92,'wood'],abyssmaw:[130,'water'],moonwarden:[580,'chime']};
const sr=22050,pi=Math.PI;
for(const creature of all)for(const type of ['attack','skill','impact']){
 const [freq,flavor]=profiles[creature.id];const skill=type==='skill',impact=type==='impact';const duration=impact?.17:skill?.72:.32;
 const count=Math.ceil(sr*duration),pcm=Buffer.alloc(count*2);let phase=0,seed=creature.sprite*1337+19,low=0;
 for(let i=0;i<count;i++){
  const t=i/sr,u=t/duration;seed=(seed*1664525+1013904223)>>>0;const noise=seed/2147483648-1;low=low*.82+noise*.18;
  const attack=Math.min(1,t/(impact?.004:.018)),env=attack*Math.pow(1-u,impact?2:skill?1.6:2.6);
  const f=freq*(impact?.55:1)*(1+ (skill?.65:.3)*Math.exp(-t*12))*(flavor==='water'?1+Math.sin(t*30)*.12:1);phase+=f*2*pi/sr;
  let sample=0;
  if(flavor==='fire')sample=Math.sin(phase)*.35+low*.9+Math.sin(phase*2.03)*.08;
  if(flavor==='wood')sample=Math.sin(phase)*.58+Math.sin(phase*1.52)*.25*Math.exp(-t*8)+low*.35;
  if(flavor==='chime')sample=Math.sin(phase)*.4+Math.sin(phase*2)*.2+Math.sin(phase*3.01)*.12;
  if(flavor==='water')sample=Math.sin(phase+Math.sin(t*37)*1.5)*.55+low*.3;
  if(flavor==='crystal')sample=Math.sin(phase)*.36+Math.sin(phase*2.76)*.28*Math.exp(-t*4)+Math.sin(phase*4.1)*.12;
  if(flavor==='wind')sample=low*.65+Math.sin(phase)*.25+Math.sin(phase*1.5)*.15;
  if(skill){const swell=Math.sin(pi*u);sample+=Math.sin(phase*.5)*.2*swell+Math.sin(phase*1.25)*.12*swell;}
  if(impact)sample=sample*.4+low*.65;
  pcm.writeInt16LE(Math.round(Math.tanh(sample*1.1)*env*14000),i*2);
 }
 const header=Buffer.alloc(44);header.write('RIFF');header.writeUInt32LE(36+pcm.length,4);header.write('WAVEfmt ',8);header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(1,22);header.writeUInt32LE(sr,24);header.writeUInt32LE(sr*2,28);header.writeUInt16LE(2,32);header.writeUInt16LE(16,34);header.write('data',36);header.writeUInt32LE(pcm.length,40);
 writeFileSync(new URL(`${creature.id}_${type}.wav`,root),Buffer.concat([header,pcm]));
}
writeFileSync(new URL('../assets/audio/manifest.json',import.meta.url),JSON.stringify({generator:'tools/make_audio.mjs',license:'Original synthesis for TaskMon',profiles},null,2)+'\n');
console.log(`${all.length*3} original creature sound effects`);
