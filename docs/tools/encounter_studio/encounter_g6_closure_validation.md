# Clôture de G6 — Studio de rencontres

29 août 2026 — `WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`

Ce rapport concentre les preuves de la passe de clôture. Il complète et
remplace les résultats provisoires incompatibles des rapports G3/G4 et G6.

## 1. Verdict

**PROUVÉ** — Les défauts automatisables de la demande sont corrigés : titre
complet à 1280×720, panneau Validation exploitable, carte de diagnostic et
actions visibles, légende complète, focus visible, véritable échelle 125 %,
événements clavier réels, import global sûr et parcours E2E unique.

**À CONFIRMER** — G6 n'est pas déclaré totalement clôturé humainement : le
rendu de l'icône `EditorIcons/Folder` avec le thème complet de l'éditeur et le
confort avec un lecteur d'écran réel nécessitent une vérification manuelle.
Le repli sans icône, les textes, infobulles, ordres de focus et activations
clavier sont, eux, couverts automatiquement.

## 2. Protection des données et copie jetable

**PROUVÉ** — Avant le premier lancement Godot, les 383 fichiers de `data/`
ont été inventoriés par taille et SHA-256 puis copiés sous
`artifacts/encounter_g6_closure/data_backup_before/` : 383 originaux,
383 copies, 0 divergence. L'état Git préexistant a aussi été inventorié ; il
n'a pas été nettoyé, restauré, indexé ni commité.

**PROUVÉ** — L'import et le parcours d'intégration utilisent exclusivement la
copie vérifiée :

`C:/Users/jerem/.codex/visualizations/2026/08/29/01a04b47-c172-7871-a8a1-07a779d50da2/project_copy_20260829_043218`

Le manifeste de copie couvre 444 fichiers sensibles, 0 divergence, sans
répertoire `.godot` préexistant. Les profils Godot sont isolés sous le dossier
d'artefacts.

## 3. Corrections livrées

**PROUVÉ** — `dungeon_draft_studio_main.gd` conserve le nom de produit complet
tant que la largeur logique est suffisante (dont 1280×720) et ne compacte le
titre que sous 1120 px logiques ; l'infobulle garde toujours le nom complet.

**PROUVÉ** — `encounter_studio_main.gd` réserve 250 px à Validation, garde une
carte complète visible, masque à petite hauteur seulement la chronologie et
les commandes locales non essentielles, et conserve les actions globales de
document. Le bouton Ajouter possède un anneau de focus jaune de 2 px. Le
résultat du test direct est désormais conservé dans `last_test_result`.

**PROUVÉ** — `encounter_map_preview.gd` rend les six significations de légende
sur deux lignes, ou trois lignes sous 400 px, sans collision avec le bandeau
d'échec.

**PROUVÉ** — `encounter_workspace_g6.gd` applique une vraie surface logique
mise à l'échelle et injecte les pressions/relâchements `InputEventKey` pour
Tab, Maj+Tab, Entrée, Espace et Échap. Le runner de clôture indépendant et
quatre tests de régression ont été ajoutés.

**PROUVÉ** — L'import global a mis au jour quatre inférences invalides dans
`battle/battle.gd`. Des annotations explicites minimales (`RelicRuntimeService`,
`bool`, `Dictionary`) corrigent le parsing sans changer le comportement.

## 4. Preuves graphiques

**PROUVÉ** — Trois exécutions GPU `gl_compatibility`, chacune à 707 contrôles
passants, 0 échec et 19 captures :

| Fenêtre physique | Surface logique | Échelle | Résultat |
|---|---:|---:|---:|
| 1280×720 | 1280×720 | 100 % | 707/707, 19 captures |
| 1920×1080 | 1920×1080 | 100 % | 707/707, 19 captures |
| 1280×720 | 1024×576 | 125 % réel | 707/707, 19 captures |

**PROUVÉ** — Les 57 PNG ont été inspectés à leur taille originale. À 1280,
le titre est complet ; Validation montre une carte et le diagnostic montre
Voir/Corriger/Détails ; la légende reste entière ; le focus jaune est visible.
À 125 %, le titre compact est le repli prévu pour une largeur logique
insuffisante et l'infobulle conserve le titre complet. Les contrôles restent
dans la fenêtre hors zones volontairement défilables et dialogues.

