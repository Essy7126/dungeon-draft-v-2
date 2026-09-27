// Vérifie le paquet de conception et ses calculs ; n'exécute pas Godot ni un combat V2.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
const here = new URL('./',import.meta.url);
const m = JSON.parse(readFileSync(new URL('manifest.json',here)));
const lock = JSON.parse(readFileSync(new URL('SOURCES_VERROUILLEES.json',here)));
const checks = [];
function check(name, predicate) { assert.ok(predicate,name); checks.push(name); }
const near = (a,b) => Math.abs(a-b)<1e-9;
const sha = file => createHash('sha256').update(readFileSync(file)).digest('hex');
check('Source manifeste V1 inchangée',sha(new URL('../consumable_v1/manifest.json',here))===lock.baseManifest);
check('Source catalogue V1 inchangée',sha(new URL('../consumable_v1/CATALOGUE.md',here))===lock.baseCatalogue);
check('Conception explicitement non implémentée',m.meta.status==='PREPARED_NOT_IMPLEMENTED');
check('Version du profil cohérente',m.rules.version===m.meta.version && m.rules.rulesetId===m.meta.id);
check('48 familles sans ID doublonné',m.cards.length===48 && new Set(m.cards.map(c=>c.id)).size===48);
check('48 ID runtime isolés',new Set(m.cards.map(c=>c.runtimeId)).size===48 && m.cards.every(c=>c.runtimeId===`cc2_${c.id}`));
check('23 familles modifiées recensées',m.cards.filter(c=>c.changedFromV1).length===23 && m.contentChanges.length===23);
check('Quatre classes et huit spécialisations',m.classes.length===4 && Object.keys(m.specs).length===8);
check('18 équipements et huit reliques',m.equipment.length===18 && m.relics.length===8);
check('48 effets de base et améliorations documentés',m.cards.every(c=>c.baseText?.length && c.upgradeText?.length && Object.keys(c.upgrade).length));
check('Coûts et portées légaux',m.cards.every(c=>Number.isInteger(c.ap)&&c.ap>=1&&c.ap<=4&&c.min>=0&&c.max>=c.min));
const byId=Object.fromEntries(m.cards.map(c=>[c.id,c]));
for(const c of m.classes){
  check(`Spécialisations ${c.id}`,c.specs.length===2 && c.specs.every(s=>m.specs[s]));
  for(const [i,deck] of [c.starters,c.alternativeStarters].filter(Boolean).entries()) {
    check(`Préparation ${c.id}/${i}`,deck.length*3===m.rules.initialCards && new Set(deck).size===5 && deck.every(id=>byId[id]?.rarity==='normal'&&['shared',c.id].includes(byId[id].affinity)));
  }
  check(`Pool de normales ${c.id} constant`,m.cards.filter(k=>k.rarity==='normal'&&['shared',c.id].includes(k.affinity)).length===12);
}
check('Ancienne spécialisation ambush non superposée',!m.specs.ambush && Boolean(m.specs.relay));
check('Pression définie sans conflit',m.rules.collapseStart===m.rules.pressure.startsAfterEnemyPhase && m.rules.collapseStep===m.rules.pressure.fractionPerStep && m.rules.turnLimit===m.rules.pressure.maxTurns);
check('Douze rencontres ordonnées',m.route.length===12 && m.route.every((r,i)=>r.index===i+1));
check('Références ennemies valides',m.route.every(r=>r.roster.every(id=>m.enemyTypes[id])));
check('Cinq variantes documentées',Object.keys(m.encounterContracts).length===5 && m.route.filter(r=>r.encounterVariant!=='baseline_v1').every(r=>m.encounterContracts[r.encounterVariant]));
check('Courbes complètes',m.rules.hp.length===12&&m.rules.prowess.length===12&&m.rules.xpThresholds.length===12);
check('XP monotone',m.rules.xpThresholds.every((x,i,a)=>i===0||x>a[i-1]));
check('Sept canaux par palier',m.rules.loot.rates.length===4&&m.rules.loot.rates.every(row=>row.length===7&&row.every(p=>p>=0&&p<=1)));
check('Plancher normal',m.rules.loot.rates.every(row=>row[0]===1)&&m.rules.loot.sizes[0]===2);
check('Sauvegarde V2 distincte',m.rules.savePath==='user://catabase_cards_consumable_v2.json');
check('Copie consommée incompatible avec reprise au début du combat',m.rules.checkpoint==='after_each_committed_action_and_each_actor_activation');
check('Pas de double scaling de difficulté',m.rules.difficultyProfile==='standard_v2' && m.rules.legacyDifficultyMultipliers===false);

