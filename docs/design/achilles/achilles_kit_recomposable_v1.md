# Achille — un kit que le joueur construit

> **Évolution du cadre :** le [topo de run expérimentale V2](catabase_experimentale_routes_et_builds_v2.md) prend priorité sur cette V1 pour la carte à embranchements, les quatre à six sorts, la diversité des axes, la spécialisation et la réorientation. Les quatre slots fixes, le plafond de deux doctrines et les douze achats à un point ci-dessous sont désormais des hypothèses historiques. Les techniques et analyses de la V1 restent des matériaux de conception.

**Proposition de conception V1 — 7 septembre 2026.** Base examinée : `c1311f389b68e7c9d5ab83c3585bbaa512f73ac9`. Ce document propose un personnage complet ; il ne modifie ni les sorts, ni la progression, ni les cinq salles jouées. Les coûts et coefficients proposés sont des hypothèses de prototype, pas un équilibrage validé. [Audit de l'existant et sources](achilles_kit_audit_2026-09-07.md).

## 1. La décision de design

**Conserver Achille, ses trois doctrines et quatre emplacements. Faire des doctrines des répertoires de techniques dans lesquels le joueur compose son propre combat.**

La promesse : « Je commence avec un guerrier polyvalent. Je choisis ce qu'il apprend, ce qu'il abandonne et la manière dont il survit. À la fin, je reconnais mon Achille à ses actions. »

Un Achille peut abandonner Garde pour attirer un adversaire, renoncer à Percée pour faucher une formation, retirer sa frappe de mêlée pour jouer les trajectoires, ou remplacer son tir par un coup de bouclier. Le choix doit modifier les situations qu'il recherche et celles qu'il redoute.

Sa permanence tient à son corps martial : portée, engagement, lance, bouclier, projectiles physiques, maîtrise des appuis. Il reste un héros qui lit une intention, intervient sur la formation adverse, puis accepte une position finale. Son caractère mythique émerge lorsqu'il renverse une situation préparée pendant plusieurs actions.

Trois verbes définissent les écoles :

| École conservée | Désir du joueur | Manière de survivre | Faiblesse recherchée |
|---|---|---|---|
| **Colère du Péléide** | Briser une formation et exploiter une ouverture | Supprimer une menace, attirer, enchaîner une élimination | L'engagement raté, les cibles dispersées, le manque de sortie |
| **Leçon de Chiron** | Construire une trajectoire et déplacer le point d'attaque | Distance, lignes de vue, alternance des positions | L'encerclement et les angles que l'adversaire ferme |
| **Rempart d'Éaque** | Décider où et comment l'adversaire peut frapper | Orientation, poussée, écran, conversion de protection | Les attaques croisées et la protection investie au mauvais endroit |

Le dynamisme recherché est tactique : davantage de positions finales, de géométries et d'ordres d'action intéressants. Accélérer les animations ne suffira pas à l'obtenir.

## 2. Ce que l'audit nous apprend

La Catabase actuelle utilise Frappe du Péléide, Percée fulgurante, Tir du Pélion et Garde d'airain. Les quatre anciens arbres Lance/Élan/Horizon/Airain ne sont plus son autorité. Elle possède trois doctrines et 36 maîtrises, mais aucune n'enseigne un cinquième sort.

Avec 6 PA et des coûts de 3/1/3/2, les tours qui dépensent exactement les 6 PA appartiennent à trois familles : Frappe + Tir ; Frappe + Percée + Garde ; Tir + Percée + Garde. L'ordre et la carte peuvent les rendre différents, mais l'arbre transforme rarement leur composition.

Les cinq victoires donnent 700 XP sans bonus : niveau 5 pendant le boss, niveau 6 après. Les choix majeurs attendent les niveaux 10/13, les sommets 13, les jonctions et apothéoses 14. Une grande partie du personnage décrit n'est donc pas rencontrée dans la run normale.

Certaines racines promettent aussi trop tôt des synergies qui nécessitent autre chose : Garde active demande une absorption supérieure à la Garde native non renforcée ; la troisième offensive de Fureur lucide n'existe pas dans le kit initial. Le problème n'est pas seulement l'ampleur des pourcentages.

En revanche, Garde orientée, Tir rapproché, Angle impossible, Pas victorieux, Bastion mobile et Rempart offrent déjà des comportements intéressants. **La refonte doit rapprocher ces comportements du joueur et leur donner des concurrents dans son kit.**

Le laboratoire de theorycraft lit les ressources actuelles, mais sa comparaison brute ne résout pas correctement les coefficients du Champion. Il faut le raccorder au calcul réel avant de lui demander de classer les nouveaux kits.

## 3. Les règles du kit

### Quatre emplacements réellement libres

- Conserver **6 PA, 3 PM, quatre techniques équipées**, sans emplacement réservé à la défense, au mouvement ou à la mêlée.
- Les quatre techniques actuelles sont connues dès le départ. Aucune attaque de base gratuite n'est ajoutée.
- Un apprentissage ajoute une technique à la collection de la run. Il faut l'équiper pour l'utiliser ; il ne donne pas un cinquième bouton.
- Une mutation remplace la forme d'une technique dans son emplacement. Deux formes de la même technique ne peuvent pas être équipées ensemble.
- Les sorts connus restent disponibles lorsqu'on les range. Le joueur n'efface pas une technique pour essayer autre chose.
- Les quatre sorts initiaux restent utilisables quelles que soient les doctrines choisies. Une école détermine les apprentissages et maîtrises accessibles, pas le droit de garder Garde ou Tir.

**Premier départ :** choix d'une doctrine et d'une acquisition avant la salle I. Un nouveau joueur peut choisir « commencer avec le kit polyvalent » et dépenser ce point après I ; il ne perd rien. Les runs suivantes peuvent commencer directement avec un premier remplacement.

**Deuxième doctrine :** ouverture volontaire après II. Maximum deux doctrines investies dans cette V1. L'interface montre la conséquence avant de confirmer l'école ; inspecter un nœud ne l'ouvre jamais implicitement. Le plafond sert à rendre les mélanges reconnaissables ; il devra être testé, et pourra disparaître si les quatre slots limitent déjà suffisamment les builds.

### Trois acquisitions concurrentes

| Choix | Ce que l'on achète | Exemple de décision |
|---|---|---|
| **Technique** | Une nouvelle action équipable | « Je remplace Garde par Crochet pour ramener une cible dans ma zone. » |
| **Mutation** | Un autre fonctionnement d'une technique connue | « Mon Estoc coûte 2 PA ; je peux maintenant jouer trois techniques à 2 PA. » |
| **Liaison** | Une règle conditionnelle entre des actions | « Après une élimination manuelle, je peux choisir ma prochaine position. » |

Les trois coûtent **un point de kit**. Ce prix commun sert le prototype ; le coût réel d'une technique inclut aussi l'emplacement qu'elle occupe. Une nouvelle action doit donc résoudre un problème que le kit précédent gérait mal. Ajouter une attaque moins forte sans usage propre ne suffit pas.

Les racines cessent d'être des péages à +10 %. La doctrine s'ouvre comme un répertoire. Dès le premier point, on peut apprendre une technique ou transformer le sort initial associé.

### Essayer sans figer le build

Le kit se change librement **entre les rencontres, avant le déploiement**. Pendant la rencontre, y compris entre deux vagues, il reste verrouillé. La fiche de la prochaine rencontre expose les informations prévues par le jeu avant ce choix ; aucune information cachée supplémentaire n'est révélée par le configurateur.

Lorsqu'on range un sort, ses mutations restent acquises mais inactives. La fiche affiche les liaisons devenues inutilisables. Pour le prototype, réorientation gratuite entre les salles : transaction sur le build entier, restitution des points des descendants invalidés, aperçu puis validation atomique. Rembourser un apprentissage retire la technique et ses dépendances ; les emplacements affectés doivent être recomposés avant de reprendre. Pas de remboursement qui conserve gratuitement ses bénéfices.

Ce choix remplace, dans le profil expérimental seulement, le service actuel de réorientation à 55 drachmes limité à un nœud par run. On mesurera d'abord si l'expérimentation est plaisante ; un coût pourra venir ensuite, avec une raison de jeu.

### Un vocabulaire commun, pas une nouvelle jauge

Pas de rage, d'énergie ou de combo à entretenir en plus des PA/PM. Les conditions utilisent les faits du plateau : cible déplacée, collision, distance parcourue, attaque frontale absorbée, élimination.

Chaque technique apporte au plus un mécanisme principal. Le joueur voit sa conséquence spatiale avant de valider. Les effets acquis s'appliquent à des catégories explicites — offensive manuelle, projectile, mêlée, mouvement, garde — plutôt qu'à une liste figée des quatre anciens identifiants.

## 4. Le répertoire complet : treize techniques

Les quatre fondations et neuf apprentissages ci-dessous constituent la cible complète. Le premier prototype n'implémente que trois apprentissages, décrits en section 11.

### Conventions proposées

`P` désigne la Prouesse résolue avec les caractéristiques et l'équipement. Les dégâts indiqués sont avant mitigation et utilisent ensuite le resolver commun. Les arrondis doivent rester ceux du moteur. Portées en cases de grille, déplacement orthogonal sauf le saut explicitement défini. Un cast manuel par technique et par activation ; une mutation partage le quota de sa technique. Les attaques de réaction sont autonomes, bornées et ne rouvrent pas les chaînes de déclencheurs.

« Une activation de récupération » signifie : lancer en A, indisponible en A+1, disponible en A+2. Cette convention de design devra être traduite puis testée contre la décrémentation réelle du moteur, sans se fier au seul entier `cooldown`.

### Les fondations conservées

| Technique | Coût / géométrie | Effet de départ | Raison de la conserver |
|---|---|---|---|
| **Frappe du Péléide** | 3 PA ; mêlée, portée 1 | 55 % P | Frappe fiable et concentrée ; sa puissance vient aussi du faible nombre de conditions |
| **Percée fulgurante** | 1 PA ; ligne libre de 1–3 cases | Déplacement sans dégâts | Le meilleur accès simple à une position ; la retirer doit se sentir |
| **Tir du Pélion** | 3 PA ; portée 2–6, ligne de vue | 50 % P | Solution de distance autonome, utilisable sans spécialisation |
| **Garde d'airain** | 2 PA ; soi | Formule actuelle : 5 % PV max + 25 % P | Protection personnelle fiable, expire au début de l'activation suivante |

### Colère : intervenir dans la formation

| Nouvelle technique | Proposition de fonctionnement | Décision et sacrifice |
|---|---|---|
| **Crochet du Péléide** | **2 PA**, cible ennemie en ligne cardinale à 1–2 cases, ligne de vue ; 25 % P puis attraction d'une case vers Achille si la destination est libre. À une case, pas d'attraction dans la case du héros et pas de fausse collision créée par ce refus. | Ramener une cible plutôt que courir jusqu'à elle. Dégâts modestes ; peut rapprocher une menace qu'on ne finira pas. Remplace volontiers Tir ou Garde. |
| **Fauchage de Troie** | **3 PA**, choisir un front cardinal ; frappe les trois cases de contact de ce front : la case devant et les deux contacts latéraux orthogonaux, jamais trois diagonales. 40 % P par cible, maximum trois ; sans poussée native. | Chercher une formation et organiser son contact. Sur une seule cible, Frappe reste meilleure. Remplace souvent Percée ou Tir. |
| **Bond de guerre** — signature | **4 PA**, destination libre à distance de Manhattan 2–4 ; saute unités et petites discontinuités topologiques, jamais une cellule d'arrivée absente/bloquée ; 45 % P aux ennemis orthogonalement adjacents à l'arrivée, maximum quatre. Une activation de récupération. Un plafond de franchissement et les obstacles hauts restent des propriétés explicites de carte. | Entrer derrière une ligne ou au centre d'un groupe en consacrant presque tout son tour à l'entrée. Arrivée affichée avec exposition ; aucune sortie gratuite ni immunité après le bond. |

La forme exacte de Fauchage est une croix privée du contact arrière : les cellules sont définies depuis l'orientation choisie, pas depuis l'animation. C'est une géométrie simple à prévisualiser.

### Chiron : attaquer depuis la bonne origine

| Nouvelle technique | Proposition de fonctionnement | Décision et sacrifice |
|---|---|---|
| **Trait de rupture** | **2 PA**, projectile à portée 2–5, ligne de vue ; 25 % P et poussée d'une case dans l'axe du projectile selon les règles de poussée du moteur. | Créer de la distance, un alignement ou une collision. Il remplace de la puissance par une intervention spatiale ; ne touche pas un ennemi adjacent. |
| **Pas du chasseur** | **2 PA** ; sélectionner une case orthogonale adjacente libre puis un ennemi à portée 2–4 de cette arrivée ; déplacement d'une case et projectile à 30 % P. Le pas n'utilise pas les PM et ne reçoit pas la surcharge d'engagement ; terrain et réactions d'entrée restent appliqués. Si aucun tir légal n'existe depuis l'arrivée, le cast n'est pas proposé. Son origine de tir est imposée par la technique ; les liaisons de substitution d'origine ne s'y appliquent pas. | Tirer et se dégager dans la même action, mais moins loin que Percée et moins fort que Tir. Action atomique : deux sélections, une prévisualisation, puis résolution. |
| **Lance du retour** — signature | **3 PA** pour projeter une lance spectrale vers une case libre à 2–6 cases en ligne cardinale ; frappe jusqu'à deux ennemis traversés, 40 % P chacun. Les obstacles solides arrêtent la trajectoire. La lance reste comme ancre non bloquante. Dès l'activation suivante, le même bouton devient **Rappel, 1 PA**, trace une ligne de l'ancre à la position actuelle d'Achille et inflige 40 % P aux deux premières cibles traversées. | Préparer une trajectoire puis se déplacer pour changer celle du retour. Le slot est occupé par Rappel tant que la lance existe ; les deux étapes ne sont pas disponibles dans la même activation. Le retour ne doit pas être automatique. |

Lance du retour est la mécanique la plus neuve du répertoire. Sa règle complète : une seule ancre ; Rappel disponible pendant A+1 et A+2 ; s'il n'est pas joué, l'ancre disparaît à la fin de A+2 sans dégâts et le lancer revient en A+3. Un rappel joué en A+1 interdit le relancer cette même activation, mais le lancer revient en A+2. Si un obstacle coupe le retour, les dégâts s'arrêtent au premier obstacle puis la lance est dissipée ; on n'obtient pas une traversée gratuite des murs. Le retour peut être oblique et utilise le tracé de cellules du moteur, avec règle de coin explicite à tester. Lancer et Rappel portent le tag **origine imposée** : aucune liaison ne substitue leur origine. Il ne déplace pas Achille, ne désarme pas Frappe et n'implique aucune arme d'équipement.

### Éaque : déplacer la protection

| Nouvelle technique | Proposition de fonctionnement | Décision et sacrifice |
|---|---|---|
| **Heurt d'airain** | **2 PA**, contact cardinal ; 25 % P, poussée d'une case, collision selon les règles communes. Fonctionne sans Garde active ni Garde équipée. | Un sort offensif et spatial dans une école défensive. Pousser le danger remplace parfois le besoin de l'absorber. |
| **Égide de passage** | **2 PA**, déplacement cardinal libre de 1–2 cases, sans traverser obstacles ou unités ; crée une Garde égale à **50 % de la formule native** jusqu'à l'activation suivante. Même famille de source que Garde : seule la valeur restante la plus forte subsiste, pas d'addition. | Compresser mobilité et protection pour libérer un emplacement, en perdant distance, efficacité du déplacement et moitié de protection. Cette compression doit être surveillée : elle pourrait devenir obligatoire. |
| **Rempart des Myrmidons** — signature | **3 PA**, placer à portée 1–2 une ligne de trois cellules perpendiculaire à l'axe choisi, toutes existantes, libres et visibles. Bloque les projectiles des deux camps et ajoute 1 PM de traversée aux ennemis ; ne bloque pas totalement la marche. Expire au début de la prochaine activation d'Achille. Une activation de récupération. Aucun bouclier personnel. | Investir dans un écran qui protège un angle et peut fermer son propre tir. Remplace Garde avec une réponse différente au danger. Reprend le verbe du Rempart existant, comme vraie technique indépendante. |

Chaque technique défensive doit dire ce qu'elle ne couvre pas par sa prévisualisation : Rempart ne protège pas d'un ennemi déjà de l'autre côté ; Égide protège moins que Garde ; Heurt ne résout pas une attaque venant de plusieurs côtés.

## 5. Des arbres qui composent des comportements

Chaque doctrine propose **neuf nœuds** : deux apprentissages simples, deux mutations alternatives, deux liaisons, une signature, deux légendes alternatives. Avec les exclusions, sept acquisitions peuvent coexister dans une doctrine. Trois jonctions entre paires d'écoles portent le catalogue à **30 choix proposés**. Cette topologie est une nouvelle règle de conception, pas la validation 3 × 9 du modèle actuel réutilisée à l'identique.

Les liaisons sont acquises comme les autres maîtrises. Maximum **deux liaisons actives au total**, jonctions comprises ; en activer une autre range la précédente au camp. Le premier prototype limite ce nombre à une pour isoler les causes du plaisir. Les légendes ont leur propre plafond : **une pour le héros entier**.

### Les trois étages, sans péage numérique

| Accès sur douze salles | Choix disponibles | Prérequis avant achat |
|---|---|---|
| Dès l'ouverture d'une doctrine | Deux nouvelles techniques simples ou l'une des deux mutations | Technique connue pour sa mutation ; aucun point de racine obligatoire |
| Après III | Deux liaisons de doctrine | Deux points déjà investis dans cette doctrine |
| Après V | Technique signature | Trois points déjà investis dans cette doctrine |
| Après VII | L'une des deux légendes | Quatre points déjà investis dans cette doctrine et ses techniques requises connues |

L'Atlas peut suggérer trois choix adaptés au kit, mais laisse consulter et acheter tous les choix légaux. Pas de tirage aléatoire pouvant priver le joueur du mécanisme central de son école. Les exemples d'usage précèdent les détails de calcul.

### Colère du Péléide

| Nœud | Règle proposée | Ce qui change |
|---|---|---|
| Crochet / Fauchage | Apprentissages décrits plus haut | Deux nouveaux problèmes résolus, deux nouveaux boutons possibles |
| **Estoc pressant** — mutation de Frappe | 2 PA, portée 1, **35 % P** ; conserve quota d'une utilisation. Exclusif avec Fléau. | Rend légal Estoc + Crochet + Heurt à 6 PA, mais chaque Estoc frappe moins fort que Frappe |
| **Fléau de Troie** — mutation de Frappe | 3 PA, ligne cardinale de deux cases : 55 % P sur la première, 30 % P sur la seconde ; une unité n'est frappée qu'une fois. Exclusif avec Estoc. | On recherche un alignement ; conserve le coût de 3 PA et renonce au trio de techniques à 2 PA |
| **Pas victorieux** — liaison | Première élimination causée par une offensive manuelle : déplacement optionnel jusqu'à deux cases, dans la limite commune des déplacements de réaction. | La cible achevée devient un point de passage ; aucune valeur si l'ennemi survit |
| **Brise-formation** — liaison | Après un déplacement effectif ou une collision provoqués manuellement, la prochaine offensive de mêlée **différente** contre cette cible ignore jusqu'à 20 Armure ; une consommation par activation. La préparation expire à la fin de l'activation. | Récompense Crochet/Heurt puis une autre attaque ; étend l'existant aux nouvelles techniques, sans bonus de dégâts universel |
| Bond de guerre | Signature décrite plus haut | Un nouveau mode d'entrée et une cadence sur deux activations |
| **L'assaut sans retour** — légende | Bond peut finir sur une cible ennemie située sur un axe cardinal depuis Achille et poussable si une cellule de projection derrière elle est libre : la cible est poussée d'une case, Achille occupe sa cellule, puis applique l'impact de zone normal. En choisissant cette entrée, la Garde d'Achille est dissipée. Si la projection est impossible, cette destination est invalide. Requiert Bond. | Utiliser l'ennemi comme porte d'entrée, en acceptant l'exposition ; aucune projection létale vers VOID |
| **Le combat qui avance** — légende | Après Fauchage touchant au moins deux ennemis, choisir un déplacement gratuit d'une ou deux cases vers une case libre, puis une cible **déjà touchée** pour un coup autonome à 25 % P si elle est maintenant au contact. Une fois par activation ; renoncer au pas renonce aussi au coup. Requiert Fauchage. | La zone devient une action de traversée et de poursuite, bornée par l'espace disponible |

### Leçon de Chiron

| Nœud | Règle proposée | Ce qui change |
|---|---|---|
| Trait de rupture / Pas du chasseur | Apprentissages décrits plus haut | Contrôler une distance ou changer son point de tir |
| **Tir rapproché** — mutation de Tir | 3 PA, portée **1–5**, 40 % P et poussée 1. Exclusif avec Tir de traverse. | Le tir devient une réponse au contact ; portée et puissance de base sacrifiées |
| **Tir de traverse** — mutation de Tir | 3 PA, portée **3–8**, ligne cardinale et ligne de vue ; deux cibles à 50/30 % P. Exclusif avec Tir rapproché. | La trajectoire remplace la polyvalence ; angle plus strict et zone morte près du héros |
| **Angle impossible** — liaison | Après la première technique manuelle avec déplacement résolue, proposer un pas orthogonal gratuit ; budget commun de réaction. Terrain et réactions d'entrée s'appliquent. | Conserve l'idée actuelle, l'étend à Percée, Pas, Égide et Bond ; la case d'impact de Bond ne se recalcule pas après le pas |
| **Trait du souvenir** — liaison | Une fois par activation, un projectile manuel **sans origine imposée** peut partir de la cellule occupée par Achille au début de cette activation, si cette cellule est toujours libre ou occupée par Achille. L'interface propose origine actuelle ou ancienne ; portée/ligne de vue sont recalculées depuis l'origine choisie. | Reprend l'idée du Trait du destin comme mécanique accessible. Cette origine est un repère du tour, pas une invocation |
| Lance du retour | Signature décrite plus haut | Une géométrie à préparer sur deux activations |
| **La chasse en mouvement** — légende | Pas du chasseur permet de choisir l'ordre : pas puis tir, ou tir puis pas. Pour le second ordre, l'origine imposée devient celle du départ : le tir doit y être légal et l'arrivée choisie avant de confirmer. Dégâts/coût inchangés. Requiert Pas. | Tirer avant de couper sa propre ligne de vue, sortir d'un angle après l'attaque ; ne crée pas un deuxième pas |
| **La trajectoire impossible** — légende | Au Rappel, choisir un unique coude de trajectoire sur une cellule libre à une case de l'ancre. Deux segments avec obstacle/coin vérifiés ; une cible une seule fois, toujours deux cibles maximum. Coût de Rappel **2 PA** au lieu de 1 pour cette option. Requiert Lance. | Un grand changement géométrique avec une vraie facture en PA ; aucun suivi automatique de cible |

### Rempart d'Éaque

| Nœud | Règle proposée | Ce qui change |
|---|---|---|
| Heurt / Égide de passage | Apprentissages décrits plus haut | La défense acquiert des usages qui ne nécessitent pas le bouton Garde |
| **Contre d'Éaque** — mutation de Garde | 2 PA, choisir un front ; 70 % de la Garde native. La première attaque de mêlée venant du front et effectivement absorbée déclenche un coup autonome à 30 % P contre l'assaillant s'il est encore au contact. Pas de seuil de 10 % PV. Exclusif avec Ancrage. | La Garde devient un pari sur l'angle et l'attaquant. Fonctionne sans Frappe équipée ; pas de réaction sur dégâts de terrain |
| **Ancrage d'airain** — mutation de Garde | 2 PA, Garde native ; immunité aux poussées/attractions tant qu'elle subsiste. Un déplacement volontaire d'Achille dissipe cette source **avant** de se déplacer. Exclusif avec Contre. | Tenir une case a un prix clair ; incompatible avec une fuite protégée gratuite |
| **Bastion mobile** — liaison | Première technique de déplacement manuelle sous Garde : à l'arrivée, option de consommer 50 % de la Garde restante pour pousser les contacts d'une case. Dégâts par cible = valeur consommée, plafonnée à 25 % P. Zéro Garde : pas d'effet. | Convertir une sécurité présente en rupture de formation ; partage les groupes d'exclusion avec les reliques de conversion |
| **Prise d'appui** — liaison | Lors d'un Heurt, remplacer sa poussée normale par un déplacement d'une case dans l'une des deux directions perpendiculaires, si la cellule est libre. Aucun dégât de collision sur une direction refusée. Une fois par activation. | L'école place les ennemis latéralement pour Fauchage, Tir ou un écran ; une nouvelle décision, pas un multiplicateur |
| Rempart des Myrmidons | Signature décrite plus haut | Défense de terrain avec contraintes de lignes de vue |
| **Le rempart qui marche** — légende | Après une technique de déplacement, déplacer le Rempart existant d'une case cardinale, une fois entre sa pose et son expiration. Toutes ses cellules d'arrivée doivent être valides et libres ; sinon l'option est indisponible. Consomme l'unique fenêtre de réaction de cette action. Requiert Rempart. | Réorganiser son écran avec son avancée ; ne prolonge pas sa durée |
| **L'airain rendu** — légende | Si la Garde restante est strictement positive, Heurt peut la consommer entièrement et devenir un projectile à portée 1–4 : dégâts = 25 % P + valeur consommée plafonnée à 25 % P, poussée 1 ; coût de Heurt **3 PA** pour cette forme. Après conversion, aucune création de Garde personnelle jusqu'au début de l'activation suivante. Requiert Heurt et une source de Garde connue ; pour jouer cette conversion, une source doit être équipée et avoir créé une Garde encore présente. | Transformer la protection en arme et décider de rester exposé. Aucun besoin de promettre un bouclier équipé ou son retour visuel |

### Les trois jonctions

Une jonction est une liaison et consomme l'un des deux emplacements de liaison. Elle coûte un point, demande deux points déjà investis dans **chacune** des deux doctrines et devient disponible après IV. Elle ne demande pas de compléter deux arbres.

| Jonction | Règle proposée | Kit concerné |
|---|---|---|
| **Chasse au contact** — Colère/Chiron | Une fois par activation, après un projectile manuel touchant une cible, le prochain Crochet contre cette cible gagne une case de portée (maximum 3) et peut attirer jusqu'à deux cases si le chemin est libre, en s'arrêtant toujours avant la cellule d'Achille. Expire en fin d'activation ; aucune prolongation sur une autre cible. | Tir/Pas/ Trait puis Crochet ; amener un ennemi vers la mêlée au prix de l'ordre inverse habituel |
| **La brèche et le bronze** — Colère/Éaque | Après une collision provoquée par une technique manuelle, la prochaine offensive de mêlée manuelle contre la victime peut être précédée d'un déplacement d'une ou deux cases vers une cellule libre à son contact, avec chemin légal et arrivée choisis avant validation du cast. Ce déplacement consomme le budget de réaction ; une fois/activation. | Heurt puis Frappe ; prendre physiquement la brèche avant de frapper. Sans cellule légale, aucune attaque à distance déguisée |
| **Le tir sous l'égide** — Chiron/Éaque | Une fois par activation, un projectile manuel **sans origine imposée** peut partir d'une cellule de son Rempart encore présent. Portée/ligne de vue recalculées ; seule la cellule d'origine ne bloque pas le projectile. Les autres cellules de l'écran continuent de bloquer. | Construire une origine de tir ; incompatible avec Trait du souvenir sur le même cast, le joueur choisit une origine |

Les jonctions sont des hypothèses de deuxième passe. Le premier prototype de kit n'a pas besoin des trois pour prouver son intérêt.

## 6. Six Achille réellement différents

Les séquences suivantes respectent les coûts proposés. **Leur légalité spatiale dépend du plateau** : ce sont des exemples de situations à fabriquer, pas des résultats du simulateur. Les mutations sont indiquées à la place de la technique qu'elles transforment.

| Build | Quatre techniques | Exemple de séquence | Ce qu'il abandonne / ce qui le met en difficulté |
|---|---|---|---|
| **La lame nue** — Colère/Éaque | Estoc 2 ; Crochet 2 ; Heurt 2 ; Fauchage 3 | Crochet → Estoc → Heurt = **6 PA** ; ou Fauchage et placement normal | Garde et Percée sorties du kit. Toute sa sécurité vient des 3 PM, du contrôle et de la suppression de menaces. Dangereux face à plusieurs angles ou un contrôle impossible |
| **Le poursuivant** — Colère/Chiron | Frappe 3 ; Percée 1 ; Pas du chasseur 2 ; Crochet 2 | Pas → Percée → Frappe = **6 PA**, si tir initial et contact final sont possibles | Garde et Tir de base retirés. Très mobile, mais protection directe absente et puissance distante moindre |
| **Le duelliste de bronze** — Colère/Éaque | Frappe 3 ; Percée 1 ; Heurt 2 ; Garde/Contre 2 | Frappe → Heurt → Percée = **6 PA** ; autre tour Percée → Frappe → Garde = **6 PA** | Le tir disparaît. Alterne recul infligé, engagement et pari de contre ; peine à atteindre une cible éloignée derrière une formation |
| **Le géomètre** — Chiron/Éaque | Tir 3 ; Trait de rupture 2 ; Rempart 3 ; Percée 1 | Percée → Trait → Tir = **6 PA** ; autre tour Rempart → Tir = **6 PA** si sa ligne reste libre | Plus de frappe au contact ni de Garde personnelle. Son écran et ses trajectoires sont son kit ; un ennemi déjà au contact le gêne |
| **La lance errante** — Chiron/Colère | Tir 3 ; Pas 2 ; Lance/Rappel 3/1 ; Percée 1 | A : Lance → Pas → Percée = **6 PA**. A+1 : Rappel → Tir → Pas = **6 PA** | Frappe et Garde retirées. Cherche deux bonnes trajectoires successives ; un retour interrompu coûte un investissement et un slot temporairement moins utile |
| **L'assaillant** — Colère/Chiron | Estoc 2 ; Crochet 2 ; Bond 4 ; Fauchage 3 | Bond → Estoc = **6 PA** ; activation de récupération : Crochet → Fauchage = **5 PA** | Garde, Percée et Tir retirés. Entrée spectaculaire mais coûteuse ; doit gérer le tour où Bond ne revient pas. Un PA inutilisé peut être le prix acceptable du kit |

Les archétypes sont des démonstrations, pas des classes à choisir dans un menu. Le joueur doit pouvoir arriver à une combinaison qu'on n'a pas nommée.

### Une recomposition concrète jusqu'à la salle VIII

Exemple légal vers La lame nue, sans Sagesse, relique ni achat de maîtrise :

| Acquisition | Investissement | Effet immédiat sur le kit |
|---|---|---|
| Avant I | Crochet, Colère 1 | Remplace Tir : commencer à ramener ses cibles |
| Après I | Estoc, Colère 2 | La frappe à 2 PA permet une nouvelle composition de tour |
| Après II | Ouvrir Éaque, apprendre Heurt : Éaque 1 | Remplace Garde ; accepter une sécurité basée sur la poussée |
| Après III | Fauchage : Colère 3 | Remplace Percée ; les quatre actions deviennent offensives |
| Après IV | Brise-formation : Colère 4 | Les placements forcés préparent une attaque de mêlée différente |
| Après V | Bond : Colère 5 | Premier essai d'une entrée alternative à Fauchage ; il peut rester en réserve |
| Après VI | Pas victorieux : Colère 6 | Activer une seconde liaison ; une élimination peut créer la sortie manquante |
| Après VII | Le combat qui avance : Colère 7 | Le Fauchage appris tôt transforme maintenant une zone en poursuite |

Salles VIII–XII : cinq rencontres avec cette légende, dont quatre avant le final. Les acquisitions restantes servent à élargir les outils secondaires, préparer une variante ou économiser un point ; aucune dernière récompense indispensable n'attend la mort du boss.

La spécialisation signifie ici **six ou sept choix dans la doctrine principale et des outils dans la seconde**. Une doctrine seule n'offre que sept achats compatibles : ce document ne prétend pas qu'on peut y investir les douze points. Pour un joueur qui refuse toute seconde école, garder des points doit rester possible ; si cette frustration apparaît en test, proposer des choix de kit moins fréquents sera préférable à inventer cinq passifs de remplissage.

## 7. L'économie d'action et les limites qui rendent les choix vrais

### Faire de 6 PA une composition

Trois coûts jouent trois rôles : **1 PA** pour la mobilité ou un rappel préparé ; **2 PA** pour une intervention ciblée ; **3 PA** pour un impact ou un écran ; les signatures à **4 PA** engagent le tour. Un coût n'est pas une notation de qualité.

À Prouesse 18, avant mitigation et effets, Estoc/Crochet/Heurt représentent environ 6/5/5 dégâts après arrondi, soit 16 au total. Frappe/Tir donnent 10/9, soit 19. Le trio proposé gagne des déplacements adverses et de la souplesse, pas une supériorité automatique de dégâts. La possibilité de jouer les trois dépend encore des cases et de la cible choisie.

Ne pas chercher à vider tous les PA dans tous les builds. Un PA restant dans une position sûre peut être une bonne décision. En revanche, trois tours consécutifs où le joueur ne peut utiliser qu'un seul bouton révèlent un problème à examiner.

### Contrats des réactions

1. **Un cast → au plus une fenêtre de choix optionnel.** Si Angle impossible, Pas victorieux ou Bastion sont simultanément disponibles, les présenter ensemble avec « passer ». Aucun empilement de trois petites interruptions.
2. **Deux cases gratuites maximum par activation** venant des liaisons, jonctions et légendes de déplacement. Les déplacements inclus dans un sort payé en PA, les PM normaux et le Bond ne consomment pas ce plafond. Un pas de réaction déclenche les terrains mais ne déclenche pas une nouvelle liaison de déplacement.
3. **Zéro remboursement de PA dans la première version.** Pas de chaîne d'éliminations illimitée. Une réaction de dégâts n'accorde pas une nouvelle réaction d'élimination ou un second compteur de combo.
4. **Une attaque de réaction par intervalle d'activations d'Achille**, incluant la phase adverse, les légendes, Bastion et les reliques compatibles. Un déclenchement de Bastion compte comme une attaque même s'il touche plusieurs ennemis ; sa conversion est indisponible si ce quota est consommé. Le compteur est réinitialisé au début de son activation. Le joueur choisit ses priorités au camp ; une attaque inexécutable ne consomme pas la fréquence.
5. **Les réactions possèdent leur propre attaque.** Contre d'Éaque et la poursuite de Fauchage n'appellent pas en cachette Frappe équipée. Un prérequis de sort équipé, s'il existe pour une autre maîtrise, est affiché avant qu'on le range.
6. **Une mutation géométrique principale par sort ; une origine par projectile.** On ne combine pas les zones de deux formes exclusives. Origine du souvenir, écran ou position actuelle sont des options alternatives, pas trois tirs.
7. **Les contrôles utilisent les règles communes.** Pas de dégâts bonus pour une attraction simplement refusée ; pas de collision inventée ; pas d'ennemi poussé hors carte ou dans VOID sans contrat dédié. Immunité et destination illégale sont prévisualisées.
8. **Pas de Garde renouvelable gratuitement.** Les conversions consomment leur source nommée ; elles ne puisent pas dans tous les boucliers. Les groupes de conversion concurrents des reliques restent exclusifs.

Ces limites sont des hypothèses de prototype. Elles visent à garder la profondeur lisible et à éviter qu'un moteur de réactions fasse disparaître le choix du joueur.

## 8. Une progression faite pour 10 à 15 salles

**Recommandation : prototyper douze rencontres avec un calendrier de kit garanti, indépendant de l'XP.** Réutiliser les cartes est suffisant pour cette étape ; la conception des ennemis, objectifs et boss vient après la preuve du personnage.

Un point avant I, puis un après chacune des onze salles non finales : **douze points disponibles**. L'XP conserve le rôle de faire grandir les statistiques. Les récompenses de maîtrise par niveau et les leçons achetables ne s'ajoutent pas à ces points dans ce profil expérimental ; sinon Sagesse, Gloire et argent réintroduiraient les mêmes écarts de calendrier.

Sagesse et Gloire peuvent encore accélérer la progression statistique dans le premier test, mais leurs rendements doivent être observés. Elles n'avancent aucun accès à une technique, signature ou légende. L'objet ou le consommable n'est jamais requis pour débloquer le personnage promis.

| Format | Budget de kit | Deuxième école | Liaisons | Signatures | Légende | Salles jouées avec la légende si achetée immédiatement |
|---|---:|---|---|---|---|---:|
| **10 salles** | 10 : départ + après I–IX | Après II | Après III | Après IV | Après VI | VII–X : 4 |
| **12 salles** | 12 : départ + après I–XI | Après II | Après III | Après V | Après VII | VIII–XII : 5 |
| **15 salles** | Plafond 12 : départ + après I–XI | Après II | Après IV | Après VI | Après IX | X–XV : 6 |

Les seuils d'investissement 2/3/4 dans l'école restent identiques. Les jonctions arrivent après IV dans les formats 10/12 et après V dans le format 15. « Investis » signifie les points légalement acquis **avant** l'achat, hors nœuds remboursés ; les seuils de salle suivent les victoires requises et ne peuvent pas être avancés par répétition ou chargement.

Le format quinze donne davantage de temps avec le build, pas quinze couches de passifs. Après XI, les récompenses portent sur équipement, choix tactiques de run et occasions de recomposer, pas sur de nouveaux points de kit.

### Rythme des décisions

Après une victoire, un seul espace réunit acquisition, quatre slots et validation du prochain kit. L'achat de caractéristiques et les objets peuvent y être accessibles sans imposer trois validations successives. Le joueur peut garder son point et continuer. Pas d'ouverture automatique de l'Atlas entier à chaque récompense.

Il faut alterner découvrir, pratiquer puis transformer. Si un nouveau mécanisme par salle empêche de comprendre le précédent, conserver le point garanti mais différer volontairement sa dépense ; tester ensuite une cadence plus espacée. La constance du financement ne doit pas devenir une obligation de lire trente fiches.

Douze combats ne garantissent pas une run rapide : `12 × durée moyenne d'une salle + choix + transitions`. À deux minutes par rencontre, on atteint déjà vingt-quatre minutes avant menus. À quatre minutes, quarante-huit. Ce sont des exemples arithmétiques, pas des durées observées. Les anciennes cibles 18–25 minutes ne doivent pas être reportées sans mesure. Il faut construire vite le format, puis mesurer sa durée réelle.

## 9. Statistiques, équipement et futures épreuves

### Séparer profondeur et inflation

La courbe actuelle monte de 110 à 600 PV et de 18 à 100 Prouesse au niveau 10. Pour comparer les kits, commencer par des héros au **même niveau, même équipement et mêmes consommables**, puis réintroduire cette courbe en test d'attrition. Le nouveau catalogue ne doit pas être déclaré intéressant parce que le héros tue seulement plus vite.

Ne pas fixer aujourd'hui une nouvelle courbe complète de PV ennemis : elle masquerait l'objet du test. Tester ensuite des courbes de croissance plus modérées en vérifiant le nombre d'actions nécessaires pour tuer et le nombre de fautes de position tolérées. Préserver les blessures lorsque les PV max augmentent.

### Le rôle des objets

L'arbre donne l'action. L'objet infléchit un usage. L'arme passive ne remplace pas silencieusement un slot et ne crée pas de cinquième attaque.

Les reliques actuelles de collision, mobilité et conversion de Garde ont un rôle à garder, mais leurs filtres doivent comprendre les nouvelles techniques. Une relique d'alternance Frappe/Tir peut devenir une relique de deux offensives manuelles distinctes ; ce changement n'est pas automatiquement compatible avec tous les déclencheurs actuels et doit être testé.

Quelques directions de reliques ultérieures : déplacer l'ancre de Lance d'une case après une élimination, convertir une collision en écran d'une case, permettre une première attaque depuis le bord du Rempart. Une seule exception lisible par objet ; aucun de ces objets n'est nécessaire au fonctionnement normal des techniques.

Les réserves de soin, les plafonds de marchand et les revenus actuels ne sont pas calibrés pour douze salles. Leur révision appartient à la passe de run qui suit. Pour le test de kits, utiliser un contexte d'équipement contrôlé ; pour celui d'attrition, annoncer et enregistrer exactement les soins disponibles.

### Le contrat transmis aux futurs ennemis et cartes

Il suffit à ce stade de demander des **problèmes tactiques** : une cible isolée ou protégée, deux angles de tir, un obstacle utile à une collision, une formation qui se défait, une pression au contact, une fenêtre courte d'engagement, une cible qu'il vaut mieux déplacer que tuer immédiatement.

Chaque grande menace doit laisser plusieurs réponses parmi déplacement normal, déplacement forcé adverse, blocage de ligne, mitigation, interruption prévue ou élimination. Aucun passage obligatoire ne doit exiger précisément Garde, Percée ou la signature d'une école. Une faiblesse de build augmente le prix d'une réponse ; elle ne supprime pas arbitrairement toutes les réponses.

Pour Achille solo, éviter comme norme le contrôle qui saute intégralement une activation. Préférer modifier les options et les coûts tout en laissant une décision. Préparer des épreuves de kit avant de concevoir les malus globaux, mini-boss et boss définitifs.

## 10. La sensation de jeu à produire

Une acquisition forte doit se reconnaître sans lire un nombre : une silhouette ennemie attirée dans le front du Fauchage ; un départ et une arrivée de Pas du chasseur ; un Rempart qui coupe réellement un projectile ; une ancre et sa future ligne de retour ; un bouclier consommé qui rend le héros visiblement exposé.

**Avant le cast :** montrer PA dépensés, cellules touchées, déplacements forcés, case finale, dommages et protection restants. Pour une technique en deux sélections, afficher le résultat complet avant engagement ; permettre le retour à la première sélection. Pour Lance, montrer la ligne du retour hypothétique depuis une position survolée sans la présenter comme une prédiction de déplacement ennemi.

**Au moment décisif :** animation et son soulignent le contact, la collision, la rupture de Garde ou le rappel. Les contacts d'armes doivent rester cohérents avec les assets disponibles ; réutiliser une animation n'est pas une validation artistique. Le VFX suit les événements du moteur, pas l'inverse.

**Après l'action :** une réponse claire, puis rendre la main dès que l'état tactique est lisible. Les pauses spectaculaires doivent servir une collision, une élimination ou une transformation, pas chaque lancement. Les réactions d'une même action se lisent dans une seule fenêtre, avec option de les passer.

**Dans le choix d'évolution :** montrer « Garde sort du kit ; Crochet entre ; protection garantie perdue ; attraction disponible » et un exemple de tour. Une mutation à 2 PA montre sa nouvelle combinaison à 6 PA. Un bouton de comparaison expose le kit avant/après et les maîtrises inactives. Les nouveaux sorts sont distingués des mutations par leur forme de carte et leur libellé, pas uniquement par couleur.

## 11. Comment le réaliser sans construire tout le catalogue d'un coup

### Étape A — prouver la recomposition

Profil de progression expérimental isolé, en conservant le contenu actuel comme comparaison. Réutiliser les mécanismes d'isolation de run déjà présents ; le chemin `odyssey` ne doit pas être pris pour une seconde aventure à créer.

Implémenter uniquement : **Crochet, Heurt, Fauchage**, **Estoc pressant**, remplacement libre des quatre slots au camp, acquisition garantie et **une** liaison active parmi Pas victorieux / Brise-formation. Les quatre techniques actuelles restent la base. On peut déjà jouer La lame nue et Le duelliste de bronze, donc vérifier précisément le pari demandé : abandonner une défense ou un déplacement pour une action offensive.

Utiliser les cinq salles pour les premiers essais, avec attribution contrôlée des acquisitions avant les scènes de revue. Aucune victoire forcée ne vaut preuve d'équilibrage. On peut tester les trois techniques séparément et mesurer ensuite le kit entier.

### Étape B — éprouver douze rencontres

Ajouter Trait de rupture, Pas du chasseur et Égide de passage : **six apprentissages simples au total**. Déployer le calendrier de douze points et les premières mutations spatiales. Réutiliser les cinq cartes avec douze occurrences de rencontres distinctes, rosters et départs variés. Une occurrence doit avoir son propre identifiant de récompense : dupliquer `encounter_id` ferait perdre XP et drachmes à la répétition.

Avant de considérer les nouvelles signatures implémentées, déplacer provisoirement une transformation existante comme le Rempart au jalon du milieu pour éprouver le moment d'acquisition. Documenter ce substitut ; ne pas déclarer la V1 complète sur cette base. Les cartes et adversaires définitifs restent un chantier suivant.

### Étape C — produire les signatures et légendes

Ordre recommandé : **Rempart autonome**, puis **Bond**, puis **Lance du retour**. Le premier réutilise beaucoup de comportements existants, le second introduit une entrée distincte, le dernier apporte une nouvelle gestion d'état et de trajectoire. Une légende représentative par école, puis les alternatives et jonctions après validation.

Le catalogue de treize sorts et trente choix est la destination ; ce n'est pas la taille minimale nécessaire à la première preuve de plaisir.

### Travail technique nécessaire

| Domaine | Base existante | Extension requise |
|---|---|---|
| Sorts connus / équipés | `SpellLoadoutState`, synchronisation avec `unit.spells` | Parcours camp, apprentissage par maîtrise, quatre slots génériques, validation de kit |
| Données de maîtrise | Modificateurs ciblés, effets réactifs, exclusions | Acquisition de sort et mutation explicites ; nouveaux prérequis de jalon ; retirer les hypothèses de topologie figée concernées |
| Progression | Champion, XP, attributs, déduplication des victoires | Points de kit garantis indépendants, pas de double attribution niveau/camp, jalons identifiables et idempotents |
| Réactions | Files optionnelles, priorités, réservation de fréquence | Catégories d'actions, attaque de réaction autonome, budget commun de pas et de réactions, dépendances affichées |
| Persistance | Snapshot inventaire/progression V5 | Connus, quatre slots ordonnés, mutations, doctrines, liaisons actives, jalons/points ; version et migration explicites |
| Aperçus | Resolver partagé combat/codex | Même calcul pour nouveaux sorts, variantes, origine et case d'arrivée ; aucun résultat d'interface recalculé à part |
| Theorycraft | Lecture du profil résolu, énumération PA | État Champion complet et coefficients réels ; séquences sur 2–3 activations avec plateau ; ne pas assimiler séquence abordable à séquence légale |
| Studio | Outils d'édition et validations existants | Acquisitions, mutations, exigences d'équipement, nouvelles géométries et copies isolées ; round-trip données sans mutation de la référence |

Le snapshot inter-salles doit suffire au kit persistant. Un combat en cours, ses ancres et réactions nécessiteraient un autre contrat de sauvegarde ; ne pas l'ajouter implicitement à cette refonte.

## 12. Les preuves à exiger

### Vérifications fonctionnelles ciblées

- Apprendre une cinquième technique, remplacer chaque slot, revenir au kit précédent ; aucun slot privilégié.
- Recharger le snapshot et retrouver mêmes sorts connus, même ordre, mêmes points, mutations et liaisons ; rollback complet d'un état invalide.
- Rembourser un apprentissage et toutes dépendances concernées ; aucun effet fantôme, duplication ou maintien gratuit après remboursement.
- Retirer Frappe puis déclencher Contre ; son attaque autonome fonctionne. Retirer Garde n'invalide pas Heurt. Les maîtrises exigeant une source absente sont signalées.
- Appliquer exactement une récompense par victoire, y compris après rechargement ; aucun gain de kit supplémentaire par Sagesse, Gloire ou leçon d'ancienne économie.
- Tester chaque géométrie au bord de carte, contre obstacles, unités, VOID, immunités et surfaces ; preview et résolution concordent.
- Tester deux signatures équipées, une légende, les deux liaisons actives et une relique réactive : quotas communs et exclusions restent vrais.
- Contrôler Lance sur trois activations : lancement, rappel anticipé interdit, changement d'origine, obstacle, expiration sans rappel, mort de cible, fin de rencontre ; pas d'ancre persistante en salle suivante.
- Vérifier la récupération de Bond/Rempart avec la convention A/A+1/A+2 et l'absence de réinitialisation par remplacement au milieu d'une rencontre.
- Import Godot, suites touchées, puis parcours runtime du camp vers combat et retour. Contrôler visuellement les nouveaux casts et l'interface aux résolutions de référence 1920 × 1080 et 1280 × 720, plus la résolution étroite utilisée par le projet.

### Playtest : est-ce vraiment un autre Achille ?

Comparer le kit actuel, La lame nue, Le duelliste et un Chiron mobile dans des situations identiques, au même niveau. Alterner l'ordre de présentation pour réduire l'effet de nouveauté. Commencer par 6–8 joueurs ou sessions exploratoires ; ce volume sert à découvrir des problèmes, pas à prouver un taux de préférence de la population.

| Question | Observation ou mesure |
|---|---|
| Le premier choix change-t-il le comportement ? | Le joueur peut nommer une nouvelle action ou situation recherchée dès les deux premières salles ; relever ses casts réels |
| Le remplacement est-il un choix ? | Noter ce qui est retiré, ce que le joueur pense perdre et s'il revient dessus après essai |
| Les nouveaux sorts sont-ils désirables ? | Achat, équipement et usage suivis séparément ; connaître un sort sans jamais le sortir n'est pas une réussite automatique |
| Un build a-t-il une identité ? | Comparer ordres d'action, géométries visées et positions finales ; demander au joueur de décrire sa boucle sans citer un pourcentage |
| Sacrifier Garde/Percée reste-t-il jouable ? | Mesurer tours sans action utile, dégâts subis, réponses au danger et causes d'échec ; distinguer mauvaise décision et impossibilité structurelle |
| Les transformations arrivent-elles à temps ? | Salle du premier remplacement, première liaison utilisée, première signature utilisée, nombre de combats réellement joués avec la légende |
| La lecture devient-elle trop lourde ? | Temps de décision au camp, demandes d'explication, réactions passées, temps d'attente subi ; séparer découverte et sessions suivantes |
| Le kit domine-t-il sans contrepartie ? | Croiser cible isolée, groupe, accès difficile et pression multiple ; un kit qui gagne partout avec la même séquence doit être revu |

Signaux d'alerte exploratoires : Garde/Percée jamais remplacées malgré les offres ; Égide de passage présente dans presque tous les kits ; une même séquence répétée sans adaptation pendant trois activations ; un sort acquis mais jamais utile sur plusieurs salles ; plus de temps passé à résoudre des réactions qu'à choisir des actions. Ce sont des déclencheurs d'enquête, pas des verdicts automatiques.

**Critère de passage à la conception des ennemis :** au moins trois kits dont les joueurs comprennent la boucle, les sacrifices et une manière de se sortir d'une erreur ; une première recomposition utilisée tôt ; une transformation majeure jouée sur plusieurs rencontres. Le taux de victoire et le ressenti devront être observés dans le prototype réel avant de déclarer Achille équilibré ou satisfaisant.

## 13. Arbitrages à garder visibles

La recommandation ferme est de rendre les slots libres, d'enseigner de nouveaux sorts tôt, de garantir les acquisitions importantes et de préserver des faiblesses choisies. Le plafond de deux doctrines, le nombre de liaisons actives, les coefficients, la réorientation gratuite et Lance du retour sont des hypothèses à éprouver.

Ce dossier prend la demande actuelle comme autorisation de rouvrir la conception des arbres ; les anciens gels P0 restent des documents historiques du slice. Il prépare une implémentation révisable. Aucun changement de gameplay, nouvelle run, nouveau boss ou validation runtime n'a été effectué par sa rédaction.
