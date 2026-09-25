import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const dir=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(dir,'../../..');
const read=name=>JSON.parse(fs.readFileSync(path.join(dir,name),'utf8'));
const dataset=read('catalogue.json');
const cards=dataset.cards;
const tests=[];
function verify(name,fn){fn();tests.push(name);}
const count=predicate=>cards.filter(predicate).length;
const pin='687e6dce1f325234425e1b75f09d13ddd6ce7000';

verify('Couverture exacte des 370 identifiants',()=>{
  assert.equal(cards.length,370);
  assert.equal(new Set(cards.map(c=>c.id)).size,370);
  const reference=read('inventaire_reference.json');
  const supplements=read('supplements_reference.json');
  assert.equal(reference.rawEntries,360);
  assert.equal(reference.cards.length,358);
  assert.equal(supplements.length,12);
  assert.ok(reference.source.includes(pin));
  assert.deepEqual(reference.excluded.map(c=>c.id).sort(),['IMPULSE','UNRAVELING']);
  assert.deepEqual(new Set(cards.map(c=>c.id)),new Set([...reference.cards,...supplements].map(c=>c.id)));
});
verify('Répartition des cartes et des choix spéciaux',()=>{
  for(const group of ['ironclad','silent','defect','watcher'])assert.equal(count(c=>c.group===group),75);
  assert.equal(count(c=>c.group==='neutres'),70);
  assert.equal(count(c=>c.color==='colorless'&&['Uncommon','Rare'].includes(c.rarity)),35);
  assert.equal(count(c=>c.color==='colorless'&&c.rarity==='Special'&&!c.choiceOnly),13);
  assert.equal(count(c=>c.type==='Status'),5);
  assert.equal(count(c=>c.type==='Curse'),14);
  assert.equal(count(c=>c.choiceOnly),3);
  assert.deepEqual(cards.filter(c=>c.choiceOnly).map(c=>c.id).sort(),['BECOME_ALMIGHTY','FAME_AND_FORTUNE','LIVE_FOREVER']);
  assert.deepEqual(dataset.scope,{entries:370,cardEntries:367,wishChoices:3,classCards:300,colorlessOrdinary:35,specialCards:13,statuses:5,curses:14});
});
verify('Contrats, analyses, coûts et références présents pour chaque entrée',()=>{
  for(const c of cards){
    assert.ok(c.name&&c.id&&c.contrat&&c.analyse,c.id);
    assert.ok(c.analyse.length>35,c.id);
    assert.ok(Number.isInteger(c.cost)&&c.cost>=-2,c.id);
    assert.ok(Number.isInteger(c.upgradeCost)&&c.upgradeCost>=-2,c.id);
    assert.ok(c.sources.length>=1,c.id);
    for(const s of c.sources)assert.equal(new URL(s).protocol,'https:',c.id);
    assert.ok(!/TODO|undefined|NaN|PLACEHOLDER/.test(c.contrat),c.id);
  }
});
// L'import évite de dépendre du lancement de sous-processus dans les environnements restreints.
const originalArgs=[...process.argv];
process.argv.push('--check');
try {
  await import('./construire_catalogue.mjs');
  await import('./calculs.mjs');
  tests.push('Catalogues et calculs identiques à leurs sources éditables');
} finally {process.argv=originalArgs;}
verify('Scénarios mathématiques annoncés et énumération indépendante',()=>{
  const results=read('resultats_calcules.json');
  assert.equal(results.cases,47);
  assert.equal(results.assertions,50);
  assert.equal(results.enumeratedHands,3003);
  assert.equal(results.results.length,47);
  assert.deepEqual(results.results.map(r=>r.id),Array.from({length:47},(_,i)=>'M'+String(i+1).padStart(2,'0')));
});

