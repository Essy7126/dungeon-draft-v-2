# Arena Map Editor

Editeur autonome Godot pour fabriquer une arene isometrique avant la creation
du decor peint. Il reutilise la projection du `Dynamic Arena Lab` (dalles
64 x 32) sans modifier les scenes de combat de production.

## Lancer l'editeur

1. Ouvrir `ArenaMapEditor.tscn` dans Godot.
2. Executer la scene courante avec **F6**.
3. Choisir la taille de la grille, puis peindre les quatre couches.

Les cartes sont sauvegardees dans
`user://arena_map_editor/maps/<map_id>.json`. Le bouton **OUVRIR** permet aussi
de charger un JSON place ailleurs sur le disque.

## Couches

- **SOL** : VOID, pierre, eau, glace, lave, ombre et rune.
- **EFFET** : feu, eau et glace, poses par-dessus un sol praticable.
- **SPECIALE** : spawn allie, spawn ennemi, objectif et ancre de decor.
- **MUR** : mur neutre, feu ou glace. Un mur remplace visuellement la dalle et
  n'est jamais dessine comme un volume flottant.

Les cellules VOID restent dans les donnees et dans les vues logique/debug,
mais n'ont pas de face superieure dans la reference.

## Commandes

- clic gauche : peindre ; clic droit : effacer ; `Alt + clic` : pipette ;
- molette : zoom ; clic milieu : deplacer la vue ;
- `1` a `4` : choisir la couche ; `F` : remplir la couche ; `G` : grille ;
- `Ctrl+Z` / `Ctrl+Y` : annuler / retablir ;
- `Ctrl+S` : sauvegarder ; `Ctrl+E` : exporter.

## Pack Nano Banana

Chaque export est un dossier 1920 x 1080 contenant :

- `map_reference.png` : dalles, volumes, effets et reperes speciaux ;
- `map_clean.png` : meme geometrie sans les reperes de gameplay ;
- `map_logic.png` : autorite couleur + coordonnees de toutes les cellules ;
- `map_debug.png` : reference visuelle avec grille et coordonnees ;
- `map_definition.json` : document complet reutilisable ;
- `nano_banana_brief.txt` : intention artistique et contraintes a transmettre
  a l'IA avec les images.

Le decor genere doit rester autour et sous l'arene. La silhouette, la
projection, les VOID, les murs, les spawns et les objectifs viennent du JSON
et des vues logique/debug et ne doivent pas etre reinventes par l'image.
