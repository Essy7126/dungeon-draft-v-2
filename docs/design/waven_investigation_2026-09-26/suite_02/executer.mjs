import fs from 'node:fs';
import path from 'node:path';
import {classes} from '../../consumable_v1/content.mjs';
import {out,here,variants,modules,compact,contracts,hashes,focus} from './laboratoire.mjs';
const checks=contracts();
if(process.argv.includes('--contracts-only')){console.log(JSON.stringify(checks));process.exit(0);}
const group=process.argv.includes('--pilotage')?'pilotage':'marchand';
const selected=variants.filter(v=>group==='marchand'?v.id.startsWith('m'):!v.id.startsWith('m'));
const rows=[];
const metadata={group,sourceHashes:hashes,date:new Date().toISOString(),node:process.version,variants:selected,focus,checks,
  seeds:[28001,28010],specIndex:0,deckCap:20,basePolicy:'planner',interpretation:'Fixed exploratory paired policies; no combat or economy rules changed. Not human balance.'};
for(const cl of classes)for(let seed=28001;seed<=28010;seed++){
  const row={classId:cl.id,spec:cl.specs[0],seed};
  for(const v of selected)row[v.id]=compact(modules[v.id].simulateRun({classId:cl.id,specIndex:0,seed}));
  rows.push(row);console.log(JSON.stringify({classId:cl.id,seed,wins:selected.map(v=>row[v.id].won)}));
  fs.writeFileSync(path.join(out,group+'.partial.json'),JSON.stringify({complete:false,metadata,rows},null,2)+'\n');
}
const result={complete:true,metadata,rows};
fs.writeFileSync(path.join(here,group.toUpperCase()+'.json'),JSON.stringify(result,null,2)+'\n');
fs.writeFileSync(path.join(out,group+'.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({complete:true,group,runs:rows.length*selected.length,wins:Object.fromEntries(selected.map(v=>[v.id,rows.filter(r=>r[v.id].won).length]))}));
