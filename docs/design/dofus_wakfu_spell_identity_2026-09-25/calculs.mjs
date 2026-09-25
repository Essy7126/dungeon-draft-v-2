import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';

// Modèles documentaires, sans connexion aux clients DOFUS ou WAKFU.
const root = new URL('./', import.meta.url);
const near = (a, b) => assert.ok(Math.abs(a - b) < 1e-9, `${a} != ${b}`);
let checks = 0;
const check = (name, run) => { run(); checks++; return name; };
const cases = [];
function sequence(initial, actions) {
  let ap = initial;
  const history = [];
  for (const action of actions) {
    if (ap < action.cost) return { legal: false, ap, blocked: action.name, history };
    const before = ap;
    ap -= action.cost;
    const afterPayment = ap;
    ap += action.refund;
    history.push({ name: action.name, before, afterPayment, refund: action.refund, after: ap });
  }
  return { legal: true, ap, netCost: initial - ap, history };
}
function minimumInitial(actions) {
  let spent = 0;
  let required = 0;
  for (const a of actions) {
    required = Math.max(required, spent + a.cost);
    spent += a.cost - a.refund;
  }
  return { required, netCost: spent };
}
const suspension = Array.from({ length: 2 }, (_, i) => ({ name: `Suspension ${i + 1}`, cost: 4, refund: 2 }));
cases.push({ id: 'suspension', hypothesis: 'Deux ciblages du Cadran légaux, remboursements immédiats, aucun autre gain.', ...minimumInitial(suspension), at4: sequence(4, suspension), at5: sequence(5, suspension), at6: sequence(6, suspension) });
check('Deux Suspensions nécessitent six PA, malgré un coût net de quatre', () => { assert.deepEqual(minimumInitial(suspension), { required: 6, netCost: 4 }); assert.equal(sequence(4, suspension).legal, false); assert.equal(sequence(5, suspension).legal, false); assert.equal(sequence(6, suspension).ap, 2); });

const pointe = [{ name: 'Pointe-heure avec échange et Cours du temps sous Distorsion', cost: 2, refund: 2 }];
cases.push({ id: 'pointe', hypothesis: 'Cumul théorique du remboursement du sort et du passif, un événement de transposition éligible. Plafond documentaire : deux lancers/tour, un/cible.', required: minimumInitial(pointe).required, netCost: 0, at1: sequence(1, pointe), at2: sequence(2, pointe), twoCasts: sequence(2, [...pointe, ...pointe]) });
check('Zéro coût net ne permet pas le lancement à un PA', () => { assert.equal(sequence(1, pointe).legal, false); assert.equal(sequence(2, pointe).ap, 2); assert.equal(sequence(2, [...pointe, ...pointe]).ap, 2); });

const aiguille = [1, 2, 3, 4].map(remaining => ({ remaining, spent: Math.min(4, remaining), damage: 111, damagePerAP: 111 / Math.min(4, remaining), spentIfKill: 0 }));
cases.push({ id: 'aiguille', hypothesis: 'Règle de reliquat 1.92, base N245 WAKFULI ; cible légale et sans autres modificateurs.', rows: aiguille });
check('Aiguille conserve son dégât avec des coûts différents', () => { near(aiguille[0].damagePerAP, 111); near(aiguille[3].damagePerAP, 27.75); assert.equal(aiguille.every(x => x.damage === 111), true); });

cases.push({ id: 'eclair', hypothesis: 'Deux ennemis éligibles, rebond effectif ; pas de résistance ni bonus.', first: 97, rebound: 181, total: 278, ap: 5, firstPerAP: 97 / 5, reboundPerAP: 181 / 5, totalPerAP: 278 / 5, criticalTotal: 122 + 227 });
check('Éclair répartit la majorité des dégâts sur le rebond', () => { assert.equal(97 + 181, 278); near(278 / 5, 55.6); assert.ok(181 > 97); });

const dust = [0, 1, 2].map(priorCasts => ({ priorCasts, min: 3 + 2 * priorCasts, max: 5 + 2 * priorCasts }));
cases.push({ id: 'poussiere', hypothesis: 'Fenêtres successives tant que le bonus n’est pas réinitialisé ; règle de remise à zéro non établie.', ranges: dust, stationaryDistance3: dust.map(x => 3 >= x.min && 3 <= x.max), stationaryDistance5: dust.map(x => 5 >= x.min && 5 <= x.max) });
check('Augmenter la portée minimale ferme une ancienne solution', () => { assert.deepEqual(dust.map(x => 3 >= x.min && 3 <= x.max), [true, false, false]); assert.deepEqual(dust.map(x => 5 >= x.min && 5 <= x.max), [true, true, false]); });

cases.push({ id: 'martel', hypothesis: 'Trois cibles distinctes, toutes reçoivent chaque répétition ultérieure. Hypothèse de mémoire/éligibilité à confirmer en jeu ; dégâts seulement, pas retrait PA.', perTarget: [83 * 3, 83 * 2, 83], hits: 6, damage: 498, ap: 9, damagePerAP: 498 / 9 });
check('Mémoire triangulaire sur trois cibles distinctes', () => { assert.equal(83 * (1 + 2 + 3), 498); assert.equal(249 + 166 + 83, 498); });

const mirror = (point, center) => point.map((v, i) => 2 * center[i] - v);
const caster = [3, 3]; const target = [5, 3];
cases.push({ id: 'symetrie', hypothesis: 'Grille abstraite, destinations légales et libres ; ne modélise ni portée ni immunité.', caster, target, targetAroundCaster: mirror(target, caster), casterAroundTarget: mirror(caster, target) });
check('Changer le centre change le combattant déplacé et sa destination', () => { assert.deepEqual(mirror(target, caster), [1, 3]); assert.deepEqual(mirror(caster, target), [7, 3]); assert.deepEqual(mirror(mirror(target, caster), caster), target); });

