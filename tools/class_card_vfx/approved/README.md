# Quatre sorts approuvés — production Blender / Godot

Référence : les planches A/B/C/D validées dans
`docs/design/vfx_avant_production_2026-09-27/`. Run Cartes historique uniquement.

## Sources et reconstruction

- `build.py` : six scènes dédiées, géométrie cel originale facettée et matériaux
  émissifs à aplats. Aucune bibliothèque externe ou licence d'asset ajoutée.
- `art/source/vfx/approved_spells/approved_spells.blend` : manille, deux orientations
  de maillon, flèche, 24 poses de rosette, 30 poses de harpé.
- `pack.py` : atlas RGBA sans redimensionnement, comparaison des pixels,
  marges transparentes et empreintes dans `vfx/class_cards/approved/provenance.json`.
- `verify_source.py` : rerend les scènes sauvegardées dans un dossier distinct.
- `export_workshop.gd` : documents et exports via le service Sprite Clip du Studio.
  La première pose transparente de Moisson est conservée dans l'atlas runtime ;
  son clip d'édition contient 29 dessins et un décalage documenté de 33,33 ms.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/class_card_vfx/approved/build.py -- --render
# Puis pack.py avec le runtime Python disposant de Pillow.
./tools/class_card_vfx/approved/run.ps1 -Workshop
./tools/class_card_vfx/approved/run.ps1 -Capture
./tools/class_card_vfx/approved/run.ps1
```

Si une autre tâche utilise le moteur du projet, `workshop_isolated.ps1` exécute
le même service Studio (empreinte vérifiée) dans un projet temporaire séparé,
puis recopie uniquement les six exports `approved_*` et leurs documents.

Validation : 185 tests Cartes / 14 428 assertions, 312 contrôles en arène,
58 rerendus Blender identiques, six exports Studio relus sans perte.

La refonte concurrente du nouveau départ Cartes change de catalogue : ces
productions ciblent les quatre identifiants approuvés, toujours conservés pour
les anciennes sessions. Leur affectation aux nouvelles cartes reste à définir.

## Raccordement

`class_card_vfx_facts.gd` observe le contexte résolu des quatre cartes ; il n'écrit
que dans la rubrique `card_vfx` du rapport. Cases, ennemis et seuil de PV sont
capturés avant dégâts. Le journal final fournit les déplacements réels.

Le lecteur attend la confirmation après une anticipation de 0,20 s (chaîne),
0,30 s (harpé) ou 0,40 s (volée), au même point de revalidation que Sentence.
Un cast direct sans anticipation commence au contact. L'échec annule l'objet.
Une esquive conserve le geste sans inventer d'impact sur la cible.

La chaîne interpole uniquement la vue de l'unité vers la destination déjà
résolue : 0,12–0,26 s, puis ouverture des maillons. Un nouveau déplacement
reprend la main ; une fermeture recale uniquement la vue encore possédée.
Le Jardin n'a pas de seconde explosion : les surfaces réellement posées font
éclore leurs rosettes, puis gardent leur petite pose jusqu'au signal d'expiration.
Une restauration commence directement dans cette pose basse. L'entrée confirmée
produit deux éclats aux chevilles et conserve la rangée compacte des états.

La revue utilise la vraie arène et le lanceur de production, avec IA suspendue,
main préparée, ennemis à PV augmentés et caméra de détail. Elle vérifie aussi
les quatre commandes publiques, le reçu et la reprise. Ce n'est pas une mesure
d'équilibrage. Les PNG sont les pixels natifs Godot ; le GIF ne change que la palette.
