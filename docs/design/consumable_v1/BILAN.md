# Bilan de la V1 théorique

La proposition ferme un système de cartes réellement consommables, alimenté par des sacs sur les mobs. Elle dispose maintenant d’un résolveur tactique, de tables complètes et de résultats reproductibles. **Elle est prête à être portée dans un prototype Godot et soumise à des joueurs ; elle n’est pas déclarée équilibrée pour publication.**

## 1. Ce qui a changé grâce aux essais

Le premier modèle comptable pouvait financer une run en moyenne tout en laissant mourir certaines classes avant le premier marchand. La V1 garantit un petit sac de deux normales par mob, ajoute un deuxième sac de fréquence croissante et réduit le saut de PV ennemis aux combats 2 et 3. Ce réglage conserve 108,1 normales attendues avant le boss pour 32 morts éligibles ; il déplace surtout leur régularité et leur arrivée.

À 32 morts éligibles, l’ancienne distribution de normales donnait une espérance de 108 et une variance de 88,695 ; la nouvelle donne 108,1 et 24,87. La variance baisse d’environ 72 % à volume presque identique. Au premier mob, le risque de zéro normale passe de 21,25 % à zéro. Cela garantit du ravitaillement, pas la famille idéale.

Le premier Gardien défendait correctement mais payait trop de copies pour finir les combats. Son nouveau renvoi de 0,25 P, une fois par tour après absorption, rend la défense productive dans l’économie de run. Il remplace le bonus de poussée initial. Sur les mêmes 25 graines, Bastion passe de 3 à 19 victoires, Broyeur de 10 à 17. Les données de la révision défavorable restent dans [le résumé R1](iteration_r1_run_summary.csv).

Les investissements sont attachés aux familles, afin qu’une amélioration survive à la consommation de la copie qui a motivé le choix. La rareté augmente l’efficacité par exemplaire ou ouvre une option spéciale ; elle ne remplace pas automatiquement toutes les normales par des multiplicateurs de dégâts.

## 2. Résultats principaux

Politique de recherche à deux actions, 25 graines par spécialisation, préparations initiales fixes, cinq marchands, deck préparé jusqu’à vingt cartes. Les intervalles sont des Wilson à 95 %, arrondis ici ; ils ne décrivent pas des joueurs humains.

| Classe / spécialisation | Victoires | Taux | Intervalle approximatif | Cartes consommées moyennes, toutes tentatives | Réserve finale médiane des vainqueurs |
|---|---:|---:|---:|---:|---:|
| Assassin / Exécution | 24/25 | 96 % | 80–99 % | 73,84 | 36 |
| Assassin / Embuscade | 23/25 | 92 % | 75–98 % | 72,56 | 36 |
| Gardien / Bastion | 19/25 | 76 % | 57–89 % | 88,28 | 27 |
| Gardien / Broyeur | 17/25 | 68 % | 48–83 % | 82,92 | 26 |
| Arpenteur / Tireur | 23/25 | 92 % | 75–98 % | 84,36 | 33 |
| Arpenteur / Escarmouche | 20/25 | 80 % | 61–91 % | 90,84 | 28 |
| Thaumaturge / Brasier | 18/25 | 72 % | 52–86 % | 84,56 | 24 |
| Thaumaturge / Givre | 16/25 | 64 % | 45–80 % | 80,44 | 27 |

La comparaison confirme que les quatre classes peuvent parcourir cette route. Elle ne démontre ni égalité entre classes ni difficulté finale satisfaisante. L’Assassin reste favorisé dans ce modèle ; le Thaumaturge/Givre et les variantes défensives méritent des tests humains prioritaires. Les intervalles sont larges et les vingt-cinq graines ne couvrent pas tous les builds.

Une réserve finale de 24 à 36 copies chez les vainqueurs n’est pas automatiquement du gaspillage : il faut pouvoir changer la préparation. Elle signale néanmoins un risque de tri répétitif et de stock devenu sans valeur. Le prochain prototype doit mesurer le temps passé à préparer, pas seulement augmenter un plafond de vente.

