# Notes de validation — 6 septembre 2026

## Statut exact

Le runner est créé et deux parcours GPU historiques ont passé leurs assertions fonctionnelles. **La reprise finale à seed fixe, après correctif mémoire et après stabilisation des travaux parallèles, n'a pas été exécutée. La galerie canonique 44 états n'a pas été exécutée dans cette mission d'intégration.** Ne pas présenter les anciennes preuves comme une certification du worktree courant.

À 08:46:38 UTC, vérification locale read-only :

- `data/characters/paris/animations.tres` est désormais présent (il était absent dans le log précédent).
- `assets/characters/paris/sprites_v1/paris_portrait.tres` reste absent.
- Aucun processus Godot dont la ligne de commande cible `RunIntegrationQARunner.tscn` ou `HudGrayboxCaptureRunner.tscn` n'est actif.

Ces ressources appartiennent à un autre travail utilisateur en cours. Aucun fichier Paris n'a été modifié pour contourner le blocage. Preuve antérieure de chargement cassé : `artifacts/run_integration_20260906/test_logs/codex_gallery_mastery_lifecycle_final.log`, lignes 9/35 (ressources absentes), puis 308/633 (préchargement `odyssey.tres` impossible). Malgré son nom, ce log n'est pas une validation finale réussie.

## Deux parcours historiques réussis

| Preuve | 1200 × 896 | 1920 × 1080 |
|---|---|---|
| Dossier sous `artifacts/run_integration_20260906/` | `e2e_1200/corrected` | `e2e_1920` |
| Début → fin UTC | 08:33:07 → 08:34:09 | 08:35:30 → 08:36:41 |
| Assertions fonctionnelles | 317 réussies, 0 erreur | 314 réussies, 0 erreur |
| Vrais casts HUD résolus | 10, chacun un événement correspondant | 10, chacun un événement correspondant |
| Captures | 51 | 51 |
| Parcours | 5 salles → victoire → refuge, puis départ → perte → refuge | Identique |
| Seed effectif victoire / perte | 1642350974 / 2175619833 | 2081737592 / 2475866831 |

Chaque dossier contient `run_integration_report.json`, `native.log`, `stdout.log`, `stderr.log` et les PNG horodatés. Renderer observé dans les logs : **D3D12 12_0 / Forward+ / NVIDIA GeForce RTX 4070 Laptop GPU**. Aucun rendu OpenGL n'est revendiqué pour ces E2E.

Les quatre capacités canoniques ont été déclenchées depuis leurs boutons HUD puis les endpoints publics de grille ; le runner n'a pas appelé SpellCaster directement, remis les PA à zéro, soigné le héros ou téléporté une unité. Les parcours ont ensuite utilisé **cinq victoires QA forcées** pour accélérer les transitions après actions réelles, puis **une défaite QA forcée** après une garde réellement lancée. Ce ne sont pas des preuves de victoire organique ni d'équilibrage.

Le Dialecticien canonique de salle IV (`philosopher_mage.tres`, pas le Mage allié du trio) a été observé avec sa scène visuelle et une activation IA complète. Sur la preuve 1200 : 1 début de tour, 1 fin, 1 `action_resolved`, avec deux activations joueur avant progression. Les modales inventaire/codex, leur fermeture Échap, l'exclusivité OBJETS/SORTS et les raccourcis ont passé leurs contrôles.

Captures de référence 1200, dans `e2e_1200/corrected/` :

- `room_01_idle__20260906T083314__1200x896.png`
- `room_04_idle__20260906T083340__1200x896.png`
- `victory_result__20260906T083359__1200x896.png`
- `loss_result__20260906T083407__1200x896.png`

Les captures idle attendent la disparition naturelle du bandeau de début de tour, sans masquer un nœud. Les captures `combat` gardent l'état de début de tour comme preuve distincte. La légende « Lance · CATABASE » provient du thème canonique existant `data/ui/achilles_hud_theme_refined.tres:27`, pas du runner.

## Réserves mémoire et évolution de la sonde

Les contrats fonctionnels verts n'impliquent pas une fermeture moteur propre : les deux E2E historiques signalent **390 ressources encore utilisées**, environ **2790 instances ObjectDB** et des RIDs/shader non libérés à la sortie. Ces messages figurent surtout dans stdout/stderr ; ne pas les retirer de la preuve.

Un autre agent a ensuite corrigé un cycle de référence de `MasteryReactiveRuntimeService`. Sa validation ciblée est distincte : `artifacts/run_integration_20260906/test_logs/codex_mastery_lifecycle_clean.log`, **21/21 tests, 367 assertions, sans erreur ni warning de fuite**. Aucun E2E GPU post-correctif n'a encore confirmé l'effet sur les 390 ressources historiques.

Les premiers essais de la sonde ont révélé puis corrigé ses propres erreurs : argument PowerShell mal concaténé ; mauvais Mage attendu en IV ; capture lambda d'un écran déjà libéré, remplacée par une `WeakRef` explicitement typée. Ces essais restent conservés dans `e2e_1200/` et `e2e_1200/final/` ; ils ne sont pas les résultats verts listés plus haut.

Le `default_seed=2401` de RunData n'était pas effectif dans les deux historiques, car `randomize_seed_each_run` est activé par défaut. Le runner a donc été complété avec `--seed=2401` : copie mémoire superficielle de la seule run sélectionnée, tirage aléatoire désactivé sur cette copie, ressource canonique non sauvegardée, seed effectif asserté. Les métadonnées de renderer effectif ont aussi été ajoutées au JSON. Ce dernier code a seulement atteint sa garde de parsing headless (`parse_smoke_seeded/run_integration_report.json`) ; **ce smoke ne valide pas le gameplay ni les assets**.

Les trois commandes de reprise exactes et sérialisées figurent dans [README.md](README.md), vers `e2e_final_1200`, `e2e_final_1920` et `hud_canonical`. Attendre les ressources Paris complètes et un chargement Catabase propre, sans modifier le travail parallèle.
