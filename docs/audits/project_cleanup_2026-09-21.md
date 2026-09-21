# Organisation et nettoyage — 21 septembre 2026

Référence de départ : `fadd1449f51d90ec76714ff14d1e3113d100ee5e`.
Ce compte rendu décrit la mise en œuvre de l’audit d’organisation ; il ne remplace
pas les références courantes dans `docs/current/`.

## Changements

- README réduit de 222 à 52 lignes ; ancienne présentation conservée avec liens
  corrigés dans `docs/archive/project_overview_2026-09-21.md`.
- Références courantes produit, architecture, validation et statut du contenu.
- `dev.ps1 context` : domaines/alias, points d’entrée prioritaires, type de fichier,
  pagination, accès explicite aux archives et exclusion des chemins supprimés.
- `.rgignore` : sorties générées et anciens manifestes exclus des recherches
  ordinaires ; accès explicite possible, aucun effet sur Git ou Godot.
- `test-suites.json` partagé par le lanceur et la CI pour les 36 contrats Studio,
  conservés exactement. Nouvelle suite `cards`, également incluse dans `catabase`.
- Les simulations historiques longues sont identifiées par `cards-audit` ; elles
  restent dans `all` et la CI globale, séparées des contrats Cartes courants.
- Le formateur accepte le Studio du projet et exclut toujours les addons tiers.
- Aucun changement aux règles de jeu, aux sauvegardes ou aux contrôleurs runtime.

## Suppressions vérifiées

26 fichiers, 115 363 986 octets dans le checkout (environ 115,4 Mo décimaux).
La taille de l’historique Git n’est pas réduite par ces suppressions.

| Ensemble supprimé | Fichiers | Justification |
|---|---:|---|
| `imported_models/Lanternbound Archivist_1/` | 10 | Binaires identiques à l’original conservé, aucune référence de chemin/UID identifiée vers cette copie |
| Les cinq dossiers `asset/map/painted/nouveau_terrain*` | 10 | Même image que `asset/Background/montagne plateau.png`, conservée ; copies non référencées |
| `gobtest.tscn` | 1 | Vestige avec deux dépendances déjà absentes |
| `test_phase_1.tscn` | 1 | Prototype de phase 1 sans référence identifiée ; tests grille/pathfinding conservés |
| `main.gd` et son UID | 2 | Ancien point d’entrée ; le projet utilise `ui/TitreEcran.tscn` |
| `debug.log`, `artifacts/intro_headless.log` | 2 | Journaux historiques ; le log de racine est désormais ignoré |

Avant suppression : contrôle des chemins et UID dans les sources textuelles
suivies, comparaison SHA-256 des binaires dupliqués, vérification des empreintes
immédiatement avant retrait. Les chemins résolus ont été bornés au workspace.
Les références construites dynamiquement ne sont pas entièrement couvertes par
cette analyse : les contrôles moteur restent nécessaires.

Le manifeste détaillé est local et ignoré :
`artifacts/project_audit/2026-09-21/cleanup_manifest.json`.

## Contenu volontairement préservé

Paris reste référencé comme ennemi de Catabase. Le trio Elfe/Mage/Guerrier,
le mage philosophe, le spectre et les anciennes maps restent des dépendances
de laboratoires, tests ou profils historiques. Le modèle d’Archiviste utilisé
par le refuge est conservé. Les anciennes révisions Cartes restent nécessaires
à la restauration de sauvegardes.

Un retrait complet des aventures historiques demanderait de remplacer leurs
fixtures et de définir explicitement la compatibilité conservée. Ce nettoyage
ne réduit pas la couverture des tests pour justifier une suppression.

## Vérifications

- `./dev.ps1 selftest` : 64 contrôles du harnais et 17 cas synthétiques de
  l’analyseur réussis. Rapport final de l’outillage :
  `artifacts/dev/20260921-102541-selftest--24041251/summary.json`.
- `./tools/halt_workshop/halt.ps1 test -PythonPath <Python fourni par Codex>` :
  29 tests réussis ; rapport `artifacts/dev/20260921-100816-halt-test-9799a0e2/`.
- `./dev.ps1 format tools/dev/inspect_resource.gd` : contrôle réussi, sans écriture.
- Recherche `context` sur Catabase, personnages et documents historiques :
  entrées prioritaires, filtres et accès aux archives vérifiés.
- Liens relatifs des documents ajoutés/modifiés : présents ; parité avec les
  36 chemins Studio de la CI avant modification : exacte.
- Portabilité des chemins sur les dossiers contrôlés par la CI : aucun chemin
  de poste détecté ; versions Studio et JSON de l’allowlist vérifiés.
- `.rgignore` : exclusions constatées avec `rg --files`, archive accessible
  avec `rg --no-ignore --files docs/archive`.
- `git diff --check` : réussi.

### Moteur, CI et scénarios

- `./dev.ps1 test all` : import recovery réussi, puis timeout GUT après 900 s,
  avec erreurs de script et de rendu ; pas de JUnit ni de bilan complet. Le zéro
  des compteurs du rapport strict n’est pas un décompte des tests réellement
  démarrés. Aucune réussite globale n’est revendiquée.
