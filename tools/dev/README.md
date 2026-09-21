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
./dev.ps1 test cards
./dev.ps1 test catabase
./dev.ps1 test audio
./dev.ps1 test halts
./dev.ps1 test monsters
./dev.ps1 test content
./dev.ps1 test navigation
./dev.ps1 test selection
./dev.ps1 test retirement
./dev.ps1 test test/unit/test_champion_codex.gd
./dev.ps1 capture inventory -Resolution 1920x1080
./dev.ps1 selftest
```

Chaque exécution possède ses logs, son contexte Git et son `summary.json` dans
un dossier neuf `artifacts/dev/`. Les tests utilisent l'analyseur strict existant,
avec un import en recovery mode et un répertoire de données utilisateur isolé.
Les erreurs moteur et rapports absents restent des échecs. La suite locale `all`
signale tous ses échecs ; la CI conserve sa propre allowlist historique.
Le délai GUT par défaut est de 900 secondes. Pour une suite longue, utiliser
par exemple `./dev.ps1 test studio -TimeoutSeconds 1800` ; la durée choisie est
consignée dans `gut.command.json`. Un dépassement reste un échec strict.

Les sélections sont dans `test-suites.json`. `smoke` garde son périmètre historique
de deux suites de codex UI, sans valider un parcours de jeu. `cards` couvre les
contrats Cartes, classes, icônes, VFX et HUD ; elle est incluse dans `catabase`.
`studio` exécute la liste exacte des contrats Studio utilisée aussi par la CI.
`cards-audit` sépare les campagnes statistiques et de transactions historiques
(180 000 tirages, milliers de transactions/tours). Les exécuter quand ces règles
changent ; elles restent incluses dans `all` et dans la suite globale de la CI.
Voir [la matrice de validation](../../docs/current/validation.md) pour les scénarios
runtime et contrôles visuels à compléter.

`content` couvre la sélection, le refuge, l'isolation des profils et le contrat
de titre Studio. `navigation` couvre les haltes et le carrefour via le vrai
GameManager. Ces sélections supplémentaires ne retirent aucun test de `all`.
`selection` étend les contrôles aux portraits, au focus, au laboratoire
philosophe et à la confirmation de remplacement des sauvegardes.
`retirement` vérifie le refuge 2D et les contrats génériques conservés lors du
retrait du trio : animation, aperçu, mouvement, progression et cycle de vie.
L'[audit de contenu](../content_audit/README.md) permet de préparer un retrait
avec un rapport de dépendances détaillé et une sortie terminal compacte.

Un verrou sérialise les commandes moteur lancées via `dev.ps1`. Il ne contrôle
pas les lancements manuels : coordonner ceux-ci avec les générations d'assets.
Les captures `inventory` et `hud` utilisent la galerie HUD réelle existante ;
elles ne prouvent pas un parcours de jeu complet. Inspecter aussi les images.

## Recherche et contenu

```powershell
./dev.ps1 context philosopher
./dev.ps1 context catabase -Kind code
./dev.ps1 context cartes -Kind tests
./dev.ps1 context terrain -Page 2 -PageSize 20
./dev.ps1 context philosopher -Kind docs -IncludeArchive
./dev.ps1 inspect res://data/spells/enemies/catabase_givre.tres
./dev.ps1 references res://data/spells/enemies/catabase_givre.tres
```

`context` donne par défaut 30 chemins et indique le total, la page et `has_more`.
Les points d'entrée de `context-domains.json` passent avant les autres résultats,
puis viennent code, tests, données, documentation et art. Domaines/alias :
`catabase`/`expedition`/`run`, `cards`/`cartes`/`deck`, `combat`/`battle`,
`studio`/`edition`, `terrain`/`maps`/`map`, `personnages`/`characters`/`heroes`.
Tout autre mot cherche dans les noms de chemins, sans charger les fichiers.
`-Kind all|code|tests|docs|data|art` filtre les catégories ; les scripts dans
`data/` ou `assets/` suivent la catégorie de leur répertoire.
Les notes `docs/ai/`, audits et archives sont exclus sauf `-IncludeArchive`.
Les sorties générées et addons tiers restent exclus. Les fichiers supprimés
du worktree ne sont pas proposés. Les sources complètes restent accessibles.
Le `.rgignore` de la racine retire aussi les sorties générées, l'archive du
README et les audits datés des recherches `rg` ordinaires.
Pour les consulter : `rg --no-ignore motif docs/audits`.
Cela ne change ni leur suivi Git ni l'import Godot.
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
SHA256. Les addons tiers sont exclus ; le Studio du projet reste éligible.
Aucun formatage global automatique n'est
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