Les [variantes appariées et l’exemple de run complet](COMPARAISONS_RUN.md) comparent sur les mêmes dix graines la présence des rares, marchands, équipements et reliques, les préparations 15/20/30 et les différentes politiques. La référence de ce tableau utilise les mêmes dix graines, pour éviter de comparer artificiellement un groupe de dix à une moyenne de vingt-cinq.

Sans rares ni catégories supérieures, les quatre classes réussissent encore 8 ou 9 runs sur 10 dans ce lot. La limite de quinze cartes préparées pénalise surtout le Gardien : 1/10 contre 8/10 avec vingt. Il faut donc distinguer les **quinze cartes de départ** d’une limite permanente à quinze : la consommation crée aussi un besoin de capacité pour les longs combats. Trente donne davantage de réserve engagée mais dilue les familles investies ; vingt reste la proposition de préparation par défaut, trente le plafond.

Le témoin qui ne joue aucune carte échoue sur ses quarante tentatives. Une [borne analytique du boss](MATHS_ET_RUN.md) complète ce résultat : même en accordant le meilleur renvoi défensif, un Miroir et la puissance maximale, les gestes de secours ne fournissent pas assez de dégâts avant que la pression soit létale. Cette conclusion est propre au catalogue V1.

La monnaie restante moyenne des séries principales se situe approximativement entre 196 et 240 or, mais les tentatives interrompues et le choix automatique des achats rendent ce chiffre difficile à interpréter isolément. La politique n’achète pas de reliques et garde un coussin pour les sacs ; on ne peut pas conclure que les prix sont trop faibles sans comparer de vraies décisions d’achat.

## 3. Couverture et niveau de preuve

| Domaine | Vérification réalisée | Ce qu’elle ne démontre pas |
|---|---|---|
| 48 cartes | 2 304 cas : quatre niveaux, six contextes, base/améliorée ; résolution et comparaison avec témoin | Toutes les séquences possibles de cartes |
| 18 équipements, 8 reliques, 8 spécialisations | 672 comparaisons appariées sur trois rencontres et deux graines par classe | Rentabilité universelle du prix ou préférence des joueurs |
| Cumul d’objets | 135 paires d’équipement, 729 ensembles complets pour les bornes ; 28 paires de reliques sur cinq effets | Exhaustivité de toutes les parties avec tous les ensembles |
| Stats | 336 répartitions de six points sur douze niveaux, formules et bornes | Performance complète de chacune des 336 répartitions en run |
| Drops | 192 probabilités famille/classe ; espérances, variances, chances de découverte | Satisfaction face à une longue malchance |
| Économie | Stocks finis, coût des transactions, atomisation, reprise, conservation des copies et cycles déficitaires | Équilibre d’un marché multijoueur, absent du concept |
| Runs | 640 runs finales, douze variantes, graines identifiées et trajectoires enregistrées | Taux de victoire humain, rétention ou plaisir |
| Tests | 199 contrôles V1 + 13 du laboratoire : **212/212 réussis**, aucun ignoré | Import, rendu et intégration Godot |

Les scénarios de cartes peuvent être illégaux volontairement, par exemple la stase sans marque. Ils vérifient alors le refus et le témoin. Un cas calculé n’est pas compté comme un lancement réussi. Les coefficients et résultats par famille restent consultables dans [card_summary.csv](card_summary.csv).

## 4. Ce que disent les objets

Le Sceau du chasseur économise environ 0,96 copie par rencontre du lot contrôlé ; l’Éclat téméraire environ 0,75, avec son coût en PV max. Ces moyennes ne sont pas des rendements garantis sur une run. Le Pendentif écarlate et la Coupe donnent surtout plus de santé finale, de l’ordre de quatre points de pourcentage sur ce lot. La Cuirasse pesante peut faire perdre du rendement malgré sa protection : perdre un PM change les lignes d’attaque.

Le Fil du détour ne modifie aucune des 24 rencontres automatiques de sa comparaison finale. Son effet passe un test fonctionnel, et un scénario supplémentaire montre un déplacement suivi d’une attaque de mêlée impossible sans le PM rendu. **Décision :** garder l’outil de mobilité à usage précis, et signaler sa fréquence d’utilité comme non démontrée. Il serait incorrect de le déclarer équilibré au seul motif que son code fonctionne.

