# Préparation des sprites d’Achille peint G

Exécuter `build.py` uniquement dans le sandbox Higgsfield. Le script traite les dessins mécaniquement : détourage magenta, suppression de la frange colorée, échelle uniforme par planche, placement et assemblage. Il ne dessine ni ne reflète les orientations. NumPy et Pillow sont requis ; SciPy accélère le nettoyage des petits points isolés.

```text
python build.py input.json --inspect
python build.py input.json
```

Le fichier JSON contient `outDir`, éventuellement `targetBodyHeight` (270 pixels par défaut), et `sources`. Chaque source contient :

- `key` : famille et direction, par exemple `locomotion_N` ;
- `url` : URL HTTPS confirmée du fichier Higgsfield ou CloudFront ;
- `columns` : 4 ;
- `rows` : 4 pour `locomotion` et `extra`, 3 pour `base` ;
- `scale` facultatif : facteur unique pour toutes les poses de cette planche ;
- `roots` facultatif : un couple `[x, y]` par cellule, en coordonnées de la cellule source.
- `keyColor` facultatif : `[r, g, b]` pour un fond uni explicitement identifié ; sans ce champ, le détourage magenta reste inchangé.
- `backgroundSeeds` facultatif : points `[x, y]` entiers en coordonnées globales de la feuille, pour retirer des poches de fond uni enfermées. Nécessite `keyColor`. Chaque point doit être dans l’image et à une distance RGB maximale de 18 du fond déclaré ; sinon la préparation s’arrête.
- `removeDetachedProjectiles` facultatif, `false` par défaut : nettoyage conservateur des flèches isolées, uniquement dans les cellules 4–7 de `base` (`bow`) et `extra` (`volley`).
- `preserveCrossCellEquipment` facultatif, `false` par défaut : détourage puis segmentation de la feuille entière pour préserver les armes dépassant d’une cellule. Cette option requiert SciPy dans le sandbox.
- `componentOwners` facultatif : association explicite `{ "idComposante": indexCellule }` pour un équipement secondaire dont l’attribution automatique est ambiguë ; les identifiants et rectangles viennent du rapport de segmentation.

La clé magenta supprime complètement les dominances magenta à partir de 110, avec transition de 40 à 110. Elle traite ainsi aussi les fonds magenta sombres. Au moins 99 % de la bordure doit avoir un alpha inférieur ou égal à 32 après la clé ; autrement, la préparation s’arrête.

En mode global, les N corps dominants sont attribués aux cellules par leur centroïde. Une cellule sans corps unique ou une composante avec une masse corporelle importante dans deux cellules provoque un arrêt. Les équipements secondaires suivent le corps le plus proche ; une majorité inférieure à 60 % exige un contrôle et, si nécessaire, une association explicite. Chaque pixel RGBA détouré est conservé une seule fois, y compris les franges translucides dépassant les deux pixels usuels. La somme alpha source/poses est contrôlée avant le nettoyage optionnel des projectiles.

Les crops peuvent dépasser horizontalement et verticalement leur cellule. Les mesures conservent le corridor horizontal nominal et s’étendent verticalement avec le dessin ; les racines restent exprimées par rapport à la cellule nominale. `cropOrigin` convertit ces racines au moment du placement. Une racine manuelle peut dépasser la cellule tant qu’elle reste dans la feuille source, ce qui préserve notamment le sol commun d’une pose aérienne. Seuls les bords de la feuille entière deviennent des erreurs de source tronquée dans ce mode ; un simple franchissement de cellule est signalé `crossesNominalCell`.

Contrôle synthétique à exécuter dans le sandbox, avec `self_test.py` placé à côté de `build.py` : `python self_test.py`. Il vérifie la conservation RGBA, les franges, l’équipement traversant les cellules, les racines, les acteurs fusionnés et les vrais bords de feuille. Il ne constitue pas une validation artistique des dessins.

Pour `keyColor`, seul le fond de couleur proche relié à un bord de chaque cellule est retiré. Une distance RGB maximale de 18 produit la transparence ; la bande 18–40 produit des bords progressifs avec retrait de la couleur de fond. Une région de même couleur enfermée à l’intérieur du personnage reste intacte. L’audit indique le type et la couleur de détourage, les pixels retirés, les bords progressifs et les pixels similaires conservés à l’intérieur. Ce réglage peut par exemple traiter un fond gris `[131,131,131]` ou blanc `[251,249,252]` lorsqu’une feuille a ignoré le fond magenta demandé.

