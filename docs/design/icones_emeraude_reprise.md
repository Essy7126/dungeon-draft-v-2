# Reprise des icônes — illustrations Émeraude

L’utilisateur rejette les glyphes simplifiés hors carte. Remplacer toutes les icônes hors route par des illustrations générées, dessinées comme le Sanctuaire des Sources Émeraude. Préserver exactement les 12 marqueurs de carte.
Référence : asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png.
Sources générées : art/source/catabase/emerald_icons_v2 ; assets : assets/catabase/emerald_icons_v2.
185 illustrations individuelles produites et intégrées. generated.json contient les prompts, chemins source et empreintes ; les 185 fichiers correspondent exactement aux sorties générées retenues. L’arc a reçu une seconde passe pour épaissir sa silhouette.
Correction utilisateur : limiter fortement le détail pour une lecture à 32–64 px. Grandes silhouettes et volumes peints, trois valeurs par matière, aucun motif fin, grain, gravure ou particule. Les trois essais détaillés sont remplacés par des versions sobres ; générer la suite avec style_prompt.txt.
Fond encre opaque choisi après rejet d’un faux damier de transparence. Pas de SVG de remplacement, pas de conversion en symboles.
Bibliothèque centrale : ui/theme/catabase_icon_library.gd ; textures peintes importées en 256 px avec mipmaps. La route garde les SVG d’origine et leurs empreintes. Références directes remplacées dans les thèmes HUD, les effets de progression et les objets. Filtrage adapté dans les sorts, les commandes et les cases d’inventaire.
Raccourcis HUD : Inventaire, Compétences, Caractéristiques et Carte utilisent désormais les illustrations seules, sans cadres de bouton. Le shader painted_shortcut.gdshader retire leur fond encre à l’affichage ; les PNG sources restent conservés. Proportions natives, icônes de 32 px minimum en présentation premium, zones de clic de 36 px minimum, focus/survol lumineux, infobulles et touches I/K/P/C conservés. Les apparences antérieures peuvent restaurer leurs styles et matériau.

Validation achevée : 106 tests / 5194 assertions ; ensemble final de 66 captures / 1229 contrôles rendus en 1280×720 et 1920×1080. Après le retrait des cadres, les 22 tests HUD concernés et les captures HUD/jeu ont été relancés avec succès. Les quatre raccourcis ont été cliqués réellement par la galerie. Inspection des six planches, de l’inventaire et du HUD aux deux tailles, du grimoire et de la carte. Scénarios préparés utilisant les services réels ; aucune partie complète revendiquée.
Rapport consolidé : artifacts/dev/20260910-230621-emerald-icons-validated/summary.json.
