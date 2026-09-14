# Camp des compagnons — halte de la voie du puits

Demande : camp improvisé par les anciens tailleurs de roche, références visibles à Hadès et aux profondeurs grecques. Suite de La garde des sources, halte hub existante de profondeur IV ; d04_0 en graine 2401.
Plan préalable et trois gabarits H=18% de l'image. Master Étal du passeur + précédente map joints à image_gen. Trois originaux conservés : correction du relief, Cerbère à trois têtes puis sceptre simple pour éviter le trident généré. Source retenue source-v3.png, 1672x941 ; tous les prompts conservés.
Fichiers propres tools/camp_companions_review/, art/source/halts/companions_quarry_v1/, asset/map/painted/halts/companions_quarry_v1/, data/halts/companions_quarry_v1.json et test/unit/test_companions_quarry_binding.gd. Seul raccord partagé : ajout d'un binding titre exact/hub/profondeur4 dans data/halts/route_bindings.json. Modifications Léthé et autres tâches préservées ; graphe inchangé.
Calibration manuelle des allées, foyer et tabourets interdits, points de repos/départ, flammes et vitrages. Runtime commun des haltes, aucun nouveau service.

Validations du 12 septembre 2026 :
- Atelier GPU : PASS, 281 contrôles, 4 392 échantillons de déplacement, zéro position dangereuse, 52 captures. Rapport artifacts/dev/20260912-132358-halt-verify-5ee50b13/summary.json.
- Production : PASS, 100 contrôles, 8 captures, aucune erreur. Rapport artifacts/dev/20260912-132655-camp-companions-production-4fb8ba59/summary.json. Repos exact de 30% une fois, refus du doublon, sauvegarde/reprise, départ unique et transitions vérifiés sur d04_0.
- Inspection visuelle : atelier 720p et zoom 1080p ; production 1080p et dialogue 720p. Silhouette, passages, mobilier et texte lisibles.
- Raccord du camp : PASS, 2 tests et 588 assertions sur les révisions 2/3/4 et quatre graines ; destinations voisines et graphe préservés. Rapport artifacts/dev/20260912-133054-test-test_unit_test_companions_quarry_binding.gd-0c139207/gut-strict-report.json.
- Une première invocation de la suite générale des haltes n'a pas démarré : moteur déjà réservé par une tâche parallèle (20260912-133219-test-halts-11f3d880). Aucun test exécuté dans ce rapport ; nouvelle exécution avec attente du verrou.
- Première suite générale exécutée : 51/52 tests passent (20260912-133309-test-halts-camp-de56ad9b). Le seul échec est l'énumération historique des trois haltes dans test_painted_halt_runtime.gd. Actualisation chirurgicale pour le quatrième raccord camp, en conservant la stèle et les deux haltes de profondeur VIII ; vérification du format réussie sans réécriture du fichier partagé.
- Essai ouvert : artifacts/dev/20260912-133559-camp-companions-play-8f157475/preview.json confirme d04_0, graine 2401, userdata isolées ; journal LIVING_HALT_READY pour companions_quarry_v1.
- Suite générale finale : PASS, 52 tests, 1 271 assertions, zéro échec et zéro erreur. Rapport artifacts/dev/20260912-133613-test-halts-camp-2538de0e/gut-strict-report.json. Travail terminé ; peinture, navigation, services et raccord vérifiés.
