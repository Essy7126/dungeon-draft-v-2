# Validation de Catabase et du build recomposable

Ces contrôles utilisent Godot 4.7 et le moteur de combat du projet. Aucun fichier
de sauvegarde du joueur n'est nécessaire. Les scripts de test ne doivent pas être
présentés comme une validation de l'équilibrage ou du plaisir de jeu.

## Exécution

Depuis la racine du dépôt, remplacer `godot` par le chemin du binaire local :

```text
godot --headless --editor --recovery-mode --path . --import
godot --headless --path . --script res://tests/expedition/route_state_test.gd
godot --headless --path . res://tests/expedition/build_state_test.tscn
godot --headless --path . res://tests/expedition/session_integration_test.tscn
godot --headless --path . res://tests/expedition/BattleFlowProbe.tscn
godot --headless --path . res://tests/expedition/CatabaseMapsTest.tscn
```

Dans un environnement restreint, ajouter à chaque commande `--log-file` suivi
d'un chemin absolu accessible en écriture. Le mode d'import `--recovery-mode`
évite de lancer les outils d'édition et leurs traitements automatiques.

Le code de sortie doit être zéro **et** le journal ne doit contenir aucun
`SCRIPT ERROR`, `Parse Error` ou `Compile Error`. Godot peut continuer un script
après une erreur d'exécution ; un compteur d'assertions seul ne suffit donc pas.

## Périmètre

| Contrôle | Ce qu'il vérifie |
| --- | --- |
| `route_state_test.gd` | Déterminisme, chemins de vingt étapes, enveloppe de 14–16 combats, visibilité, secrets, transitions et restauration atomique. |
| `build_state_test.tscn` | Départ fixe, racines, découvertes, coûts, formes exclusives, kit, capacités, douze équipements, sauvegarde et effets réels de `SpellCaster`. |
| `session_integration_test.tscn` | Lancement canonique de Catabase, vingt destinations, XP unique par victoire, transactions multiples des haltes, reçus et stocks, équipement, cinquième/sixième emplacements, reprise atomique et isolation du trio. |
| `MerchantHallIntegration.tscn` | Première halte marchande dans la Halle parcourable : entrée/reprise, achats/repos/mémoire, reçus, préparatifs, sortie et récupération après échec d’écriture. Avec `--capture`, rendu réel à 720p/1080p ; sauvegardes isolées dans `artifacts/merchant_hall/`. |
| `BattleFlowProbe.tscn` | Vraie première victoire avec les quatre sorts canoniques, puis achat Colère/Crochet, remplacement de Garde, récompense et retour sur la carte. |
| `CatabaseMapsTest.tscn` | Dix arènes supplémentaires, sources auteur, sérialisation Studio/disque, grille runtime, connexité, formations sur 24 graines et plans de rendu. |

L'intégration remplace uniquement le lancement des scènes de combat par un
compteur et appelle explicitement les résultats de victoire. Les sorts sont
exécutés séparément dans la suite de build. Cette distinction doit rester claire
dans tout compte rendu de validation.

Le test d'intégration redirige ses sauvegardes vers des fichiers uniques dans le
répertoire temporaire système, puis supprime uniquement ces fichiers. Il vérifie
la reprise d'une entrée de combat, d'un écran de récompense et de la carte ;
Catabase ne sauvegarde pas le milieu d'un combat.

`BattleFlowProbe.tscn` joue un combat réel avec les scènes et ressources du jeu.
Il constitue un smoke test de branchement, pas une mesure de difficulté : les
intentions du joueur sont conduites par le probe, les ennemis utilisent leur IA réelle.

## Régressions ciblées

Le paramètre vide `-gconfig=` empêche `.gutconfig.json` d'ajouter toute la suite
historique à une sélection ciblée :

```text
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://test/unit/test_catabase_champion_run.gd -gtest=res://test/unit/test_character_progression_foundation.gd -gtest=res://test/unit/test_run_flow_isolation.gd -gtest=res://test/unit/test_champion_runtime_integration.gd -gtest=res://test/unit/test_spell_modifier.gd -gtest=res://test/unit/test_champion_spell_tooltips.gd -gexit
```

Les contrôles de rendu de Catabase sont dans `ExpeditionUIProbe.tscn`.
Ils nécessitent un pilote graphique réel : le moteur de rendu factice de
`--headless` ne produit pas de capture visuelle exploitable.

