# Intégration du bestiaire Cartes — suivi

Base : `6e8d2605de49d7ad53301db39395b12eaa5c13fe`. Demande : commencer la résolution de l'audit en intégrant le philosophe et la famille squelette existante aux rencontres publiques. Les dossiers non suivis `docs/audits/gameplay_2026-09-28/` et `tools/gameplay_audit_2026_09_28/` appartiennent à l'audit terminé ; les préserver.

Inventaire : un centurion de glace, un chef squelette rouge, un squelette de mêlée, un squelette à distance ; philosophe « Le Dialecticien ». Les ressources et comportements existent, mais hors compositions publiques actuelles. Question facultative adressée à l'utilisateur sur le sens de « différents centurions ».

Contraintes identifiées : l'adaptateur Cartes remplace les sorts/IA ; l'aperçu reconstruit le profil natif ; les checkpoints intégrés supposent un roster fixe et n'enregistrent pas les invocations/télégraphes natifs. Les VFX philosophe reconnaissent son identité native. Une simple insertion dans les listes n'est pas suffisante.

Direction : définition de rencontre Cartes partagée entre aperçu et combat, compositions explicites pour les nouvelles parties, conservation du profil antérieur des sauvegardes ; budgets adaptés au niveau, kits natifs et services de combat réutilisés. Les invocations doivent être bornées, sauvegardées et exclues du loot initial. Vérifier scènes, intentions, reprise, mort du commandant, effets de classe et visuels.

Périmètre confirmé par l'utilisateur : toute la famille squelette et le philosophe.

Implémentation : `consumable_enemy_profile.gd` partage composition/projection entre aperçu et Battle. Bestiaire 1 choisi au départ sur route 6 ; les sauvegardes sans champ restent en 0. D2 : mêlée/archer avec compagnon de branche ; D6 : légion complète ; D8/D17 : Dialecticien. Budgets initiaux conservés, réserve de 72 PV pour les deux invocations de l'élite (total maximal 336 PV). Aucun tirage de butin pour les renforts.

Les kits passent par le runner natif. Identité de contenu distincte des IDs de combat ; hook de dégâts différés neutre pour les anciens sorts, adapté aux règles Cartes. Checkpoint 3 : invocations, budgets consommés, annonces, ordre de jeu, orientation, réduction du déplacement forcé. ID attribué selon le roster, pas l'ordre du solveur de placement. Description complète : `docs/current/cards_bestiary.md`.

Tests ajoutés : `test_consumable_cards_bestiary.gd` (budgets/branches/difficultés, sorts, IA, reprise réelle, absence de loot supplémentaire). Fixtures historiques adaptées dans `test_consumable_cards_live_rooms.gd`. Captures reproductibles : `tools/consumable_cards/verify_bestiary.ps1` ; elles font passer le héros deux fois, sans affaiblir les ennemis. Les victoires intermédiaires sont déclarées pour accéder aux salles ; ce n'est pas une campagne d'équilibrage.

Premiers essais : typage de tableau de sorts corrigé ; formation native comptant également le héros documentée ; fixture de nettoyage des graphes de combat corrigée ; différence JSON entier/flottant corrigée ; reprise refusée lorsque le solveur réordonnait le roster corrigée. Le formateur 0.25.0 refusait le modificateur avec « formatted output is structurally different » ; une expression scindée en variables intermédiaires résout le problème. Les cinq nouveaux scripts passent désormais sa vérification de structure.

Validation intermédiaire : suite Cartes `20260928-130407-test-consumable-v2-9db477ee`, 137 tests / 6 769 assertions, seul échec dans la fixture du jardin qui supposait un socle libre. Fixture corrigée : vérifier le refus quand occupé, libérer explicitement le socle puis vérifier commande/reprise. La légion et les douze reprises ont passé ce lancement. Le test Gardien et la persistance explicite de l'ordre de jeu ajoutés ensuite sont couverts par la validation finale ci-dessous.

