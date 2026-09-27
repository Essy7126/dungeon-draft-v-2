# Cartes consommables — intégration dans la run existante

> Réaudit du même jour : [quatre défauts d'intégration encore présents](cards_reaudit_2026-09-27.md). Les preuves ci-dessous restent historiques ; elles ne suffisent pas à déclarer toute la refonte terminée.

Demande : appliquer la refonte à Catabase, en retirant la troisième aventure
publique créée autour du prototype. Travail effectué dans le checkout existant,
avec les modifications concurrentes de personnages, VFX, Studio et haltes conservées.

## Parcours et responsabilités

Le menu propose Classique et Cartes. Cartes emprunte la sélection existante,
l'introduction, le Seuil des Ombres, `ExpeditionSession`, les scènes `Battle`
de la route, leur HUD persistant et les haltes existantes. La session Cartes
porte les quinze copies de départ, les niveaux 1–12, attributs, spécialisations,
améliorations de famille, équipements, reliques et reçus économiques.

`consumable_cards_integration.gd` raccorde les règles à la session ;
`battle/consumable_cards_runtime.gd` raccorde les mêmes règles à la grille,
aux unités, au séquenceur de tours et aux animations de Battle. Les cartes
utilisent le lanceur de sorts partagé. Les ennemis gardent leurs apparences
et leurs placements ; leurs statistiques et comportements suivent les sept
rôles de la refonte. La route garde vingt profondeurs et douze combats.

Il n'y a plus de `GameManager.consumable_run`, de variante publique `cards_v2`
ni de redirection de la sélection vers l'écran du prototype. Les petites
arènes et cet ancien écran restent des harnais de référence.

## Corrections contrôlées

- Consommation effective dans la vraie Battle et commandes rétention, Relais,
  ancre, attraction et sacrifice raccordées à la main existante.
- Reprise du combat sans redéploiement ni nouveau tirage : PA/PM, PV, boucliers,
  unités mortes, positions, statuts, usages, intentions et surfaces persistés.
  Les données sont validées avant de remplacer la session active.
- Victoire enregistrée avant l'animation de sortie ; reçu idempotent et copie
  du coup final consommée. Une défaite supprime la continuation.
- Une erreur d'écriture pendant le combat bloque les nouvelles commandes et
  offre une nouvelle tentative. Pendant la résolution ennemie, la reprise se
  fait à la dernière décision complète du héros.
- Les changements d'équipement préservent le ratio de PV non arrondi à travers
  les sauvegardes. Le soin de montée de niveau n'ajoute le gain de PV qu'une fois.
- L'atelier affiche les familles lorsque la recherche est vide. La halte de
  préparation finale n'ouvre pas les services commerciaux.

La sauvegarde reste `user://catabase_cards_v1.json`. Le champ `ruleset_id`
identifie les nouvelles règles. Les anciennes parties restent lisibles avec
leurs règles historiques ; aucune sauvegarde personnelle n'a été convertie.
Tous les essais utilisent des données utilisateur isolées dans `artifacts/dev`.

## Vérifications

Les rapports ci-dessous sont relatifs à `artifacts/dev/`.

| Contrôle | Résultat | Rapport |
|---|---|---|
| Neuf scénarios d'intégration après correction | PASS, 430 assertions ; douze scènes réelles, reprise après mort ennemie, coup final et sauvegarde | `20260927-122202-test-test_unit_test_consumable_cards_integration.gd-64eb4f6d/summary.json` |
| Suite Cartes complète finale | PASS, 190 tests / 14 625 assertions, aucun diagnostic bloquant | `20260927-122354-test-cards-ed72ec45/summary.json` |
| Entrée publique et captures réelles | PASS, seize images produites à 1280×720 et 1600×900, zéro diagnostic moteur ; parcours et bilan inspectés visuellement | `20260927-121111-cards-integrated-visual-63d11492/report.json` |
| Ressources sérialisées | PASS, 12 270 fichiers, aucune référence externe ou manquante | `cards-integrated-resources-final-20260927.json` |
| Contrats Python de l'audit de contenu | PASS, sept tests | commande `python -m unittest discover -s tools/content_audit -p 'test_*.py'` |
| Suite globale | FAIL, 3 177 tests, 166 tests en échec, crash de fermeture `-1073741819` | `20260927-114638-test-all-2790eefa/summary.json` |
| Comparaison exacte au global précédent | Les mêmes 166 identités, aucune nouvelle ni résolue | `cards-global-comparison-20260927.json` |
| Liste CI Studio dans la suite globale | 36 scripts attendus présents, 522 tests, les mêmes 28 tests en échec | `cards-studio-subset-20260927.json` |
| Smokes partagés | Rencontre fonctionnel mais première fermeture avec fuites ; Objets FAIL ; Terrain headless sans viewport et GL avec fuites malgré cinq images produites | `20260927-121325-cards-shared-smokes-9d8ffcd7/report.json` |
| Diagnostic supplémentaire Rencontre | Fonctionnel, sortie 0, sans diagnostic moteur bloquant ; fuite précédente non reproduite avec `--verbose` | `20260927-121755-encounter-smoke-diagnostics-7c485a8a/report.json` |
| Portabilité CI | FAIL, 17 chemins de provenance VFX locaux déjà présents | `cards-portability-final-20260927.log` |
| Vérification du diff | PASS, aucune erreur d'espacement | `cards-diff-check-final-20260927.log` |

Le global a démarré avant les derniers durcissements des sauvegardes. Ceux-ci
sont validés par les scénarios d'intégration puis la suite Cartes finale, pas
par une nouvelle exécution globale prétendue. Les deux rapports globaux viennent
d'un checkout partagé et modifié : la comparaison ne remplace pas une baseline
propre. L'allowlist CI attend huit échecs et reste inchangée ; elle rejette ce
global et son crash. Aucun nettoyage des modifications concurrentes n'a été
effectué pour présenter artificiellement un arbre propre.

Les essais intermédiaires restent des échecs : script de test non chargé pour
une annotation manquante, tentative bloquée par le verrou, puis reprise refusée
après mort ennemie. Le dernier défaut venait de la comparaison de `[-1, -1]`
avec les nombres flottants décodés depuis JSON ; le validateur accepte désormais
ces coordonnées numériquement sans accepter d'autres cases invalides. Le test
du coup final sélectionne une famille à impact dans la main réellement tirée.

Le formatage structurel automatique refuse encore certaines expressions de
plusieurs nouveaux scripts ; il n'a pas été forcé. Les imports et tests Godot
restent la preuve de compilation. Les sorties et décisions intermédiaires sont
dans la [fiche de suivi](../ai/CARTES_INTEGRATION_RUN_2026-09-27.md).

Les scénarios de vingt profondeurs et les captures de bilan utilisent des
fixtures de transactions. Ils ne mesurent ni le taux de victoire ni la durée
d'une partie normale. L'équilibrage complet exige une campagne jouée sur les
cartes réelles ; les simulations des sept arènes du prototype ne le prouvent pas.
