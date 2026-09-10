# Atelier des haltes peintes

Le **Sanctuaire des Sources Émeraude** est le premier lieu de cette chaîne : nouvelle illustration dans la direction de la Halle, monde de 2 200 unités de large, Achille jouable et effets localisés. Ouvrir `hub/painted_halt/LivingHalt.tscn`, puis **F6**. La scène directe reste une visite d’essai isolée. Le sanctuaire et la Forge des Racines servent également de présentations aux haltes ordinaires sanctuaire et marchand de l’étape VIII de Catabase ; la Halle de l’étape IV garde son affectation.

## Créer dans le Studio

Ouvrir **Dungeon Draft Studio → Haltes peintes**, ou lancer
`addons/dungeon_draft_arena_studio/halts/HalteStudio.tscn` avec **F6**.
Le [guide de l’éditeur](../../addons/dungeon_draft_arena_studio/halts/README.md)
décrit les plans, contours, ancres, courants, torches, annulations et essais.
L’édition et la préparation natives nécessitent seulement Godot.

Dessiner le plan spatial avant l’illustration, puis **Exporter le plan** pour
le joindre au brief et à la référence artistique commune. **Joindre l’original…**
conserve le fichier dans une nouvelle version. Recaler les contours sur l’image,
puis **Explorer** permet de tester la copie non enregistrée avec Achille.
L’essai possède sa propre visite : aucune transaction ne touche la partie ouverte.

## Essayer et contrôler

PowerShell 7.2+, Godot défini par `tools/dev/toolchain.json`, Python 3.10+ avec Pillow (`python -m pip install -r tools/halt_workshop/requirements.txt`). Renseigner `GODOT4_BIN` ou `-GodotPath`. Pour les commandes Python, utiliser `-PythonPath` si Python n'est pas dans le PATH. Pour simplement jouer après un `git pull`, **Godot suffit** : l'image, les masques et la calibration sont versionnés.

```powershell
./tools/halt_workshop/halt.ps1 open
./tools/halt_workshop/halt.ps1 check
./tools/halt_workshop/halt.ps1 prepare
./tools/halt_workshop/halt.ps1 verify
./tools/halt_workshop/halt.ps1 test
./dev.ps1 test halts
./tools/halt_workshop/halt.ps1 verify -Map res://data/halts/bronze_forge_v1.json
./tools/halt_workshop/verify_production.ps1 -Kind merchant
```

`verify_production.ps1` accepte `-Kind merchant` ou `-Kind sanctuary` et contrôle le raccord Catabase :
vrai GameManager, écran de production, reçu sauvegardé, inventaire, aller-retour
au parchemin et départ. Son lanceur isole les données utilisateur dans son rapport ;
il ne reprend aucune partie personnelle. La scène de contrôle refuse un lancement
F6 sans cette isolation.

`-Map res://data/halts/nom_v1.json` sélectionne un autre manifeste. `verify -Record` enregistre également 336 images réelles Godot, à 24 images/s, sous le rapport de l'exécution. Les commandes ne contactent aucun service de génération.

| Commande dans la map | Action |
| --- | --- |
| Clic sur le sol / boutons des lieux | Achille rejoint la destination en contournant les bassins |
| Clic dans l'eau | Onde locale |
| Clic droit | Arrêt |
| Molette / + / − | Zoom jusqu'à 165 %, centré sur Achille |
| Espace / Tab | Pause complète / comparaison avec l'illustration |
| H / F / F1 | Masquer les commandes / plein écran / navigation |
| Eau, Torches, Atmosphère, Feuillage | Isoler les couches |
| Mouvement doux | Réduire l'intensité des effets |

## Produire la suivante