const willExpectation = (nominal, delta) => nominal * Math.max(0, Math.min(1, 0.5 + delta / 200));
const will = [-100, -50, 0, 50, 100].map(delta => ({ delta, expectedRemovalOf2: willExpectation(2, delta) }));
cases.push({ id: 'volonte', hypothesis: 'Modèle linéaire communautaire ; deux paquets nominaux de 2 sur une cible avec assez de PA, Volonté initiale égale, aucun bonus du lanceur. Ce n’est pas une rotation complète de Ralentissement.', points: will, sameTargetTwoPackets: 1 + willExpectation(2, -10), distinctTargetsTwoPackets: 2 });
check('La Volonté rend nominal et effectif différents', () => { near(willExpectation(2, 0), 1); near(willExpectation(2, -100), 0); near(willExpectation(2, 100), 2); near(1 + willExpectation(2, -10), 1.9); });

const taken = resistance => 0.8 ** (resistance / 100);
const resist = [0, 100, 400].map(before => ({ before, after: before + 100, damageBefore: 100 * taken(before), damageAfter: 100 * taken(before + 100), relativeReduction: 1 - taken(before + 100) / taken(before) }));
cases.push({ id: 'resistance', hypothesis: 'Formule continue communautaire, sans arrondi en paliers ni plafond des joueurs. Trêve applique le gain aux deux camps.', rows: resist });
check('Cent résistances supplémentaires réduisent de 20 % le restant dans le modèle continu', () => resist.forEach(x => near(x.relativeReduction, 0.2)));

cases.push({ id: 'di', hypothesis: 'Bonus de même catégorie DI additionnés ; pas un multiplicateur final séparé.', initialDI: 100, addedDI: 50, relativeGain: (1 + 1 + 0.5) / (1 + 1) - 1 });
check('Cinquante points de DI ajoutés à cent donnent 25 % de gain relatif', () => near((1 + 1 + 0.5) / 2 - 1, 0.25));

const feca = [0, 1, 2, 3, 4].map(enemies => ({ enemies, rempartArmor: 166 * enemies, orbeArmorIfCondition: 499 }));
cases.push({ id: 'armures_feca', hypothesis: 'Bases N245, sans modificateur d’armure ; comparaison de montants, pas de disponibilité. Les moments et conditions diffèrent.', rows: feca, orbeExpectedAt50PercentSuccess: 499 * 0.5 });
check('Trois ennemis au contact approchent le montant de l’Orbe, sans équivalence de contrat', () => { assert.equal(feca[3].rempartArmor, 498); assert.equal(feca[4].rempartArmor, 664); near(499 * 0.5, 249.5); });

const armor = 2.4 * 200;
cases.push({ id: 'fermentation', hypothesis: 'N200 ; deux applications de 480, chacune présente pour sa fenêtre ; dégâts positifs absorbables.', each: armor, twoWaves800: Math.min(800, armor) * 2, oneWave960: Math.min(960, armor), hpLostDuringOneWave960: 960 - Math.min(960, armor) });
check('Une protection différée ne finance pas la première rafale', () => { assert.equal(armor, 480); assert.equal(Math.min(800, armor) * 2, 960); assert.equal(960 - Math.min(960, armor), 480); });

cases.push({ id: 'bombance', hypothesis: 'Départ Sobre, deux bascules consécutives, aucun autre modificateur.', ...minimumInitial([{ cost: 1, refund: 0 }, { cost: 1, refund: 1 }]), casts: 2 });
check('Bombance : deux bascules coûtent un net mais nécessitent deux PA avant le retour', () => { assert.deepEqual(minimumInitial([{ cost: 1, refund: 0 }, { cost: 1, refund: 1 }]), { required: 2, netCost: 1 }); });

const consumable = { copiesPrepared: 2, copiesPerCast: 1, apNetPerCast: 0, maxCastsFromCopies: 2 };
cases.push({ id: 'copies', hypothesis: 'Transposition hypothétique dans Catabase : destruction d’une copie à chaque lancement ; aucune création/récupération.', ...consumable });
check('Un remboursement de PA ne recrée pas de consommable', () => assert.equal(consumable.copiesPrepared / consumable.copiesPerCast, 2));

const dofus = await readFile(new URL('DOFUS.md', root), 'utf8');
const wakfu = await readFile(new URL('WAKFU.md', root), 'utf8');
const countRows = (text, domain) => text.split('\n').filter(line => line.startsWith('| [') && line.includes(domain)).length;
const coverage = { dofus: countRows(dofus, 'dofusdb.com/sorts/'), wakfu: countRows(wakfu, 'wakfuli.com/encyclopedia/spells/'), total: 91 };
check('Le nombre annoncé correspond aux fiches documentées', () => { assert.equal(coverage.dofus, 36); assert.equal(coverage.wakfu, 55); assert.equal(coverage.dofus + coverage.wakfu, 91); });

const result = { studyDate: '2026-09-25', kind: 'documentary_contract_models_not_game_client_tests', coverage, checkedGroups: checks, cases };
await writeFile(new URL('resultats_calcules.json', root), JSON.stringify(result, null, 2) + '\n', 'utf8');
console.log(JSON.stringify({ coverage, checkedGroups: checks, cases: cases.length, result: 'Tous les contrôles mathématiques exécutés ont réussi. Aucun client Ankama ni runtime Godot testé.' }, null, 2));
