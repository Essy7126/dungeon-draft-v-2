# Passe-Rive — directions S20

Correction du 26 septembre 2026. Le lecteur S19 ne disposait que d'une vue et
de son miroir : le calcul isométrique était correct, mais le dessin restait de
profil lorsque la cible était devant ou derrière. Le test numérique de direction
ne suffisait donc pas à valider l'image.

Résultats et chemins des preuves : [VALIDATION.md](VALIDATION.md).

## Assets et sélection

Les neuf animations disposent maintenant de cinq vues : E conservée du lot S18,
SE, S, NE et N dessinées pour S20. W, SW et NW utilisent respectivement les miroirs
de E, SE et NE. Cela couvre les huit directions à l'écran. Les diagonales suivent
la projection du terrain (pente 1/2), et non des angles graphiques de 45 degrés.
Les directions de face et de dos emploient des poses en raccourci.

Les 36 nouvelles planches, 432 poses, sont dans
`assets/characters/PasseRive/sprites_s20/atlases/`. Garde, marche, lames, riposte,
dague, tir, volée, braise et sceau conservent leurs identifiants et durées S19.
Les cinq initiations reprennent ces gestes. Les directions changent aussi pendant
une pose de garde identique. L'origine et les accents locaux des sorts suivent
la même direction projetée.

Les PNG S18/S19 restent inchangés. Une région de la pose de décoche E/W du tir
est exclue à l'affichage : elle contenait une petite flèche pointant à l'envers.
La volée SE/SW maintient la pose de tension jusqu'à la vraie image de décoche.
Les contacts S19 sont triés à la profondeur de leur cible pour ne pas apparaître
sur le dos d'un personnage placé devant. Les icônes d'état gardent leur rail.

## Reproduction et provenance

Génération et retouches : outil intégré **image_gen**, avec les planches S18
comme références de personnage et d'action. Prompts finaux, chemins de sortie
originaux, chemins du projet et SHA-256 : [generated_sources.json](generated_sources.json).
Les études multivues et candidats mal cadrés ont été rejetés. Aucun asset Dofus
n'est inclus.

`python tools/class_card_vfx/build_s20_data.py` analyse les PNG du projet en lecture
seule et génère les régions, pivots et dépendances de textures. Il nécessite
Pillow et NumPy. `--check` vérifie la reproductibilité sans écrire. L'échelle
constante par planche est calculée depuis la hauteur capuche-sol de la garde,
pour ne pas confondre hauteur du personnage et hauteur de son arme levée.
Il n'y a ni suppression de fond par code, ni retouche des pixels par Python.
Les deux pointes de dague de la riposte SE qui dépassent dans les cellules
voisines sont enregistrées comme régions supplémentaires de leur propre pose.

Essai natif :

```powershell
./tools/class_card_vfx/play_passe_rive_s19.ps1
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Capture -Directions
./tools/class_card_vfx/play_passe_rive_s19.ps1 -Capture -Directions -Card a_ambush
./dev.ps1 test cards
./dev.ps1 test test/unit/test_passe_rive_s19.gd
```

Les boutons E/SE/S/SW/W/NW/N/NE désignent la direction de la cible à l'écran.
Une carte de portée 1 ne peut atteindre que les quatre cases voisines de la
grille : l'essai refuse les quatre autres axes au lieu de modifier ses règles.
Le scénario complet joue 48 combinaisons légales et capture anticipation,
contact et retour en garde.

## Limites

Il s'agit de cinq vues originales et trois miroirs, pas de huit dessins
indépendants. Les miroirs inversent donc aussi l'équipement et la main dominante.
Les vues sont des animations raster de douze poses : elles ne prouvent pas une
reconstruction 3D identique sous chaque angle. Le tracé et certains appuis restent
perfectibles entre dessins. Les nouveaux sprites n'incluent pas de projectile
en vol détaché ; le contact est affiché sur la cible confirmée. Les anciennes
petites traînées E/W restantes restent locales. Aucune nouvelle animation de
blessure ou de mort n'est ajoutée, et la garde conserve l'arc.

Le périmètre reste les combats Cartes de Passe-Rive. Le lecteur Classique,
le Seuil, les haltes et les portraits ne changent pas.
