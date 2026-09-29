# Prototype v1 — intégration

Demande : intégrer la proposition du 29 septembre dans Catabase Cartes existante, sous le nom Prototype v1.
HEAD initial : `86018f9c7ea0f13f1dde868b6fcafe95e8b620f1`. Nombreuses modifications de ressources étrangères préexistantes, à préserver.

- Contrat accepté : 4 + 2/niveau points élémentaires (rendements 3/2/1), aptitudes 3/6/9, spécialisation 4, perfectionnements 4/8/12 réaffectables ; corrections de 2 points par halte, réorientation complète aux refuges 11/16/19 à partir du niveau 8.
- Même ruleset/session/parcours public. Ajouter une révision de progression interne ; une ancienne sauvegarde active finit son combat avec ses valeurs puis migre à la préparation. Rembourser explicitement les anciens attributs, conserver copies, niveaux, XP et équipements, préserver le ratio de PV sans soin de migration.
- Composantes élémentaires explicites dans le catalogue, calcul partagé avec les aperçus, effets dérivés non amplifiés deux fois, effets différés figés à leur création. Attaque permanente distincte pour les quatre classes ; passifs et spécialisations conservés.
- Réutiliser les ressources d'objets et services Studio, la fenêtre dossier et les transactions/sauvegardes existantes. Aucun nouvel écran de run parallèle.
- Vérifications prévues : import, tests ciblés progression/math/migration/combat/UI, suite cards puis all, gates CI et captures intégrées pertinentes. Aucun ancien rapport ne constitue une preuve nouvelle.
- Avancement : implémentation et contrôles intégrés terminés. HEAD revérifié inchangé le 29 septembre à 22 h 02. Les gates globales restent en échec, détaillées ci-dessous.

## Fichiers et décisions concrètes

- Service de règles `core/expedition/consumable_progression_v1.gd`, état versionné, calcul des composantes, attaques permanentes, garde/soins/effets différés raccordés au moteur existant.
- `consumable_cards_integration.gd` contrôle allocations et quotas ; `expedition_save_service.gd` valide/restaure les PV historiques avant toute migration. Les anciens combats actifs gardent leurs règles jusqu'à la victoire.
- 48 sorts classifiés, 6 sceaux de maîtrise, 32 objets publiés via `ItemTransactionalSaveService` / `ItemStudioDocument`. Les changements d'identifiants de sérialisation des ressources inchangées ont été retirés.
- Sélection `cards_character_setup.gd`, dossier existant et `consumable_progression_editor.gd` : allocation groupée, aperçu, points de départ, réorientation et perfectionnements gratuits. Captures existantes étendues pour réellement actionner et sauvegarder ces contrôles.
- Contrat courant : `docs/current/prototype_v1.md`. Aucun changement de difficulté ennemi ni de route ; la courbe historique de Puissance reste utilisée par les ennemis et la compatibilité.

## Vérifications nouvelles