Les `backgroundSeeds` explicitement fournis ajoutent uniquement leurs régions de fond à ce flood de connexité 8. Les autres blancs enfermés restent intacts. L’audit conserve chaque coordonnée, son RGB/alpha source, sa distance au fond, les pixels supplémentaires atteints et ceux rendus transparents. En mode global, les points sont utilisés directement ; en découpage simple ils sont traduits dans leur cellule. Pour la source `extra_E` 2048 × 2048 inspectée, les cinq points proposés sont `[[835,625],[870,755],[1340,625],[1370,755],[1900,780]]` avec le fond `[251,249,252]` ; ils ne doivent pas être réutilisés sur une autre génération sans inspection.

Le nettoyage optionnel des projectiles analyse les composantes connexes à alpha supérieur à 32. Il préserve toujours la plus grande composante, et ne retire que les petites formes horizontales isolées : largeur au moins 20 pixels, hauteur au plus `max(10, hauteurCellule × 0.04)`, rapport largeur/hauteur au moins 5 et aire inférieure à 1 % de la cellule. Les deux pixels de frange translucide autour d’une composante retenue sont inclus sans effacer le cœur opaque d’une autre composante. L’équipement relié au corps, ainsi que tous les autres clips dont la mort, restent inchangés. `projectileRemoval` conserve les rectangles, nombres de pixels et motifs de retrait pour une inspection visuelle ; les projectiles animés appartiennent au système de combat.

`--inspect` accepte un sous-ensemble des planches. Il écrit les originaux, contacts et mesures sans construire le kit. L’assemblage complet exige les douze planches : trois familles multipliées par quatre directions. Les mesures automatiques restent signalées `PROVISIONAL_AUTO` ; elles demandent une inspection des pieds, proportions et armes avant intégration.

Sans racines manuelles, une même hauteur de sol s’applique à chaque animation. Pour le dash, sa médiane utilise uniquement les cellules 0, 1 et 3 : l’envol de la cellule 2 reste visible. Les huit images de marche partagent aussi une seule hauteur. `rootMeasured` conserve la mesure initiale, `autoRoot` celle utilisée automatiquement et `rootSuggested` propose un X de bassin d’après le tissu bleu sombre dans une bande centrale. Cette proposition X reste inactive : le bouclier peut fausser la mesure et un contrôle visuel reste nécessaire.

Les bornes de grille utilisent `round(i × dimension / divisions)` sans redimensionner la feuille : 1792 pixels sur trois rangées donnent 597, 598 et 597 pixels. Chaque entrée de pose indique son `cellRect` et son `cellSize` exacts ; `gridBounds` conserve toutes les bornes. Le `cellSize` global vaut `null` si les cellules diffèrent.

| Famille | Cellules, dans l’ordre de lecture |
| --- | --- |
| `locomotion` | `idle` 0–3, `walk` 4–11, `attack` 12–15 |
| `base` | `dash` 0–3, `bow` 4–7, `guard` 8–11 |
| `extra` | `sweep` 0–3, `volley` 4–7, `hit` 8–11, `death` 12–15 |

Les directions sont celles de la grille : N vers le haut, E à droite, S vers le bas, W à gauche. En projection isométrique, elles pointent respectivement en haut à droite, en bas à droite, en bas à gauche et en haut à gauche de l’écran.

Toutes les images finales mesurent 512 × 384 pixels, avec l’ancre des pieds à `(256, 320)`. `bow`, `guard`, `sweep` et `volley` ajoutent la première pose de repos avant et après leurs quatre dessins, soit six images. Le marqueur est l’index 3 (quatrième image) ; celui du dash est l’index 2. La réception du dash utilise l’index 3 après l’arrivée réelle, suivant le backend partagé avec l’ancien Achille.

Le résultat contient 40 atlas, les images PNG RGBA individuelles, les GIF de prévisualisation, les planches contacts, les originaux inchangés et leurs SHA-256, un `manifest.json` de diagnostic et `achilles_sprite_frames.tres`. Les chemins du fichier Godot ciblent `res://assets/characters/Achilles/sprites_painted_g/atlases/`.

L’assemblage refuse une pose coupée par le canvas final ou dont la silhouette touche déjà un bord de cellule source. Aucun redimensionnement individuel ne masque une variation de proportions. Les GIF illustrent les poses : le moteur maintient le repos sur l’image 0, pilote la marche avec la distance parcourue et maintient la charge jusqu’à l’arrivée. La complétude du pack ne remplace ni l’import Godot, ni les tests runtime, ni la validation visuelle en salle.