1. **Dessiner un plan spatial, puis créer un brief versionné.** Le Studio exporte un SVG ; le CLI accepte également `new -Plan chemin/plan.png` pour joindre un plan visuel (image ou SVG) ; le brief conserve aussi son document éditable `spatial_plan.json`.  La commande ajoute la direction commune et le contrat de proportions au brief, conserve la référence à joindre et refuse d'écraser un dossier existant. Le nouveau plan fixe `world.player_height_ratio` à `0.22` : la pose de référence d’Achille occupe 22 % de la hauteur image, des pieds au sommet de la silhouette, lance comprise.

   ```powershell
   ./tools/halt_workshop/halt.ps1 new -Id jardin_jade_v1 -Kind sanctuary -Brief 'Un jardin sacré en ruines, bassins jade, chemins larges en boucle, torches de bronze, trois accès dégagés.'
   ```

2. **Générer avec la référence attachée.** Utiliser le texte `art/source/halts/jardin_jade_v1/generation_prompt.txt` et les images indiquées dans `request.json`. Le sanctuaire a été généré avec l'outil natif **image_gen**. Le choix du fournisseur est séparé de la préparation Godot. Sauvegarder le fichier original livré ; mesurer sa définition effective au lieu de supposer que la résolution demandée a été obtenue.

3. **Enregistrer l'original.** La copie reste identique octet pour octet ; l'outil mesure les dimensions et le SHA-256, puis crée un manifeste à calibrer. Le CLI conserve les réglages `world` du plan, dont son ratio de hauteur ; il ajoute `0.22` si le ratio manque et refuse une valeur invalide avant toute installation.

   ```powershell
   ./tools/halt_workshop/halt.ps1 attach -Id jardin_jade_v1 -Image 'C:/chemin/vers/generation.png'
   ```

4. **Calibrer cette image.** Renseigner dans `data/halts/jardin_jade_v1.json` le titre, le fournisseur, le point d'arrivée, les allées, obstacles, matières, torches et points de contrôle. Les coordonnées sont des fractions de la taille source : `[x / largeur, y / hauteur]`. Le manifeste du sanctuaire est un exemple complet de structure, **pas un jeu de coordonnées à reprendre**. Une géométrie inventée à partir des couleurs de l'image n'est pas une navigation validée. Passer `stage` à `playable_study` une fois ce travail réalisé.

5. **Préparer puis vérifier.** `prepare -Map ...` produit le masque technique `materials.png`, la carte des courants `flow.png` et leurs empreintes dans `build.json`. `verify -Map ...` importe le projet, réutilise l'inspection des décors du Studio, fait marcher Achille, contrôle les couches rendues et capture en 1 280 × 720 et 1 920 × 1 080. Examiner ces captures et les journaux du rapport dans `artifacts/dev/`.

6. **Revoir puis affecter la halte.** Après revue explicite des proportions d’Achille et des objets, de l'image, des trajets et du mouvement, connecter le manifeste au nœud de halte voulu avec un adaptateur de présentation. Conserver l'identifiant du nœud, ses transactions de jeu et la sortie de halte. Les services d'édition du Studio restent la voie pour modifier le contenu et ses ressources. Les affectations de présentation sont dans `data/halts/route_bindings.json`. La sélection conserve les identifiants, transactions et sauvegardes existants ; les choix de progression restent prioritaires. Le Studio édite le lieu, tandis que ce catalogue déclare son affectation au parcours.

## Ce qui maintient la famille artistique

`data/halts/styles/roots_bronze_v1.json` verrouille la vue élevée de trois quarts, la pierre bleu-gris, les racines, la mousse, le bronze patiné, les volumes peints et les contours lisibles. Les teintes jade/émeraude/turquoise, la fonction et l'architecture du lieu peuvent varier. Garder les torches ambre, les allées lisibles et les premiers plans bas. Ne pas générer de personnages, texte ou interface dans le décor.

Pour un lot de propositions, conserver **la même image maîtresse** : utiliser chaque résultat comme référence du suivant ferait dériver progressivement le style. Une variation de style intentionnelle reçoit un nouvel identifiant de style et une revue explicite.

## Verrouiller les proportions avant de peindre

