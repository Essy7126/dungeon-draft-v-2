# Caverne suspendue — 13 septembre 2026

Demande : une caverne mystérieuse, étrange, avec un silence audible. Préférences
antérieures : gratuit, peu artificiel, sans aigus stridents, musique discrète.

Base CC0 JaggedStone, Loopable Dungeon Ambience, récupérée sur OpenGameArt.
Recette `tools/audio_workshop/build_cavern_ambience.py` : vitesse 82 %, filtrage
large, respirations lentes, pics des gouttes arrondis, raccord de six secondes.
Sortie 109 s, -30 dBFS RMS, -17,76 dBFS crête ; fichier et provenance dans
`assets/audio/catabase/ambience/`. Aperçu de 40 s dans artifacts/audio/cavern_v1.

Intégration : `core/audio/cavern_ambience.gd`, bus Ambience, entrée progressive
2,5 s, phase initiale variable. -3 dB au Seuil (activation par sa scène),
-6 dB dans les combats peints via CombatAudio. Pause/coupure/fermeture nettoient
ou suspendent le lecteur ; autres haltes inchangées sans activation explicite.

Validation finale : les 10 contrôles WASAPI indépendants des contrôleurs de
production passent, sans erreur moteur (signal mesuré, raccord, coupure/reprise,
nettoyage). `./tools/audio_workshop/verify_cavern.ps1` ; rapport :
`artifacts/dev/20260913-093735-cavern-audio-20f7dc95/summary.json`.

Le parcours réel confirme les 6 contrôles de caverne au Seuil, crête 0,0658,
mais échoue ensuite à la porte (timeout) :
`artifacts/dev/20260913-093103-production-audio-a300bdc1/flow-report.json`.
Ne pas présenter cette exécution comme une validation du parcours complet.
Suite élargie : 104 tests, 97 réussis, 7 échecs dans test_catabase_threshold et
test_painted_halt_catabase (initialisation de l’inventaire de run et préparation
de haltes ; voir les piles d’appels). Les deux tests de caverne et les tests
audio de combat et de nettoyage des haltes passent.
Rapport : `artifacts/dev/20260913-092424-test-audio-e49f91f8/gut-strict-report.json`.
Le premier parcours réel a révélé que l’ajout dans le JSON du Seuil invalidait
son manifest_sha256 de préparation. Correction : JSON restauré, activation par
la scène après préparation via `ambience.enable_cavern()` ; accès au Seuil vérifié.
Suite relancée après correction : 104 tests, 99 réussis, 5 échecs d’inventaire/
sauvegarde restants, dans `artifacts/dev/20260913-092848-test-audio-9841f1e3/`.
Les nouveaux tests de caverne et les tests audio existants passent.
Le GameManager porte aussi des modifications simultanées ; ne pas les réécrire
pour faire passer les tests audio.
Premier essai GUT bloqué par le type inféré de WeakRef dans le test ; type explicité.
Préserver les modifications simultanées (Charon, défis, animations, menu).
