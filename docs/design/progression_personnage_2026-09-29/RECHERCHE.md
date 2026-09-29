# Enquête — comment faire grandir un personnage ?

29 septembre 2026. Enquête de conception, sources consultées et versions distinguées ci-dessous. La recommandation pour Dungeon Draft se trouve dans [README](README.md), avec les calculs reproductibles dans [calculs.py](calculs.py).

## 1. Les décisions que cache le mot « progression »

Un niveau peut augmenter les chiffres, ouvrir des actions, fournir une monnaie à répartir ou modifier les règles d'un personnage. Ces fonctions ne doivent pas nécessairement partager une monnaie. Il faut également déterminer **quand** on progresse, **ce qui persiste**, **ce qui peut être réattribué**, et **comment le contenu acquis rencontre les statistiques**.

Pour nous, la contrainte centrale est particulière : les sorts sont des copies consommées dans une traversée courte. Le personnage doit conserver son identité et ses investissements après leur disparition, tout en pouvant changer de répertoire. Copier une progression construite pour des centaines d'heures ou pour des sorts permanents produirait d'autres incitations.

Les sections « transfert » ci-dessous sont notre analyse, pas des déclarations attribuées aux développeurs cités.

## 2. Dofus — coût de spécialisation et liberté des classes

**Mécanisme documenté.** Le guide communautaire Dofus Builds, mis à jour le 18 août 2026, indique cinq points de caractéristiques par niveau gagné. Les caractéristiques élémentaires ont des coûts croissants : 1 point pour les cent premiers rangs, puis 2, 3 et 4 au-delà de 300. Cela distingue budget dépensé et caractéristique obtenue. [Guide et paliers](https://dofusbuilds.com/guides/characteristic-points).

**Intention de conception.** Le devblog de 2015 sur l'uniformisation explique que des paliers inégaux entre classes rendaient certaines voies peu intéressantes. Harmoniser les coûts demandait aussi de retoucher les dégâts de sorts. Le texte original est accessible par une [reproduction de JeuxOnLine](https://dofus.jeuxonline.info/actualite/48710/mise-jour-230-uniformisation-paliers-caracteristiques) ; l'[adresse officielle](https://www.dofus.com/fr/mmorpg/actualites/devblog/billets/441193-uniformisation-paliers-caracteristiques) n'a pas livré son corps à l'outil de lecture. C'est un raisonnement historique de développeurs, pas une preuve de tous les réglages du client de 2026.

**Notre calcul.** Avec 300 points de budget, sans équipement ni parchemins : une spécialisation donne 200/0, deux éléments donnent 125/125. Pour un sort hypothétique de base 8 Eau + 8 Terre avec +1 % par caractéristique : 32 contre 36. Pour une base 16 Eau : 48 contre 36. Ce ne sont pas deux sorts identifiés dans le jeu ; l'exemple isole l'effet mathématique des coûts.

**Transfert.** La diversité peut provenir du prix marginal de l'investissement et du catalogue. Il n'est pas nécessaire de fabriquer une règle « avoir X dans deux éléments débloque l'hybridation ». Cela corrige notre ancien raisonnement à somme de caractéristiques constante : un budget égal ne donne pas forcément la même somme de caractéristiques. En revanche, reprendre cinq points par niveau ou des centaines de rangs n'apporterait rien à nos douze niveaux.

## 3. Wakfu — séparer les budgets pour préserver les choix

La documentation communautaire décrit plusieurs catégories d'aptitudes, distribuées selon une cadence alternée, ainsi que des choix majeurs. Elle distingue les maîtrises élémentaires des maîtrises conditionnelles. On peut donc travailler une préférence de portée sans que celle-ci remplace automatiquement tous les autres axes du personnage. [Caractéristiques](https://wakfu.wiki.gg/wiki/Characteristic), [maîtrise mêlée](https://wakfu.wiki.gg/wiki/Melee_Mastery).

**Limite de lecture.** La page Caractéristique a été partiellement consultée via les extraits indexés ; l'ouverture directe renvoyait 403. Les plafonds et nombres de points majeurs dépendent des versions : ils ne sont pas utilisés dans nos calculs. Cette source sert à établir la structure, pas à certifier un personnage maximal actuel.

**Transfert.** Une monnaie élémentaire et quelques choix d'aptitudes distincts évitent que chaque choix de survie soit directement le renoncement à un élément. Il faut cependant limiter le nombre de catégories : multiplier les jauges reproduirait la charge d'apprentissage d'un jeu beaucoup plus long.

## 4. Divinity: Original Sin 2 — plusieurs couches de spécialisation

Le tableau communautaire daté du 20 octobre 2019 indique deux points d'attributs et un point de compétence de combat par niveau supplémentaire, avec des talents et des compétences civiles à des paliers espacés. Les gains ne sont donc pas tous distribués au même rythme ni pour le même usage. [Tableau de progression DOS2](https://steamcommunity.com/sharedfiles/filedetails/?id=1158467368).

**Transfert.** C'est une bonne réponse au problème « tout se réduit à augmenter le dégât ». Mais copier chaque monnaie créerait chez nous plusieurs écrans après chaque combat. On retient des petits investissements fréquents et des décisions qualitatives espacées. Les aptitudes civiles ne deviennent pas artificiellement une deuxième fonction obligatoire de chaque élément.

## 5. Baldur's Gate 3 — rendre certains niveaux mémorables

Le plafond est de douze niveaux. Dans le cas général, les dons arrivent aux niveaux **de classe** 4, 8 et 12, avec des exceptions selon la classe. L'amélioration des caractéristiques est elle-même un don : elle concurrence d'autres options. Le multiclassage peut donc retarder ces paliers. [Expérience](https://bg3.wiki/wiki/Experience), [dons](https://bg3.wiki/wiki/Feats).

**Transfert.** Le même plafond que le nôtre n'implique pas le même temps de jeu. Nous pouvons conserver des moments forts espacés ; un arbre de multiclassage complet serait beaucoup plus lourd. Faire concourir un gain quantitatif très fiable et une aptitude situationnelle peut aussi créer un faux choix. Il faut comparer leur valeur réelle avant de les placer dans la même liste.

## 6. Grim Dawn — investir pour ouvrir, puis investir pour renforcer

Le guide officiel donne un point d'attribut par niveau et un nombre de points de compétence qui décroît avec les tranches de niveaux. Les points de compétence servent à développer la barre de maîtrise ou les compétences elles-mêmes. La seconde classe arrive au niveau 10. [Bases du personnage](https://www.grimdawn.com/guide/character/character-basics/), [maîtrises](https://www.grimdawn.com/guide/character/masteries/).

Un autre budget provient des sanctuaires de Dévotion, avec un réseau de constellations et d'affinités. La progression n'est ainsi pas intégralement indexée sur l'XP. [Dévotion, guide officiel](https://www.grimdawn.com/guide/character/devotion/).

**Attention aux versions.** Certaines pages de base présentent la barre de maîtrise comme non remboursable. Le guide des services précise une exception avec Ashes of Malmouth : la barre peut être réduite jusqu'à un point. Il ne faut pas déduire qu'une réinitialisation permet librement de changer les classes choisies. [Services et remboursement](https://www.grimdawn.com/guide/gameplay/service-npcs/).

**Transfert.** Faire concurrence entre accès à de nouvelles compétences et approfondissement est fertile lorsque le joueur conserve ces compétences longtemps. Dans notre économie de copies, acheter l'accès à une branche puis ne plus trouver ses cartes peut devenir une double peine. Nous conservons les voies élémentaires ouvertes et réservons l'accès au catalogue au contenu et à la classe, plutôt qu'à un immense arbre de prérequis.

## 7. Slay the Spire 1 — les récompenses construisent le personnage

La présentation des développeurs met en avant le deck enrichi au fil de l'ascension, les reliques modifiant les interactions et les embranchements du parcours. [Présentation officielle sur Steam](https://store.steampowered.com/app/646570/Slay_the_Spire/).

**Transfert.** Nos cartes, équipements, reliques et dépenses sont déjà des choix de progression. Compter uniquement les points de niveau sous-estime le nombre de décisions. La différence déterminante reste que nos copies jouées sont détruites pour la run : un investissement de personnage ne doit pas être lié pour toujours à la possession d'une seule copie. La proposition porte sur Slay the Spire 1 ; elle n'attribue aucune de ses règles à sa suite.

## 8. Hades 1 — croissance pendant la tentative et entre les tentatives

Les bienfaits obtenus pendant une tentative coexistent avec des améliorations permanentes du Miroir. La présentation officielle assume que le personnage devient plus fort au fil des retours. [Présentation des développeurs](https://store.steampowered.com/app/1145360/Hades/).

**Transfert.** Une croissance permanente de puissance est un choix valide si l'objectif est de rendre les tentatives progressivement plus accessibles. Elle ajoute néanmoins un second axe d'équilibrage : deux joueurs au même niveau de run peuvent avoir des moyens très différents. Pour Dungeon Draft, la proposition initiale privilégie des options de départ à débloquer, à budget équivalent. Le système de compte existant n'a pas été audité exhaustivement dans cette étude ; ce passage recommande une direction, il ne décrit pas son état actuel.

## 9. Waven — attention à la superposition des progressions

L'enquête locale du 26 septembre distingue niveau du héros, investissements, équipement, runes et compagnons. Le build étudié était une configuration avancée ; modifier son curseur de niveau ne réinitialisait pas ses investissements. On ne peut pas utiliser ce résultat comme trajectoire d'un nouveau personnage. [Rapport et observation](../waven_coeur_du_jeu_2026-09-26/KITS_ET_COMBAT.md), [build étudié](https://www.waven-build.com/builds/10898).

**Transfert.** L'intérêt est de distinguer chaque source de puissance et son coût. Empiler une progression propre aux objets, aux cartes et aux compagnons dans une traversée de douze combats alourdirait fortement notre économie. Cette section réemploie explicitement une investigation antérieure ; ce n'est pas une nouvelle mesure du client Waven, ni une affirmation sur l'état actuel d'un autre mode de jeu.

## 10. Les alternatives pour Dungeon Draft

| Famille de système | Ce qu'elle apporte | Problème concret dans notre jeu | Choix proposé |
|---|---|---|---|
| XP par élimination | Granularité et variation | Farming, invocations, combats interminables, différences de niveau selon composition ennemie | Garder la récompense de victoire déjà fixe |
| Niveau après chaque étape | Cadence très lisible | Aucun rattrapage par grind | Garder les onze niveaux gagnés sur la route actuelle |
| Amélioration en utilisant les sorts | Progression liée à l'action | Dépenser des copies inutilement pour entraîner une maîtrise | Écarter comme moteur principal |
| Une grande monnaie universelle | Liberté apparente | Comparer PA, dégâts, survie et talents dans le même panier crée des dominances | Deux budgets limités + perfectionnements de sorts |
| Arbres à prérequis | Objectifs lointains, anticipation | Voies fermées et investissements perdus quand les cartes disparaissent | Ne pas en faire la fondation élémentaire |
| Statistiques linéaires | Compréhension immédiate | Le monoélément domine facilement les investissements quantitatifs | Comparer aux rendements décroissants |
| Coûts croissants | Arbitrage naturel entre profondeur et largeur | Points en attente et deuxième compteur « rangs achetés » | Bon modèle de référence, pas notre première interface |
| Gains décroissants | Même arbitrage, chaque point se dépense immédiatement | Il faut montrer le gain du prochain point | Recommandé pour le prototype |
| Réinitialisation partout | Permet d'expérimenter | Reconstruction optimale avant chaque ennemi | Corrections courtes aux haltes + une refonte complète |
| Puissance permanente de compte | Soutient l'accessibilité et la rétention | Change le référentiel de difficulté entre tentatives | Option de produit ultérieure, hors premier équilibrage |

Ces conclusions sont des hypothèses de conception argumentées. Elles ne remplacent pas les essais de combat, les mesures de compréhension ni l'observation de vrais choix de joueurs.