- Import/test initial en sandbox : échec avant tests (accès certificats/répertoire). Nouvelle exécution autorisée avec profil isolé.
- Profil : 7 tests / 79 assertions, PASS, `artifacts/dev/20260929-205120-test-test_unit_test_consumable_cards_profile.gd-ff3eae91/summary.json`.
- Première suite Cartes : 352 tests, trois échecs identifiés et corrigés (libellés nouveaux, comparaison JSON entière/flottante, attente de l'ancien attribut au niveau 2). Ne vaut pas un PASS global. `artifacts/dev/20260929-210249-test-cards-813d1d8a/summary.json`.
- Prototype v1 corrigé : **12 tests / 204 assertions, PASS**, import compris, `artifacts/dev/20260929-211137-test-test_unit_test_consumable_cards_prototype_v1.gd-55e8abfc/summary.json`. Comprend drain, garde, brûlure, surface, attaque permanente, quotas, migration et ratio de PV.
- Audit contenu : 7 tests Python, PASS ; 13 060 fichiers, aucune ressource externe manquante, `artifacts/content_audit/prototype-v1-resources.json`.
- Formatage des trois nouveaux scripts : PASS. `git diff --check` : PASS.

## Résultats finaux

- **Périmètre Cartes : 354 tests, 32 860 assertions, aucun test échoué** dans le JUnit de la suite globale. Extraction selon les motifs de `tools/dev/test-suites.json` : `artifacts/dev/prototype-v1-cards-results.json`. Il s'agit d'un sous-ensemble d'une exécution globalement en échec, pas d'un PASS de `test all`.
- **Parcours public et 16 captures : PASS**, `artifacts/dev/20260929-215318-cards-integrated-visual-b113ce26/report.json`. Sélection réelle, passage au seuil, maîtrise Soleil conservée, garde effectivement produite de 8, consommation et reprise. Résolutions 1280×720 et 1600×900, aucun diagnostic Godot. Les champs de départ et les titres des attaques permanentes ont été corrigés après inspection visuelle ; nouvelle capture du combat 720p inspectée après le dernier ajustement.
- **Dossier et butin, 34 captures : PASS**, `artifacts/dev/20260929-211413-player-dossier-f37b4ea8/report.json`. Allocation Nuit réellement validée et retrouvée en sauvegarde. Inspection des vues départ 720p/900p, caractéristiques 720p et progression 900p, en complément des contrôles de géométrie automatisés.
- **Douze scènes réelles : OK**, `artifacts/dev/20260929-220022-cards-live-reaudit-60e1bc55/summary.json`. Douze rencontres, sept captures, aucune anomalie ni erreur moteur. Pression : 3 PV retirés, garde de 16 préservée ; passage du boss en phase 2 après dégâts périodiques. Capture Forge/pression inspectée. Le harnais force les transitions et les victoires : il ne mesure pas la difficulté d'une partie.
- **Publication : PASS**, 32 objets via les services Studio ; `artifacts/consumable_cards_v2/content_publication.json`. Couverture des composantes et des six domaines : `artifacts/dev/prototype-v1-content-coverage.json`.

## Gates globales non vertes

- `test all` : **3 386 tests, 166 tests échoués**, 300 679 assertions rapportées. Rapport `artifacts/dev/20260929-211714-test-all-284d701c/summary.json`. Godot a également terminé par une violation d'accès (`-1073741819`). L'allowlist exacte refuse le résultat ; `artifacts/dev/prototype-v1-allowlist-result.txt`. Aucune entrée ni gate CI n'a été neutralisée.
- `test studio` : **522 tests, 28 tests échoués**, 17 552 assertions réussies sur 17 668. Rapport `artifacts/dev/20260929-214626-test-studio-db853c3d/summary.json`, détails extraits dans `artifacts/dev/prototype-v1-studio-failures.json`.
- Smokes CI : **Rencontres PASS ; Terrain et Objets FAIL**. `artifacts/dev/20260929-220002-prototype-v1-ci-smoke-d59bf1e9/summary.json`. Terrain ne produit pas d'image de viewport avec le renderer headless. Objets rencontre une conversion en Dictionary invalide dans `ItemStudioMain._remember_ui_state`, ligne 1539, en ouvrant la fixture générale `hache_executeur` ; ce code n'est pas modifié ici.
- Portabilité : **FAIL**, 17 chemins utilisateur dans le fichier inchangé `vfx/class_cards/cel/art/provenance.json`. Versions Studio et JSON de l'allowlist : PASS. `artifacts/dev/prototype-v1-ci-lint.json`.

Les échecs examinés incluent les attentes de backend 3D d'Achille alors que sa scène
sélectionne SPRITE_2D, les comptes historiques 46 sorts/12 objets du mode classique,
les transactions de récupération Studio et l'empreinte du catalogue général.
Ce dernier découvre `data/items/definitions` ; les six nouveaux sceaux résident dans
`data/cards/consumable_v2/items` et n'entrent pas dans ce catalogue. Les tests du seuil
classique utilisent `odyssey.tres`, tandis que le parcours Cartes passe ses propres
tests intégrés. Détails : `artifacts/dev/prototype-v1-global-failure-audit.json`.
Sans relance dans un checkout vierge, il ne faut pas attribuer automatiquement les
166 échecs à un état antérieur ni annoncer une absence globale de régression.

## Préservation et limites

La suite globale a réécrit deux fixtures suivies, initialement propres, sous
`artifacts/arena_studio/arena_studio_test/`. Leurs sorties ont été conservées dans
`artifacts/dev/prototype-v1-test-mutations/`, puis leurs octets initiaux restaurés.
L'empreinte complète du diff suivi et des fichiers non suivis a ensuite retrouvé
son état avant tests : `artifacts/dev/prototype-v1-worktree-after.json`.
Les derniers contrôles Studio, captures et smokes n'ont pas muté le worktree :
`artifacts/dev/prototype-v1-final-worktree-after.json`. Les ressources étrangères
déjà modifiées avant ce travail restent préservées.

La couverture normale de départ contient au moins une famille par élément et
classe, mais certaines orientations n'en ont qu'une. Cela ne prouve pas la
viabilité de chaque construction mono-élément. Aucun taux de victoire ni équilibre
de fin de run n'est certifié. La suite utile est une campagne de parties sur ce
Prototype v1 et l'enrichissement des répertoires faibles, sans créer de parcours parallèle.
