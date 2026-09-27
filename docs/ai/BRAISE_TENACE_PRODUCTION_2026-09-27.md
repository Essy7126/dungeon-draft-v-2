# Braise tenace — production

Suite autorisée par « Ok on passe au vfx suivant ». Choix du projet E,
prochain recommandé dans le lot E–H ; planche existante conservée. Run Cartes
consommable actuelle, `cc2_t02` normal/amélioré uniquement.

Charbon facetté et fissuré, impact vermillon/crème, signe de braise compact.
Un seul signe par brûlure ; pulse uniquement au vrai dégât de brûlure, retire
le signe à expiration/mort. La vapeur appartient à la case d'eau dynamique
réellement transformée, avec sa propre durée. Aucun feu sur case sèche.

Décisions : atlas Blender originaux, mêmes exports Studio vérifiés que les
pilotes précédents. Branche dédiée du routeur ; ajout du `status_id` déjà
supporté par le moteur aux faits périodiques du profil Cartes (sans modifier
le calcul des dégâts). Preuves pré-impact pour les cibles tuées. Reprise des
états compacts sans rejouer le projectile.

Reprise demandée : « continue l'intégration ». Les 39 poses originales sont
rendues, assemblées et reproduites depuis le fichier Blender sauvegardé ;
comparaison RGBA PASS. Quatre exports Studio : pixels et durées PASS.
Rapports sous `artifacts/dev/class_card_vfx/braise/`.

Tests ciblés : 18 tests, 440 assertions, PASS,
`artifacts/dev/20260927-213435-test-test_unit_test_consumable_cards_braise_vfx.gd-94f03573/`.
Ils couvrent les deux ticks, la distinction brûlure/terrain/saignement,
réapplication sans cumul visuel, dégâts absorbés, mort, refus, impact létal,
vapeur normale/améliorée, restauration des signes et rail compact.
Deux essais précédents bloqués à l'import ne sont pas des validations :
accès Windows refusé puis atlas S27 concurrent en cours d'import. Aucun
contrôle n'est ignoré ; relance après résolution, avec accès local autorisé.

Première capture complète : 180 images, 441 contrôles PASS, dont commande
publique, sauvegarde/reprise après le cast puis au milieu de la brûlure et
bilan sauvegardé. Inspection des images : correction du libellé technique
« Cc2 Burn » et des chiffres verts en « Brûlure » ambrée ; saignement distinct.
La dernière pulsation continue pendant l'extinction du signe. Ces corrections
sont incluses dans la capture et la suite Cartes finales ci-dessous.

La revue rapproche les deux activations
pour montrer les pulses, via le véritable runtime Cartes ; l'IA est maintenue
immobile. Les PV sont remis au maximum normal entre les deux exemples.
Git comporte les productions précédentes et des modifications concurrentes
préservées ; aucun commit ni changement de règles demandé.

## Clôture de l'intégration

- Capture finale : **PASS**, 180 images, 441 contrôles, processus terminé
  le 27 septembre à 19:58:10 UTC, aucune erreur moteur. Deux reprises disque,
  commande publique, coûts, consommation, dégâts, durées et bilan contrôlés.
  `artifacts/dev/class_card_vfx/braise/combat/report.json` et
  `capture_manifest.json` (28 sources sélectionnées inchangées après tests).
- Suite Cartes : **PASS**, 281 tests, 19 431 assertions, dont les 18 tests du
  fichier Braise avec les corrections de texte et de dernière pulsation.
  `artifacts/dev/20260927-215814-test-cards-a6cfcc5f/summary.json`.
- Contrat des textes flottants : **PASS**, 6 tests, 47 assertions.
  `artifacts/dev/20260927-220715-test-test_unit_test_combat_feedback_contract.gd-00b7d27b/summary.json`.
- Suite Terrain élargie : **FAIL**, 189/194 tests réussis, 11 451/11 461
  assertions. Échecs de catalogue, récupération transactionnelle de l'éditeur
  et snapshot Odyssey ; erreur d'index dans le test de récupération et fuites
  de fermeture Studio. Rapport complet conservé :
  `artifacts/dev/20260927-220804-test-terrain-c236cbd4/gut-strict-report.json`.
  Les cinq identifiants en échec figurent déjà dans le rapport antérieur
  `artifacts/dev/20260927-144950-cards-corrections-all-4a582337/gut-strict-report.json`.
  Le JUnit antérieur a aussi été lu pour les trois tests de récupération.
  Ces échecs restent ouverts : ni modification de l'éditeur, ni réduction
  des assertions, ni déclaration de réussite globale Terrain.
- Atlas et fichier Blender toujours conformes aux empreintes de provenance.
  Format des cinq scripts dédiés vérifié ; `git diff --check` ciblé passe.

L'aperçu `artifacts/dev/class_card_vfx/braise/combat/braise.gif` contient
180 images natives, 6 secondes : détail puis caméra normale. Libellé ambré
« Brûlure », seconde pulsation et reprise HUD inspectés sur captures. Les
captures précédentes incorrectes ne constituent pas des preuves finales.
`final_validation.json` distingue explicitement intégration réussie et
suite Terrain en échec. Aucun son dédié ni validation d'équilibrage.
