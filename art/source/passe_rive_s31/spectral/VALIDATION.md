# Passage spectral — validation du 29 septembre 2026

**Terminé en V1 dans les huit orientations.**

- Suite complète : **75 tests / 15 697 assertions PASS**, `artifacts/dev/20260929-010533-test-passe-rive-fa27b3ef/gut-strict-report.json`.
- Combat : **48 lancers / 1 265 contrôles PASS**, `artifacts/dev/passe-rive-spectral-cards-20260929-010802/report.json`. Trois cartes × base/amélioration × huit directions, plus rejet d'une destination occupée. 192 captures. Marqueur invisible, aucune avance de mouvement, arrivée réelle, échange de la seconde unité, aucun trajet interpolé, coûts et consommation réels.
- Présentation : **58 images**, `artifacts/dev/passe-rive-spectral-directions-20260929-005433/`. Préparation, effacement, retour et raccord revus sur huit vues. La confirmation y est simulée sans déplacement ; le banc de combat constitue la preuve du déplacement.
- Revue combat : disparition de Permutation NW, retour d'Au-delà du front NE et images de réapparition de Bond spectral SE. Les effets dédiés aux deux sites de Permutation sont conservés ; aucun portail générique supplémentaire pour a05/r05.
- Cinq scripts dédiés formatés et vérifiés ; contrôle Git des espaces ciblé réussi.

Deux essais de suite ont été rejetés : le premier ne chargeait pas le nouveau test (variable Vector2 non explicitement typée) ; le second réutilisait une instance après sa mort. Fixture corrigée, départ de chaque action vérifié. Le test ciblé a ensuite passé 2 tests / 2 219 assertions (`20260929-010340-test-test_unit_test_passe_rive_spectral_directions.gd-c1159c5f`), puis la suite complète ci-dessus a réussi.

Les sept vues complémentaires partagent des poses corrigées de Prélèvement selon un montage propre au Passage spectral. Le SE et le voile approuvés restent inchangés. Les limites de contour, l'amplitude modeste du pivot et la portée du banc sont détaillées dans README.md. Médias et provenance sous `review/`.
