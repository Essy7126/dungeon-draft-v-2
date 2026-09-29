# Contre préparé — planche F

`cc2_g05` uniquement, dans la run Cartes actuelle. Source de direction artistique :
`docs/design/vfx_avant_production_lot2_2026-09-27/f_contre_prepare.png`.

Deux pièces de bronze se rejoignent en 0,20 s ; le croissant se résorbe avant
0,47 s. Un jeton triangulaire reste dans la ligne compacte des états, séparé de
la garde. La riposte produit un revers ivoire de 0,30 s et un contact local à
0,067 s. Tout est terminé avant 0,37 s. Pas de boucle d'aura.

Le corps utilise toujours la garde S27 et son point de libération existant.
Seul l'ancien accent de garde S27 est remplacé pour cette carte.
Le marqueur `cc2_counter` passe par `HitContext.status_id` puis `hit_resolved`.
La classification demeure `cc2_indirect` : règles, montants et ordre sont
inchangés. Les représailles du passif et de Miroir n'ont pas ce marqueur.
Le contact est figé avant le retrait de la cible morte. Une riposte sans dégâts
ni absorption ne crée pas de contact. La disparition de l'état n'invente jamais
de frappe, notamment à l'activation suivante ou si le passif a tué la cible.

La restauration ne joue que le jeton statique. Le routeur traite la mort,
l'expiration, la fermeture et le débordement de la ligne des états.

## Production

1. Blender 5.1 : `--background --factory-startup --python tools/class_card_vfx/contre/build.py -- --render`.
2. Python/Pillow : `tools/class_card_vfx/contre/pack.py` assemble les atlas sans modifier les pixels et vérifie les marges alpha.
3. `workshop_isolated.ps1` réutilise le service Studio inchangé : quatre documents éditables et vérification de l'export.
4. Blender : `--background --factory-startup --python tools/class_card_vfx/contre/verify_source.py`, puis Python `verify_pixels.py` vérifie les 32 poses depuis le `.blend` sauvegardé.
5. `./dev.ps1 test cards` et `./tools/class_card_vfx/contre/run.ps1 -Capture`.
6. Node/Sharp : `tools/class_card_vfx/contre/encode.cjs`, avec `SHARP_PATH` si nécessaire. Images natives Godot, aucune retouche ; seule la palette GIF est quantifiée.

Le fichier éditable est `art/source/vfx/contre/contre.blend`. Les atlas runtime
et leurs empreintes sont dans `vfx/class_cards/contre/` ; les documents Studio
dans `art/source/sprite_workshop/contre_*.json`.

## Revue intégrée

`run.ps1` ouvre la revue interactive ; `-Capture` produit deux clips de trois
secondes, détail/normal et caméra normale/amélioré. La commande publique lance
la carte et le runtime de l'ennemi exécute sa vraie attaque avec son animation.
La revue vérifie ensuite les sauvegardes disque avec contre armé puis dépensé,
l'expiration et le bilan/reprise. Placement et PV au maximum naturel sont des
fixtures ; la victoire de fin de parcours est une fixture, pas une partie jouée.

Les preuves sont dans `artifacts/dev/class_card_vfx/contre/`. Un rapport absent,
un changement de source pendant la capture ou une erreur moteur est un échec.