Runtime visuel initial `20260928-131656-cards-bestiary-visual-a22daf02` : quatre salles, huit captures, deux phases ennemies réelles chacune, zéro diagnostic moteur, 100 s. Sorts observés : lame/tir, marque/Appel des ossements, Aporie/Axiome/Égide. Les captures initiales masquaient parfois les acteurs avec la bannière de tour : le harnais attend désormais sa fermeture et les captures finales ont été refaites. Le héros passe ses tours ; ce contrôle ne prouve pas une victoire normale.

CI indépendante : sept tests Python `tools/content_audit` réussis après relance avec accès aux dossiers temporaires ; analyse des ressources (`artifacts/content_audit/bestiary-resources.json`) : 12 519 fichiers, zéro référence externe manquante. `git diff --check` et les deux contrôles de version Studio 2.0.0 réussis. Le contrôle de portabilité signale 17 chemins de provenance déjà présents dans `vfx/class_cards/cel/art/provenance.json`, fichier inchangé. Import du lancement global `20260928-133917-test-all-3d52bd3c` réussi ; résultats GUT ci-dessous. Le lancement précédent `131929` a été interrompu pendant l'import, avant les tests : aucune validation à en tirer.

## Résultats finaux des tests

État Git vérifié : même base `6e8d2605de49d7ad53301db39395b12eaa5c13fe`, modifications de ce lot non commitées. Les audits précédents non suivis sont préservés.

`./dev.ps1 test all -TimeoutSeconds 3600` : import réussi ; 334 scripts, **3 289 tests**, 3 115 réussis, **166 échecs**, sept pending et un risky ; 270 247 assertions réussies sur 271 101 selon GUT. Les tests ont produit leur résumé et le JUnit après 3 141,568 s, puis le moteur a crashé à la fermeture (`-1073741819`). **Validation globale FAIL**, ni timeout ni succès masqué. Rapport : `artifacts/dev/20260928-133917-test-all-3d52bd3c/gut-strict-report.json`.

Sous-ensembles extraits de ce JUnit avec les motifs actuels de `tools/dev/test-suites.json` (ils ne constituent pas des lancements isolés supplémentaires) :

| Ensemble | Scripts | Tests | Échecs |
|---|---:|---:|---:|
| Cartes consommables | 18 | 138 | 0 |
| Cartes complet | 31 | 296 | 0 |
| Monstres Catabase | 8 | 92 | 0 |
| Famille native : squelettes, centurion, philosophe | 5 | 81 | 0 |
| Catabase complet | 87 | 789 | 17 |
| Liste exacte CI Studio | 36 | 522 | 25 |

Les listes d'échecs sont dans `bestiary-subsets.json` du même dossier. Elles incluent anciens contrats visuels/décors, sélection et seuil, reliques, récupération et transactions Studio. Les notes du 27 septembre rapportent également 166 échecs et le même code de crash, mais leurs rapports complets ne sont pas présents sur cette machine : **aucune comparaison exacte des identités avec cette exécution antérieure n'est revendiquée**.

Le contrôle exact `tools/verify_gut_historical_allowlist.py` a été exécuté sur le log et le vrai code de sortie : **FAIL**, 166 échecs observés pour huit attendus, sortie normale GUT absente. Détails : `allowlist-check.txt`. La liste historique n'a pas été modifiée.

La gate d'absence de mutation est **FAIL** : GUT a réécrit les deux rapports suivis `artifacts/arena_studio/arena_studio_test/{arena_definition,validation_report}.json`. Ils étaient propres avant le lancement ; leurs sorties et leur diff sont conservés dans `source-mutations/`, puis leurs versions HEAD ont été restaurées. Les empreintes des sources modifiées n'ont montré aucun autre changement que les deux éditions explicitement réalisées pendant le lancement : texte du statut Égide + test associé. Les documents du lot ont aussi été complétés volontairement.

