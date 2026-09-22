# Créer un personnage qui change vraiment la manière de jouer

Recherche et proposition pour **Catabase — variante Cartes**, 22 septembre 2026.
Base du dépôt examinée : `b6973d6d`. **Document de conception, pas une liste de
fonctionnalités livrées.** Les valeurs proposées servent à cadrer des prototypes ;
elles ne sont pas présentées comme équilibrées.

## 1. Conclusion de la recherche

Notre prochaine étape doit être une différenciation des **règles de décision**.
Les nouveaux decks distinguent les classes, mais leurs spécialisations restent
surtout des bonus conditionnels. Le joueur choisit encore souvent la meilleure
conversion de PA en dégâts, puis utilise déplacement et protection pour pouvoir
continuer. Ajouter cinquante variantes de dégâts ne suffira pas.

Une création intéressante annonce et rend immédiatement jouable une manière
de résoudre les combats : détourner des ressources, construire un réseau,
convertir une défense, manipuler des effets persistants. Le deck trouvé ensuite
doit transformer cette manière de jouer, pas simplement relever ses chiffres.

**Direction proposée : une règle centrale par classe, deux doctrines réellement
différentes au départ, un deck initial fonctionnel, puis des transformations
pendant la run.** Chaque règle doit rencontrer des ennemis et des terrains qui
lui donnent plusieurs usages. Les intentions ennemies annoncées ne constituent
pas le moteur de cette proposition.

### Méthode et limites

Le corpus couvre onze jeux, choisis pour leur complémentarité : RPG tactiques,
MMO de placement, deckbuilders, roguelites et ARPG. Il ne constitue pas un
classement objectif des « meilleurs jeux ». Une mécanique documentée n'est pas
une preuve qu'elle améliore automatiquement notre jeu.

Les passages **Observation** décrivent les sources ; **Transposition** exprime
une analyse ; les sections 5 à 11 sont nos propositions. Les publications
historiques sont datées : aucune ancienne valeur n'est donnée comme l'équilibrage
actuel du jeu concerné. Les sources sont des publications de développeurs ou
d'éditeurs ; deux devblogs Ankama sont consultés dans leur reproduction JOL,
explicitement attribuée au texte original. Leurs commentaires communautaires
ne servent pas de preuve. Les liens ont été consultés le 22 septembre 2026.

Cette passe comprend des recherches et une lecture du code, **pas de nouvelles
parties jouées**. Les résultats de runs cités viennent de l'audit du 21 septembre.

## 2. Ce qui aplatit notre gameplay aujourd'hui

### 2.1 Des identités encore dominées par les coefficients

Dans [class_card_modifier.gd](../../core/expedition/class_card_modifier.gd),
les passifs favorisent une première attaque au contact contre une cible isolée,
une garde, une attaque distante ou une attaque magique sur une cible préparée.
Les spécialisations remplacent ce passif par d'autres conditions de dégâts/garde.
Elles ne donnent pas un nouveau système de dépense, de récupération ou de
transformation. Une condition spatiale peut être intéressante ; elle ne suffit
pas à différencier durablement quatre classes si son aboutissement reste le
même calcul de dégâts.

[class_cards.gd](../../core/expedition/class_cards.gd) confirme un autre décalage :
la spécialisation arrive au niveau 4. Le choix initial de cinq familles sur sept
donne une composition, mais ne permet pas encore de choisir une doctrine qui
modifie les règles de la classe dès le premier combat.

### 2.2 Beaucoup de cartes, moins de fonctions distinctes

L'[audit du 21 septembre](card_catalog_and_selection_audit_2026-09-21.md)
recense 112 familles publiques : 28 d'initiation, 60 usuelles, 16 rares et
8 épiques. Elles mobilisent 29 codes d'effet, dont plusieurs variantes d'une
même fonction. Le catalogue comprend notamment cinq familles de surfaces,
mais aucune invocation du côté des cartes joueur. « Envoûté » attire et retire
un PA ; cela ne donne pas le contrôle d'un ennemi.

Le problème n'est donc pas simplement le nombre de cartes. Il faut augmenter
le nombre de **relations utiles entre les cartes et l'état du combat** :
consommer un effet plutôt que l'ajouter ; déplacer une réserve ; récupérer une
carte en sacrifiant autre chose ; interrompre une coopération ; transformer
un outil ennemi en opportunité.

### 2.3 Une synergie dans le deck n'est pas une synergie accessible

Avec dix cartes, quatre en main et deux copies de chaque composant d'un combo
à deux familles, une main initiale uniforme contient les deux composants dans
40,48 % des cas. Cela ne tient encore compte ni du placement ni des PA.
Calcul : `1 − 2 × C(8,4)/C(10,4) + C(6,4)/C(10,4)`.

Dans les douze runs instrumentées du 21 septembre, 349 des 755 sorts du héros
étaient des gestes de secours, soit 46,2 %. Ce pilote glouton joue mal certaines
combinaisons : ce chiffre **ne prouve pas** que les joueurs humains feraient
pareil. Il signale néanmoins une hypothèse à tester : une action universelle
fiable peut concurrencer une identité de classe qui dépend d'une bonne main.

### 2.4 L'acquisition ne permet pas toujours de construire volontairement

L'audit estime à 42,84 % la probabilité de ne recevoir aucune carte au premier
combat normal, sans mémoire de malchance. C'est compatible avec le choix produit
de vrais drops aléatoires. Cela devient problématique si la classe attend
précisément un drop pour commencer à fonctionner.

La boutique tire actuellement dans les quatre classes sans rechercher les
fonctions manquantes du deck. Une offre peut être légalement jouable tout en
aidant peu à développer le personnage. Il faut distinguer acquisition,
utilisation et transformation effective de la stratégie.

### 2.5 Les ajouts récents apportent des bases à réutiliser

