# Rapport — cartes consommables, sacs et économie de run

Date : 24 septembre 2026. Référence inspectée : `6a500c545f04d3e4c53a99d3643d0c4d844e303f`.

**Complément du 25 septembre :** lire l'[audit systémique](research_2026-09-25/README.md). Les résultats ci-dessous restent historiques. La variante `early_supply` fait baisser deux taux au deuxième palier et ne constitue donc pas une base de progression conforme. Le paramètre de 70 % est un stress supposé d'utilité, pas une restriction de classe observée : les cartes étrangères sont jouables au rang zéro.

## 1. Conclusion opérationnelle

La direction est réalisable et mérite un prototype : des mobs produisent des sacs, les normales deviennent abondantes, les qualités supérieures restent des événements, et le joueur prépare jusqu'à trente charges pour chaque combat à partir de sa réserve.

Le principal problème de la première table n'est pas le volume total : **le début manque de marge tandis que les survivants accumulent ensuite beaucoup de cartes**. La compatibilité avec le build est un deuxième problème indépendant. L'économie doit servir à ajuster le stock ; elle ne devrait pas devenir le passage obligatoire qui répare une pénurie créée par les trois premiers combats.

Recommandation de travail : conserver la table initiale comme témoin ; comparer une table avec davantage de sacs normaux au premier palier, mesurer les dépenses réelles et le taux d'utilité des cartes. Ne pas augmenter les légendaires pour résoudre un manque de cartes ordinaires. Ne pas ajouter maintenant de prospection, de maîtrise ou de bonus de performance pour masquer ce problème.

## 2. Ce qui vient de la demande et ce qui reste une hypothèse

**Direction utilisateur :** exemplaire à usage unique ; environ quinze cartes choisies au départ ; sacs sur les monstres ; plusieurs sacs normaux possibles par combat ; normales faibles faciles à obtenir ; progression des chances avec l'avancement ; élite, rare, légendaire, Dieu et immortel plus difficiles à obtenir ; établir le standard avant les modificateurs ; étudier préparation, run et économie.

**Hypothèses de laboratoire, non validées par le joueur :** deck plafonné à trente ; réserve sans plafond ; contenu 3/2/1 selon les sacs ; taux précis ; trois copies maximum par famille ; main de cinq ; prix, revenus initiaux et politique de ravitaillement ; consommation par combat ; compatibilité de 70 % ; variante de départ plus généreuse. La main publique actuelle est de quatre cartes, le deck de dix ; ces idées ne sont pas déjà implémentées.

**Pistes écartées après correction :** vol de sorts aux ennemis, paquets garantis par victoire remplaçant les drops, choix imposé entre trois paquets comme source principale, plafond de réserve de vingt-quatre. Les documents antérieurs sont des archives de réflexion.

## 3. Correction des effectifs : 32 à 33 monstres, pas 43

Lecture statique de `catabase_route_v6.gd`, `catabase_monster_encounter_catalog.gd`, du combat d'ouverture et de `card_tactical_room_catalog.gd`. Les salles tactiques conservent le roster. Le boss a trois unités mais ses drops ne financent pas la préparation de la run.

| Combat | Profondeur | Type | Monstres |
|---|---:|---|---:|
| 1 | 1 | Normal | 1 |
| 2 | 2 | Normal | 2 Airain ; 3 Styx/Léthé |
| 3 | 3 | Normal | 3 |
| 4 | 5 | Normal | 3 |
| 5 | 6 | Élite | 4 |
| 6 | 8 | Normal | 3 |
| 7 | 10 | Élite | 2 |
| 8 | 12 | Normal | 4 |
| 9 | 13 | Normal | 3 |
| 10 | 15 | Élite | 4 |
| 11 | 17 | Normal | 3 |
| 12 | 20 | Boss | 3 |

La première table, inchangée, produit sur Airain avant boss : **93 normales, 9,76 élites et 1,10 rare en moyenne**. Styx/Léthé : 94,65 normales et 9,86 élites. L'hypothèse précédente produisait 125,25 normales : écart de 32,25 cartes avec Airain.

