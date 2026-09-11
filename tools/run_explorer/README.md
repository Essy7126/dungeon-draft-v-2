# Explorateur de run

Outil local d'audit et d'essai de Catabase. Il lit les catalogues courants à chaque
actualisation : les changements de maps, rencontres et haltes ne nécessitent pas
de refaire un export HTML.

## Ouvrir

- Godot : **Projet → Outils → Dungeon Draft : explorateur de run (F6)**, puis F6.
- Ou ouvrir `tools/run_explorer/RunExplorer.tscn`, puis F6.
- Ou `./tools/run_explorer/explorer.ps1` ; `-GodotPath` accepte le moteur 4.7.1.

Après ajout du menu, recharger le plugin Studio ou redémarrer l'éditeur lorsque
les documents en cours sont enregistrés. La scène et le lanceur fonctionnent
immédiatement, sans recharger le plugin.

## Examiner un parcours

Choisir une graine puis **Actualiser**. La carte affiche toutes les destinations,
y compris les secrets et la nature réelle des inconnues. Cliquer une destination
ou la choisir dans la liste. **Entrée des Enfers** ouvre la fiche du Seuil, hors
des vingt étapes.

La fiche relie destination, décor, ressource de salle, intention tactique et
composition de rencontre. Elle montre la peinture source lorsqu'elle existe ;
sinon, les dalles du manifeste. Ce plan ne simule pas les textures, obstacles ou
effets du rendu de jeu. Les haltes génériques sont explicitement identifiées.

- **Jouer cette destination** : vraie rencontre ou halte, avec les services de
  production. Un chemin valide est préparé depuis le départ : victoires précédentes
  simulées, butin conservé en oboles, attributs en vitalité et sixième emplacement
  choisi. Les quatre techniques initiales sont conservées. Cette préparation ne
  représente pas un build équilibré ni une sauvegarde personnelle.
- **Examiner la DA** : vraie scène d'arène, sans personnages, HUD ou combat ;
  options de test direct du Studio et caméra de production.
- **Ouvrir la peinture** : image originale dans l'application associée.
- **Après le combat** (Seuil uniquement) : victoire simulée dans une session isolée,
  puis exploration libre et choix des trois sorties. Accès direct :
  `./tools/run_explorer/explorer.ps1 -AfterCombat`.
- Dans l'essai : **F8** ferme cette fenêtre, **F9** capture sans la barre du laboratoire.

L'explorateur reste ouvert pendant les essais. Chaque essai lance un processus
Godot distinct avec données utilisateur et sauvegardes propres sous
`artifacts/dev/run-explorer-*`. Le lanceur d'essai refuse de fonctionner si son
dossier utilisateur n'est pas isolé. Il n'enregistre aucune ressource de contenu.

## Vérifications

Test de catalogue : `./dev.ps1 test test/unit/test_run_explorer_catalog.gd`.
Validation graphique et lancements : `./tools/run_explorer/verify.ps1`.
Utiliser `-BrowserOnly` pour le navigateur et son lancement de processus, ou
`-PreviewsOnly` pour les huit destinations représentatives.
Le scénario `VerifyRunExplorer.tscn` teste les clics et le cadrage en 720p/1080p,
puis la préparation/restauration de destinations représentatives. Il exige
`--output=res://artifacts/dev/<dossier>`.

Le paramètre `--explorer-capture` du lanceur d'essai attend la scène, capture puis
ferme ; il reste réservé aux contrôles. Une capture de lancement ne démontre pas
une victoire ni une campagne entière.
