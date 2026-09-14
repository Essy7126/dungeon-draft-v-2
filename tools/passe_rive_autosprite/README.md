# Passe-rive AutoSprite

66 planches originales transparentes de 1280 × 1280 (5 × 5 images de 256).
Le générateur conserve leurs octets et produit les ressources Godot, le portrait,
les SHA-256, les cycles, les pivots et les échelles par clip.

```powershell
python tools/passe_rive_autosprite/build.py
python tools/passe_rive_autosprite/build_combat_v2.py
./tools/passe_rive_autosprite/validate.ps1
./tools/passe_rive_autosprite/validate.ps1 -Integration
./tools/passe_rive_autosprite/capture.ps1 -Scenario entry
./tools/passe_rive_autosprite/capture.ps1 -Scenario combo -Direction E -TimingOnly
./tools/passe_rive_autosprite/capture.ps1 -Scenario shot -Direction N
./tools/passe_rive_autosprite/capture.ps1 -Scenario combo -Kit wrath -Direction S
./tools/passe_rive_autosprite/capture.ps1 -Scenario hit_death -Direction W
```

Python requiert Pillow (et NumPy pour `build_combat_v2.py`). Par défaut, rebuild depuis les originaux déjà empaquetés ;
`--source <dossier>` permet leur première importation depuis les exports fournis.
Godot et sa version sont résolus via les outils du dépôt. Exécuter la validation
avant les captures après toute modification de ressources pour terminer l'import.

La validation exige un import complet, au moins douze tests et aucune erreur
moteur inattendue. Les captures lancent la sélection publique ou la vraie scène
de combat, avec des données utilisateur isolées. Les rapports sont dans
`artifacts/dev/`, les images sous `artifacts/dev/passe_rive_autosprite/`.
Le dossier APPDATA de chaque capture est consigné dans son `summary.json`.

Les directions des scénarios combat sont celles de la grille : `S` produit
notamment un geste visuel SW. Seuls les sauts W/SW existent dans les sources ;
les autres orientations utilisent leur esquive native. Arc, dash, garde,
réactions et mort ont chacun leur séquence.

Le lot `combat_v2` ajoute 128 dessins ImageGen, répartis en huit directions :
attente armée, tir rapide, tir chargé bas et tir aérien. Les 120 clips natifs restent
dans la ressource ; les 32 nouveaux clips portent le total à 152. L’attente armée
est activée par la vue de combat ; l’exploration conserve son attente native.
Le tir aérien utilise une trajectoire courbe avec les mêmes cibles et la même
confirmation d’impact que le combat.

Les sources opaques, leurs prompts et la méthode de préparation sont conservés
dans [art/source/passe_rive/combat_v2](../../art/source/passe_rive/combat_v2/README.md).
Le découpage et le détourage ont été explicitement autorisés par l’utilisateur.
Le constructeur produit les atlas RGBA, la géométrie des appuis, les empreintes,
32 aperçus GIF et une planche de contrôle sous `artifacts/dev/passe_rive_combat_v2/`.
Pour reconstruire les deux lots, exécuter `build.py` avant `build_combat_v2.py`.

Les réglages de cadence dans le profil Godot doivent correspondre à `CLIPS` dans
le constructeur. Les poids d’images sont échantillonnés autour du marqueur de
départ : un ralentissement du rendu ne peut pas supprimer ou doubler ce marqueur.

Voir [la fiche d'intégration](../../docs/ai/passe_rive_autosprite_integration.md)
pour les réglages d'ancrage, les preuves et les limites de la suite élargie.
