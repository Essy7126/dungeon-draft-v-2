# Coup de pied haut — validation du 28 septembre 2026

**Intégration terminée pour les huit orientations.** SE approuvé conservé, sept vues dessinées supplémentaires, sans miroir ni remplacement neutre. Cartes : Heurt, Repousser, Choc de masse.

- Suite Passe-Rive : **59 tests / 7 015 assertions PASS**, `artifacts/dev/20260928-222614-test-passe-rive-58c2bea2/gut-strict-report.json`.
- Après correction graphique finale NE/NW : **3 tests / 916 assertions PASS**, `artifacts/dev/20260928-224105-test-test_unit_test_passe_rive_kick_directions.gd-08e5c3eb/gut-strict-report.json`. Ils sont inclus dans les 59, pas additionnés.
- Combat final : **24 lancers / 496 contrôles PASS**, `artifacts/dev/passe-rive-kick-cards-20260928-223821/report.json`. Trois cartes, base/amélioration, quatre orientations de mêlée légales ; copie, PA, résolution unique, absence de dégâts précoces, direction et retour natif vérifiés. 150 captures, dont le film SE.
- Présentation finale : **49 images**, `artifacts/dev/passe-rive-kick-directions-20260928-223621/`. Les huit vues du même geste sur fonds clair/sombre, échelle doublée pour inspection. Horloge commune, impact 310 ms, aucun redimensionnement par pose.
- Quatre nouveaux GDScript : format et structure vérifiés. Contrôle des espaces Git sur les fichiers suivis concernés : PASS.

## Revue visuelle

Repos, préparation, impact et retour revus. Silhouettes correctement orientées ; capuche et dos NE/NW redessinés pour rejoindre la caméra native. Contact lié au talon ; régions mesurées sans couper les membres. Palette et stature fixes, fin sur le repos natif désarmé. Cette revue valide une V1 directionnelle utilisable.

Des différences de contour et de modelé subsistent entre dessins et repos, visibles au ralenti ou pendant les fondus courts. Huit positions temporelles ne constituent pas 60 dessins/s. Le contact ne s'adapte pas anatomiquement à toutes les tailles de monstres. Les règles de poussée restent souveraines. Le banc prépare une main et suspend l'IA, il n'est pas un parcours complet du menu.

## Itérations conservées

- Premier test de groupe : 58/59 passaient ; un ancien test exigeait encore l'absence du coup en NW. Contrat remplacé par la vérification de la nouvelle vue ; échec conservé sous `20260928-222258-test-passe-rive-e02292a8`.
- E/W v01 trop tournés ; v02 corrigés, puis v03 retire le fermoir de l'épaule cachée W.
- Premier SW dans le mauvais sens, exclu ; v02 reprend seulement le repos natif SW.
- Premiers NE/NW trop vus de dos ; v02 retenue depuis les repos natifs. Cellule 3 remplacée par la chambre du genou pour éviter une disparition de la jambe.
- S/N : cellule 2 changeant de jambe écartée. Aucun script ne repeint les pixels source.

Les captures précédentes restent des diagnostics datés. Médias finaux sous `review/`, sources et prompts sous `sources/`.
