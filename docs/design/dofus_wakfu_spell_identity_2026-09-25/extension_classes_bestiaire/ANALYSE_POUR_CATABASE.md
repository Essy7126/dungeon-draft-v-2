# Conséquences pour Catabase et sa run de cartes consommables

## Diagnostic central

Une carte ne vaut pas seulement ses dégâts, son coût PA et sa rareté. Elle vaut **les décisions qu'elle rend possibles contre une composition donnée**, et le nombre de copies qu'elle permet d'économiser ensuite. Un déplacement peut éviter une attaque, séparer un soutien, déplacer une zone ou ouvrir un chemin. Le rendre disponible seulement par un drop rare peut donc bloquer une rencontre conçue autour de lui.

Les lectures des [classes DOFUS](CLASSES_DOFUS.md), [classes WAKFU](CLASSES_WAKFU.md), [ennemis DOFUS](BESTIAIRE_DOFUS.md) et [ennemis WAKFU](BESTIAIRE_WAKFU.md) conduisent aux propositions ci-dessous. Il s'agit de notre analyse, pas d'une affirmation de satisfaction de tous les joueurs. Aucun sondage représentatif ni taux de victoire Ankama n'est disponible dans ce corpus.

## 1. Ce qui crée de l'identité

| Structure de gameplay | Décision répétable | Comment l'adapter au consommable |
|---|---|---|
| Ressource avec plusieurs sorties | Garder la réserve, finir une cible, se protéger ou rejoindre une position | État conservé par le héros ; plusieurs cartes communes peuvent l'exploiter. |
| Objet de terrain persistant | Construire, défendre, déplacer ou sacrifier | Une carte de pose crée un investissement ; éviter de faire payer une copie rare pour chaque commande triviale. |
| Effet différé | Préparer l'échéance en acceptant un tour plus faible | Échéance visible et état attaché à une identité persistante, pas à une carte détruite. |
| Posture qui remplace une règle | Changer de portée, de bénéficiaire ou de ressource | Relique/spécialisation comme compromis ; pas addition automatique de toutes les postures. |
| Cible alliée/ennemie ou objet | Réutiliser le même outil dans un autre rôle | Un petit nombre de cartes polyvalentes réduit les mains inutilisables ; afficher les branches avant paiement. |
| Événement spatial | Préparer une collision, une traversée, un alignement | Définir l'événement exact et ses règles de répétition. |

**Les contraintes doivent acheter une décision.** Une portée minimale, une dette au prochain tour ou la destruction d'une structure peuvent créer un choix lisible. Une condition d'état cachée, une exception sans prévisualisation ou un coût de préparation disproportionné peut seulement rendre le kit pénible. La difficulté d'exécution ne constitue pas à elle seule une profondeur de jeu.

## 2. Ce que le dépôt possède déjà, relu pendant cette extension

Lecture statique à la base Git `6a500c545f04d3e4c53a99d3643d0c4d844e303f`. Les valeurs suivantes sont des contrats de code/documents ; leur fonctionnement en partie n'a pas été revalidé ici.

