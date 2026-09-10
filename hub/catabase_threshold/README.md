# Le Seuil des Ombres

`CatabaseThreshold.tscn` est l’entrée jouable de Catabase, après l’introduction et
avant la création de l’expédition. Le manifeste est
`data/halts/underworld_threshold_v1.json` ; la peinture, la navigation, les points
d’approche et la brume y sont définis en coordonnées normalisées.

Le sol se parcourt au clic. Les trois plaques peintes sont directement
cliquables : Achille rejoint leur point d’approche sûr, puis ouvre le souvenir.
Toute la porte est cliquable et propose de franchir le seuil après l’approche.
Le trajet et son point d’arrivée sont visibles pendant la marche ; un clic
proche du bord rejoint le sol praticable le plus proche. Les destinations trop
lointaines ou sans chemin sont refusées avec un message. **Clic droit** arrête
la marche. **E** active le lieu proche. **Échap**
ferme une lecture ou ouvre le menu, qui permet de réduire les animations ou de
revenir à l’accueil. Une exécution directe avec **F6** permet la visite et
propose la sélection d’Achille à la porte, sans démarrer une run par défaut.

`GameManager.continue_after_intro()` conserve la sélection jusqu’au portail.
`finish_catabase_threshold()` réutilise le démarrage existant, sa confirmation de
remplacement et son premier checkpoint. Une écriture en attente se réessaie par
`retry_expedition_save()` ; elle ne doit jamais relancer la création du run.
La reprise d’une sauvegarde contourne l’introduction et cette entrée.

Le contrôleur réutilise `living_halt.gd` pour le monde, l’ordre de profondeur et
l’éclairage. Ses hooks choisissent le profil d’Achille, le shader et les
interactions locales. `threshold_navigation.gd` ajoute seulement au Seuil
l’assistance au clic et le contrôle du segment entier. Les trajets conservent
les obstacles et la marge des pieds ; la marche ralentit aux virages. Chaque
repère distingue `hit_polygon` (plaque ou porte visible), `focus` (centre de
clic) et `point` (position sûre des pieds pour lire). Aucun achat ni solde de halte n’est
présent avant l’expédition. La brume reçoit uniquement l’horloge du monde.

Validation unitaire : `./dev.ps1 test res://test/unit/test_catabase_threshold.gd`.
Le pilote graphique `tests/cinematics/CatabaseThresholdFlowQA.tscn` accepte
`--ending=skip|natural`, `--appearance=classic|painted_g` et
`--output=res://artifacts/dev/<rapport-neuf>` après le séparateur `--` de Godot.
Il clique sur les interfaces réelles, compare la sauvegarde avant chaque
interaction, traverse le portail, vérifie `d01_0`, et écrit captures et
`flow-report.json`. L’ancien `CatabaseFullFlowQARunner` réutilise ce parcours avec
la fin naturelle de l’introduction.

`tests/cinematics/CatabaseThresholdVisualQA.tscn` capture une visite isolée avec
le même argument `--output`. Il produit `report.json`, les vues 1280×720,
1920×1080 et 1200×896, les états pause/brume à 24 secondes/original/menu/mouvement
réduit, et trois sondes d’occlusion. Les positions proviennent de
`review.occlusion_points` : `statue_right_behind`, `statue_right_front` et
`statue_left_behind`. Le personnage est placé directement pour ces sondes
visuelles ; chaque point est aussi contrôlé comme praticable. Les images avec
et sans personnage/découpes permettent de mesurer l’occlusion sans la confondre
avec un changement de peinture. Ce pilote nécessite un affichage graphique.
