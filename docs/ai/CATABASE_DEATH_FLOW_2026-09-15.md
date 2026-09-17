# Mort Catabase — correction de parcours et écran

Statut : WORKTREE_CANDIDATE, 2026-09-15.
Dépôt `Essy7126/dungeon-draft-v-2`, branche `main`, base vérifiée
`40ea393dcd539c63f2aa7f024271524f65ade399`. Worktree propre au départ.

## Demande et périmètre

Corriger le retour vers l'Archiviste et le trio après une défaite Catabase.
Habiller ensuite la mort ; ne pas ajouter de résurrection, bonus, méta-progression
ou pénalité. Le brainstorming mécanique reste une étape ultérieure.
Aucun commit, push, changement de branche ou suppression de contenu autorisé.

## Diagnostic observé

`ui/run_result_screen.gd` envoyait explicitement Catabase vers
`GameManager.return_to_hub()`. Le refuge historique possède encore la run trio.
Le résultat d'expédition utilisait aussi les compteurs de salles génériques,
sans distinguer profondeur, combats gagnés et identité de Passe-rive.

## Correction candidate

- Nouvelle tentative : sélection publique de Catabase, sans ancien héros/build.
- Menu principal : retour au titre, sans reprise de la tentative morte.
- Un ancien callback vers le refuge après un résultat Catabase est redirigé.
- Une suppression de reprise échouée reste bloquante ; un retour au menu ne
  peut pas la transformer en enregistrement d'une run morte.
- Bilan factuel depuis la route : profondeur, combats gagnés, niveau, difficulté
  et apparence. Aucun ennemi responsable ou score n'est inventé.
- Dernier plateau capturé après la mort, avec fallback visuel si indisponible.

## Vérification

- Interface/chronique : **9 tests, 78 assertions, PASS** ; rendu de données
  d'expédition et de Passe-rive, victoire, compatibilité historique, verrouillage
  des deux actions, reprise après refus et animations réduites.
  Rapport : `artifacts/dev/20260915-125849-test-test_unit_test_catabase_run_chronicle.gd-9601127b/gut-strict-report.json`.
- Cycle de mort : **6 tests, 67 assertions, PASS** sur le correctif final ;
  suppression de reprise, état neuf, absence du trio, identité Passe-rive,
  aucun gain à la mort et blocage titre/hub/abandon en cas d'échec terminal.
  Rapport : `artifacts/dev/20260915-131836-test-test_unit_test_catabase_death_flow.gd-1ae9c583/gut-strict-report.json`.
- Fiabilité du cycle d'expédition : **15 tests, 201 assertions, PASS** ;
  remplacement confirmé, sauvegardes et sorties en échec, abandon, transaction
  unique, halte et suppression terminale. Total ciblé : **30 tests / 346 assertions**.
  Rapport : `artifacts/dev/20260915-132113-test-test_unit_test_reliability_expedition_lifecycle.gd-d140e53e/gut-strict-report.json`.
- Le premier essai de la suite de fiabilité n'a exécuté aucun test : un import
  a rencontré le script UI pendant sa réécriture. Le suivant a été interrompu
  sans rapport final. Aucun de ces essais n'est compté comme une réussite.
- Parcours GPU : **173 contrôles / 173, 2 cas, 4 captures, PASS**, aucune
  erreur moteur. Déploiement réel et dégâts létaux contrôlés dans la Battle de
  profondeur I, sans appeler directement la finalisation du GameManager :
  Achille 720p → résultat → nouvelle tentative → sélection publique Passe-rive
  → configuration Catabase et introduction ; Passe-rive 1080p → résultat →
  menu principal sans reprise. Le dernier plateau capturé est celui du combat.
  Rapport : `artifacts/catabase_death_validation/death_flow_gpu_deployment_20260915_1323/report.json`
  et verdict strict `summary.json` dans le même dossier.
- Captures 720p et 1080p inspectées : titre, lieu, bilan, identité et actions
  entièrement visibles. Panneau 720p : `(120,18,1040,684)` ; panneau 1080p :
  `(440,160,1040,760)`. Le rendu testé utilise Windows/Intel Graphics en
  `gl_compatibility` avec animations réduites et données utilisateur isolées.
  Le mode D3D12 et une revue humaine en jeu ne sont pas certifiés par ce probe.
- Le premier probe GPU cherchait le héros avant le déploiement : 2 scènes de
  combat ouvertes, mais 0 capture et verdict FAIL. Sa fixture a été corrigée
  pour passer par le placement réel ; ce premier passage n'est pas une preuve
  de bon fonctionnement ni un bug de production.

## Reproduire et fichiers concernés

```powershell
./dev.ps1 test test/unit/test_catabase_death_flow.gd
./dev.ps1 test test/unit/test_catabase_run_chronicle.gd
./dev.ps1 test test/unit/test_reliability_expedition_lifecycle.gd
./tools/catabase_death_validation/validate.ps1
```

Exécuter les commandes moteur en série. Le probe crée un dossier neuf et une
sauvegarde de validation isolée ; il ne touche pas à la progression du joueur.

- Production : `battle/battle.gd`, `core/game_manager.gd`,
  `core/run_result_narrative_service.gd`, `ui/run_result_screen.gd`,
  `ui/RunResultScreen.tscn`.
- Régression : `test/unit/test_catabase_death_flow.gd`,
  `test/unit/test_catabase_run_chronicle.gd` ; harnais
  `tools/catabase_death_validation/`.
- Documentation : ce rapport, `CURRENT_STATE.md`, `DECISIONS.md`,
  `KNOWN_ISSUES.md`. `BALANCE_BASELINE.md` inchangé : aucune valeur de balance.

HEAD final inchangé : `40ea393dcd539c63f2aa7f024271524f65ade399` ; `git diff --check`
propre. Aucune opération commit/push/branche/reset/stash effectuée.

## Limites et non-objectifs

Les tests de cycle simulent certaines victoires et injectent une défaite ; ils
ne constituent ni une partie humaine ni une mesure de difficulté. La fixture
de victoire vérifie sa destination, pas l'accomplissement d'une run entière.
L'audit statique confirme que la victoire réelle complète le dernier nœud
avant le bilan. L'ancien refuge et ses contenus de laboratoire restent présents
mais ne sont plus la destination du résultat Catabase. Aucun contrat de mort
nouveau n'est inventé et aucune valeur de production n'a été rééquilibrée.
La sélection publique conserve un ancien libellé « Incarner Achille » lorsque
Passe-rive est sélectionné : incohérence de texte observée hors écran de mort,
sans retour au trio (le probe vérifie la configuration Passe-rive/Catabase).
