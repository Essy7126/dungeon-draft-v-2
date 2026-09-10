# Haltes peintes dans Dungeon Draft Studio

Ouvrir **Dungeon Draft Studio → Haltes peintes**, ou lancer
`res://addons/dungeon_draft_arena_studio/halts/HalteStudio.tscn` avec **F6**.
Le catalogue comprend les manifestes de `data/halts/`, dont le sanctuaire
émeraude et la forge de bronze. La navigation continue reste indépendante
de la grille des arènes ; les deux éditeurs partagent l’historique du Studio
et les services d’inspection des originaux.

## Construire un lieu

1. **Nouveau plan / version** crée un identifiant inédit. Tracer d’abord les
   allées, obstacles, arrivée et points d’interaction. Le bouton **Illustration**
   peut être désactivé pour retrouver le plan seul.
2. **Exporter le plan** produit un SVG versionné dans
   `art/source/halts/<id>/spatial_plan.svg`. Joindre ce plan à la référence
   artistique et au brief avant la génération de l’illustration.
3. **Joindre l’original…** accepte un fichier local PNG/JPEG/WebP. Le service
   conserve ses octets, dimensions et empreinte ; une version possédant déjà
   son original refuse son remplacement. Pour une nouvelle illustration,
   créer une nouvelle version et, si utile, reprendre les zones actuelles.
4. Calibrer les calques sur l’image. Les coordonnées restent normalisées,
   indépendantes du zoom et de la taille de la fenêtre.
5. **Enregistrer / préparer** vérifie puis écrit le manifeste et ses masques
   ensemble. Un plan sans image peut être enregistré avant cette étape.
6. **Explorer** lance le runtime commun avec la copie de travail, même non
   enregistrée. Cliquer pour marcher, rejoindre un lieu et essayer ses
   services. Les transactions utilisent une session d’essai isolée.

## Calibrer l’échelle avant de peindre

Régler **Hauteur d’Achille / image** dans l’inspecteur : la pose réelle debout,
lance et plumet compris, occupe cette fraction de l’image. Le défaut d’un nouveau
plan est 22 %. Le réglage conserve les proportions si la largeur du monde ou le
zoom change. **Repère Achille** superpose cette pose et une règle ; **Alt+clic**
la place près d’un objet sans changer la géométrie du plan ni l’arrivée.
L’export SVG inclut les silhouettes à l’arrivée et aux points d’approche.
Elles servent de références de génération et doivent disparaître du décor livré.

Comparer le seau, le plan de travail et l’ouverture de porte depuis leur propre
sol adjacent. Une plateforme surélevée doit être prise en compte. Régler la
**Marge des pieds**, puis tester tous les passages dans **Explorer**. Consulter
la [grille et les trois étapes de revue](../../../tools/halt_workshop/README.md#verrouiller-les-proportions-avant-de-peindre)
avant de valider la prochaine image. La Forge utilise 24 % après comparaison
au four, à l’enclume et à l’arche ; son ensemble central reste massif dans l’asset.

## Gestes

| Geste | Résultat |
| --- | --- |
| Choisir un calque puis **Dessiner / placer** | Tracer un polygone ou placer un point |
| Entrée, double clic ou **Terminer** | Fermer le polygone après au moins trois sommets |
| Glisser un sommet ou une croix | Modifier la géométrie ou son ancrage |
| Double clic sur une arête | Insérer un sommet |
| Suppr | Retirer le sommet sélectionné, ou la zone sans sommet sélectionné |
| Échap | Annuler le geste en cours sans ajouter d’historique |
| Molette | Zoom sous le pointeur |
| Clic milieu + déplacement | Déplacer la vue |
| Alt+clic | Placer le repère Achille près d’un objet, sans modifier les zones |
| **Cadrer** | Revenir au cadrage initial |
| Ctrl+Z / Ctrl+Y | Annuler / rétablir un geste complet |

Le contour extérieur et l’arrivée ne se suppriment pas ; les redessiner pour
les remplacer. Un polygone ne descend jamais sous trois sommets. Les cases
près des calques contrôlent leurs superpositions, sans modifier les données.

## Profondeur et interactions

Les **premiers plans** sont des découpes de l’image originale. Leur croix
blanche fixe le pied du volume : Achille passe derrière quand ses pieds sont
au-dessus de cet ancrage. La croix d’une **cascade** fixe son impact.

Une **interaction** possède un point d’approche au sol (`point`) et un objet
cliquable (`focus`, croix blanche), avec une portée de clic normalisée
(`radius`). Son `action` choisit l’ordre des services communs : sanctuaire,
marchand, repos, dialogue ou sortie. Le texte vient de `description`.
La scène conserve les transactions et la sortie de la session de halte.

## Matières et sauvegarde

L’inspecteur règle les courants par bassin, la teinte de l’eau, la largeur
des projections et les intensités séparées de flamme, lumière et fumée.
**Animer les matières** montre le shader partagé directement sur le canevas ;
les masques de la copie de travail sont recalculés après une courte pause
d’édition. **Explorer** vérifie aussi Achille, la profondeur, les interactions,
l’atmosphère et le son dans la scène réelle.

Les changements restent dans la copie de travail jusqu’à l’enregistrement.
Une récupération locale est conservée sous `user://dungeon_draft/painted_halts`
lors d’un changement de document ou d’une fermeture. À la reprise,
l’enregistrement refuse d’écraser une source modifiée ailleurs depuis son
chargement. Revoir le travail récupéré avant de résoudre cette divergence.

## Vérifications

- `test/unit/test_painted_halt_studio_interactions.gd` injecte de vrais clics,
  glissements, touches et zooms dans un viewport isolé.
- `test/unit/test_painted_halt_studio_preview.gd` passe une copie non enregistrée
  au runtime, fait marcher Achille par un clic dans l’aperçu redimensionné,
  vérifie le shader et l’absence d’écriture du manifeste source.
- `test/unit/test_painted_halt_manifest_service.gd` contrôle les versions,
  originaux, sauvegardes et masques.
