# Comprendre l'identité d'un sort et mesurer son équilibre

Les faits de référence sont dans [DOFUS](DOFUS.md) et [WAKFU](WAKFU.md). Ce document contient nos déductions et des propositions pour Catabase ; il ne les attribue pas à Ankama.

## 1. Une fiche de dégâts n'est pas une fiche de sort complète

Pour comprendre un sort, il faut pouvoir répondre à ces questions sans combler les trous de mémoire :

| Dimension | Question à résoudre | Pourquoi elle change la décision |
|---|---|---|
| Paiement | Coût fixe, variable, minimum de ressources avant lancement ? | Détermine si une séquence est possible, même avec remboursements. |
| Rendement | Que récupère-t-on, quand, sous quelle condition et quel plafond ? | Distingue économie durable, dépense de réserve et remboursement conditionnel. |
| Ciblage | Qui/case quoi ? Portée min/max, ligne, diagonale, LDV, obstacle ? | Détermine le travail spatial nécessaire. |
| Mode | Le résultat change-t-il sur allié, ennemi, soi, invocation, case vide ? | Un bouton peut offrir plusieurs fonctions exclusives. |
| Mémoire | Position précédente de qui ? Début de quel tour ? Dernier événement de quelle portée ? | Rend l'ordre du tour significatif ; évite des retours imprévisibles. |
| Chronologie | Paiement, état, dégâts, déplacement, remboursement dans quel ordre ? | Deux descriptions similaires peuvent autoriser des combos différents. |
| Déclencheur | À l'entrée, au début du tour, à l'impact, à la mort, au cycle ? | Détermine qui peut encore répondre avant l'effet. |
| Durée | Jusqu'à quelle frontière ? Rafraîchissement, cumul, consommation ? | Détermine si le joueur peut stocker une préparation. |
| Résolution | Critique, armure, résistances, esquive, immunité, dégâts indirects ? | Empêche de convertir le chiffre affiché en promesse de résultat. |
| Échec | Cible morte, destination occupée, support détruit, événement annulé ? | Les cas limites déterminent fiabilité et exploitabilité. |
| Build | Quel passif remplace un effet ou change le ciblage ? Quelle exclusion ? | Le même sort peut avoir un autre rôle selon la spécialisation. |
| Contre-jeu | Comment l'autre camp réduit-il sa valeur ? | Un très gros effet peut rester sain si sa préparation est contestable. |
| Progression | Quand obtient-on l'outil, sa portée utile et son partenaire ? | Un kit amusant à haut niveau peut manquer d'autonomie pendant l'apprentissage. |
| Présentation | Peut-on prévoir destination, victimes, ressources et délais ? | La difficulté intéressante réside dans le choix, pas dans une règle cachée. |

Une propriété inconnue doit rester inconnue. Notre propre modèle de données ne doit pas convertir une absence en valeur zéro, ce que l'on pourrait être tenté de faire avec les plafonds de lancement DOFUS.

## 2. Les familles de décisions révélées par les lectures

### Préparer puis choisir comment consommer

Le Xélor DOFUS possède des outils qui produisent un état spatial et plusieurs raisons de l'exploiter. Le risque d'un système « marque puis attaque renforcée » est d'avoir une seule sortie évidente. Il devient plus intéressant si le même état peut donner des dégâts, un déplacement, un contrôle ou une sécurité, avec des occasions incompatibles.

Pour nos cartes à usage unique, conserver une ressource n'a de sens que si une autre manière de la dépenser est raisonnablement accessible. Une marque qui disparaît avant de pouvoir piocher un consommateur, ou dont le seul consommateur est légendaire, produit de la frustration plus souvent qu'un choix.

### Acheter un moment plutôt qu'un montant

Déclencher plus tôt une protection, un retrait ou une source de PA peut changer la survie d'un tour entier. Un effet différé possède deux prix : la ressource dépensée et l'occasion accordée à l'ennemi. Supprimer le délai exige de revaloriser le second prix, même si le chiffre ne change pas.

Cela s'applique à notre garde : promettre deux petites protections successives diffère d'une grande protection immédiate. Les simulations de run doivent suivre **quand** arrivent les coups, pas seulement additionner défense et attaque sur le combat.

### Changer la cible change la fonction

Une case vide peut créer un objet ; un allié recevoir un bouclier ; un ennemi subir des dégâts. Cela réduit le nombre de cartes nécessaires pour rendre un kit polyvalent. Mais le bénéfice d'interface n'existe que si le mode actif est parfaitement prévisualisé. Sans cela, une carte devient une énigme de description.

