# Deck : consultation, réserve et actions séparées

## Demande et décisions

Le bouton Deck du HUD ouvrait la classe. La collection présentait simultanément
le deck, la réserve et un inspecteur avec effets, améliorations et commerce.

- L’entrée du HUD et son raccourci K ouvrent `cards` pour les runs Cartes,
  `build` reste la destination classique. Le texte et le nom accessible suivent.
- La collection retire ses onglets globaux de personnage et l’inspecteur fixe.
  Mon deck et Réserve sont deux pages exclusives, avec compteurs séparés.
- Une galerie adaptative, des illustrations plus grandes, les quantités, coûts,
  affinités et raretés permettent de reconnaître les cartes.
- Les filtres avancés sont repliés au départ. La recherche et le tri restent directs.
- Le survol réutilise `spell_hover_card` et le rendu des cartes de combat :
  coûts, portée, effets, mots clés colorés, éléments et quantités. Il est passif.
- Le clic ouvre une fenêtre de lecture. Ses actions sont dans un second onglet.
  Les améliorations, ouverture, suivi et échanges existants restent accessibles.
  Échap ferme cette fiche sans fermer le deck. Un clic sur une autre carte
  repart toujours sur l’onglet de lecture.
- Les transactions, limites de copies, sauvegardes et interdictions en combat
  continuent de passer par les règles existantes. Aucun équilibrage modifié.

## Audit et corrections pendant la passe

Le contrôle visuel a révélé une fiche vide malgré une ouverture correcte :
le conteneur défilant n’avait pas de hauteur disponible. La zone s’étend désormais
verticalement ; le banc vérifie une hauteur utile et des effets non coupés.
Le bouton de retrait avait conservé une largeur de 40 px : corrigé en bouton
sur toute la largeur, avec destination explicite vers la réserve.

## Validation

- Suite `consumable-v2` : **PASS, 219 tests, 20 972 assertions**, import valide,
  aucun diagnostic bloquant.
  `artifacts/dev/20261001-040656-test-consumable-v2-47117e69/gut-strict-report.json`
- Accès du HUD : le nouveau test passe avec le vrai PersistentRunUI et son bouton,
  vérifie la destination, le verrou de combat, l’absence de mutation et le retour
  des contrôles. Le fichier de tests complet est **FAIL, 4/5 tests réussis** :
  son test d’inventaire classique déborde à 960×720 et 1200×720 et attend un autre
  nombre de colonnes. Les assertions n’ont pas été assouplies. Aucun fichier
  de cet inventaire n’a été modifié par cette passe ; pas de preuve baseline
  permettant d’affirmer ici la date d’apparition du défaut.
  `artifacts/dev/20261001-041302-test-test_unit_test_run_interface_access.gd-83009431/gut-strict-report.json`
- Contrôle natif final : **PASS, 52 captures**, 1280×720 et 1600×900, six
  processus terminés sans diagnostic moteur. Les contrôles couvrent les onglets,
  recherche/tri/filtres, absence d’inspecteur permanent, survol passif, ouverture
  au clic, Échap, transferts +1/−1, lecture seule et accès aux actions des 48 sorts.
  `artifacts/dev/20261001-041452-player-dossier-e84320be/report.json`
- Inspection visuelle : galerie 720p/900p, réserve, infobulle de combat, fiche
  et gestion séparée. Les effets se lisent, les commandes restent atteignables.
- Formatage ciblé avec conservation de structure et `git diff --check` : PASS.

Verdict : accès Deck corrigé et surcharge de consultation réduite. Pas de blocage
reproduit dans ces parcours ; le défaut distinct d’inventaire classique reste ouvert.

Les captures sont des fenêtres réelles sur une session isolée. Elles ne sont
pas une preuve d’équilibrage ni une run complète. Le test HUD utilise un contexte
de combat contrôlé ; il valide le routage et les verrous, pas l’IA des ennemis.
