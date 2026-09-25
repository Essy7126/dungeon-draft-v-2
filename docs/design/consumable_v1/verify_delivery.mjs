import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {manifest,cards,classes} from './content.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
export function parseCsv(text){
  const rows=[];let row=[],cell='',quoted=false;
  for(let i=0;i<text.length;i++){const ch=text[i];if(ch==='"'){if(quoted&&text[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}
    else if(ch===','&&!quoted){row.push(cell);cell='';}else if(ch==='\n'&&!quoted){row.push(cell.replace(/\r$/,''));rows.push(row);row=[];cell='';}else cell+=ch;}
  if(cell||row.length){row.push(cell);rows.push(row);}const keys=rows.shift();return rows.map(row=>Object.fromEntries(keys.map((key,i)=>[key,row[i]])));
}
const read=name=>fs.readFileSync(path.join(root,name),'utf8');
assert.deepEqual(JSON.parse(read('manifest.json')),manifest);
const metadata=JSON.parse(read('metadata.json'));
assert.equal(metadata.version,manifest.rules.version);assert.equal(metadata.runCount,640);assert.equal(metadata.cardScenarios,2304);assert.equal(metadata.itemComparisons,672);
for(const [file,hash]of Object.entries(metadata.hashes))assert.equal(createHash('sha256').update(read(file)).digest('hex'),hash,'Stale evidence: '+file);
for(const [file,n]of [['card_summary.csv',48],['item_summary.csv',34],['run_summary.csv',52],['stat_allocations.csv',336],['family_drop_math.csv',192]])assert.equal(parseCsv(read(file)).length,n,file);
const runs=parseCsv(read('run_summary.csv'));assert.equal(runs.reduce((n,r)=>n+Number(r.n),0),640);
for(const r of runs){assert.ok(Number(r.wins)<=Number(r.n));assert.ok(Number(r.ciLow)<=Number(r.rate)&&Number(r.ciHigh)>=Number(r.rate));}
const family=parseCsv(read('family_drop_math.csv'));
for(const cls of classes)for(const rarity of new Set(cards.map(c=>c.rarity))){const group=family.filter(r=>r.class===cls.id&&r.rarity===rarity);assert.ok(Math.abs(group.reduce((n,r)=>n+Number(r.conditionalFamilyProbability),0)-1)<1e-9);}
let links=0;for(const file of fs.readdirSync(root).filter(f=>f.endsWith('.md'))){for(const match of read(file).matchAll(/\]\(([^)]+)\)/g)){const target=match[1].replace(/^<|>$/g,'').split('#')[0];if(!target||/^[a-z]+:/i.test(target))continue;assert.ok(fs.existsSync(path.resolve(root,decodeURIComponent(target))),file+' -> '+target);links++;}}
console.log(JSON.stringify({manifest:'matches',inputHashes:'match',runs:640,runGroups:52,cardScenarios:2304,itemComparisons:672,statAllocations:336,familyProbabilities:192,localLinks:links}));
