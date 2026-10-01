# Le socle commun à toutes les créations futures

Proposition de conception, non intégrée. Référence jouable :
[Prototype v1](../../current/prototype_v1.md).

## Décision principale

Construire un langage commun d'effets, de coûts et de sources, puis un
laboratoire branché sur les règles existantes. La profondeur future vient de
l'association de ces effets avec les maîtrises, la grille, les objets et la
route. Les combinaisons élémentaires ne deviennent pas des classes cachées
ni des conditions d'accès à des transformations prédéfinies.

Quatre couches à distinguer :

| Couche | Question | Autorité proposée |
|---|---|---|
| Échelle | Quelle quantité de base au niveau atteint ? | Courbes de P et de PV versionnées ; profils ennemis indépendants |
| Orientation | Quelles composantes renforcer ? | Six maîtrises ; aptitudes dans le budget existant |
| Comportement | Qu'arrive-t-il, où, quand, et après quel événement ? | Carte, forme, passif, équipement ou relique ; mêmes primitives |
| Accès | Puis-je préparer et maintenir cette stratégie ? | Possession, copies, offres, prix, route et checkpoints |

La puissance P existe déjà comme échelle automatique. Elle ne doit pas devenir
une caractéristique universelle à investir qui concurrence les six éléments.
Une croissance chiffrée du personnage et des constructions ouvertes peuvent
coexister : P règle l'échelle, les investissements règlent la direction.

## 1. Les fondations statistiques à fixer en premier

| Grandeur | Unité / périmètre | Recommandation de départ |
|---|---|---|
| P du joueur | Base par niveau, pas points achetables | Garder la courbe v1 ; versionner une extension seulement après les essais d'acte |
| PV de base | Base par niveau | Suivre le rapport PV/P et les soins entre salles ; évolution cohérente avec les menaces |
| Six maîtrises | Points investis → points de pourcentage de composante | Garder +3/+2/+1 pendant les premiers lots ; toujours distinguer points et bonus d'équipement |
| Aptitudes | Rangs ; bonus sur un périmètre précis | Trois points existants ; Vitalité, Protection, Contact, Distance. Soin/Persistance restent futurs et financés dans ce budget |
| PA / PM / main | Actions, cellules, cartes visibles | 4/3/5 de base ; aucune croissance automatique pour l'acte II expérimental |
| Défense physique / magique | Réduction du canal | Conserver les règles actuelles et leur plafond de 40 % ; tarifer le gain marginal effectif |
| Garde | Quantité absorbable, source, échéance | Conserver plafond 2,5 P et expiration ; suivre production utile et garde perdue |
| Copies | Stock physique de run et stock préparé | Départ 15, plafond préparé 30, trois copies par famille ; mesurer le stock par fonction |
| Quantités utilitaires | Cellules, cartes, activations, cibles | Nombres explicites ; ne pas augmenter la poussée ou la pioche par maîtrise sans effet déclaré |
| Déclencheurs | Occurrences avec portée temporelle | Quota par source, cible, tour, combat, acte ou run ; origine et remise à zéro explicites |

Ces lignes ne sont pas dix nouveaux attributs à montrer au joueur. Ce sont les
dimensions que le calculateur et l'auteur de contenu doivent connaître.

À différer : critique, précision/esquive, vitesse/initiative comme nouvelles
caractéristiques investissables, pénétration générale et résistances à six
éléments. Leur ajout peut être utile plus tard ; il n'est pas nécessaire pour
créer dès maintenant des choix de cadence, de stock et de placement.

Les bonus généraux de dégâts déjà présents dans des objets restent possibles.
Un bonus général, un bonus de distance et une maîtrise ne valent pas le même
budget à quantité égale : portée d'application, concurrence d'emplacement et
fréquence d'usage changent leur valeur.

## 2. Une formule commune, une provenance conservée

Pour une composante originale j :

`brut_j = P_niveau × coefficient_j × (1 + Σ_e poids_j,e × maîtrise_e + bonus_applicables_j)`

Chaque distribution élémentaire d'une composante chiffrée somme à 1. Les
conditions peuvent ajouter une autre composante, avec ses propres poids.
Les bonus compatibles sont additionnés dans leur périmètre. La résolution
applique ensuite défense, garde, PV disponibles et arrondi selon le contrat
du moteur. L'aperçu et l'exécution doivent appeler les mêmes fonctions.

Trois familles de quantités à déclarer :

- **Originale** : le coefficient définit une quantité à valoriser, comme
  dégâts directs, brûlure, garde ou soin.
- **Dérivée** : elle vient d'un résultat déjà valorisé. Exemple : convertir
  40 de garde en dégâts ; ne pas appliquer la maîtrise une seconde fois.
- **Fixée par règle** : passif ou relique à coefficient P explicite, avec ses
  bonus autorisés. Ne pas le faire hériter silencieusement de ceux de la carte.