| Élément local | Contrat relu | Conséquence réelle pour l'audit |
|---|---|---|
| [Catalogue des salles](../../../../core/expedition/card_tactical_room_catalog.gd) | Forge : presse 32 héros/60 ennemis ; Jardin : anneaux Manhattan 2→3→1, 28 dégâts ; Convoi : porteurs vers autel ; Sablier : croix 32 retardable à 48 ; Réservoir : PA stockés | Nous avons déjà dangers manipulables, temporalité, ressource disputée et soutiens. Le manque n'est pas « aucun boss tactique ». |
| [Règles de salle](../../../../core/expedition/card_tactical_room_rules.gd) | Convoi : porteur proche donne 12 garde ; livraison soigne 35 et ajoute 8 attaque ; sceau 2 PA fait reprendre les attaques normales | Sceller a une contrepartie : cela évite la livraison mais réactive les ennemis. Conserver cette alternative. |
| [Règles de ressource](../../../../core/expedition/card_tactical_resource_rules.gd) | Réservoir ≤6 charges ; décharge 1 PA, 22 dégâts/charge ; voleur proche consomme une charge et soigne jusqu'à 12 ; le sablier résout une liste d'impacts | La valeur d'une poussée dépend de la charge sauvée. La simultanéité évite de tronquer une explosion si le chef meurt. |
| [IA des salles](../../../../core/ai/tactical_room_enemy_ai.gd) | Pénalise les dangers ; brutes/molosses/alphas peuvent les accepter hors danger létal ; valorise les réservoirs chargés | Différences de comportement déjà présentes ; vérifier leur lisibilité avant d'inventer davantage de profils. |
| [Écosystème ennemi](../../../../core/expedition/card_enemy_ecosystem.gd) | Sorts de cartes ajoutés selon rôle ; invocations annoncées, case occupable pour les interrompre ; recharge quatre, plafond six vivants | Le plafond simultané ne démontre pas un plafond de renforts sur tout le combat. Auditer le budget total dans une run à stock fini. |
| [Sentence de bronze](../../../../data/spells/enemies/catabase_execution.tres) | Préparation au contact, résolution activation suivante, 3 PA, recharge trois, délai initial un ; sortie du contact annoncée comme réponse | Préserver la réponse par mouvement. Ne pas remplacer cette lecture par une simple hausse des PV ennemis. |

Le [premier audit](../../spell_comparison_2026-09-25/AUDIT_ET_PRIORITES.md) décrit aussi Conducteur, Oracle, Porte-Égide, Collecteur et Pâris. Ce sont des conclusions précédentes, pas une nouvelle validation moteur. Notre extension apporte surtout une grille plus précise des **déclencheurs**, des **sources de soutien** et du **coût en copies**.

## 3. Les manques prioritaires à vérifier ou préciser

### A. Un contrat d'événement commun

Chaque sort, passif et règle de salle doit répondre aux mêmes questions : cible légale au paiement ou à l'impact ; coût dépensé si échec ; état consommé avant ou après dégâts ; impact absorbé compté ou non ; déplacement réel ou seulement demandé ; expiration à quelle activation ; effets conservés après décès. Une présentation commune n'exige pas nécessairement une refonte du moteur : commencer par documenter les contrats existants et les scénarios de régression.

### B. Une limite totale aux ressources que l'ennemi recrée

Une limite de six ennemis vivants empêche l'encombrement, mais permet encore un nouveau renfort après chaque élimination. Un soin plafonné par lancement peut rester indéfini. Pour un deck détruit à l'usage, définir une réserve totale de soins, d'armure renouvelée, de renforts et de résurrections par rencontre. Une difficulté supérieure peut modifier ces réserves, explicitement annoncées.

### C. L'accès garanti aux réponses obligatoires

Trois copies d'une réponse dans trente cartes ne garantissent pas de l'avoir en main. Séparer les outils d'optimisation des outils indispensables. Une salle à verrou obligatoire doit fournir une commande de salle, un objet utilisable ou une alternative de victoire. Une carte appropriée rend la solution moins coûteuse ; sa possession ne doit pas être un test de chance irréversible.

### D. Une progression des comportements

Pour une même famille : rencontrer d'abord sa règle isolée, puis un soutien, puis un boss qui change un paramètre connu. Faire apparaître une règle létale sans répétition préalable ni aperçu transforme l'apprentissage en perte de run. Réserver les empilements complexes aux défis explicitement choisis.

### E. Des améliorations qui modifient l'emploi d'un outil

Les sorts étudiés suggèrent des choix de bénéficiaire, d'origine, d'échéance ou de conversion. Pour nos quatre classes, proposer un mécanisme central et deux issues concurrentes. Les cartes communes doivent déjà permettre d'en faire l'expérience ; une rareté élevée approfondit le mécanisme plutôt que d'autoriser enfin le personnage à fonctionner.

## 4. Quatre axes de classe proposés, sans remplacement du catalogue

