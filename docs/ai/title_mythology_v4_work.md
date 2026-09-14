# Menu V4 — retours du 11 septembre 2026

Demande : retirer l’oreille surnuméraire de Cerbère, améliorer le drapeau droit,
animer la fumée proche à gauche entre les rochers. Versions V1/V2 conservées ;
sauvegarde V2 et shader V3 dans `artifacts/dev/title-mythology-v4/`.

État Git vérifié : les modifications V3 du menu sont toujours non commitées ;
préserver les autres travaux. Retouche imagegen locale prévue sous image V3.
Cause drapeau : masque par couleur excluant la broderie dorée ; remplacer à droite
par une zone suivant le tissu, déformation continue avec bord stable.
Brume gauche : couche advectée propre, masque de profondeur fondé sur les poches
de brume peintes ; aucun déplacement des rochers.

Terminé : image V3 intégrée ; six oreilles vérifiées en gros plan. Tissu et
broderies du drapeau droit suivent une même déformation douce, sans variation
de luminosité à droite. Brume gauche propre, masque couleur et profondeur.

Import et GUT : PASS 2 tests / 82 assertions, rapport
`artifacts/dev/20260911-211414-test-test_unit_test_catabase_selection_launch.gd-9ade8bb3/gut-strict-report.json`.
Revues finales : 37 contrôles titre + 117 atmosphère dans chacun des moteurs
OpenGL et D3D12, sans erreur ;
`artifacts/dev/title-mythology-v4/run-20260911-211705/summary.json`.
Premier passage : voile détecté sur pierres bleues, corrigé par masque profondeur.
Image V2 et copie de sécurité toujours identiques par SHA-256.
Formatage ciblé et diff --check réussis ; gros plans image et shaders inspectés.
Aperçu réel : `artifacts/dev/title-mythology-v4/catabase_corrected.webp`.
Suite : aucune correction restante identifiée ; revue utilisateur de la nouvelle animation.
