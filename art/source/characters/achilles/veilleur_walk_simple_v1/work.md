# Marche simple — essai direct

Demande du 12 septembre 2026 : repartir de la planche de premières poses fournie
par l'utilisateur. Une tentative simple, peu d'images, quatre angles et essai Godot.
Cette demande remplace la priorité de chercher un animateur extérieur.

Choix : une seule génération, une planche 4 directions × 8 poses du corps entier.
PNG détourés sans rig ni images interpolées ; réutiliser le laboratoire Godot.
Conserver l'ancien Veilleur ISO rejeté et les modifications des autres tâches.

État : 28 poses intégrées, 7 par direction, 10 images/s. Une seule génération.
Détourage du damier, aucun rig/intermédiaire. Quatre captures GPU inspectées.
Import et 93 contrôles natifs réussis :
artifacts/dev/20260912-162544-veilleur-simple-6b7e1786/summary.json.
Scène WalkSimpleReview.tscn ouverte pour essai ; avis artistique à recevoir.
L'ancien laboratoire à 48 poses reste fonctionnel. Pause, chemin et arrêt vérifiés.
Incident d'import résolu : aperçus WebP exclus avec .gdignore ; type bool explicite
sur `boosted` dans core/expedition/catabase_deck_modifier.gd, seule ligne changée
dans ce fichier en cours d'une autre tâche. Un essai a rencontré le verrou moteur
occupé ; aucune suppression de verrou, relance après libération.