Les [salles tactiques](../../core/expedition/card_tactical_room_catalog.gd)
comprennent désormais convoi et réservoirs. Le convoi oppose interception,
livraison et soutien du chef. Les réservoirs stockent des PA ; les ennemis
adjacents peuvent voler une charge et se soigner. Ce sont déjà des interactions
sur lesquelles travailler : elles ne doivent pas être décrites comme absentes.

En revanche, forge, anneau du jardin et sablier reposent largement sur des
dangers de zone périodiques ou annoncés. Ils peuvent varier des rencontres,
mais ne répondent pas à eux seuls à la demande d'identités, de sorts et de
coopérations ennemies. Une salle originale ne remplace pas une classe originale.

Les anciens diagnostics d'invocation et d'identifiants de ralentissement restent
des points d'intégration à revalider avant un prototype. Le code lu reconnaît
encore `class_slow` dans le passif, tandis que la glace crée `ecosystem_ice`.
Un effet conceptuellement semblable doit être reconnu par ses propriétés,
sinon une combinaison promise ne fonctionne que dans une partie des situations.

## 3. Les références : ce qu'elles nous apprennent précisément

### 3.1 Baldur's Gate 3 : une identité qui a plusieurs conséquences

**Observation.** Dans sa présentation de création du 2 octobre 2020, Larian
relie race, historique et classe aux capacités du personnage et aux réactions
du monde. Le studio distingue aussi capacités magiques répétables et sorts
limités entre repos. Cette publication concerne l'accès anticipé, pas le
catalogue actuel de classes. [Source Larian](https://baldursgate3.game/news/community-update-8-character-creation_9).

**Transposition.** Chaque choix de création doit avoir une conséquence que le
joueur pourra reconnaître : ce qu'il fait en combat, ce qu'il veut trouver,
ce qu'il peut négocier au refuge. Montrer une courte situation jouable en dit
plus que douze pourcentages. L'apparence peut rester indépendante du gameplay.

**Limite.** Notre run courte n'a ni la durée ni les dialogues d'un grand RPG.
Ajouter origines, alignements, races et six attributs serait coûteux si ces
choix ne changent pas les situations rencontrées. Copier la richesse du menu
avant celle des conséquences reproduirait notre problème.

### 3.2 DOFUS : choisir implique de renoncer à une fonction

**Observation.** Le devblog de conception du 15 novembre 2016 décrit des
variantes mutuellement exclusives dans un combat et modifiables entre combats.
Il vise notamment la conversion d'un rôle secondaire en orientation principale.
Il critique aussi les sorts communs qui s'ajoutent sans coût de sélection et
la complexité de niveaux de sorts que tous peuvent finalement maximiser.
C'est un document d'intention historique, dont le calendrier a ensuite évolué.
[Texte Ankama reproduit et sourcé par JOL](https://dofus.jeuxonline.info/actualite/51619/variantes-sorts).

**Transposition.** Une doctrine Gardien pourrait permettre de transporter sa
protection, en renonçant à maintenir plusieurs positions protégées. Une carte
pourrait expulser une cible ou maintenir un obstacle, sans faire parfaitement
les deux. La valeur du choix vient de la capacité abandonnée.

**Limite.** Il ne faut pas reprendre le délai de progression d'un MMO. Le
premier renoncement intéressant doit arriver avant le départ. Et une carte
hybride trouvée doit rester une découverte jouable, pas exiger des heures
d'investissement dans une seconde classe.

### 3.3 WAKFU : une classe construit un petit système sur le terrain

**Observation historique.** Le devblog Steamer de septembre 2013 associe rails,
microbots, blocs et modes de fonctionnement. Il explique vouloir rendre la
mise en place moins lourde ; les rails doivent aussi servir aux alliés. Certains
sorts changent d'usage selon qu'ils visent une unité ou une case vide.
[Devblog Ankama reproduit par JOL](https://wakfu.jeuxonline.info/actualite/41534/devblog-refonte-steamer).

**Contre-exemple utile.** Dans ses annonces de juillet 2026, Ankama souligne
que la rigidité et la difficulté de compréhension des outils du Féca ne sont
pas compensées par une richesse de jeu suffisante. Le studio souhaite aussi
des mécanismes plus fiables pour le Sacrieur et plus souples pour le Roublard.
Il s'agit de diagnostics et d'intentions de refonte, pas de résultats prouvés.
[Publication officielle WAKFU sur Steam, « Ankama's 25th Anniversary Convention »](https://steamcommunity.com/app/215080/announcements/).

**Transposition.** Balises et ancrages doivent être posés rapidement, réutilisés
de plusieurs façons et contestables. Un personnage qui passe trois tours à
installer son identité pendant que l'autre frappe n'est pas profond : il peut
simplement être laborieux. Prévoir un usage immédiat et un usage préparé.

### 3.4 Divinity: Original Sin 2 : la classe n'enferme pas toutes les interactions

**Observation.** Larian décrit un système sans classes rigides, avec des
préréglages pour faciliter le départ ; attributs, capacités, talents et sorts
définissent ensuite le personnage. La présentation officielle du jeu met
également en avant hauteur, environnement et manipulation des éléments.
[FAQ Larian, décembre 2025](https://forums.larian.com/ubbthreads.php?Number=959594&an=82&ubb=showflat),
[présentation de l'éditeur](https://store.steampowered.com/app/435150/Divinity_Original_Sin_2__Definitive_Edition/).

**Transposition.** La classe donne une compétence particulière sur un système
partagé. Le Thaumaturge sait convertir une surface ; les autres peuvent toujours
y pousser un ennemi, l'éviter ou l'utiliser avec une carte trouvée. C'est plus
fécond que quatre systèmes étanches.

**Limite.** Ne pas construire une simulation de dizaines de réactions avant de
valider trois interactions lisibles. Les murs, zones et états doivent suivre
les mêmes règles pour le joueur et les ennemis, avec les exceptions affichées.

### 3.5 Gloomhaven : la main et le terrain peuvent définir la classe

**Observation.** La présentation officielle de la deuxième édition décrit deux
cartes choisies par round, dont on joue le haut de l'une et le bas de l'autre.
Elle distingue notamment le Cragheart par la création/destruction d'obstacles,
et la Spellweaver par la récupération d'actions puissantes normalement
utilisables une seule fois dans le scénario. [Source Cephalofair](https://cephalofair.com/products/gloomhaven-board-game-2nd-edition).

**Transposition.** Une spécialisation peut changer ce qu'une carte devient
après usage : récupérable, mise en réserve, échangée contre une autre fonction.
Une autre peut manipuler les cases traversables. La classe change alors la
planification, même si les dégâts restent identiques.

**Limite.** Le double usage de toutes les cartes doublerait notre charge de
lecture. Commencer par quelques cartes à deux modes clairement visibles. Une
carte épuisée pour le combat ne doit jamais être confondue avec un objet perdu
définitivement dans la run.

### 3.6 Slay the Spire : équilibrer des contextes, pas un classement de cartes

**Observation.** Dans sa conférence GDC 2019, Anthony Giovannetti présente
l'objectif de donner une place aux cartes sans qu'une carte déforme trop le jeu.
Il insiste sur les tests, les retours qualitatifs et une lecture prudente des
métriques, notamment selon le niveau des joueurs. [Présentation du concepteur](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).

**Transposition.** Nos cartes doivent avoir des situations où elles deviennent
préférables. Comparer uniquement dégâts/PA élimine précisément l'intérêt d'une
conversion, d'une réserve ou d'un déplacement. Mesurer aussi les alternatives
abandonnées et les conditions d'utilisation.

**Limite.** Notre jeu garde des drops dans le reçu de combat, pas un choix
systématique de trois cartes. Nous ne reprenons pas non plus les intentions
ennemies comme source de profondeur. Cette référence sert ici à la méthode de
construction et d'équilibrage du catalogue.

### 3.7 Monster Train : des identités combinables et des investissements spatiaux

**Observation.** Le premier Monster Train permet d'associer un clan principal
et un clan de soutien ; les cartes peuvent recevoir des améliorations et
certaines étapes permettent d'en dupliquer. Le jeu distribue le combat sur
trois étages. Dans l'extension, le site officiel décrit les Échos des Wurmkin
comme une ressource locale pouvant soutenir l'ensemble d'un étage.
[Présentation du premier jeu](https://store.steampowered.com/app/1102190/Monster_Train/),
[description officielle des clans](https://www.themonstertrain.com/clans).

**Transposition.** L'hybridation devient intéressante quand deux classes
partagent un objet manipulable : garde, position, effet ou ressource. Une
poussée Gardien qui traverse une balise Arpenteur a une raison d'exister au-delà
de l'accès à une carte de couleur différente.

**Limite.** Ne pas imposer une seconde classe dès la création. Cela fixe trop
tôt une combinaison et augmente les explications. Laisser les drops proposer
une bifurcation ; expliciter la compatibilité lors de l'acquisition.

### 3.8 Hades : le choix initial change la valeur des récompenses futures

**Observation.** Les notes officielles de 2020 montrent des améliorations
transformant une action, par exemple un spécial converti en attaque distante
chargée. Elles introduisent aussi des variantes de bienfaits de lancer liées
à l'aspect de Beowulf. L'identité de départ influe donc jusque sur la forme
des améliorations. [Notes de Supergiant, Blood Price Update](https://www.supergiantgames.com/blog/6/).

**Transposition.** Un objet pourrait permettre à un Gardien de déplacer sa
réserve plutôt que d'augmenter sa garde de 15 %. Une découverte change les
combinaisons recherchées et la façon d'occuper le terrain. Le personnage est
reconnaissable dès le départ, mais sa forme finale reste ouverte.

**Limite.** Les réflexes d'un jeu d'action ne se transposent pas directement
aux PA. Traduire les transformations en coût, portée, destination et timing
explicites. Éviter les déclenchements automatiques opaques.

### 3.9 Last Epoch : modifier le fonctionnement d'une compétence

**Observation.** Le devblog de 2018 donne des exemples de saut transportant les
invocations ou frappant les ennemis survolés, et de météore consommant tout le
mana restant. Il explique aussi pourquoi limiter les compétences équipées
crée des choix. L'aide officielle actualisée en février 2026 confirme un
maximum de cinq compétences spécialisées et des moyens de respécialisation.
[Devblog EHG](https://forum.lastepoch.com/t/skills-to-pay-the-bills/1333),
[aide actuelle](https://support.lastepoch.com/hc/en-us/articles/46363203944859-Skill-Specialization).

**Transposition.** Les améliorations individuelles doivent parfois modifier
le ciblage, la dépense ou le devenir d'une carte. Exemple original pour nous :
une poussée expulse une cible, ou déplace ensemble cible et ancrage ; une garde
reste personnelle, ou devient une réserve sur une dalle.

**Limite.** Un arbre par carte serait disproportionné pour 112 familles.
Commencer par quelques transformations majeures, exclusives, sur les outils
centraux. Une interface à deux options peut contenir un choix très profond.

### 3.10 Grim Dawn : relier un déclencheur à une capacité

**Observation.** Le guide officiel décrit l'association de deux maîtrises.
Le système de Dévotion ajoute notamment des pouvoirs liés à des compétences,
avec des conditions de déclenchement différentes ; les affinités servent de
prérequis. [FAQ Crate](https://www.grimdawn.com/guide/about/faq/),
[guide Dévotion](https://www.grimdawn.com/guide/character/devotion/).

**Transposition.** Un emplacement limité de « lien » pourrait faire dépendre
un effet du déplacement d'un ennemi ou de la consommation d'une réserve. Le
joueur choisirait quelle carte porte ce lien : même catalogue, organisation
différente.

**Limite.** C'est une couche ultérieure, après les moteurs de classe. Ajouter
maintenant un grand arbre et des réactions en cascade rendrait plus difficile
de comprendre ce qui produit les résultats. Toute boucle doit avoir une
source, une limite et un coût traçables.

### 3.11 Griftlands : le personnage existe aussi dans ses décisions de parcours

**Observation.** Klei présente un deckbuilder où négocier, combattre, choisir
des contrats et des relations participent à la trajectoire de la run.
[Présentation officielle](https://www.klei.com/games/griftlands).

**Transposition.** Une doctrine peut créer des offres de refuge pertinentes :
recycler une carte, orienter une recherche de butin, choisir une récompense
liée à une fonction. La création prépare ainsi des décisions ultérieures,
sans livrer d'avance le personnage final.

**Limite.** Un second système complet de négociation n'est pas prioritaire.
Quelques décisions de parcours ayant des conséquences mécaniques suffisent
pour expérimenter cette continuité.

## 4. Les principes retenus pour Catabase

| Principe | Critère concret de réussite | Faux équivalent à éviter |
|---|---|---|
| Une classe change les décisions | Même terrain et même main de rôles équivalents : plans différents | Une autre couleur et +20 % dans une condition |
| Une doctrine comporte un renoncement | Elle améliore une façon d'agir en abandonnant une autre | Une branche strictement meilleure à niveau égal |
| L'identité fonctionne au départ | Première salle intéressante sans drop | Attendre l'épique qui débloque le personnage |
| Les règles se combinent | Une ressource a au moins deux dépenses concurrentes | Empiler trois bonus sur la même attaque |
| Le terrain compte | Déplacer une unité change la valeur de plusieurs actions | Des cases décoratives ou un simple malus |
| L'ennemi participe au système | Il peut protéger, transporter, consommer ou détourner | Davantage de PV avec les mêmes attaques |
| Le butin fait évoluer le plan | Une acquisition peut changer le deck ou les priorités | Remplacer 12 dégâts par 17 dégâts |
| La profondeur reste lisible | Le joueur explique pourquoi il a choisi une action | Multiplier les compteurs et les exceptions |

Un test de conception particulièrement utile : **si l'on enlève les noms,
couleurs et bonus de dégâts, reconnaît-on encore la classe à ses décisions ?**
Ce n'est pas une mesure suffisante, mais c'est un bon filtre avant production.

## 5. Repenser la création sans tout faire choisir d'un coup

### 5.1 Trois décisions de gameplay, avec une information principale par écran

1. **Classe :** une promesse en un verbe, un mécanisme central, une situation
   démontrée. Exemples : détourner / ancrer / relier / convertir.
2. **Doctrine :** deux façons d'exploiter ce mécanisme, avec le bénéfice et le
   renoncement côte à côte. Le choix agit dès le premier combat.
3. **Techniques initiales :** cinq familles parmi sept, deux copies chacune,
   toujours choisies avant le départ. Un ensemble conseillé est précoché et
   entièrement modifiable ; l'interface explique les fonctions couvertes.

Apparence et difficulté restent séparées. La revue finale résume les décisions
sans introduire de nouveau système. Franchir le seuil ne redemande ni classe,
ni doctrine, ni deck. Pendant la run, chaque découverte ou évolution se traite
séparément, dans le contexte où elle devient pertinente.

### 5.2 Une signature fiable, qui ne remplace pas les cartes

Proposition à tester : une petite action de classe hors pioche, limitée à une
fois par activation, qui **installe** le mécanisme. Elle coûte des PA et ne
constitue pas une bonne source de dégâts répétable. Les cartes développent,
déplacent ou dépensent ce qu'elle prépare.

Exemples : poser un ancrage vide, déposer une balise, créer une ouverture,
tracer un résidu. Cela évite une classe désactivée par la pioche sans lui donner
gratuitement son meilleur combo. Il faudra la comparer à une alternative plus
légère : une carte de fondation assurée à l'ouverture, mais ensuite soumise
au cycle normal du deck. Ne pas cumuler les deux garanties par défaut.

Le départ conseillé contient de quoi préparer, exploiter et se repositionner,
ainsi qu'une réponse défensive et une option flexible. Ce sont des conseils,
pas cinq catégories obligatoires qui rendraient toutes les créations identiques.

### 5.3 Montrer un choix, pas seulement le décrire

Un aperçu rejouable de deux tours, sur une même petite grille, doit montrer
deux solutions avec la doctrine choisie. Afficher le résultat immédiat et la
ressource abandonnée : « je garde ce point protégé » / « je le consomme pour
passer ». L'aperçu n'a pas besoin de révéler une prochaine attaque ennemie.

Conserver les couleurs de classe existantes et ajouter symbole + intitulé.
La doctrine reçoit un motif ou un sous-titre ; la rareté garde un emplacement
distinct. Éviter que la même bordure signifie à la fois classe, rareté et état.

## 6. Quatre moteurs de classe proposés

Les noms ci-dessous sont des propositions de travail. Les limites chiffrées
cadrent l'expérimentation ; elles ne changent pas le produit existant.

### 6.1 Assassin — créer puis dépenser des ouvertures

**Promesse :** désorganiser un groupe pour choisir où porter l'effort.

Une Ouverture est un état consommable sur une cible, et pas simplement un
bonus permanent de dégâts. Sa création peut venir de la signature ou d'une
action qui sépare effectivement un ennemi d'un allié adjacent. Plafond initial
à tester : deux cibles ouvertes, pas d'accumulation sur la même cible. Un
déplacement sans changement de situation ne génère rien.

L'Ouverture permet soit de frapper, soit de rompre un lien de soutien, soit
d'échanger sa position avec une destination autorisée près de la cible.
Dépenser pour se sauver empêche d'utiliser la même ouverture pour exécuter.
La cible doit pouvoir retrouver une protection ; la ressource ne doit pas
rester gratuitement acquise pour tout le combat.

| Doctrine | Changement de règle | Renoncement |
|---|---|---|
| Duelliste | La consommation peut déplacer le héros vers une case libre adjacente à la cible | Une seule cible peut porter son Ouverture |
| Saboteur | Une Ouverture peut suspendre un lien de soutien jusqu'à la prochaine activation du héros | Pas de déplacement gratuit lié à sa consommation |

**Quatre cartes candidates :**

- **Découdre :** écarter une cible d'une case ; crée une Ouverture seulement si
  l'action rompt une adjacence avec son groupe. Utile aussi sans déclenchement.
- **Dérober l'appui :** consommer l'Ouverture pour extraire une quantité plafonnée
  de garde transférable. Ne vole pas un passif ni toute la réserve d'un boss.
- **Sortie oblique :** consommer l'Ouverture pour rejoindre une case libre
  adjacente à la cible, puis récupérer une carte de mobilité de la défausse
  en défaussant une autre carte. Aucun gain net gratuit de cartes ou de PA.
- **Dernière entaille :** convertir l'Ouverture en dégâts ; choix direct,
  concurrent du vol ou de la fuite, sans remboursement intégral en cas de mort.

**Ce qui change :** la meilleure cible n'est pas systématiquement celle qui
a le moins de PV. Elle peut être celle dont le soutien protège tout le groupe.
Un ennemi isolé dès le départ reste jouable grâce à la signature : pas de classe
en panne contre un boss seul.

### 6.2 Gardien — investir la protection dans l'espace

**Promesse :** décider où conserver sa sécurité et quand la transformer.

Un Ancrage occupe une dalle et peut recevoir une partie de la garde personnelle.
La quantité transférée est retirée au héros : aucune duplication. La réserve
protège une zone courte ou sert à déplacer une unité ; dépenser cette réserve
retire la protection correspondante. L'ancrage est visible et destructible,
avec durée et plafond. Il ne bloque pas gratuitement tous les passages.

| Doctrine | Changement de règle | Renoncement |
|---|---|---|
| Bastion | Maintient deux ancrages fixes entre lesquels répartir une réserve totale limitée | Doit consommer/recréer un ancrage pour changer son emplacement |
| Escorte | Transporte son unique ancrage lors de certains déplacements | Ne protège pas simultanément deux positions |

**Quatre cartes candidates :**

- **Mettre à l'abri :** transférer de la garde vers un ancrage ; une partie peut
  être reprise par le héros s'il y revient. La capacité totale reste conservée.
- **Bélier de réserve :** consommer un palier de réserve pour pousser ; le coût
  paie le contrôle même si une collision ne produit pas de dégâts.
- **Repli sous couvert :** rejoindre une case protégée accessible ; réduit
  l'exposition mais abandonne la position offensive et coûte des PA.
- **Démanteler :** détruire son ancrage pour récupérer une partie de la réserve
  ou une carte de protection défaussée, au choix. Jamais les deux gratuitement.

**Ce qui change :** défendre prépare des options actives. En solo, le Gardien
protège sa trajectoire et ses mécanismes ; il n'attend pas un équipier imaginaire
à tanker. Les ennemis peuvent contourner l'ancrage, déplacer le héros ou
consommer du temps pour détruire l'investissement.

### 6.3 Arpenteur — construire et sacrifier un réseau de positions

**Promesse :** donner une valeur différente aux mêmes cases.

Deux Balises au maximum définissent une liaison. Les cartes peuvent partir
d'une balise, exploiter une traversée ou en consommer une pour déplacer le héros.
La pose coûte une action ; les ennemis peuvent occuper ou détruire les balises.
Une liaison exige une géométrie explicite, interrompue par les murs. Elle ne
devient pas un tir universel sans ligne de vue.

| Doctrine | Changement de règle | Renoncement |
|---|---|---|
| Cartographe | Le réseau reste en place et relaie certaines cartes de contrôle | Le déplacement du héros ne transporte pas ses balises |
| Éclaireur | Consommer une balise permet une traversée personnelle vers une destination libre autorisée | Chaque traversée défait une partie du réseau |

**Quatre cartes candidates :**

- **Tir relayé :** tirer depuis une balise ; portée et ligne de vue sont
  calculées depuis celle-ci, pas additionnées sans limite à celles du héros.
- **Fil de traverse :** la prochaine traversée ennemie volontaire du lien
  déclenche une entrave, une fois, puis consomme le fil. La poussée ne provoque
  pas une infinité de déclenchements en aller-retour.
- **Décrocher :** consommer une balise pour se déplacer, en renonçant au relais
  qu'elle offrait pour l'attaque suivante.
- **Relever la piste :** déplacer une balise et échanger une carte de la main
  contre une carte de mobilité en défausse, avec coût et limite d'activation.

**Ce qui change :** choisir où finir son tour n'est plus seulement maximiser
la distance à l'ennemi. On arbitre entre accès, angles de tir, fuite et maintien
d'un investissement vulnérable.

### 6.4 Thaumaturge — convertir des effets plutôt qu'empiler des éléments

**Promesse :** changer l'usage d'un état déjà présent.

Deux types de résidus suffisent pour un premier prototype : braise et givre.
Ils peuvent être créés par les deux camps. Une carte peut exploiter, déplacer
ou consommer le résidu ; une conversion remplace son effet précédent.
Durée courte, nombre de dalles plafonné, aucune propagation automatique infinie.

| Doctrine | Changement de règle | Renoncement |
|---|---|---|
| Alchimiste | Consomme deux résidus compatibles pour un effet immédiat de contrôle | Détruit les zones qu'il aurait pu réutiliser |
| Ritualiste | Lie un résidu à une construction temporaire qui entretient un effet local | Immobilise cette ressource jusqu'à destruction ou dissolution |

**Quatre cartes candidates :**

- **Distillation :** retirer un résidu et conserver une charge, une seule à la
  fois. On nettoie un danger en renonçant à son effet de terrain.
- **Vapeur opaque :** consommer braise et givre proches pour créer une brume
  courte qui coupe les tirs des deux camps. Pas de bonus de dégâts automatique.
- **Transvaser :** déplacer un résidu existant vers une case valide ; permet
  aussi de retourner une préparation ennemie sans en devenir le propriétaire
  implicite pour tous les calculs de dégâts.
- **Effigie de suie :** immobiliser une charge dans une invocation temporaire
  de soutien ; une seule, non combattante au premier prototype, avec durée et
  dissolution explicites. Les règles d'admission doivent être réparées avant
  d'annoncer cette carte comme disponible.

**Ce qui change :** les effets adverses deviennent parfois des ressources.
La surface n'est plus seulement « cette case inflige des dégâts » ; sa
conservation, sa transformation et son emplacement se disputent.

## 7. Faire évoluer le deck sans casser l'identité

### 7.1 Une grammaire de cartes, plutôt qu'un quota de nouveautés

| Fonction | Exemple original | Place dans la progression |
|---|---|---|
| Fondation | Créer une petite réserve ou une ouverture | Disponible au départ sous une forme modeste |
| Exploitation | Dépenser la réserve pour repousser | Version simple au départ, alternatives en butin |
| Conversion | Transformer une défense en mobilité | Découverte qui ouvre une nouvelle direction |
| Récupération | Reprendre un outil en sacrifiant une carte | Permet un rythme différent, sous contraintes |
| Liaison entre classes | Une poussée exploite une balise | Rend un drop étranger pertinent |
| Transformation majeure | Transporter un ancrage avec une invocation | Rare/épique possible, pas clé obligatoire de viabilité |

Pour chaque nouvelle carte, écrire deux usages contextuels, deux partenaires
possibles et une raison de ne pas l'équiper. Si l'on n'y arrive pas, revoir la
carte avant de produire son illustration et ses effets visuels. Ne pas exiger
que toutes les cartes aient deux paragraphes de règles : un déplacement simple
peut acquérir ces usages grâce au terrain et aux autres cartes.

### 7.2 Respecter la demande sur les cartes de départ

Les attaques d'initiation doivent céder leur place à des acquisitions plus
efficaces ou plus polyvalentes. En revanche, garder une petite carte utilitaire
peut être un vrai choix si sa simplicité aide une nouvelle combinaison.
Supprimer mécaniquement toute utilité à chaque carte initiale transforme la
progression en remplacement obligatoire, sans réflexion.

Le critère visé est donc : **le deck de départ seul ne doit pas constituer la
meilleure réponse à toute la run ; le joueur doit pouvoir expliquer pourquoi
il conserve ou remplace ses outils.** La progression doit changer les
séquences et les priorités, pas seulement les valeurs affichées.

### 7.3 Les drops restent des drops

Conserver le reçu de victoire avec zéro, une ou plusieurs cartes selon les
tirages. La Résonance peut continuer à régler fréquence et rareté. Ne pas la
faire dépendre uniquement de la vitesse ou de dégâts infligés : cela risquerait
de pénaliser les stratégies de contrôle que nous voulons rendre intéressantes.

Tester un seul levier d'orientation à la fois : au refuge, choisir une fonction
recherchée, par exemple mobilité ou conversion. Cela peut pondérer un emplacement
de boutique ou une partie des futurs tirages, sans garantir une carte précise.
Afficher la portée de cette influence, et garder une part de découvertes libres.
Un recyclage limité de doublons peut fournir un deuxième filet ; ne pas activer
tous les filets avant de mesurer si le hasard a encore une place.

Une carte étrangère doit apporter son usage de base immédiatement. Une carte
qui exige une ressource de sa classe doit soit savoir la produire modestement,
soit être explicitement présentée comme une pièce à préparer. Éviter une
récompense annoncée comme utile mais totalement inerte dans le deck actuel.

### 7.4 Rareté, statistiques et progression

La rareté peut exprimer une transformation plus spécialisée ou un potentiel
supérieur sous certaines conditions ; elle ne doit pas rendre toutes les
usuelles inutiles. Évaluer chaque carte avec PA, portée, déplacement préalable,
fiabilité, délai, taille de main et coût d'opportunité.

Ne pas remplacer immédiatement la Prouesse par six nouveaux attributs. D'abord
faire fonctionner des mécaniques distinctes à statistiques normalisées. Les
stats pourront ensuite accentuer une préférence mesurable : réserve maximale,
durée contre intensité, coût contre portée. Si augmenter une statistique ne
change jamais un choix, sa place doit rester secondaire dans la création.

## 8. Les ennemis doivent rendre ces personnages nécessaires à penser

Il ne s'agit pas de fabriquer un ennemi immunisé à chaque classe. Un groupe
offre plusieurs points d'intervention et s'adapte quand un membre disparaît.
Le joueur lit des états présents : qui porte une ressource, qui entretient un
lien, quelle dalle nourrit quoi. Il n'a pas besoin de connaître l'action exacte
qui sera jouée au tour suivant.

| Groupe proposé | Coopération | Plusieurs réponses possibles |
|---|---|---|
| Phalange des créanciers | Deux porteurs alimentent une réserve de garde finie, partagée à courte distance | Séparer les porteurs, épuiser la réserve, voler une partie, contourner pour atteindre le bénéficiaire |
| Verriers du Léthé | Un poseur crée du givre, un convertisseur le consomme pour défendre le groupe, un pousseur exploite les zones restantes | Nettoyer, déplacer le convertisseur, retourner la surface, tuer le poseur ou forcer une dépense prématurée |
| Convoi des oboles | Un collecteur transporte une ressource qu'un autre ennemi consomme | Intercepter le trajet, déplacer la réserve, rompre le rayon de transfert, attaquer le consommateur |
| Chœur des cendres | Une mort laisse une essence ; un officiant peut la convertir en soutien temporaire | Occuper la dalle, consommer l'essence, déplacer l'officiant, changer l'ordre des éliminations |

Le convoi prolonge du contenu déjà présent ; les trois autres lignes décrivent
des rencontres à construire ou à compléter, pas des groupes validés en run.

**Charme :** commencer par détourner une seule action de soutien ou imposer
un déplacement légal borné. Une possession complète change équipe, ciblage,
victoire, inventaire et IA : elle exige un contrat plus lourd. Le texte doit
dire exactement l'effet obtenu.

**Passage de tour :** un verrou répété peut supprimer tout le gameplay ennemi.
Préférer dans un premier prototype l'interruption d'une fonction de groupe ou
la consommation d'une réserve ; si une stase totale demeure, limiter sa répétition
et fournir une réponse visible. Ne pas donner une immunité arbitraire à tous
les chefs pour masquer une boucle non maîtrisée.

### Une même rencontre, quatre raisonnements

Situation de test proposée : deux porteurs se protègent à courte distance,
un tireur utilise leur réserve, un pilier coupe un passage, un réservoir
contestable occupe une voie secondaire.

- L'Assassin sépare un porteur, ouvre une cible, puis choisit entre couper le
  soutien du tireur et utiliser l'ouverture pour traverser le groupe.
- Le Gardien réserve sa protection près du passage, puis décide de la conserver
  pour accéder au tireur ou de la dépenser pour expulser un porteur.
- L'Arpenteur installe un angle de tir depuis l'autre côté du pilier ; une
  fuite immédiate consommerait la balise qui rend ce tir possible.
- Le Thaumaturge déplace une surface pour couper un trajet, puis hésite entre
  conserver cette contrainte et la convertir en brume contre le tireur.

Ces plans ne sont pas des solutions prescrites. Changer la position du tireur
ou l'état de la réserve doit pouvoir changer le meilleur plan de chaque classe.
Si chaque classe répète sa rotation dans tous les cas, le prototype a échoué.

## 9. Ce que je ne recommande pas comme prochaine étape

- Un immense arbre de talents : trop de lecture avant d'avoir prouvé des choix
  réellement différents ; la quantité de nœuds ne mesure pas la profondeur.
- Une seconde classe obligatoire à la création : ferme trop tôt les découvertes.
- Une hausse générale des PV ennemis : allonge éventuellement les combats,
  sans créer de nouvelle décision.
- Un élément associé à chaque classe avec immunités croisées : produit des
  mauvais appariements davantage que des interactions.
- Un sort annoncé et une case à quitter comme structure principale de combat :
  ne répond pas au gameplay demandé.
- Une baisse isolée de la Frappe de secours : peut créer davantage de tours
  sans solution tant que les actions de classe sont peu accessibles.
- Un quota de cartes pour remplir le catalogue : chaque ajout doit avoir une
  fonction, un contexte et une compatibilité identifiables.
- Des rôles de groupe copiés tels quels : un protecteur solo doit agir sur
  les positions et investissements du joueur, pas attendre des partenaires.

## 10. Prototype recommandé et ordre de réalisation

### Étape A — Un Gardien complet, avant quatre refontes simultanées

Choisir le Gardien comme premier prototype : garde, déplacement, grille et
réserves ont déjà des bases ; cette classe permet de tester rapidement si
la défense devient une décision active. Il n'est pas nécessaire de construire
d'abord un nouveau système de surfaces ou une IA d'invocation complète.

Périmètre : deux doctrines, sept familles d'initiation retravaillées, cinq
familles d'acquisition qui convertissent ou déplacent la réserve, deux groupes
ennemis (phalange et convoi), trois topologies (ouverte, passage, voies
alternatives). Réutiliser le Studio pour les salles et le moteur de sorts
partagé. Les chiffres se règlent après l'observation des décisions.

Le prototype doit permettre : création → première rencontre sans drop →
acquisition dans le reçu → remplacement réel → rencontre où l'acquisition
change un plan. Une démonstration isolée d'un sort ne valide pas cette chaîne.

### Étape B — Hybridation limitée avec l'Arpenteur

Ajouter les balises et une interaction simple poussée/liaison. Tester une
carte étrangère dans chacun des deux decks. Si l'hybridation exige une longue
liste d'exceptions ou remplace toute l'identité, revoir le contrat partagé.

### Étape C — Assassin puis Thaumaturge

Introduire ouvertures et rupture de soutien sur les groupes déjà construits.
Puis seulement ajouter les conversions de résidus et l'invocation de soutien,
après validation de durée, propriété, admission et disparition des effets.
L'ordre réduit le nombre de systèmes nouveaux à diagnostiquer en même temps.

### Étape D — Progression et sélection définitives

Remplacer les spécialisations principalement numériques par les doctrines
validées. Le niveau 4 devient une évolution de la doctrine ou une transformation
de son outil, sans faire découvrir l'identité de base aussi tard. Mettre à jour
aperçus, descriptions, couleurs secondaires, sauvegardes et migrations explicites.
Conserver les anciennes révisions tant que leurs sauvegardes doivent être lues.

### Contrats techniques à définir avant contenu massif

- Séparer état individuel, réserve partagée et objet de terrain ; propriétaire,
  source, durée, plafond et règles de transfert doivent être explicites.
- Définir le sens de « déplacé », « ralenti », « protégé », « consommé » par
  propriétés communes, pas par une liste incomplète d'identifiants de sorts.
- Distinguer déplacement volontaire, poussée et téléportation pour les
  déclenchements. Résoudre les réactions dans un ordre déterministe.
- Interdire les boucles de production/consommation sans coût ; enregistrer
  un identifiant d'action source et limiter les réactions d'une même chaîne.
- Utiliser les mêmes règles pour simulation de l'IA, aperçu et exécution réelle.
  Une prévisualisation qui promet un déplacement refusé en combat est un échec.
- Tester la disparition d'une source, la mort simultanée, la destruction
  d'une dalle porteuse et la reprise de sauvegarde avec décisions en attente.

## 11. Comment prouver que le gameplay est devenu plus profond

### 11.1 Mesurer autre chose que victoire et nombre de sorts

| Question | Observation à recueillir |
|---|---|
| La doctrine change-t-elle la partie ? | Trajectoires, cibles, consommation de réserve et cartes équipées, à conditions comparables |
| Le joueur a-t-il plusieurs plans raisonnables ? | Deux options envisagées et raison du renoncement, relevées pendant les essais humains |
| La classe fonctionne-t-elle sans chance initiale ? | Premiers combats sans acquisition, mains défavorables, PA réellement disponibles |
| Les drops changent-ils la construction ? | Carte reçue → équipée ou refusée → usage réel → modification d'une séquence |
| Les ennemis coopèrent-ils vraiment ? | Différence quand le lien est rompu à PV et dégâts de base conservés |
| Le terrain change-t-il les choix ? | Même groupe sur plusieurs topologies, sans simplement ajouter du danger |
| Une stratégie écrase-t-elle toutes les autres ? | Variété des plans gagnants et coût d'exécution, pas seulement taux de sélection |
| Les règles sont-elles compréhensibles ? | Capacité à prédire un transfert, une conversion et la perte de protection |

### 11.2 Un protocole en trois niveaux

**Contrats moteur.** Tests ciblés sur conservation des réserves, limites,
réactions, cases invalides, mort de source, restauration et exécution IA.
Puis suites du moteur commun et contrôles CI requis. Une invocation qui ne
fonctionne que dans le laboratoire n'est pas acceptée.

**Comparaisons contrôlées.** Pour le premier prototype : deux doctrines ×
deux groupes × trois topologies × dix graines de main = 120 rencontres par
politique de pilotage. Comparer une politique simple et une politique qui
évalue les transferts ; ne pas utiliser uniquement le pilote glouton actuel.
Conserver positions, stats, tirages et résultats complets.

Faire ensuite des ablations : retirer le partage de réserve des ennemis,
retirer le mécanisme de classe, neutraliser un passage, en conservant autant
que possible les autres paramètres. Le but est de comprendre ce qui change
les décisions ; une baisse de victoire ne prouve pas à elle seule la profondeur.

**Essais humains exploratoires.** Six à huit personnes, dont débutants et
joueurs tactiques, jouent les deux doctrines dans un ordre alterné. C'est un
échantillon qualitatif, pas une estimation précise de la population. Relever
les hésitations, erreurs de compréhension, décisions expliquées et envies de
rejouer. Compléter par des runs entières pour observer drops et transformations.

### 11.3 Conditions de passage à la production

Avant de généraliser, demander au prototype de démontrer :

1. Une identité utilisable dès le premier combat, y compris sans drop.
2. Au moins deux plans différents pour une même doctrine selon le groupe ou
   le terrain ; pas seulement deux ordres de lancement équivalents.
3. Un renoncement perceptible entre les deux doctrines, sans gagnante universelle.
4. Plusieurs acquisitions capables de changer le plan, pas seulement les dégâts.
5. Une coopération ennemie que l'on peut affaiblir de plusieurs façons.
6. Aucun tour systématiquement réduit au secours à cause d'un mécanisme inaccessible.
7. Des joueurs capables d'expliquer les causes principales du résultat.

Ce sont des critères de décision à documenter, pas des résultats déjà obtenus.
Une baisse de l'usage des secours serait encourageante, mais viser arbitrairement
zéro serait une erreur : ils doivent conserver leur fonction de récupération.

## 12. Sources locales et traçabilité

- [Produit courant](../current/product.md) : parcours, choix et règles publiques.
- [Contenu courant](../current/content.md) : intégration des cinq salles tactiques.
- [Audit des cartes, 21 septembre](card_catalog_and_selection_audit_2026-09-21.md) :
  catalogue, stats, formules de drops et limites du pilote.
- [Export du catalogue](../../artifacts/dev/cards-catalog-20260921/report.json) :
  inventaire et tirages historiques ; ne constitue pas une nouvelle exécution.
- [Douze runs du 21 septembre](../../artifacts/dev/cards-distinct-starters-20260921/report.json) :
  résultats bruts, à distinguer des propositions de protocole ci-dessus.
- [Recherche sur les groupes, 20 septembre](card_systems_and_enemy_synergies_2026-09-20.md) :
  essais antérieurs, diagnostics d'intégration et pistes d'écosystèmes.
- [Passifs et spécialisations](../../core/expedition/class_card_modifier.gd),
  [progression Cartes](../../core/expedition/class_cards.gd),
  [effets de surfaces](../../core/expedition/card_ecosystem_effects.gd),
  [salles](../../core/expedition/card_tactical_room_catalog.gd),
  [réservoirs et sablier](../../core/expedition/card_tactical_resource_rules.gd) :
  code relu pour distinguer existant et propositions.

Les liens externes sont placés auprès de chaque observation dans la section 3.
Les pages officielles DOFUS n'ont pas fourni de texte exploitable lors de cette
recherche ; le devblog 2016 est donc cité via sa reproduction attribuée. Les
pages d'archives Supergiant et le fil d'annonces WAKFU peuvent évoluer : les
titres et dates sont indiqués pour retrouver les passages. Aucune recommandation
ne dépend d'une affirmation sur la méta actuelle de ces jeux.
