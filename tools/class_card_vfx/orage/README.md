# Orage du passage — planche H en production

Sort public Cartes `cc2_l01`, normal et amélioré. Référence approuvée :
`docs/design/vfx_avant_production_lot2_2026-09-27/h_orage_du_passage.png`.

Sources originales : `art/source/vfx/orage_passage/orage_passage.blend`.
Quatre scènes Blender, 66 poses RGBA : foudre (15), couronne arrière (18),
couronne avant (18), contact et arcs au sol (15). Matériaux à aplats émissifs,
palette sRGB bleu nuit #132958, sarcelle #168e9b, cyan #49e6ec, ivoire #fff6d6,
or discret #eab763. La couronne respecte le recouvrement avant/arrière du héros.

L'anticipation dure 0,30 s et s'arrête avant l'impact jusqu'à confirmation du
lanceur réel. Le lecteur instancie un éclair et un contact pour chaque ennemi
effectivement touché, aux cases capturées avant les morts. Les contacts sont
simultanés, avec un miroir alterné de la foudre. Le cœur plein tient trois poses,
la foudre se resserre puis se défait. Plus rien n'est visible après 0,80 s ;
l'objet est retiré avant 0,92 s. Un cast direct commence au contact. Un refus
annule la charge ; un cast sans dégâts laisse seulement la couronne se dissiper.

Les sources sont des dessins géométriques animés simples, sans bibliothèque
externe. `build.py` construit et rend ; `pack.py` vérifie les marges alpha et
chaque pixel d'atlas. `verify_source.py` et `verify_pixels.py` relisent le .blend
sauvegardé et comparent les 66 frames. Aucun filtre de flou ni flash plein écran.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/class_card_vfx/orage/build.py -- --render
# Exécuter pack.py avec Python + Pillow.
./tools/class_card_vfx/orage/workshop_isolated.ps1
./tools/class_card_vfx/orage/run.ps1 -Capture
./tools/class_card_vfx/orage/run.ps1
```

Capture livrée : `artifacts/dev/class_card_vfx/orage/combat/orage_du_passage.gif`
(2,8 s : détail puis caméra normale), pixels du viewport Godot. Les PNG sources
restent dans les sous-dossiers `detail/` et `combat/`. `encode.cjs` réalise
uniquement l'encodage GIF ; aucun agrandissement ni effet ajouté après capture.

L'export utilise le service Sprite Clip inchangé du Studio dans un petit projet
isolé ; documents `art/source/sprite_workshop/orage_*.json`. La revue utilise le
parcours et la vraie Battle Cartes actuels. Les deux séquences visuelles déplacent
les trois ennemis du troisième combat et augmentent leurs PV pour examiner
l'effet. Le HUD est masqué uniquement dans ces deux séquences. Le contrôle de
commande publique et de sauvegarde repart d'une bataille aux PV normaux, avec
son HUD. Les deux victoires précédentes et le bilan final sont des fixtures,
pas une simulation d'équilibrage. La capture utilise un dossier utilisateur neuf
à chaque exécution et un pilote audio muet ; le lancement interactif conserve
l'audio normal. Le son n'est pas l'objet de cette validation visuelle.

Validation et limites : voir `docs/ai/ORAGE_PASSAGE_PRODUCTION_2026-09-27.md`.
