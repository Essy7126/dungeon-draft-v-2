# Lisibilité des cartes — 28 septembre 2026

## Décisions

- Dans les règles V2, une `family` désigne un sort nommé et tous ses exemplaires,
  pas une école élémentaire. L'interface dit **sort**, **carte**, **classe** et
  **rôle**. Elle conserve les identifiants et sauvegardes existants.
- Les quatre classes gardent leurs noms fonctionnels, accompagnés d'une signature :
  Assassin / Lames de l'ombre, Gardien / Rempart de bronze,
  Arpenteur / Chasseur des rives, Thaumaturge / Secrets du Léthé.
  Chaque fiche donne une intention, son bonus exact et une combinaison à essayer.
- Les cartes affichent des valeurs de base calculées avec la Puissance actuelle,
  leurs conditions, leurs durées et leurs zones. Le détail facultatif exprime les
  coefficients en pourcentage de Puissance. Un bonus de 25 % de Puissance n'est
  pas présenté comme +25 % aux dégâts.
- Attaque, protection, déplacement, contrôle, soin, pioche et terrain sont des
  étiquettes descriptives. Feu, eau et givre identifient les effets existants ;
  aucune nouvelle résistance élémentaire ni restriction de classe n'est créée.
- Les calculs de règles restent dans le moteur. `card_player_language.gd` utilise
  la définition effective (améliorations incluses) pour présenter les effets.
  Les textes bruts du catalogue restent disponibles pour les outils internes.

## Parcours

Le départ propose une aide « Comprendre les cartes et les sorts », avec l'exemple
« 3 cartes Estoc = 3 utilisations ». La fenêtre se ferme sans changer la sélection.
Les détails de Puissance et les spécialisations sont consultables à la demande.
La fiche du deck montre en priorité illustration, coût, portée et effet ; le butin
et l'amélioration viennent ensuite. Le survol en combat reste passif et ne couvre
pas la main. Le butin utilise les mêmes descriptions numériques.

## Vérifications

- Sélection finale : `artifacts/dev/20260928-201548-selection-player-language-final-e21fb0e1/report.json`,
  387 contrôles et 39 captures, trois résolutions. Parcours réel jusqu'au transfert
  du deck de départ, ouverture/fermeture du guide et détail de Puissance.
- Combat : `artifacts/dev/20260928-201143-combat-readability-de51a61c/report.json`,
  24 captures ; les 96 formes de carte sont mesurées dans le vrai HUD à deux résolutions.
- Dossier et butin : `artifacts/dev/20260928-201726-player-dossier-8feaf8b8/report.json`,
  28 captures à deux résolutions, dont le détail de sort réagencé.
- Inspection visuelle des captures 1280 × 720 : classe, aide, pourcentages,
  effet dans le deck et survol en combat/butin.
- Suite Cartes V2 : `artifacts/dev/20260928-201741-player-language-tests-3d1e6058/report.json`,
  verdict strict PASS, 180 tests et 10 613 assertions.
- Dernières retouches et fenêtres héritées :
  `artifacts/dev/20260928-202507-player-language-final-regressions-f5298417/report.json`,
  verdict strict PASS, 24 tests et 4 157 assertions (langage, comparaisons, butin,
  descriptions et intégration réelle). Les tests relisent les 96 formes à trois
  valeurs de Puissance et contrôlent les conditions sensibles.
- Formatage vérifié sur les douze scripts concernés ; `git diff --check` propre.

Les validations moteur de cette tâche ont été exécutées sans import et avec des
données utilisateur isolées : une autre tâche détenait le verrou d'import. Elles
ne sont pas présentées comme une validation d'import neuf ou de toute la CI.

Les premières validations ont détecté un conflit avec `RefCounted.reference`,
trois infobulles trop hautes et un faux positif de test (« Sans » confondu avec
la variable « S »). Ces défauts ont été corrigés. L'aide initialement dépliée dans
la page occupait trop de place : elle utilise désormais une fenêtre dédiée.

Limites : les valeurs affichées sont explicitement des bases, pas une prédiction
du résultat sur une cible précise. Ces contrôles ne constituent pas un test de
compréhension avec de nouveaux joueurs ni une nouvelle campagne d'équilibrage.
Les modifications de VFX/combat présentes dans le même checkout appartiennent
à d'autres travaux et ne font pas partie de cette révision de vocabulaire.
