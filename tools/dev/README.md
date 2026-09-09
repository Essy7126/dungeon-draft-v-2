# Commandes de développement

Depuis la racine du dépôt, utiliser PowerShell 7.2 ou supérieur. `./dev.ps1 help`
affiche les commandes. Le même lanceur est utilisable par une personne et par un agent.

## Préparation

```powershell
./dev.ps1 install formatter
./dev.ps1 doctor -GodotPath 'C:/chemin/Godot_v4.7.1-stable_win64_console.exe'
```

Le chemin explicite est mémorisé dans `artifacts/dev-tools/local.json`, ignoré par Git.
Les variables `GODOT4_BIN` et `GODOT_BIN` sont aussi reconnues. Les versions sont
fixées dans `toolchain.json`. Le diagnostic ne remplace pas un import ou un test.

## Validation

```powershell
./dev.ps1 test smoke
./dev.ps1 test monsters
./dev.ps1 test test/unit/test_champion_codex.gd
./dev.ps1 capture inventory -Resolution 1920x1080
./dev.ps1 selftest
```

Chaque exécution possède ses logs, son contexte Git et son `summary.json` dans
un dossier neuf `artifacts/dev/`. Les tests utilisent l'analyseur strict existant,
avec un import en recovery mode et un répertoire de données utilisateur isolé.
Les erreurs moteur et rapports absents restent des échecs. La suite locale `all`
signale tous ses échecs ; la CI conserve sa propre allowlist historique.

Un verrou sérialise les commandes moteur lancées via `dev.ps1`. Il ne contrôle
pas les lancements manuels : coordonner ceux-ci avec les générations d'assets.
Les captures `inventory` et `hud` utilisent la galerie HUD réelle existante ;
elles ne prouvent pas un parcours de jeu complet. Inspecter aussi les images.

## Recherche et contenu

```powershell
./dev.ps1 context philosopher
./dev.ps1 inspect res://data/spells/enemies/catabase_givre.tres
./dev.ps1 references res://data/spells/enemies/catabase_givre.tres
```

`context` donne jusqu'à 30 chemins et indique les résultats supplémentaires.
L'inspection décrit les valeurs scalaires et références ; les collections sont
résumées par leur taille. Les sources restent accessibles. `references` utilise
le graphe existant de Dungeon Draft Studio : sa couverture est celle des racines
de production découvertes, pas celle de tous les fichiers du dépôt.

## Formatage

```powershell
./dev.ps1 format                          # vérifie les scripts modifiés
./dev.ps1 format tools/dev/inspect_resource.gd -Write
```

Le formateur GDQuest est fixé en version 0.25.0 et son archive est vérifiée par
SHA256. Les addons tiers sont exclus. Aucun formatage global automatique n'est
effectué. `--verify-structure` ajoute un contrôle mais ne remplace pas la revue
du diff et les tests Godot. La CI commence par les scripts de ce harnais.

## Atelier de sprites

`./tools/sprite_workshop/workshop.ps1 open|seed|new|import|check|export|capture`
partage les services du Studio et ce harnais. Les documents sont versionnés,
les exports et captures restent dans `artifacts/sprite_workshop/`.
Voir [le guide de production](../sprite_workshop/README.md) pour la syntaxe,
la revue des poses et les limites de validation artistique et en combat.

## Workbench

`./dev.ps1 install workbench` compile la révision fixée dans `toolchain.json`,
exécute ses tests Go et vérifie que le protocole correspond à l'addon local.
L'exécutable, les dépendances et les journaux restent dans `artifacts/dev-tools/`.
La configuration locale `.codex/config.toml` expose 20 outils du mode `lite`.
Elle est ignorée par Git car les chemins de l'exécutable sont propres au poste.
Sur un autre poste, `./dev.ps1 configure workbench` crée cette connexion sans
écraser une configuration existante. La sélection est dans `workbench-tools.json`.
Après installation ou
changement de configuration, recharger la connexion MCP et l'éditeur si nécessaire.

L'addon est activé et sa sonde runtime est déclarée avant le premier lancement.
Les options `godot_ai_workbench/auto_connect`, `profile` et `port` de `project.godot`
pilotent la connexion locale. La sonde ne traite pas de frames hors débogage.
Le test isolé peut être relancé avec Node :

```powershell
node tools/dev/workbench_smoke.mjs 'C:/chemin/Godot_v4.7.1-stable_win64_console.exe'
```

Ne pas confondre les tests de la passerelle avec la validation du gameplay.
L'import recovery désactive les plugins pendant la préparation des tests.

## Reprise d'une tâche longue

Conserver une note courte, propre à la tâche, contenant : objectif, décisions,
fichiers concernés, commandes réellement exécutées, résultats et prochain travail.
Relire l'état Git avant réutilisation. Les rapports restent datés et ne deviennent
jamais automatiquement des preuves valables après une modification de leurs entrées.
