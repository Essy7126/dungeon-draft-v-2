# Les roseaux du tireur — étape V

La salle reçoit une berge de roseaux ouverte sur le fleuve, un ancien pavage
humide et la même barque à trois bancs, amarrée avec sa lanterne. La rencontre
et les 112 cellules existantes restent l’autorité du gameplay ; aucune collision
ne vient de la peinture.

`prepare.py` conserve la baseline puis produit le guide géométrique.
`apply.py` exige l’empreinte de la peinture calibrée, construit le masque
R=eau/G=roseaux/B=sol et objets rigides, puis applique le seul plan visuel.
`prepare.ps1` synchronise les ressources par les services Studio et vérifie
l’empreinte de gameplay après sauvegarde et rechargement.

La peinture native de 1586 × 992 pixels est conservée telle que fournie par
image_gen intégré, avec les prompts et les corrections ciblées. Le plan de
combat utilise un repère de 1920 × 1200 ; la calibration convertit explicitement
les coordonnées entre ces deux espaces.

La pipeline sépare le support peint et les zones praticables. Une base pavée
sèche assez large soutient les 112 cellules complètes et leur réserve. Les
83 cellules de fosse restent définies par la géométrie canonique ; `Platform`
les rend en eau sombre avec leur shader local. Ce dessin runtime conserve une
frontière lisible même lorsque la peinture élargit la berge. La géométrie des
fosses, des obstacles et des déplacements reste celle de la salle existante.

Le support est mesuré contre le contour réel, non convexe, du **bord supérieur
sec** de la pierre. Les faces verticales ne comptent pas dans sa réserve.
`allowed_floor_polygon` suit ce contour ; les poches d’eau et leur couronne
verticale deviennent des `excluded_floor_polygons` avec leurs rives intérieures.
Le contour sec peut également servir de rive conservatrice. La marge de sol
reste de 30 pixels natifs et la distance minimale aux rives de 20 pixels natifs.
Une enveloppe convexe de guide ne constitue pas une preuve de support intérieur.

Les retouches partent de l’union des polygones complets qui échouent, dilatée
avec une réserve explicite. Un **aplat opaque** signale toute la surface à rendre
sèche. Si une ancienne encoche ou sa face verticale persiste, un guide
rectangulaire couvre toute cette structure pour la remplacer par un pavage
continu. La barque et les zones conservées restent hors de l’emprise. Après
chaque correction, le contour est retracé sur l’image obtenue puis les distances
sont recalculées ; déplacer le contour pour masquer un défaut invaliderait la
preuve. Les guides et rapports sont dans `artifacts/dev/lethe-reeds/`.

Les effets ont une horloge locale : eau douce, roseaux dans un vent lent,
lumière ambrée circonscrite au vitrage et à son halo. La coque, les dalles et
l’armature de la lanterne restent immobiles. Pause et réduction du mouvement
figent cette horloge.

```powershell
./tools/lethe_reeds_review/verify.ps1 -GodotPath C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe
./tools/lethe_reeds_review/open.ps1 -GodotPath C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe
./tools/lethe_reeds_review/expedition.ps1 -GodotPath C:/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe -Resolution 1600x900
```

La revue cible `route_6d5efdb88ff0`. Elle vérifie à l'exécution que le nœud
`d05_1`, graine 2401, désigne **Les roseaux du tireur**, étape V, et résout cette
ressource de combat. L'ouverture passe par l'explorateur et sa préparation de
parcours réelle avec des données utilisateur isolées. Elle ne valide pas le
rendu à elle seule. F8 ferme cet essai.

Le lanceur de revue prend `artifacts/dev/engine.lock`, vérifie version et import,
puis lance les oracles communs de géométrie, support, matériaux, cadrage, picking,
déplacement et garde, en 1920 × 1080 et 1200 × 896. Les proportions sont comparées
entre ces deux formats. Les contrôles communs de déplacement et garde restent
ceux de `tools/combat_da_review/registered_map_checks.gd`.

`--reeds-visual-review` réutilise l'oracle des Lances avec un profil de régions
distinct. Le fichier de calibration doit être créé **sur la peinture retenue** :

`assets/catabase/combat/lethe_reeds_v1/visual_review.json`

Il contient `controller` (chemin du contrôleur sous `GreekTerrainComposition`),
`boat_region` et six zones de mesure dans `regions` :

| Région QA | Comportement attendu |
| --- | --- |
| `water` | Eau extérieure animée |
| `channel` | Eau intérieure du chenal animée |
| `vegetation` | Roseaux animés |
| `lantern` | Luminance du vitrage animée |
| `stable_ground` | Sol immobile |
| `stable_wall` | Paroi de pierre immobile |

Chaque région est un rectangle `[x, y, largeur, hauteur]` en coordonnées natives
du plan de combat, avant transformation caméra. Les pixels de l’image source
sont convertis dans ce repère. La barque doit être délimitée entière, lanterne
et extrémités de coque comprises. Une calibration absente, incomplète ou fondée
sur des rectangles fictifs ne permet pas de valider la revue.