Le Pandawa donne un autre exemple : une pièce du plateau sert de centre aux effets. Cette pièce n'est pas un simple buff de statistiques ; sa position crée des possibilités et offre une prise à l'adversaire.

### Transformer une règle plutôt qu'ajouter un pourcentage

Promptitude échange une contrainte de visibilité contre une contrainte d'alignement. Rémanence rend les invocations transparentes aux deux camps. Mage de combat et Flétrissement remplacent une famille d'effets. Ces choix produisent des builds parce qu'ils changent les situations favorables.

À l'inverse, un bonus de dégâts donné à la même ouverture dans toutes les arènes augmente la force du personnage sans nécessairement enrichir sa manière de jouer.

### Défendre un plan, pas seulement des PV

L'Orbe veut que la cible reste intacte. Rempart veut des ennemis au contact. Un support de contrôle peut devoir être protégé plutôt que le héros lui-même. Le joueur répartit donc sa défense entre sa survie et la continuité de son plan.

Une contrepartie comme « −2 PM » dépend aussi du contexte : elle peut être faible sur un réseau d'heures intact et sévère après sa destruction. Un malus n'a pas une valeur universelle indépendante du reste du kit.

## 3. Ce qui peut mal fonctionner

| Risque | Signe observable | Réglage à examiner avant de changer les dégâts |
|---|---|---|
| Ouverture obligatoire | La même séquence domine presque toutes les rencontres | Coût de préparation, autres modes, accès aux bénéfices essentiels, pertinence de l'ennemi |
| Contre trop binaire | Une immunité retire simultanément placement, ressources et dégâts | Prévoir une utilité partielle qui ne contourne pas complètement l'immunité |
| Moteur infini | Un événement paie les conditions de sa propre répétition | Plafond par sort/cible/événement, consommation, provenance des remboursements |
| Coût de build invisible | Un sort fonctionne seulement avec plusieurs passifs imposés | Rendre le fonctionnement de base autonome ; laisser aux passifs une spécialisation |
| Complexité sans décision | Beaucoup de clauses mais toujours un ordre optimal identique | Supprimer les démarches inutiles ; déplacer la difficulté vers des choix de situation |
| Survie retardée mal vendue | Le joueur meurt en pensant avoir déjà la défense annoncée | Séparer gain immédiat et programmé dans la prévision |
| Domination par portée | Une variante fait pareil, plus fort et de plus loin | Différencier géométrie, timing ou risque, plutôt que compter seulement la rareté |
| Sacrifice rentable sans limite | Invoquer puis tuer ses propres pièces génère un excédent | Comptabiliser coût de création, limite d'entités et éligibilité du remboursement |
| Classe utile seulement tard | Plusieurs niveaux avant de pouvoir accomplir sa promesse | Avancer le noyau du kit ; faire progresser ses options plutôt que débloquer tard son existence |

Un plafond ne suffit pas à rendre un combo équilibré : deux usages trop puissants peuvent décider tous les combats. Inversement, un coût élevé ne suffit pas à empêcher une boucle si le système rend davantage de ressources à chaque étape.

## 4. Comment l'éprouver vraiment

Les scénarios suivants sont un **protocole à exécuter dans les clients**, pas des tests déjà passés. Les calculs documentaires exécutés sont séparés dans [CALCULS](CALCULS.md).