| Classe Catabase | Préparation | Deux sorties concurrentes | Limite explicite proposée |
|---|---|---|---|
| Assassin | Ouverture sur une cible après approche ou marque | Finir la cible / transférer l'ouverture à la suivante | Une ouverture active ; transfert perd une partie de sa puissance ; pas de remboursement de copie. |
| Gardien | Réserve de garde et position tenue | Encaisser / consommer une part de garde pour déplacer ou frapper | Garde expirante affichée ; conversion consomme avant dégâts ; pas de création nette par boucle. |
| Arpenteur | Balise de retour et distance préparée | Revenir / sacrifier la balise pour déplacer une menace | Une balise, durée courte ; case occupée prévisualisée ; issue de secours si bloquée. |
| Thaumaturge | État sur cible ou surface produite | Propager / consommer pour un effet ciblé | Deux états de base au prototype ; pas toutes les combinaisons élémentaires simultanément. |

Ces axes prolongent les boucles déjà relevées dans l'audit. Ils restent des propositions. Leur priorité est de rendre plusieurs cartes utiles à la même préparation, ce qui supporte mieux le drop de sacs qu'une combinaison exigeant deux noms exacts.

## 5. Fiches de prototypes ennemis à éprouver

**Propositions originales, valeurs de laboratoire, non implémentées et non équilibrées en partie.** Les nombres permettent de construire un essai reproductible, pas de déclarer la V1 validée. Une seule carte est consommée par lancement légal ; action de salle et déplacement ordinaire n'en consomment pas.

### A. Fondeur sous pression — choisir le nombre d'impacts

- 100 PV ; compteur de pression initial 0, plafond 6. Chaque impact direct positif non létal reçu ajoute 1. Poison, dégâts de salle et dégâts absorbés ne chargent pas dans ce prototype.
- À 6, remplace sa prochaine attaque par une ligne annoncée de quatre cases, 35 dégâts. Résolution à sa prochaine activation, puis compteur 0. Déplacer le Fondeur déplace la ligne ; son orientation annoncée reste fixe.
- Deux vannes de salle : à distance Manhattan ≤1, payer 2 PA remet son compteur à 0, une commande par tour. Le plan doit garantir un chemin vers au moins une vanne ; condition non démontrée par les seuls calculs.
- Réponses : gros impact, poison/salle, dispersion de cibles, vanne, sortie de ligne. Un deck de petites cartes a une réponse plus coûteuse, mais possible.
- Drop : éligibilité initiale unique ; sacs normaux de sa famille selon la table de profondeur. Une technique de pression peut appartenir au pool rare ; sa présence n'est jamais nécessaire au combat.

### B. Veilleuse d'oboles — soutien à réserve finie

- 60 PV ; deux oboles visibles. À son activation, soigne de 30 PV l'allié blessé au plus faible pourcentage de vie dans un rayon trois et en vue, puis consomme une obole. En cas d'égalité : distance puis identifiant de combat.
- Sans cible légale : conserve l'obole, avance selon son rôle ; aucune consommation fictive. Sans obole : attaque faible de base, aucune recharge d'obole.
- Réponses : l'éliminer, isoler son bénéficiaire, bloquer la vue, forcer le soin sur une cible secondaire. La perte totale de stock due à ses soins est bornée à 60 PV supplémentaires.
- Drop : sacs sur la Veilleuse initiale ; aucun drop par obole ni par soin empêché. Tuer vite peut donner un bonus économique plafonné, jamais créer une boucle reproductible.

### C. Porte-cloche — préparer l'emplacement de la prochaine menace

- 80 PV ; tous les deux tours annonce un cercle Manhattan de rayon un centré sur sa case au lancement. Explosion à sa prochaine activation : 24 dégâts à toutes les entités présentes, puis expiration.
- Le glyphe reste fixe si le Porte-cloche bouge. Sa mort n'annule pas une cloche déjà posée. Il ne peut en avoir qu'une active.
- Réponses : sortir à pied, attirer un ennemi dedans, supprimer l'ennemi avant le prochain lancement, utiliser une garde. Différence volontaire avec le Fondeur dont la zone suit la source.
- Premier combat pédagogique : un seul Porte-cloche, cases sûres visibles ; aucun ralentissement ajouté avant que cette règle soit enseignée.

