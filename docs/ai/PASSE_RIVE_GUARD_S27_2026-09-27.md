# Passe-Rive — Garde S27

Demande : poursuivre l’intégration du prototype dessiné Sceau de parade.

## État de l’implémentation

Le backend public Passe-Rive rend un atlas dédié de douze poses pour `cc2_n02`, `cc2_g05` et `cc2_fallback_guard`. Durée 720 ms, libération 240 ms. Les autres orientations gardent le repos natif ; la source dessinée est SE uniquement. Échelle et palette fixes sur tout le geste.

L’arc de bronze est confirmé par le routeur après gain réel de protection. Contre préparé ne frappe pas au lancement. La garde de secours emprunte son vrai chemin sans exemplaire consommé. Règles, coûts, effets persistants et autres gestes conservés.

## Fichiers

- `characters/achilles/2d/passe_rive_guard_body.gd`, `passe_rive_s19_backend.gd`, `passe_rive_card_bindings.gd`.
- `vfx/class_cards/passe_rive_guard_ward.gd`, ajout ciblé dans `class_card_vfx_router.gd`.
- `assets/characters/PasseRive/sprites_s27/` et [sources / preuves](../../art/source/passe_rive_s27/README.md).
- `test/unit/test_passe_rive_s27.gd`, attentes S19/S26 mises à jour, suite locale étendue.
- `tools/class_card_vfx/passe_rive_s27/`, support des secours dans le banc commun `passe_rive_assignments.gd`.

## Validation

Premier passage : 32 tests, 3930 assertions PASS. Formatage ciblé de neuf scripts et contrôle d’espaces Git passés. Le routeur contient des modifications parallèles ; seul notre ajout est mis en forme, sans reformatage global.

La capture initiale a passé ses 206 contrôles mais son journal comportait des erreurs de chargement de l’interface ajoutée en parallèle : elle reste exclue de la validation finale. Les tentatives de test refusées par le verrou moteur n’ont exécuté aucun test. Le lanceur S27 attend désormais le verrou, réimporte puis capture.

Capture finale `artifacts/dev/passe-rive-garde-20260927-214503/report.json` : **PASS**, 5 lancers, 205 contrôles, 95 captures dont 79 images du film. Import et moteur sans erreur. Revue du raccord au repos effectuée ; douze poses vues, taille constante, hash atlas inchangé. La riposte fonctionne seulement au premier coup reçu, le secours ne consomme pas de carte. GIF final et provenance dans le dossier de travail `outputs/passe_rive_garde_S27/integration_review/`.

Aucune run complète, orientation manquante ou retouche anatomique 3D déclarée validée. Le prototype dessiné, les intervalles et les vérifications en combat sont terminés pour cette version SE.