Les chances Airain d'au moins une carte avant boss deviennent : rare 67,77 %, légendaire 10,99 %, Dieu 1,31 %, immortel 0,140 %. Le premier monstre a 45 % de chances de ne donner aucun sac normal. À l'inverse, le dernier combat avant boss donne 12,6 normales en moyenne.

Le drop par mob crée aussi une différence de récompense entre chemins et entre groupes de tailles différentes. Le deuxième combat à trois unités rapporte 50 % de plus qu'à deux unités avec la même table. Ce n'est pas nécessairement un défaut : c'est un choix de route à rendre lisible. Un élite de deux unités peut moins rapporter qu'un normal de quatre ; ne pas dissimuler cette conséquence derrière une moyenne par acte.

## 4. Mathématiques du modèle

Chaque monstre tire indépendamment sept lignes : normal A, normal B, élite, rare, légendaire, Dieu, immortel. Les sacs contiennent respectivement 3, 3, 2, 1, 1, 1, 1 cartes. La table complète est dans [baseline.json](baseline.json), en probabilités entre zéro et un.

Pour une ligne de chance p, k cartes par sac, m monstres :

`E[cartes] = m × k × p`

`Var[cartes] = m × k² × p × (1 − p)`

Le carré de k compte : trois cartes dans un sac sont plus variables que trois petits jets indépendants ayant le même total attendu. Oublier cette corrélation sous-estimerait les sécheresses.

Sur des chances différentes par monstre : `P(au moins un sac) = 1 − produit(1 − p_i)`. Pour une carte précise dans un catalogue uniforme de F références, remplacer p par p/F pour les sacs à une carte. Les rangs fermés à zéro restent fermés, quelle que soit la durée des tentatives à ce palier.

Un taux d'obtention ne mesure pas la valeur tactique. Il faut distinguer successivement : sac obtenu, carte compatible, carte cohérente avec le build, carte piochée à temps, carte utile dans la situation, carte effectivement jouée. Le paramètre appelé compatibilité dans le modèle est un filtre hypothétique agrégé ; il ne mesure empiriquement aucune de ces étapes et ne prouve pas une interdiction des cartes hors classe.

## 5. Expériences exécutées

Node v24.19.0, 20 000 parcours par cas, graine 24092026, 36 cas = 720 000 parcours de budget. Un calcul exact par propagation des probabilités vérifie indépendamment les cas sans boutique et avec toutes les cartes utilisables. Huit tests automatiques couvrent notamment conservation, absence de financement par un drop futur, reproductibilité et accord Monte Carlo/calcul exact.

Trois demandes hypothétiques de cartes, dans l'ordre ouverture / normal suivant / élite / boss :

- Sobre : 2 / 4 / 6 / 10, soit 58 exemplaires sur la run.
- Intermédiaire : 3 / 6 / 9 / 12, soit 84 exemplaires.
- Intensif : 3 / 9 / 12 / 15, soit 117 exemplaires.

Un parcours s'arrête lorsque son stock ne peut pas payer la demande AVANT le combat. Ce n'est pas une mort simulée : un humain pourrait utiliser ses actions d'arme, consommer moins de cartes ou perdre pour une autre raison. Les cartes de toutes raretés sont traitées comme des charges équivalentes ; aucun PA, ciblage, dégât, pioche, soin ou équipement n'est simulé.

### Base : assez de cartes au total, mauvais calendrier

| Hypothèse | Parcours finançant toutes leurs dépenses |
|---|---:|
| Sobre, 100 % utilisables, sans achat | 99,82 % exact |
| Intermédiaire, 100 %, sans achat | 73,44 % exact |
| Intensif, 100 %, sans achat | 1,13 % exact |
| Intermédiaire, 70 %, sans achat | 12,83 % Monte Carlo |
| Intermédiaire, 100 %, achats aux refuges | 79,81 % Monte Carlo |
| Intermédiaire, 70 %, achats aux refuges | 32,67 % Monte Carlo |

Le profil intermédiaire échoue surtout à financer les combats quatre et cinq : respectivement 6,68 % et 13,79 % de l'ensemble des parcours dans le calcul exact. Son stock final médian, parmi les parcours financés dans le Monte Carlo sans achat, est pourtant de 38 cartes. Le profil sobre finit à 61 cartes médianes. **L'abondance tardive ne répare pas une dépense impossible auparavant.**

