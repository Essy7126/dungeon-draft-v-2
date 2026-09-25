import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const dir = path.dirname(fileURLToPath(import.meta.url));
const checkOnly = process.argv.includes('--check');
const write = (name, content) => {
  const target = path.join(dir, name);
  if (checkOnly) assert.equal(fs.readFileSync(target, 'utf8').replaceAll('\r\n', '\n'), content, `Fichier généré périmé : ${name}`);
  else fs.writeFileSync(target, content);
};
const readJson = name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
const reference = readJson('inventaire_reference.json');
const meta = [...reference.cards, ...readJson('supplements_reference.json')];
const corrections = {
  FLEX:'ironclad/Flex', UPPERCUT:'ironclad/Uppercut', SWORD_BOOMERANG:'ironclad/Sword_Boomerang',
  SEARING_BLOW:'ironclad/Searing_Blow', BANE:'silent/Bane', BOUNCING_FLASK:'silent/Bouncing_Flask',
  DODGE_AND_ROLL:'silent/Dodge_and_Roll', GRAND_FINALE:'silent/Grand_Finale',
  GENETIC_ALGORITHM:'defect/Genetic_Algorithm', REPROGRAM:'defect/Reprogram',
  FASTING2:'watcher/Fasting', HALT:'watcher/Halt', TANTRUM:'watcher/Tantrum',
};
const types = {Attack:'Attaque', Skill:'Compétence', Power:'Pouvoir', Status:'Statut', Curse:'Malédiction'};
const rarities = {Basic:'Départ', Common:'Commune', Uncommon:'Peu commune', Rare:'Rare', Special:'Spéciale', Curse:'Malédiction'};
const labels = {ironclad:'Ironclad — Le Soldat de fer', silent:'Silent — La Silencieuse', defect:'Defect — Le Défectueux', watcher:'Watcher — La Gardienne', neutres:'Incolores, spéciales, choix de Wish, statuts et malédictions'};
const cost = n => n === -1 ? 'X' : n === -2 ? '—' : String(n);
const escape = s => String(s).replaceAll('|','\\|').replaceAll('\n',' ');
const cards = [];
for (const group of Object.keys(labels)) {
  const lines = fs.readFileSync(path.join(dir, `lectures_${group}.tsv`), 'utf8').trim().split(/\r?\n/);
  assert.equal(lines.shift(), 'id\tcontrat\tanalyse');
  const entries = lines.map((line, index) => {
    const fields = line.split('\t');
    assert.equal(fields.length, 3, `${group}:${index+2}: colonnes`);
    const [id, contrat, analyse] = fields;
    const m = meta.find(x => x.id === id);
    assert.ok(m, `Métadonnées absentes: ${id}`);
    assert.ok(contrat.length > 3 && analyse.length > 35, `Lecture incomplète: ${id}`);
    const sources = [m.source ?? reference.source];
    if (corrections[id]) sources.push(`https://slaythespire.gg/cards/${corrections[id]}`);
    return {...m, group, contrat, analyse, sources};
  });
  assert.equal(entries.length, group === 'neutres' ? 70 : 75);
  cards.push(...entries);
  let md = `# ${labels[group]}\n\n${entries.length} entrées lues et analysées, base et amélioration. Lecture documentaire du premier Slay the Spire, 25 septembre 2026.\n\n`;
  md += 'D = dégâts ; B = blocage. La flèche indique la valeur normale puis améliorée. Le reste du contrat reste identique. Les analyses sont notre interprétation de conception. Les coûts sont ceux imprimés avant modificateurs ; — signifie injouable normalement, ou simple choix de Wish.\n\n';
  md += 'Un pouvoir joué devient un effet installé, sans rejoindre la défausse ou la pile épuisée. Épuisement retire du combat, pas de la run. Les jetons et cartes créées en combat disparaissent ensuite. Voir [règles et interactions](EFFETS_ET_REGLES.md), [méthode et sources](SOURCES_ET_VERIFICATION.md) et [synthèse](README.md).\n\n';
  md += '| Carte et identifiant | Type · rareté | Énergie base → + | Contrat base → + | Fonction, choix et limites | Source de lecture |\n|---|---|---|---|---|---|\n';
  for (const c of entries) {
    const sources = c.sources.map((s,i)=>`[${i ? 'recoupement' : 'source'}](${s})`).join(' ; ');
    md += `| **${escape(c.name)}** · \`${c.id}\` | ${types[c.type]} · ${rarities[c.rarity]}${c.choiceOnly?' · choix uniquement':''} | ${cost(c.cost)}${c.upgradeCost!==c.cost?' → '+cost(c.upgradeCost):''} | ${escape(c.contrat)} | ${escape(c.analyse)} | ${sources} |\n`;
  }
  write(`CATALOGUE_${group.toUpperCase()}.md`,md);
}
assert.equal(new Set(cards.map(x=>x.id)).size,370);
assert.deepEqual(new Set(cards.map(x=>x.id)),new Set(meta.map(x=>x.id)));
const counts = Object.fromEntries(['group','type','rarity'].map(field=>[field,cards.reduce((acc,c)=>(acc[c[field]]=(acc[c[field]]??0)+1,acc),{})]));
const result = {version:'1.0-documentary',date:'2026-09-25',game:'Slay the Spire 1',scope:{entries:370,cardEntries:367,wishChoices:3,classCards:300,colorlessOrdinary:35,specialCards:13,statuses:5,curses:14},counts,cards};
write('catalogue.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({entries:cards.length,...counts},null,2));