Le contrôleur expose `effect_time`, `seek_for_review(seconds)` et respecte le
réglage `GameManager.reduced_motion_changed`. Pour chacun des deux formats,
l’oracle capture huit instants : 0 ; 0,45 ; 0,90 ; 1,35 ; 1,80 ; 2,25 ; 2,70 ;
3,15 secondes. Il exige eau extérieure, chenal, végétation et lanterne animés,
sol et paroi fixes, barque entièrement visible hors du HUD et mouvement réduit
figé. Le gel est contrôlé sur l’horloge **et sur les pixels des six régions**.
Les zones de mesure masquées par le HUD ou hors viewport sont exclues ; un
échantillon vide échoue. La vérification de la barque ne tolère aucun recouvrement
HUD au-delà de la tolérance de surface commune.

Chaque format conserve le rapport complet, la capture initiale, celle après
déplacement/garde et huit captures temporelles. Le lanceur refuse un rapport ou
une capture manquante. Ces images doivent être inspectées pour juger la peinture,
la silhouette de la barque, les occultations du décor et la qualité de l'animation.
La QA effectue un déplacement et une garde ; elle ne joue pas une victoire entière
et n'ajoute aucun déplacement libre de la barque.

## Capture du parcours réel

`expedition.ps1` lance `RunExplorerPreview.tscn` en mode `play`, graine 2401,
avec `--explorer-capture`. Il attend au maximum 55 secondes le verrou moteur,
utilise des données utilisateur isolées et limite le lancement à 120 secondes.
Le contenu doit déjà avoir été importé par la préparation ou la revue ci-dessus.

Le résumé exige une scène de combat prête sur `d05_1`, la bonne identité de salle,
la résolution demandée et au moins une image PNG valide de cette résolution.
Le checkpoint de préparation doit avoir un hash valide et placer la même graine
au combat après la Stèle. Toute erreur moteur, timeout ou preuve absente échoue.
La composition « trois archers » est contrôlée si le rapport expose ses rôles ;
les rapports actuels de l'explorateur n'exposent pas ce roster, ce que le résumé
indique explicitement. Cette capture prouve le lancement de production et son
cadrage, pas une victoire complète. Résolutions acceptées : 1600x900, 1920x1080,
1200x896. Les preuves restent dans `artifacts/dev/*-lethe-reeds-expedition-*`.

## Preuves obtenues avant la revue GPU des Roseaux

- [Audit indépendant du support peint](../../artifacts/dev/lethe-reeds/final-dry-surface-audit.json) :
  112 cellules sur 112 passent, avec une marge sèche minimale de 31,0049 pixels
  natifs. Le [contour final](../../artifacts/dev/lethe-reeds/final-contour.json)
  contient 177 points extérieurs et une poche de 23 points, sans croisement.
  Cet audit porte sur les losanges canoniques ; l’oracle Godot doit encore
  confirmer les transformations des sprites réellement rendus.
- [Tests unitaires du parcours](../../artifacts/dev/20260912-125530-test-test_unit_test_catabase_route_layouts.gd-d0bcd58e/gut-strict-report.json) :
  3 tests et 15 940 assertions réussis, sans test ignoré ni erreur de parsing.
- [Non-régression de l’oracle partagé sur Les lances oubliées](../../artifacts/dev/20260912-125743-lethe-lances-review-d5c7b8e5/summary.json) :
  réussie en 1920 × 1080 et 1200 × 896, rapports et captures présents.

## Livraison validée le 12 septembre 2026

- [Revue GPU finale](../../artifacts/dev/20260912-135650-lethe-reeds-review-a5e78c11/summary.json) :
  deux formats, 20 captures, support des 112 dalles, six régions d’effets,
  stabilité des pierres, mouvement réduit, picking, déplacement et garde.
  Captures après déplacement inspectées dans les deux formats.
- [Parcours réel](../../artifacts/dev/20260912-135504-lethe-reeds-expedition-8d762996/summary.json) :
  étape V après la Stèle, chargement complet et capture en 1600 × 900.
  La barque entière est visible dès le placement d’Achille, hors du journal.
- [Tests sur les ressources finales](../../artifacts/dev/20260912-134727-test-test_unit_test_catabase_route_layouts.gd-ea0c756c/gut-strict-report.json) :
  3 tests et 15 940 assertions réussis.

Le profil local utilise `camera_offset_adjustment = Vector2(-120, 50)`.
Les fosses reprennent directement un échantillon d’eau de `Land.texture`,
avec des replis miroir adoucis et une distorsion d’environ un pixel natif.
Les surfaces verticales gardent leur couleur et leur position.

Les empreintes de tous les fichiers runtime et les rapports sont enregistrés
dans `assets/catabase/combat/lethe_reeds_v1/manifest.json`.
