import assert from 'node:assert/strict';
import {readFileSync,readdirSync,existsSync,mkdirSync,writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {resolve,dirname} from 'node:path';

const dir=dirname(fileURLToPath(import.meta.url));
const docs=readdirSync(dir).filter(x=>x.endsWith('.md'));
let links=0,tables=0,external=new Set();
for(const name of docs){
  const text=readFileSync(resolve(dir,name),'utf8');
  assert.ok(!text.includes('\uFFFD'),`Encodage ${name}`);
  for(const m of text.matchAll(/\[[^\]]+\]\(([^\s)]+)\)/g)){
    const target=m[1];
    if(/^https?:/.test(target)){new URL(target);external.add(target);}
    else if(!target.startsWith('#')){
      const path=decodeURIComponent(target.split('#')[0]);
      assert.ok(existsSync(resolve(dir,path)),`${name}: lien absent ${target}`);links++;
    }
  }
  let width=0;
  for(const line of text.split(/\r?\n/)){
    if(line.startsWith('|')){
      const cells=line.split('|').length;
      if(!width){width=cells;tables++;}
      assert.equal(cells,width,`${name}: colonnes de tableau`);
    }else width=0;
  }
}
for(const [name,classes,spells,pattern] of [
  ['CLASSES_DOFUS.md',16,80,/https:\/\/dofusdb\.com\/sorts\/[^)\s]+/g],
  ['CLASSES_WAKFU.md',15,75,/https:\/\/wakfuli\.com\/encyclopedia\/spells\/[^)\s]+/g]
]){
  const text=readFileSync(resolve(dir,name),'utf8');
  const sections=text.split(/^## .+ — .+$/m).slice(1);
  assert.equal(sections.length,classes,`${name}: classes`);
  const urls=[...text.matchAll(pattern)].map(x=>x[0]);
  assert.equal(urls.length,spells,`${name}: fiches`);
  assert.equal(new Set(urls).size,spells,`${name}: doublons`);
  for(const s of sections) assert.equal([...s.matchAll(pattern)].length,5,`${name}: cinq fiches par classe`);
}
const sourceLengths=[];
for(const [name,expected,prefix] of [['BESTIAIRE_DOFUS.md',6,'D'],['BESTIAIRE_WAKFU.md',5,'W']]){
  const text=readFileSync(resolve(dir,name),'utf8');
  const sections=[...text.matchAll(new RegExp(`^## (${prefix}\\d+) — ([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`,'gm'))];
  assert.equal(sections.length,expected,`${name}: rencontres`);
  for(const s of sections){
    const clean=s[2].replace(/\[([^\]]+)\]\([^)]+\)/g,'$1').replace(/[|*#—]/g,' ');
    const words=clean.trim().split(/\s+/).length;
    sourceLengths.push({id:s[1],mots:words});
    assert.ok(words<=200,`${name}: synthèse ${s[1]} trop longue (${words})`);
  }
}
const report=JSON.parse(readFileSync(resolve(dir,'resultats_calcules.json'),'utf8'));
assert.equal(report.cas,16);assert.equal(report.assertions,32);
assert.equal(report.resultats.length,16);
assert.equal(new Set(report.resultats.map(x=>x.id)).size,16);
const validation={documents:docs.length,tables,liens_locaux:links,urls_externes_distinctes:external.size,
  classes:{dofus:16,wakfu:15},fiches:{dofus:80,wakfu:75},rencontres:11,
  calculs:report.cas,assertions_calculs:report.assertions,syntheses:sourceLengths,
  limites:'Contrôle documentaire, syntaxe URL et modèles ; aucun accès HTTP ni validation client/moteur.'};
const out=resolve(dir,'../../../../artifacts/dev/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire');
mkdirSync(out,{recursive:true});
writeFileSync(resolve(out,'validation.json'),JSON.stringify(validation,null,2)+'\n');
console.log(JSON.stringify(validation,null,2));
