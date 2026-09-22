# Salles créatives — run Cartes

Base : prototype Charon existant, audits de comparaison conservés. Travail demandé :
construire des salles plus créatives. Réponse explicite : **intégration directe à
la run Cartes**. Le développement a été adapté à cette réponse.

Trois contraintes : forge à presse détournable, jardin à anneau mobile, convoi à
intercepter. Géométries originales 9 × 7 et règles visibles, quatre classes et moteur
réel de cartes. Projections Arena Studio, aucun changement des règles communes.

Fichiers : core/expedition/card_tactical_room_* ; battle/tactical_rooms ;
tools/tactical_rooms pour les essais de la scène réelle. Fabrique de salles et
aperçus de route adaptés ; aucun changement de graphe canonique ou fingerprint.
Charon retrouve son implémentation initiale, indépendante.

Cartes à écosystème actif, route r6 : forge à 5/airain, jardin à 8/lethe, convoi à
12/styx. Pack, difficulté, XP et récompenses conservés. Le chef de salle est
l'ennemi initial aux PV max les plus élevés ; aucune nouvelle fiche de monstre.
Les porteurs du convoi remplacent leur activation par la marche tant que l'autel
est actif, et retrouvent leurs sorts lorsque le sceau est fermé.

Premier test ciblé : PASS 5 tests / 85 assertions,
artifacts/dev/20260922-141321-test-test_unit_test_catabase_tactical_rooms.gd-6a77a46f.
Première capture arrêtée : l'essai Studio sans déploiement place les unités mais
ne démarre pas le combat ; le lanceur de capture appelle désormais le démarrage.
## Résultats finaux

- `./dev.ps1 test test/unit/test_catabase_tactical_rooms.gd` : **PASS**, 7 tests,
  104 assertions, aucune erreur ; import réussi. Rapport
  `artifacts/dev/20260922-144015-test-test_unit_test_catabase_tactical_rooms.gd-63dea256/gut-strict-report.json`.
  Inclut sauvegarde/restauration des aperçus, invariance du graphe canonique,
  limitation à trois destinations Cartes, accessibilité des spawns, vrais murs
  bloquant les tirs, oboles/âmes, contrôle du chef et paiement des commandes.
- `./dev.ps1 test catabase -TimeoutSeconds 1800` : **FAIL**, 542/560 tests réussis,
  18 échecs dans les tests existants ; 76 371 assertions réussies sur 76 574.
  Rapport `artifacts/dev/20260922-141949-test-catabase-f37d1e5f/gut-strict-report.json`.
  Échecs sur illustrations, sélection, Seuil, contenus historiques et inventaire
  de reliques. Erreur runtime de salle nulle dans `test_catabase_selection_launch`
  et erreurs de nettoyage en fermeture. La nouvelle suite de cinq tests présents
  au lancement passe dans cette exécution. Les deux tests ajoutés ensuite sont
  couverts par l'exécution ciblée finale. Les échecs larges ne sont ni masqués ni
  réparés dans cette tâche ; pas de déclaration de non-régression globale.
- `./dev.ps1 test terrain -TimeoutSeconds 1800` : **FAIL**, 192/194 tests réussis.
  Échecs : `test_04_every_final_entry_is_placeable` (9 au lieu de 8) et
  `test_update_real_encounter_candidate_preserves_odyssey_room_without_mutation`
  (snapshot Odyssey différent), plus erreurs de nettoyage du Studio.
  Rapport `artifacts/dev/20260922-143419-test-terrain-c66aabf5/gut-strict-report.json`.
- Format ciblé des nouveaux scripts ; `git diff --check`. Aucun assouplissement
  des suites ou des gates CI. Aucun commit créé.

## Contrôles graphiques et runtime

Captures réellement inspectées, scènes publiques avec main de quatre cartes,
commandes cliquées par le scénario puis activation ennemie et retour au héros :

- Forge 1280 × 720, piliers finaux :
  `artifacts/dev/20260922-143651-tactical-forge-final-1280x720-b1dc4eca/room.png`.
- Jardin 1200 × 896, piliers finaux :
  `artifacts/dev/20260922-144109-tactical-garden-final-1200x896-cc341c30/room.png`.
- Convoi scellé 1200 × 896 (avant correction visuelle des piliers) :
  `artifacts/dev/20260922-143327-tactical-convoy-runtime-1200x896-6c531ddc/room.png`.
- Convoi actif 1280 × 720, piliers finaux, étourdissement et ordre des tours :
  `artifacts/dev/20260922-144238-tactical-convoy-turn-order-final-1280x720-36b2b9b4/room.png`.

Ces exécutions ont terminé avec code 0 et stderr vide. Le scénario `--exercise`
ajoute 1 000 PV uniquement au personnage de prévisualisation : il vérifie la
continuité du runtime, pas l'équilibrage. L'essai initial au niveau 1 dans le
jardin est mort face au pack de l'étape 8 ; ce n'est pas une partie au niveau
normal de cette destination. Les PV renforcés sont affichés dans la dernière
capture. Aucune modification des statistiques de la run normale.

Corrections issues des contrôles : obstacles Studio explicites pour les piliers
(un terrain non praticable seul était projeté comme trou), cadrage au-dessus de
la main et à droite des commandes, panneaux défilants, coût via `spend_ap`,
respect des verrous de combat, terrains/statuts avant marche du convoi et délai
d'activation évitant la réentrance qui affichait le nom du porteur après son tour.

## Limites et suite

Intégration directe terminée ; rendu modulaire, pas de nouvelle peinture.
Les anciennes recherches et Charon restent présents. Les échecs des suites
larges restent ouverts. Pas de partie humaine complète ni de validation de
difficulté aux niveaux réels. Priorité suivante : mesurer le recours aux leviers,
le nombre de porteurs interceptés et les dégâts de salle sur des builds réels.
