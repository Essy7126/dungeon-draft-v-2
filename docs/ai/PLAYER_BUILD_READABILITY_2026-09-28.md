# Lisibilité du build — 28 septembre 2026

Suite de l'audit du parcours du 27 septembre. Périmètre : fenêtres publiques
Cartes V2 ; DA marron sobre. Pas de changement des règles ni du format de sauvegarde.

## Décisions et réalisation

- Comparaison en lecture seule d'un équipement avec l'emplacement actuel : valeurs
  avant/après issues de `consumable_card_math.gd`, retrait compris. Les bonus de
  dégâts conditionnels restent séparés de la puissance. Les plafonds et excédents
  de résistance/PM/main sont explicités. Le bouton équiper/retirer reste fixe sous
  la fiche défilante ; la consultation en combat n'autorise pas les transactions.
- Origine des statistiques dépliable : base du niveau, contribution des attributs,
  contribution effective de l'équipement, total permanent. Les arrondis et plafonds
  sont pris en compte dans les contributions. Les valeurs temporaires du combat
  ne sont pas présentées comme des bonus permanents.
- Filtres « Dernier butin » dans cartes et inventaire, badges BUTIN, quantités
  reçues dans la fiche. La source est le dernier combat enregistré, y compris après
  changement de destination et reprise. Ce n'est pas un indicateur de lecture :
  aucune fausse promesse de « nouveau/non lu ». Seuls les objets encore possédés
  figurent dans ces vues ; le reçu original reste indépendant des ventes/consommations.
- Recherche d'objets et filtre d'emplacement dans le sac. Les quantités actuelles
  et reçues sont distinctes ; les cartes restent dans la réserve après acquisition.
- Correction de deux unités d'affichage : garde initiale et réduction du premier
  coup sont des coefficients de P, pas des pourcentages.

## Fichiers

`ui/expedition/consumable_build_preview.gd` (nouveau présentateur pur),
`consumable_player_dossier.gd`, `consumable_loot_receipt.gd`,
`consumable_cards_presenter.gd`, `consumable_combat_results.gd` ;
tests `test_consumable_cards_build_preview.gd` et `test_consumable_cards_loot_receipt.gd` ;
scénario `tools/consumable_cards/dossier_capture.gd` et son lanceur.

Le dépôt a reçu en parallèle du travail VFX Convergence. Une référence à
`DamageResult` non qualifiée dans `vfx/class_cards/convergence/facts.gd` bloquait
l'import : seule cette annotation a été corrigée en `DamageResolver.DamageResult`.
Les autres changements de ce travail sont préservés.

## Vérifications

- Première suite arrêtée avant les tests sur cette erreur de type VFX : échec,
  zéro test, ne vaut pas validation.
- Première relance `consumable-v2` : 154 tests exécutés, deux échecs VFX Convergence
  et un test de reçu non chargé à cause d'une annotation de type manquante dans
  mon ajout. Annotation corrigée ; ce rapport n'est pas présenté comme un succès.
- Régressions isolées après correction : **8 tests, 655 assertions, PASS**, sans
  import pendant l'occupation du verrou par l'autre tâche.
  Rapport : `artifacts/dev/20260928-192308-build-readability-regressions-89a64913/report.json`.
- La suite `cards` exécutée en parallèle dans le dépôt a ensuite terminé avec
  **317 tests, 21 298 assertions, aucun échec ni test ignoré**. Rapport strict
  relu : `artifacts/dev/20260928-192012-test-cards-9c8cccfc/gut-strict-report.json`.
  Les derniers ajustements d'agencement sont couverts par les captures ci-dessous.
- Dossier et bilan en 1280×720 et 1600×900 : **28 captures, quatre processus
  réussis, aucune erreur moteur**. Rapport :
  `artifacts/dev/20260928-192725-player-dossier-4512e163/report.json`.
  Contrôles : comparaison pure, retrait/équipement, filtres après restauration,
  recherche vide sans fiche périmée, filtre par emplacement, sources dépliables,
  valeurs de comparaison sur une seule ligne et actions verrouillées en consultation.
- Inspection visuelle effective des comparaisons aux deux tailles, de la collection,
  du filtre butin et du détail des statistiques. Deux itérations ont corrigé une
  comparaison située trop bas puis un retour à la ligne caractère par caractère
  des chiffres. Le détail des statistiques défile automatiquement à son ouverture.
- Format des nouveaux scripts/du dossier/tests et `git diff --check` : réussis.
- Dernière passe après clarification « Bonus de portée » : 18 captures du dossier,
  deux résolutions, **PASS**, aucune erreur moteur. Rapport :
  `artifacts/dev/20260928-193050-build-readability-final-d5000128/report.json`.
  La comparaison 1280×720 a été inspectée à nouveau ; les nombres restent alignés
  et le titre désigne bien le bonus, pas la portée totale de tous les sorts.

Les victoires du scénario visuel sont des fixtures : elles ne prouvent pas un
équilibrage de run. Les valeurs d'équipement proviennent des calculs réels ; le
reçu est consulté sans transaction. La suite CI globale n'a pas été lancée ici.

## Suite du parcours

Restent les liens directs du reçu vers une famille précise, la conservation des
filtres entre fermetures, le résumé de reprise, le glossaire et les réglages de
lisibilité. Ce lot permet déjà de retrouver les gains avec un filtre stable ; il
ne modifie pas l'ordre bilan → notification de niveau → décisions → route.
