# Journal de l’étude Slay the Spire

Demande : lire toutes les cartes, leurs améliorations et leurs effets, puis expliquer leur gameplay et leur intérêt pour Catabase. Étude du premier jeu, hors mods et jeu de plateau, commencée le 25 septembre 2026.

Référence locale initiale : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Les dossiers antérieurs, initialement non suivis, ont entretemps été intégrés à `main`. Base de publication contrôlée après fetch : `24053adbb4a41f9442f14a6c23ca721b8c413c8b`, identique à `origin/main`. Aucun écart sur les catalogues de cartes Godot et les règles de salles cités entre ces références. Aucun changement du moteur ou du contenu jouable dans cette étude.

Constat de collecte : Spire Archive annonce 361 cartes dans son README mais son fichier contient 360 entrées, dont Impulse et Unraveling, retirées. Les cartes générées sont incomplètes. Plusieurs textes améliorés sont mal reconstruits : nombre de coups confondu avec dégâts, deuxième occurrence d’une valeur non mise à jour. Ce jeu de données sert d’inventaire à corriger, pas d’autorité unique.

Livré : cinq catalogues et un JSON, 370 entrées dont 367 cartes et 3 choix de Wish ; contrats base/amélioration et analyses individuelles. Dictionnaire transversal, douze moteurs de build, notes d’équilibrage de créateur et témoignages distingués, comparaison locale et six propositions de règles. Le README constitue le point d’entrée ; les TSV sont les sources éditables. Les compteurs sont contrôlés par `verifier_dossier.mjs`.

Décisions : conserver les sacs sur les mobs et la consommation définitive ; ne pas copier les boucles de rejouage ; distinguer cartes permanentes et éventuels jetons ; donner priorité à l’accès aux combinaisons et aux améliorations de règles. Les six propositions ne sont pas implémentées ni déclarées équilibrées.

Vérifications exécutées avant publication :

- `node docs/design/slay_the_spire_complete_2026-09-25/construire_catalogue.mjs` : 370 identifiants uniques, couverture 75/75/75/75/70.
- `node docs/design/slay_the_spire_complete_2026-09-25/calculs.mjs` : 47 scénarios, 50 assertions ; 3 003 mains énumérées.
- `node docs/design/slay_the_spire_complete_2026-09-25/verifier_dossier.mjs` : contrôles de couverture, fraîcheur, liens et comparaison V1 réussis ; détails dans VERIFICATION.json.
- `node --test --test-isolation=none docs/design/card_economy_lab/simulate.test.mjs docs/design/card_economy_lab/research_2026-09-25/systems_math.test.mjs docs/design/consumable_v1/model.test.mjs docs/design/consumable_v1/contracts.test.mjs` : 212 tests réussis, 0 échec, 0 ignoré. Sortie complète dans `artifacts/dev/slay-the-spire-complete/research-tests.txt`.
- `node docs/design/consumable_v1/verify_delivery.mjs` : manifeste et empreintes concordants. Contrôle de fraîcheur des résultats existants ; les 640 runs de cette livraison précédente n’ont pas été toutes relancées ici.
- `node docs/design/dofus_wakfu_spell_identity_2026-09-25/verifier_dossier.mjs` et celui de `extension_classes_bestiaire` : contrôles documentaires réussis.
- `git diff --check` : aucun défaut signalé avant préparation finale.

Incident d’outillage résolu : un lancement de sous-processus Node était refusé (`EPERM`) avant vérification de fraîcheur. Le vérificateur utilise désormais des imports avec `--check`, sans sous-processus. Le Git minimal ne disposait pas du transport HTTPS ; le Git complet fourni par GitHub Desktop a permis le fetch autorisé. Aucun contournement par force-push n’est prévu.

Publication demandée explicitement : commit Conventional Commits et push de tous les changements restants sur `main`. Les travaux précédents sont conservés ; les logs sous `artifacts/dev/` ne font pas partie du contenu à versionner. Vérifier l’égalité des HEAD local/distant et la propreté du dépôt après push. Les workflows CI existants restent actifs ; leur réussite n’est pas incluse dans les résultats locaux ci-dessus.

Suite : choisir un prototype de règle dans APPLICATION_CATABASE.md, définir son timing exact, puis tester le moteur et des joueurs. Avant toute transposition d’un cas limite StS, reproduire les ordres d’action et de copie signalés dans EFFETS_ET_REGLES.md.

Limite : une lecture documentaire et des calculs ciblés ne constituent pas des parties jouées ni une validation du moteur Slay the Spire.

Complément demandé avant clôture : le dossier `wakfu_character_builds_2026-09-25` approfondit les 18 classes WAKFU, avec 38 lectures dont 36 identifiants nouveaux, deux relectures et 15 scénarios mathématiques. Les portraits explicitent les ressources, deux directions de construction, les sacrifices et les réponses adverses ; les incohérences de fiches restent visibles. Les READMEs des études sont reliés pour reprise sur l'autre ordinateur. Publication commune demandée sur `main`.