| Cas | Situation normale | Cas limite / attaque du contrat | Résultat à relever |
|---|---|---|---|
| Mémoire Gelure | Deux déplacements successifs de la cible | Autre entité déplacée entre-temps | Case historique choisie, différence avec Retour spontané |
| Retour spontané | Une poussée dans le tour Xélor | Marche, déplacement sur cadran puis autre échange | Quels événements remplacent exactement la mémoire |
| Symétrie WAKFU | Même cible, heure paire puis impaire | Case d'arrivée occupée / mur / stabilisé | Entité déplacée, échange ou échec, paiement conservé |
| Pointe + Cours | Échange unique sous Distorsion | Deux échanges déclenchés par une même action | Nombre de remboursements et identité de leur événement |
| Suspension | Geler, dépenser, libérer | Assez de charges pour plusieurs cycles | Ordre, plafonds par tour et événements différés consommés |
| Dévouement | Bénéfice au prochain tour | Cycle accéléré avant le prochain tour | Gain anticipé unique ou réapplication ; durée restante |
| Aiguille | Lancer avec 1, 2, 3, 4 PA | Cible survit, meurt, invocation alliée | Coût réel et remboursement ; interaction Assimilation |
| Martel'heure | Cibles A puis B puis C | Refrapper A, mort de B, B hors portée | Déduplication, mémoire, répétitions et retrait associé |
| Sablier | Deux porteurs proches | Trois états formant un cycle de voisinage | Nombre de visites, consommation et absence de récursion infinie |
| Prémonition | Dégâts inférieurs au seuil puis restauration | Soin, dégâts puis soin, mort, variation exactement 50 % | Définition de variation et dénominateur ; annulation exacte |
| Synchro | TF par déplacement | Application directe de TF, réinvocation par allié | Immunités, quota d'équipe, destruction/remplacement |
| Complice / Régulateur | Mécanisme vivant recevant un coup direct | Dégât indirect, mort du protecteur pendant la chaîne | Ordre et destination du dégât, éventuel reliquat |
| Orbe | Aucun dégât reçu | Coup absorbé entièrement par armure, zéro dégât, perte de PV sans dommage | Définition exacte de « subir des dommages » |
| Immunité | Une fenêtre de protection | Second Féca, dissipation, états d'exclusion | Anti-chaînage par cible et relance par lanceur |
| Terre Brûlée | Entrée puis début de tour | Multiples entrées par poussées ; cible stabilisée | Fréquence du retrait et interaction des deux glyphes |
| Pandawa multi-mode | Soi, allié, ennemi, tonneau, cible portée | État modifié entre sélection et résolution | Branche exacte et coût de chaque mode ; nettoyage des contradictions |

Mesures à conserver pour chaque événement : tour et phase, acteur et cible, PA/PW/PM avant paiement et après remboursement, position avant/après, états et charges, dégâts par bénéficiaire, raison d'échec. Une vidéo seule peut montrer le résultat tout en laissant l'ordre interne indéterminé ; un relevé événementiel permet de reproduire l'analyse.

Pour l'équilibrage PvM, varier les rencontres : cible seule, groupe espacé, groupe dense, boss peu mobile, invocation fragile, terrain encombré, menace urgente. Pour le PvP, ajouter un adversaire qui sait refuser le déclenchement ou détruire la préparation. Ne pas utiliser le même mannequin comme preuve pour les deux contextes.

## 5. Ce que cela change pour notre projet

L'[audit local précédent](../spell_comparison_2026-09-25/AUDIT_ET_PRIORITES.md) distinguait déjà les cartes Godot et le catalogue théorique consommable. Il constatait notamment des verbes partagés entre classes et une majorité d'améliorations V1 centrées sur les dégâts. Ce sont des résultats antérieurs, pas de nouvelles validations moteur dans cette étude.

Les priorités qui se précisent sont les suivantes :

1. **Donner une ressource propre à décider, avec au moins deux débouchés.** Garde à conserver ou convertir ; marque à consommer ou déplacer ; position mémorisée à exploiter ou abandonner. Le débouché alternatif doit être utile dans de vraies arènes.
2. **Séparer l'outil de préparation de sa fréquence économique.** Si poser une pièce consomme une carte, cette pièce peut durer plusieurs actions ; elle n'a pas à redemander la même carte à chaque déclenchement. Sa destruction et son remplacement deviennent alors les coûts à mesurer.
3. **Préserver une voie de fonctionnement avec les drops normaux.** Les sacs rares peuvent ouvrir une autre sortie ou une prise de risque ; ils ne devraient pas être le seul moyen de faire fonctionner l'identité choisie au départ. Cela conserve le drop sur les mobs demandé par le projet.
4. **Compter les copies en plus des PA.** Un finisseur remboursé peut rester précieux parce qu'il évite un coup, tout en ayant un coût de run. Ne pas lui rendre automatiquement sa copie avec ses PA : ce serait une autre économie.
5. **Construire les ennemis pour rendre ces choix visibles.** Une armure en préparation, une cible qui cherche une ligne, un soutien destructible ou une attaque au prochain tour donnent un sens aux outils de protection et de déplacement.
6. **Rendre les prévisions contractuelles.** Afficher la vraie branche, la case mémorisée, les effets futurs et le coût avant remboursement. Le joueur doit pouvoir prévoir les règles avant d'apprendre à les optimiser.

Il ne s'agit pas d'importer toute la complexité du Xélor. La leçon est de faire naître plusieurs décisions cohérentes à partir d'un petit nombre de règles stables, puis de vérifier leurs interactions et leur économie de copies.
