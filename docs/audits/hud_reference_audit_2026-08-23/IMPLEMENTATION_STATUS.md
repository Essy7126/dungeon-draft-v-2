# Statut d'implémentation du lot HUD / combat

Date de validation : 2026-08-23.

Ce lot réalise le premier chantier issu du verdict `PARTIAL_REBUILD`. Il ne
modifie ni les compétences, ni les données, ni les ressources d'Achille.

## Livré

- Snapshot de présentation commun : joueur libre, ciblage, résolution, tour
  adverse, modale et fin de combat.
- Verrou d'interaction partagé entre Battle, HUD et interfaces persistantes.
- Priorité d'Échap : modale de run, modale de combat, ciblage, puis pause.
- Propriétaire modal unique pour pause, inventaire, arbre et évolution.
- Masquage immédiat des tooltips lorsqu'une modale prend la main.
- Refus de déplacement ou de sort expliqué sans annuler le ciblage.
- HUD focalisé pendant le ciblage et désactivé uniformément pendant une action.
- Journal repliable et placements inspect/journal bornés pour le 720p.
- Ownership du tour adverse sans révélation d'intention.
- Confirmation de fin de tour si des PA ou PM restent, désactivable pour le
  combat courant.
- Dégâts de l'attaque de base alignés sur l'impact visuel, avant la récupération.
- Issue locale victoire/défaite avant le flow post-combat existant.
- Galerie de validation reproductible aux résolutions 1280×720 et 1920×1080.

## Preuves

- 18 tests ciblés passent, 118 assertions, sur le contrat de présentation, les
  modales, les tooltips, Échap et le HUD Recraft.
- Le test final du composant HUD passe 7/7, 57 assertions.
- Douze captures de présentation passent : six états aux deux résolutions.
- Les six salles First Run passent la capture réelle à 1920×1080 : formations,
  comptes d'ennemis, cellules uniques et ancrages visibles.

Les captures générées sont dans
`artifacts/combat_presentation_validation/`. Le runner versionné est
`tools/capture_combat_presentation_validation.tscn`.

## Restant hors de ce lot

- Extraire l'héritage `action_bar.gd` vers une interface HUD par composition.
- Réduire les trois chemins HUD historiques après inventaire complet des usages.
- Ajouter des marqueurs de grille non exclusivement colorimétriques.
- Auditer tout le parcours clavier, la réduction de mouvement et la narration.
- Attribuer puis corriger les fuites ObjectDB/RID historiques observées en fin
  de processus; les runners passent mais Godot signale encore ces allocations.
- Revalider le flow continu dernier impact → post-combat → retour monde sur une
  partie automatisée complète, au-delà de la chaîne locale couverte ici.
