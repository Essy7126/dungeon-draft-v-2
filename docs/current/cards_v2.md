# Cartes — Prototype v1 dans Catabase

Choisir **Cartes** au menu, puis **Nouvelle partie**. La galerie existante permet
de choisir l'apparence et de préparer la traversée depuis quatre socles libres :
**Classe**, **Deck**, **Éléments** et **Difficulté**. Chaque socle ouvre une fenêtre
superposée ; une synthèse Cartes reste à droite du personnage illustré.
Préparer quinze copies normales et répartir jusqu'à quatre points élémentaires,
puis **Franchir le seuil**. Les compositions personnalisées sont conservées par
classe durant la préparation ; fermer ou confirmer une fenêtre conserve ses choix.
Échap ferme d'abord l'aide, puis la préparation et restitue le focus au socle.
La préparation reprend la composition de la référence avec ses socles peints,
son personnage illustré, ses cadres et son bouton bronze. Les illustrations
et cadres des cartes conservent leurs assets d'origine ; la synthèse reste à droite.
Le parcours suit ensuite la cinématique, le Seuil des Ombres, les combats et
les haltes de Catabase. Il n'existe plus de troisième variante publique.

## Jouer

Les fenêtres Cartes partagent une matière brune sobre, des champs mats et des
onglets actifs soulignés. Les actions principales utilisent un bouton bronze
clair ; les comparaisons d’équipement distinguent gains et pertes par couleur
et par valeurs avant/après. Les accès du HUD sont nommés **Sac**, **Deck**,
**Stats** et **Carte**. L’[audit des interfaces du 30 septembre](../ai/PLAYER_INTERFACE_AUDIT_2026-09-30.md)
précise les corrections, les parcours testés et leurs limites.

L'interface appelle **sort** une action nommée et **carte** un exemplaire utilisable
une fois dans la run. Les noms techniques `family` et `copy` restent dans les données.
Au départ, les classes présentent leur style, leur bonus et une combinaison à essayer.
L'aide **Comprendre les cartes et les sorts** explique les règles de préparation.
Les fiches affichent des effets chiffrés selon la Puissance actuelle ; **Lien avec
la Puissance** expose les pourcentages à la demande. Les protections et bonus
conditionnels peuvent modifier ces valeurs de base en combat.