Les 24 combats témoins de ce lot reçoivent volontairement un deck fourni en normales et élites. Toutes les différences de victoire y sont nulles : le lot mesure surtout les copies, PV et tours économisés et présente un effet de plafond. Il ne remplace pas les runs avec pénurie de stock. Les colonnes complètes sont dans [item_summary.csv](item_summary.csv).

## 5. Valeur et disponibilité des raretés

Sur une route finie avec 32 morts éligibles avant le boss : rare présente dans environ 67,8 % des runs théoriques, légendaire 11 %, dieu 1,31 %, immortelle 0,14 %. Ces probabilités de présence ne sont pas celles d’une **famille précise** ; [family_drop_math.csv](family_drop_math.csv) calcule chacune d’elles.

La progression et les identités reposent sur normales/élites. Dieu et immortel sont des surprises, pas des objectifs nécessaires pour débloquer une classe. Leur fréquence peut être trop basse pour une V1 commerciale qui voudrait faire découvrir tout le catalogue rapidement ; le socle garde la rareté demandée, avec cette conséquence visible. Un objectif futur de découverte fréquente demanderait un autre réglage explicite.

Le nom « immortel » désigne une rareté : Seconde aurore ne rend pas invulnérable et ne réimprime pas le deck. Décret évite un impact létal seulement. Leur texte doit empêcher toute promesse implicite de victoire automatique.

## 6. Limites du contrôle automatique

La menace estimée ne simule pas exactement chaque chemin ennemi ni chaque choix humain de terrain. L’anticipation s’arrête à deux actions parmi les suites des six meilleurs premiers choix. Le contrôleur de préparation privilégie certains rendements immédiats et n’invente pas de plan de deck à long terme. Les achats n’explorent pas toutes les offres. Les tirages du même numéro de graine peuvent diverger après consommation ou achat différents.

Les politiques à une action échouent beaucoup plus souvent, parfois en reculant sans finir l’ennemi. Ce résultat mesure notamment leur myopie. Les utiliser comme modèle de « joueur débutant » serait abusif. Le témoin économe teste aussi une peur de consommer très élevée, pas une maîtrise experte de l’économie.

Les runs finales utilisent des graines différentes des dix graines de réglage initiales. Elles ont toutefois servi à constater le défaut de la révision R1 puis à vérifier la révision du Gardien : il s’agit d’une **validation interne réutilisée**, pas d’un test aveugle entièrement neuf après toutes les décisions. Une mesure externe demanderait de nouvelles graines et des joueurs. Cette distinction empêche de surestimer la force statistique de l’amélioration.

## 7. Points de vigilance avant publication

1. Le coût émotionnel de consommer une rare : aucune preuve humaine disponible. Préparer une session où l’utiliser sauve une situation, puis écouter le raisonnement du joueur.
2. Le tri de réserve : vérifier que la diversité rend la préparation intéressante et ne crée pas une corvée après chaque combat.
3. La pression au tour 9 : elle résout l’attente indéfinie mais peut pénaliser des joueurs réfléchis si l’information est mal présentée. Elle porte sur les tours, jamais sur un chronomètre réel.
4. Les identités défensives : le renvoi résout un déficit dans ce modèle ; vérifier que le Gardien reste plaisant sans devenir une routine garde–secours.
5. Les bonus de mobilité et la géométrie : les plateaux Godot réels peuvent rendre un PM bien plus important, ou moins, que les petits plateaux du laboratoire.
6. L’ergonomie des améliorations de famille et des cartes étrangères : ces règles doivent être comprises avant de comparer les taux de réussite.
7. Les prix : fermés, sans arbitrage positif, mais pas optimisés à partir de préférences humaines. Un test marchand doit proposer plusieurs achats réellement désirables.

La priorité suivante est donc un port fidèle et observé de cette V1, en suivant [le guide de reprise](REPRISE_REPO.md). Les réglages, les effets et les cas de test sont préparés ; la validation dans le produit et auprès de joueurs reste identifiée comme un travail distinct.
