// Modèles analytiques documentaires ; ce fichier n'exécute pas le moteur WAVEN.
import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';

const checks = [];
function near(name, actual, expected, epsilon = 1e-10) {
  assert.ok(Math.abs(actual - expected) < epsilon, `${name}: ${actual} != ${expected}`);
  checks.push(name);
}
function choose(n, k) {
  if (k < 0 || k > n) return 0;
  let result = 1;
  for (let i = 1; i <= k; i++) result *= (n - i + 1) / i;
  return result;
}
function enumerateHands(n, h, visit, hand = [], start = 0) {
  if (hand.length === h) { visit(hand); return; }
  for (let i = start; i <= n - h + hand.length; i++) {
    enumerateHands(n, h, visit, [...hand, i], i + 1);
  }
}
const fixture = {
  source: 'https://www.waven-build.com/builds/10898',
  scope: 'Valeurs du constructeur, pas une mesure en combat. Talents inchangés aux deux positions du curseur.',
  base: { hp: 394, attack: 28 },
  skillBonuses: { hp: 0.50, attack: 1.55, points: 250 },
  equipment50: { hp: 3.90, attack: 4.70 },
  equipment1: { hp: 0.96, attack: 0.29 },
};
fixture.reconstructed50 = {
  hp: Math.round(394 * (1 + 3.90 + 0.50)),
  attack: Math.round(28 * (1 + 4.70 + 1.55)),
};
fixture.reconstructed1 = {
  hp: Math.round(394 * (1 + 0.96 + 0.50)),
  attack: Math.round(28 * (1 + 0.29 + 1.55)),
};
near('PV affichés curseur 50', fixture.reconstructed50.hp, 2128);
near('ATK affichée curseur 50', fixture.reconstructed50.attack, 203);
near('PV affichés curseur 1, talents conservés', fixture.reconstructed1.hp, 969);
near('ATK affichée curseur 1, talents conservés', fixture.reconstructed1.attack, 80);

const costs = [6, 3, 4, 3, 4, 3, 6, 2, 3, 3, 4, 3, 3, 4, 3];
const deck = { count: costs.length, sumAP: costs.reduce((a, b) => a + b, 0) };
deck.meanAP = deck.sumAP / deck.count;
near('15 coûts relevés', deck.count, 15);
near('Somme des coûts imprimés', deck.sumAP, 54);
near('Moyenne des coûts imprimés', deck.meanAP, 3.6);

const companions = [
  { name: 'Champion Croulant', air: 3, earth: 2, water: 0, fire: 0 },
  { name: 'Yugo', air: 7, earth: 0, water: 0, fire: 0 },
  { name: 'Lance Dur', air: 2, earth: 0, water: 3, fire: 2 },
  { name: 'Épinette', air: 2, earth: 2, water: 0, fire: 0 },
];
const gauges = Object.fromEntries(['air', 'earth', 'water', 'fire'].map(
  color => [color, companions.reduce((sum, c) => sum + c[color], 0)]));
gauges.total = Object.values(gauges).reduce((a, b) => a + b, 0);
near('Jauges des quatre premières invocations', gauges.total, 23);
near('Goulot air', gauges.air, 14);

function alignedCells(x, y, size = 7, radius = 2) {
  const cells = [];
  for (let a = 0; a < size; a++) for (let b = 0; b < size; b++) {
    const d = Math.abs(a - x) + Math.abs(b - y);
    if (d > 0 && d <= radius && (a === x || b === y)) cells.push([a, b]);
  }
  return cells;
}
const pikuxala = {
  scope: 'Coefficient PvE 0.17, ATK maintenue fixe ; ni Instabilité, ni arrondis, ni mitigation.',
  centerCells7x7: alignedCells(3, 3).length,
  cornerCells7x7: alignedCells(0, 0).length,
  attack: 203, teleports: 2, targetsPerTeleport: 2,
  passiveDamage: 203 * 0.60 * 2 * 2,
  saut: { upfrontAP: 3, successfulTeleports: 2, reserveWithEfficacite: 2, eventualNetAP: 1 },
};
near('Croix à portée 2 au centre', pikuxala.centerCells7x7, 8);
near('Croix à portée 2 dans un coin', pikuxala.cornerCells7x7, 4);
near('Deux téléportations, deux cibles', pikuxala.passiveDamage, 487.2);

