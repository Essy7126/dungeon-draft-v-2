# Production des effets sur une map de combat peinte

## Socle et référence concrète

Cette procédure complète la [pipeline de terrain enregistré](registered_terrain_pipeline.md).
Son premier exemple est Les traces du Léthé, étape II :
`assets/catabase/combat/lethe_traces_v1/` et `tools/lethe_map_review/`.
La [recherche initiale](lethe_shader_research_2026-09-11.md) explique les sources
techniques et les défauts de l'ancienne itération.

L'Autel des serments et l'Étal du passeur restent les références visuelles.
Partir de leurs peintures réelles, pas d'une description de style de mémoire.
Conserver leurs grandes formes, la pierre bleu-vert et les touches ambrées.
Les escales de début de run restent modestes. Sur le parcours du Léthé, la
barque et l'eau sont constantes ; les silhouettes de terrain et les étapes du
voyage doivent évoluer. Produire et examiner une salle à la fois.

## Préparation de la salle

1. Confirmer la ressource de destination et son étape dans le parcours.
2. Lire l'ArenaDefinition, le plan et le manifeste géométrique. Conserver une
   empreinte avant modification ; les effets visuels ne changent ni cellules,
   ni obstacles, ni déplacements, ni adversaires.
3. Pour une nouvelle peinture, préparer le guide depuis la géométrie canonique,
   ménager les surfaces de combat et les marges, joindre les références directes.
   La peinture ne doit pas inventer une deuxième grille ou des obstacles tactiques.
4. Relever les dimensions réelles de l'image, le canevas natif et la caméra.
   Ici : image 1586×992, canevas 1920×1200. Les coordonnées des masques et des
   lampes sont dans l'image ; le shader convertit les positions natives.
   Réévaluer cette conversion si la peinture change de résolution.
5. Délimiter les matières animées et les objets immobiles sur la peinture finale.
   Un masque visuel ne définit jamais une collision.

## Eau : ce qui est effectivement implémenté

`water_flow.json` contient les dimensions de l'image, le contour aquatique,
les exclusions (plateforme, coque, bornes, rochers), le centre du courant et
son facteur vertical. Le contrôleur construit une texture RGBA de 793×496 au
chargement : RG encode le vecteur signé de courant, B l'autorisation d'animer.
Ce champ est calculé autour d'un centre dessiné pour cette plateforme, puis
le shader le lit comme une carte de courant. Ce n'est pas une simulation
physique ni un solveur général de contournement des obstacles.

Le shader déplace les couleurs déjà peintes avec deux phases courtes décalées
d'une demi-période. Leur mélange masque les réinitialisations et limite
l'étirement. Un petit déphasage spatial évite que toute la surface redémarre
ensemble. Il n'ajoute plus de réseau de caustiques sinusoïdales.

Chaque échantillonnage déplacé doit rester dans l'eau. Quatre lectures voisines
à six pixels atténuent l'animation au contact des exclusions. Cette réserve
protège les détails fixes ; elle doit être contrôlée visuellement pour éviter
une bande d'eau figée trop large. Le filtrage linéaire adoucit le masque.

Valeurs de cette salle, à régler au zoom réel : excursion 19 pixels source,
fréquence de phase 0,19 cycle/seconde, mélange animé 0,88. Ce sont des réglages
locaux, pas des normes imposées à toutes les maps.

Pour un chenal différent, modifier le champ et ses exclusions. Un seul courant
circulaire ne convient pas à une cascade, un embranchement ou une rivière droite.
La prochaine généralisation peut accepter une carte RG peinte ou plusieurs
guides de courant ; elle n'est pas encore implémentée.

## Torche et lanterne : trois phénomènes distincts

La torche utilise une déformation locale de la flamme déjà peinte. Son pied
reste fixe au-dessus de la coupelle ; le déplacement augmente vers la pointe.
Le masque s'éteint avant le métal. La lumière projetée sur la pierre varie
séparément, sans déplacer la texture de pierre.

La lanterne conserve son cadre et sa coque. Son masque intérieur module la
luminance du verre, y compris vers le bas pour que le changement reste visible
dans une peinture déjà claire. Un halo local accompagne cette variation.
Les reflets ambrés déjà présents sur l'eau sont déplacés par le même courant
et modulés avec la lanterne.

