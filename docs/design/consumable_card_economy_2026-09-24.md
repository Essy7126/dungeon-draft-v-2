# Cartes consommables : économie et préparation de run

**Cadrage remplacé après correction utilisateur :** les drops doivent venir des monstres sous forme de sacs, avec des taux croissants selon l'avancement. Les paquets garantis par victoire et le choix entre trois paquets ci-dessous ne sont plus la proposition retenue. Voir `mob_card_bags_baseline_2026-09-24.md` pour la nouvelle base sans modificateurs de drop.

Proposition du 24 septembre 2026. Remplace le cadrage précédent : aucun vol de technique ennemie. Les drops dépendent de tables de récompenses et de la route, pas du répertoire des monstres. Aucune implémentation. Valeurs de prototype, calcul de stocks exécuté, aucun équilibrage combat ni test joueur réalisé.

## Contrat de jeu

Le joueur choisit quinze exemplaires au départ. Il construit entre les combats un deck de trente exemplaires maximum à partir de sa réserve de run. Chaque exemplaire joué est consommé définitivement ; les exemplaires inutilisés restent disponibles. Les récompenses vont en réserve. Aucun accès à la réserve pendant le combat.

La réserve n'a pas de plafond pour le prototype : affichage groupé par famille et rang, opérations par quantité. Un plafond de réserve ajouterait une deuxième contrainte de rangement sans démontrer de bénéfice tactique. Les cartes et oboles ne passent pas à la run suivante. Le codex et les déblocages éventuels augmentent les choix de départ, pas la richesse initiale.

La préparation de départ accorde exactement quinze exemplaires, dont au plus trois inhabituels et le reste commun, maximum trois exemplaires par famille. Le catalogue initial doit être validé pour permettre attaque, défense, mobilité et contrôle dans chaque classe. Le joueur peut volontairement construire une composition spécialisée.

Le plafond de trente n'est pas un objectif à remplir. Un petit deck trouve plus vite ses synergies, mais dispose de moins d'actions avant épuisement. Un grand deck prépare une rencontre longue et davantage de réponses, mais dilue les cartes clés. Maximum trois exemplaires par famille dans le deck ; la réserve peut en contenir davantage. Une action d'arme reste disponible sans carte.

Hypothèse pour un prototype dédié : main de cinq, avec deux emplacements de la main initiale préparés par le joueur et trois tirages aléatoires. Les deux exemplaires préparés sont retirés de la pioche, jamais dupliqués. Aucun nouveau tirage gratuit par fermeture d'écran. La défausse des cartes non jouées reste recyclable ; les cartes consommées en sont retirées. La main et l'ouverture préparée sont des changements supplémentaires à évaluer séparément si l'on veut isoler les effets du système économique.

## Distribution des cartes

Le volume garanti finance le fonctionnement ordinaire. La rareté, les affinités et les choix créent la progression.

| Rencontre | Exemplaires | Structure proposée |
|---|---:|---|
| Normale | 6 | 4 communs, 1 inhabituel, 1 emplacement variable |
| Élite | 9 | 4 communs, 3 inhabituels, 1 rare, 1 variable |
| Boss final | Hors budget de run | Récompense de fin / déblocage éventuel |

Distribution de l'emplacement variable :

| Partie de run | Commun | Inhabituel | Rare | Épique |
|---|---:|---:|---:|---:|
| Premier tiers | 65 % | 30 % | 5 % | 0 % |
| Deuxième tiers | 45 % | 40 % | 15 % | 0 % |
| Dernier tiers | 25 % | 45 % | 25 % | 5 % |

La cinquième rareté, exceptionnelle, relève d'offres ou de récompenses spéciales explicites. Elle n'est pas nécessaire à la viabilité d'un build. Un quota garantit une offre épique avant le dernier refuge : pas forcément la carte désirée, mais une occasion réelle de montée en puissance.

Les contraintes fonctionnelles sont appliquées avant le tirage des identités : au moins une attaque, une défense et une mobilité ou contrôle dans chaque paquet normal ; au moins quatre des six cartes immédiatement utilisables avec les maîtrises actuelles. Le générateur dispose de familles communes de repli pour satisfaire ces contraintes. Les autres cartes peuvent ouvrir une diversification sans remplir le stock de cartes injouables.

Répartition indicative des identités : moitié affinités déclarées par le joueur, un quart table de la route, un quart découverte. Il s'agit de poids corrigés par les garanties, pas de probabilités finales indépendantes. Le joueur déclare deux affinités, modifiables aux refuges. Il voit ce biais dans l'interface.

