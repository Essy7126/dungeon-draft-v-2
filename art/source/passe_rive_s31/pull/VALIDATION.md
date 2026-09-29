# Ramener au front — validation du 28 septembre 2026

## Résultats mécaniques

- **62 tests / 7 839 assertions PASS**, suite Passe-Rive : `artifacts/dev/20260928-230849-test-passe-rive-5f28e163/gut-strict-report.json`. Les trois tests directionnels ajoutés sont inclus dans ces totaux. Ils contrôlent les huit orientations, les appuis fixes, les sockets de main sous transformation de scène, la résolution unique même après un grand pas temporel et les interruptions.
- **16 lancers réels / 427 contrôles PASS** : `artifacts/dev/passe-rive-pull-cards-20260928-231451/report.json`. Ramener au front normale/améliorée dans huit orientations ; PA, copie consommée, aucune attraction ni perte de PV précoce, poing ramené à la résolution, déplacement réel et récupération.
- Carte inchangée : portée 2–3, attraction de 1/2 cases. Une cible diagonale reste attirée sur l'axe choisi par le moteur. Le lien suit ce résultat réel.
- Captures de présentation finales : `artifacts/dev/passe-rive-pull-directions-20260928-231758/`.
- Quatre GDScript dédiés : format et structure vérifiés ; contrôle des espaces Git des fichiers suivis concernés réussi.

## Revue visuelle

Caméras, stature, palette, appuis et main examinés dans le lecteur Godot puis en combat. Fermoir W et changement de bras SW corrigés dans les sources. Point de main NW et placement W repris après la première capture. Huit textures directionnelles explicites, SE approuvé conservé ; aucun miroir. Le repère orange des captures de présentation est une aide de contrôle absente en jeu.

Les contours et l'amplitude du contrepoids varient légèrement selon les vues dessinées. Les fondus de raccord restent perceptibles au ralenti. La cible n'est déplacée visuellement qu'après confirmation du combat ; l'animation ne corrige pas la règle d'axe des attractions diagonales. Le banc prépare une main et suspend l'IA, il ne représente pas une run entière depuis le menu.

## Diagnostics conservés

Premier banc de combat interrompu sur une variable de cellule non typée : `artifacts/dev/passe-rive-pull-cards-20260928-231213/`. Corrigé puis repris entièrement ; aucune réussite déduite de cette tentative.
Première présentation avant ajustement W/NW : `artifacts/dev/passe-rive-pull-directions-20260928-230533/`.
Sources retenues, essais écartés, prompts exacts et médias de revue : dossiers `sources/` et `review/`.
