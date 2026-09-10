# Sentinelle — essai de dessin guidé par poses

État du 10 septembre 2026, base Git `2473c335`, travail local non commité.

## Décision et périmètre

L'utilisateur propose d'utiliser le squelette Blender comme référence de mécanique
et de dessiner les sprites depuis le personnage original. Le mannequin a reçu un
retour positif sur la cohérence du mouvement ; l'habillage `sentinelle_armor_v1`
a ensuite été rejeté pour manque de fidélité au sprite. Il ne définit donc pas
la direction artistique à reproduire.

Le premier kit apprécié était celui d'Achille : ses dessins de poses complets
étaient générés, puis découpés et assemblés. Ils ne contiennent pas de rig
permettant des corrections locales garanties. Conserver les dessins réussis.

Cet essai reprend un seul estoc, vue E, quatre poses : garde, charge, contact,
freinage. Blender sert aux appuis, articulations et trajectoires. Le sprite
original sert au dessin, à la silhouette et à l'équipement. La génération
guidée reste une hypothèse à évaluer, pas une garantie de fidélité au squelette.

## Livré et vérifié

- `pose_guide.json` : projection des poses 1, 6, 13 et 16 de `Estoc_Preview`.
- `pose_guide.png` : planche technique 1280 × 1240 ; JPEG de consultation associé.
- `generation_prompt.txt` : texte exact envoyé à l'outil intégré ImageGen.
- Export Blender terminé avec code 0 ; aucune sauvegarde du fichier Blender.
- Entre contact et freinage, les coordonnées projetées du pied avant et de sa
  semelle restent identiques (écart maximum mesuré : 0 pixel dans l'export).
- Les semelles sont des boîtes englobantes, et le mannequin conserve son faible
  écart initial au sol. Ce guide ne prouve pas une biomécanique parfaite.

## Génération bloquée

Un appel à l'outil intégré ImageGen a été tenté avec deux références locales :

1. `art/source/characters/catabase_monsters/sentinelle_airain/base_frame_E.png`
   — identité et peinture uniquement.
2. Le présent `pose_guide.png` — mouvement et caméra uniquement.

L'appel a échoué avant génération lors de la lecture de la première référence :
`windows sandbox failed: helper_unknown_error: apply deny-read ACLs`.
Aucun nouveau sprite, aucune validation artistique et aucun clip Godot n'ont
été produits. Aucun appel API de remplacement n'a été lancé.

## Suite limitée

Quand l'accès aux références fonctionne, rejouer le prompt avec ces deux images.
Comparer d'abord les poses au sprite original et au guide : pieds, transfert du
poids, coordination bras/buste, lance, bouclier diagonal, proportions et palette.
Une planche techniquement valide ne vaut pas acceptation artistique. Une fois
les poses convaincantes, travailler les intervalles et le timing, puis seulement
les autres directions et actions. Pas de nouvel habillage 3D détaillé préalable.
Pour la mort future, conserver la demande d'explosion noire avec disparition.

## Reproduction du guide

Source : `art/source/blender/sentinelle_armor_v1/source_pose.blend`, copie de la
scène prise avant l'habillage 3D. Scripts depuis la racine du dépôt :

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background 'art/source/blender/sentinelle_armor_v1/source_pose.blend' --python-exit-code 1 --python 'tools/blender_sentinelle/export_pose_guide.py'
& 'artifacts/dev-tools/sprite-python/Scripts/python.exe' tools/blender_sentinelle/draw_pose_guide.py
```

Rapport d'export : `artifacts/dev/sentinelle-guided-export.log`.