Après cette dernière correction de texte, `./dev.ps1 test test/unit/test_consumable_cards_bestiary.gd -TimeoutSeconds 600` : **PASS strict**, huit tests, **830 assertions**, zéro erreur moteur et zéro échec ; import réussi. Rapport : `artifacts/dev/20260928-143546-test-test_unit_test_consumable_cards_bestiary.gd-044f37a5/gut-strict-report.json`. Le global avait chargé la version précédente de cette infobulle et comptait 828 assertions dans ce fichier.

## Validation visuelle finale

`./tools/consumable_cards/verify_bestiary.ps1` : **PASS**, quatre salles, huit images en **1280×720**, deux phases ennemies réelles chacune, 97,280 s, zéro diagnostic moteur. Rapport : `artifacts/dev/20260928-143920-cards-bestiary-visual-5bdd807a/summary.json`. Les huit images `02/06/08/17_deployment` et `02/06/08/17_after_two_enemy_turns` ont été ouvertes et inspectées : ennemis visibles, HUD et main lisibles, patrouille et légion différenciées, case d'invocation et texte « Renfort · prochaine activation » visibles, Dialecticien présent aux deux profondeurs avec les compagnons attendus. Les zones dangereuses du jardin suivent son rôle de chef de salle.

Les snapshots ne montrent pas chaque animation de sort à son instant d'impact. Les logs confirment les lancers natifs et le retour au tour du héros. Les victoires de passage restent des fixtures et le héros passe dans les salles échantillonnées : aucun taux de victoire, aucun équilibrage final ni essai à une autre résolution n'est revendiqué.

## Smokes CI et limites restantes

Les trois scènes et les arguments Terrain de `.github/workflows/godot-validation.yml` ont été exécutés avec `--headless`, un profil utilisateur isolé et une limite de 240 s par scène. Rapports : `artifacts/dev/20260928-144136-bestiary-ci-smokes-0ab6c6b6/summary.json` et logs associés.

- **Rencontres : PASS** en 24,485 s, code 0, zéro diagnostic ; formation valide, graine 424242 et ressources canoniques inchangées.
- **Terrain : FAIL** en 53,194 s, code 1 ; cinq vues essayées, mais le renderer dummy ne fournit aucune image de viewport, puis des fuites à la fermeture.
- **Objets : FAIL** en 60,238 s, code 1 ; `ItemStudioMain._remember_ui_state` ne peut pas convertir une valeur en `Dictionary` (`item_studio_main.gd:1539`), puis échec explicite de validation/persistance et fuites de fermeture.

La relance complémentaire de Terrain avec `--rendering-method gl_compatibility --windowed --resolution 1280x720` a produit les cinq images, annoncé `failures=0` et terminé avec le code 0 en 32,545 s. **Verdict strict encore FAIL**, à cause des fuites RID, ObjectDB et ressources à la fermeture. Rapport : `artifacts/dev/20260928-144522-bestiary-terrain-rendered-f912454f/summary.json`. Les captures existent sous `artifacts/terrain_studio/screenshots/` ; aucune revue visuelle détaillée du Studio n'est revendiquée. Cette exécution ne remplace pas le verdict de la commande CI en mode headless.

Commandes Python reproductibles (exécutées avec le Python du runtime local) : `python -m unittest discover -s tools/content_audit -p 'test_*.py'` ; `python tools/content_audit/audit.py . --check-resources --output artifacts/content_audit/bestiary-resources.json`. Aucun résultat rouge n'a été ajouté à l'allowlist. Les anciens fichiers de rapport non suivis restent hors du lot.

## Reprise du travail

Le lot bestiaire est implémenté et ses contrôles ciblés sont terminés. Pour le découvrir, démarrer une **nouvelle run Cartes**. Les anciennes parties conservent volontairement leur bestiaire. Aucun processus de vérification n'est laissé actif ; dernier `git diff --check` réussi, HEAD inchangé. L'équilibrage ressenti demande des parties complètes avec plusieurs classes et styles de jeu ; les huit captures et les budgets mathématiques ne le remplacent pas. Les blocages transversaux listés ci-dessus restent à traiter séparément et empêchent une validation verte du dépôt entier.
