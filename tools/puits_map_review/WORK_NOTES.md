# Passage du puits — première descente

Demande : première map jouable des profondeurs, lave, magma, roche et ossements, selon la DA commune et la pipeline du Léthé.
Décision : reprendre la destination existante du puits route_76ac69bb7c8d (nom historique La sente des oliviers), sans changer ses identifiants, rencontres ni géométrie. Peinture guidée par les 112 dalles réelles ; passage maçonné au pied du puits, corniche de basalte, deux coulées latérales et petits dépôts funéraires. Une seule map.
Fichiers propres : tools/puits_map_review/, assets/catabase/combat/puits_descent_v1/ ; ressources de cette seule destination. Les modifications des tâches parallèles sont conservées.
Validation prévue : import et synchronisation Studio avec empreinte de gameplay avant/après, QA GPU deux formats (support, picking, mouvement/garde), revue visuelle et shader/mouvement réduit.
État : guide produit ; peinture en cours. Baseline conservé artifacts/dev/puits-descent/before/.

Livraison 12/09 : peinture v2 installée, faille parasite v1 corrigée par image_gen. Source 1586x992 conservée ; calibration propre, lave et lumières locales. Géométrie et gameplay inchangés après synchronisation Studio. Premier import sandbox échoué ; relance compte local PASS.
Import/préparation : 20260912-124709-puits-descent-prepare-629405f5.
GPU 2 formats / 20 captures, mouvement/garde, picking 112 cases, support >=38,66 px, animation et mouvement réduit PASS : 20260912-124818-puits-descent-review-477db2d9. Captures 1080p et compact inspectées.
Catalogue : 3 tests / 15940 assertions PASS : 20260912-124956-test-test_unit_test_catabase_route_layouts.gd-43593faa.
Format ciblé PASS (prepare_room.gd, living.gd, bloc ajouté à review.gd). Vérifier le diff courant : review.gd contient aussi le travail Léthé parallèle, conservé.
Suite : retour artistique utilisateur sur cette première salle ; les autres maps, transitions physiques et noms publics du trajet ne font pas partie de cette livraison. Guide d'ouverture et limites dans README.md local.
