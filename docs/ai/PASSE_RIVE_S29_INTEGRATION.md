# Passe-Rive S29 — intégration en cours

28 septembre 2026. Prototype Passage spectral accepté, intégration demandée par l'utilisateur.

- Périmètre : cc2_a05, cc2_r05, cc2_r08 ; corps SE dessiné, autres vues natives correctes avec effacement spectral commun. Ne pas transformer les vues non dessinées en SE.
- Conserver les règles de téléportation, les coûts et les VFX dédiés de Permutation.
- Échelle fixe, ancrage du pied, repos natif aux raccords ; disparition au marqueur de résolution, arrivée après déplacement confirmé.
- Générer les intervalles avec imagegen ; métadonnées et calage dans le moteur, pas de redessin Python.
- Travail parallèle déjà présent dans core/expedition, interface Cartes et vfx/class_cards/class_card_vfx_router.gd : préserver.
- Vérifications prévues : import, suite Passe-Rive, régressions natives et Permutation, vrais lancers base/amélioré, annulation et refus, captures de raccord.
- État final : intégration, revue et validations terminées. Aucun travail obligatoire restant pour cette livraison SE + voile directionnel.
- Atlas : douze poses SE + huit dessins VFX, fichiers et calibration sous assets/characters/PasseRive/sprites_s29 ; lecteur passe_rive_spectral_body.gd. Les autres vues gardent leur corps natif et le même voile/horloge.
- Battle : déplacement visuel instantané pour les cc2 TARGET_CELL sans chemin requis ; arrivée différée protégée par génération, sans réception de ruée. Routeur : le backend possède le voile des blink ; anciens portails retirés uniquement dans ce cas, Permutation dédiée conservée.
- Capture finale : artifacts/dev/passe-rive-spectral-20260928-203312, six lancers réels, 201 contrôles PASS. GIF et planche dans art/source/passe_rive_s29/review.
- Suite passe-rive : artifacts/dev/20260928-203500-test-passe-rive-f7153ef1, 47 tests / 5229 assertions PASS.
- Régression mouvement : nettoyage des fixtures corrigé, relance stricte PASS (17 tests / 101 assertions). Aucun changement de règle pour ce nettoyage.
- Ensemble final : 135 tests distincts / 15 930 assertions PASS, six lancers / 201 contrôles runtime PASS. Dernière relance S29 : huit tests / 937 assertions PASS, déjà inclus dans le total distinct.
- Dossier définitif : art/source/passe_rive_s29/README.md et VALIDATION.md ; empreintes dans review/integration_hashes.json.
- Limite assumée : le pivot dessiné existe en SE uniquement ; les sept autres directions emploient leur corps natif correct et la disparition/réapparition commune. Les directions dessinées supplémentaires restent une production artistique future.