Drain : distinguer dégâts calculés, absorption et PV réellement retirés.
Un ennemi à 4 PV ne finance pas un soin de 30 via un impact de 30. La quantité
de soin, son plafonnement et ses éventuels modificateurs sont un périmètre
distinct. La hausse du maximum de PV lors d'un niveau, les soins de refuge et
une redistribution ne sont pas des sorts de soin.

Les effets différés capturent ce que le contrat prévoit au lancement ; la
défense de la cible reste évaluée au moment du tic. Rééquiper après le lancement
ne doit pas revaloriser le même tic. Sauvegarder les valeurs, sources et horloges,
pas seulement le nom du statut.

### Les éléments d'investissement et les canaux défensifs sont distincts

Aujourd'hui, `consumable_card_effects.gd` envoie `Spell.Element.NONE` au
résolveur. Les poids Feu/Eau/etc. servent à l'investissement ; les dommages
sont physiques ou magiques. Ajouter six résistances ennemies n'est donc pas
un changement de six nombres dans un tableau.

Une extension élémentaire doit d'abord définir : canal défensif, composante
hybride, portions converties, application des plafonds et moment d'arrondi.
Réserver ces métadonnées dans le futur contrat est utile. Activer cette défense
avant une couverture de contenu et des solutions de secours accessibles crée
une obligation de changer de stratégie que le butin ne permet peut-être pas.

## 3. La carte doit avoir un budget vectoriel

Fiche d'évaluation minimale :

`(PA, copies, emplacement, coût d'acquisition, dégâts immédiats,
 dégâts différés, garde utile, soin utile, contrôle, mobilité,
 fiabilité, cibles, délai, conditions)`

Estoc normal, par exemple, établit une référence locale de 0,55 P physique,
1 PA, une copie, contact, une famille utilisable une fois par tour. Il ne fixe
pas le prix de toutes les autres fonctions.

Une zone de deux cibles ne vaut pas automatiquement deux fois un monocible :
accessibilité des cibles, ligne de vue, dégâts excessifs et urgence varient.
Une garde expirante ne vaut pas un soin permanent. Un contrôle qui empêche une
attaque complète peut valoir beaucoup, puis presque rien face à une autre
portée. Une carte puissante consommée dans une salle facile a un coût futur.

Pour chaque effet, conserver : potentiel, quantité réellement produite,
quantité utile, occasions perdues et ressource dépensée. Comparer par scénarios
et frontières de Pareto : coût comparable, situations où chaque candidat gagne.
Une domination sur une seule mesure ne suffit pas à supprimer une carte dont
la géométrie, le délai ou l'accès sont différents.

## 4. Une grammaire d'effets ouverte

Le moteur connaît déjà 25 opérations de cartes. L'étendre progressivement
avec les services existants, pas créer un moteur parallèle dans le laboratoire.

Chaque définition doit déclarer :

| Champ du contrat | Exemple / règle |
|---|---|
| Identité et version | Famille, forme, définition ; IDs stables |
| Coût | PA, copie consommée, emplacement ; payé une seule fois |
| Ciblage | Portée min/max, ligne de vue, forme, cibles permises, limite réelle |
| Composantes | Coefficient, poids, canal, origine originale/dérivée/fixe |
| Condition | Cible marquée, déplacement réel, garde absorbée, etc. |
| Horloge | Début d'activation cible, fin du héros, fin de phase ennemie… |
| Cumul | Remplacement ou paquets coexistants ; aucun maximum synthétique implicite |
| Événements émis | Impact, PV retirés, absorption, mort, déplacement accompli… |
| Réactions acceptées | Sources et classifications admises ; quota explicite |
| Persistance | Données du checkpoint, échéance, bénéficiaire et référence de source |

