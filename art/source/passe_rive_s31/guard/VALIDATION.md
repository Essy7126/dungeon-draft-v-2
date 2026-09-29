# Parade — validation du 29 septembre 2026

**Terminée en V1 dans les huit orientations.**

- Suite Passe-Rive : **69 tests / 12 367 assertions PASS**, `artifacts/dev/20260928-235950-test-passe-rive-0d9f1bee/gut-strict-report.json`. Résolution unique à 240 ms, appuis et paume, transformations de l'arc, interruptions et douze poses par vue.
- Combat : **40 lancers / 1 241 contrôles PASS**, `artifacts/dev/passe-rive-guard-cards-20260929-001211/report.json`. n02/g05 base et amélioration, garde de secours, huit directions ; 207 captures. Coût et consommation réels, aucune protection anticipée, une seule riposte sur coup reçu, secours sans carte consommée.
- Présentation : **52 images**, `artifacts/dev/passe-rive-guard-directions-20260928-235649/`. Préparation, paume levée, effet orienté et raccord au repos revus. Captures de combat E, NW, SW et NE inspectées.
- GDScript dédié formaté et vérifié ; contrôle Git des espaces réussi.

Le premier banc de combat (`20260929-000312`) a échoué uniquement sur une attente historique : g05 n'emploie plus l'arc générique. Le banc vérifie désormais son armement dédié, le jeton persistant, sa suppression et une seule riposte. Les effets de production n'ont pas été modifiés pour satisfaire ce test.

L'arc de garde n02/secours garde la taille du SE approuvé, quelle que soit la résolution du nouvel atlas. Contre conserve son effet dédié. Les sources et prompts exacts sont conservés, sans retouche raster par script. Les occlusions du bras dans les vues de dos et de petites variations de contour restent visibles au ralenti ; le banc suspend l'IA et ne constitue pas une run complète.

Médias dans `review/`, chemins de preuves dans `review/provenance.json`.
