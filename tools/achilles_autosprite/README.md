# Achille — planches AutoSprite

L’apparence **Achille classique** utilise les 56 planches reçues le 13 septembre
2026 dans la sélection, le Seuil des Ombres, les haltes et les combats. Lancer le
projet avec F5 et choisir cette apparence pour tester. Les apparences peintes
restent séparées.

## Ressources et reproduction

- Images originales : `assets/characters/Achilles/autosprite_v1/`.
- Animation Godot : `sprite_frames.tres`, 112 clips, 1 400 régions d’atlas.
- Profil : `data/visuals/achilles/achilles_autosprite_profile_v1.tres`.
- Adaptateur : `characters/achilles/2d/achilles_autosprite_backend.gd`.

Avec Python et Pillow :

```powershell
python tools/achilles_autosprite/build.py --source C:/Users/paolo/Downloads
# Reconstruire à partir des PNG déjà inclus :
python tools/achilles_autosprite/build.py
```

Le script copie les PNG sans modifier leurs pixels ni leur alpha et génère les
régions de 256 × 256 dans une grille 5 × 5. `manifest.json` conserve les SHA-256,
les boîtes alpha et les indices utilisés. Priorité aux attaques v2 et aux autres
planches v1 ; le repos nord porte le nom sans version fourni par l’utilisateur.
Le fond vert de la palette a déjà un alpha nul.

## Lecture des animations

Chaque famille possède N, NE, E, SE, S, SW, W et NW. Le combat projette la direction
de la grille sur l’écran avant de choisir la planche ; les haltes utilisent
directement la direction écran. Aucun retournement horizontal n’est nécessaire.

Le repos lit les 25 images sur deux secondes. La marche lit les images source
1 à 12, la course 1 à 7 (indices à partir de zéro), soit un cycle complet sans
répéter l’amorce. Leur phase suit la distance parcourue. La Percée garde la course
jusqu’à l’arrivée réelle, puis termine par une réception fixe et le repos animé.

Les attaques, balayages, tirs et crochets utilisent leurs 25 images. Le profil
place les marqueurs de frappe et de lâcher sur les poses correspondantes. Les
trois sorts `exp_crochet*` utilisent le geste de crochet fourni ; la modification
reste limitée à la présentation.

Les tirs spécialisés réutilisent le tir fourni. Aucune planche de garde, de
réaction ou de mort n’était fournie : ces états utilisent le repos dans la bonne
direction avec les effets de garde, le flash de dégâts et le fondu existants.
Les pointes d’armes touchant les bords de certaines images source sont conservées.

## Vérification

Les scripts résolvent le moteur via `tools/dev`, isolent les sauvegardes dans
`artifacts/dev/` et échouent sur un processus incomplet, un rapport absent ou une
erreur moteur. Ne pas interpréter le seul nombre de tests passés comme un succès
de l’analyse stricte.

```powershell
./tools/achilles_autosprite/validate.ps1
./tools/achilles_autosprite/validate.ps1 -Integration
./tools/achilles_autosprite/validate.ps1 -Full
./tools/achilles_autosprite/validate.ps1 -Integration -VerboseEngine
./tools/achilles_autosprite/capture.ps1 -Scenario entry
./tools/achilles_autosprite/capture.ps1 -Scenario combo -Direction E -TimingOnly
./tools/achilles_autosprite/capture.ps1 -Scenario shot -Direction N
./tools/achilles_autosprite/capture.ps1 -Scenario hit_death -Direction W
```

Les captures utilisent la vraie sélection, le vrai seuil et
`RegisteredTerrainBattle` par les sondes existantes. Les directions du lanceur
de combat désignent des axes de grille ; N produit ici une visée NE à l’écran.
La mort est provoquée par les tours ennemis ordinaires. L’exécution sans captures
sert à contrôler les temps sans le coût des lectures GPU.

Résultats et limites de la session : `docs/ai/achilles_autosprite_integration.md`.