Les 70 % utilisables sont un stress test indépendant par carte, pas une mesure des maîtrises actuelles. Des cartes inutilisables groupées dans un même sac pourraient créer davantage de variance que ce modèle. Les quinze cartes initiales et les achats ciblés restent tous utilisables.

### Variante de base : davantage de normales tôt

La variante `early_supply` change seulement le premier palier : sac normal A 75 % au lieu de 55 %, sac B 15 % au lieu de 0 %. Tous les rangs supérieurs restent identiques. La chance de zéro sac normal par monstre devient 21,25 %. Le premier ennemi donne 2,7 normales en moyenne ; les six monstres des trois premiers combats Airain donnent 16,2 normales au lieu de 9,9.

| Variante généreuse au départ | Parcours financés |
|---|---:|
| Intermédiaire, 100 %, sans achat | 95,85 % |
| Intermédiaire, 100 %, achats aux refuges | 98,02 % |
| Intermédiaire, 70 %, sans achat | 39,53 % |
| Intermédiaire, 70 %, achats aux refuges | 73,68 % |

C'est une candidate pour le prototype, pas une nouvelle règle acceptée. Elle améliore l'approvisionnement, mais ne résout pas à elle seule le problème des cartes inutilisables. Ne pas conclure qu'un taux de financement de 95 % équivaut à un taux de victoire de 95 %.

### Boutique avant le quatrième combat : efficace mais structurante

Politique d'achat : aux refuges après combats 5, 7, 10 et 11, acheter jusqu'à atteindre quinze cartes utilisables, maximum deux paquets de six à 36 oboles par visite, sans dette. La variante `early_vendor` ajoute une boutique après le combat 3. La route propose effectivement une halte marchande à profondeur 4, mais son accessibilité dépend du chemin : elle n'est pas universellement garantie. Le modèle suppose cette visite possible.

Avec la table initiale, le profil intermédiaire finance 99,995 % de ses parcours à compatibilité 100 %, et 99,83 % à 70 %. Mais le profil intensif reste à 48,24 % et 9,30 %, car une partie des pénuries arrive AVANT cette boutique. Un coût de ravitaillement faible observé chez les profils en échec ne signifie pas qu'ils n'en ont pas besoin : ils n'atteignent pas le magasin.

Le marchand peut devenir une route obligatoire plutôt qu'un choix. Recommandation : améliorer d'abord la base et la compatibilité ; conserver le commerce pour la précision et les arbitrages. Les revenus de 35/65 sont présents dans `expedition_session.gd`, mais l'or initial de 40, les prix, stocks et politiques d'achat sont proposés. Soins et autres dépenses ne sont pas débités dans les expériences.

## 6. Préparation du deck : trente n'est pas automatiquement préférable

Avec une main aléatoire de cinq cartes et trois copies d'une famille : probabilité d'en voir au moins une à l'ouverture = `1 − C(N−3,5)/C(N,5)`.

| Taille du deck | Probabilité approximative |
|---|---:|
| 15 | 73,63 % |
| 20 | 60,09 % |
| 25 | 50,43 % |
| 30 | 43,35 % |

Ces chiffres supposent une main de cinq, sans ouverture préparée ni mulligan. Ils ne modélisent pas une séquence de pioche pendant le combat. Le grand deck augmente l'endurance et les réponses disponibles mais dilue l'ouverture. Le petit deck ne doit pas permettre d'oublier la consommation persistante.

Deux cartes préparées au départ peuvent réduire la frustration, mais garantiraient aussi un combo dans chaque combat tant que le joueur en possède les copies. Comparer d'abord la main actuelle de quatre à une main de cinq ; tester ensuite une ouverture préparée séparément. Ne pas cumuler trois changements puis attribuer le résultat uniquement aux drops.

Pistes d'interface : réserve empilée, préparation par quantités, avertissement de deck court sans interdiction, estimation du nombre de charges par rôle, fiche des tables des mobs, ouverture groupée des sacs. Une carte non jouée ne doit jamais être détruite par une défausse de fin de tour.

