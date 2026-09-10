# Sélection Catabase — style émeraude (2026-09-10)

## Résultat
Le sanctuaire de sélection reprend les contours peints, la pierre bleu-gris, les brumes jade et les bronzes du menu principal émeraude. Le cadrage et le socle sont conservés pour les deux aperçus d'Achille. Après correction du retour utilisateur, les boutons et panneaux conservent le thème partagé validé : brun fumé, filet bronze de 1 px, sélection pétrole et focus natif distinct. Le style émeraude s'applique au décor.

## Fichiers
- Décor : assets/catabase/selection/sanctuary_emerald_v1.png.
- Prompt exact : assets/catabase/selection/sanctuary_emerald_v1.prompt.txt.
- Génération : outil imagegen intégré, édition du sanctuary_v2 avec le menu underworld_gate_emerald_v1 comme référence de style. Original conservé.
- Intégration : ui/selection/selection_backdrop.gd et character_selection_screen.gd.
- Interface : palette partagée CatabaseUITheme et matériau SelectionAshenSurface existant. Le matériau émeraude ajouté par erreur a été retiré.
- Revue native : tools/character_selection/SelectionEmeraldReview.tscn et selection_emerald_review.gd.

## Périmètre
Deux apparences publiques, Catabase solo. Rotation, zoom, poses, statistiques, techniques, histoire et consultation des maîtrises gardent leur comportement. Le décor de sélection est fixe ; les animations du personnage restent réelles. Le shader animé du menu principal est inchangé (SHA256 21DA8B70929516A78D3D2B5741DA5A82DDB9DCDA759E65B35A971EC06E31A51C).

## Vérification
- Revue native : 43 contrôles sans échec, captures 1280x720, 1200x896 et 1920x1080 ; deux apparences, histoire, rotation, marche, codex et restitution du focus.
- Captures inspectées : artifacts/dev/selection-emerald-restored/captures/.
- Rapport de revue : artifacts/dev/selection-emerald-restored/captures/report.json.
- Validation GUT finale : PASS, 37 tests et 1 871 assertions, zéro erreur/avertissement ; artifacts/dev/selection-emerald-restored/gut-strict-report.json.
- Deux tests historiques ont été adaptés à la sélection publique : le clic de matériau cible Achille peint ; le test de sauvegarde consacré aux anciennes aventures active explicitement leur catalogue. Les autres tests de sauvegarde utilisent le catalogue public.

L'import et les exécutions utilisent des données utilisateur isolées dans artifacts/dev/se4.

Correction : la première livraison avait réintroduit des biseaux et doubles bordures en recolorant l'interface. La version finale rétablit l'habillage récent du lot 2 de catabase_ui_refonte_2026-09-10.md, comparé à la capture artifacts/dev/20260910-161455-chrome-menus-1280x720-e962ffd2/captures/selection.png. Les preuves de la première proposition restent conservées dans artifacts/dev/selection-emerald/.
