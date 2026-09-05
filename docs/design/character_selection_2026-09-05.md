# Sélection de personnage — Catabase

## Référence observée

Capture locale de la fenêtre Dofus le 5 septembre 2026, 2560 × 1600, sans interaction avec le client ni lecture de ses fichiers. L’outil de pilotage du bureau n’a pas démarré (`apply deny-read ACLs`) ; le script existant `tools/reference_capture/capture_dofus.ps1` a permis la capture en lecture seule.

Les images effectivement observées sont l’accueil et **« Choix d’un serveur »**. La seconde montre une composition ouverte sur un décor illustré, une navigation supérieure stable, de grandes cartes illustrées, une sélection persistante au contour jaune très contrasté, et un bouton Jouer isolé en bas. Les informations secondaires restent attachées à leur carte.

La sélection/création de personnage de Dofus n’a pas été observée dans ces captures. Les animations de ses panneaux, leurs comportements au survol, leur code et leurs technologies internes ne sont pas déduits des pixels. La disposition de notre fiche de personnage ci-dessous est une proposition du projet.

Références locales : `artifacts/reference_capture/dofus_20260905_150716.png`, `dofus_character_selection_20260905.png` et `dofus_character_selection_final.png`. Ces captures sont des références de travail, pas des assets distribués avec le jeu.

## Interface livrée

- Colonne de gauche : quatre personnages réellement présents, portrait, rôle, aventure solo ou trio, bordure persistante de sélection et focus clavier distinct.
- Centre : nom et rôle, sanctuaire original peint, aperçu du visuel utilisé en jeu, quatre orientations et animations disponibles. Les commandes indisponibles sont désactivées avec explication.
- Colonne de droite : PV, PA, PM, initiative et armure provenant du personnage résolu ; quatre icônes de capacité et détails sélectionnables ; onglet histoire et disciplines.
- Bas : aventure et composition exacte du groupe, puis action principale. Le choix d’Elfe, Mage ou Guerrier conserve le trio fixe ; il ne crée pas de run solo fictive.
- Apparence : seule la tenue actuelle est annoncée. Aucun inventaire cosmétique ni fausse variante de skin n’a été ajouté.

Palette : encre bleu vert, surfaces sombres, bronze clair et textes crème. Cinzel pour les noms, Atkinson Hyperlegible pour les données. Le décor est indépendant des éléments interactifs et utilise un dessin de repli si l’illustration manque.

## Parcours

`TitreEcran` → `CharacterSelectionScreen` → configuration de la run sélectionnée → introduction existante → pipeline de combat existant. La configuration n’altère pas les ressources des personnages ni le groupe défini par chaque run. Un échec de transition réactive le bouton.

Le bouton **Le refuge** conserve l’accès au hub et à l’Archiviste. Retour à l’accueil et Échap quittent la sélection sans démarrer d’aventure.

L’écran utilise un canevas 1440 × 900 mis à l’échelle uniformément et centré. Le décor suit exactement le même cadrage. Il ne dépend pas de la résolution du projet pour positionner ses panneaux.

## Fichiers et fabrication

- `ui/selection/CharacterSelectionScreen.tscn` et `character_selection_screen.gd` : scène et interactions.
- `ui/selection/character_selection_catalog.gd` : catalogue construit depuis `RunHeroResolver`, avec les sorts réels des profils.
- `ui/selection/selection_backdrop.gd` : décor et dessin de repli.
- `asset/ui/character_selection/sanctuary_v1.png` : illustration originale générée avec l’outil intégré `image_gen` ; [prompt exact](../../art/source/character_selection/sanctuary_v1_prompt.md).
- `asset/ui/character_selection/portraits/` : portraits du trio rendus depuis les modèles du jeu.
- `tools/character_selection/render_portraits.gd` : reproduction des portraits.
- `tools/character_selection/selection_review.gd` : captures et simulation des clics, du menu jusqu’à l’introduction.

## Vérification

Les 9 tests de `test/unit/test_character_selection_screen.gd` passent : 112 assertions sur les données résolues, les sélections, les orientations/animations réelles, le groupe lancé et la reprise après refus de configuration. Le runner du refuge passe également après adaptation au nouveau parcours.

La revue rendue produit les états Achille, Garde d’airain, histoire, Mage et les résolutions 1200 × 896 et 1920 × 1080, avec rapport dans `artifacts/character_selection/review.json`. Elle vérifie des clics injectés dans Godot, la navigation depuis le titre et le transfert de la run Catabase à l’introduction.

Commandes depuis la racine, en remplaçant `godot` par l’exécutable local si nécessaire :

```powershell
godot --path . res://ui/selection/CharacterSelectionScreen.tscn
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_character_selection_screen.gd -gexit
godot --path . --resolution 1440x900 --script res://tools/character_selection/selection_review.gd
godot --headless --path . res://tools/VerifyMenuStartHubFlow.tscn
```

La suite globale n’est pas certifiée : un premier lancement a hérité de `.gutconfig.json` et collecté des tests historiques sans rapport, dont des contrats 3D Achille incompatibles avec son rendu sprite courant. Il a été interrompu, puis les tests concernés ont été isolés explicitement avec `-gconfig=`. L’import éditeur se termine avec des avertissements de ressources à la fermeture ; la revue rendue ciblée est contrôlée séparément.