Résultats bruts : `g6_closure_1280x720.json`,
`g6_closure_1920x1080.json`, `g6_closure_1280x720_125pct.json` et journaux
`g6_closure.log`, `g6_closure_1920.log`, `g6_closure_125pct.log`.

## 5. Parcours E2E réel et unique

**PROUVÉ** — `test_encounter_g6_closure_e2e.gd`, exécuté seulement dans la
copie jetable, passe **1/1 avec 40 assertions**. Un même workspace effectue :
ouverture du brouillon Terrain ; bouton global Rencontres ; création ; saisie
dans la recherche ; bouton Ajouter ; quantité 2 ; placement ; Voir sans
mutation ; Corriger ; Annuler/Rétablir ; sauvegarde/relecture ; bouton global
Tester et relecture du run temporaire ; bouton global Produire ; choix d'une
run jetable canonique ; prévol avec preuve runtime correspondante ; vrais
boutons OK ; transaction ; rechargement sans cache du terrain, de la vague et
du roster. La transaction est marquée `committed: true` puis
`finalized: true`. Le SHA-256 de `data/runs/first_run.tres` reste identique.

Preuves : `parcours_bout_en_bout.log` et
`resultat_parcours_bout_en_bout.json`.

## 6. Import global sûr

**PROUVÉ** — La première importation de la copie a correctement échoué sur
les inférences de `battle.gd`; la procédure s'est arrêtée, le défaut a été
corrigé, la copie resynchronisée et son seul cache `.godot` supprimé après
vérification du chemin. La seconde importation fraîche et le chargement de la
scène principale sortent à 0.

**PROUVÉ** — Dans `import_global_copie.log` et
`chargement_principal_copie.log` : 0 `Parse Error`, 0 `SCRIPT ERROR`,
0 script introuvable, 0 type/classe introuvable. Les messages restants sont
l'indisponibilité du magasin de certificats racine et les fuites de fermeture
RID/ObjectDB déjà historiques ; ils ne sont pas présentés comme corrigés.

## 7. Régression

**PROUVÉ** — Les journaux séparés antérieurs confirment S0 (62 assertions sur
les cinq scripts de sécurité), G5 (13/13), G6 (5/5) et les quatre nouvelles
régressions (4/4). La passe finale comparable regroupe les dix suites formant
les 124 tests existants et `test_encounter_g6_closure.gd`, soit **128/128**.
La preuve brute est `regression_finale.log` ; le parcours E2E 1/1 reste séparé
car il doit muter uniquement la copie jetable.

## 8. Limites et vérification manuelle courte

**À CONFIRMER — icône d'éditeur.** Ouvrir le plugin dans l'éditeur Godot avec
son thème complet, afficher Rencontres et vérifier que « Ouvrir une partie »
montre l'icône de dossier à gauche du texte. Vérifier ensuite que le texte
reste présent si l'icône est indisponible. Le code utilise `has_theme_icon`
avant `get_theme_icon`, donc l'absence d'icône est un repli sûr.

**À CONFIRMER — lecteur d'écran.** Avec le lecteur d'écran utilisé par
l'équipe, parcourir l'en-tête puis le catalogue par Tab/Maj+Tab et confirmer
que les libellés et infobulles entendus sont compréhensibles. Aucun lecteur
d'écran n'était disponible dans l'environnement automatisé ; aucune
compatibilité complète n'est revendiquée.

## 9. Index des preuves

- Données : `data_manifest_before.json`, `data_manifest_after.json`,
  `data_backup_manifest.json`, `data_backup_verification.json`.
- Sécurité de copie : `project_copy_path.txt`, `project_copy_manifest.json`.
- Tests : `s0.log`, `g5.log`, `g6.log`, `g6_closure_tests.log`,
  `regression_finale.log`, `parcours_bout_en_bout.log`.
- Import : `import_global_copie.log`, `chargement_principal_copie.log`.
- Graphique : les trois JSON de runner, leurs trois journaux et 57 PNG.

`WORKTREE_CANDIDATE — NOT_CURRENT — NOT_PRODUCTION`
