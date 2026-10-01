# Fondations de progression et de contenu à long terme

Étude du 30 septembre 2026, suite de « Auditer les idées de gameplay » et de
[la première proposition de progression](../progression_systeme_2026-09-30/README.md).
Le [Prototype v1](../../current/prototype_v1.md) reste le jeu actif. Aucun
changement de gameplay n'est effectué par ce dossier.

**Recommandation : conserver les six maîtrises ouvertes et bâtir un langage
commun d'effets, de sources, de coûts et d'accès.** La croissance de niveau
donne l'échelle ; cartes, placement, formes et objets changent la façon de
jouer ; copies et route déterminent combien de temps le plan reste possible.

- [Comparaisons et sources primaires](COMPARAISONS.md) : sept références de
  conception, puis le retour particulièrement utile de Waven.
- [Fondations statistiques et contrats](FONDATIONS.md) : unités, formule,
  composantes, budgets, événements, accès et puissance ressentie.
- [Calculs exacts et limites](CALCULS.md) : allocations, croissance 13–18,
  292 019 mains, défenses, stock, butin et espace de possibilités.
- [Construction, idées et acte II](CONSTRUCTION.md) : huit briques, premier lot,
  quatre interactions candidates, transition de Pâris et laboratoire de runs.
- [Laboratoire reproductible](laboratoire.py) et
  [rapport de cette exécution](../../../artifacts/dev/20260930-fondations-long-terme-final/resultats.json).

## Les décisions prioritaires

1. Fixer le contrat de composante et de source avant davantage de statuts,
   conversions, échos ou durées.
2. Calculer dégâts, garde, soin, contrôle et fiabilité dans leurs scénarios ;
   conserver un budget vectoriel, sans score universel qui additionne tout.
3. Compléter le contenu normal et son accès avant d'ajouter des statistiques
   que les cartes disponibles ne peuvent pas exploiter.
4. Faire des formes et objets des choix de cadence, de géométrie et de stock,
   transversaux aux classes et aux éléments.
5. Tester l'acte II à niveau 12 constant, puis un prolongement modéré 13–18 ;
   conserver le personnage et traiter le ravitaillement comme un budget.
6. Énumérer ce qui est petit et exact ; filtrer les interactions, puis exécuter
   les états légaux dans Godot et les campagnes continues.

## Résultats qui changent la conception

- 26→38 points : +38→+50 % de maîtrise mono, soit **+8,70 %** à P constant.
- Extrapolation géométrique de tout l'acte I vers 18 : P=243 contre 93 au 12.
  Un candidat à +4 % par niveau donne P=118. Aucune de ces extensions n'est jouable.
- Une ouverture à deux fonctions, trois copies chacune : **51,45 %** dans
  15 cartes, **16,53 %** dans 30. Doubler le répertoire ne garantit pas le plan.
- +10 points de résistance de 30 à 40 % : **+16,67 %** de PV effectifs contre
  ce canal ; les mêmes « 10 % » offensifs ont un autre rendement.
- Le produit cartésien actuel dépasse **1 664 milliards d'états** avant deck et
  formes. Il ignore accès et équivalence ; ce n'est pas un nombre de builds.

164 contrôles analytiques réussis ; les dix empreintes des preuves précédentes
concordent. Ces vérifications ne valident pas le plaisir, les quatre idées de
reliques/objets, ni une campagne d'acte II. Les prochains essais ont un périmètre
et des critères de sortie définis dans le plan de construction.

Pour reproduire les calculs, choisir un nouveau dossier :

```powershell
python docs/design/fondations_long_terme_2026-09-30/laboratoire.py --output-dir artifacts/dev/<nouvelle-execution>
```

Le script refuse d'écraser un rapport et d'écrire hors `artifacts/dev/`.
