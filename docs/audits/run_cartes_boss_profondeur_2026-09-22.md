# Boss, bestiaires et profondeur systémique — run Cartes

Complément chiffré : [fiches techniques — statistiques, sorts, coûts, seuils et calculs tactiques](run_cartes_boss_fiches_techniques_2026-09-22.md). Il précise les valeurs finales de notre code et signale les divergences de versions des références.

Recherche du 22 septembre 2026. Périmètre : **run Cartes uniquement**, héros solo, tactique sur grille, deck de dix cartes, équipements, reliques et progression roguelike. Complète [l’audit du jeu existant](run_cartes_game_design_2026-09-22.md) et [la comparaison des combats et du deckbuilding](run_cartes_references_combat_deckbuilding_2026-09-22.md).

Les noms ont été confirmés : quatre Cavaliers de l’Éliocalypse, Protozorreur, Kabahal également pour « Cabal », Alice Alisceon dans Divinity: Original Sin 2. Otomaï désigne ici les cinq donjons de l’île. Les propositions sont des concepts à tester, pas du contenu implémenté.

## 1. Méthode et conclusion de conception

Pour chaque rencontre : identifier la règle, son déclencheur, l’importance de la salle et des autres monstres, puis expliquer pourquoi les méthodes de victoire fonctionnent. Les paragraphes « Transposition » sont notre analyse originale. Les guides communautaires documentent les comportements et stratégies ; ils ne constituent pas une mesure indépendante de l’équilibrage. Les témoignages de joueurs sont signalés comme tels. Aucun de ces combats n’a été rejoué pour cette recherche.

Les versions comptent : Dofus PC ne se confond pas avec Retro, Touch ou les anciennes Expéditions ; les variantes de difficulté de BG3 sont précisées. Certains guides conservent des passages historiques. Les chiffres douteux ont été écartés et les divergences pertinentes sont indiquées.

**Notre ambition peut dépasser largement quelques boss à vulnérabilité et quelques cartes à combo.** Elle demande trois développements conjoints : des ennemis qui changent les décisions, des personnages capables de détourner leurs règles, et des récompenses qui transforment durablement cette capacité. Les premiers prototypes proposés dans les audits précédents sont des expériences de validation, pas un plafond de contenu.

La richesse recherchée apparaît lorsque le joueur peut raisonner : « Je pourrais interrompre cette attaque, mais la laisser partir détruirait le soutien adverse ; je garde donc ma poussée et je modifie son axe. » Ajouter séparément un sort de poussée, un monstre soutien et une attaque de zone ne garantit pas cette interaction.

## 2. Dofus : les règles deviennent des outils

### Meulou — contrôler les conséquences de ses attaques

