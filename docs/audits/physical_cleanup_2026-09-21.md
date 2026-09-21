# Nettoyage physique — 21 septembre 2026

## Périmètre

Suite aux audits précédents, suppression autorisée des anciens personnages,
des anciennes maps inutilisées, puis de la salle de l'Archiviste.
Les changements antérieurs du répertoire de travail ont été conservés.

## Résultat

- Modèles, textures, animations et scènes propres à Elfe/Mage/Guerrier supprimés.
  Leurs identités et règles restent des fixtures de régression, avec un mannequin
  procédural partagé sous `test/fixtures/party_rules/`.
- Sept anciennes scènes nécessaires aux tests de grille déplacées vers
  `test/fixtures/terrain/`, sans leurs fonds ni musiques spécifiques.
- Salle de l'Archiviste supprimée avec le modèle original, le décor, les panneaux,
  la navigation et les captures dédiées. Les anciens retours de run vont au titre.
  Le Refuge des braises, les haltes et le Seuil restent actifs.
- Quatre anciennes fiches ennemies orphelines et cassées supprimées : archer,
  hurleur et lieur gobelins, serpent de Méduse. Une scène d'aperçu orpheline
  dont le script avait disparu est également retirée.
- Ancien écran de groupe isolé dans les fixtures ; aperçus rapides du Studio
  basés sur Achille et son profil de progression explicite.
- Suppression du fallback implicite vers le trio. Les scénarios de diagnostic
  injectent leurs fixtures ; les runs déclarent leur profil.
- Catalogues Studio compatibles avec un profil partagé par plusieurs runs.
- Suite locale `retirement`, délai de test configurable, contexte ciblé et audit
  des références pour limiter les recherches et relectures inutiles.

Les terrains peints forêt/volcan/station et les règles historiques encore
exercées restent conservés. Ils ont des consommateurs de tests/Studio identifiés.
Les archives documentaires ne décrivent pas nécessairement le produit actuel.

## Taille et traçabilité

L'ensemble des changements non commités représente environ **344 Mo de moins**
de fichiers versionnables (comparaison au HEAD `fadd1449`, au 21 septembre).
Cette mesure inclut les lots précédents, pas seulement la présente intervention.
Elle ne mesure ni une réduction de `.git`, ni une économie chiffrée de tokens.

Les manifestes locaux sous `artifacts/project_audit/2026-09-21/` consignent chemins,
tailles et empreintes avant suppression. Les rapports de validation sont sous
`artifacts/dev/`. Les déplacements apparaissent parfois comme suppression/ajout
avant indexation Git ; le nombre de suppressions n'est donc pas un compte de
ressources définitivement abandonnées.

## Validation

- `./dev.ps1 selftest` : réussi, 65 contrats du harnais et 17 de l'analyseur strict
  (`artifacts/dev/20260921-134838-selftest--8f33b8c5`).
- `python -m unittest discover -s tools/content_audit -p 'test_*.py'` : 7/7 réussis.
- `python tools/content_audit/audit.py . --check-resources --output artifacts/content_audit/resources.json` :
  11 692 fichiers inventoriés, aucune déclaration `ext_resource` manquante.
  Vérification complémentaire de casse : aucun écart. Les projets imbriqués
  utilisent leur propre racine. Ce contrôle est ajouté à la CI.
- `./dev.ps1 test retirement -TimeoutSeconds 1200` : 212 tests exécutés,
  207 réussis et 5 échoués. Les cinématiques Catabase (17), retours après défaite
  (6), chronique (9), isolation des profils (15), registre de captures (3) et
  Studio des compétences (23) passent leurs assertions. La suite stricte échoue
  aussi sur des ressources non libérées en fermeture.
  Rapport : `artifacts/dev/20260921-134826-test-retirement-750bc9fd`.
- Trois de ces cinq échecs provenaient d'un appel sans argument dans le runner
  adapté ; l'appel a été corrigé. Sa relance a ensuite révélé un contrat historique
  à cinq salles, alors que la ressource en contient quinze. Le test et les textes
  de présentation obsolètes ont été actualisés. Relance finale `./dev.ps1 test test/unit/test_odyssey_validation_expectations.gd -TimeoutSeconds 240` : **3 tests et 20 assertions réussis**, verdict strict PASS
  (`artifacts/dev/20260921-140918-test-test_unit_test_odyssey_validation_expectations.gd-ebbe00eb`).
- Sélection avec rendu réel : **223 contrôles réussis**, **9 captures**, aucune
  erreur moteur. Résolutions 1280×720, 1440×900 et 1920×1080 ; inspection visuelle
  effectuée sur 1280×720. Le runner active explicitement le scénario de laboratoire
  en plus des trois apparences publiques. Ce contrôle ne vaut pas une partie entière.
  Rapport : `artifacts/dev/20260921-140706-cleanup-selection-final-16529d0b`.
- `./dev.ps1 test all -TimeoutSeconds 1800` : **incomplet et en échec**.
  Exécution arrêtée après erreurs répétées des anciens tests 3D et absence de
  progression dans `test_all_twenty_meshy_clips_keep_safe_viewport_margins`.
  Aucun JUnit final : les totaux à zéro de la synthèse signifient « indisponibles ».
  Logs et motif d'arrêt : `artifacts/dev/20260921-135646-test-all-43fa9ccd`.
- Les imports de préparation en mode recovery se terminent avec code 0. L'import
  normal effectué précédemment se termine aussi avec code 0, mais son verdict
  strict reste négatif à cause de ressources non libérées ; ce n'est pas un import
  entièrement validé (`artifacts/dev/20260921-133725-cleanup-runtime-a2f91ffb`).
- `git diff --check` : réussi. Les captures historiques modifiées par les essais
  ont été restaurées ; les nouvelles copies restent dans les rapports locaux.

## Limites restantes

Deux échecs Studio persistent : vérification finale après sauvegarde d'un profil
(`FINAL_VERIFY`) et empreinte du catalogue d'objets différente de sa caractérisation.
Le catalogue d'objets et son empreinte attendue n'ont pas été réécrits pour faire
passer le test. Les erreurs de fermeture et les contrats 3D historiques empêchent
également de déclarer la CI verte. L'essai complet des 36 scripts Studio a atteint
son délai de 900 secondes sans rapport final exploitable.

Aucune liste d'exceptions CI n'a été élargie. Les **36 scripts Studio obligatoires**
restent sélectionnés exactement comme avant. Les tests exclusivement liés au trio
artistique et à la salle de l'Archiviste retirés ont été supprimés ; les règles
communes restent testées avec des fixtures explicites. La suite `retirement`
contient désormais 16 scripts.

Le retrait physique demandé est réalisé ; la validation globale du projet reste
incomplète. Aucun commit ni aucune publication n'a été effectué.