function choose(n,k){if(k<0||k>n)return 0;let r=1;for(let i=1;i<=k;i++)r=r*(n-i+1)/i;return r;}
const access=[15,20,30].map(n=>({n,normalHand:1-2*choose(n-3,5)/choose(n,5)+choose(n-6,5)/choose(n,5),prepared:1-choose(n-4,4)/choose(n-1,4)}));
let count=0,withB=0;
for(let a=0;a<16;a++)for(let b=a+1;b<17;b++)for(let c=b+1;c<18;c++)for(let d=c+1;d<19;d++){
  count++; if([a,b,c,d].some(i=>i<3))withB++;
}
check('Ouverture préparée : formule et énumération indépendante',count===choose(19,4)&&near(withB/count,access[1].prepared));
const P=40,guard=Math.round(byId.g01.amount*P),maxSacrifice=Math.floor(Math.min(guard,byId.g09.sacrificeCap*P));
const conversions=[0,16,maxSacrifice].map(s=>({sacrifice:s,damage:Math.round(byId.g09.damage*P+byId.g09.amount*s),remainingGuard:guard-s}));
check('Répercussion au sacrifice maximum',conversions[2].damage===76 && conversions[2].remainingGuard===14);
check('Répercussion conserve le point zéro',conversions[0].damage===28 && conversions[0].remainingGuard===46);
check('Le cap de supplément est cohérent',near(byId.g09.sacrificeCap*byId.g09.amount,byId.g09.cap));
const lowLevelSacrifice=Math.floor(Math.min(Math.round(byId.g01.amount*18),byId.g09.sacrificeCap*18));
check('Sacrifice entier au niveau 1',lowLevelSacrifice===14 && Math.round(byId.g09.damage*18+byId.g09.amount*lowLevelSacrifice)===34);
check('Eau et glace exigent une préparation temporelle',byId.t04.ap+byId.t01.ap>m.rules.ap && byId.t04.duration>=2);
check('Déplacement puis relais reste payable',byId.n03.ap+byId.r01.ap<=m.rules.ap);
const preboss=m.route.filter(r=>r.index<12);
const gold=m.rules.initialGold+preboss.reduce((s,r)=>s+(r.kind==='elite'?m.rules.economy.goldElite:m.rules.economy.goldNormal),0);
check('Budget de monnaie sans vente/Obole',gold===515);
const targetExpectation=m.rules.economy.bagCards*m.rules.loot.nativeOrShared/12;
check('Le sac conserve son espérance ciblée',near(targetExpectation,.35));
check('Pas d’arbitrage achat/revente normal',m.rules.economy.normalSingle>m.rules.economy.sell.normal && m.rules.economy.bagPrice>m.rules.economy.bagCards*m.rules.economy.sell.normal);
const boss=m.route.at(-1),weight=boss.roster.reduce((s,id)=>s+m.enemyTypes[id].weight,0);
const bossHP=Math.round(m.rules.prowess[boss.level-1]*boss.hpBudget*m.enemyTypes.boss.weight/weight);
check('Budget de Pâris et transition conservée',bossHP===840 && bossHP/2===420);
const reservoir=m.rules.prowess[11]*.5*6;
check('Réservoir indépendant de P équipé',reservoir===336 && reservoir!==145.6*.5*6);

let localLinks=0;
const generatedLinks=[];
for(const filename of readdirSync(here).filter(f=>f.endsWith('.md'))){
  const text=readFileSync(new URL(filename,here),'utf8');
  for(const match of text.matchAll(/\]\(([^)]+)\)/g)){
    const target=match[1];if(/^(https?:|#)/.test(target))continue;
    localLinks++;
    const resolved=new URL(target.split('#')[0],here);
    if(resolved.href===new URL('VERIFICATION.json',here).href) generatedLinks.push(resolved);
    else assert.ok(existsSync(resolved),`${filename}: ${target}`);
  }
}
check('Tous les liens documentaires locaux résolus',localLinks>0);
const result={
  status:'DESIGN_PACKAGE_CHECKED_NOT_GAMEPLAY_VALIDATED',
  version:m.meta.version,checks:checks.length,checkNames:checks,localLinks,
  manifestSha256:sha(new URL('manifest.json',here)),
  calculations:{access,enumeratedPreparedHands:count,guardConversionAtP40:conversions,prebossGold:gold,targetCopiesPerBag:targetExpectation,bossHP,bossPhaseThreshold:bossHP/2,reservoirSixChargesLevel12:reservoir},
  notExecuted:['Godot import','Godot unit/scenario tests','Full V2 combat/run simulation','Human playtest'],
};
writeFileSync(new URL('VERIFICATION.json',here),JSON.stringify(result,null,2)+'\n');
for(const url of generatedLinks) assert.ok(existsSync(url),'Le rapport de vérification doit avoir été écrit.');
console.log(JSON.stringify({status:result.status,checks:checks.length,localLinks,calculations:result.calculations},null,2));