### D. Gardien des soupapes — assembler un boss sans invulnérabilité dure

- 360 PV, une Veilleuse ; première phase : attaque de ligne annoncée 24 dégâts et pression du prototype A. Pas de remise à plein des PV.
- Premier passage à ≤50 % PV : après résolution complète de la carte en cours, donne 60 garde au boss, une seule fois. Aucun tour supplémentaire immédiat. Deuxième phase : zone de pression plus large, même seuil et mêmes vannes.
- La garde peut être consommée par dégâts ordinaires ou supprimée par une commande de vanne coûtant 2 PA. L'absence d'une carte de déplacement n'empêche pas la victoire.
- Borne nominale d'attrition sans résistances : boss 360 + garde 60 + Veilleuse 60 + soins maximum 60 = 540 dégâts, soit dix-huit impacts effectifs de 30. Ce n'est **pas** un coût de victoire complet : ajouter mobilité, défense, accès, surdégâts et disponibilité réelle des cartes.
- Ne pas l'introduire tant que les modèles isolés A/B et l'affichage de transition ne sont pas vérifiés dans Godot.

## 6. Préserver le drop sur les mobs

Le drop reste attaché aux monstres, comme demandé. La lecture des techniques sert à donner une identité aux **pools de sacs**, pas à imposer un vol de sort automatique. Une famille mobile peut alimenter davantage les outils de mouvement ; les sacs normaux restent abondants, les techniques rares restent occasionnelles. Les probabilités numériques doivent être calibrées avec les tables de profondeur déjà proposées dans le [laboratoire économique](../../card_economy_lab/), pas inventées à partir des taux d'un MMO.

Trois règles de robustesse proposées : l'identité initiale donne au maximum une éligibilité au butin ; résurrection/sacrifice ne la réinitialisent pas ; invocations ne créent pas de sacs supplémentaires. Les sacs proviennent toujours de victoires sur les mobs. Une source peut produire plusieurs sacs selon sa table, mais un même monstre ne donne pas plusieurs tirages parce qu'il meurt plusieurs fois.

Évaluer chaque famille par **entrée de copies, consommation de copies, sortie de copies, valeur des rares conservées et capacité de préparation avant la salle suivante**. La moyenne de drop ne suffit pas : vérifier aussi la pire séquence raisonnable de combats sans outil de contrôle. Une réserve universelle de sortie de crise doit être une décision de préparation accessible, pas une légendaire obligatoire.

## 7. Mesures nécessaires au prochain essai jouable

| Mesure | Pourquoi elle compte | Critère de prototype proposé |
|---|---|---|
| Main sans action utile | Sépare problème de deck et problème d'ennemi | Toute rencontre conserve une réponse de salle ou un mouvement utile ; aucun verrou insoluble. |
| Copies par combat, médiane et queue haute | Détecte l'attrition cachée des soins/renforts | Rapporter au stock d'entrée et aux sacs réellement obtenus. |
| Actions d'ennemi empêchées | Rend visible la valeur du contrôle | Distinguer évitement, interruption, report et annulation définitive. |
| Réponse choisie à une même intention | Vérifie la diversité tactique | Au moins deux voies utilisées en essais, pas seulement deux décrites. |
| Dépense de cartes rares | Détecte l'accumulation par peur | Comparer joueurs informés du prochain boss et joueurs sans information. |
| Compréhension de la mort | Vérifie la lisibilité | Après une défaite, le joueur peut identifier déclencheur et réponse possible. |
| Temps de décision et de résolution | Invocations et réactions peuvent ralentir la run | Compter les commandes et événements réellement joués, pas le nombre de cartes du catalogue. |

Ces critères ne sont pas encore satisfaits par des essais humains : ils définissent ce qui doit être mesuré. Le dossier fournit les lectures, les prototypes et les calculs préparatoires, sans prétendre avoir exécuté ces combats.
