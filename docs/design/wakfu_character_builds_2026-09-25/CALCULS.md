# Calculs WAKFU : ressources, seuils et temporalité

15 scénarios déterministes, 15 assertions exécutées par [calculs.mjs](calculs.mjs). Les entrées sont des contrats documentaires et des hypothèses explicites ; les résultats ne certifient pas le client.

## W01 — Tacticien : deux plafonds distincts

**Fiches :** 7982 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** A désigne un seul lancement déplaçant deux bombes ; B/C/D sont trois autres lancements. Événements admissibles. Seul le remboursement est calculé, pas la perte de niveaux après plafond.

```json
{
  "events": 5,
  "spells": 4,
  "refundedAP": 3
}
```

**Conséquence.** Ni un PA par bombe sans limite, ni quatre PA parce que quatre sorts ont déplacé une bombe.

## W02 — Bas les masques : différence et plafond

**Fiches :** 7094 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Le personnage commence avec A ; les choix sans changement ne déclenchent rien. Le coût des changements ne figure pas dans le gain brut.

```json
{
  "refundedAP": 2
}
```

**Conséquence.** Deux changements admissibles ne rendent pas quatre PA.

## W03 — Mini-Bond : payer plusieurs budgets

**Fiches :** 5103 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Trois lancements légaux ; aucun autre modificateur. On ne calcule ni trajet ni portée cumulée traversable.

```json
{
  "AP": 6,
  "WP": 3,
  "casts": 3
}
```

**Conséquence.** Le coût appartient à l’économie WAKFU ; notre personnage V1 à quatre PA ne peut copier cette séquence.

## W04 — Pacte de sang : passages plutôt que présence

**Fiches :** 5053 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Base 1 000 PV, PV max réduits avant les seuils. Toutes les transitions sont dans une même fenêtre de compteurs ; aucun coup mortel. Trajectoire artificielle pour tester les caps, pas un combo garanti.

```json
{
  "maxHP": 700,
  "lower": 140,
  "upper": 280,
  "armor": 210
}
```

**Conséquence.** Les séjours sous 20 % et les deuxièmes passages ne redonnent pas chacun une couche d’armure.

## W05 — Jeu dangereux : frontière à 35 %

**Fiches :** 7214 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Soin brut 100, sans autres modificateurs ni soin excédentaire. Le seuil est évalué avant cette instance ; cette convention doit être contrôlée dans le client.

```json
{
  "rawHeals": [
    200,
    200,
    25,
    25
  ]
}
```

**Conséquence.** Une moyenne de PV masque une discontinuité de facteur huit entre les deux fenêtres.

## W06 — Digestion : plafond sur les événements

**Fiches :** 7555 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Fenêtre unique du compteur, PV max 1 000, événements déjà qualifiés, pas de modificateur de soin ni perte par soin excédentaire. Ne tranche pas le reset entre tours des combattants.

```json
{
  "three": {
    "events": 3,
    "rage": 12,
    "rawHealFor1000HP": 120
  },
  "seven": {
    "events": 5,
    "rage": 20,
    "rawHealFor1000HP": 200
  }
}
```

**Conséquence.** Fractionner encore les dégâts après le cinquième événement ne produit plus de gain dans cette fenêtre.

## W07 — Virevolte : accès à l’angle

**Fiches :** 7105 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Dégâts de référence identiques par attaque ; aucun autre bonus DI ni multiplicateur d’orientation. 60 % des attaques de côté, 40 % de face.

```json
{
  "relativeOutput": 1.05,
  "breakEvenSideShare": 0.5
}
```

**Conséquence.** Le gain moyen est ici 5 %, et non 25 %. La fréquence des positions légales fait partie de la balance.

## W08 — Guerrier invocateur : quel acteur produit ?

**Fiches :** 7331 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Deux répartitions de 200 dégâts bruts ; aucun autre bonus DI. Les +20/−20 points se lisent donc ici comme 1,2/0,8. Aucun soin inclus.