const armor = {
  scope: 'Scénario fixe H=2000, quatre bonus armure additifs ; pas un relevé du DPS total de Justelame.',
  hp: 2000,
  old: 2000 * 0.20 * (1 + 4 * 0.20),
  next: 2000 * 0.15 * (1 + 4 * 0.10),
};
armor.relativeChange = armor.next / armor.old - 1;
armor.frappeExtra = { old: armor.old * 0.65, next: armor.next * 0.65 };
armor.endPulse = { old: armor.old * 0.30, next: armor.next * 0.30 };
near('Armure ancien scénario', armor.old, 720);
near('Armure nouveau scénario', armor.next, 420);
near('Baisse composée conditionnelle', armor.relativeChange, -5 / 12);

const piven = {
  scope: 'Illustration conditionnelle de l’ordre de résolution. Delta=0.5 A0 est une hypothèse, pas la formule du moteur.',
  auras: 5,
  normalizedFixedAttackDamage: 5 * 0.60,
  normalizedBuffAfterEach: 0.60 * (5 + 10 * 0.50),
  normalizedBuffBeforeEach: 0.60 * (5 + 15 * 0.50),
};
near('Piven ATK constante', piven.normalizedFixedAttackDamage, 3);
near('Piven hypothèse buff après', piven.normalizedBuffAfterEach, 6);
near('Piven hypothèse buff avant', piven.normalizedBuffBeforeEach, 7.5);

const survival = {
  scope: 'Composition annoncée juin 2026 ; tirage uniforme sans remise, sans mulligan, tuteur ou remplacement préalable.',
  deck: 16, openingHand: 5, heroCards: 4, companionCards: 1, impactCards: 11,
  totalHands: choose(16, 5),
  companionInOpening: 5 / 16,
  companionAmongSevenDistinctSeen: 7 / 16,
  atLeastOneHeroSpell: 1 - choose(12, 5) / choose(16, 5),
  twoSpecifiedCards: choose(14, 3) / choose(16, 5),
  expectedImpactInOpening: 5 * 11 / 16,
};
let total = 0, withCompanion = 0, withHero = 0, withPair = 0;
enumerateHands(16, 5, hand => {
  total++;
  if (hand.includes(0)) withCompanion++;
  if (hand.some(i => i >= 1 && i <= 4)) withHero++;
  if (hand.includes(1) && hand.includes(2)) withPair++;
});
near('Énumération des mains', total, 4368);
near('Compagnon, formule vs énumération', withCompanion / total, survival.companionInOpening);
near('Sort de héros, formule vs énumération', withHero / total, survival.atLeastOneHeroSpell);
near('Duo exact, formule vs énumération', withPair / total, survival.twoSpecifiedCards);

const crit = {
  scope: 'Illustration du témoignage Reddit : p=45%, multiplicateur supposé exactement 3 et jets indépendants.',
  p: 0.45, baseAttack: 359, multiplier: 3,
  expectedDamage: 359 * (1 + 0.45 * (3 - 1)),
  criticalPeak: 359 * 3,
  oneAttackNoCrit: 0.55,
  atLeastOneCritTwoAttacks: 1 - 0.55 ** 2,
};
near('Dégâts moyens sous hypothèse critique', crit.expectedDamage, 682.1);
near('Au moins un critique en deux jets', crit.atLeastOneCritTwoAttacks, 0.6975);
const enemies = {
  scope: 'Règles du wiki non datées, avant protections et arrondis ; exemples analytiques.',
  toxicThreeSources: [2000, 4000].map(hp => ({ hp, rawDamage: hp * 0.05 * 3, fraction: 0.15 })),
  odaimThreeAlliesArmorPerAttackUnit: 0.5 * 3,
  rarpieWithThreeOtherRatsAttackMultiplier: 1 + 3 * 0.25,
  poolAttacksWithFourReplays: 1 + 4,
  pramiumFourMechanismsThreeCompanionAttacksPotentialActivations: 4 * 3,
};
near('Rarpie avec trois autres rats', enemies.rarpieWithThreeOtherRatsAttackMultiplier, 1.75);
near('Toxique conserve la fraction des PV', enemies.toxicThreeSources[1].rawDamage / 4000, 0.15);

const output = {
  date: '2026-09-26', nature: 'calculs analytiques, pas simulation du moteur WAVEN',
  fixture, deck, companions, gauges, pikuxala, armor, piven, survival, crit, enemies,
  verification: { assertions: checks.length, checks, enumeratedOpeningHands: total },
};
writeFileSync(new URL('./CALCULS.json', import.meta.url), JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ assertions: checks.length, openingHandsEnumerated: total, survival, armor, output: 'CALCULS.json' }, null, 2));
