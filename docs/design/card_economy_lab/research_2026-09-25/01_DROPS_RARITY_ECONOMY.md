# 1 — Drops, raretés, préparation et économie

Statut : recherche et propositions, 25 septembre 2026. [Sources](SOURCES.md) · [Calculs](MATH_RESULTS.md) · [Vue d'ensemble](README.md).

## 1.1 Le problème à résoudre

Le joueur dépense une ressource pour gagner le combat qui reconstitue cette ressource. Il faut donc équilibrer **le moment des entrées**, leur quantité et leur utilité. Une run peut distribuer beaucoup de cartes au total et devenir impossible à financer avant le premier refuge. Elle peut aussi être finançable mais pénible, si la bonne stratégie consiste à économiser chaque carte pendant des tours de gestes de secours.

La carte consommable paie simultanément trois coûts : PA pendant le tour, place dans le deck, exemplaire retiré de la run. Une carte à zéro PA n'est donc pas gratuite ; inversement, une carte chère en PA peut être très économique en exemplaires si elle règle plusieurs menaces.

**Contrat proposé pour le prototype :** seule une carte effectivement jouée et résolue est consommée. Une action annulée avant validation ne détruit rien. Une carte non jouée retourne au stock de préparation après le combat. L'interface distingue immédiatement dépense de PA et consommation définitive. La fuite, l'annulation après résolution, la perte d'une sauvegarde et les cartes générées demandent des règles explicites avant implémentation.

## 1.2 Ce que le dépôt possède déjà

Le [catalogue de drop](../../../../core/expedition/card_drop_catalog.gd) effectue des jets **par victoire**, pas un jet par mob. Une réussite fournit une carte, pas un sac. Les chances dépendent de profondeur, danger et victoires sans carte. Au premier combat : 49 % et 16 %, soit 0,65 carte moyenne et 42,84 % de zéro carte. Ce système convient à une acquisition de cartes durables ; il ne suffit pas à financer une consommation de plusieurs exemplaires par combat.

Deux bonnes propriétés à conserver : la rareté est choisie sans dilution par le nombre de familles de son palier ; le tirage/reçu déterministe évite de regagner ou relancer le butin en rechargeant. Le biais actuel de 70 % vers la classe principale **n'est pas un taux de cartes légalement jouables** : une carte d'une autre classe peut utiliser le rang de maîtrise zéro.

L'initiation est actuellement exclue du butin. Il faut donc décider si les « normales faibles » du nouveau concept correspondent à de nouvelles familles ou à une nouvelle politique d'acquisition des starters. Renommer Usuelle en Normale sans traiter ce point laisserait une rupture de stock invisible.

## 1.3 Une architecture de drop codifiée

Chaque ennemi naturel inscrit dans la rencontre reçoit une identité de butin. À sa première défaite validée : plusieurs canaux indépendants peuvent produire des sacs. L'attribution peut rester groupée à la victoire pour éviter les manipulations d'inventaire en combat ; l'origine reste le mob. Pas de copie de ses techniques nécessaire.

Ordre proposé :

1. Éligibilité de l'ennemi : naturel, invoqué, ressuscité, déjà récompensé.
2. Jets des sacs par canal et palier de progression.
3. Quantité fixée par le type de sac.
4. Pool de familles autorisées par biome et palier.
5. Choix de la famille au sein de ce pool, avec poids documentés.
6. Attribution d'identifiants uniques aux exemplaires et d'un reçu immuable.

La graine peut combiner run, rencontre, ennemi et canal ; ouvrir plus tard un sac ne doit pas permettre de changer son résultat en rechargeant. Les invocations et résurrections ne créent pas de nouvelles identités rémunérées. Ces règles ne sont pas des détails : sans elles, la meilleure économie peut devenir une boucle de reproduction d'ennemis.

Séparer les canaux normaux et rares évite qu'une légendaire remplace la nourriture du deck. « Trouver une merveille et manquer ensuite de cartes ordinaires » serait une punition associée à la chance.

## 1.4 Les probabilités qui ont un sens pour le joueur

Pour un canal de probabilité `p`, un sac de `b` cartes et `n` ennemis indépendants :

```text
E[cartes] = n × b × p
Var[cartes] = n × b² × p × (1 − p)
P(au moins un sac) = 1 − (1 − p)^n
P(zéro normale avec deux canaux A/B) = [(1 − pA)(1 − pB)]^n
```

Même espérance ne signifie pas même expérience. Un sac de trois cartes à 50 % donne 1,5 carte moyenne, variance 2,25. Trois jets indépendants de cartes à 50 % donnent aussi 1,5 carte, variance 0,75. On peut conserver visuellement des sacs tout en choisissant consciemment leur variance ; changer la présentation seule ne change pas le hasard sous-jacent.

Les pourcentages de nos canaux peuvent dépasser 100 % lorsqu'on les additionne : plusieurs sacs peuvent tomber sur le même ennemi. Ce ne sont pas des choix mutuellement exclusifs. Il faut l'écrire dans la définition de données et dans l'explication au joueur.

Pour une carte précise, multiplier seulement des probabilités **conditionnelles cohérentes** : obtention du sac, famille dans son pool, sélection dans le deck, pioche avant le besoin, pertinence de la situation. Ne pas supposer que ces événements sont indépendants. Un faible taux de jeu peut provenir de la pioche ou des rencontres, même avec un bon taux de drop.

## 1.5 Progression standard : le test corrigé

La variante historique `early_supply` passait de 75/15 % à 70/10 % pour les deux sacs normaux. Elle est conservée comme expérience isolée, mais ne respecte pas la croissance souhaitée.

Nouvelle **courbe candidate de laboratoire**, par ennemi :

| Combats | Normal A, 3 cartes | Normal B, 3 cartes | Élite, 2 cartes | Rare, 1 | Légendaire, 1 | Dieu, 1 | Immortel, 1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1–3 | 75 % | 15 % | 5 % | 0,5 % | 0 | 0 | 0 |
| 4–6 | 80 % | 20 % | 10 % | 1,5 % | 0,1 % | 0 | 0 |
| 7–9 | 90 % | 30 % | 18 % | 4 % | 0,4 % | 0,03 % | 0 |
| 10–12 | 95 % | 45 % | 28 % | 8 % | 1 % | 0,15 % | 0,02 % |

Les rangs supérieurs restent ceux du premier laboratoire. Aucun modificateur de maîtrise, prospection, équipement, relique ou performance n'est ajouté. Les effectifs sont ceux de la branche Airain et le butin du boss final ne finance pas la run.

Cette courbe donne **108 normales attendues avant le boss**, contre 93 auparavant. Elle finance 98,845 % des parcours du profil central quand toutes les cartes reçues sont utilisables, contre 73,135 % avec la base, sur 20 000 simulations par cas. Mais les parcours financés terminent avec une médiane de **50 cartes** restantes. Avec seulement 70 % des drops traités comme utiles, le même financement tombe à 65,670 % sans magasin. Détails et limites dans [les résultats](MATH_RESULTS.md).

**Conclusion : augmenter les drops corrige une partie du début sans résoudre l'économie.** Il faut mesurer la consommation réelle et la pertinence des familles avant de fixer cette table. Le surplus pourrait servir au troc, mais ne justifie pas automatiquement sa propre existence.

Des taux croissants par ennemi ne garantissent pas des récompenses croissantes par combat : un groupe de deux élites peut donner moins de cartes qu'un groupe précédent de trois ennemis. Distinguer « progression des taux » et « progression du budget de rencontre ». Commencer par publier les deux courbes ; seulement ensuite tester un poids de butin d'élite, en comptant des ennemis équivalents, plutôt que multiplier plusieurs bonus opaques.

## 1.6 Rareté : fréquence, complexité et puissance

Dans la table initiale et la candidate, avant le boss Airain :

| Rang | Cartes attendues | Probabilité d'au moins un sac |
|---|---:|---:|
| Élite | 9,76 | Calcul exact disponible dans la sortie détaillée |
| Rare | 1,10 | 67,77 % |
| Légendaire | 0,116 | 10,99 % |
| Dieu | 0,0132 | 1,312 % |
| Immortel | 0,0014 | 0,1399 % |

Pour Immortel, il faudrait environ **2 140 runs indépendantes complètes** pour avoir 95 % de chances d'en avoir vu au moins un avant le boss. Les abandons rendent l'accès effectif encore plus faible. Un tel rang ne peut pas être une pièce nécessaire d'un build standard ni absorber une grosse part du travail de contenu. C'est un choix de fantasme exceptionnel, pas une progression que l'on peut promettre pendant une run.

Proposition de fonction des rangs, sans supprimer les six noms demandés :

| Rang | Fonction de conception | Piège à éviter |
|---|---|---|
| Normale | Verbe fiable : frapper, couvrir, pousser, avancer ; faible rendement mais toujours une situation utile | Carte systématiquement dominée, vendue sans réflexion |
| Élite | Meilleur rendement conditionnel ou combinaison simple de deux verbes | Même carte avec tous les chiffres supérieurs au même coût |
| Rare | Ouvre une séquence ou change la géométrie d'un tour | Build complet impossible sans sa découverte |
| Légendaire | Résout une crise avec une contrainte visible | Bouton universel qui dispense d'observer la carte |
| Dieu | Exception spectaculaire sur une scène ou un objectif | Bonus permanent démultipliant tous les futurs drops |
| Immortel | Événement mémorable, règles très explicites ; exemplaire toujours consommé | « Immortel » compris comme usage infini ; contenu obligatoire quasiment invisible |

Une normale peut gagner en valeur avec une relique, un terrain ou un besoin précis. Sa faiblesse doit être un rendement modeste, pas l'absence d'intérêt. Magic a précisément distingué complexité et profondeur dans son travail sur les communes ; la rareté n'est pas une obligation d'accumuler des lignes de texte. [S10 — New World Order](https://magic.wizards.com/en/news/making-magic/new-world-order-2011-12-05).

## 1.7 Trouver des doublons : protection ou ravitaillement ?

Hearthstone a étendu en 2020 la protection contre les doublons aux différentes raretés tout en conservant leurs fréquences. C'est utile pour compléter une collection. Chez nous, deux copies de poussée peuvent être précisément le ravitaillement désiré. Copier cette protection empêcherait potentiellement le joueur de renouveler son outil préféré. [S19 — patch 17.0](https://hearthstone.blizzard.com/en-us/news/23357896).

Séparer, si nécessaire, le registre de **découverte d'une famille** et le stock d'**exemplaires disponibles**. Une aide à la découverte ne doit pas interdire les doublons consommables. Premier prototype : pools courts, doublons autorisés, familles connues affichées par biome. Le ciblage se fait en choisissant une destination ou en troquant, sans remplacer le drop par un choix de trois récompenses.

Le minimum jouable mérite une variance plus faible que le jackpot. PoE 2 a travaillé séparément qualité, protections de boss et variance des conteneurs, puis recalibré les bonus de rareté du joueur lorsque leur effet aurait grandi indirectement. Notre application : suivre indépendamment pénurie de normales et accès aux rangs rares. [S05 — 0.2.0g](https://www.pathofexile.com/forum/view-thread/3774647).

## 1.8 Préparer le deck : trente est un plafond, pas un objectif

Avec quatre cartes en main, une copie unique apparaît à l'ouverture dans 26,67 % des decks de quinze, contre 13,33 % des decks de trente. Même trois copies ne donnent que 35,96 % dans trente cartes, contre 63,74 % dans quinze. Ajouter des cartes protège contre l'épuisement mais dilue les réponses : c'est une vraie tension, à condition d'être comprise.

Proposition : deck de préparation séparé de la réserve ; quantité par famille visible ; estimation du coût en PA de la main ; deux ou trois intentions de préparation enregistrables (« mobile », « contrôle », « boss »), jamais une consommation automatique de copies sans aperçu. Une grosse réserve peut rester rangée par piles, pas par dizaines d'icônes individuelles.

Ne pas imposer artificiellement trente cartes pour absorber les drops. Mesurer plutôt : taille choisie, nombre de familles, réponse absente au moment critique, cartes jamais piochées, temps de préparation et stock conservé jusqu'à la défaite.

## 1.9 Économie : les sources, usages et échanges

Pour la première version, une économie **interne à la run** est plus vérifiable : mobs → cartes/or ; marchand → sélection/ravitaillement ; troc → conversion de familles ; consommation → retrait des exemplaires. La persistance après la run reste une décision produit ouverte. Un marché entre joueurs introduirait un autre système ; il n'est ni implicite ni simulé.

Les factions de Last Epoch illustrent pourquoi butin individuel et marché global sont difficiles à équilibrer ensemble. Le projet de 2023 propose des avantages distincts ; la documentation actuelle conserve des restrictions au butin de Circle of Fortune. À notre échelle, des achats et un troc local suffisent pour tester l'intérêt économique, sans importer tout cet appareil. [S08 — conception](https://forum.lastepoch.com/t/trade-development-update-introducing-merchants-guild-and-circle-of-fortune-factions/51994), [S09 — documentation](https://support.lastepoch.com/hc/en-us/articles/46363322928283-Circle-of-Fortune).

Trois fonctions doivent garder des coûts différents :

| Opération proposée | Ce que le joueur achète réellement | Premier réglage à tester |
|---|---|---|
| Sac normal marchand | Sécurité quantitative avec contenu encore aléatoire | Lot de 6 à 36 or, stock limité ; hypothèse héritée du laboratoire |
| Carte normale précise | Certitude de la fonction | 8 or pièce, soit plus que les 6 or/cartes du sac |
| Troc de normales | Changement de composition, pas création de valeur | 3 normales contre 1 normale ciblée ; offre fixe par visite |
| Revente d'excédent | Liquidité partielle | 1 or par normale ; conserver une décote forte |
| Amélioration d'équipement | Économie future de PV ou d'exemplaires | Prix à comparer au nombre de combats restants, pas seulement à sa rareté |

Ces prix ne sont pas validés. Ils rendent seulement le choix concret. Le cycle achat de 6 cartes à 36 puis revente à 1 rapporte 6, donc ne s'auto-finance pas. Un troc 3→1 avec revente à 1 détruit de la quantité. Toute nouvelle recette, remise ou relique monétaire doit être auditée sur le graphe des conversions : aucun cycle ne doit produire gratuitement cartes, or ou améliorations.

Conserver des débouchés limités au surplus : échange ciblé, contrat de fourniture annoncé avant le combat, don contre un avantage de route. Éviter que chaque normale devienne un fragment universel permettant de fabriquer les rangs divins : les grandes quantités banaliseraient les raretés et feraient du tri une obligation.

## 1.10 Le coût caché d'un bonus de puissance

Dans un combat à exemplaires consommés, tuer en deux cartes au lieu de trois économise aussi une carte pour plus tard. Un équipement offensif peut alors gagner sur trois plans : moins de tours ennemis, moins de PV perdus, moins de cartes dépensées. Un équipement défensif peut au contraire encourager à économiser les cartes par des gestes gratuits plus lents. C'est une boucle de richesse, même sans aucun bonus de drop.

Mesurer le coût total d'une rencontre : `cartes dépensées + coût des soins + temps + options sacrifiées`. Il n'existe pas encore de taux de conversion commun validé ; le tableau doit montrer ces dimensions séparées. Le modèle actuel n'achète ni équipement ni soins : son argent disponible est donc optimiste.

Le débat autour des idoles de DOFUS rappelle au moins un point de méthode : modifier un gros bonus exige de revoir les autres entrées de l'économie. L'article consulté annonçait plusieurs chantiers liés ; il ne suffit pas à démontrer leur résultat. Nous retenons ici la nécessité d'un bilan global. [S04 — annonce de 2023, source secondaire](https://www.gamosaurus.com/jeux/dofus/les-idoles-sont-supprimees-de-dofus).

## 1.11 Garde-fous et expériences prioritaires

1. Tester le financement **avant chaque combat**, pas seulement le solde final. Le butin d'une victoire future n'est pas une ressource disponible maintenant.
2. Comparer les normales toutes utiles à des pools réalistes. Le paramètre 70 % reste un stress arbitraire, pas une observation.
3. Tester un troc ciblé sans augmentation de drop ; mesurer s'il améliore l'utilisation du stock mieux qu'une pluie supplémentaire de cartes.
4. Observer la rétention de rares jusqu'à la mort. Une carte conservée peut être une assurance rationnelle ou une frustration ; demander ce que le joueur attendait pour la jouer.
5. N'ajouter aucun modificateur de drop avant d'avoir une base qui fonctionne pour plusieurs classes. Si prospection arrive ensuite : budget d'opportunité, plafonds et effet explicite par canal ; pas une multiplication commune cachée.

Le retour des jetons de donjon dans la lettre WAKFU de 2014 répondait à l'incertitude d'accès aux objets. Pour notre run courte, le premier filet possible est un accès de ravitaillement connu ou du troc de normales. Une garantie de rare, un compteur de malchance ou une récompense de boss resteraient des variantes séparées, pas des ajouts silencieux à la table standard. [S03 — lettre de 2014](https://wakfu.jeuxonline.info/actualite/45655/lettre-communaute-septembre-2014).