**Règles et stratégies documentées.** Fureur augmente la puissance de la cible touchée dans le groupe du boss. Le Meulou exerce une forte pression de mêlée ; ses éliminations peuvent alimenter le combat en Mulous. Les attaques répétées qui blessent sans éliminer renforcent ainsi le camp adverse. Les joueurs privilégient concentration des dégâts, maîtrise de la distance et prudence avec les invocations offertes au boss. Attention au guide mélangeant plusieurs états du combat : le récapitulatif 3.6 remplace l’ancienne invulnérabilité sur la première attaque par une réduction de 50 %, et réduit la durée de Fureur. [Tanière](https://www.dofuspourlesnoobs.com/taniere-du-meulou.html), [changements 3.6](https://www.dofuspourlesnoobs.com/mise-a-jour-306.html).

**Transposition.** Excellent modèle de premier boss : peu de règles, mais le joueur choisit entre préparer un gros impact et multiplier les petits coups. Notre assortiment doit aussi lui permettre de dépenser utilement son tour autrement. Une punition du multi-coup devient pauvre si toute une classe n’a que du multi-coup ; elle devient intéressante si ce joueur peut orienter la riposte, disperser les cibles ou convertir son nombre de touches en une autre ressource.

### Corailleur Magistral — une fenêtre de puissance avec un coût spatial

**Référence historique.** Le guide décrit une montée de puissance accompagnée d’une perte de mobilité et une menace mortelle au contact. La réponse consiste à exploiter cette immobilisation, puis à anticiper le retour de sa capacité d’approche. Il faut donc lire ensemble dégâts, portée et durée du handicap. Ce guide ancien sert de référence de conception, sans certifier les valeurs actuelles. [Grotte Hesque](https://www.tofus.fr/donjons/hesque).

**Transposition.** Un champion peut se rendre beaucoup plus dangereux tout en donnant une ouverture. Pour notre solo à trois PM, afficher la portée après sa prochaine récupération de mobilité est essentiel : la case sûre maintenant peut devenir un piège au tour suivant. Une posture adverse peut aussi constituer un signal pour conserver une carte de déplacement.

### Gourlo — préserver un objet ennemi pour s’en servir

**Règles et stratégie.** Les tonneaux participent à l’affaiblissement élémentaire du boss lorsqu’ils sont exploités à son contact. Le placement permet de maintenir Gourlo et un tonneau dans une configuration favorable ; bloquer avec le terrain ou une entité facilite ce maintien. Détruire systématiquement les invocations peut supprimer l’outil nécessaire. Les détails des tonneaux varient dans les guides historiques, donc pas de protocole chiffré universel retenu ici. [Arche d’Otomaï](https://www.dofuspourlesnoobs.com/arche-dotomaiuml.html), [guide JeuxOnline](https://dofus.jeuxonline.info/article/9858/arche-otomai).

**Transposition.** Nos invocations et objets de salle devraient parfois avoir deux valeurs : danger immédiat et ressource exploitable. Une carte qui déplace une entité gagnerait alors une fonction supplémentaire sans nouvelle ligne de texte. Il faut rendre explicite qu’un objet adverse est manipulable et que le tuer fait perdre une opportunité.

### Silf le Rasboul Majeur — fabriquer une vulnérabilité

**Règles et stratégie.** Le retrait de PA provoque ici un gain de PA du boss ; atteindre le seuil requis permet Hololole. Les touches dans un élément construisent ensuite sa faiblesse dans cet élément en renforçant les autres résistances. L’ordre optimal devient préparation par petites frappes puis attaque lourde. Les petits Rasbouls apportent du soin : leur distance au boss compte, ainsi que les échanges de position. [Guide Silf](https://www.millenium.org/guide/420377.html), [fiche de sorts](https://doflex.fr/fr/encyclopedia/monsters/615-silf-le-rasboul-majeur?grade=3&spell=838).

**Transposition.** Un effet habituellement défavorable peut devenir un investissement. Dans notre jeu, exposer temporairement un ennemi, nourrir sa charge ou lui donner une surface pourrait construire un rendement futur. La prévisualisation doit montrer ce rendement : sans elle, le joueur apprend une exception opaque au lieu de prendre une décision.

### Tynrils — raisonner sur les positions futures

**Règles et stratégie.** Les quatre Tynrils ont des vulnérabilités élémentaires distinctes, échangent leurs places et peuvent se soutenir au contact. Leur menace mêle affaiblissement et danger de proximité. Les joueurs concentrent leurs attaques, limitent les soins et prévoient les échanges : la menace n’est pas uniquement le monstre actuellement le plus proche. [Laboratoire](https://dofus.jeuxonline.info/article/13866/laboratoire-tynril).

**Transposition.** Nous avons déjà du déplacement forcé ; des ennemis pouvant échanger leurs fonctions ou leurs places ajouteraient une lecture relationnelle. En revanche, exiger quatre éléments est incompatible avec un deck solo spécialisé sans outils fournis par la salle. Une alternative serait quatre comportements défensifs, chacun contournable par plusieurs verbes : détourner, isoler, interrompre, déplacer.

### Kimbo — déplacer l’origine d’une règle spatiale

**Règles et stratégie.** Les éléments utilisés déterminent le mode pair ou impair du glyphe du Disciple. Les cases dangereuses pour les joueurs et le placement qui expose le Kimbo dépendent de cette géométrie. On prépare les positions avant le déclenchement et on évite de changer involontairement de famille élémentaire. Déplacer l’origine du motif transforme toute la lecture du terrain. [Canopée du Kimbo](https://www.dofuspourlesnoobs.com/canopeacutee-du-kimbo.html).

**Transposition.** Très bon candidat pour un boss de fin de chapitre : le terrain devient une règle mobile. Notre carte de déplacement pourrait modifier l’ensemble du problème, plutôt que simplement gagner une case. Il faut un aperçu des cases après déplacement, des symboles au-delà des couleurs, et une première démonstration dont l’erreur reste récupérable.

### Moon — le ciblage modifie le plateau

**Règles et stratégie.** Les totems élémentaires et leurs glyphes permettent d’affaiblir Moon. Dans la version décrite, une attaque de l’élément approprié, en ligne, attire le totem vers l’attaquant ; la poussée habituelle ne remplit pas ce rôle. Atteindre la correspondance totem/glyphe permet d’exploiter la faiblesse associée. Frapper Darkli Moon a aussi des conséquences de déplacement et de renforcement. Le guide juxtapose combat de base et Expédition : il ne faut pas importer indistinctement les anciennes exigences portant sur les quatre totems. [Arbre de Moon](https://www.dofuspourlesnoobs.com/arbre-de-moon.html).

**Transposition.** Donner plusieurs usages à une attaque enrichit le deck sans grossir la main : dommage, commande d’objet, modification du trajet. Pour éviter un verrou élémentaire arbitraire, les dispositifs de notre salle pourraient convertir n’importe quelle frappe en activation, avec un bonus si l’affinité correspond.

### Kralamoure Géant — synchroniser un rituel et une fenêtre offensive

**Règles et stratégie.** Les attaques élémentaires provoquent l’apparition des tentacules correspondants. Le rituel exige ensuite de leur faire effectuer des actions sur des appâts ; la Primaire, particulièrement dangereuse, intervient dans la dévoration. L’ordre d’invocation, le placement des tentacules et la survie des appâts préparent une courte vulnérabilité. Le guide propose de faire apparaître la Primaire tardivement et de l’utiliser également comme écran devant le boss. Les joueurs préparent leurs dégâts avant l’ouverture ; sinon il faut survivre à la reprise. [Antre du Kralamoure](https://www.dofuspourlesnoobs.com/antre-du-kralamoure-geacuteant.html).

**Transposition.** La chaîne préparation → synchronisation → dépense est compatible avec conservation de carte et défausse. La copie littérale l’est beaucoup moins : Achille ne peut pas occuper simultanément les postes d’une équipe. Une salle solo devrait fournir des leurres persistants ou des mécanismes retardés ; le joueur organiserait plusieurs futurs événements avec ses actions successives.

### Koutoulou — chaque attaque est aussi un déplacement

**Règles et stratégies.** Les dégâts directs déclenchent des échanges avec l’entité admissible la plus proche ; leur répétition peut produire invulnérabilité et Folie. La Folie augmente aussi par d’autres événements, dont certaines expositions au boss, et ses seuils deviennent très dangereux. Les poisons permettent d’éviter la logique des frappes directes. Klûtiste, clones et doubles ajoutent leurs propres contraintes : tuer le soutien prioritaire, exploiter les obstacles et maîtriser les échanges simplifie le combat. Les invocations peuvent servir d’écran, mais ne sont pas toutes admissibles aux mêmes échanges. [Temple de Koutoulou](https://www.dofuspourlesnoobs.com/temple-de-koutoulou.html).

**Transposition.** Notre moteur doit distinguer dégâts directs, périodiques, collision et réaction. Ensuite, un boss peut transformer une distinction déjà connue en problème nouveau. Un aperçu doit annoncer la destination après la frappe et les déclenchements successifs d’un multi-coup. Il faut préserver l’intérêt du poison sans en faire l’unique construction permettant de jouer.

### Protozorreur — superposer des contrats et une pression collective

**Référence documentée, guide historique 2019.** La Malamibe reçoit les dégâts redirigés et doit être éliminée dans son délai, pendant que les joueurs maintiennent des conditions pour les autres monstres. Ces conditions diffèrent : distances, contact, éléments ou interdictions d’actions. Plusieurs doivent être respectées cinq tours consécutifs ; le Protozorreur demande une préparation plus longue autour de son glyphe. Le premier attaquant et son alignement peuvent déterminer l’attraction du boss. Réussir suppose de distribuer les rôles, ordonner les attaques et éviter la remise à zéro d’un compteur tout en alimentant les dégâts collectifs. [Ventre de la Baleine](https://dofus.jeuxonline.info/article/14644/ventre-baleine).

**Transposition.** Très riche pour une équipe ; trop de contrats simultanés risquent de supprimer toute latitude en solo. Retenir les contrats qui se combinent avec le build et la salle, puis autoriser à choisir lequel résoudre en premier. Éviter dix tours identiques après compréhension : un maintien réussi devrait accélérer ou transformer le combat. Afficher la condition, son compteur et la cause exacte de rupture.

### Kabahal — commander les armes du boss

**Règles et stratégies.** Kabahal reste invulnérable : les Bras démoniaques infligent les dégâts utiles. Des runes annoncent leurs apparitions ; un personnage peut bloquer une apparition et prendre le contrôle des Bras. Les Bras produisent dégâts et déplacements, permettant des chaînes dépendant de l’ordre des actions. Les laisser remplir tous leurs emplacements mène à une attaque fatale ; les renforts ajoutent une autre échéance. L’Instabilité modifie les résistances à chaque frappe, même sans dégâts sur l’invulnérabilité : préparer la résistance pertinente augmente le rendement des Bras. Les joueurs organisent leur rotation, maintiennent des emplacements disponibles et éliminent les soutiens les plus gênants. [Rituel de Kabahal](https://www.dofuspourlesnoobs.com/rituel-de-kabahal.html).

**Transposition.** Référence majeure pour notre hybride : acquérir temporairement une action de salle pourrait se faire via une carte spéciale conservable ou une commande hors pioche. Le deck améliore l’exploitation du mécanisme, tandis que son accès demeure garanti. On obtient une économie complète : action pour contrôler, position pour viser, espace à préserver, cadence à accélérer et risque à accepter.

### Servitude — payer le droit d’attaquer, contenir une population

**Règles et stratégies.** Ses renvois de dégâts directs se contournent avec les charges Traître obtenues par les glyphes ; les lignes de dégâts consomment ces charges. Les poisons suivent une autre logique. Les Armécréantes produisent des Iopprimés lorsqu’elles ne subissent pas les dégâts directs requis, ce qui oblige à arbitrer entretien et élimination. Domestication ramène une cible à sa position de départ : on peut utiliser ce retour pour une sortie offensive. À très basse vie, Servitude revient aux positions initiales et se soigne ; l’Insoignable permet de contrer le soin. [Fers de la Tyrannie](https://www.dofuspourlesnoobs.com/fers-de-la-tyrannie.html). La 3.6 modifie notamment les invocations et rend Domestication dissipable ; les anciens chiffres ne sont pas repris ici.

**Transposition.** Un excellent modèle d’économie de charges, avec des usages offensifs et défensifs du même statut. Notre jeu gagnerait à permettre de détourner un retour forcé, au lieu de toujours le présenter comme un malus. Le cas du soin terminal souligne aussi une décision à formaliser pour Paris : transition obligatoire, contournable par surdégâts, ou neutralisable par un contre explicite ?

### Guerre — choisir quand franchir un seuil

**Règles et stratégies.** Guerre n’est vulnérable qu’après les autres ennemis. Sa Bravoure structure les cibles et les occasions d’attaque. Les seuils de 20 % font apparaître des armes aux motifs distincts ; les dégâts sont arrêtés au seuil. Éliminer l’arme avant l’action de Guerre évite ses bénéfices ultérieurs. Autre approche : éloigner l’arme et exploiter le calendrier de Bravoure. Les joueurs préparent le franchissement avec leurs ressources disponibles, au lieu de simplement infliger le maximum immédiatement. [Trône de Sang](https://www.dofuspourlesnoobs.com/trone-de-sang.html).

**Transposition.** La barre de vie devient un outil de planification. Avec quatre cartes en main, le joueur doit connaître le prochain seuil avant de dépenser sa dernière réponse. Un indicateur de phase et une carte conservée peuvent porter cette préparation. Réserver les plafonds de dégâts à des boss dont la règle les explique : les généraliser détruirait la valeur des builds à forte attaque unique.

### Misère — supprimer la source d’un renforcement

**Règles et stratégies.** Les monstres volent des caractéristiques ; Misère peut en récupérer une partie depuis ceux qu’elle voit. La disparition du monstre source retire sa contribution. Misère attire les entités à son début de tour et lorsqu’elle subit des dégâts ; sa vie restante influe sur la force de l’attraction. Son passage à mi-vie change la situation et inclut une période d’invulnérabilité. Les choix portent donc sur la coupure de ligne de vue, les cibles qui alimentent le boss et le nombre de frappes qui déclenchent les déplacements. [Sentence de la Balance](https://www.dofuspourlesnoobs.com/sentence-de-la-balance.html).

**Transposition.** Nos collecteurs et protecteurs offrent déjà une base relationnelle. Leur ajouter une origine visible aux bénéfices permettrait de choisir entre tuer le relais, rompre le lien ou exploiter son effet. La suppression d’une source doit être immédiate et lisible, faute de quoi l’ordre des cibles ressemble à une règle cachée.

### Corruption — soigner pour attaquer, conserver un malus utile

**Règles et stratégies.** Kissiphrot Sipique punit les lignes de dégâts ; soigner une entité au contact de l’ennemi permet de retirer cet état. La Peau Pourrissante a un coût mais protège contre les maladies : les joueurs peuvent la conserver sur un tank et la retirer sur leurs attaquants. Les maladies demandent plusieurs soins. Les soutiens, dont le Pistilangue, compliquent les interactions ; les contrôler ou les éliminer rend l’ouverture exploitable. Le guide recommande de distinguer les besoins des personnages plutôt que de nettoyer tous les états immédiatement. [Arbre de Mort](https://www.dofuspourlesnoobs.com/arbre-de-mort.html).

**Transposition.** Une carte de soin peut devenir une clé offensive ; un statut négatif peut être une ressource consentie. Pour notre héros unique, il faut remplacer la répartition tank/attaquant par des postures ou des fenêtres : je conserve la corruption pendant ma préparation, puis je la purge pour ma dépense. Le choix doit rester possible sans posséder une carte de soin particulière.

### Les quatre Cavaliers ensemble — l’ordre d’élimination modifie le problème

**Règles et stratégies.** La Tempête réunit leurs mécaniques avec le Feu Primordial, soutien central qui renforce le groupe et frappe dans sa ligne de vue. La survie de son invocateur conditionne celle du combat. Le guide préconise Corruption, puis Servitude, Misère et enfin Guerre, avec variantes. Tuer Corruption allège les maladies ; retarder le seuil de Misère limite sa dangerosité. Les attaques automatiques du Feu sur Misère peuvent déclencher ses attractions : même l’allié demande une anticipation. Les Armécréantes ajoutent la pression de population et des retours de position exploitables. [Tempête de l’Éliocalypse](https://www.dofuspourlesnoobs.com/tempete-de-l-eliocalypse.html).

**Transposition.** Un boss multiple doit faire varier les règles restantes selon l’ordre choisi. Dans notre solo, commencer par deux autorités aux interactions fortes avant d’envisager quatre. Une assistance de salle peut compenser le nombre d’adversaires tout en introduisant une responsabilité nouvelle. Le soutien automatique doit afficher ses cibles et les réactions qu’il provoquera.

**Autre rencontre, à ne pas confondre.** La quête solo « Entretemps, une renaissance » prête des pouvoirs liés à une relique. Les Cavaliers sont neutralisés par affaiblissement, actions spécifiques et placement, avec Guerre traitée après les autres. Ce n’est pas le fonctionnement du donjon collectif. Son intérêt est précisément de montrer un combat complexe rendu possible par un ensemble temporaire d’outils adaptés. [Quête solo](https://www.dofuspourlesnoobs.com/entretemps-une-renaissance.html).

### Songes — composer des rencontres, puis contrôler leurs incompatibilités

**Versions et principes.** Les descriptions de la finale en trois vagues ne doivent pas être réutilisées comme règle courante : le récapitulatif 3.5 décrit des vagues générées, sans chevauchement, avec nettoyage des mécaniques précédentes et une limite globale de tours. La sélection et les cotes de boss sont aussi révisées. Cela documente un besoin de curation, pas la validité de tous les mélanges possibles. [Révision 3.5](https://www.dofuspourlesnoobs.com/mise-a-jour-305.html), [guide général à lire selon sa version](https://www.dofuspourlesnoobs.com/songes-infinis.html).

**Transposition.** Pour notre roguelike, définir des contraintes de composition : visibilité nécessaire, nombre de cases libres, disponibilité d’un objet requis, budget d’actions, compatibilité des états. Un modificateur qui bloque le mouvement ne doit pas être tiré aveuglément avec une attaque imposant d’atteindre une case lointaine. Les variantes devraient changer les priorités et trajets, pas seulement multiplier les PV. La connaissance d’une famille doit rester utile même quand la rencontre change.

## 3. Baldur’s Gate 3 : transformer le terrain et l’économie d’actions

### Grym — manipuler une règle de poursuite

**Règles et stratégies.** La lave rend Grym vulnérable ; sa poursuite privilégie la dernière créature qui l’a touché. On peut donc déterminer son trajet puis utiliser le marteau de forge. Le marteau retire la surchauffe, ce qui impose de renouveler la préparation. Une autre stratégie emploie directement les dégâts contondants lorsque la chaleur le permet. En Honneur, la réverbération ajoute des PV temporaires et de la mobilité ; leur destruction déclenche une onde. Les positions inaccessibles offrent aussi des stratégies à distance qui neutralisent fortement le risque. [Grym](https://bg3.wiki/wiki/Grym).

**Transposition.** Une IA prévisible peut être plus intéressante qu’une IA qui poursuit toujours la meilleure cible. Le joueur transforme sa connaissance en commande indirecte. En solo, « dernier attaquant » ne suffit pas : il faut une balise, un objet attaquable ou une case ciblée que le boss poursuit. La règle doit annoncer si le déplacement change sa destination ou uniquement le chemin qui y mène.

### Raphaël — choisir comment couper l’alimentation du boss

**Règles et stratégies.** Les quatre piliers renforcent Raphaël et lui procurent des âmes à dépenser. Les détruire supprime ces ressources, mais leur destruction déclenche aussi sa transformation ; ce n’est donc pas une réduction linéaire de difficulté. Les dégâts radiants peuvent interrompre temporairement l’apport d’un pilier. Le joueur répartit son effort entre piliers, serviteurs et contrôle du boss. Les contrôles sur Raphaël sont limités en durée : leur renouvellement coûte des actions. La concentration des destructions dans une même fenêtre et la préparation des protections permettent de mieux maîtriser la transition. [Combat de Raphaël](https://bg3.wiki/wiki/Raphael/Combat).

**Transposition.** Un soutien destructible devrait parfois donner le choix entre l’éteindre, le détruire et le détourner. Trois verbes peuvent produire trois constructions viables : contrôle économe, destruction rapide, appropriation technique. Éviter que tous nos boss aient seulement « trois cristaux à tuer ». Le comportement modifié après leur disparition doit donner du sens à l’ordre choisi.

### Ansur — gérer un compte à rebours et des abris consommables

**Règles et stratégies.** Ansur charge sa nova ; les cristaux servent de protection puis sont détruits, ce qui modifie les réponses disponibles pour la suite. Des protections magiques ou un mur peuvent fournir une alternative. Les myrmidons et l’eau ajoutent un risque électrique. Le guide signale que le délai réel de la charge ne correspond pas à certaines indications d’interface. En Honneur, atteindre zéro PV déclenche une dernière survie avec PV temporaires et nouvelle nova. La riposte draconique existe aussi en Tacticien : ne pas assimiler toute action dite légendaire au seul mode Honneur. [Combat d’Ansur](https://bg3.wiki/wiki/Ansur/Combat).

**Transposition.** Un abri peut être une ressource de combat, au même titre que la garde. Se cacher maintenant, le préserver en interrompant l’attaque, ou déplacer la menace pour conserver une route : voilà plusieurs usages de nos cartes. Si un boss revient à la vie, ce retour doit être annoncé dans sa fiche et le calcul des dégâts ; sinon le joueur dépense sa main sur une fausse fin de combat.

### Apôtre de Myrkul — couper une chaîne de ravitaillement

**Règles documentées.** Myrkul est immobile et empêche les soins à proximité. Il consomme les nécromites pour obtenir Finger of Death et, à partir de Tacticien, se soigner. Attraction et balayage rendent la position autour de sa plateforme importante. En Honneur, le premier attaquant provoque aussi un regard réactif. [Apôtre de Myrkul](https://bg3.wiki/wiki/Apostle_of_Myrkul).

**Lecture stratégique.** À partir de ces règles, les réponses consistent à intercepter les ressources avant consommation, ménager une sortie de la zone anti-soin et choisir qui absorbe la réaction avant l’offensive principale. C’est une analyse des règles, pas un résultat de test personnel. Les dégâts immédiats sur le boss et les dégâts empêchés en supprimant un nécromite n’ont pas la même temporalité.

**Transposition.** Nos collecteurs et porteurs sont le rapprochement le plus direct. Il faudrait montrer la destination de la livraison, son délai et le bénéfice évité. Un porteur peut devenir un objectif qu’on tue, ralentit, détourne ou vole ; ces options donnent une valeur tactique à des cartes aujourd’hui évaluées surtout sur leurs coefficients.

### Matriarche araignée — attaquer le support plutôt que la cible

**Règles et stratégies.** Les œufs permettent de nouveaux ennemis ; les détruire avant le combat réduit cette pression. Brûler un pont de toile sous la Matriarche provoque une chute : le décor devient une attaque. La dispersion et la résistance au poison réduisent ses dégâts. En Honneur, tuer une petite araignée peut déclencher Gossamer Tomb ; le feu ou l’acide permettent de libérer la victime. La méthode consistant à pousser la Matriarche dans le gouffre ne s’applique pas de la même manière en Tacticien/Honneur, où elle revient par téléportation. [Matriarche](https://bg3.wiki/wiki/Phase_Spider_Matriarch).

**Transposition.** Les surfaces actuelles peuvent devenir des supports : passerelle fragile, couverture inflammable, sol conducteur. Détruire le support peut endommager, isoler ou déplacer sans ajouter un nouveau sort spécialisé. Pour notre grille, il faut préciser ce qui arrive aux unités, drops et objets après transformation du sol. Une préparation avant combat mérite aussi un coût ou un choix, sinon elle devient une formalité toujours optimale.

### Netherbrain — gagner autrement qu’en vidant la salle

**Règles et stratégies.** La première partie demande d’atteindre la Couronne et de protéger la canalisation, pas de tuer tous les ennemis. Les arcanistes peuvent interrompre ce projet. La mobilité, le regroupement près du portail et la neutralisation des perturbateurs sont décisifs. À l’intérieur, les orbes annoncent la destruction de plateformes ; il faut conserver des sorties tout en infligeant les dégâts nécessaires. En Honneur, l’immunité aux types de dégâts du tour précédent oblige à organiser leur alternance. [Combat du Netherbrain](https://bg3.wiki/wiki/The_Netherbrain/Combat).

**Transposition.** Une salle de notre run pourrait demander d’ouvrir un passage, d’extraire une relique ou d’interrompre un rituel. La mobilité et la défense auraient alors une contribution directe à la victoire. Une immunité élémentaire intégrale serait toutefois très punitive pour notre deck de dix cartes : mieux vaut une résistance adaptative, un mécanisme de conversion accessible ou une récompense à l’alternance.

### Dragon rouge dominé — une grande menace peut être secondaire

**Règles documentées.** Le dragon occupe la bataille extérieure du Netherbrain. Il combine souffle, vol, peur et attaques de proximité ; en Tacticien, sa riposte peut employer le souffle une fois par round. Son atterrissage peut éliminer des tentacules. Sa présence s’inscrit dans l’objectif de canalisation décrit ci-dessus. [Dragon rouge dominé](https://bg3.wiki/wiki/Dominated_Red_Dragon).

**Lecture stratégique et transposition.** Le joueur peut décider de consacrer ses ressources à sa destruction ou de supporter sa menace pendant qu’il accomplit l’objectif. Cela donne un modèle de champion qui domine l’espace sans devenir obligatoirement la cible principale. Pour notre run, éliminer un tel champion pourrait procurer une récompense supplémentaire ; l’interface devrait annoncer explicitement que sa mort est facultative.

## 4. Divinity: Original Sin 2 : préparer, neutraliser, retourner les systèmes

Les exemples suivants appartiennent à DOS2 ; ils ne décrivent pas le Braccus Rex du premier Original Sin. Les guides et témoignages divergent parfois sur les délais exacts selon version et situation : aucun compteur incertain n’est présenté comme garanti.

### Le Docteur / Adramahlihk — la préparation change le combat

**Règles documentées.** L’affaiblissement obtenu via les bougies intervient avant le combat et implique un coût narratif majeur. La présence de Lohse introduit un risque de possession ; les serviteurs et l’importante défense du Docteur compliquent sa neutralisation. [Crippling a Demon](https://divinity.fandom.com/wiki/Crippling_a_Demon), [Sur ordre du Docteur](https://www.jeuxvideo.com/wikis-soluce-astuces/722312/sur-ordre-du-docteur.htm).

**Méthodes de joueurs.** Des témoignages décrivent l’usage de la porte comme goulet, la séparation des adversaires et le contrôle du Docteur après réduction de son armure. D’autres méthodes reposent sur le fonctionnement des dialogues ou de l’entrée en combat ; elles montrent des limites du système, pas seulement des solutions tactiques. [Discussion de joueurs](https://www.reddit.com/r/DivinityOriginalSin/comments/1n22xc4/).

**Transposition.** Un événement de run peut modifier un boss à venir en échange d’un prix concret : sacrifier une récompense, accepter un défaut de relique, renforcer un autre étage. Notre préparation à la profondeur 19 est un point naturel pour rendre un tel arbitrage visible. Il faut annoncer l’effet avant le choix pour permettre une décision de build.

### Alice Alisceon — employer une règle dans un sens inhabituel

**Règles et stratégies documentées.** Alice est une morte-vivante ; sa Pain Aura peut être retirée avec Bless. Les joueurs recommandent de disperser le groupe avant l’ouverture, de préparer la résistance au feu et de supprimer son armure pour permettre le contrôle. Certains exploitent aussi les interactions de soin contre les morts-vivants. Attention : les discussions emploient parfois « aura » et « renvoi » de manière imprécise ; cette étude ne les assimile pas. [Fiche Alice](https://divinity.fandom.com/wiki/Alice_Alisceon), [témoignage sur placement et contrôle](https://forums.larian.com/ubbthreads.php?Number=633114&ubb=showthreaded), [discussion sur les interactions de soin](https://www.reddit.com/r/DivinityOriginalSin/comments/15bdw1v).

**Transposition.** L’intérêt est de rendre les propriétés des créatures opérationnelles : soigner un mort-vivant, brûler une toile, purifier une corruption. Une carte utilitaire acquiert plusieurs usages cohérents. Chez nous, un mot-clé doit donc correspondre à un comportement commun reconnu par toutes les cartes concernées ; les identifiants de statuts divergents constituent précisément un obstacle à cette promesse.

### Le Dévoreur — les choix de quête configurent l’affrontement

**Règles et stratégies documentées.** La quête d’armure prépare le combat : visions, esprits et choix précédents influencent les contraintes et les soutiens. Le guide consulté recommande de gérer les esprits avant l’affrontement et décrit une immunité temporaire après certains contrôles forts. Il propose d’exploiter une armure magique plus accessible et de traiter les manifestations avec les outils adaptés. La priorité n’est donc pas seulement « contrôler le dragon » : il faut choisir quel contrôle utiliser et quand. [Guide, section A Hunger From Beyond](https://gamefaqs.gamespot.com/ps4/236378-divinity-original-sin-ii-definitive-edition/faqs/81674/chapter-6-the-hunt-for-dallis).

**Transposition.** Une collection d’équipement peut déboucher sur une rencontre et modifier ses règles. Pour notre roguelike, des fragments de relique pourraient offrir une puissance progressive tout en annonçant leur créancier final. La protection temporaire après contrôle est préférable à une immunité générale lorsqu’elle laisse des alternatives : déplacement, interruption partielle ou exploitation d’une autre fenêtre.

### Braccus Rex — exploiter une bataille entre factions

**Règles et stratégies documentées.** Les choix précédant l’affrontement changent la première partie. Le combat final peut opposer plusieurs camps ; la phase de Braccus fait intervenir le Kraken et d’autres ennemis connus. Les déplacements entre plateformes compliquent l’accès aux cibles. Éliminer Braccus fait disparaître les forces qui dépendent de lui : tuer chaque apparition n’est pas nécessaire. [End Times](https://divinity.fandom.com/wiki/End_Times). Des joueurs utilisent les combats entre factions pour concentrer leur mobilité et leurs dégâts sur la cible décisive. [Témoignages](https://steamcommunity.com/app/435150/discussions/0/1488866813753887914/).

**Transposition.** Un troisième camp, une créature libérée ou un ancien champion recruté peut modifier le combat final de notre run. Les unités doivent cependant avoir des règles de ciblage compréhensibles. Une bataille spectaculaire perd son intérêt tactique si le résultat dépend d’arbitrages d’IA invisibles. Le joueur devrait pouvoir infléchir cette hostilité par ses cartes ou le terrain.

## 5. Ce que les méthodes de victoire révèlent

Cette classification est notre synthèse des cas précédents. Les exemples servent à identifier des familles de décisions, pas à affirmer qu’une seule méthode domine chaque combat.

| Méthode | Décision réelle | Application à notre hybride |
|---|---|---|
| Préparer une fenêtre | Dépenser maintenant ou conserver une ressource | Main retenue, charges de relique, garde, effets différés |
| Couper une alimentation | Attaquer le boss ou supprimer son rendement futur | Porteurs, protecteurs, liens, objets destructibles |
| Détourner un outil adverse | Détruire la menace ou l’utiliser | Bras, projectiles, invocations, surfaces |
| Piloter une réaction | Qui ou quoi déclenche, depuis quelle case | Leurre, collision, première frappe, déplacement après ciblage |
| Choisir une transition | Franchir un seuil ou attendre une meilleure main | Barre de phase, compteur visible, garde d’une carte |
| Modifier le terrain | Réduire le danger ou créer un accès offensif | Abri, passerelle, brume, gel, propagation |
| Contrôler le tempo | Retarder pour construire ou accélérer avant saturation | Renforts annoncés, ressource ennemie plafonnée |
| Préparer avant la salle | Sacrifier une valeur de run pour un avantage ciblé | Événement, réserve, équipement, drop de renseignement |
| Accomplir un objectif | Quels ennemis valent réellement le détour | Rituel, extraction, protection, champion facultatif |
| Exploiter une faction | À qui laisser une action et qui provoquer | Entité libérée, soutien manipulable, hostilité prévisible |

Il faut distinguer une interaction créative, une stratégie dominante et un dysfonctionnement. Un poison qui évite volontairement une riposte directe peut être une récompense de spécialisation. Une position inaccessible qui neutralise tout un boss peut supprimer le reste du combat. Une boucle hors initiative peut contourner les règles plutôt que les approfondir. L’existence d’un guide de victoire ne prouve donc pas à elle seule la profondeur de l’affrontement.

Nous devrions accepter que certains builds deviennent très puissants. Leur réussite devrait venir de pièces réunies et de décisions compréhensibles. Une réponse forte à un boss particulier donne de la valeur au parcours ; une réponse universelle qui annule toutes les salles réduit cette valeur.

## 6. Comparaison précise avec notre version

Ces constats prolongent la lecture du code consignée dans l’audit initial ; ils ne reposent pas sur une nouvelle simulation. Référence Git de la recherche : `9af4a96a`.

| Système actuel | Potentiel révélé par la recherche | Écart à traiter |
|---|---|---|
| Déplacement, poussée, attraction, portée | Piloter les attaques, manipuler des objets, rompre des liens | Les occasions doivent être portées par les salles et ennemis |
| Surfaces et réactions déjà présentes | Terrain transformable, danger convertible en outil | Règles communes et aperçu des réactions successives |
| Collecteur et porteurs | Interception et détournement de ravitaillement | Rendre le rendement futur et la source visibles |
| Conducteur et molosses | Ciblage marqué, coordination de chasse | Permettre de manipuler la marque et la trajectoire |
| Rabatteur et exécuteur | Placement suivi d’une punition différée | Montrer la chaîne entière avant la fin du tour |
| Porte-égide et soutiens | Réseau de protection à désassembler | Plusieurs manières de casser une relation |
| Paris, transition sous seuil | Préparation d’un second temps de combat | Le déclenchement actuel peut être évité par un coup létal : choisir si c’est voulu |
| Dix cartes, quatre en main, une conservée | Planifier une séquence courte sous incertitude | Un mécanisme obligatoire ne doit pas exiger une seule pioche |
| 112 familles, initiations proches entre classes | Grande capacité de contenu et spécialisation | Davantage de relations entre cartes, pas seulement de variantes de dégâts |
| Équipements et trois reliques d’élite | Construire une manière de jouer persistante | Effets encore largement numériques ou orientés dégâts directs |

Sources locales principales : [rencontres](../../core/expedition/catabase_monster_encounter_catalog.gd), [évolutions](../../core/expedition/catabase_monster_evolution_catalog.gd), [décisions ennemies](../../core/ai/catabase_monster_decision.gd), [cartes de classe](../../core/expedition/class_card_catalog.gd), [écosystème](../../core/expedition/card_ecosystem_catalog.gd), [effets](../../core/expedition/card_ecosystem_effects.gd), [surfaces](../../battle/dynamic_terrain/terrain_surface_runtime_service.gd), [route](../../core/expedition/catabase_route_v6.gd).

Le point le plus important : nous possédons plusieurs **verbes tactiques**, mais encore trop peu de rencontres et de constructions qui les font coopérer sur plusieurs tours. Ajouter des boss sans développer les moteurs de personnage ferait porter toute la profondeur sur des énigmes imposées par l’adversaire. Ajouter des cartes sans rencontres qui leur donnent des usages laisserait les meilleurs coefficients décider trop souvent.

### Donner une intelligence de combat différente à chaque classe

Propositions, en complément des passifs existants :

| Classe | Ressource ou relation à développer | Manières différentes de résoudre une même menace |
|---|---|---|
| Assassin | Marques transférables, exécution, emprunt de mobilité | Supprimer le relais, échanger avec une cible, préparer une élimination qui rembourse une action |
| Gardien | Garde investie, interception, riposte orientable | Encaisser pour charger, protéger un dispositif, convertir la pression ennemie en contre-attaque |
| Arpenteur | Trajets, balises, lignes préparées | Rediriger une poursuite, couper un ravitaillement, créer un angle de tir |
| Thaumaturge | États convertibles, surfaces, détonation différée | Changer le terrain, consommer une affliction, transformer un danger en ouverture |

Ces identités demandent des cartes de préparation, de conversion et de dépense. Un bonus conditionnel de première attaque ne suffit pas à constituer un moteur. Les classes peuvent partager une solution de secours tout en ayant des rendements, risques et vitesses très différents.

### Relier les cartes, équipements, reliques et niveaux

La comparaison avec Slay the Spire développée dans le dossier précédent reste déterminante : une carte devrait pouvoir changer la valeur des autres. Pour notre grille, ajouter une quatrième relation : changer la valeur d’une case ou d’une intention ennemie.

Exemple de construction proposée : une carte produit de la garde ; une seconde dépense une partie de cette garde pour pousser ; une relique conserve un reliquat après une collision ; un équipement récompense le maintien près d’un obstacle. La même construction peut éloigner un porteur, orienter un champion ou préparer une ouverture de boss. Les quatre pièces ne doivent pas être obligatoires pour que la première interaction fonctionne.

Le niveau peut débloquer un choix de fonctionnement — portée contre conversion, mobilité contre rendement, déclenchement immédiat contre conservation — plutôt qu’ajouter exclusivement une valeur. Les drops automatiques en réserve doivent donner une occasion réelle de compléter un moteur ; sinon la variété du catalogue reste théorique. Les cartes étrangères doivent avoir une utilité accessible compte tenu des limites actuelles de maîtrise.

Une relique intéressante pose une nouvelle règle que le joueur peut exploiter fréquemment. Elle peut aussi avoir un coût : une charge supplémentaire en échange d’une case dangereuse, un effet conservé contre une ressource future. Il faut mesurer la fréquence réelle des déclenchements dans la run, pas seulement l’attrait de sa description.

## 7. Construire un bestiaire et des champions à grande profondeur

Proposition de vocabulaire partagé : **lier, marquer, charger, livrer, copier, intercepter, déplacer, transformer, invoquer, consommer, canaliser, réagir**. Chaque famille de monstres introduit un petit ensemble cohérent ; les champions en changent une relation, les boss les recombinent avec la salle.

| Famille proposée | Monstre de base | Champion | Usage de boss |
|---|---|---|---|
| Convoyeurs | Porte une charge vers un receveur | Peut détourner une charge déposée | Réseau de livraisons et choix de sabotage |
| Chasseurs | Suit une marque annoncée | Transmet la marque après sa charge | Manipulation des trajectoires et des leurres |
| Ligateurs | Protège un allié en ligne de vue | Répartit une partie des dégâts entre deux liens | Défaire, déplacer ou retourner un réseau |
| Fondeurs | Dépose une surface | Consomme une surface pour modifier son sort | Salle dont les propriétés changent avec les actions |
| Répliquants | Réagit à une catégorie d’action | Mémorise le dernier effet admissible | Choisir ce qu’on lui fait apprendre |
| Collecteurs | Aspire une ressource proche | Convertit une ressource volée en nouvelle attaque | Interception, récupération et dépense concurrentes |

Ce tableau décrit des propositions ; il ne prétend pas que les variantes sont déjà présentes. Une variante champion doit changer une décision : l’ordre de ciblage, la bonne distance, la ressource à conserver ou le moment d’attaquer. « Plus de PV et plus de dégâts » peut accompagner cette transformation, mais ne la remplace pas.

Pour composer les salles, utiliser une matrice de compatibilité : le chargeur crée-t-il une ouverture pour l’artilleur ? Le protecteur supprime-t-il toutes les réponses au porteur ? Une surface empêche-t-elle l’accès à l’unique commande obligatoire ? Chaque combinaison doit être évaluée avec les trois PM de base, les obstacles et l’ordre effectif des actions.

La progression pédagogique peut suivre : découvrir un verbe sur un monstre, le combiner avec un soutien, affronter sa variante champion, puis le retrouver dans une phase de boss. La progression roguelike peut ensuite changer l’ordre des familles, les ressources de salle et les modificateurs compatibles. Cela donne de la rejouabilité sans effacer ce que le joueur a appris.

## 8. Exemple original : le Régisseur des Chaînes

**Prototype de conception uniquement, inspiré de principes étudiés et adapté à notre solo.** Objectif : permettre des plans fondés sur le déplacement, la garde ou les états, avec un accès universel au mécanisme. Les valeurs ci-dessous sont hypothétiques.

**Salle.** Deux conduits indépendants, deux treuils, des obstacles interrompant les liens et un porteur. Le boss reste attaquable ; chaque conduit alimenté lui donne une réduction partielle, plafonnée. Les treuils sont accessibles à pied par des trajets vérifiés. Une interaction adjacente coûte 1 PA, hors pioche, une fois par treuil et par tour ; elle redirige la prochaine livraison de ce conduit. Elle ne modifie pas les dix cartes du deck.

**Calendrier annoncé.** Au début du tour du héros, un porteur révèle son trajet et le conduit qu’il alimentera. Une livraison requiert qu’il atteigne effectivement le conduit ; le lien est bloqué par les obstacles prévus à cet effet. Après le tour du héros, la livraison se résout, puis le boss. Un conduit redirigé par treuil reçoit la livraison mais décharge son énergie sur le boss. S’il n’y a aucune livraison, la redirection reste disponible jusqu’à la prochaine, avec indicateur visible.

**Menace.** Le boss annonce une charge vers une case fixée. Se déplacer évite la zone mais ne change pas la destination ; le trajet peut heurter un conduit. Une collision casse le conduit, retire sa réduction et provoque une riposte annoncée au cycle suivant. Aucun recalcul silencieux de cible après le déplacement du héros.

**Trois plans.** Détruire rapidement le porteur réduit la pression mais renonce à son énergie. Manipuler la charge casse une défense au prix d’une nouvelle menace. Laisser la livraison partir après redirection consomme des actions et du déplacement, mais transforme le soutien adverse en dommage. Les cartes améliorent ces plans : ralentissement pour gagner du temps, poussée pour changer un trajet, garde pour accepter la riposte, téléportation pour rejoindre un treuil.

**Exemple de budget, pas une simulation gagnante.** Avec 6 PA : interaction de treuil 1 PA, deux cartes à 2 PA, garde de secours 1 PA. Quatre cartes en main suffisent puisque seules deux sont jouées ; les trois PM restent une contrainte de position à vérifier sur la map. Un autre tour peut conserver une carte utile et investir dans l’interception. Cette comptabilité montre seulement qu’un tour comportant mécanique de salle et jeu de cartes est possible.

**Transition.** À mi-vie, le boss annonce la réparation prochaine d’un seul conduit, choisi selon une règle affichée. Le joueur peut interrompre la réparation, exploiter l’ouverture restante ou préparer une nouvelle redirection. Un coup létal termine le combat : dans ce prototype, la transition n’est pas un verrou de PV. Ce choix explicite conserve la valeur d’une forte attaque préparée.

**Contre-exemples à vérifier.** Le porteur est immobilisé indéfiniment ; le boss n’atteint jamais le héros ; les deux conduits sont cassés avant d’avoir joué ; la redirection déclenche deux fois ; la mort du porteur laisse un renforcement permanent ; une main sans mobilité ne rejoint aucun treuil. Il faut traiter ces cas avant de multiplier les variantes.

## 9. Conditions nécessaires à cette ambition

1. **Un langage fiable des effets.** Catégories communes pour ralentissement, immobilisation, marque, dégâts périodiques et déplacement. Les divergences actuelles d’identifiants doivent être résolues avant de promettre des interactions générales.
2. **Des événements précisément ordonnés.** Frappe, dégâts, mort, collision, apparition et transition doivent avoir un ordre stable. Les effets provenant d’une source doivent savoir quoi faire à sa disparition.
3. **Des intentions explicables.** Indiquer cible, case, trajet, condition et possibilité de révision. Une intention verrouillée et une poursuite adaptative sont deux mécaniques distinctes ; l’interface doit les distinguer.
4. **Une réponse accessible aux obligations.** Une commande de salle, un outil prêté ou plusieurs contres ordinaires peuvent garantir l’accès. Une carte rare peut être excellente contre le boss sans être nécessaire pour avoir le droit de le combattre.
5. **Des interactions entre progression et combat.** Drops, niveaux et équipements doivent construire les possibilités qui seront réellement utilisées dans les salles suivantes.
6. **Des variantes composables.** Une règle de compatibilité vaut mieux qu’un tirage arbitraire de tous les monstres et modificateurs. Conserver aussi des salles simples qui laissent apprécier la puissance acquise.

L’ordre de réalisation recommandé est : fiabiliser ces contrats ; développer une famille existante et deux moteurs de classe complets ; construire une salle de boss qui les accepte avec des réponses différentes ; relier ses récompenses à la suite ; élargir ensuite le bestiaire et les recombinaisons. Cet ordre organise la production sans réduire l’ambition finale.

## 10. Vérifications à prévoir et état réel du travail

La profondeur n’est pas validée par le nombre de règles écrites. Pour chaque boss proposé, tester les quatre classes, plusieurs ordres de pioche, une main sans mobilité spéciale et un build spécialisé. Relever les décisions qui changent réellement le résultat, les tours consacrés à répéter une procédure acquise, les décès incompris et les occasions de détourner une règle.

Une fiche de rencontre devrait conserver : préconditions, états, événements, délais, ordre de résolution, géométrie, sources de renforcement, réponses ordinaires, contres spécialisés, variantes compatibles, stratégie de victoire attendue et solutions alternatives découvertes. Le but est de rendre les interactions partageables entre concepteurs et vérifiables dans le moteur.

**Travail effectué :** recherche documentaire et comparaison avec l’audit du code ; rédaction de ce dossier ; liens avec les deux audits précédents. Aucun gameplay modifié. Aucun nouveau test moteur ni playtest exécuté pour cette extension documentaire. Le résultat antérieur de la suite `cards` reste 76/77 tests réussis, avec un échec de contrôle d’unicité des icônes ; il ne valide ni l’équilibrage ni les propositions présentes.

**Couverture :** les boss nommés par l’utilisateur, les cinq donjons d’Otomaï, les Cavaliers séparés et réunis, leur rencontre solo distincte, les Songes, puis transpositions en monstres, champions, classes, cartes et progression. Wakfu, Waven, Slay the Spire et les autres deckbuilders restent traités dans le [dossier comparatif précédent](run_cartes_references_combat_deckbuilding_2026-09-22.md). Cette recherche ciblée ne prétend pas inventorier intégralement leurs bestiaires.
