# Icônes Catabase — 10 septembre 2026

> Cette direction vectorielle a été refusée par l’utilisateur hors carte. La reprise en illustrations peintes sobres est suivie dans `icones_emeraude_reprise.md`. Les résultats de tests ci-dessous concernent uniquement l’ancienne version.

197 SVG originaux intégrés, 179 Ko de sources. Générateur déterministe : `tools/ui_icons/build_icons.py`.
Manifeste : `assets/catabase/icons/manifest.json`. Bibliothèque : `ui/theme/catabase_icon_library.gd`.

## Direction graphique

Ivoire et or patiné sur fond encre vert. Accents sarcelle pour mobilité/chasse, cuivre rosé pour sang/feu, bleu pour givre/foudre, vert pour soin.
Silhouettes lisibles, traits réguliers, aucune ombre épaisse ni cadre biseauté dans l’icône. Les emplacements portent leurs propres états d’interaction.
Glyphes transparents de 64 px pour commandes/statistiques/états ; tuiles de 256 px pour sorts, équipements et maîtrises, sur une grille optique de 64 unités.
Mutation : un losange ; légende : deux losanges ; signature : étoile. Le motif familial reste reconnaissable.
Les silhouettes partagées représentent une même fonction ; les illustrations de personnages et décors restent des assets séparés.
Aucun asset de Baldur’s Gate n’a été copié.

## Couverture et intégration

- 43 glyphes de sorts pour les 46 sorts du catalogue (familles communes et formes améliorées).
- 38 objets : 12 Catabase, 24 récompenses du catalogue canonique, potion et parchemin de départ.
- 36 maîtrises du grimoire, quatre caractéristiques, six emblèmes et neuf statistiques.
- 17 commandes, huit ressources, 12 marqueurs de carte, six états de combat et 18 effets de progression.

Les catalogues communs desservent HUD, inventaire, récompenses, arbre, sélection, grimoire et carte. Le catalogue historique garde ses chemins de secours pour les anciennes peintures et les remplacements explicites.
Les informations cachées de l’arbre et de la carte passent toujours par le filtre de connaissance existant.
Les objets utilisent les mêmes glyphes dans leurs champs icon/inventory_icon/card_texture. Aucun coût, statistique ou comportement d’objet n’a changé.

## Corrections révélées par la vérification

- Les commandes du HUD réduisent explicitement les textures à 24 px, y compris dans la présentation premium sans session Catabase ; elles ne débordent plus sur Fin de tour.
- `TargetedSpellModifierData` copie le modificateur avant d’y placer la cible du wrapper. Acheter une maîtrise ne modifie plus la définition source ; la vérification de son empreinte reste active.
- La fixture de combat statique libère son historique d’effets et appelle `terrain.dispose()` pour terminer sans fuite de références.
- Les tests d’atlas conservent la validation des archives et vérifient les glyphes réellement affichés par le grimoire.

## Vérifications finales

Rapport consolidé : `artifacts/dev/20260910-212140-icons-da-validated/summary.json`.
105 tests / 4787 assertions / 11 suites, tous passés.
66 captures / 1229 contrôles rendus, tous passés : HUD, inventaire, menus/grimoire, progression, route, haltes et infobulles en 1280 × 720 et 1920 × 1080 ; six planches supplémentaires comparent les icônes à 48 et 24 px.
Import et rasterisation des 197 icônes vérifiés, avec présence de pixels de silhouette à 24 px. Régénération byte-identique vérifiée. Les nouveaux scripts ont passé le formateur ciblé.
Inspection visuelle : toutes les familles sur planches, HUD six sorts, inventaire sélectionné, grimoire et carte. Les captures utilisent les composants et services réels avec des états de combat/récompenses préparés, sans partie complète.
Un premier passage game en 1080p a manqué deux clics ; le même scénario isolé a ensuite passé ses 87 contrôles. Les rapports bruts d’échec et de reprise restent conservés.