La version actuelle reste un seul matériau CanvasItem `unshaded`, avec des
traitements spatialement séparés. Elle n'utilise ni sprite animé supplémentaire,
ni PointLight2D, ni bloom global. Le flipbook peint reste une alternative si
la déformation locale ne suffit pas. Ne pas prétendre qu'il est déjà livré.

Les centres, rayons et limites de lumière sont encore dans le shader local.
Pour une nouvelle salle, recalibrer ces positions sur l'image ; ne pas recopier
les coordonnées du Léthé. Leur extraction dans un schéma partagé sera une
évolution du socle, pas une capacité acquise de cette version.

## Intégration au combat et accessibilité

Le plan sélectionne le shader de `Land` et `Living.tscn` comme décor
`foreground`. Le contrôleur retrouve ainsi `Land` sous le même parent.
Une couche `y_sorted` change cette hiérarchie : l'ancien essai a échoué pour
cette raison. Vérifier le contrat du renderer avant de déplacer le contrôleur.

L'horloge `effect_time` est pilotée par le contrôleur plutôt que par `TIME`.
Le réglage de réduction des animations gèle les effets sans éteindre les
sources lumineuses. `seek_for_review()` permet des captures reproductibles.
Le format des masques est indépendant des règles de combat ; les services
Studio restent l'autorité lors d'une modification de salle.

## Vérification reproductible

Depuis PowerShell 7.2+, avec le moteur du projet configuré :

```powershell
./dev.ps1 test test/unit/test_catabase_route_layouts.gd
./tools/lethe_map_review/verify.ps1
./tools/lethe_map_review/open.ps1
```

Le premier lanceur effectue l'import et le test ciblé. Le second vérifie la
salle réelle via le reviewer commun en 1920×1080 et 1200×896 : géométrie,
matériaux, support des dalles, picking, déplacement, garde, cadrage et
comparaison des proportions. Le troisième ouvre un aperçu jouable avec des
données utilisateur isolées.

Le contrôle d'animation capture 48 états espacés de 0,20 seconde, soit 9,4
secondes entre premier et dernier état. Il vérifie l'avancement de l'horloge,
son gel en mouvement réduit, les variations dans l'eau/torche/lanterne et la
stabilité de points témoins du sol/coque/mur. Un témoin hors écran doit échouer,
pas produire un faux succès : le premier essai de cette reprise l'a révélé.

Ces mesures portent sur des régions échantillonnées. Elles ne prouvent ni
l'absence de tout débordement ailleurs, ni la qualité artistique, ni le budget
GPU. Lire les rapports complets et inspecter les images. Examiner aussi une
boucle au zoom de jeu : une capture fixe ne valide pas la continuité temporelle.
Vérifier les berges, les mâts/cadres, le pied des flammes et les reflets ;
comparer aux références et vérifier que les unités restent prioritaires.

Le résultat actuel a passé les contrôles techniques aux deux résolutions et
des captures fixes ont été inspectées. L'acceptation artistique de cette
nouvelle animation par l'utilisateur reste distincte. Aucun benchmark, export
packagé ou playtest complet de run n'est couvert par ces commandes.

## Livraison et apprentissages à conserver

- Garder la peinture, les données de masque, le shader, le contrôleur et les
  instructions nécessaires dans Git. Ne pas dépendre d'un fichier local ignoré
  pour afficher la map sur un autre ordinateur.
- Conserver dans la documentation les commandes, les identifiants de rapports,
  les limites et les corrections apportées. Les captures et logs volumineux
  restent dans `artifacts/dev/`, régénérables avec le reviewer.
- Distinguer trois statuts : fonctionnement technique, inspection visuelle,
  acceptation artistique. Un compteur de pixels modifiés n'est jamais une
  preuve d'un bon effet.
- Le bon principe réutilisable est de fournir une géométrie de matière et un
  mouvement adapté à la salle. La détection par couleur et les grands rectangles
  ne suffisent pas pour une peinture contenant des couleurs communes à l'eau
  et aux pierres.
- Après validation, commit précis puis push demandé par l'utilisateur.
  Vérifier que le SHA distant correspond au SHA local ; le commit seul ne
  rend pas le travail disponible sur son autre ordinateur.
