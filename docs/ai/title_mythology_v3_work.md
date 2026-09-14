# Menu mythologique — travail du 11 septembre 2026

Demande : conserver le décor émeraude, remplacer les emblèmes romains par ceux
d’Hadès, graver Hadès casqué et Cerbère à trois têtes sur la porte, animer
discrètement les tissus et améliorer surtout la brume proche.

Original conservé : `assets/catabase/title/underworld_gate_emerald_v1.png`.
Copie de sécurité et shader V2 : `artifacts/dev/title-mythology-v3/`.
Nouvelle illustration prévue sous un nom V2 distinct, outil intégré imagegen.
Fichiers : `ui/TitreEcran.tscn`, `ui/menus/catabase_title.gdshader`, revue
`tools/title_menu/review_atmosphere.gd`, documentation du menu.

État initial Git : travaux indépendants Passe-rive/Spine présents ; aucun fichier
du menu modifié. Ne pas toucher aux travaux indépendants.

Terminé : image V2 intégrée, original et copie vérifiés par SHA-256 ; vent local
et brume de premier plan implémentés. Le shader reste piloté par `elapsed`.

Vérifications : import recovery et GUT sélection, PASS 2 tests / 82 assertions.
Revues finales OpenGL et D3D12 : chacune 37 contrôles titre + 108 atmosphère,
sans erreur. Rapport `artifacts/dev/title-mythology-v3/run-20260911-210311/summary.json`.
GUT `artifacts/dev/20260911-205846-test-test_unit_test_catabase_selection_launch.gd-6900c542/gut-strict-report.json`.
Formatage des deux scripts de revue et diff --check réussis. Captures du menu,
gravures et brume isolée inspectées ; aperçu animé réel exporté sur 96 frames.
Le banc arrête désormais la musique et libère le titre avant de quitter Godot,
pour éviter la fuite AudioStreamMP3 intermittente observée dans les premiers essais.

Suite : aucune modification fonctionnelle restante. Pour voir le résultat,
lancer F5 et activer « Animer le décor ». Documentation :
`docs/design/catabase_main_menu_2026-09-10.md`, section Mythologie et vent.