`world.player_height_ratio` désigne la hauteur de référence **H**, du point de pieds
au sommet visible de la pose `idle_S` d’Achille, **lance et plumet compris**, divisée par la
hauteur de l’image. Le défaut des nouvelles créations est `0.22` ; seules les valeurs
finies entre `0.06` et `0.35` sont admises. Ce ratio prend la priorité sur
`player_scale`. Un ancien manifeste sans ratio conserve son échelle historique.
La largeur du monde règle les distances jouables ; le zoom et la résolution ne
corrigent pas une disproportion entre personnage et mobilier.

Le mobilier se compare désormais à **B**, hauteur corporelle hors lance et plumet.
Sur la pose actuelle, B = 202 px (pieds y=320 à calotte du casque y≈118, ±2 px),
et H = 257 px. Le crâne étant caché, cette mesure avec casque est une convention
de travail. Refaire la mesure si le sprite ou son ancre change. Pour une maquette
métrique : `player_height_ratio = hauteur projetée du corps / hauteur image × 257/202`.

La grille suivante est une cible artistique pour cette famille, à examiner sur le
sol adjacent de chaque objet. La largeur du corps exclut les armes. Mesurer le corps
du seau sans son anse, le plan de travail depuis son sol, et séparer un socle ou une
flamme de l’objet lui-même. La boîte englobante d’un meuble en trois quarts inclut
sa profondeur et ne mesure pas sa hauteur.

| Repère | Proportion de référence |
| --- | --- |
| Corps du seau | `0.15–0.25 B` en hauteur, sans anse |
| Enclume avec souche ou surface de l’établi | `0.45–0.55 B` au-dessus du sol adjacent |
| Ouverture praticable de porte | `1.3–1.6 B` du sol au linteau |
| Allée | Au moins trois largeurs de corps libres au sol |

Un four monumental peut dépasser B ; cette intention ne rend pas les outils usuels
monumentaux. Trois contrôles sont nécessaires :

1. **Avant génération**, placer dans le plan trois silhouettes de référence de même
   hauteur à l’entrée, près de l’enclume et à la sortie, avec leurs pieds sur le sol
   concerné. Le brief doit reprendre le ratio et la grille. Si le ratio du plan
   change après `new`, synchroniser `generation_prompt.txt` et le prompt de
   `request.json` avant de générer. Les silhouettes et graduations appartiennent à
   la référence ; l’illustration finale reste sans personnage ni marques.
2. **Sur l’original reçu**, superposer la vraie pose d’Achille au ratio convenu aux
   trois positions, sans modifier la source. Comparer pieds, hauteur du plan de
   travail, seau et ouverture. Réviser l’illustration si les objets réclament des
   échelles contradictoires ; un seul objet trop grand ne doit pas imposer la taille
   de tout le monde.
3. **Après intégration**, examiner ces mêmes comparaisons en jeu à 720p et 1080p,
   au zoom normal puis rapproché, ainsi que le passage et l’occultation derrière le
   mobilier. Les proportions relatives doivent rester constantes. Cette revue
   visuelle précède l’affectation à une route ; `check` et `prepare` vérifient les
   valeurs, sans certifier les dimensions des objets peints.

## Le manifeste et ses couches

| Champ | Rôle |
| --- | --- |
| `source`, `style` | Image originale, dimensions, empreinte, prompt et famille artistique |
| `world` | Largeur jouable, `player_height_ratio` rapporté à la hauteur image (ou `player_scale` historique), vitesse d’Achille et marge des pieds |
| `navigation` | Contour continu des allées et trous interdits ; navigation dédiée déjà utilisée par la Halle |
| `landmarks` | Approche `point`, cible visuelle `focus`, `radius`, `action` et `description` ; marchand, sanctuaire, repos, mémoire ou sortie |
| `water` | Surfaces, exclusions et `regions` : polygone, direction `[x,y]` et vitesse de 0 à 4 |
| `cascades` | Polygones du flux, point d'impact et largeur de projection en pixels source |
| `torches` | Centre et rayons normalisés ; maximum 12, scintillement indépendant |
| `foliage`, `bounce` | Feuillage oscillant et surfaces de pierre recevant les reflets mobiles |
| `mist` | Rectangles normalisés `[x,y,largeur,hauteur]`, teinte et opacité de la brume |
| `foreground` | Découpes et ancrages de profondeur pour masquer Achille derrière le décor |
| `ambience` | Sources d’eau ou de feu localisées et pas de pierre ; pause et bouton Son |
| `review` | Destinations interdites et échantillons de matières utilisés par les contrôles de rendu |

