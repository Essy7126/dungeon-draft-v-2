# Audit de la run Cartes après pull — 23 septembre 2026

État étudié : `ad1f4c58`, arbre de travail propre au début. Comparaison avec
`569fc474` (salles) et `9af4a96a` (avant les deux lots). Périmètre : run Cartes,
départs, cartes, salles, adversaires, preuves de validation. Aucun changement
des règles du jeu pendant cet audit. Les défauts de salles décrits ci-dessous
étaient déjà présents dans notre implémentation : le pull ne les a pas introduits.

## Conclusion

Les départs ont gagné une identité tactique tangible. Le problème principal
n'est plus le manque de techniques initiales : c'est la faible couverture des
rencontres particulières, leur articulation avec les monstres et la mesure de
leur difficulté. Le deckbuilding reste principalement une sélection de sorts
qui interagissent avec les positions et les états ; les cartes modifient encore
peu la circulation du deck lui-même.

## 1. Ce que le pull améliore réellement

- Sélection de classe et de cinq techniques avant le départ ; transmission
  du choix au jeu, sans seconde composition au seuil.
- 28 initiations distinctes, sept par classe ; 21 sélections de cinq familles
  possibles par classe, chacune doublée pour former dix cartes.
- 112 familles publiques : par classe, 7 initiations, 15 communes, 4 rares,
  2 épiques. Les anciennes `s_*` restent lisibles en sauvegarde mais ne sont
  plus proposées dans le catalogue public.
- VFX remaniés : impacts, déplacements, surfaces, états et intentions différées
  sont reliés aux faits de combat. Un essai des réservoirs après pull confirme
  que le nouveau deck et les indicateurs d'état cohabitent avec le panneau de salle.
  Cela ne vaut pas inspection visuelle des 112 compositions.

Exemples des nouveaux départs, normalisés à 20 Prouesse, sans armure, passif,
critique ni équipement :

| Classe | Combinaison | Coût et effet |
|---|---|---|
| Assassin | Faille furtive → Lame opportuniste | 3 PA ; 3 dégâts puis 9 + 7 si marqué ; exige d'arriver au contact pour la lame |
| Gardien | Rempart d'apprenti → Heurt sous couvert | 4 PA ; 15 garde puis 10 + 7 tant que la garde subsiste |
| Arpenteur | Pas d'éclaireur → Tir d'escarmouche | 3 PA ; déplacement jusqu'à 2 cases, puis 9 + 6 si au moins 2 cases parcourues ce tour |
| Thaumaturge | Tracer le sceau → Réveiller le sceau | 3 PA ; 3 dégâts puis 9 + 7 si marqué, portée jusqu'à 3 |

Le Gardien possède désormais poussée et attraction dès l'initiation : cela
renforce directement ses interactions avec la presse, l'anneau et les réserves.
Les nombres ci-dessus ne sont pas les dégâts complets du héros réel : les
passifs et sa Prouesse effective doivent être ajoutés pour une mesure de combat.

Sources : `core/expedition/class_starter_catalog.gd`, `class_card_catalog.gd`,
`class_card_modifier.gd`, `ui/selection/cards_character_setup.gd`.

## 2. Priorité haute : les salles spéciales ne structurent pas encore chaque run

Mesure du graphe réel, en parcourant tous les chemins pour les graines
0, 1, 42 et 2401 : **minimum 0, maximum 3 salles spéciales sur les 12 combats**.
Ce résultat n'est pas un échantillon de quatre parties : les bornes sont calculées
sur tous les chemins du graphe de chacune des quatre graines.

- Bloc 2–6 : rester sur Airain donne la forge ; rester sur Léthé donne le
  sablier ; Styx ne donne aucune de ces deux salles. Forge et sablier s'excluent.
- Bloc 8–10 : seul Léthé donne le jardin.
- Bloc 12–15 : Styx donne le convoi, Airain les réservoirs ; Léthé aucun.
  Convoi et réservoirs s'excluent.
- Après le refuge 16, aucune nouvelle salle de ce catalogue aux étapes 17–20.

Exemple de chemin sans ces salles : Styx dans le premier bloc, Airain dans le
deuxième, Léthé dans le troisième. Les rencontres normales conservent leurs
propres sorts et intentions ; « zéro salle spéciale » ne signifie pas zéro mécanique.

**Conséquence :** enrichir le catalogue de cinq entrées ne garantit pas cinq,
ni même une, rencontres de ce type au joueur. Recommandation : garantir une
rencontre à règle spéciale dans chaque grand bloc, avec des variantes selon
la branche. Conserver le choix du contre-jeu plutôt que le choix implicite entre
une salle particulière et une rencontre ordinaire.

Sources : `core/expedition/catabase_route_v6.gd:135`,
`core/expedition/card_tactical_room_catalog.gd:4`.

