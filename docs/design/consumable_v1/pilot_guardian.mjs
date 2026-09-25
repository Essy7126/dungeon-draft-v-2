// Reproduce the narrow tuning experiment, separate from the holdout run seeds.
import fs from 'node:fs';
import {rules} from './content.mjs';
import {simulateRun} from './run.mjs';
const original=rules.retaliation,rows=[];
for(const retaliation of [.25,.4,.55])for(const specIndex of [0,1]){
  rules.retaliation=retaliation;let wins=0,used=0;const failures={};
  for(let seed=1;seed<=10;seed++){
    const result=simulateRun({classId:'gardien',seed,specIndex});wins+=result.completed;used+=result.consumed;
    if(!result.completed)failures[result.failureFight]=(failures[result.failureFight]??0)+1;
  }
  const row={retaliation,specIndex,wins,used:used/10,fail:failures};rows.push(row);console.log(row);
}
rules.retaliation=original;
fs.mkdirSync('artifacts/dev/consumable-v1',{recursive:true});
fs.writeFileSync('artifacts/dev/consumable-v1/guardian_pilot.json',JSON.stringify(rows,null,2)+'\n');
