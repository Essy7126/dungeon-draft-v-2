# Le Seuil de Catabase après la victoire

Le premier combat utilise le décor peint du Seuil aux trois passages. À sa
victoire, la scène de combat et son HUD sont retirés ; le même décor est chargé
dans le moteur de haltes, avec marche libre au clic, eau et lumières animées.

Cliquer un objet fait marcher Achille jusqu'à son point d'approche, puis ouvre
son choix. Les touches 1, 2 et 3 proposent aussi ces approches. Échap ferme le
choix ; un clic sur le sol permet de continuer l'exploration.

| Objet | Destination de l'étape II |
| --- | --- |
| Barque du passeur | Les traces du Léthé |
| Porte ronde | Le portique des oboles |
| Puits des racines | La sente des oliviers |

Les liens utilisent les destinations du graphe courant et restent stables si la
graine inverse ses branches. Le joueur choisit ses caractéristiques et son butin
avant de confirmer un départ. Les transactions et leur reprise restent gérées
par GameManager. Une sauvegarde en attente empêche le départ et peut être retentée.
Reprendre une sauvegarde après cette victoire rouvre le Seuil, sans rejouer le combat.

## Essayer

- Explorateur : sélectionner **Le seuil de Catabase**, puis **Après le combat**.
- Ligne de commande : `./tools/run_explorer/explorer.ps1 -AfterCombat`.
- Pour éprouver la transition, utiliser **Jouer cette destination** et gagner le combat.

Le raccourci après combat simule la victoire dans une sauvegarde de laboratoire
isolée ; il ne touche pas à la partie personnelle. F8 ferme l'essai et F9 capture.
Ouvrir `SeuilCrossroads.tscn` avec F6 permet une visite sans expédition, sans départ.

## Art et données

La peinture `assets/catabase/combat/seuil_three_paths_v1/land.png` a été éditée
avec image_gen à partir de la caverne existante, avec l'Autel des serments et
l'Étal du passeur comme références. Voir [le prompt](ART_PROMPT.md).
Les zones de navigation, l'eau, les lumières, les clics et les approches sont
décrits dans `data/halts/seuil_crossroads_v1.json`. Les masques sont préparés par
`tools/halt_workshop/halt.ps1 prepare -Map res://data/halts/seuil_crossroads_v1.json`.
La grille du premier combat et ses adversaires sont conservés.

## Validation

- `./dev.ps1 test test/unit/test_seuil_crossroads.gd`
- `./dev.ps1 test test/unit/test_reliability_expedition_lifecycle.gd`
- `./hub/seuil_crossroads/verify.ps1`
- `./tools/run_explorer/verify.ps1 -Seuil`

Le scénario graphique déclenche la victoire par GameManager après chargement du
combat ; il ne prétend pas gagner une bataille en jouant ses tours. Il vérifie les
clics, les approches, la progression, le butin, les trois départs et les reprises.
