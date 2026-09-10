# Atelier des haltes peintes

Le **Sanctuaire des Sources Émeraude** est le premier lieu de cette chaîne : nouvelle illustration dans la direction de la Halle, monde de 2 200 unités de large, Achille jouable et effets localisés. Ouvrir `hub/painted_halt/LivingHalt.tscn`, puis **F6**. Il s'agit d'une étude autonome ; l'affectation actuelle de la Halle dans Catabase reste en place.

## Essayer et contrôler

PowerShell 7.2+, Godot défini par `tools/dev/toolchain.json`, Python 3.10+ avec Pillow (`python -m pip install -r tools/halt_workshop/requirements.txt`). Renseigner `GODOT4_BIN` ou `-GodotPath`. Pour les commandes Python, utiliser `-PythonPath` si Python n'est pas dans le PATH. Pour simplement jouer après un `git pull`, **Godot suffit** : l'image, les masques et la calibration sont versionnés.

```powershell
./tools/halt_workshop/halt.ps1 open
./tools/halt_workshop/halt.ps1 check
./tools/halt_workshop/halt.ps1 prepare
./tools/halt_workshop/halt.ps1 verify
./tools/halt_workshop/halt.ps1 test
```

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

1. **Créer un brief versionné.** La commande ajoute la direction commune au brief, conserve la référence à joindre et refuse d'écraser un dossier existant.

   ```powershell
   ./tools/halt_workshop/halt.ps1 new -Id jardin_jade_v1 -Kind sanctuary -Brief 'Un jardin sacré en ruines, bassins jade, chemins larges en boucle, torches de bronze, trois accès dégagés.'
   ```

2. **Générer avec la référence attachée.** Utiliser le texte `art/source/halts/jardin_jade_v1/generation_prompt.txt` et les images indiquées dans `request.json`. Le sanctuaire a été généré avec l'outil natif **image_gen**. Le choix du fournisseur est séparé de la préparation Godot. Sauvegarder le fichier original livré ; mesurer sa définition effective au lieu de supposer que la résolution demandée a été obtenue.

3. **Enregistrer l'original.** La copie reste identique octet pour octet ; l'outil mesure les dimensions et le SHA-256, puis crée un manifeste à calibrer.

   ```powershell
   ./tools/halt_workshop/halt.ps1 attach -Id jardin_jade_v1 -Image 'C:/chemin/vers/generation.png'
   ```

4. **Calibrer cette image.** Renseigner dans `data/halts/jardin_jade_v1.json` le titre, le fournisseur, le point d'arrivée, les allées, obstacles, matières, torches et points de contrôle. Les coordonnées sont des fractions de la taille source : `[x / largeur, y / hauteur]`. Le manifeste du sanctuaire est un exemple complet de structure, **pas un jeu de coordonnées à reprendre**. Une géométrie inventée à partir des couleurs de l'image n'est pas une navigation validée. Passer `stage` à `playable_study` une fois ce travail réalisé.

5. **Préparer puis vérifier.** `prepare -Map ...` produit uniquement le masque technique RGBA et son empreinte de construction. `verify -Map ...` importe le projet, réutilise l'inspection des décors du Studio, fait marcher Achille, contrôle les couches rendues et capture en 1 280 × 720 et 1 920 × 1 080. Examiner ces captures et les journaux du rapport dans `artifacts/dev/`.

6. **Revoir puis affecter la halte.** Après revue de l'image, des trajets et du mouvement, connecter le manifeste au nœud de halte voulu avec un adaptateur de présentation. Conserver l'identifiant du nœud, ses transactions de jeu et la sortie de halte. Les services d'édition du Studio restent la voie pour modifier le contenu et ses ressources. Cette première version ne fournit ni un nouvel éditeur visuel ni une affectation automatique au graphe.

## Ce qui maintient la famille artistique

`data/halts/styles/roots_bronze_v1.json` verrouille la vue élevée de trois quarts, la pierre bleu-gris, les racines, la mousse, le bronze patiné, les volumes peints et les contours lisibles. Les teintes jade/émeraude/turquoise, la fonction et l'architecture du lieu peuvent varier. Garder les torches ambre, les allées lisibles et les premiers plans bas. Ne pas générer de personnages, texte ou interface dans le décor.

Pour un lot de propositions, conserver **la même image maîtresse** : utiliser chaque résultat comme référence du suivant ferait dériver progressivement le style. Une variation de style intentionnelle reçoit un nouvel identifiant de style et une revue explicite.

## Le manifeste et ses couches

| Champ | Rôle |
| --- | --- |
| `source`, `style` | Image originale, dimensions, empreinte, prompt et famille artistique |
| `world` | Taille jouable indépendante du nombre de pixels, échelle et vitesse d'Achille, marge des pieds |
| `navigation` | Contour continu des allées et trous interdits ; navigation dédiée déjà utilisée par la Halle |
| `landmarks` | Destinations nommées et testées, utilisables ensuite par les interactions de halte |
| `water` | Surfaces d'eau et exclusions protégeant statues et fontaine |
| `cascades` | Polygones du flux, point d'impact et largeur de projection en pixels source |
| `torches` | Centre et rayons normalisés ; maximum 12, scintillement indépendant |
| `foliage`, `bounce` | Feuillage oscillant et surfaces de pierre recevant les reflets mobiles |
| `mist` | Rectangles normalisés `[x,y,largeur,hauteur]`, teinte et opacité de la brume |
| `foreground` | Découpes facultatives et ancrages de profondeur pour masquer Achille derrière le décor |
| `review` | Destinations interdites et échantillons de matières utilisés par les contrôles de rendu |

Le masque `materials.png` contient **R=eau, G=cascades, B=feuillage, A=reflets sur pierre**. Son alpha est une donnée ; `process/fix_alpha_border=false` est indispensable. L'original n'est jamais repeint par l'outil de préparation. Le runtime refuse une source, un manifeste ou un masque dont l'empreinte diffère du `build.json`.

## Donner de la vie sans saturer l'image

Le sanctuaire combine trois rythmes : caustiques et brume lentes, ondulation et feuillage modérés, flammes et gouttes rapides. Les effets suivent les matières ; les allées gardent une lecture stable. Les huit torches projettent des variations locales, les six chutes ont des projections et des anneaux, et Achille reçoit une légère lumière ambre/émeraude. Une seule horloge permet de figer tout le décor pendant une pause.

Les prochaines améliorations utiles sont une **ambiance sonore spatialisée** (sources, feu et pas), des micro-événements rares et des réactions aux interactions de halte. Elles ne sont pas encore implémentées. Il vaut mieux leur donner des causes et des emplacements précis que multiplier les particules au centre du chemin. Les PNJ pourront se greffer aux points d'intérêt plus tard.

## Portée et preuves

La source du sanctuaire est de **1 672 × 941 pixels**. Son monde est 60 % plus large que celui de la Halle (2 200 contre 1 376 unités), à échelle de personnage comparable. Le zoom apporte de la proximité, pas de nouveaux détails d'image. Une véritable source de plus haute définition nécessiterait une nouvelle version et une recalibration.

Les rapports incluent les commandes exactes, le contexte Git, l'import et les journaux moteur, les empreintes, les contrôles de déplacement et les captures. Un import en erreur, une exécution interrompue, zéro contrôle ou un rapport absent ne vaut pas succès. La revue visuelle reste humaine ; `prepare` ne déclare jamais une navigation validée. Consulter la [fiche de validation du sanctuaire](../../docs/maps/emerald_sanctuary_working_note.md) pour les exécutions effectuées et les limites.
