# La garde des sources — suite du puits

Demande du 12 septembre : reprendre cette destination comme deuxième map du trajet du puits, à la suite du Pied du puits validé.
Destination existante route_9c104c2158d3, d03_1 pour graine 2401. La liaison d02_0 → d03_1 existe. Préserver graphe, identifiants, combats et données des tâches parallèles.
Direction : même arcade côté arrivée, poste de garde désaffecté, deux sources de magma latérales, lave en bordure, ossements modestes. Géométrie : 185 dalles conservées, guide exporté avant peinture. Référence maîtresse originale jointe avec la première map pour le raccord.
Fichiers propres : tools/puits_sources_review/, assets/catabase/combat/puits_sources_v1/, ressources de cette destination. Baseline artifacts/dev/puits-sources/before/.
Prévu : peinture, calibration manuelle des matières/rives, sauvegarde Studio avec empreinte de gameplay, revue GPU 2 formats et catalogue. État : génération en cours.

Point de contrôle 13:03 : source unique générée et conservée. Premier import échoué sur un WebP Spine en cours, relance PASS (20260912-125955-puits-sources-prepare-532231da). Première QA GPU automatisée PASS mais revue visuelle REFUSÉE : découpe héritée de l'ancien land_polygon et liseré brun. apply.py corrigé pour peindre tout le canevas et désactiver combat_ground_band. Cette QA initiale ne vaut pas validation artistique finale. Nouvelle préparation/revue en cours.

État final visuel : seconde préparation PASS 20260912-130225-puits-sources-prepare-7deccd2b ; revue GPU finale PASS 20260912-130328-puits-sources-review-80d44c16. 185 dalles, marge rive 36,65 px, deux sources/torche animées, sol immobile, réduction des mouvements et proportions entre résolutions PASS. Les captures après mouvement/garde en 1080p et 1200x896 ont été inspectées : fond entier corrigé, combat et HUD lisibles. Format ciblé des trois GDScripts PASS ; diff --check propre.
Catalogue en cours de test. Le pilote open.ps1 sélectionne d03_1, graine 2401, session isolée. Aucun changement du graphe ou de la première map.

Livraison : catalogue PASS, 3 tests / 15940 assertions sans erreur (20260912-130436-test-test_unit_test_catabase_route_layouts.gd-78739ff5). Aucun travail requis restant pour cette map ; essai isolé lancé. Prochaine étape éventuelle : retour utilisateur sur la peinture et choix de la troisième destination.