## 3. Priorité haute : désigner explicitement le chef de chaque rencontre

Les règles prennent l'ennemi initial ayant le plus de PV maximum comme chef.
Cela produit actuellement, en difficulté normale, graine 42 :

| Salle | Chef réellement choisi | Autre acteur significatif |
|---|---|---|
| Forge | Brute du portique, 90 PV | Rejeton de braise, 36 PV |
| Sablier | Brute du portique, 120 PV | Officiant des oboles, 72 PV |
| Jardin | Molosse dévoreur, 146 PV | Conducteur de la chasse, 109 PV |
| Convoi | Molosse dévoreur, 187 PV | Collecteur d'oboles, 140 PV ; deux porteurs, 94 PV chacun |
| Réservoirs | Un des deux Rabatteurs, 227 PV | Fondeur des Enfers, 113 PV |

Dans le convoi, le Collecteur est donc lui-même un porteur qui avance vers
l'autel ; il ne pilote plus son kit normal tant que l'autel reste ouvert.
Les livraisons soignent et renforcent le molosse. Le journal mentionne pourtant
encore le Collecteur lorsque le sceau est fermé.

**Recommandation :** identifier le chef par un rôle ou identifiant de rencontre,
puis définir précisément quels acteurs portent une âme. Ne pas faire dépendre
ces responsabilités d'un rééquilibrage de PV ou de l'ordre des unités à égalité.
Critère de validation : le Collecteur reçoit toujours les livraisons, et seuls
les porteurs désignés remplacent leurs attaques par une marche.

Sources : `core/expedition/card_tactical_room_rules.gd`, fonctions `bind`,
`begin_enemy_turn`, `_advance_convoy`.

## 4. Priorité haute : les sondes d'équilibrage ne jouent pas ces règles de salle

`tools/catabase_run_balance_validation/full_run_probe.gd::_fight_continuous`
construit bien la nouvelle grille avec `make_room`, mais instancie ensuite sa
propre boucle : `TerrainEffects`, `SpellCaster`, `EnemyAI`, `TurnQueue`.
Elle n'instancie ni la scène `TacticalRoomBattle` ni ses règles locales.
La sonde des classes hérite de ce chemin.

**Conséquence vérifiée dans le code :** une simulation peut parcourir la bonne
géométrie sans presse, anneau, livraisons, croix ou charges. Ses victoires ne
mesurent donc pas la difficulté actuelle de ces rencontres publiques.
Les tests de sauvegarde injectent également certaines victoires ; ils vérifient
la progression, pas la capacité d'un build à battre les ennemis.

**Recommandation :** partager le cycle des règles de rencontre entre la scène
et la sonde. Enregistrer dans chaque résultat l'identifiant de salle, les
déclenchements, charges, livraisons et dégâts de mécanisme. Exiger un test de
parité avec la scène avant de publier un taux de victoire ou un équilibre de classes.

## 5. Priorité moyenne : l'IA ne connaît pas les objectifs propres à ces salles

Les zones dangereuses sont calculées dans `danger_cells()` et dessinées par
l'overlay ; elles ne deviennent pas des dangers du terrain pour l'évaluation
de l'IA. Celle-ci consulte les effets de grille et leurs poids de danger.
De même, aucune intention spécifique ne lui demande de défendre un réservoir
ou d'éviter la croix verrouillée. Le siphon est déclenché si un ennemi se trouve
déjà au bon endroit.

Il est intéressant de pouvoir piéger un monstre ; il est moins profond que tous
les monstres ignorent systématiquement la règle. Recommandation : profils
différenciés, par exemple brute téméraire, artilleur prudent et voleur attiré
par une réserve chargée. Ne pas rendre tous les ennemis omniscients ou parfaits.

Sources : `core/enemy_ai.gd:495`, `core/ai/support_mage_terrain.gd`,
`core/expedition/card_tactical_resource_rules.gd`.

## 6. Priorité moyenne : différencier résolution, difficulté et identité des salles

Les cinq mécanismes cessent à la mort du chef ; le reste du combat redevient
ordinaire. Cela encourage partout la même priorité de cible. Ce n'est pas un
blocage technique, mais un risque d'aplatissement du contre-jeu.
Charon demeure un atelier autonome, pas un miniboss intégré à la route.

Les dommages de mécanisme sont fixes, tandis que cartes et ennemis progressent :

- Forge : 60 dégâts bruts représentent 67 % des 90 PV de la brute ; le rejeton
  n'a que 36 PV. Un placement réussi peut donc peser davantage que plusieurs cartes.
- Sablier : 32/48 dégâts représentent 27/40 % des 120 PV du chef.
- Jardin : 28 dégâts représentent 19 % des 146 PV du chef, mais l'anneau ne
  touche justement pas son origine ; il faut comparer aux cibles réellement exposées.
