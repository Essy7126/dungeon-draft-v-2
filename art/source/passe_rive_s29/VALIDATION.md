# Validation S29 — 28 septembre 2026

Toutes les lignes ci-dessous ont un rapport strict PASS, sans erreur moteur. Les huit tests S29 sont déjà inclus dans les 47 tests Passe-Rive ; leur dernière relance ne doit pas être additionnée au total.

| Suite | Tests | Assertions | Rapport |
|---|---:|---:|---|
| Passe-Rive (S19, S24–S29) | 47 | 5229 | [Rapport](../../../artifacts/dev/20260928-203500-test-passe-rive-f7153ef1/gut-strict-report.json) |
| Mouvement commun | 17 | 101 | [Rapport](../../../artifacts/dev/20260928-204116-test-test_unit_test_unit_movement_presentation.gd-61e855bf/gut-strict-report.json) |
| Récupération des sorts | 6 | 32 | [Rapport](../../../artifacts/dev/20260928-203745-test-test_unit_test_spell_visual_recovery.gd-7e8fa4ab/gut-strict-report.json) |
| Permutation | 18 | 428 | [Rapport](../../../artifacts/dev/20260928-203825-test-test_unit_test_consumable_cards_permutation_vfx.gd-6f78c14b/gut-strict-report.json) |
| Animations natives | 13 | 6589 | [Rapport](../../../artifacts/dev/20260928-203904-test-test_unit_test_passe_rive_autosprite.gd-794c15e3/gut-strict-report.json) |
| VFX communs | 34 | 3551 | [Rapport](../../../artifacts/dev/20260928-203957-test-test_unit_test_class_card_vfx.gd-287274ca/gut-strict-report.json) |
| S29 après nettoyage des fixtures et formatage | 8 | 937 | [Rapport](../../../artifacts/dev/20260928-204157-test-test_unit_test_passe_rive_s29.gd-56604ef1/gut-strict-report.json) |

Total sans compter la relance S29 deux fois : **135 tests, 15 930 assertions**.

Capture finale : [rapport des six lancers et 201 contrôles](../../../artifacts/dev/passe-rive-spectral-20260928-203312/report.json), [provenance](review/provenance.json), [GIF](review/passage_spectral_en_jeu.gif), [raccords](review/raccord_en_jeu.png).

## Contrôles et limites
- Trois cartes × normal/amélioré : un seul marqueur, aucune position modifiée avant résolution, corps absent au marqueur, vrai déplacement, réapparition confirmée, coût de deux PA et consommation correcte, retour natif.
- Téléportation au-dessus d'une case bloquante ; refus sur destination occupée sans départ ni consommation. Permutation échange effectivement les deux occupants.
- Tests du backend sur huit vues, annulation, retard de frame, absence de déplacement, mort, désactivation, échelle constante à trois tailles de profil et ancrage des douze poses.
- Corps nouvellement dessiné SE seulement ; les sept autres directions conservent leur propre sprite natif avec le voile et l'horloge S29.
- Revue humaine par l'agent des captures : pied, stature, visibilité, disparition des portails en doublon, réapparition ; les variations de dessin ne sont pas assimilées à une identité parfaite.
- La fixture utilise une vraie scène de combat avec main préparée et IA suspendue ; pas de certification de toutes les salles ni de la run entière.
- Formatage : cinq fichiers ciblés contrôlés, aucun formatage global. git diff --check ciblé sans erreur d'espacement.

## Échecs conservés et corrections
- 20260928-202356 : import dans le compte restreint bloqué par le magasin de certificats Windows et trois sous-dossiers ; zéro test, donc aucun succès annoncé. Relances Godot autorisées hors du compte restreint.
- 20260928-202455 : un test supposait qu'un cast actif pouvait être remplacé ; le contrat refuse correctement cette action. Test corrigé pour vérifier le refus, puis annuler avant le nouveau cast.
- 20260928-203027 : commande refusée par le verrou moteur pendant la capture ; relancée après sa fermeture, aucun contournement du verrou.
- Première capture 20260928-202854 : six lancers mécaniquement corrects, mais anciens portails trop présents. Correction du propriétaire VFX et nouvelle capture finale sans doublon.
- Mouvement 20260928-203608 : assertions passées, fermeture stricte en échec avec quatorze ressources conservées. Les fixtures possèdent désormais le nettoyage dispose_grid déjà utilisé ailleurs dans les tests. La relance 20260928-204116 est strictement verte. Aucun seuil d'erreur n'a été assoupli.
- Le formateur a refusé structurellement une longue expression preload(...).MovementBattleFixture.new(). Son extraction en constante a permis le formatage avec vérification de structure et la dernière relance S29.

[Empreintes des fichiers d'intégration à la clôture](review/integration_hashes.json). Les travaux parallèles sur les autres cartes et interfaces ne sont pas validés par cette campagne.