Après victoire, choix entre trois paquets préconstruits de même volume et même profil de rareté : équilibré, orienté première affinité, orienté seconde affinité. Les cartes sont visibles. Un seul paquet est acquis, pas dix-huit cartes. Pas de relance gratuite. Une sélection remplace six confirmations successives.

Pas de butin proportionnel au nombre de cartes jouées, de victimes invoquées ou de tours passés. Pas de baisse du ravitaillement après une mauvaise performance. Les tables sont attachées à la rencontre, enregistrées et attribuées une seule fois.

## Une monnaie, trois fonctions économiques

Les oboles achètent du volume, de la précision ou de la puissance. La vente récupère une fraction de valeur ; le troc remplace des cartes peu pertinentes par des cartes utiles. Aucune poussière de fabrication nécessaire.

| Rareté | Achat ciblé | Revente | Crédit de troc |
|---|---:|---:|---:|
| Commune | 8 | 2 | 1 |
| Inhabituelle | 16 | 4 | 2 |
| Rare | 32 | 8 | 4 |
| Épique | 64 | 16 | 8 |
| Exceptionnelle | 96 | 24 | 12 |

Le crédit de troc n'est pas une monnaie stockée. Il ne sert qu'à évaluer les cartes déposées dans une transaction. Obtenir une carte du catalogue de troc coûte deux fois son crédit : deux communes pour une commune choisie ; une rare pour deux communes choisies ou une inhabituelle. Pas de crédit résiduel conservé : le panier doit être exact ou l'interface propose de retirer les cartes excédentaires.

Cette règle est simple, mais volontairement défavorable en quantité : on paie la certitude. Offres de troc limitées aux communes et inhabituelles au départ ; catalogue visible et stock fini. Les cartes de même rareté doivent avoir une valeur situationnelle comparable, faute de quoi le troc devient toujours la même conversion optimale.

Paquet de ravitaillement : **six communes pour 36 oboles**, moins cher que six achats ciblés à 48. Le joueur choisit une orientation fonctionnelle, pas six noms précis. Composition visible avant achat. Deux paquets disponibles à chaque point de ravitaillement, plus des cartes à l'unité. Revente du paquet : douze oboles, donc perte de vingt-quatre, jamais profit immédiat.

Les services de précision fournissent le principal supplément : commander une carte exacte pour la halte suivante coûte le prix normal plus 25 %, payé à la commande. Une commande par halte, sans création de rareté inaccessible à ce stade. Avant le boss, livraison immédiate possible au même tarif si le catalogue l'autorise. Une transaction ne peut pas être remboursée après livraison ou réutilisation d'un exemplaire.

## Créativité économique : plusieurs usages d'un même stock

**Le comptoir de commandes.** Programmer la réception de deux pièces d'un combo transforme la route en plan de préparation. Le coût est la précision et l'immobilisation d'oboles avant livraison.

**Les commandes de collectionneur.** Une offre visible demande un ensemble précis, par exemple deux communes de mobilité et une rare de contrôle, contre une épique déterminée. Le crédit d'entrée vaut six contre huit en sortie : c'est une subvention ponctuelle, volontaire. Une seule exécution, budget maximal de subvention par run, aucun renouvellement. Cette exception est distinguée du troc ordinaire et ne doit pas entrer dans un cycle répétable.

**La compression.** Deux exemplaires communs identiques deviennent un exemplaire amélioré, uniquement si une variante supérieure existe. Même valeur totale théorique de revente, moins de charges, davantage de puissance par carte et par place de deck. La variante ne doit pas être strictement meilleure dans tous les combats. Disponibilité limitée au refuge ; aucune décompression.

**Les lots de déstockage.** Un lot visible de dix communes disparates à cinquante oboles permet de préparer un gros combat à faible coût. Maximum une offre spécifique par run. Le prix réduit achète du volume au prix de la cohérence. Ne pas activer cette offre dans le premier calcul de référence pour conserver une base lisible.

**Le pari de préparation.** Dépenser pour un deck compact de seize à vingt cartes très cohérentes ou acheter trente charges variées. Ce choix n'a de sens que si le jeu annonce la nature et la longueur approximative de la prochaine rencontre.

## Budget de référence et calendrier