## 7. Économie : valeur d'usage, valeur de précision, valeur de vente

La table économique expérimentale est dans le JSON : achat ciblé 8/16/40/110/250/500 ; revente 1/3/12/35/80/150 pour normale à immortelle. Les prix des rangs supérieurs sont des valeurs de réflexion, pas la promesse d'un magasin permettant de les acheter. Une immortalité ultra-rare ne doit pas devenir banale par une offre commerciale permanente.

Le flux de drops Airain représente **140,806 oboles de valeur moyenne brute à la revente** si tout était vendu. C'est un plafond comptable moyen de liquidation intégrale, pas un revenu attendu pendant une run : vendre supprime les moyens de combattre. Les événements et équipements ne sont pas inclus. Les quinze cartes initiales ne sont pas valorisées dans ce chiffre.

Le paquet marchand de six normales à 36 se revend six : acheter pour revendre détruit trente oboles. Une carte précise est plus chère qu'une carte aléatoire, car elle économise l'incertitude de recherche. Le troc de deux normales contre une normale précise détruit aussi de la valeur de liquidation. Cela suffit pour ces opérations simples ; **cela ne prouve pas l'absence de cycles avec remises, contrats, annulations et transformations futures**.

Pistes à conserver pour plus tard : commander un exemplaire pour le refuge suivant, échanges de familles de même rang, collections thématiques de sacs, contrats ponctuels visibles longtemps à l'avance. Ne pas convertir automatiquement des centaines de normales en immortelle. Une conversion ascendante répétable transforme immédiatement le taux de drop du rang supérieur en simple coût de farm.

Éviter les erreurs suivantes : multiplier les monnaies avant besoin ; payer des oboles pour ouvrir un sac déjà gagné ; renouveler gratuitement les offres ; vendre sans confirmation un exemplaire préparé ; modifier son contenu en le rouvrant ; donner davantage de butin parce que le joueur a volontairement joué dans le vide.

Le surplus normal n'est pas forcément un problème si le joueur l'utilise pour préparer différents combats. Il devient un problème si le tri prend plus de temps que le jeu, ou si l'or obtenu rend les autres décisions triviales. Mesurer surplus par fonction et famille, pas seulement nombre brut de cartes.

## 8. Atelier de cartes : vingt lignes proposées

[cards.csv](cards.csv) contient huit normales, six élites, trois rares, une légendaire, une divine et une immortelle. Ce sont des exemples originaux, non importés dans Godot. `P` désigne une référence de prouesse commune à définir ; les coefficients ne sont pas validés avec les PV et résistances réels. Chaque ligne comporte son risque d'équilibrage.

Les normales ont une fonction économique essentielle : fournir de petites actions encore utiles tardivement. Une attaque à 1 PA peut être faible par carte tout en étant efficace par PA ; une carte de déplacement ou de préparation peut rester pertinente sans grand coefficient de dégâts.

Exemples de séquences à tester :

- Repérage puis Rupture : deux exemplaires dépensés pour concentrer un impact. Comparer au même budget de PA en attaques simples, et au risque de piocher les pièces séparément.
- Traction puis Heurt : réorganiser une menace avec des déplacements courts ; vérifier que les collisions ne deviennent pas un moteur de dégâts dominant.
- Protection brève puis Écho défensif : conserver assez de bouclier pour rentabiliser la deuxième carte ; la situation ennemie compte autant que la rareté.
- Relais : sacrifier une carte et un PA pour chercher une normale déjà présente dans la pioche. Il réduit l'incertitude sans créer de copies.

Pour les rangs extrêmes, préférer un moment spectaculaire aux effets qui cassent le modèle de ressources. « Seconde aurore » restaure uniquement les PV du début d'activation puis termine le tour ; elle ne restitue aucune carte consommée, monnaie ou action. Son nom ne signifie pas que son exemplaire cesse d'être consommable.

Une immortelle trouvée dans 0,14 % des runs pose aussi un problème d'expérience : beaucoup de joueurs ne la verront jamais et ceux qui la trouvent risquent de ne jamais la dépenser. Le codex peut garder son souvenir après usage, sans ajouter implicitement une banque de cartes inter-runs. Le choix de conserver ou non des biens entre runs reste ouvert et changerait radicalement les équations économiques.