```json
{
  "petHeavy": 184,
  "heroHeavy": 216
}
```

**Conséquence.** Le même passif donne −8 % ou +8 % selon la répartition de contribution.

## W09 — Délai : même soin nominal, survie différente

**Fiches :** 5451 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** 20 PV avant soin, PV max au moins 120, soin brut 100 ; ennemi inflige 80 avant le prochain tour du bénéficiaire. Aucun autre effet et aucune résurrection.

```json
{
  "immediate": {
    "aliveBeforeDeferredHeal": true,
    "finalHP": 40
  },
  "delayed": {
    "aliveBeforeDeferredHeal": false,
    "finalHP": 0
  }
}
```

**Conséquence.** La seconde moitié ne peut sauver rétroactivement une cible morte.

## W10 — Échange asynchrone : conversion non additive

**Fiches :** 8272 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Statistiques fictives stables, aucune modification temporaire ; on isole la reprise de maîtrise et pas la formule complète des dégâts.

```json
{
  "convertedMelee": 1000,
  "incorrectSum": 1200
}
```

**Conséquence.** Un parseur additionnant les deux maîtrises inventerait 200 points de puissance.

## W11 — Fermentation : dépendance aux PV max

**Fiches :** 8597 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Portage valide en fin de tour ; PV max 800 puis 1 200, aucun bonus d’armure. Le 245 isolé de la fiche n’est pas additionné.

```json
{
  "armorAt800": 160,
  "armorAt1200": 240
}
```

**Conséquence.** Un test client à deux valeurs de PV permettrait de distinguer une formule proportionnelle d’un montant fixe.

## W12 — Tarot : plusieurs paires, un seul gain

**Fiches :** 5246 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Quatre cartes blanches légales dans un même tour, indépendamment des coûts et de leur accessibilité. Aucune paire noire : le cas du compteur mixte reste ouvert.

```json
{
  "WP": 1
}
```

**Conséquence.** Le plafond porte sur la récompense de séquence, pas sur chaque sous-séquence détectée.

## W13 — Assimilation : revenu théorique et revenu utilisable

**Fiches :** 7196 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Maximum initial fictif 12, réduit à 6 ; réserve 5 ; trois éliminations admissibles sans dépense intermédiaire. Le maximum 12 est un paramètre d’exemple, pas une affirmation sur toute classe équipée.

```json
{
  "maxWP": 6,
  "finalWP": 6,
  "wastedWP": 5
}
```

**Conséquence.** Une petite réserve transforme un remboursement généreux en excédent perdu ; l’ordre des dépenses compte.

## W14 — Croissance : le coût de recommencer

**Fiches :** 8152 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Poupée présente trois fins de tour sans interruption ; uniquement le bonus +1 du passif, sans croissance normale. Une transformation en graine enlève ensuite les niveaux.

```json
{
  "bonusByTurn": [
    1,
    2,
    3
  ],
  "bonusAfterReset": 0,
  "bonusLost": 3
}
```

**Conséquence.** Le repositionnement via recyclage peut détruire de l’investissement ; ne pas lui attribuer un coût nul.

## W15 — Bouclier immédiat : disponibilité sur une cible

**Fiches :** 6991 ; voir [lectures complémentaires](LECTURES_COMPLEMENTAIRES.md).

**Hypothèses.** Exemple abstrait : délai de base choisi à deux tours, augmenté de deux ; disponibilité initiale tour 1, observation jusqu’au tour 6. Cette convention de recharge n’est pas une mesure d’un bouclier particulier.

```json
{
  "baseline": [
    1,
    3,
    5
  ],
  "immediateVariant": [
    1,
    5
  ]
}
```

**Conséquence.** Le bénéfice de l’immédiateté doit être comparé à une intervention future absente, pas seulement au montant du premier bouclier.
