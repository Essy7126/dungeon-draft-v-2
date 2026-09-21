# Retrait de contenu et maintenance — 21 septembre 2026

Ce lot poursuit le nettoyage déjà présent dans le worktree. Il ne constitue
pas une suppression physique complète du trio, ni de toutes les anciennes maps.
Les modifications restent non commitées.

## Comportement et architecture

- Le catalogue de sélection n'expose plus Elfe, Mage et Guerrier, même avec
  `include_archived_adventures`. Le mode public garde les trois apparences
  d'Achille ; le mode laboratoire ajoute le scénario philosophe.
- L'Archiviste propose uniquement Catabase. Les tests vérifient le départ à la
  première salle, l'introduction, le profil solo et le refus de transition.
- Les constantes historiques du trio dans `GameManager` restent des alias de
  compatibilité pour les outils et tests ; elles ne définissent pas le roster public.
- `core/expedition/expedition_destination.gd` porte maintenant les décisions de
  destination : priorité de progression/butin, carrefour, halte peinte, marchand.
  Les méthodes publiques du manager délèguent ; sauvegarde et changement de
  scène restent dans le manager. Aucun format de sauvegarde n'est modifié.
- Les contrats de sélection, portraits, focus, protection des sauvegardes et
  profils sont adaptés au roster actuel. Les tests génériques du trio et les
  36 contrats Studio obligatoires sont conservés.
- Le test de titre Studio appelle le vrai comportement responsive au lieu d'une
  méthode supprimée. Le smoke Objets vérifie les cinq onglets réels.
- Le test du premier carrefour classique tient compte de la revue de build
  désormais optionnelle après les attributs ; les contrôles de reprise,
  progression obligatoire et destination restent présents.

## Fichiers supprimés dans ce lot

| Chemin sous `data/rooms/` | Motif |
|---|---|
| `maps/battle_salle_crete_montagne_enneigee.tscn` | Scène sans référence active identifiée |
| `maps/battle_salle_montagne_iso.tscn` | Ancienne variante sans référence active identifiée |
| `maps/battle_salle_montagne_chemin.tscn` | Uniquement liée à la fiche retirée ci-dessous |
| `first_run_room_02_chemin.tres` | Fiche sans référence externe identifiée |

Total : **4 fichiers, 45 281 octets**, en supplément du premier nettoyage.
Recherches effectuées par chemin, nom et UID dans les sources, ressources,
outils et tests. Les dépendances partagées de ces scènes restent présentes.
Les empreintes sont dans le rapport local
`artifacts/project_audit/2026-09-21/retired_maps.json`.

L'ancien runner `tools/run_flow_isolation_hub_smoke` (script, UID et scène)
a également été supprimé : il exposait exclusivement les deux anciennes runs,
n'était appelé par aucun autre outil ni par la CI et doublonnait les contrats
conservés du refuge et du flux de run. Ses empreintes sont dans
`retired_hub_runner.json`. **Total du présent lot : 7 fichiers, 56 534 octets.**

## Outils pour réduire le travail répété

- `tools/content_audit/audit.py` inventorie les dépendances littérales `res://`
  et UID. Rapport complet en JSON, sortie terminal limitée aux comptes et au
  chemin du rapport. Aucun effacement automatique.
- Cinq tests couvrent Unicode, ressources non suivies, UID, cycles internes,
  fichiers supprimés et exclusion des rapports. Une étape CI les exécute.
- Les suites `content`, `selection` et `navigation` ciblent les contrôles
  concernés ; `content` rassemble les onze scripts utiles au présent lot.
  Aucun retrait de `all`, aucune modification de l'allowlist historique.
- Le registre de contexte inclut le service de destination pour le retrouver
  sans relire l'ensemble du manager.
- Les audits datés sont exclus des recherches `rg` ordinaires, comme des
  recherches de contexte. `rg --no-ignore motif docs/audits` les garde accessibles.

Le graphe statique ne couvre pas les chemins construits, les scans de dossiers,
les références contenues dans des binaires ni les sauvegardes externes. Il aide
à choisir un périmètre de retrait ; il ne prouve pas seul l'absence d'usage.

## Vérifications

- Python : `python -m unittest discover -s tools/content_audit -p 'test_*.py'`
  **5/5 réussis** avec le Python local fourni. Le sandbox Windows refusait les
  dossiers temporaires ; exécution hors sandbox réussie.
- `./dev.ps1 selftest` : réussi, 65 contrats du lanceur et 17 cas de l'analyseur ; rapport
  `artifacts/dev/20260921-110820-selftest--85c803ad/`.
