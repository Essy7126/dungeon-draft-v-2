import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
export function build({ check = false } = {}) {
  const lines = fs.readFileSync(path.join(dir, 'lectures.tsv'), 'utf8').trim().split(/\r?\n/);
  const fields = lines.shift().split('\t');
  const spells = lines.map((line, index) => {
    const values = line.split('\t');
    assert.equal(values.length, fields.length, `Colonnes ligne ${index + 2}`);
    const row = Object.fromEntries(fields.map((key, i) => [key, values[i]]));
    row.id = Number(row.id);
    row.source = `https://wakfuli.com/encyclopedia/spells/${row.slug}?spell=${row.id}`;
    return row;
  });
  const previous = [
    '../dofus_wakfu_spell_identity_2026-09-25/WAKFU.md',
    '../dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/CLASSES_WAKFU.md',
  ].map(file => fs.readFileSync(path.join(dir, file), 'utf8')).join('\n');
  const priorIds = new Set([...previous.matchAll(/wakfuli\.com\/encyclopedia\/spells\/[^?\s)]+\?spell=(\d+)/g)].map(m => Number(m[1])));
  const repeatIds = spells.filter(s => priorIds.has(s.id)).map(s => s.id);
  const dataset = {
    date: '2026-09-25', level: 245, sourceType: 'encyclopédie communautaire, client non testé',
    coverage: { classes: new Set(spells.map(s => s.classe)).size, readings: spells.length,
      passive: spells.filter(s => s.type === 'passif').length,
      active: spells.filter(s => s.type === 'actif').length,
      priorUniqueIds: priorIds.size, repeatedIds: repeatIds,
      additionalUniqueIds: spells.length - repeatIds.length,
      combinedUniqueIds: new Set([...priorIds, ...spells.map(s => s.id)]).size }, spells,
  };
  let md = '# Lectures complémentaires : contrats et décisions\n\n';
  md += `Lecture du ${dataset.date}, niveau ${dataset.level}. ${spells.length} fiches, ${dataset.coverage.classes} classes ; ${dataset.coverage.additionalUniqueIds} identifiants supplémentaires et ${repeatIds.length} relectures par rapport aux deux dossiers précédents. Ensemble : ${dataset.coverage.combinedUniqueIds} identifiants WAKFU distincts.\n\n`;
  md += 'Les contrats sont des reformulations des fiches consultées ; les analyses sont originales. Le niveau de preuve et les contradictions sont détaillés dans [SOURCES_ET_LIMITES.md](SOURCES_ET_LIMITES.md). Généré depuis [lectures.tsv](lectures.tsv) ; modifier cette source puis relancer le générateur.\n\n';
  for (const classe of new Set(spells.map(s => s.classe))) {
    md += `## ${classe}\n\n`;
    for (const spell of spells.filter(s => s.classe === classe)) {
      md += `### [${spell.nom}](${spell.source}) — ${spell.type}, ${spell.id}\n\n`;
      md += `**Contrat lu.** ${spell.contrat}\n\n**Décision et équilibrage.** ${spell.analyse}\n\n**Limite de preuve.** ${spell.limite}\n\n`;
    }
  }
  const outputs = { 'lectures.json': JSON.stringify(dataset, null, 2) + '\n', 'LECTURES_COMPLEMENTAIRES.md': md.trimEnd() + '\n' };
  for (const [name, body] of Object.entries(outputs)) {
    if (check) assert.equal(fs.readFileSync(path.join(dir, name), 'utf8').replaceAll('\r\n', '\n'), body, `Dérive ${name}`);
    else fs.writeFileSync(path.join(dir, name), body);
  }
  return dataset;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(build({ check: process.argv.includes('--check') }).coverage, null, 2));
}