- **Sorts & deck** : préparer zéro à trente copies, trois au plus par famille ;
  laisser le reste en réserve ; choisir une copie normale d'ouverture facultative.
  Deux collections distinctes affichent leurs propres exemplaires : **Deck préparé**
  (piochable) et **Réserve** (hors pioche). Les boutons +1/−1 déplacent un exemplaire,
  avec les mêmes limites et sauvegardes que les commandes existantes.
  La fiche reste à droite ; recherche, rôle, affinité et rareté filtrent les deux
  collections sans modifier le deck. Coût, quantité, affinité et rareté sont visibles
  sur chaque pile ; la rareté possède aussi une bordure colorée.
  L'aide **Les familles ?** distingue l'affinité de classe, le rôle, la rareté et
  la famille de sort (tous les exemplaires d'un même sort). L'affinité détermine
  le catalogue de départ, pas une interdiction d'emprunter des cartes en cours
  de run. Chaque composante chiffrée indique ses éléments et leurs poids ;
  ces éléments sont indépendants de l'affinité, du rôle et de la rareté.
- **Caractéristiques / Classe & améliorations** : répartition des maîtrises et
  aptitudes, spécialisation au niveau 4, perfectionnements aux niveaux 4, 8 et 12.
  Les règles précises figurent dans le [contrat Prototype v1](prototype_v1.md).
  **Caractéristiques** ouvre une fiche de consultation compacte : onglets
  **Résumé** et **Détails**. **Répartir mes points** ouvre une autre fenêtre,
  avec choix et aperçu avant confirmation. Fermer abandonne le brouillon non
  validé et revient à la fenêtre d’origine. Les choix de classe restent dans
  **Classe & améliorations**, qui propose aussi un accès à la répartition.
- **Inventaire** : six emplacements d'équipement et deux reliques distinctes.
  La fiche compare les valeurs permanentes avant/après équipement ou retrait,
  précise les plafonds et garde l'action accessible sous le détail défilant.
  Recherche par nom, filtre d'emplacement et filtre **Dernier butin** permettent
  de retrouver les objets encore possédés du dernier combat enregistré.
- Dans **Sorts & deck**, le filtre **Dernier butin** retrouve également les familles
  acquises. Les fiches distinguent quantités reçues et quantités encore disponibles.
  Ces repères restent disponibles après reprise et changement de salle.
- Dans **Caractéristiques**, l’onglet **Détails** présente la base du
  niveau, les aptitudes et l'apport effectif de l'équipement après arrondis/plafonds.
  Les effets conditionnels restent séparés du total permanent.
  Le résumé regroupe ressources, résistances et éléments dans des lignes alignées ;
  les six maîtrises utilisent les mêmes pictogrammes et couleurs que les cartes.
  La fenêtre de répartition sépare **Éléments** et **Aptitudes** en onglets,
  avec aperçu avant confirmation et bouton de validation fixe.
  La main de combat affiche l'affinité de classe et le nom de rareté, un cadre
  de rareté et les symboles élémentaires. L'infobulle nomme les éléments et reste
  passive, hors de la zone de sélection. Les cartes neutres sont indiquées.
- En combat, utiliser la main dans le HUD habituel et cibler sur la vraie carte.
  Une famille ne se joue qu'une fois par tour. Chaque copie jouée disparaît de
  la traversée ; les copies non jouées sont défaussées puis repiochées.
- La main revient à cinq cartes, modifiable par équipement jusqu'à sept.
  L'attaque permanente propre à la classe et la garde de secours restent
  disponibles sans consommer de copie, chacune une fois par tour.
  Conserver une carte exige un effet de rétention. L'ancre, le Relais et les
  choix d'attraction/sacrifice apparaissent dans cette même barre d'actions.
- Aux marchands existants : achats ciblés, sacs, équipement, reliques, soin,
  vente et échange de trois copies normales. La réaffectation d'une amélioration
  se trouve dans la fenêtre de progression. Les stocks et reçus sont persistants.

48 familles et leurs améliorations, quatre classes, huit spécialisations,
24 équipements, dont six sceaux de maîtrise, et huit reliques sont définis dans
`data/cards/consumable_v2/catalog.json`. La route garde ses vingt profondeurs et
ses douze combats. Les sept petites arènes du prototype servent aux tests des
règles ; elles ne remplacent pas les cartes et les décors de la run.

Les nouvelles parties rencontrent aussi la famille squelette : patrouille au
combat 2, puis légion du centurion au combat 5. Le Dialecticien intervient aux
combats 6 et 11 avec son contrôle et ses soutiens. Leurs kits natifs, les budgets
et les invocations bornées sont détaillés dans le [contrat du bestiaire](cards_bestiary.md).
Les parties déjà sauvegardées conservent leur bestiaire initial.

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
sélectionne les règles consommables. Leur champ interne `prototype_revision = 1`
identifie cette progression. Une ancienne partie consommable migre hors combat :
les anciens attributs sont remboursés et les nouveaux budgets deviennent disponibles.
Un combat actif reprend avec ses anciennes valeurs et migre après sa victoire.
Copies, niveaux, XP et équipement sont conservés ; les PV restent proportionnels.
Les variantes Cartes antérieures au moteur consommable gardent leurs règles historiques.

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

Pour le nouveau bestiaire, le checkpoint 3 conserve aussi les renforts,
l'ordre de jeu, les budgets d'invocation dépensés et les annonces natives en
attente. Une reprise n'ajoute ni invocation gratuite ni tirage de butin.

La victoire est enregistrée dès la fin de l'action, avant l'animation de sortie.
Les changements d'équipement conservent le ratio de PV non arrondi, y compris
après rechargement ; alterner deux objets ne procure pas de soin gratuit.

L’aperçu de répartition compare des effets du deck préparé, avec leur distance
explicite et les valeurs avant/après. Il privilégie les effets modifiés et
annonce les limites de cette estimation. Les bonus d’aptitudes restent visibles
même sans variation après arrondi. La réorientation complète exige une
confirmation séparée : elle rend les points, efface la spécialisation et
consomme son usage unique. Annuler ou Échap ne modifie pas la run.

## Vérifier

`./dev.ps1 test cards` inclut les tests de règles et
`test_consumable_cards_integration.gd` : seuil réel, session, vingt étapes,
compatibilité et scène Battle avec consommation/reprise. La suite `all` et les
gates CI restent obligatoires pour les changements du moteur commun.

`./tools/character_selection/verify_cards_preparation.ps1` exerce la sélection
publique à la souris et au clavier, les quatre fenêtres, le deck, les maîtrises
et le transfert de préparation. Il capture Cartes et Classique en 1280×720 et
1920×1080, avec un rendu réel et des données utilisateur isolées. Les captures
doivent aussi être inspectées visuellement.

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
