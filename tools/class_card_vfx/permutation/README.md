# Permutation — planche G en production

Carte publique `cc2_r08`, normale et améliorée, dans la run Cartes actuelle.
Référence approuvée :
`docs/design/vfx_avant_production_lot2_2026-09-27/g_permutation.png`.

Deux agrafes jade et ivoire, fermoir bronze, entourent les pieds du lanceur
et de l'ennemi. Elles se ferment simultanément en une fente lumineuse, puis
se rouvrent autour des personnages après l'échange réel de leurs positions.
La préparation dure 8/30 s ; la séquence complète dure 20/30 s. Une attente
de résolution retient la dernière pose de fermeture ; un refus annule l'effet.
L'ouverture ne se produit que si les deux positions ont réellement été échangées.
Les deux sites restent fixes et le tri avant/arrière suit leur nouvel occupant.

Le VFX n'inflige aucun dégât, ne déplace ni ne masque les personnages et
ne laisse aucun portail persistant. Les règles restent celles du catalogue :
2 PA, portée 1–5 (1–6 améliorée), ennemi requis et boss exclu.

Source originale : `art/source/vfx/permutation/permutation.blend`.
Trois scènes et 48 poses transparentes à 30 images/s : agrafe arrière (20),
agrafe avant (20), fente (8). Géométrie courbe simple, aplats émissifs cel,
jade #438d83 / #8de3c2, ivoire #fff0cc, bronze #ac743c et or #f3cc80.
`build.py` construit et rend ; `pack.py` assemble et compare les pixels.
`verify_source.py` relit le fichier Blender sauvegardé et rend à nouveau les
48 poses ; `verify_pixels.py` les compare aux sources des atlas.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.1/blender.exe' --background --factory-startup --python tools/class_card_vfx/permutation/build.py -- --render
# Exécuter pack.py avec Python + Pillow.
./tools/class_card_vfx/permutation/workshop_isolated.ps1
./tools/class_card_vfx/permutation/run.ps1 -Capture
./tools/class_card_vfx/permutation/run.ps1
./dev.ps1 test test/unit/test_consumable_cards_permutation_vfx.gd
./dev.ps1 test cards
```

Le service Sprite Clip du Studio est réutilisé sans modification dans un
petit projet isolé. Documents : `art/source/sprite_workshop/permutation_*.json`.
Les PNG du jeu sont les atlas dont les pixels sont contrôlés lors de cet export.

Revue : `artifacts/dev/class_card_vfx/permutation/combat/permutation.gif`,
2,8 secondes, détail puis caméra normale. Pixels natifs Godot, sans effet
ajouté après capture ; seule la palette est quantifiée lors de l'encodage GIF.
Les PNG originaux restent disponibles dans `detail/` et `combat/`.

La revue réutilise le montage de la vraie Battle et le parcours Cartes du
pilote Orage, sans modifier ce pilote. Les unités sont placées sur deux cases
visibles à portée quatre. Leurs PV ne sont pas augmentés. Le HUD est masqué
dans les séquences visuelles ; le contrôle de la commande publique conserve
le HUD et vérifie les 2 PA, la consommation de la carte, les PV inchangés,
la sauvegarde sur disque et la reprise aux positions échangées. Deux victoires
préalables et le bilan final sont des fixtures, pas un test d'équilibrage.
Chaque exécution utilise un dossier utilisateur neuf. Le pilote audio est
muet pour la capture, normal en revue interactive ; aucun son dédié n'est créé.

Preuves et limites : `docs/ai/PERMUTATION_PRODUCTION_2026-09-27.md`.