Le masque `materials.png` contient **R=eau, G=cascades, B=feuillage, A=reflets sur pierre**. Son alpha est une donnée ; `process/fix_alpha_border=false` est indispensable. L'original n'est jamais repeint par l'outil de préparation. Le runtime refuse une source, un manifeste ou un masque dont l'empreinte diffère du `build.json`.

Les courants de `flow.png` encodent la direction dans RG, la vitesse divisée par
4 dans B et la couverture d’eau dans A. Le hachage du manifeste normalise UTF-8
et les fins de ligne LF/CRLF (`lf_utf8_v1`). La préparation native et Python
partagent les mêmes canaux ; leur adoucissement des contours est propre à chaque
moteur, et chaque préparation est reproductible avec le même moteur. Les couches
d’eau, cascades, feuillage et reflets sont facultatives : une forge sèche ne
requiert aucun échantillon d’eau.

## Donner de la vie sans saturer l'image

Le sanctuaire combine trois rythmes : caustiques et brume lentes, ondulation et feuillage modérés, flammes et gouttes rapides. Les effets suivent les matières ; les allées gardent une lecture stable. Les huit torches projettent des variations locales, les six chutes ont des projections et des anneaux, et Achille reçoit une légère lumière ambre/émeraude. Une seule horloge permet de figer tout le décor pendant une pause.

Des sources sonores suivent la position d’Achille : eau, feu et pas de pierre.
Les trois samples originaux sont reproductibles avec
`python tools/halt_workshop/synthesize_ambience.py`. Leur pause suit celle du lieu.
Le bouton **Son** permet de les couper. Les premiers plans masquent correctement
le personnage ; l’autel et les lieux de service réagissent à l’approche et aux
transactions. Les interactions de production réutilisent le pont SanctuarySession
et GameManager : un échec d’enregistrement attend une reprise, sans répéter l’achat.
Les PNJ et les déplacements à plusieurs niveaux ne font pas partie de ce mode.

## Portée et preuves

La source du sanctuaire est de **1 672 × 941 pixels**. Son monde est 60 % plus large que celui de la Halle (2 200 contre 1 376 unités). Cette largeur ne garantit aucune proportion du personnage : le ratio de hauteur fixe désormais cette relation pour les nouvelles créations. Le zoom apporte de la proximité, pas de nouveaux détails d'image. Une véritable source de plus haute définition nécessiterait une nouvelle version et une recalibration.

La forge sèche éprouve le même runtime avec une navigation et une calibration propres. Son plan, prompt, provenance et revue sont dans `art/source/halts/bronze_forge_v1/`. La [fiche de mission](../../docs/maps/living_halts_mission_2026-09-10.md) suit les validations de cette évolution.

Les rapports incluent les commandes exactes, le contexte Git, l'import et les journaux moteur, les empreintes, les contrôles de déplacement et les captures. Un import en erreur, une exécution interrompue, zéro contrôle ou un rapport absent ne vaut pas succès. La revue visuelle reste humaine ; `prepare` ne déclare jamais une navigation validée. Consulter la [fiche de validation du sanctuaire](../../docs/maps/emerald_sanctuary_working_note.md) pour les exécutions effectuées et les limites.

## Pilote Blender → peinture → calques

L’[Atelier du Bronze](../../docs/maps/bronze_workshop_pilot_2026-09-10.md) éprouve
la chaîne complète avec le corps d’Achille, une maquette métrique, une peinture
guidée, un fond sous les objets et un fichier Krita/OpenRaster éditable.
Le lanceur `verify` accepte `-WaitForEngineSeconds 55` pour attendre le moteur
partagé directement dans la prise de verrou, sans relancer une autre tâche.