- Le vérificateur `tools/verify_gut_historical_allowlist.py`, appliqué au log et
  au statut de timeout, refuse cette exécution incomplète. L’allowlist reste
  inchangée ; la CI distante n’a pas été lancée.
- Deux rapports suivis sous `artifacts/arena_studio/arena_studio_test/` ont été
  modifiés par la suite globale (uniquement `generated_at`). Le contrôle de
  non-mutation n’est donc pas satisfait par cette exécution. Ces deux modifications
  produites par nos tests ont été restaurées après comparaison du contenu JSON,
  et la preuve copiée sous `artifacts/project_audit/2026-09-21/gut_generated_changes/`.
- Import normal : processus terminé avec code 0, mais erreurs de ressources/RID
  non libérés ; contrôle strict en échec. Le diagnostic ne masque pas ces erreurs.
- Smoke Rencontres : réussi, sans erreur moteur détectée.
- Smoke Objets : échec sur l’attente historique du nombre d’onglets, plus fuites
  à la fermeture. Le runner exige quatre onglets, le Studio en crée cinq.
- Terrain headless : échec, aucun viewport exploitable. Réexécution avec rendu
  OpenGL hors écran : cinq vues 1280 × 720 produites, marqueur `failures=0` et
  code de sortie 0 ; contrôle strict toujours en échec à cause des fuites de
  ressources à la fermeture. La capture `terrain_studio_edit_1280x720.png` a été
  inspectée : décor et grille présents. Cela ne certifie pas toute l’interface.
- Contrats de contenu avec rendu : 54 tests, un échec
  (`test_donnees_archiviste_preparent_le_trio_reel_dans_game_manager`) et erreurs
  de fermeture. Les suites pathfinding (3), sélection (16) et isolation (14)
  n’ont pas d’échec d’assertion ; le refuge a 20 tests réussis sur 21.
- Une première sélection Cartes incluant l’audit historique long a été arrêtée
  pendant les simulations. Elle reste explicitement incomplète et en échec,
  jamais comptée comme réussite. Les simulations restent sélectionnables par
  `cards-audit` et conservées dans `all`/CI ; la sélection courante a été relancée.
- Sélection Cartes courante : 77 tests, 76 réussis, 6 886 assertions réussies.
  Un test échoue sur l'unicité des illustrations (`test_class_painted_icons.gd::
  test_every_live_card_and_crest_has_distinct_painted_art`, notamment `s_a_hit`).
  Les cartes historiques (24 tests), classes (25), VFX (20) et HUD (6) n'ont
  pas d'échec de test. Les catalogues et images concernés n'ont pas été modifiés
  par le nettoyage. Le verdict de la suite reste FAIL, sans nouvel assouplissement.

Rapports moteur locaux (arguments exacts dans les fichiers `*.command.json`) :

- `artifacts/dev/20260921-100217-test-all-dbf3892d/`.
- `artifacts/project_audit/2026-09-21/global_allowlist_check.log`.
- `artifacts/dev/20260921-101815-cleanup-runtime-gates-0f1332bb/`.
- `artifacts/dev/20260921-102541-cleanup-content-rendered-d293d945/`.
- `artifacts/dev/20260921-102044-cleanup-cards-c5ff0977/` (interrompu).
- `artifacts/dev/20260921-102738-cleanup-cards-current-94b688a9/` (77 tests).
- `artifacts/terrain_studio/screenshots/` (cinq captures 1280 × 720).

## Dette de validation observée

L’ancien `test_encounter_g6_closure.gd` appelle
`DungeonDraftStudioMain.uses_compact_title()`, méthode déjà absente du code à
HEAD avant ce nettoyage. La suite globale comporte aussi des tests de rendu
3D qui échouent en headless et des attentes historiques sur la présentation
d’Achille. Les échecs n’ont pas été supprimés ou ajoutés à l’allowlist.

Avant une refactorisation profonde des orchestrateurs, remettre ces contrats
en cohérence avec le produit actuel et distinguer tests de règles et tests de
rendu, tout en conservant les gates requises. Un simple rangement de dossiers
ne peut pas rendre ces contrôles fiables.

## État livré

Les modifications restent non commitées pour revue. Les nouveaux fichiers sont
`.rgignore`, les deux manifestes sous `tools/dev/`, les références `docs/current/`,
l'archive du README et les comptes rendus d'audit/nettoyage. Les rapports de tests,
captures et preuves de suppression restent ignorés sous `artifacts/`.
Le rapport d'audit non suivi présent au début de cette intervention a été conservé.
La comparaison finale de l'état Git n'a révélé aucun changement supplémentaire
produit par les tests après restauration des deux dates de rapports.

La refactorisation des gros orchestrateurs et le retrait complet des aventures
historiques restent distincts de ce lot : le moteur conserve ses contrats actuels.
La validation globale n'est pas acquise et les défauts ci-dessus restent à traiter.