- Réservoir plein : 132 dégâts bruts, soit 58 % des 227 PV du chef, mais au
  prix de 6 PA investis + 1 PA de décharge, du délai et du risque de vol.

Ces ratios ignorent les défenses : ce ne sont ni des dommages garantis ni des
preuves de facilité. Il faut mesurer tours, PV perdus, PA investis, siphons et
choix du joueur au niveau réel de chaque étape avant d'ajuster ces valeurs.

Le jardin, le sablier et les réservoirs utilisent exactement les mêmes sept
rangées de terrain. Les règles changent, mais pas leur topologie. La passe suivante
devrait fournir des parcours propres : abris pour la croix, deux ailes disputées
pour les réserves, plusieurs origines intéressantes pour l'anneau.

## 7. Priorité moyenne : approfondir la circulation du deck et les premiers gains

Le catalogue exporté contient 112 familles et 29 étiquettes d'effet. Une étiquette
n'est pas une mécanique complète : portée, coût, classe et combinaisons comptent.
Cependant, les branches d'effets des cartes concernent surtout dégâts, états,
déplacements, garde et surfaces. Elles n'ajoutent pas de cartes jouables dont
l'effet central soit piocher, récupérer de la défausse, épuiser volontairement
une carte ou retenir plusieurs cartes. Conservation et recomposition existent
comme commandes communes du système, pas comme moteurs de builds variés.

Le début reste aussi dépendant des drops : profondeur 1, combat normal,
sans sécheresse préalable, les deux chances sont 49 % et 16 %.
La probabilité théorique de zéro carte est donc 0,51 × 0,84 = **42,84 %**.
L'export actuel observe 123 cas sans carte sur 300 tirages de ce scénario ; ce
n'est pas un taux de victoire. La mémoire des combats sans carte améliore ensuite
les probabilités, sans transformer le premier gain en choix garanti.

Recommandations à prototyper : une première décision de carte garantie ; puis
quelques cartes liant vraiment plateau et deck, avec limites explicites :
« après une poussée effective, pioche 1, une fois par tour », ou « épuise cette
carte pour reprendre un déplacement de la défausse ». Ce sont des propositions,
pas des effets actuellement implémentés.

## Validation et limites

- Catalogue courant exporté dans
  `artifacts/dev/20260923-132816-audit-post-pull-catalog-a686d2cf/` :
  112 familles, 29 étiquettes d'effet, 7 200 tirages de butin, sortie 0, stderr vide.
- Graphe et statistiques exportés dans `artifacts/dev/audit_post_pull_20260923.json`.
  Exécution valide via scène :
  `artifacts/dev/20260923-133103-audit-post-pull-route-scene-725ebad8/`, sortie 0,
  marqueur `AUDIT_POST_PULL_PASS`, stderr vide. Le premier lancement via
  `--script` avait des erreurs d'autoload ; il ne sert pas de preuve de succès.
- Réservoirs : deux cycles réels, stockage, décharge et scénario de coup fatal
  réussis après pull ; capture 1280×720 réellement inspectée, stderr vide :
  `artifacts/dev/20260923-133032-audit-post-pull-reservoir-48fdaee5/`.
  Le mode d'exercice affiche +1 000 PV de test ; le scénario terminal place le
  chef à 1 PV après la capture. Cela vérifie les mécanismes et la fermeture,
  pas l'équilibrage d'une run au niveau 13.
- `./dev.ps1 test cards -TimeoutSeconds 1800` : **PASS, 93 tests et 8 882
  assertions**, import inclus, aucune erreur dans le rapport strict
  `artifacts/dev/20260923-132627-test-cards-fcbf4051/gut-strict-report.json`.
- `./dev.ps1 test test/unit/test_catabase_tactical_rooms.gd` : **PASS, 11 tests
  et 192 assertions**, import inclus, aucune erreur dans le rapport strict
  `artifacts/dev/20260923-133507-test-test_unit_test_catabase_tactical_rooms.gd-25f1513d/gut-strict-report.json`.
- La suite Catabase complète n'a pas été relancée aujourd'hui ; aucune conclusion
  de validation globale du dépôt n'est tirée des deux suites ciblées.
- Le résultat Catabase resté en cours hier existe maintenant : 566 tests,
  échec global avec 18 tests en échec et erreurs moteur. Rapport historique
  `artifacts/dev/20260922-152613-test-catabase-aded9c86/summary.json` ; il ne
  constitue pas une validation ni un diagnostic automatique du nouveau commit.

Ordre de travail recommandé : chefs explicites et couverture de route ; parité
des sondes ; intentions ennemies liées à la salle ; mesures de difficulté ;
ensuite nouveaux moteurs de deck et nouvelles rencontres. Ajouter seulement
des salles supplémentaires laisserait ces limites en place.
