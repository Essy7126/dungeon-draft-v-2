# Sorts habituels et défis — décision du 12 septembre 2026

Le joueur rejette le prototype de deck. Retour aux sorts équipés et à leur
progression, avec les récompenses, caractéristiques et équipements du jeu.
Retirés : choix de familles, main, pioche, conservation, Ferveur, catalogue de
cartes, éditeur de deck et ajustement de caméra associé. Les surcharges de
statistiques et dangers automatiques ajoutés par ce mode ont aussi été retirés.
Les compositions et techniques ennemies travaillées avant cet essai subsistent.

## Ce qui reste jouable

Avant chaque combat d'une nouvelle partie, accepter un défi ou refuser :

- Gagner en cinq tours, puis six à partir de la profondeur III.
- Déplacer un ennemi deux fois, par poussée ou attraction effective.
- Éteindre un sceau accessible avant la fin du tour quatre, pour 2 PA à une case
  maximum. Ce choix est proposé seulement lorsqu'une position accessible existe.

Réussite : au prochain combat, Achille reçoit un bouclier de 10 % de ses PV max.
Échec : le premier ennemi reçoit un bouclier de 10 % de ses PV max.
Chaque bouclier dure deux activations de son porteur. La conséquence est consommée
au prochain combat, même si une halte les sépare. Refuser un défi n'entraîne aucune
pénalité de durée. Il n'y a plus d'augmentation automatique liée au nombre de tours.

La faveur de conservation de carte devient ainsi un bouclier, indépendant des sorts.
Un petit suivi de défi et le sceau remplacent la grande interface du deck ; aucun
sort n'est ajouté ou retiré de la barre d'actions pendant le combat.

## Reprise des parties

Les sauvegardes du prototype conservent le chemin parcouru, les PV, la progression,
l'inventaire et les conséquences déjà acquises, puis utilisent le kit normal.
Leur collection de cartes n'est plus utilisée ni réécrite. Une Alerte 2 déjà
enregistrée devient exceptionnellement un bouclier ennemi de 20 %, consommé une fois.
Les anciennes sauvegardes sans défis restent compatibles. Comme auparavant,
quitter pendant un combat reprend à son entrée, pas au milieu d'une action.

## Prochaine réflexion, sans nouvelle implémentation

Direction souhaitée : donner une identité propre aux sorts, puis ajouter à côté
des reliques permanentes (bonus ou interactions durables) et des reliques éphémères
(usage unique, effet limité à deux tours, etc.). Leur acquisition, leurs limites
et leurs interactions restent à concevoir avec le joueur. Aucun nouveau système
de reliques n'a été ajouté lors de ce retrait.

## Validation

- `artifacts/dev/challenge_regression/gut-strict-report.json` : **PASS**, 40 tests,
  3 866 assertions, aucune erreur. Défis, migration, parcours guidé, récompenses,
  carte et fiabilité des sauvegardes. Analyse stricte des nouveaux journaux et du
  JUnit, avec réutilisation de l'import recovery validé de cette passe.
- `artifacts/dev/20260912-180434-test-test_unit_test_catabase_challenges.gd-4a0114fe/` :
  import recovery et suite isolée, **PASS**, 7 tests et 61 assertions. La lecture
  JSON réelle de la sauvegarde est incluse ; une erreur de conversion numérique
  détectée au premier essai a été corrigée avant cette validation.
- `artifacts/dev/challenge_capture/report.json` et `runtime.log` : combat réel,
  sortie 0 sans erreur moteur. Quatre sorts habituels présents avant/après un
  lancement de Garde d'airain, PA 6→4 et bouclier 10. Trois captures à 1280×720 ;
  inspection visuelle de la barre de sorts et du suivi de défi.

La suite globale Studio/3D qui avait échoué et dépassé quinze minutes pendant
l'essai précédent n'a pas été relancée ici. Aucun succès global de CI n'est revendiqué.
