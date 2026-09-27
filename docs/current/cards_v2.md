# Cartes — règles consommables dans Catabase

Choisir **Cartes** au menu, puis **Nouvelle partie**. La galerie existante permet
de choisir l'apparence, la classe, quinze copies normales et la difficulté.
Le parcours suit ensuite la cinématique, le Seuil des Ombres, les combats et
les haltes de Catabase. Il n'existe plus de troisième variante publique.

## Jouer

- **Sorts & deck** : préparer zéro à trente copies, trois au plus par famille ;
  laisser le reste en réserve ; choisir une copie normale d'ouverture facultative.
- **Classe & améliorations** : attributs tous les deux niveaux, spécialisation
  au niveau 4, améliorations de famille aux niveaux 4, 8 et 12.
- **Inventaire** : six emplacements d'équipement et deux reliques distinctes.
- En combat, utiliser la main dans le HUD habituel et cibler sur la vraie carte.
  Une famille ne se joue qu'une fois par tour. Chaque copie jouée disparaît de
  la traversée ; les copies non jouées sont défaussées puis repiochées.
- La main revient à cinq cartes, modifiable par équipement jusqu'à sept.
  Les deux gestes de secours restent disponibles sans consommer de copie.
  Conserver une carte exige un effet de rétention. L'ancre, le Relais et les
  choix d'attraction/sacrifice apparaissent dans cette même barre d'actions.
- Aux marchands existants : achats ciblés, sacs, équipement, reliques, soin,
  vente et échange de trois copies normales. La réaffectation d'une amélioration
  se trouve dans la fenêtre de progression. Les stocks et reçus sont persistants.

48 familles et leurs améliorations, quatre classes, huit spécialisations,
18 équipements et huit reliques sont définis dans
`data/cards/consumable_v2/catalog.json`. La route garde ses vingt profondeurs et
ses douze combats. Les sept petites arènes du prototype servent aux tests des
règles ; elles ne remplacent pas les cartes et les décors de la run.

Les combats 4, 5, 6, 8, 9 et 11 portent leurs mécanismes sur ces mêmes décors :
presse, sablier, jardin, convoi et réservoirs. Les zones orange annoncent les
impacts ; les repères turquoise indiquent les leviers, socles, autel et réserves.
Les commandes apparaissent dans la main et exigent de rejoindre le mécanisme
ou une case adjacente. Une commande de salle est possible par tour.
Les porteurs livrés renforcent leur chef et perdent leur butin ; les sceller
ou les neutraliser avant livraison conserve une possibilité de le récupérer.
La pression à partir de la fin du tour 9 retire directement des PV, sans
consommer la garde. Pâris passe définitivement en phase 2 à la moitié de ses
PV, y compris sur une brûlure ou un saignement ; son intention déjà annoncée reste due.

## Sauvegarde

Le mode Cartes continue d'utiliser `user://catabase_cards_v1.json` et le format
ExpeditionSession. Le champ explicite `ruleset_id = catabase_cards_consumable_v2`
sélectionne les nouvelles règles. Les anciennes parties restent lisibles sous
leurs règles initiales, sans conversion implicite ni effacement.

Les actions du héros sauvegardent l'état de la vraie Battle : main, copies
consommées, PA/PM, PV, garde, positions, usages, statuts, intentions et surfaces. Une reprise ne
repasse pas par le déploiement. Pendant la résolution ennemie, une interruption
revient à la dernière décision complète du héros ; elle ne restitue pas les
copies déjà jouées. Une erreur d'écriture bloque les nouvelles commandes et
affiche **Réessayer** dans la main.

Les mécanismes sont aussi sauvegardés : commande dépensée, rail, croix,
charges, sceau, sacrifices et bonus du convoi. Les anciens checkpoints intégrés
sans mécanisme restent repris avec leur main et leurs ressources ; ils
initialisent le mécanisme à cette décision, sans rejouer les tours antérieurs.

La victoire est enregistrée dès la fin de l'action, avant l'animation de sortie.
Les changements d'équipement conservent le ratio de PV non arrondi, y compris
après rechargement ; alterner deux objets ne procure pas de soin gratuit.

## Vérifier

`./dev.ps1 test cards` inclut les tests de règles et
`test_consumable_cards_integration.gd` : seuil réel, session, vingt étapes,
compatibilité et scène Battle avec consommation/reprise. La suite `all` et les
gates CI restent obligatoires pour les changements du moteur commun.

`./tools/consumable_cards/verify_integration.ps1` vérifie le départ public,
joue une carte dans la vraie Battle puis capture les fenêtres existantes en
1280×720 et 1600×900, avec sauvegardes utilisateur isolées. Le bilan capturé
utilise une fixture de victoire ; seul le test de Battle vérifie la fin réelle
d'un combat. Ces contrôles ne mesurent pas l'équilibrage d'une partie complète.

`test_consumable_cards_live_rooms.gd` vérifie les six rencontres, leurs commandes
et reprises, les sacrifices après Stase, les butins perdus, la formation et
la transition périodique de Pâris. `audit_live_integration.ps1 -Capture`
monte les douze scènes et capture les six mécanismes sur la grille existante.

Les anciens `consumable_cards_run.gd`, `consumable_cards_battle.gd` et leur écran
isolé restent des harnais de référence. Ils n'orchestrent plus le parcours public.
Leurs résultats ne prouvent pas l'intégration de Battle. Le
[suivi du 27 septembre](../ai/CARTES_INTEGRATION_RUN_2026-09-27.md) distingue les
exécutions nouvelles de l'[audit historique du prototype](../audits/cards_v2_integration_2026-09-26.md).
