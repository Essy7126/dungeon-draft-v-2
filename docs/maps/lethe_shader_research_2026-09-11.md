# Léthé II — recherche eau, torche et lanterne

## Statut et périmètre

Retour utilisateur du 11 septembre 2026 : eau mal rendue, effets de torche et
de lampe imperceptibles. Les contrôles GPU précédents attestent des variations
de pixels, pas d'une qualité artistique acceptée. Cette note est une proposition
de reprise ; aucun nouveau shader n'est implémenté ou validé ici.

Cible : `data/rooms/catabase_routes/route_f51a86b714b9/room.tres`,
Les traces du Léthé, étape II. Références visuelles inchangées :
`asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png` (Autel des serments)
et `asset/map/painted/merchant/hall_v1/hall.png` (Étal du passeur).
Début de run sobre ; eau et barque sont le fil conducteur des cinq escales.

## Diagnostic du code existant

Dans `assets/catabase/combat/lethe_traces_v1/living.gdshader` :

- L'eau est identifiée par sa couleur, puis exclue par deux grands rectangles.
  Cela ne décrit ni les véritables berges ni la coque ; les pierres turquoise
  peuvent satisfaire le même critère de couleur.
- Des sinusoïdes déplacent la peinture et ajoutent des lignes lumineuses sans
  suivre un courant dessiné pour cette salle.
- Torche et lanterne reçoivent uniquement une addition de lumière. Leur forme
  reste fixe ; le clamp final à 1 peut écrêter les variations des pixels clairs.
- Le matériau est `unshaded` : ajouter simplement une PointLight2D ne suffirait
  pas à éclairer ce matériau via le calcul de lumière du moteur.

## Recherche et adaptation proposée

### Eau : un courant dirigé, une texture peinte préservée

Valve décrit une carte de vecteurs de courant pilotant le déplacement des UV.
Deux animations courtes décalées d'une demi-phase masquent leurs redémarrages ;
un déphasage spatial aide à réduire les pulsations. Leur présentation traite
aussi le déplacement des textures de couleur, avec une déformation limitée.
Source primaire : [Alex Vlachos, Water Flow in Portal 2, slides 8, 22–24,
31–38 et 40–46](https://cdn.cloudflare.steamstatic.com/apps/valve/2010/siggraph2010_vlachos_waterflow.pdf).

Adaptation proposée pour notre peinture : masque explicite de l'eau, carte de
courant suivant le chenal et contournant la barque, quelques touches de reflets
peintes animées. Atténuer le déplacement aux berges et empêcher l'échantillonnage
de tirer la pierre dans l'eau. Conserver de grandes zones calmes. Le masque,
le courant et les détails doivent être propres à chaque salle ; l'algorithme
peut être commun. Les matériaux des haltes disposent déjà de `materials` et
`flow_map` : réutiliser ce contrat lorsque pertinent, après vérification de son
intégration au terrain enregistré.

### Torche : animer la flamme et sa lumière séparément

Godot permet l'animation d'images avec AnimatedSprite2D ou AnimationPlayer.
Source : [documentation des sprites animés](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html).

Choix artistique proposé : petite séquence de flammes peintes, ou déformation
strictement masquée de la flamme, avec pied fixe et pointe mobile. Le support
reste immobile. Si une couche remplace la flamme intégrée à la peinture, traiter
la flamme d'origine pour éviter une double silhouette. Ajouter une lueur douce
sur une zone de pierre choisie, synchronisée avec la flamme, sans flash régulier.

### Lanterne : cœur lumineux, cadre fixe, reflet dans l'eau

La documentation Godot distingue la texture de lumière, son énergie et les
masques des surfaces éclairées. Elle explique aussi qu'une scène déjà pleinement
éclairée devient seulement plus claire avec un éclairage additif.
Sources : [lumières 2D](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)
et [modes CanvasItem, dont unshaded](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html).

Adaptation proposée : variation visible à l'intérieur du verre, halo local
texturé et reflet chaud fragmenté sur l'eau. Ne pas déformer le cadre ou la
coque. Préférer d'abord des couches locales contrôlées pour préserver l'éclairage
déjà peint ; évaluer PointLight2D seulement avec des récepteurs compatibles.
Le reflet doit suivre le même courant que l'eau.

## Protocole avant adoption dans la pipeline

1. Travailler uniquement l'eau de la map II, puis la torche, puis la lanterne.
2. Comparer une boucle animée de 8 à 12 secondes et la version sans effet au
   zoom de jeu, en 1920×1080 et 1200×896 ; un gros plan seul ne suffit pas.
3. Vérifier : courant compréhensible, berges/coque stables, absence de raccord
   rectangulaire, flamme visible, lumière sans écrêtage dominant, dalles et unités
   prioritaires. Comparer directement aux deux références artistiques.
4. Rejouer les contrôles existants de géométrie, clics, déplacement, cadrage et
   réduction des animations. Ils restent nécessaires mais distincts du jugement
   visuel et du retour utilisateur.
5. Après validation visuelle, documenter les paramètres réutilisables : textures,
   masques, courant, ancrages et intensités par salle. Garder la géométrie et les
   règles de combat sous l'autorité de la pipeline de terrain enregistré.

Le socle doit permettre des salles différentes ; aucune génération des quatre
escales suivantes n'est engagée par cette recherche.
