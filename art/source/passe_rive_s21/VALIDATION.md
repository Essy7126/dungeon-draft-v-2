# Validation S21 — 26 septembre 2026

## Résultats finaux

| Contrôle | Résultat | Preuve |
| --- | --- | --- |
| Suite Cartes | 101 tests, 10 145 assertions, aucune erreur | `artifacts/dev/20260926-123518-test-cards-c42f1035/summary.json` |
| Contrats ciblés Passe-Rive | 7 tests, 1 245 assertions | `artifacts/dev/20260926-123150-test-test_unit_test_passe_rive_s19.gd-669e0cec/summary.json` |
| Essai natif locomotion | PASS, huit orientations de repos, huit trajets réels de 1/3 cases, un virage, trois sorts ; 26 captures fixes et séquence de captures à 12 ips | `artifacts/dev/passe-rive-s21-20260926-123331/report.json` et `locomotion_samples.json` |
| Partie avec IA | PASS : huit sorts, trois déplacements, trois fins de tour, victoire, sauvegarde et reprise du reçu avec Passe-Rive | `artifacts/dev/passe-rive-s20-flow-20260926-124539/appdata/s19_flow_report.json` |
| Métadonnées | `build_s21_data.py --check` conforme | Régions JSON et constantes GDScript reproductibles depuis PNG et guides conservés |
| Source Blender | SHA256 inchangé | `b8916301e855af9cebca2a6c42f6e3f10cdc128f5b992467d5700bb2f87c4650` |
| Format et différences | Fichiers GDScript modifiés conformes, aucune erreur `git diff --check` sur le périmètre | Vérification après les corrections |

Le nom historique `s20-flow` est celui du lanceur ; ce dernier parcours utilise bien `PR_LOCOMOTION_SE` et `PR_LOCOMOTION_NE`, en plus des sprites des sorts S20.

## Inspection visuelle

Les planches retenues ont été comparées aux guides Blender : contact gauche, passage, contact droit, passage opposé. Les captures de combat inspectées montrent les deux appuis distincts, les vues avant/arrière, les bras abaissés mains libres et le maintien de la même taille au repos et en marche. Le personnage se déplace réellement sur le sol de la scène ; les preuves ne se limitent pas à une animation en place.

Lecture image par image ou en boucle des captures natives : `artifacts/dev/passe-rive-s21-20260926-123331/review.html`.

Les 440 entrées du rapport natif incluent l'enregistrement des images : ce ne sont pas 440 évaluations artistiques. La qualité perçue du cycle reste à juger dans l'arène avec l'utilisateur ; les limites de dessin et de transitions sont listées dans README.md.

## Essais rejetés et réparations

- Premier atlas SE rejeté avant intégration : le contact opposé était remplacé par une quasi-garde.
- Premier import : textures encore non importées et annotation `Vector2` manquante dans le rendu de respiration. Zéro test exécuté, donc non validé. Corrigé avant les essais finaux.
- Premier audit de déplacement : le fixture des sorts désactivait le HUD, mais la demande de déplacement de production attend son port. L'option HUD est maintenant activée pour l'audit S21 seulement ; la logique de déplacement partagée n'a pas été modifiée. Rapport avec erreurs rejeté.
- Deux parcours IA ont atteint la victoire puis échoué dans l'audit sur la référence `current_scene` libérée. Un essai intermédiaire de recherche par script exact ne trouvait pas la scène dérivée et a été arrêté. L'audit recherche désormais une Battle vivante dans l'arbre et prend en charge ses scènes dérivées. Le parcours final complet est celui cité plus haut et ne comporte aucune erreur moteur.

Aucun résultat de ces essais incomplets n'est utilisé comme preuve de réussite finale. Les sauvegardes de test résident dans des APPDATA isolés ; la sauvegarde de l'utilisateur n'est pas utilisée.