Exemple conceptuel d'événement : `guard_absorbed(source, target, amount,
root_action_id, origin_kind)`. Une relique peut écouter l'absorption réelle ;
elle ne doit pas se déclencher sur la création de garde ou une prévision.
Une même action et ses effets descendants partagent une origine traçable.

Une boucle d'événements n'est pas toujours mauvaise : une chaîne finie peut
être le moment spectaculaire du build. Elle doit avoir une fin démontrable :
quota, ressources décroissantes ou source qui ne réémet pas l'événement écouté.
Un budget technique d'exécution peut détecter une anomalie ; il ne remplace pas
un contrat expliquant au joueur combien de fois la chaîne peut fonctionner.

Avant davantage de durées ou de sources, remplacer les maxima séparés des
statuts par un contrat de paquets complets. Le choix de cumul est un choix de
gameplay à mesurer, pas une correction mécanique à appliquer sans expérience.

## 5. Les objets doivent ouvrir des façons de jouer

Rôles proposés :

- **Équipement** : ajuster une direction et un compromis répétable. Maîtrise
  mono contre polyvalence, défense contre mobilité, bénéfice à une portée
  contre bénéfice plus large. Six slots existants ; prix et poids de butin
  indépendants du nombre de définitions par slot.
- **Relique** : modifier une relation entre événements. Absorption puis garde,
  déplacement puis tic anticipé, dépense puis écho. Deux slots existants,
  règles lisibles et quotas explicites.
- **Perfectionnement** : changer une famille choisie, parfois sa forme,
  sans additionner deux variantes dans le même emplacement. Trois slots existants.
- **Choix de route** : financer fiabilité, économie, puissance ou risque.
  L'identité du personnage résulte aussi de ce qu'il décide de préserver.

Éviter un catalogue composé uniquement de bonus généraux identiques dans tous
les slots. Prévoir des objets transversaux : leur fonction doit être utilisable
par plusieurs classes et plusieurs éléments, avec des occasions différentes.

## 6. La matrice de contenu précède l'inflation des statistiques

Faire une matrice éléments × fonctions : direct, différé, garde/soin,
placement, contrôle, accès à la main. Annoter départ légal, butin, magasin,
coût, familles distinctes et acte d'apparition. Elle n'impose pas de remplir
toutes les cases ni de rendre chaque élément identique.

Pour chaque voie annoncée au joueur, viser provisoirement trois familles
accessibles et au moins deux modes d'utilisation avant de la présenter comme
une stratégie durable. Ce seuil est une cible de conception à éprouver,
pas une preuve de viabilité. Une attaque permanente adaptée aide le départ ;
elle ne remplace pas le répertoire consommable.

Priorités actuelles : dégâts Soleil normaux transversaux, soin normal, plusieurs
sources de dégâts différés, puis formes et objets qui exploitent ces fonctions.
Soin et Persistance ne deviennent des aptitudes proposées que quand elles ont
des sources utilisables dans les quatre classes. La modification des offres
doit être testée séparément : même nombre de copies peut signifier bien plus de
puissance attendue lorsque leur qualité augmente.

## 7. La puissance ressentie doit être mesurée

Une montée ou un objet devraient régulièrement produire une différence visible :
franchir un seuil de mise à mort, toucher une deuxième cible, réussir plus
souvent une ouverture, éviter une phase ennemie, conserver une ressource pour
la prochaine salle. L'écran doit montrer l'effet concret pour le répertoire
préparé et le prochain seuil lorsque l'arrondi masque le gain immédiat.

Mesures à associer aux résultats mathématiques : tours avant le premier plan
réussi, actions répétées, cartes inutilisées faute de cible/PA, interventions
des objets, temps de lecture et hésitation, choix abandonnés après découverte.
Ces mesures signalent des problèmes ; demander ensuite aux joueurs ce qui
était agréable, confus ou frustrant. Une victoire ne mesure pas le plaisir.

Un travail UI concurrent est apparu pendant cette étude. Le
[contre-audit disponible](../../ai/STATS_SEPARATION_REVIEW_2026-09-30.md),
son `findings.json` et les appels actuels de l'éditeur ont été relus : Contact
et Distance ne modifient pas l'aperçu sans contexte de portée ; la réorientation
complète reste une transaction immédiate malgré la promesse générale d'aperçu.
Ce sont des reproductions antérieures relues, pas des essais exécutés ici.
Aligner prévision et confirmation est un préalable utile au jugement des
investissements. Cette étude ne modifie pas les fichiers de cette autre tâche.

La méta-progression future peut d'abord ouvrir des options et informations :
nouveaux départs, cartes, objets, contrats de route, variantes de rencontre.
Ajouter de la puissance permanente au compte demanderait un profil de balance
distinct ; elle ne doit pas masquer les faiblesses d'accès d'une nouvelle run.

## Points d'entrée à prolonger

- [Progression](../../../core/expedition/consumable_progression_v1.gd),
  [mathématiques](../../../core/expedition/consumable_card_math.gd),
  [effets](../../../core/expedition/consumable_card_effects.gd),
  [horloges](../../../core/expedition/consumable_card_turns.gd).
- [Économie](../../../core/expedition/consumable_card_economy.gd),
  [profil de bestiaire](../../../core/expedition/consumable_enemy_profile.gd),
  [intégration](../../../core/expedition/consumable_cards_integration.gd),
  [checkpoints](../../../core/expedition/consumable_cards_checkpoint.gd).
- [Projection et ressources publiées](../../../core/expedition/consumable_cards_content.gd) :
  le manifeste reste la source, les objets et arènes passent par les services
  du Studio. Conserver cette chaîne pour produire et valider les nouveaux lots.

Le laboratoire Python de ce dossier analyse des expériences isolées. Pour
équilibrer un combat, le futur outil appelle les règles Godot et la vraie Battle.
Un second simulateur qui réimplémente les sorts n'aurait pas autorité sur le jeu.
