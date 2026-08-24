# Statut d'implémentation des lots HUD / combat

Date de validation : 2026-08-23.

Ces lots réalisent les deux premiers chantiers issus du verdict
`PARTIAL_REBUILD`. Ils ne modifient ni les compétences, ni les données, ni les
ressources d'Achille.

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
- Port `Battle ↔ HUD` explicite, partagé par le HUD persistant, Recraft et le
  fallback historique, sans supprimer la compatibilité `action_bar.gd`.
- Connexions d'intentions réversibles et snapshot de cycle de vie du HUD.
- Marqueurs de cases non exclusivement colorimétriques : déplacement,
  engagement limité, attaque, sort, zone d'effet et déploiement ont chacun un
  symbole distinct en plus de leur couleur.
- Capture du dernier frame de bataille avant l'overlay de victoire, idempotente
  jusqu'au post-combat.
- Raccourcis clavier stables : `M` déplacer, `A` attaquer, `F` finir le tour,
  `I` inventaire, `K` compétences et `1–4` pour la barre affichée.
- Option « ANIMATIONS : RÉDUITES » accessible au clavier dans le menu pause ;
  propagation immédiate aux bannières de tour, feedbacks, choix d'évolution,
  écran de victoire, post-combat et textes flottants.
- Parcours automatisé réel : First Run de production → déploiement → coup final
  injecté → victoire → post-combat → transition vers la salle suivante.

## Preuves

- 18 tests ciblés passent, 118 assertions, sur le contrat de présentation, les
  modales, les tooltips, Échap et le HUD Recraft.
- Le test final du composant HUD passe 7/7, 57 assertions.
- Douze captures de présentation passent : six états aux deux résolutions.
- Les six salles First Run passent la capture réelle à 1920×1080 : formations,
  comptes d'ennemis, cellules uniques et ancrages visibles.
- Le lot port / accessibilité passe 19/19 tests, 287 assertions.
- Le flow, la présentation et les grilles passent 38/38 tests, 380 assertions.
- Le cycle de vie asynchrone entre fin d'action et changement de salle passe
  10/10 tests, 32 assertions ; son ancien double de Battle a été réaligné sur
  le contrat d'identifiants d'action de production.
- Le post-combat passe 21/23 tests, 268/273 assertions. Les deux échecs sont une
  divergence préexistante du catalogue de récompenses et non une régression HUD.
- Le runner continu `validate_combat_to_next_room_flow.tscn` passe tous ses
  contrôles. Il prouve un seul HUD persistant pendant le combat, zéro contexte
  lié dès le post-combat, zéro UnitView après changement de scène et zéro HUD
  persistant après nettoyage du run.

Les captures générées sont dans
`artifacts/combat_presentation_validation/`. Le runner versionné est
`tools/capture_combat_presentation_validation.tscn`.

Le rapport du parcours continu et sa mesure de cycle de vie sont dans
`artifacts/combat_flow_validation/report.json`. Son runner est
`tools/validate_combat_to_next_room_flow.tscn`.

## Restant après ces lots

- Retirer physiquement les anciens chemins HUD devenus inutiles seulement après
  une période de compatibilité et un inventaire complet de leurs consommateurs.
- Ajouter, si une vraie page d'options globale est créée, la persistance disque
  du choix « animations réduites » ; le choix reste actuellement conservé pour
  toute la session et entre les runs.
- Compléter la narration lecteur d'écran des informations tactiques complexes ;
  les noms accessibles, le focus et les raisons d'indisponibilité sont présents,
  mais aucune synthèse vocale spécifique au plateau n'est introduite ici.
- Les avertissements ObjectDB/RID de fermeture restent globaux au projet. La
  mesure runtime exclut une rétention du HUD : le HUD, son contexte et les
  UnitView reviennent tous à zéro après nettoyage. Leur attribution restante
  concerne le cache de ressources / rendu et sort du périmètre HUD.
