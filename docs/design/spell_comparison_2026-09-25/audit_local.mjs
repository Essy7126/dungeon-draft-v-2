// Read-only audit of the published catalogues and the independent V1 proposal.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {cards} from '../consumable_v1/content.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../../..');
const classes=['assassin','gardien','arpenteur','thaumaturge'];
const sources=['core/expedition/class_card_catalog.gd','core/expedition/class_starter_catalog.gd','core/expedition/card_ecosystem_catalog.gd'];
const rows=[];
for(const source of sources){
  fs.readFileSync(path.join(root,source),'utf8').split(/\r?\n/).forEach((line,index)=>{
    if(!/^\s*\["[a-z0-9_]+", "(?:assassin|gardien|arpenteur|thaumaturge)"/.test(line))return;
    const raw=line.trim().replace(/,$/,'').replace(/([,\s])\.(\d)/g,'$10.$2').replace(/(\d)\.(?=[,\]])/g,'$1.0');
    const r=JSON.parse(raw); assert.equal(r.length,10);
    rows.push({id:r[0],class:r[1],name:r[2],ap:r[3],min:r[4],max:r[5],damage:r[6],effect:r[7],amount:r[8],role:r[9],source,line:index+1});
  });
}
assert.equal(rows.length,112); assert.equal(new Set(rows.map(r=>r.id)).size,112);
assert.equal(cards.length,48); assert.equal(new Set(cards.map(c=>c.id)).size,48);
const counts=xs=>Object.fromEntries([...new Set(xs)].sort().map(k=>[k,xs.filter(x=>x===k).length]));
const normalize=e=>({frost:'slow',ice_area:'area_slow',fire:'area_hit',cross:'area_hit',lightning:'hit',shadow:'hit'}[e]??e);
const verbs=Object.fromEntries(classes.map(c=>[c,[...new Set(rows.filter(r=>r.class===c).map(r=>normalize(r.effect)))].sort()]));
const shared=verbs.assassin.filter(e=>classes.every(c=>verbs[c].includes(e)));
const summary={catalogue_counts:counts(rows.map(r=>r.source)),classes:counts(rows.map(r=>r.class)),effects:counts(rows.map(r=>r.effect)),normalized_verbs_by_class:verbs,verbs_in_all_four_classes:shared,v1:{count:cards.length,ops:counts(cards.map(c=>c.op)),upgrades_damage_only:cards.filter(c=>Object.keys(c.upgrade).length===1&&c.upgrade.damage!==undefined).map(c=>c.id)},limits:'Static source inventory, rank 0 before modifiers. Shared verbs do not imply identical cards. No engine execution or player testing.'};
const proofFiles=[...sources,'core/expedition/class_card_modifier.gd','core/expedition/card_ecosystem_effects.gd','core/expedition/card_enemy_ecosystem.gd','core/expedition/catabase_monster_evolution_catalog.gd','core/expedition/catabase_monster_encounter_catalog.gd','battle/dynamic_terrain/terrain_interaction_resolver.gd','battle/dynamic_terrain/terrain_surface_runtime_service.gd','docs/design/consumable_v1/content.mjs','docs/design/consumable_v1/combat.mjs'];
const source_sha256=Object.fromEntries(proofFiles.map(f=>[f,createHash('sha256').update(fs.readFileSync(path.join(root,f))).digest('hex')]));
fs.writeFileSync(path.join(here,'inventaire_local.json'),JSON.stringify({summary,source_sha256,godot:rows,v1:cards},null,2)+'\n');
const table=['# Inventaire local reproductible','', 'Généré par `node docs/design/spell_comparison_2026-09-25/audit_local.mjs`. Lecture statique : rang zéro avant passifs, équipement, résistances et modificateurs. P = Prouesse. Un code d’effet décrit une famille technique, pas une identité de gameplay. Voir la fabrique pour les règles exactes.','', '| ID | Carte | Classe | PA | Portée | Dégâts / P | Effet | Paramètre | Source |','|---|---|---|---:|---|---:|---|---:|---|',...rows.map(r=>`| ${r.id} | ${r.name} | ${r.class} | ${r.ap} | ${r.min}–${r.max} | ${r.damage} | ${r.effect} | ${r.amount} | [ligne ${r.line}](../../../${r.source}#L${r.line}) |`),'','## V1 : les 48 familles','', '| ID | Carte | PA | Portée | Dégâts / P | Effet | Condition |','|---|---|---:|---|---:|---|---|',...cards.map(c=>`| ${c.id} | ${c.name} | ${c.ap} | ${c.min}–${c.max} | ${c.damage} | ${c.op} | ${c.condition??'—'} |`),''];
fs.writeFileSync(path.join(here,'INVENTAIRE_LOCAL.md'),table.join('\n'));
console.log(JSON.stringify(summary,null,2));