```text
godot --path . --rendering-method gl_compatibility res://tests/expedition/ExpeditionUIProbe.tscn -- resolution=1280x720
godot --path . --resolution 1280x720 res://tests/expedition/CatabaseMapsRuntimeProbe.tscn -- capture=true
```

Le séparateur `--` transmet la résolution au probe. Le probe peut tout de même
être lancé en tête seule pour vérifier la structure, les débordements et les
boutons ; il signalera alors les images comme volontairement ignorées.

Le probe UI ouvre la carte depuis le vrai HUD de combat, contrôle le verrou et sa
fermeture, puis simule la progression pour afficher l'arbre, les haltes, une branche
découverte, le choix XII et la reprise depuis le titre. Le probe des maps charge
les dix scènes, déploie Achille et vérifie les quatre sorts ; il ne joue pas dix victoires.

La suite historique `test_catabase_champion_run.gd` garde une fixture explicite
de cinq salles pour les anciens contrats du sous-système Champion. La production
Catabase à carte est couverte par les probes de ce dossier. Les tests historiques
ne constituent pas une validation de la nouvelle durée ni de son équilibrage.

## Habillage Meshy

La suite GUT `res://test/unit/test_catabase_meshy_art.gd` exige les assets de
production : 46 sorts illustrés, douze équipements, neuf glyphes de statistiques,
les emblèmes, marqueurs de route, icônes de navigation et textures d'interface.
Elle vérifie aussi la confidentialité des destinations inconnues et la remise en
place des thèmes d'origine pour les autres aventures.

```text
godot --headless --path . --script res://addons/gut/gut_cmdln.gd -- -gconfig= -gexit -gtest=res://test/unit/test_catabase_meshy_art.gd
godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/expedition/CatabaseMeshyUIProbe.tscn -- resolution=1280x720
godot --path . --rendering-method gl_compatibility --resolution 1920x1080 res://tests/expedition/CatabaseMeshyUIProbe.tscn -- resolution=1920x1080
godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/expedition/CatabaseMeshyUIProbe.tscn -- resolution=1280x720 outcomes_only=true
```

Ce probe capture le combat après la disparition naturelle de sa bannière, la
pause, les récompenses, la carte, l'équipement, l'inventaire rempli, les cinq
doctrines, Tempête et le kit de six sorts. Il utilise les vrais boutons de pause,
sélection d'objet et fermeture, ainsi que les API de production d'équipement et
de build. Des événements souris passent par le moteur pour survoler et cliquer
l'option de réduction des animations puis Équiper. Le pied d'actions doit rester
visible et fixe lorsque la description de l'objet défile, et le retour visuel ne
doit pas déplacer les cibles. Les quatre puis six emplacements de sorts ne doivent
chevaucher ni Déplacer, ni Fin de tour, ni les boutons de navigation, ni un autre
sort. Les douze objets et les découvertes sont des fixtures explicites ; les
victoires intermédiaires sont simulées. Les deux récompenses exclusives de XII
sont examinées séparément en restaurant le même snapshot antérieur au choix.

Les images et `report.json` sont écrits dans `artifacts/meshy_ui/<résolution>/`.
Les sauvegardes du probe sont isolées dans ce répertoire. Le probe peint existant
reste nécessaire pour vérifier les cibles et transactions des haltes Higgsfield.
Le mode `outcomes_only=true` capture la vraie scène de résultat avec deux fixtures
victoire/défaite et vérifie la restauration du thème d'une autre aventure ; il ne
prétend pas jouer le boss final. Son rapport est `outcomes_report.json`.

## Carte en vue d'ensemble

Le bouton **Déplier toute la carte** ouvre les vingt seuils avec une légende
illustrée. Cliquer inspecte ; **Replier la carte** ou **Échap** retrouve la fiche
et le défilement précédent. Le départ reste une confirmation séparée.
Les nouvelles runs utilisent des jonctions entre voies (catalogue v3) ;
une sauvegarde v2 conserve sa topologie d'origine.

La régression GUT est `res://test/unit/test_expedition_route_overview.gd`.
Le probe `res://tests/expedition/RouteMapProbe.tscn` utilise de vrais événements
souris et clavier, sans sauvegarde joueur, et produit des images et un
`report.json` dans `artifacts/route_map/<résolution>/` :

```text
godot --path . --rendering-method gl_compatibility --resolution 1280x720 res://tests/expedition/RouteMapProbe.tscn -- resolution=1280x720
godot --path . --rendering-method gl_compatibility --resolution 1920x1080 res://tests/expedition/RouteMapProbe.tscn -- resolution=1920x1080
```