## 9. Ce que les recherches ajoutent

Voir [SOURCES.md](SOURCES.md) pour six références commentées et leurs limites. Les idées retenues sont : rendre visibles les sources de butin et leurs règles ; séparer quantité, qualité et utilité ; utiliser les conteneurs pour un éventuel ciblage ; confronter les données aux observations de joueurs ; prévenir la peur de consommer ; donner plusieurs usages concurrents aux ressources.

Les chiffres Dofus actuels n'ont pas été vérifiés dans une documentation primaire accessible. Aucune formule de prospection de ce jeu n'est réutilisée. Les sources GGG, Nintendo, Digital Extremes et Mega Crit étayent les axes de réflexion, pas les paramètres de notre prototype.

## 10. Architecture à reprendre sur l'autre ordinateur

- `core/expedition/card_drop_catalog.gd` : système actuel au niveau du nœud, avec résonance et mémoire de sécheresse. Créer un contrat explicite par monstre pour la variante ; ne pas cumuler silencieusement les deux systèmes.
- `core/expedition/catabase_monster_encounter_catalog.gd` : source des compositions initiales et de leurs variantes. Définir les détenteurs uniques de droits au butin ; pas de nouveau droit pour une invocation ou une résurrection.
- `core/expedition/class_cards.gd` : validation actuelle du deck, récompenses, catalogue et restauration. Réviser le contrat de taille et les sauvegardes uniquement lors d'une implémentation autorisée.
- `core/expedition/catabase_cards.gd` : piles, consommation, vente et annulation. Une consommation doit retirer exactement un exemplaire de la propriété et des piles ; une défausse d'inutilisé ne le détruit pas.
- `core/expedition/expedition_session.gd` : ordre de récompenses et monnaie.
- Studio : réutiliser les services existants pour toute future édition de contenu ; ne pas créer un deuxième outil d'authoring concurrent.

Enregistrement proposé d'un drop : version de table, seed de run, identifiant de rencontre, identifiant du monstre initial, ligne de drop, sac, exemplaires produits, état attribué/ouvert. Les jets et contenus sont déterministes et enregistrés une fois. Un changement ultérieur de table ne réécrit pas un sac déjà gagné.

Un cast invalide ne consomme pas de carte ; un cast accepté qui est esquivé la consomme. Effet et retrait doivent rester cohérents lors d'une sauvegarde ou interruption. Le troc doit vérifier et consommer toutes les entrées avant d'attribuer les sorties dans une transaction atomique. Aucun test moteur de ces règles n'a été exécuté ici puisqu'elles ne sont pas implémentées.

## 11. Prochaine session recommandée

1. Vérifier la fraîcheur du commit et des compositions. Rejouer les tests du laboratoire et les 36 cas ; ne pas reprendre le scénario de 43 mobs comme réalité.
2. Exporter les dépenses réelles de cartes, usages des actions gratuites, PA et durée sur plusieurs rencontres actuelles. Les profils 58/84/117 sont des hypothèses de stress.
3. Définir le catalogue normal minimal et son accessibilité entre classes. Mesurer compatibles, utiles et jouées séparément.
4. Choisir un prototype limité : table témoin ou départ renforcé, cartes consommables, réserve et deck plafonné. Garder le reste fixe.
5. Instrumenter et faire des parties humaines ; comparer peur de manquer, plaisir de dépenser, qualité des décisions et charge de gestion. Un manque volontairement accepté pour une prise de risque n'est pas équivalent à une main inutile imposée.
6. Ajouter seulement ensuite économie plus riche, identité des sacs et modificateurs de drop, une couche à la fois.

Questions produit encore ouvertes : persistance entre runs ; accessibilité des six rangs dans une run aussi courte ; noms définitifs ; cartes incompatibles autorisées au drop ; stock marchand des rangs supérieurs ; éventuel commerce des sacs fermés ; règles de fuite ; garantie ou non d'un marchand précoce. Aucun de ces choix n'a été tacitement tranché par le simulateur.