- `./dev.ps1 format core/expedition/expedition_destination.gd -Write` : réussi,
  limité au nouveau service.
- Première suite `content` corrigée : **55/55 tests, 3 281 assertions** ; contrôle
  strict en échec sur les fuites de fermeture et l'erreur volontaire de refus
  de transition du refuge. Rapport
  `artifacts/dev/20260921-110015-test-content-fc2f9e7f/`.
- Navigation initiale : 8/9 tests ; le test obsolète de revue de build a été
  corrigé ensuite et fait partie de la vérification finale.
- Import normal : code de sortie 0, mais **échec strict** sur les fuites de
  fermeture. Smoke Objets rendu : marqueur fonctionnel de succès présent,
  **échec strict** sur les fuites. Rapports
  `artifacts/dev/20260921-110522-retirement-runtime-c1de2958/`.
- Sélection rendue : **223 contrôles, 9 captures, aucun échec ni erreur moteur**.
  Tailles 1280×720, 1440×900 et 1920×1080. Capture 1280×720 inspectée : roster
  laboratoire actuel, aperçu et commandes lisibles, aucun ancien membre du trio.
  Ce runner active explicitement le laboratoire ; ce n'est pas une capture du
  menu public à trois entrées. Rapport `artifacts/character_selection_v2/after_review.json`.
- Vérification finale des dix scripts : **98/98 tests, 4 945 assertions** ;
  contrôle strict toujours en échec sur les fuites de fermeture et l'erreur
  volontaire du refuge. Aucun échec d'assertion ou de parsing dans ce lot.
  Rapport `artifacts/dev/20260921-110803-retirement-content-final-91e552ec/`.
- Suite globale : **échec et timeout à 900 secondes**, avec erreurs des anciens
  tests 3D d'Achille, JUnit et résumé final absents. Le zéro affiché par le
  contrôleur signifie des totaux indisponibles, pas zéro test exécuté. Rapport
  `artifacts/dev/20260921-111332-retirement-global-3a9d6d6b/`.
  Deux assertions de cinématique encore liées à l'ancien catalogue du refuge
  ont été détectées puis adaptées ; leur vérification ciblée est consignée ci-dessous.
  La comparaison à l'allowlist refuse cette exécution incomplète ; aucune
  entrée n'a été ajoutée ou retirée.
- La suite globale a modifié uniquement `generated_at` dans deux rapports
  suivis de `artifacts/arena_studio/arena_studio_test/`. Après comparaison des
  objets JSON hors ce champ, leurs octets initiaux ont été rétablis. Les sorties
  produites sont conservées sous `global_generated_changes/` dans l'audit local.
  Le contrôle de non-mutation reste en échec ; cette restauration ne le valide pas.
- Cinématique après correction : `./dev.ps1 test test/unit/test_catabase_cinematic_v4.gd`,
  **19/19 tests, 451 assertions**, mais échec strict sur les fuites de fermeture.
  Rapport `artifacts/dev/20260921-113234-test-test_unit_test_catabase_cinematic_v4.gd-44ec6137/`.
  Les vérifications ciblées finales totalisent donc **117 tests** dans deux
  exécutions ; elles ne remplacent pas une suite globale complète.
- CI distante non exécutée ; la liste des 36 tests Studio est identique à HEAD.

Les erreurs moteur restent bloquantes. Aucun résultat incomplet n'est présenté
comme réussi et aucune tolérance du contrôleur strict n'a été élargie.

## Retraits encore nécessaires

La suppression physique du trio est autorisée, mais **non effectuée** dans ce
lot : ses fiches et médias servent encore au fallback de `RunHeroResolver`, à
l'avatar du vieux refuge, à la progression, aux validations 3D et aux smokes du
Studio. Retirer uniquement les fichiers casserait ces parcours et leurs tests.
La suite consiste à remplacer ces usages par du contenu actuel ou des fixtures
minimales explicites, puis à retirer leurs dépendances devenues orphelines.

Les maps forêt, volcan, station, montagne `iso_v2`/`iso_v3`, arène et plateau
restent également utilisées par les fixtures et outils. Le nouveau graphe
permet d'identifier leurs consommateurs avant migration. Les ressources de
Catabase et leurs références artistiques partagées sont conservées.

Les autres grands contrôleurs, l'unification complète des règles et les fuites
du Studio restent des travaux distincts. Aucun gain chiffré de tokens n'est
revendiqué : mesurer sur des tâches comparables les fichiers lus, recherches,
relances de tests et temps de validation.