Hypothèses conservées à partir des indications de récompenses du projet : 35 oboles par combat normal, 65 par élite. Nouvelle dotation proposée : 40 oboles au départ. Pour huit normaux et trois élites, cela donne 515 oboles avant la fin. Les autres événements, ventes et récompenses ne sont pas inclus.

Quinze exemplaires au départ + 8 × 6 + 3 × 9 = 90 exemplaires. Le boss final ne rembourse pas sa propre préparation.

Points de ravitaillement proposés après les combats 3, 5, 7, 10 et 11. Les derniers correspondent aux refuges et à la préparation finale ; le premier est un ajout à assurer dans la route. C'est une condition du modèle, pas une disponibilité actuelle garantie.

Calcul séquentiel exécuté : à chacun de ces points, acheter des paquets de six jusqu'à disposer d'au moins quinze exemplaires. Aucun achat si le stock atteint déjà quinze. Même ordre de combats que la route de référence : N N N N E N E N N E N B. Les paquets disponibles sont suffisants pour les achats calculés, au maximum deux au même arrêt.

| Profil supposé | Dépense N / E / B | Cartes consommées | Cartes achetées | Coût | Stock final | Oboles restantes |
|---|---|---:|---:|---:|---:|---:|
| Sobre | 4 / 6 / 10 | 60 | 0 | 0 | 30 | 515 |
| Central | 6 / 9 / 12 | 87 | 0 | 0 | 3 | 515 |
| Intensif | 9 / 12 / 15 | 123 | 36 | 216 | 3 | 299 |

Le profil intensif achète douze cartes après le troisième combat, puis six aux arrêts suivants. Il dépense 72 oboles au premier arrêt, où il en possède 145. Il atteint parfois zéro carte juste après sa dépense de combat : le financement est possible, mais la marge tactique est faible. Une carte inutilisable ou un combat plus long peut changer le résultat.

Ces résultats démontrent seulement une cohérence comptable et temporelle pour ces dépenses supposées. Ils ne démontrent ni victoire, ni pioche favorable, ni qualité suffisante du ravitaillement commun. Le scénario mélange librement les cartes par utilité et ne simule pas leur rang, leurs PA ou leurs restrictions.

## Autres dépenses et progression

Ne pas ajouter automatiquement 515 oboles de nouvelles dépenses au jeu actuel : ces revenus ont déjà des usages. Il faut arbitrer les prix de découverte de branches, soins, équipement et consommables ensemble.

Pour la variante, la progression indispensable du personnage vient des combats et des choix de maîtrise. Elle ne dépend pas de l'achat continu de cartes ni d'un investissement monétaire obligatoire. L'or restant finance des avantages concurrents : soin, service de préparation, équipement, carte rare ciblée. Une enveloppe illustrative de 200 à 250 oboles pour plusieurs dépenses annexes laisserait le profil intensif viable dans le scénario, sans prouver que les prix actuels conviennent.

Le joueur sobre conserve davantage d'argent et de stock, mais doit accepter des risques ou un coût tactique pour économiser ses bonnes cartes. Si les actions d'arme permettent d'économiser sans conséquence et sans intérêt, la stratégie sobre domine et ralentit le jeu. Cette question ne se règle pas seulement en augmentant les prix : il faut examiner la durée, la pression ennemie et la valeur des cartes jouées.

## Vérifications indispensables avant adoption

1. Cartes effectivement jouées par combat, selon classe, difficulté et expérience du joueur ; distribution des dépenses, pas seulement moyenne.
2. Proportion réellement jouable du stock, mains sans solution et épuisement avant victoire.
3. Valeur tactique des cartes communes en fin de run : le ravitaillement ne fonctionne pas si elles deviennent inutiles.
4. Temps passé en préparation, fréquence des decks à trente et cartes jamais choisies.
5. Fréquence des ventes et commandes ; circuits vente/troc/compression/remises sans profit répétable.
6. Oboles restantes, dépenses annexes sacrifiées et cartes rares conservées sans jamais être jouées.
7. Génération des paquets avec contraintes compatibles ; pas de rareté ou de fonction rendue impossible par les maîtrises.
8. Sauvegarde atomique des consommations et transactions, attributions uniques, absence de relance par rechargement.

Le premier prototype devrait se limiter à réserve, deck trente, consommation, paquets garantis, achat/revente et troc simple. Commandes spéciales et compression sont des extensions à tester individuellement. Les paramètres économiques sont conçus pour être ajustables ; aucun n'est présenté comme un équilibre acquis.