let localLinks=0,externalLinks=0;
const files=fs.readdirSync(dir).filter(name=>/\.(md|json|tsv|mjs)$/.test(name)&&name!=='VERIFICATION.json').sort();
verify('Encodage et largeur des tableaux Markdown',()=>{
  for(const name of files.filter(n=>n.endsWith('.md'))){
    const md=fs.readFileSync(path.join(dir,name),'utf8');
    assert.ok(!md.includes('\uFFFD'),`Encodage : ${name}`);
    let width=0;
    for(const [index,line] of md.split(/\r?\n/).entries()){
      if(!line.startsWith('|')){width=0;continue;}
      const cells=line.split(/(?<!\\)\|/).length;
      if(!width)width=cells;
      assert.equal(cells,width,`Tableau : ${name}:${index+1}`);
    }
  }
});
verify('Liens Markdown locaux résolus ; URLs distantes syntaxiquement valides',()=>{
  for(const name of files.filter(n=>n.endsWith('.md'))){
    const md=fs.readFileSync(path.join(dir,name),'utf8');
    for(const match of md.matchAll(/\[[^\]\n]*\]\(([^)\s]+)\)/g)){
      const href=match[1];
      if(/^https?:/.test(href)){
        assert.ok(['http:','https:'].includes(new URL(href).protocol));externalLinks++;
      }else if(!href.startsWith('#')){
        const target=path.resolve(dir,decodeURIComponent(href.split('#')[0]));
        assert.ok(fs.existsSync(target)||target===path.join(dir,'VERIFICATION.json'),`${name}: ${href}`);
        localLinks++;
      }
    }
  }
});
// Import local explicite : le comptage ci-dessous porte sur la V1 théorique, pas le catalogue Godot.
const {cards:v1}=await import('../consumable_v1/content.mjs');
verify('Comparaison V1 : 48 familles et 33 améliorations exclusivement offensives',()=>{
  assert.equal(v1.length,48);
  assert.equal(v1.filter(c=>Object.keys(c.upgrade).length===1&&'damage' in c.upgrade).length,33);
});

const fingerprints=Object.fromEntries(files.filter(n=>n!=='WORKLOG.md').map(name=>[
  name,createHash('sha256').update(fs.readFileSync(path.join(dir,name))).digest('hex'),
]));
function readGitHead(){
  let gitDir=path.join(root,'.git');
  if(fs.statSync(gitDir).isFile()){
    const pointer=fs.readFileSync(gitDir,'utf8').trim();
    assert.ok(pointer.startsWith('gitdir: '));
    gitDir=path.resolve(root,pointer.slice(8));
  }
  const head=fs.readFileSync(path.join(gitDir,'HEAD'),'utf8').trim();
  if(!head.startsWith('ref: '))return head;
  const ref=head.slice(5);
  const commonFile=path.join(gitDir,'commondir');
  const commonDir=fs.existsSync(commonFile)?path.resolve(gitDir,fs.readFileSync(commonFile,'utf8').trim()):gitDir;
  for(const location of new Set([gitDir,commonDir])){
    const loose=path.join(location,ref);
    if(fs.existsSync(loose))return fs.readFileSync(loose,'utf8').trim();
    const packed=path.join(location,'packed-refs');
    if(fs.existsSync(packed)){
      const entry=fs.readFileSync(packed,'utf8').split(/\r?\n/).find(line=>line.endsWith(' '+ref));
      if(entry)return entry.split(' ')[0];
    }
  }
  throw new Error(`Référence Git non résolue : ${ref}`);
}
const report={
  checkedAt:new Date().toISOString(),
  repoHead:readGitHead(),
  status:'passed',
  scope:'Intégrité documentaire, couverture et calculs isolés ; aucun client StS ou Godot exécuté.',
  checks:tests,
  totals:{entries:370,cards:367,wishChoices:3,calculationScenarios:47,calculationAssertions:50,enumeratedHands:3003,localLinks,externalLinks},
  remoteLinksCheckedOverNetwork:false,
  fingerprints,
};
fs.writeFileSync(path.join(dir,'VERIFICATION.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({status:report.status,checks:tests.length,...report.totals},null,2));
