# 2 — Reliques, équipements, statistiques et progression

Statut : audit statique et propositions, sans modification du gameplay. [Sources](SOURCES.md) · [Calculs](MATH_RESULTS.md) · [Vue d'ensemble](README.md).

## 2.1 Donner une fonction distincte à chaque couche

Un build peut rester identifiable malgré la consommation de ses cartes si son identité durable vient de la classe et de ses règles. Proposition de répartition :

| Couche | Question posée au joueur | Ce qu'elle ne devrait pas faire seule |
|---|---|---|
| Classe | Quelle situation ai-je intérêt à créer ? | Interdire la majorité du butin |
| Spécialisation | Quelle variante de cette situation vais-je privilégier ? | Remplacer un pourcentage par un autre sans changer de décision |
| Maîtrise | Dans quelles familles vais-je investir pour la suite de la run ? | Augmenter simultanément dégâts, drops, XP et prix de revente |
| Caractéristiques | Quelle faiblesse vais-je compenser ? | Devenir une allocation évidente identique pour tous |
| Équipement | Quelles contraintes de portée, survie ou mobilité vais-je modifier ? | Multiplier encore les mêmes conditions de dégâts |
| Relique | Quelle règle inhabituelle donne une autre valeur à mes cartes ? | Une remise universelle sur toute l'économie |
| Cartes | Quelles actions puis-je financer maintenant ? | Porter seules l'identité persistante du personnage |
| Niveau | À quel moment ai-je accès à un nouveau choix ? | Exiger du farming pour maintenir une difficulté fixée d'avance |

Ce découpage est une proposition, pas une obligation de garder huit écrans. Plusieurs décisions peuvent être regroupées dans un même bilan. La distinction porte sur leur effet, pas sur la quantité de menus.

## 2.2 Audit des identités actuelles

Le [catalogue de classes](../../../../core/expedition/class_card_catalog.gd) annonce des intentions claires : isoler/exécuter ; protéger/riposter ; se déplacer/viser ; affaiblir/regrouper. Leurs passifs de base renforcent surtout le premier dégât ou la première garde. Les douze spécialisations conservent largement cette structure de bonus conditionnel.

L'extraction de 84 lignes — 60 familles historiques et 24 avancées, starters exclus — trouve **six groupes de signatures numériques identiques**. Exemples : `a_step/r_step/t_step` ; `a_escape/r_escape/t_escape` ; `a_parry/r_guard` ; `a_phantom/r_horizon`. D'autres signatures identiques comprennent des dégâts physiques/magiques différents : ce ne sont donc pas automatiquement des doublons fonctionnels. La liste reproductible figure dans [les calculs](MATH_RESULTS.md).

La redondance n'est pas intrinsèquement mauvaise. Des verbes communs rendent les drops utilisables et les règles apprenables. Elle devient coûteuse si chaque famille occupe un emplacement de catalogue, une icône, une amélioration et une ligne de butin sans ouvrir une décision différente. Première action : classer les cartes en **socle partagé**, **variante de classe**, **signature de classe**. Ne pas supprimer indistinctement les déplacements communs.

Le risque principal est une convergence des séquences : appliquer Marqué/Ralenti → premier coup bonifié → répéter. Les cartes avancées de terrain, déplacement, interruption et stase donnent déjà des moyens de sortir de cette convergence. Il faut leur donner des rencontres favorables et vérifier leur disponibilité, avant de produire des dizaines de familles supplémentaires.

## 2.3 Quatre identités compatibles avec l'usage unique

Propositions à tester séparément du réglage de drop ; les quantités ci-dessous sont des règles de prototype.

| Classe | Boucle proposée | Deux orientations de build | Limite explicite |
|---|---|---|---|
| Assassin | Créer un angle d'attaque, consommer une préparation pour une fenêtre courte | Exécuteur : finir une cible ; Saboteur : retirer un outil ennemi puis changer de cible | Une seule ouverture renforcée par tour ; aucune création d'exemplaire sur meurtre |
| Gardien | Transformer une garde réellement absorbée en possibilité de placement | Rempart : sécuriser une case ; Percuteur : convertir la défense en poussée | Compter l'absorption réelle, exclure dégâts auto-infligés et garde non utilisée |
| Arpenteur | Choisir un point de tir, puis accepter de l'abandonner ou de le défendre | Tireur : ligne longue ; Escarmoucheur : alterner deux positions | Le déplacement doit coûter PA/PM ou carte ; pas de mouvement infini obtenu en boucle |
| Thaumaturge | Installer une petite zone, décider quand la transformer ou la détruire | Contrôleur : fermer un passage ; Dévastateur : consommer sa zone pour un impact | Deux zones actives au prototype, ordre de résolution visible, pas de propagation récursive |

Ce qui peut rendre ces classes plaisantes est une **hypothèse explicable** : le joueur prépare une situation, reconnaît qu'il l'a créée et choisit comment en tirer parti. La satisfaction viendrait de cette maîtrise visible et de plusieurs solutions possibles. Elle doit être observée ; les sources consultées ne mesurent pas l'attachement à nos quatre classes.

Chaque classe devrait pouvoir montrer sa boucle avec des normales fréquentes. Les rares élargissent ensuite les angles possibles. Une spécialisation ne devrait pas demander une carte qui a moins d'une chance sur deux d'apparaître avant la fin de run.

## 2.4 Reliques : modifier une relation entre actions

Le [catalogue de préparation](../../../../core/expedition/catabase_preparation_catalog.gd) contient déjà de bonnes idées : Urne de bronze fondée sur la garde absorbée, Fil du retour lié au Disque, Mèche errante liée aux braises, Coupe des blessures, Obole fendue. Plusieurs sont liées aux constructions Classique et ne sont **pas toutes offertes dans le parcours Cartes**. Ce sont des éléments du dépôt à examiner, pas un inventaire public homogène.

Leur intérêt est la relation qu'elles créent : protection → riposte ; trajectoire → mobilité ; terrain → tempo ; attaque → soin plafonné ; meurtre → or plafonné. Les plafonds et conditions ont une fonction essentielle contre les boucles. En les portant dans le nouveau mode, il faut changer les dépendances qui supposent une technique permanente.

Trois propositions originales :

| Relique de prototype | Règle | Décision créée | Test d'abus |
|---|---|---|---|
| Agrafe du passeur | Au début du combat, épingler une normale déjà en main ; elle n'est pas défaussée tant qu'elle n'est pas jouée | Garder une réponse au prix d'une place occupée | Ne crée ni carte ni pioche supplémentaire ; prévoir une façon de désépingler |
| Bronze patient | Une fois par tour, après absorption de garde, la prochaine poussée du tour déplace d'une case supplémentaire | Laisser approcher une attaque ou dépenser sa poussée tout de suite | Une source ennemie réelle ; pas de cumul intertours ; boss et bord de carte |
| Encrier des ruines | Une fois par combat, jouer une normale de terrain permet de déplacer une zone existante d'une case | Réutiliser le plateau sans recréer l'exemplaire | Zone déplacée une fois, pas de double déclenchement à l'origine et à l'arrivée |

Éviter d'abord « 20 % de chances de ne pas consommer la carte ». Ce serait une exception au contrat utilisateur et une augmentation cachée de l'offre ; avec probabilité de conservation `r`, le nombre moyen d'usages théorique devient `1/(1−r)` si l'effet peut se répéter. Une conservation de 50 % doublerait le rendement de chaque exemplaire éligible.

Monster Train a réduit Volatile Gauge de coûts aléatoires 0–3 à 1–3 et Winged Steel de deux cartes piochées à une. Iron Dropcage a eu une réduction de durée alors que ses déclenchements devenaient plus accessibles. Ce sont trois leviers distincts : supprimer un seuil gratuit, limiter le débit, compenser une meilleure disponibilité. [S12 — annonces de 2020](https://store.steampowered.com/news/posts/?appids=1102190&enddate=1602708373&feed=steam_community_announcements).

Application : avant de diminuer tous les dégâts d'une relique amusante, regarder fréquence, éligibilité, limite par tour et interaction avec pioche/PA. Une carte consommée ne suffit pas à contenir une combinaison si elle empêche toute riposte pendant plusieurs tours.

## 2.5 Équipement : budget lisible, propriétés distinctives

Le [catalogue Cartes](../../../../core/expedition/class_equipment_catalog.gd) génère 3 paliers × 6 emplacements × 4 affinités, soit **72 définitions**. Chaque emplacement porte une statistique fixe multipliée par le palier ; l'affinité ajoute principalement un pourcentage conditionnel de dégâts, ou garde/soins. Tous ces objets sont utilisables par toutes les classes.

Cela donne une structure lisible, mais 72 définitions ne représentent pas 72 choix de gameplay. Les affinités répètent des conditions déjà présentes dans les passifs : contact, distance, magie. Le prochain audit runtime devra vérifier l'ordre d'empilement réel des modificateurs ; aucun produit de pourcentages n'est supposé ici sans inspection du résolveur.

Diablo IV a ramené les affixes de base à trois pour les légendaires et deux pour les rares dans Loot Reborn, en réduisant des conditions difficiles à comparer et en transférant une part de personnalisation à la trempe. Le gain recherché était la lisibilité du butin. [S06 — saison 4](https://news.blizzard.com/en-gb/article/24077223/galvanize-your-legend-in-season-4-loot-reborn).

Application proposée : une ligne de socle, une propriété qui change une décision, une contrainte éventuelle. Exemples à chiffrer ensuite : bottes qui facilitent le premier déplacement mais réduisent la portée d'un tir après ce mouvement ; bouclier qui améliore la garde restante mais réduit la mobilité ; arme qui permet de pousser avec le geste de secours au prix de ses dégâts. Le joueur compare des usages, pas six variantes de « +4 % si… ».

Ne pas transformer chaque drop d'équipement en loterie supplémentaire. Le fil joueur S07 décrit précisément la déception d'obtenir un objet prometteur puis de manquer sa personnalisation ; le patch 1.5.0 ajoute une tentative de trempe par affixe supérieur. Cela montre une tension et une réponse déclarée, sans prouver qu'elle est résolue pour tous. [S07 — témoignage](https://us.forums.blizzard.com/en/d4/t/gambling-reborn/173838), [S20 — patch](https://news.blizzard.com/en-us/article/24123440/diablo-iv-1-5-0-patch-notes).

Dans une run courte, recommander d'abord une modification choisie et tarifée, sans destruction aléatoire du meilleur objet. Une fabrication permanente de MMO et douze combats n'ont pas la même tolérance au délai de récupération.

## 2.6 PA, PM, portée : des statistiques qui changent les possibilités

Un point de PA peut débloquer une carte de plus ; un point de portée peut rendre une cible atteignable sans mouvement ; un PM peut éviter une activation ennemie. Leur valeur n'est pas comparable linéairement à +1 % dégâts.

Le devblog DOFUS de 2011 explique le besoin de borner les cumuls pour conserver les faiblesses de classe ; son cadre annoncé était 12 PA, 6 PM et 9 PO pour les sources concernées, avec distinction des bonus temporaires de sorts. Ce sont des valeurs historiques, **pas une proposition pour Catabase**. [S01 — devblog reproduit](https://dofus.jeuxonline.info/actualite/30454/devblog-nouvelles-restrictions-pa-pm-po).

Le travail WAKFU de 2013 sur les équipements illustre aussi un budget d'objets et des contraintes globales à expliciter. Chez nous, commencer par une table de possibilités : PA de départ, PA maximal de l'équipement, gain temporaire maximal, portée des réponses et coût minimal d'une séquence. Tester les combinaisons qui franchissent ces seuils avant les moyennes de dégâts. [S02 — règles d'équipement](https://wakfu.jeuxonline.info/actualite/40890/devblog-nouvelles-regles-equipement).

## 2.7 Statistiques : analyser le rendement marginal

Données présentes dans le [profil Achille](../../../../data/runs/progression/odyssey/achilles_champion_progression_v0.tres) et l'[application de progression](../../../../characters/progression/champion_progression_state.gd) : Vitalité ajoute 6 % des PV de base par point ; Puissance apporte 5 % de Prouesse par point ; Résolution ajoute 4 armure et 5 % de bouclier. Les points de caractéristiques sont distribués aux niveaux 2 à 10.

La maîtrise des cartes non initiales utilise un coefficient `1 + 0,1 × rang`. Passer du rang 2 au rang 3 donne `1,3/1,2 − 1 = 8,33 %` d'augmentation du coefficient, pas 10 % du résultat précédent. Les déplacements purs ne gagnent pas automatiquement une case avec la maîtrise. Il faut afficher ce que l'investissement améliore effectivement.

Trois pièges de calcul :

* **Additif ou multiplicatif :** des bonus hypothétiques de 40 %, 35 % et 45 % donnent ×2,20 en addition, ×2,7405 en multiplication. Ces nombres illustrent un choix de règle, pas le cumul vérifié du jeu.
* **Réduction de dégâts :** à 100 PV, 20 % de réduction donne 125 PV effectifs ; 60 % donne 250 ; 80 % donne 500. Une hausse constante en points de réduction n'a pas une valeur constante. L'exemple n'est pas la formule d'armure actuelle.
* **Seuil de mise à mort :** contre 100 PV, passer de 49 à 50 dégâts réduit trois coups à deux ; passer de 50 à 51 ne change pas le nombre de coups. Dans notre concept, le premier gain économise un exemplaire entier.

Un budget de carte doit donc comparer PA, portée, nombre de cibles, garde, contrôle, consommation et fiabilité. Une formule unique « dégâts par PA » ne peut pas évaluer correctement une poussée hors danger ou une interruption.

## 2.8 Évolution numérique : la faiblesse des bonus plats tardifs

Sur le parcours de référence, la Prouesse de base va de 18 à 112 avant le boss. Une arme de palier 3 donne +9 Prouesse : 50 % de la base initiale mais seulement 8,04 % de la base pré-boss, avant autres modificateurs. Ce calcul ne dit pas qu'une telle arme est disponible au départ ; il expose la dépendance au moment d'acquisition.

Inversement, les gains d'un équipement proportionnel se maintiennent mieux à mesure que la base monte. Mélanger beaucoup de bonus plats et proportionnels sans budget par palier produit des remplacements évidents et des objets tardifs décevants.

Trois options à comparer : objets à valeurs adaptées au palier ; objets à proportion modeste ; objets à effet fonctionnel peu dépendant du niveau. Garder une même métrique de comparaison sur les niveaux 2, 5, 8 et 12. Éviter d'introduire une mise à l'échelle automatique de tous les objets sans examiner son effet sur le plaisir de trouver un remplacement.

## 2.9 XP et niveaux : le calendrier réel

L'extraction de la [route r6](../../../../core/expedition/catabase_route_v6.gd) et du profil donne un niveau gagné après chacun des douze combats si seules ces récompenses s'appliquent. En Cartes, la [configuration](../../../../core/expedition/class_cards.gd) force la sagesse à zéro et le multiplicateur de gloire à un. Le scénario de référence arrive donc au boss **niveau 12**, puis niveau 13 après victoire, avec 2 785 XP ; le seuil du niveau 14 est 2 950.

Implication : un bénéfice débloqué au niveau 13 ou 14 n'enrichit pas les décisions précédant le boss de cette route. Ne pas équilibrer la run autour d'une capacité de fin de progression générique sans vérifier qu'elle y est accessible. Des sources d'XP supplémentaires pourraient changer le calendrier ; l'extraction ne les invente pas et ne remplace pas un parcours runtime.

La spécialisation arrive au niveau 4, donc après le troisième combat dans ce scénario. C'est un moment cohérent pour transformer une boucle déjà apprise. Ajouter simultanément nouvelle rareté, deux menus de stats, relic et nouvelle règle de terrain ferait toutefois un pic d'apprentissage à mesurer.

## 2.10 Améliorations : l'investissement doit survivre à l'exemplaire

Le système actuel donne jusqu'à douze points de perfection, deux à chaque niveau pair jusqu'à 12. Une maîtrise principale commence à 2 : rang 3 coûte 3 points, rang 4 coûte 4 supplémentaires. Une maîtrise secondaire de 0 à 2 coûte 2 puis 3. Les deux trajectoires ensemble consomment exactement douze points. L'amélioration d'une copie coûte deux points et exige maîtrise 3 ; elle concurrence donc ces trajectoires.

Avec consommation définitive, ce budget risque de pousser à **ne pas jouer l'exemplaire amélioré**. Le coût aurait la durée de la run et le bénéfice une seule résolution. C'est un changement de nature, pas seulement un mauvais prix.

Option recommandée à prototyper : améliorer une **famille pour la durée de la run** ; les copies présentes et futures de cette famille bénéficient de la règle, mais sont toutes consommées à l'usage. Limiter le nombre de familles améliorées et offrir une réorientation tarifée au refuge si le stock s'assèche. Ne pas donner un remboursement intégral exploitable entre chaque combat.

Alternative distincte : garder une amélioration d'exemplaire mais la payer en or, comme préparation exceptionnelle avant un boss, sans points de build permanents. Tester laquelle produit le plus de décisions compréhensibles. Les points investis par famille nécessitent un nouveau registre et une migration ; aucun changement de sauvegarde n'est réalisé ici.

## 2.11 Progression entre runs

Décision ouverte : si le stock, l'or ou l'équipement survivent entre runs, toute l'économie doit être recalculée. La réserve d'un vétéran peut alors rendre les quinze cartes initiales anecdotiques et banaliser un drop immortel à travers les échanges.

Premier test recommandé : progression extérieure horizontale — découverte de familles, choix de départ, informations de bestiaire, variantes de classe — et remise à zéro des stocks consommables de la run. C'est une hypothèse à soumettre au ressenti, pas une modification tacite de la direction utilisateur. Si une réserve persistante est désirée ensuite, définir séparément budget de départ, transfert et destination du surplus.

## 2.12 Ce que doit prouver un prototype

Le joueur doit pouvoir expliquer pourquoi il a changé une pièce, choisi une maîtrise et dépensé une carte rare avec trois raisons différentes. Il doit percevoir sa classe avant de trouver une rare, et pouvoir utiliser son meilleur outil sans avoir l'impression de sacrifier tout son investissement.

Mesurer : diversité des séquences réellement jouées ; gain d'une maîtrise par rôle de carte ; fréquence de remplacement d'équipement ; reliques jamais déclenchées ; cartes améliorées mortes en réserve ; nombre de décisions de progression avant lesquelles le joueur consulte un guide. Ces indicateurs doivent être accompagnés de quelques commentaires en situation, pas seulement d'un taux de victoire global.
