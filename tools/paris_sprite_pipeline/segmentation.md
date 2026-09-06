# Séparer des silhouettes dont les rectangles se chevauchent

`alignment[key].segmentation = true` active une attribution des pixels par
silhouette au lieu des fenêtres rectangulaires. Les ancres manuelles et
l’échelle fixe de la source restent obligatoires. Les autres sources, notamment
les deux vues infernales, gardent leurs fenêtres explicites inchangées.

Le module mécanique `segmentation.cjs` suit ces étapes :

1. Détecter les composantes connexes à huit voisins dans l’alpha supérieur à 32.
2. Classer les composantes principales d’au moins 1 500 pixels par leur centre
   dans la grille nominale 4×4, ou 4×2 pour la transformation. Plusieurs
   composantes principales appartenant à la même case sont conservées ensemble.
   Cela inclut l’arc détaché de la pose spectrale N12.
3. Rattacher les petits fragments de cœur à la boîte principale la plus proche.
4. Propager simultanément les propriétaires des cœurs à huit voisins sur toute
   l’image, y compris les pixels transparents. Les franges et fragments isolés
   d’alpha égal à 1 trouvent ainsi leur pose la plus proche.
5. Copier chaque pixel dont l’alpha est non nul dans un seul masque de pose,
   avec ses quatre valeurs RGBA d’origine. Les pixels des voisins présents dans
   la même boîte sont exclus uniquement de cette pose, et conservés dans la leur.

Le seuil de 32 sert à identifier les silhouettes ; il ne sert jamais à supprimer
des pixels du dessin. La reconstruction des masques dans les coordonnées de la
source exige une égalité RGBA exacte pour tous les pixels d’alpha non nul, ainsi
qu’une couverture égale à un. Toute omission, duplication ou modification est
une erreur bloquante. Les couleurs cachées sous un alpha nul sont sans effet
visuel et ne font pas partie de cette obligation.

Les fenêtres de diagnostic peuvent donc se chevaucher. Le champ historique
`source_window_coverage` décrit alors la couverture des propriétaires de pixels,
et non le recouvrement géométrique des rectangles. `extraction_mode` vaut
`segmentation` et le rapport `segmentation` expose les composantes, regroupements
et rattachements. Les tableaux de propriétaires restent en mémoire et ne sont
pas exportés dans le manifest.

Les deux sources spectrales réelles ont été inspectées sans écrire d’assets :

| Source | Principales | Pixels conservés | Dont alpha 1 | Omis / dupliqués |
| --- | ---: | ---: | ---: | --- |
| Spectral E | 16 | 612 849 | 57 044 | 0 / 0 |
| Spectral N | 17, regroupées en 16 poses | 602 025 | 59 458 | 0 / 0 |

Les SHA des reconstructions visibles sont identiques à ceux des sources
normalisées uniquement à alpha nul. La préparation utilise ensuite ces masques
pour le recadrage transparent et la mise à l’échelle, jamais le rectangle brut
qui contiendrait aussi une partie de la pose voisine.

```powershell
node --test tools/paris_sprite_pipeline/build.test.cjs tools/paris_sprite_pipeline/segmentation.test.cjs
```

Les cinq tests de segmentation restent entièrement en mémoire : deux
silhouettes aux boîtes superposées, conservation RGBA et alpha 1 après packing,
arc détaché, petits fragments, propriétaires déterministes, refus d’une pose
principale manquante et prise en charge des huit poses de transformation.
