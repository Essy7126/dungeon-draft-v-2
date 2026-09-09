# Validation du socle de développement — 9 septembre 2026

## Installation réalisée

- `dev.ps1` : diagnostic, suites ciblées, captures, inspection et références du Studio, recherche de chemins, formatage, installation et configuration Workbench.
- `AGENTS.md` : carte et commandes courtes ; guide détaillé dans `tools/dev/README.md`.
- Godot 4.7.1 et GUT 9.7.1 : références locales ; CI principale alignée sur Godot 4.7.1.
- Formateur GDQuest 0.25.0 installé dans le cache ignoré, archive vérifiée par SHA256.
- Serveur Workbench compilé à la révision `6a8f91518624dfe3cb1356ffb269a4ac65a8ddde` avec Go 1.27.1 ; 22 paquets de tests Go réussis.
- Addon Workbench activé, autoload runtime explicite et reconnexion configurée. Son traitement par frame est désactivé hors débogage.
- `.codex/config.toml` local configuré pour 20 outils vérifiés parmi les 97 du mode `lite`. La connexion sera disponible après rechargement du client MCP ; l'éditeur déjà ouvert doit aussi recharger le projet pour activer le plugin.
- Nouveau workflow `dev-tooling.yml` : contrats du harnais, alignement de version et vérification du formatage des scripts du harnais.

## Commandes exécutées et résultats

| Commande | Résultat observé |
| --- | --- |
| `./tools/dev/install.ps1 -Component all`, puis `-Component workbench` | Formateur installé ; compilation Workbench réussie après normalisation des chemins temporaires des tests Windows. |
| `./dev.ps1 doctor` | Godot 4.7.1 et GUT 9.7.1 reconnus. Ce diagnostic ne vaut pas un import. |
| `./dev.ps1 selftest` | 11 contrôles du harnais et 17 cas synthétiques de l'analyseur strict réussis. |
| `./dev.ps1 test smoke` | Import et 16 tests / 215 assertions réussis ; aucune erreur moteur dans les rapports finaux. |
| `./dev.ps1 references res://data/spells/catabase_monsters/lethe_trait.tres` | Inspection réussie, 72 propriétés ; graphe Studio de 4 949 nœuds et 5 509 liens. Aucune utilisation trouvée pour cette ressource dans les racines parcourues ; ce n'est pas une preuve d'absence d'utilisation ailleurs. |
| `./dev.ps1 capture inventory -Resolution 1280x720` | Une capture créée et inspectée visuellement. |
| `./dev.ps1 capture hud -Resolution 1280x720` | 11 états réussis, aucune image manquante et galerie créée. |
| `./dev.ps1 capture inventory -Resolution 1920x1080` | Une capture créée, aucun contrôle de capture en échec. |
| `node tools/dev/workbench_smoke.mjs <Godot console 4.7.1>` | 8 contrôles réussis : MCP, connexion éditeur, inspection, valeur runtime exacte, capture 640×360, erreur de nœud absent, arrêt du jeu et déconnexion. |
| `./dev.ps1 format tools/dev/inspect_resource.gd -Write`, puis sans `-Write` | Formatage appliqué uniquement au nouveau script, puis vérification réussie. |
| `./dev.ps1 configure workbench` | Réexécution sans modification de la configuration existante, empreinte contrôlée. |
| Analyse syntaxique PowerShell, `node --check tools/dev/workbench_smoke.mjs`, `git diff --check` ciblé | Réussis. |

Les rapports finaux sont conservés dans les dossiers uniques `artifacts/dev/`,
notamment `20260909-124821-test-smoke-0f8ca98e`,
`20260909-124927-capture-hud-8b44624d`,
`20260909-124950-capture-inventory-b51d868e` et
`workbench-5800acf9-e8a9-4c55-a4fb-0702773e0e97`.
Les essais ayant échoué restent également enregistrés ; ils ne sont pas présentés comme valides.

## Limites et portée

Les validations Godot ont nécessité l'accès Windows normal au magasin de certificats ;
le premier essai dans le bac à sable a correctement échoué. Les processus créés pour
les tests ont été fermés ; l'éditeur et le jeu déjà ouverts ont été préservés.

La suite GUT globale et les workflows distants GitHub n'ont pas été exécutés ici.
Les captures vérifient la galerie HUD existante, pas une run complète. Le test
Workbench utilise un projet isolé et ne certifie pas toutes ses commandes.

Les plugins de dialogue et d'IA ennemie restent des options de contenu, sans migration
du gameplay. Le modèle et l'effort de raisonnement n'ont pas été changés. Aucun
pourcentage d'économie de tokens n'est revendiqué avant comparaison de tâches réelles.
Les modifications de gameplay déjà en cours ont été préservées. Les nouvelles sources
de ce socle et cette note restent non suivies tant qu'elles ne sont pas ajoutées à Git ;
les exécutables, caches, images et logs restent ignorés.
