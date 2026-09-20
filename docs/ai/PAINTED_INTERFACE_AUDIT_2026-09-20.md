# Interfaces peintes — audit et intégration

Demande : compléter les assets, respecter la DA et améliorer les interfaces réelles.
Travail précédent non commité conservé. Aucun changement de règles ou d'équilibrage.

## Audit initial

- 60 techniques de classes : SVG filaires, silhouettes répétées et minuscules numéros
  intégrés aux dessins. Rupture avec les décors peints et objets émeraude existants.
- 24 modèles d'équipement / 72 définitions : pictogrammes génériques, peu reconnaissables.
- 4 runes : icônes empruntées à des sorts, donc mauvaise distinction objet/action.
- Emplacements vides : dessins de véritables équipements, absence de silhouette neutre.
- Cadres de cartes : texture conçue pour un format portrait étirée sur de petits boutons.
- Inventaire : trois colonnes peu séparées ; sélection et équipement insuffisamment repérés.
- Deck : surface importante consacrée à des lignes vides, illustrations à 52 px.

## Production

Huit atlas originaux générés avec imagegen intégré : 60 techniques, 4 emblèmes,
24 objets, 4 runes, 6 reliques, 4 consommables, 6 armes et 4 protections classiques.
Six silhouettes SVG neutres complètent les emplacements vides.
Sources et prompts exacts dans
`assets/catabase/class_icons_painted_v1/`. Les 3 paliers utilisent le même modèle
d'objet et restent indiqués par rareté/palier ; pas de faux équipement supplémentaire.
AtlasTexture, frontières de cellules calculées depuis les dimensions réelles,
filtrage limité à la région, marges de sécurité et bandes de lignes mesurées
sur la planche de reliques contre les fragments voisins,
mipmaps et cache commun. Les images sources ne sont pas modifiées.
Chargement différé : aucun préchargement PNG lors de l'analyse des autoloads avant
la première importation. Les PNG/SVG doivent faire partie des ressources exportées,
comme le reste du catalogue d'icônes dynamique existant.

DA : silhouettes pleines dessinées, plans gouachés, bronze chaud, fond émeraude,
ivoire pour les arêtes ; accent cramoisi / ochre / sauge / violet pour les classes.
Les formes, les libellés et les états de sélection complètent les couleurs.

## Références et décisions

- Captures Dofus fournies : grille d'icônes, fiche séparée, butin en ligne,
  personnage entouré d'emplacements. Aucun asset de Dofus repris.
- [Game Accessibility Guidelines — éléments interactifs](https://gameaccessibilityguidelines.com/give-a-clear-indication-that-interactive-elements-are-interactive/) :
  différence visuelle cohérente entre repos, survol et sélection.
- [W3C — contraste des icônes](https://www.w3.org/WAI/WCAG22/Techniques/general/G207.html) :
  contours et silhouettes contrastés, états explicites en plus de la teinte.
  Ces choix ne constituent pas une certification d'accessibilité.

## Validation

Première passe visuelle : 334 contrôles / 48 captures, PASS dans
`artifacts/dev/painted-interface/report.json`. Import et galerie finale sans erreur
moteur. Galerie des 112 dessins inspectée à taille réelle ; les bandes des reliques
ont été mesurées pour éviter de couper les objets ou de prendre le voisin.

Contrôles de règles déjà terminés :
- Classes / sauvegardes / équipements : 17 tests, 1420 assertions, PASS,
  `artifacts/dev/20260920-141712-test-test_unit_test_catabase_class_run.gd-c3fde285/summary.json`.
- HUD commun : 11 tests, 96 assertions, PASS,
  `artifacts/dev/20260920-141950-test-test_unit_test_recraft_combat_hud_v1.gd-4ba9e0fa/summary.json`.

Dernière passe terminée : 34 tests / 2246 assertions, PASS au total.
- Assets : 2 tests / 526 assertions,
  `artifacts/dev/20260920-143644-test-test_unit_test_class_painted_icons.gd-91b5a133/summary.json`.
- Survol : 4 tests / 204 assertions,
  `artifacts/dev/20260920-143726-test-test_unit_test_spell_hover_card.gd-5cf09c42/summary.json`.
- UI finale : 338 contrôles / 48 captures, PASS,
  `artifacts/dev/painted-interface-final/report.json`, sans SCRIPT ERROR dans le journal.
Captures de combat, butin, inventaire et deck inspectées en 720p et 1080p.
La fiche de survol reste hors de la grille et les états sélectionné/équipé sont visibles.
La sonde UI joue une carte et un tour ennemi réels ; les victoires suivantes sont
injectées pour vérifier les fenêtres. Elle ne mesure pas l'équilibrage.
