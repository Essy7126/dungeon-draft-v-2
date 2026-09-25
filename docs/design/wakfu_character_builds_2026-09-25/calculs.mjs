import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';

const dir = path.dirname(fileURLToPath(import.meta.url));
const round = n => Math.round(n * 1e6) / 1e6;
export function calculate({ check = false } = {}) {
  const cases = [];
  function add(id, title, sourceIds, assumptions, actual, expected, lesson) {
    assert.deepEqual(actual, expected, id);
    cases.push({ id, title, sourceIds, assumptions, result: actual, lesson });
  }

  const movements = ['A', 'A', 'B', 'C', 'D'];
  const credited = new Set(); let ap = 0;
  for (const cast of movements) if (!credited.has(cast) && ap < 3) { credited.add(cast); ap++; }
  add('W01', 'Tacticien : deux plafonds distincts', [7982],
    'A désigne un seul lancement déplaçant deux bombes ; B/C/D sont trois autres lancements. Événements admissibles. Seul le remboursement est calculé, pas la perte de niveaux après plafond.',
    { events: movements.length, spells: new Set(movements).size, refundedAP: ap },
    { events: 5, spells: 4, refundedAP: 3 }, 'Ni un PA par bombe sans limite, ni quatre PA parce que quatre sorts ont déplacé une bombe.');

  const masks = ['A', 'A', 'B', 'C']; let current = 'A'; let refund = 0;
  for (const mask of masks) { if (mask !== current && refund === 0) refund = 2; current = mask; }
  add('W02', 'Bas les masques : différence et plafond', [7094],
    'Le personnage commence avec A ; les choix sans changement ne déclenchent rien. Le coût des changements ne figure pas dans le gain brut.',
    { refundedAP: refund }, { refundedAP: 2 }, 'Deux changements admissibles ne rendent pas quatre PA.');

  add('W03', 'Mini-Bond : payer plusieurs budgets', [5103],
    'Trois lancements légaux ; aucun autre modificateur. On ne calcule ni trajet ni portée cumulée traversable.',
    { AP: 3 * 2, WP: 3, casts: 3 }, { AP: 6, WP: 3, casts: 3 },
    'Le coût appartient à l’économie WAKFU ; notre personnage V1 à quatre PA ne peut copier cette séquence.');

  const maxHP = 1000 * 0.7;
  const life = [350, 130, 120, 300, 320, 130, 300];
  let low = false, high = false, armor = 0;
  for (let i = 1; i < life.length; i++) {
    if (life[i - 1] >= maxHP * 0.2 && life[i] < maxHP * 0.2 && !low) { low = true; armor += maxHP * 0.15; }
    if (life[i - 1] <= maxHP * 0.4 && life[i] > maxHP * 0.4 && !high) { high = true; armor += maxHP * 0.15; }
  }
  add('W04', 'Pacte de sang : passages plutôt que présence', [5053],
    'Base 1 000 PV, PV max réduits avant les seuils. Toutes les transitions sont dans une même fenêtre de compteurs ; aucun coup mortel. Trajectoire artificielle pour tester les caps, pas un combo garanti.',
    { maxHP, lower: maxHP * 0.2, upper: maxHP * 0.4, armor },
    { maxHP: 700, lower: 140, upper: 280, armor: 210 },
    'Les séjours sous 20 % et les deuxièmes passages ne redonnent pas chacun une couche d’armure.');

  const heals = [0.30, 0.3499, 0.35, 0.40].map(ratio => 100 * (ratio < 0.35 ? 2 : 0.25));
  add('W05', 'Jeu dangereux : frontière à 35 %', [7214],
    'Soin brut 100, sans autres modificateurs ni soin excédentaire. Le seuil est évalué avant cette instance ; cette convention doit être contrôlée dans le client.',
    { rawHeals: heals }, { rawHeals: [200, 200, 25, 25] },
    'Une moyenne de PV masque une discontinuité de facteur huit entre les deux fenêtres.');

  const digest = count => ({ events: Math.min(count, 5), rage: Math.min(count, 5) * 4, rawHealFor1000HP: Math.min(count, 5) * 40 });
  add('W06', 'Digestion : plafond sur les événements', [7555],
    'Fenêtre unique du compteur, PV max 1 000, événements déjà qualifiés, pas de modificateur de soin ni perte par soin excédentaire. Ne tranche pas le reset entre tours des combattants.',
    { three: digest(3), seven: digest(7) },
    { three: { events: 3, rage: 12, rawHealFor1000HP: 120 }, seven: { events: 5, rage: 20, rawHealFor1000HP: 200 } },
    'Fractionner encore les dégâts après le cinquième événement ne produit plus de gain dans cette fenêtre.');

  add('W07', 'Virevolte : accès à l’angle', [7105],
    'Dégâts de référence identiques par attaque ; aucun autre bonus DI ni multiplicateur d’orientation. 60 % des attaques de côté, 40 % de face.',
    { relativeOutput: round(0.6 * 1.25 + 0.4 * 0.75), breakEvenSideShare: 0.5 },
    { relativeOutput: 1.05, breakEvenSideShare: 0.5 },
    'Le gain moyen est ici 5 %, et non 25 %. La fréquence des positions légales fait partie de la balance.');

  add('W08', 'Guerrier invocateur : quel acteur produit ?', [7331],
    'Deux répartitions de 200 dégâts bruts ; aucun autre bonus DI. Les +20/−20 points se lisent donc ici comme 1,2/0,8. Aucun soin inclus.',
    { petHeavy: round(60 * 1.2 + 140 * 0.8), heroHeavy: round(140 * 1.2 + 60 * 0.8) },
    { petHeavy: 184, heroHeavy: 216 },
    'Le même passif donne −8 % ou +8 % selon la répartition de contribution.');

  function survive(delay) {
    let hp = 20 + (delay ? 50 : 100);
    hp -= 80;
    const aliveBeforeDeferredHeal = hp > 0;
    if (aliveBeforeDeferredHeal && delay) hp += 50;
    return { aliveBeforeDeferredHeal, finalHP: Math.max(0, hp) };
  }
  add('W09', 'Délai : même soin nominal, survie différente', [5451],
    '20 PV avant soin, PV max au moins 120, soin brut 100 ; ennemi inflige 80 avant le prochain tour du bénéficiaire. Aucun autre effet et aucune résurrection.',
    { immediate: survive(false), delayed: survive(true) },
    { immediate: { aliveBeforeDeferredHeal: true, finalHP: 40 }, delayed: { aliveBeforeDeferredHeal: false, finalHP: 0 } },
    'La seconde moitié ne peut sauver rétroactivement une cible morte.');

  const gear = { distance: 1000, melee: 200 };
  add('W10', 'Échange asynchrone : conversion non additive', [8272],
    'Statistiques fictives stables, aucune modification temporaire ; on isole la reprise de maîtrise et pas la formule complète des dégâts.',
    { convertedMelee: gear.distance, incorrectSum: gear.distance + gear.melee },
    { convertedMelee: 1000, incorrectSum: 1200 },
    'Un parseur additionnant les deux maîtrises inventerait 200 points de puissance.');

  add('W11', 'Fermentation : dépendance aux PV max', [8597],
    'Portage valide en fin de tour ; PV max 800 puis 1 200, aucun bonus d’armure. Le 245 isolé de la fiche n’est pas additionné.',
    { armorAt800: 800 * 0.2, armorAt1200: 1200 * 0.2 },
    { armorAt800: 160, armorAt1200: 240 },
    'Un test client à deux valeurs de PV permettrait de distinguer une formule proportionnelle d’un montant fixe.');

  const colors = ['white', 'white', 'white', 'white']; let wp = 0;
  for (let i = 1; i < colors.length; i++) if (colors[i] === 'white' && colors[i - 1] === 'white' && wp === 0) wp++;
  add('W12', 'Tarot : plusieurs paires, un seul gain', [5246],
    'Quatre cartes blanches légales dans un même tour, indépendamment des coûts et de leur accessibilité. Aucune paire noire : le cas du compteur mixte reste ouvert.',
    { WP: wp }, { WP: 1 }, 'Le plafond porte sur la récompense de séquence, pas sur chaque sous-séquence détectée.');

  const wpMax = 12 - 6; const start = 5; const eligibleKills = 3;
  const end = Math.min(wpMax, start + eligibleKills * 2);
  add('W13', 'Assimilation : revenu théorique et revenu utilisable', [7196],
    'Maximum initial fictif 12, réduit à 6 ; réserve 5 ; trois éliminations admissibles sans dépense intermédiaire. Le maximum 12 est un paramètre d’exemple, pas une affirmation sur toute classe équipée.',
    { maxWP: wpMax, finalWP: end, wastedWP: start + eligibleKills * 2 - end },
    { maxWP: 6, finalWP: 6, wastedWP: 5 },
    'Une petite réserve transforme un remboursement généreux en excédent perdu ; l’ordre des dépenses compte.');

  const growth = [1, 2, 3].map(turn => turn);
  add('W14', 'Croissance : le coût de recommencer', [8152],
    'Poupée présente trois fins de tour sans interruption ; uniquement le bonus +1 du passif, sans croissance normale. Une transformation en graine enlève ensuite les niveaux.',
    { bonusByTurn: growth, bonusAfterReset: 0, bonusLost: growth.at(-1) },
    { bonusByTurn: [1, 2, 3], bonusAfterReset: 0, bonusLost: 3 },
    'Le repositionnement via recyclage peut détruire de l’investissement ; ne pas lui attribuer un coût nul.');

  const schedule = cooldown => Array.from({ length: 6 }, (_, i) => i + 1).filter(t => (t - 1) % cooldown === 0);
  add('W15', 'Bouclier immédiat : disponibilité sur une cible', [6991],
    'Exemple abstrait : délai de base choisi à deux tours, augmenté de deux ; disponibilité initiale tour 1, observation jusqu’au tour 6. Cette convention de recharge n’est pas une mesure d’un bouclier particulier.',
    { baseline: schedule(2), immediateVariant: schedule(4) },
    { baseline: [1, 3, 5], immediateVariant: [1, 5] },
    'Le bénéfice de l’immédiateté doit être comparé à une intervention future absente, pas seulement au montant du premier bouclier.');

  const result = { scope: 'Modèles isolés, pas un simulateur du client WAKFU ni de combats Godot', scenarios: cases.length, assertions: cases.length, cases };
  let md = '# Calculs WAKFU : ressources, seuils et temporalité\n\n';
  md += `${cases.length} scénarios déterministes, ${cases.length} assertions exécutées par [calculs.mjs](calculs.mjs). Les entrées sont des contrats documentaires et des hypothèses explicites ; les résultats ne certifient pas le client.\n\n`;
  for (const item of cases) {
    md += `## ${item.id} — ${item.title}\n\n**Fiches :** ${item.sourceIds.join(', ')} ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).\n\n**Hypothèses.** ${item.assumptions}\n\n`;
    md += '```json\n' + JSON.stringify(item.result, null, 2) + '\n```\n\n';
    md += `**Conséquence.** ${item.lesson}\n\n`;
  }
  for (const [name, body] of Object.entries({ 'resultats_calcules.json': JSON.stringify(result, null, 2) + '\n', 'CALCULS.md': md.trimEnd() + '\n' })) {
    if (check) assert.equal(fs.readFileSync(path.join(dir, name), 'utf8').replaceAll('\r\n', '\n'), body, `Dérive ${name}`);
    else fs.writeFileSync(path.join(dir, name), body);
  }
  return result;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = calculate({ check: process.argv.includes('--check') });
  console.log(`${result.scenarios} scénarios, ${result.assertions} assertions réussies.`);
}
