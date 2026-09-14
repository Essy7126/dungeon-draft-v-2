# Intégration musicale — 12 septembre 2026

Demande : intégrer les huit nouveautés du panneau d’écoute, gratuitement.
Décision : choix au titre, Passage of Time par défaut, volume initial 50 % sur
fichiers adoucis en niveau. Préférences séparées de la sauvegarde d’expédition.

Fichiers : core/audio/title_music_catalog.gd, title_soundtrack.gd,
ui/menus/title_music_controls.gd, ui/titre_ecran.gd, ui/TitreEcran.tscn,
assets/audio/title/ ; build_title_music.py et manifest.json pour la provenance.
Respecter les travaux simultanés sur le décor du titre et les animations.

Vérification terminée : 4 tests / 64 assertions, puis 88 contrôles du parcours
WASAPI avec les huit pistes, la coupure du volume, les crédits et quatre sorts.
Rapports :
- `artifacts/dev/20260912-100955-test-test_unit_test_title_music.gd-ed7b62f6/gut-strict-report.json`
- `artifacts/dev/20260912-101310-production-audio-e2949c95/summary.json`

Captures titre et crédits inspectées. Le scénario ouvre la liste par `show_popup`
et déclenche son signal natif de sélection ; la simulation du clic sur cette
fenêtre hors écran ne la gardait pas ouverte. Crédits et parcours suivant testés
par pointeur. Les huit signaux Music sont non nuls et modérés ; le lecteur du
titre est libéré avant le combat. Pas d’appréciation auditive automatisée.
Premier essai : 63 assertions réussies, contrôle de disposition échoué car GUT
utilise une racine headless de 64 × 64. Mesurer dans un SubViewport de 1280 × 720.
Le panneau se place après calcul de sa taille minimale. Rapports dans artifacts/dev.
