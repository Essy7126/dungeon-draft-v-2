# Sorts, enchaînements et réponses adverses

Lecture du 25 septembre 2026. Les références sont délimitées dans [Sources](SOURCES.md). Les noms anglais sont conservés lorsque cela évite une traduction ambiguë. Dans les comparaisons locales, **G** désigne les catalogues Godot actuels et **V1** la proposition consommable indépendante. P = Prouesse ; les dégâts des jeux externes ne sont pas convertis arbitrairement en P.

Chaque tableau sépare le contrat externe de notre analyse. Une ressemblance de nom n'établit pas une équivalence : une interruption, une réduction de PA et une réduction du prochain impact sont trois outils différents.

## 1. DOFUS : construire une situation plutôt que juxtaposer des dégâts

### Xélor : la position devient une ressource

La refonte annoncée par Briss en novembre 2014 expliquait les limites du retrait massif de PA : expérience répétitive et frustrante, difficile à concilier entre PvP et PvM. Elle proposait une identité fondée sur les déplacements et leurs combinaisons. C'est une intention de conception historique, pas une description du Xélor actuel. [Devblog reproduit par JeuxOnline](https://dofus.jeuxonline.info/actualite/46528/refonte-classe-xelor-annoncee).

| Référence et version | Contrat utile à retenir | Comparaison avec Dungeon Draft |
|---|---|---|
| Téléfrag, annonce 2014 | Une téléportation vers une case occupée provoque un échange ; état exploitable par d'autres sorts. | G possède déplacements et bonus sur cible déplacée, mais déplacer ne crée pas une règle de transport partagée. V1 Permutation `r08` échange des places sans construire une chaîne spatiale. |
| Synchro, annonce 2014 | Invocation stationnaire renforcée par des Téléfrags distincts ; sa propre mise en Téléfrag déclenche l'explosion. | Une pièce posée crée plusieurs tours de préparation et une cible à protéger. Nos cartes de terrain posent surtout un effet immédiat ou une zone persistante. Une telle pièce serait un nouveau rôle, avec un coût en copies à surveiller. |
| Gelure, annonce 2014 | Sur Téléfrag, retour à une position précédente et consommation de l'état. | G/V1 « marqué » récompense essentiellement le prochain impact ou certains dégâts. Un état peut aussi modifier la destination d'un déplacement : c'est une différence de fonction. |
| Frappe du Xélor, guide bêta 2.45 | Déplacement symétrique autour du lanceur. | Une poussée de deux cases et une symétrie ne posent pas le même problème géométrique. Nos grilles peuvent porter ce type de calcul, mais une version consommable doit rester utile sans une seconde carte rare. |

Source des trois premières lignes : [annonce 2014](https://dofus.jeuxonline.info/actualite/46528/refonte-classe-xelor-annoncee). La dernière appartient à un autre état du jeu : [guide indiquant la bêta 2.45](https://dofus.jeuxonline.info/article/8348/sablier-xelor). Ne pas assembler leurs valeurs en un kit contemporain fictif.

**Ce qui nous intéresse :** un déplacement peut sauver, préparer, charger une pièce et sélectionner une future cible. Le joueur apprend une grammaire. Chez nous, `a_ambush` demande deux cases parcourues puis augmente les dégâts ; la position exacte de départ et la trajectoire ont moins de fonctions propres.

**Ce qui doit rester mesuré :** rendre tous les sorts dépendants d'une permutation précise produirait des mains mortes. Pour notre V1, une mécanique spatiale devrait fonctionner avec les PM ordinaires et une seule carte commune ; une combinaison de trois consommables doit être un sommet, pas le fonctionnement de base.

### Roublard : plusieurs commandes autour d'une même pièce

Lecture d'un [guide historique Roublard](https://dofus.jeuxonline.info/article/10534/comprendre-roublards), sans prétendre reprendre les valeurs de la version actuelle.

| Sort / dispositif | Contrat utile | Comparaison locale |
|---|---|---|
| Bombes, murs, Détonateur | Pièces persistantes, liaison par alignement, explosion déclenchée. | G a des surfaces et des déplacements forcés, mais ces cartes n'offrent pas un réseau de pièces destructibles commandées par le joueur. |
| Botte | Pousse ; traitement spécifique des bombes. | Nos poussées peuvent être communes tout en ayant une interaction de classe exclusive. Inutile de créer quatre variantes numériques de la même poussée. |
| Aimantation | Attire vers une cible, avec comportement adapté aux bombes. | G `g_hook` attire fortement ; sa valeur dépend surtout de la distance. Un point d'ancrage mobile ajouterait un choix de destination. |
| Entourloupe | Échange le Roublard avec une de ses bombes. | V1 `r08` ressemble au verbe « échanger », mais le Roublard investit d'abord dans une pièce qui sert également d'arme. |
| Poudre | La destruction de la bombe peut devenir une détonation profitable. | Le joueur peut accepter de perdre un objet préparé. Chez nous, les invocations ennemies offrent des cibles, pas encore ce choix pour les cartes joueur étudiées. |
| Rémission | Protège une bombe à distance ou provoque une réaction de poussée sur une autre cible. | V1 Contre préparé `g05` attend un impact de mêlée pour riposter ; une variante spatiale changerait l'issue de la prochaine attaque plutôt que son seul total de dégâts. |

**Transposition proposée :** une unique balise de l'Arpenteur, éventuellement déplaçable par plusieurs outils ordinaires. La profondeur viendrait de ses interactions, pas d'un catalogue complet de bombes. Deux points à éprouver : coût d'installation face à un combat court ; information visible sur la destruction et les réactions.

### Ennemis : modifier l'ordre des décisions

Lecture du bestiaire historique de l'[Antre du Korriandre — JeuxOnline](https://dofus.jeuxonline.info/article/14647/antre-korriandre). Les descriptions d'un [autre guide](https://www.dofuspourlesnoobs.com/antre-du-korriandre.html) ne concordent pas toutes, notamment pour le déclencheur de Mérulette. Le tableau retient la formulation JeuxOnline, pas un contrat certifié en 2026.

| Ennemi / capacité | Contrat retenu | Ce que cela change ; comparaison locale |
|---|---|---|
| Mérulette — réaction Raulebaque | Une attaque à distance déclenche un retour de positions ; le contact évite cette réaction dans le guide retenu. | Demande « avec quel outil attaquer ? ». Nos ennemis changent surtout la priorité de cible et le placement ; une réaction à une catégorie d'action diversifierait les mains utiles. |
| Dramanite — Marasme | Poison qui sanctionne les PA dépensés. | Transforme l'utilisation du budget d'action en risque. Copier une taxe par carte serait particulièrement coûteux chez nous : perte de PV et perte définitive de la copie. Préférer un risque annoncé, bref, avec réponse par mouvement. |
| Abrazif — Spore Celaine | Invoque une Motte qui rend dangereux le fait de la frapper. | Une invocation n'est pas nécessairement la cible à tuer d'abord. Notre Porteur d'obole récompense l'interruption de livraison ; on peut ajouter une autre famille qui demande de déplacer la pièce. |
| Fongeur — Spore Tafaux | La menace augmente lorsque ses PV diminuent. | Change le choix entre répartir les dégâts et terminer une cible. Notre bonus d'exécution récompense déjà ce comportement côté joueur ; l'ennemi peut le contester. |
| Korriandre — Loute | Attire en ligne et gêne la fuite. | Une attraction prend sa valeur dans l'arène. G possède `Chaînes du Tartare`, du feu et des trous : tester ces liens avant d'inventer un nouvel effet de contrôle. |
| Korriandre — Paixe | Invoque un Sporakne associé à des poussées et réactions de déplacement. | Les invocations peuvent remodeler les trajectoires. G Appel du passeur a déjà une excellente réponse : occuper la case annoncée pour empêcher l'arrivée. |

**Conclusion DOFUS :** la meilleure inspiration est la spécialisation des interactions. Garder des attaques communes simples ; réserver à chaque famille de monstres une règle qui transforme leur emploi. Ne pas généraliser les pertes de tour ni les conditions opaques.

## 2. WAVEN : un petit kit devient un moteur de build

Les trois guides ci-dessous décrivent des kits avec équipement et passifs. Ils ne sont pas fusionnés avec la refonte annoncée sur Steam. Les builds des auteurs démontrent des associations possibles, pas un classement statistique de puissance.

### Flamboyante Kasaï : conserver une ressource ou la dépenser

Lecture du [guide Kasaï, août 2024](https://guidactik.com/waven/guide-et-build-iop-flamboyante-kasai-sur-waven/).

| Élément du kit | Contrat décrit | Comparaison locale |
|---|---|---|
| Passif d'auras | Appliquer un état élémentaire procure l'aura d'épée correspondante. | Le geste banal d'appliquer un état alimente une autre ressource. V1 Thaumaturge donne de la garde au premier état : bon début, mais conversion unique et immédiate. |
| Mouvement Flamboyant | Téléportation de deux cases, portée accrue par les auras. | Le déplacement gagne de la valeur lorsqu'on conserve la ressource. Nos téléportations ont essentiellement une portée fixe. |
| Frappe Flamboyante | Dégâts liés à l'attaque et aux auras ; coût réduit selon les ennemis porteurs d'états. | La préparation influe sur le budget du tour. Chez nous, Marque → Frappe augmente le résultat sans changer le coût ou l'organisation des actions. |
| Tranchant Kasaï | Consomme les auras pour frapper. | Introduit un débouché offensif qui renonce aux bénéfices de conservation. V1 Répercussion est déjà dans cette famille, mais sa rentabilité contextuelle doit être corrigée. |
| Vertu | Convertit les auras en armure. | Une même préparation peut résoudre deux problèmes différents. Chez nous, marque, garde et terrain ont peu de conversions alternatives au sein d'une même classe. |

**Ce qui fait l'intérêt du kit selon notre analyse :** la question n'est pas seulement « combien d'auras puis-je produire ? », mais « lesquelles garder pour les propriétés qu'elles donnent, lesquelles convertir maintenant ? ». À transposer avec un plafond bas et des générateurs communs. Un moteur alimenté uniquement par des drops rares contredirait la promesse d'un héros jouable dès le départ.

### Aiguille Pikuxala : la mobilité est aussi une attaque

Lecture du [guide Pikuxala, février 2026](https://guidactik.com/waven/guide-du-deck-xelor-aiguille-pikuxala-sur-waven/).

| Élément du kit | Contrat décrit | Comparaison locale |
|---|---|---|
| Passif de téléportation | Une arrivée par téléportation inflige 60 % de l'attaque en croix de rayon deux. | Notre mobilité améliore l'accès aux cibles ; elle n'est pas le cœur d'une production d'effets propre à la classe. |
| Puissance Pikuxala / Cadran | Cadran éphémère à 1 PA ; les failles temporaires produisent protection et dégâts au passage. | Une pièce et un trajet alimentent le tour. Notre terrain possède les supports techniques, mais le laboratoire V1 ne représente pas cette famille de séquences. |
| Saut Pikuxala | Téléportation courte puis retour à la case de début de tour. | Une ancre temporelle rend la case initiale importante. V1 `a05` et `r05` n'enregistrent pas une position de retour. |
| Téléportation Pikuxala | Déplacement, dégâts autour de l'arrivée et retour à la case initiale. | Exemple d'outil qui combine engagement et sortie sous une contrainte spatiale, plutôt que deux cartes séparées obligatoires. |
| Déstabilisation | Échange avec un Sinistro et pioche le suivant. | L'effet sélectionne un outil associé au plan. Notre Recentrage `n08` pioche sans sélectionner de rôle et reste limité par la taille maximale de main. |

**Transposition prudente :** un premier déplacement qualifiant par tour pourrait ouvrir une option d'attaque ou laisser une ancre. Éviter de copier un déclenchement à chaque téléportation sans limite : en V1, il pourrait rendre les cartes de déplacement supérieures aux vraies attaques et favoriser une seule route d'équipement.

### Justelame Brutale : défense et attaque partagent une ressource

Lecture du [guide Justelame, février 2026](https://guidactik.com/waven/guide-et-build-du-iop-justelame-brutale-sur-waven/).

| Élément du kit | Contrat décrit | Comparaison locale |
|---|---|---|
| Passif | Déclenchement de l'effet Mêlée : 50 % de l'attaque en armure, limité à une fois par tour. | Le comportement offensif construit une défense. V1 Gardien produit plutôt une riposte lorsqu'une attaque est absorbée : deux rythmes distincts, tous deux lisibles. |
| Frappe Justelame | L'attaque bénéficie de 65 % de l'armure. | La défense conservée alimente un résultat. Nos bonus `guarded` actuels demandent simplement un bouclier positif : 1 point peut suffire autant qu'un grand stock. |
| Armure Brutale | Dégâts correspondant à 50 % de l'armure. | La grandeur de la ressource devient pertinente. V1 Répercussion le fait déjà, mais la consomme intégralement. |
| Déchaînement Justelame | En fin de tour, dégâts proches fondés sur 30 % de l'armure. | Le moment de résolution fait choisir où terminer. Chez nous, le Gardien gagnerait à avoir une raison de tenir une position précise. |
| Adrénaline Brutale | +1 PM et pioche du prochain sort de mêlée. | Relie mobilité et fiabilité du build. Un outil de préparation de la main peut soutenir une classe sans augmenter directement ses dégâts. |

**Résultat local important :** notre duo Garde ferme → Répercussion est un bon concept de conversion mais une mauvaise référence de rendement au contact, dans le scénario mesuré. Voir les valeurs et les limites dans [l'audit](AUDIT_ET_PRIORITES.md).

**Contrepoint du studio :** dans sa communication d'août 2025, Ankama annonce simplifier des systèmes devenus difficiles à lire, dont la réserve de PA et les couches d'équipement. C'est une intention annoncée, pas un état livré vérifié. [Communication officielle](https://steamcommunity.com/app/2343650/announcements/?l=french). Pour nous, cela plaide pour quelques interactions compréhensibles avant d'empiler de nouveaux passifs.

### Ennemis WAVEN : ce qui est attesté, ce qui reste incomplet

Les [notes officielles sur Steam](https://steamcommunity.com/app/2343650/announcements/?l=french) donnent des éléments précis de comportement, mais pas les fiches complètes de ces monstres.

| Élément attesté dans les corrections | Information disponible | Comparaison possible et limite |
|---|---|---|
| Taure — Au centre de l'Arène | Déclenchement de l'attaque d'un Taure adjacent corrigé. | La formation participe à la menace, comme notre Conducteur avec les Molosses. Coût, déclencheur complet et limites de répétition non vérifiés : aucun calcul de dégâts n'en découle ici. |
| Groin d'Acier | Production excessive d'auras Bushi en coopération corrigée. | Exemple de multiplication involontaire d'une ressource lorsque le nombre de participants change. Notre conception doit préciser si une réaction compte par cible, par action ou par tour. Quantités exactes non vérifiées. |
| Chafers | Corrections de conditions liées au clan présent. | Les relations entre monstres peuvent conditionner des actions. La documentation consultée ne permet pas de reconstruire leur kit ; cette ligne n'est pas une fiche de sort complète. |

Le site Waven Build a été inspecté, notamment ses pages de donjons et de challenges ; les pages accessibles n'ont pas fourni les contrats ennemis nécessaires. **Le volet ennemis WAVEN reste moins documenté que les quatre autres jeux.** Il faut une lecture en jeu ou un bestiaire versionné pour le fermer, sans importer par erreur des sorts de Wakfu ou DOFUS.

Séparément, les [challenges Waven Build](https://www.waven-build.com/bestiaire/challenges) récompensent notamment une élimination au bord, au centre, ou dans un ordre imposé. C'est une piste pour nos futurs modificateurs de butin, pas une preuve sur les sorts ennemis. La baseline de drop sur les monstres doit rester indépendante de ces objectifs optionnels.

## 3. Baldur's Gate 3 : donner des prix et des limites différents aux outils

Les sorts génériques étudiés peuvent appartenir à différents personnages selon leur classe et leur build. Les attribuer exclusivement à un compagnon raconterait mal leur fonctionnement. Les fiches ci-dessous proviennent du wiki communautaire BG3 ; les variantes Tacticien/Honneur sont distinguées.

### Personnages et builds

| Sort | Contrat lu | Comparaison locale et leçon |
|---|---|---|
| [Hold Person](https://bg3.wiki/wiki/Hold_Person) | Action, emplacement de niveau 2, 18 m ; humanoïde, sauvegarde Sagesse, concentration jusqu'à dix tours, nouvelle sauvegarde en fin de tour ; critiques à courte distance contre la cible paralysée. | Plusieurs verrous limitent un effet très fort. G Stase exige Marqué, puis saute une activation avec protection temporaire ; V1 la dégrade contre boss. La durée BG3 et sa vulnérabilité ne peuvent pas être reprises sans les sauvegardes, la concentration et le contexte d'équipe. |
| [Command](https://bg3.wiki/wiki/Command) | Action, emplacement de niveau 1, sauvegarde Sagesse ; ordres de déplacement, chute, abandon d'arme ou arrêt ; pas de concentration. | Montre une famille de contrôles qui ne revient pas à « perdre des PA ». G Chant du Léthé attire et retire 1 PA ; il ne contrôle pas l'équipe de la cible. Le nom seul ferait surestimer notre variété. |
| [Create Water](https://bg3.wiki/wiki/Create_Water) | Action, emplacement de niveau 1 ; Mouillé favorise froid/foudre et protège du feu ; surface transformable. | Une préparation modifie plusieurs décisions ultérieures. G a déjà des réactions de surfaces ; V1 ne représente pas cette chimie. Ajouter une carte « eau » n'a de sens que si ses débouchés sont réellement accessibles. |
| [Hunger of Hadar](https://bg3.wiki/wiki/Hunger_of_Hadar) | Action, emplacement de niveau 3, concentration ; zone aveuglante et difficile, dégâts froid au début du tour et acide à sa fin. | Le timing d'entrée, de début et de sortie fait partie du sort. Nos champs doivent afficher ces moments. G distingue déjà feu au début et givre à l'entrée ; préserver cette information dans la V1. |
| [Repelling Blast](https://bg3.wiki/wiki/Repelling_Blast) | Invocation de Warlock : Eldritch Blast peut pousser jusqu'à 4,5 m lorsqu'il touche. | Un déplacement récurrent maintient l'adversaire dans une zone dangereuse. Chez nous, pousser consomme souvent une copie supplémentaire ; la même combinaison aura un coût de run beaucoup plus élevé. |
| [Misty Step](https://bg3.wiki/wiki/Misty_Step) | Action bonus, emplacement de niveau 2 ; téléportation vers un espace visible jusqu'à 18 m. | La mobilité ne concurrence pas exactement la même ressource que le sort principal. Nos téléportations V1 à 2 PA mangent la moitié du tour : leur valeur ne se compare pas seulement en nombre de cases. |
| [Counterspell](https://bg3.wiki/wiki/Counterspell) | Réaction et emplacement de niveau 3 ; annulation garantie jusqu'au niveau couvert, test au-delà. | Une décision pendant l'action ennemie n'équivaut pas à une préparation au tour précédent. G Dissonance retire des PA ; V1 Couper le souffle diminue le prochain impact. Aucun des deux n'est un Contresort. |

**Séquence étudiée :** une zone persistante et une poussée récurrente donnent un plan de contrôle spatial. Notre réponse n'est pas forcément un nouveau sort : cartes de poussée, terrains déjà présents et intentions ennemies peuvent suffire. Il faut vérifier que l'ennemi peut effectivement sortir, contourner ou interrompre le plan.

### Ennemis et boss

| Ennemi / capacité | Contrat lu | Comparaison locale |
|---|---|---|
| [Grym — Adamantine Skin / Vengeful Guardian](https://bg3.wiki/wiki/Grym) | La chaleur rend le boss vulnérable ; sa poursuite privilégie le dernier attaquant lorsque c'est possible. | Le joueur dirige indirectement une menace avec une règle visible. Notre forge pourrait faire intervenir le choix de cible et la trajectoire du boss, sans imposer une carte rare spécifique. |
| [Githyanki Parry](https://bg3.wiki/wiki/Githyanki_Parry) | Réaction réduisant de 10 un coup d'arme ou à mains nues ; conditions d'équipement et d'état. | Incite à choisir l'ordre des impacts ou un autre canal de dégâts. Une parade ennemie peut faire réfléchir sans supprimer une copie entière ; son nombre d'utilisations doit être visible. |
| [Death Shepherd — No Rest for the Wicked](https://bg3.wiki/wiki/Death_Shepherd) | Résurrection de mort-vivant à 3 m par action bonus ; moitié des PV, totalité en Tacticien/Honneur. | Une paire de soutiens peut rendre l'ordre d'élimination décisif. G a déjà soins limités, Porteurs et invocations plafonnées ; ne pas importer une boucle infinie dans une économie de cartes finies. |
| [Ansur — Gather Power / Stormheart Nova](https://bg3.wiki/wiki/Ansur/Combat) | Préparation d'une activation, puis explosion de foudre ; couvert et interruption deviennent des réponses. | G Fournaise et Sentence du bronze possèdent déjà préparation et fenêtre de réponse. L'écart à combler est la mise en scène de l'intention et la variété de réponses, pas l'invention du principe. |

**Leçon BG3 :** prix, fenêtre d'emploi, cibles admissibles et moyen de casser l'effet comptent autant que les dégâts. Notre V1 gagne en lisibilité avec un budget unifié de PA ; elle doit compenser par des fonctions nettement différentes, pas multiplier des exceptions de réaction.

## 4. Divinity: Original Sin 2 Definitive Edition : des combinaisons fortes, parfois trop universelles

Fiches du [guide de compétences Definitive Edition](https://gamefaqs.gamespot.com/ps4/236378-divinity-original-sin-ii-definitive-edition/faqs/81674/skills). Les contrats sont condensés ; la comparaison de puissance porte sur les contraintes, jamais sur une conversion des dégâts entre jeux. SP = points de Source.

### Compétences

| Compétence | Contrat utile | Comparaison locale |
|---|---|---|
| Adrenaline | 0 PA ; +2 maintenant, −2 au tour suivant ; recharge 4. | Un emprunt crée une dette temporelle. Une carte consommable avec ce pouvoir paierait aussi en copie : coût et remboursement doivent être lisibles avant de la jouer. |
| Backlash | 1 PA ; dague, arrivée derrière la cible, 85 % des dégâts d'arme. | Un accès offensif combiné, là où notre mouvement et notre frappe peuvent exiger deux copies. Ne pas faire de toute mobilité une attaque supérieure : cible et trajectoire doivent contraindre. |
| Rupture Tendons | 2 PA ; dégâts supplémentaires au déplacement, bloqués par l'armure physique. | G Sectionner les tendons retire des PA malgré son nom. V1 Entaille tenace applique une brûlure. Aucun de ces deux outils ne fait payer le mouvement : vraie famille fonctionnelle manquante dans ces cartes. |
| Chicken Claw | 2 PA ; transformation deux tours, sous réserve d'armure physique. | La transformation conditionne des actions, au-delà d'une simple réduction de statistiques. Avec Rupture, l'intérêt dépend d'un déplacement effectif : ne pas supposer une fuite automatique identique dans toutes les versions. |
| Teleportation | 2 PA ; transporte une cible, inflige des dégâts ; Fortifié bloque. | Bien plus libre qu'une poussée sur un axe. Nos déplacements forcés conservent des contraintes spatiales utiles ; une téléportation hostile universelle pourrait les rendre secondaires. |
| Nether Swap | 1 PA ; échange deux cibles ; recharge 3. | V1 Permutation coûte 2 PA et une copie, vise un ennemi non-boss et implique le héros. Notre variante est plus étroite : ne pas la présenter comme le même outil. |
| Rain | 1 PA ; eau et Mouillé. | Source polyvalente de préparation. G possède déjà l'infrastructure de réactions, mais pas un kit de cartes consommables articulé autour de l'eau. |
| Global Cooling | 1 PA ; froid, gel de l'eau et du sang. | Change le plateau hérité des actions antérieures. Notre V1 juxtapose ses champs ; elle ne teste donc pas encore le coût d'une transformation. |
| Living on the Edge | 3 PA ; empêche les PV de passer sous 1 pendant deux tours. | V1 Décret ne protège que d'un impact létal avant le prochain tour. Ce n'est pas une invulnérabilité prolongée ; plusieurs coups peuvent toujours tuer. |
| Skin Graft | 1 PA + 1 SP ; réinitialise les recharges, une fois par combat. | Chez nous, restaurer les cartes consommées modifierait aussi l'économie de run. Réinitialiser une limite de tour sans rendre de copie serait une proposition différente, à plafonner. |

**Enseignement de construction :** des verbes puissants et génériques permettent une grande liberté, mais risquent de devenir obligatoires dans tous les builds. Les témoignages de joueurs ne remplacent pas des statistiques ; ils font néanmoins apparaître cette question pour la mobilité et les outils d'Aérothurge. [Exemple de discussion sur cet investissement systématique](https://www.reddit.com/r/DivinityOriginalSin/comments/sasjy1).

Pour Dungeon Draft, donner un échange de places, une annulation complète et un vol de vie à toutes les classes réduirait la nécessité de les distinguer. Préférer une capacité commune correcte et une interaction spécialisée qui change son usage.

### Ennemis : cohérence entre corps, terrain et compétences

| Ennemi | Contrat / séquence documenté | Comparaison locale |
|---|---|---|
| Fire Slug | Traînée de feu, affinité permettant au feu de le soigner, faiblesse à l'eau. | Le terrain créé par l'ennemi appartient à son plan. Nos Fondeurs et Molosses peuvent déjà combiner terrain et poussée ; vérifier aussi comment l'IA valorise ses propres zones. |
| Royal Fire Slug, Tacticien | Aura protégeant les proches contre l'eau. | La réponse évidente à une faiblesse est temporairement neutralisée par une formation. G Porte-Égide et Oracle produisent déjà une logique de soutien à casser. |
| Aetera | Invocation de renforts près du groupe, suivie d'une attaque de zone Air/Eau. | L'arrivée des renforts et la position initiale structurent l'ouverture. Pour notre run, une ouverture qui exige immédiatement plusieurs rares serait un mauvais usage de ce modèle. |
| Alice Alisceon | Flay Skin puis Burning Anger ; totems et téléportation vers le Nécrofeu. | L'ennemi prépare puis exploite une faiblesse et le terrain. La surprise létale avant une réponse est à éviter chez nous ; annoncer l'étape décisive comme notre Fournaise. |

Sources : [Fire Slug — extrait indexé du wiki communautaire](https://divinityoriginalsin2.wiki.fextralife.com/Fire%2BSlug), [Aetera et Alice — guide de la Definitive Edition](https://gamefaqs.gamespot.com/ps4/236378-divinity-original-sin-ii-definitive-edition/faqs/81674/chapter-4-mastering-the-source). La page Fire Slug complète n'a pas pu être ouverte ; les propriétés reprises étaient présentes dans l'extrait indexé. Aucun chiffre de dégâts n'en est déduit.

**Vérification locale importante :** affirmer que Dungeon Draft n'a pas de réactions de surfaces serait faux. [Le résolveur](../../../battle/dynamic_terrain/terrain_interaction_resolver.gd) définit feu + eau → vapeur, feu + glace → eau, glace + eau → glace, foudre + eau → choc. [Le service](../../../battle/dynamic_terrain/terrain_surface_runtime_service.gd) les applique lors de la rencontre avec une surface dynamique. Cela ne prouve pas que chaque paire est accessible par nos cartes, ni qu'une surface de base suit exactement la même branche. Le futur travail doit relier les outils des classes à cette capacité existante.

## 5. Slay the Spire 1 : fiabilité du plan et coût des conversions

Les cartes sont décrites dans leur version de base sauf précision. Les effets « épuiser » concernent le combat de Slay the Spire ; notre copie consommée disparaît de la run. Cette différence invalide beaucoup de transpositions directes.

### Cartes et moteurs

| Carte / association | Contrat lu | Comparaison locale |
|---|---|---|
| [Corruption](https://maybelatergames.co.uk/tools/slaythespire/cards/corruption/) | Pouvoir à 3 énergies ; compétences gratuites, mais épuisées. | Un avantage immédiat achète une pénurie future au combat. Chez nous, la consommation est déjà la règle ; la même contrepartie ne paierait donc plus la gratuité. |
| Dark Embrace / Feel No Pain | Pioche / blocage déclenchés par l'épuisement. | Un événement négatif nourrit d'autres fonctions. En V1, chaque carte jouée est consommée : un bonus sans plafond toucherait presque tout le deck et gonflerait l'économie d'actions. [Fiches associées](https://maybelatergames.co.uk/tools/slaythespire/cards/corruption/). |
| [Body Slam](https://maybelatergames.co.uk/tools/slaythespire/cards/bodyslam/) | 1 énergie, 0 améliorée ; dégâts égaux au blocage sans le consommer. | Le coût d'une conversion et le fait de perdre ou conserver sa ressource sont décisifs. V1 Répercussion consomme toute la garde, donc doit recevoir une autre valeur ou un autre usage. |
| [Catalyst](https://maybelatergames.co.uk/tools/slaythespire/cards/catalyst/) | 1 énergie ; double le poison, triple améliorée ; s'épuise. | L'amélioration transforme le rendement d'une préparation existante. Nos améliorations V1 majorent souvent de 0,15 P une attaque : fiables, mais moins susceptibles de changer le plan. |
| [Wraith Form](https://maybelatergames.co.uk/tools/slaythespire/cards/wraithform/) | 3 énergies ; Intangible pour deux tours et perte de 1 Dextérité à chaque fin de tour. | Puissance forte contre dégradation future. Notre Décret évite un coup létal, sans reproduire cette fenêtre de protection ni cette dette. Il faut expliquer ce qu'un effet autorise vraiment. |
| [Seek](https://maybelatergames.co.uk/tools/slaythespire/cards/seek/) | 0 énergie ; prend une carte choisie dans la pioche, deux améliorée ; s'épuise. | La sélection rend un plan fiable sans augmenter ses chiffres. C'est un manque plus utile à explorer que de nouvelles attaques similaires. Une sélection V1 doit déplacer une copie existante, jamais créer du stock vendable. |
| [Well-Laid Plans](https://maybelatergames.co.uk/tools/slaythespire/cards/welllaidplans/) | 1 énergie ; conserve une carte en fin de tour, deux améliorée. | Permet d'attendre une fenêtre. Notre modèle de main ne représente pas une option équivalente de rétention choisie ; les combos à deux outils en souffrent quand le deck s'élargit. |
| [Vault](https://maybelatergames.co.uk/tools/slaythespire/cards/vault/) | 3 énergies, 2 améliorée ; termine le tour et en accorde un autre, puis s'épuise. | Une manipulation du temps peut contourner plusieurs contraintes simultanément. Ne pas ajouter ce type de carte avant d'avoir un contrat clair pour garde, statuts, pression de salle et compteurs « une fois par tour ». |

**Différence avec nos classes :** l'intérêt d'une carte ne réside pas seulement dans un meilleur coefficient, mais dans le plan qu'elle rend possible. Toutefois, chercher une seule combinaison obligatoire peut produire une run binaire. Nos cartes communes doivent faire fonctionner le plan ; les rares doivent en ouvrir une variante ou résoudre une situation difficile.

### Ennemis : examiner la manière de jouer les cartes

| Ennemi | Contrat lu | Comparaison locale |
|---|---|---|
| [Time Eater](https://slay-the-spire.fandom.com/wiki/Time_Eater) | Après douze cartes jouées, termine le tour du joueur et gagne de la Force ; compteur conservé entre les tours. | Le nombre de cartes devient un budget tactique. Dans notre run, c'est déjà un coût économique : un ennemi qui taxe les petites cartes doit laisser une voie normale de victoire, pas exiger les rares. |
| [Gremlin Nob](https://slaythespire.gg/elites/Gremlin_Nob) | Enrage renforce l'ennemi quand le joueur emploie une compétence. | Encourage un rythme et une composition différents. On peut construire un ennemi qui réagit à un soin ou à une garde, avec un déclenchement plafonné et annoncé. |
| [Awakened One](https://slay-the-spire.fandom.com/wiki/Awakened_One) | La première phase sanctionne les Pouvoirs par un gain de Force ; cette pression change ensuite. | Une règle peut évoluer entre phases. Notre Pâris possède déjà une transition : le laboratoire V1 simplifié ne suffit pas à juger la réserve de cartes nécessaire. |
| [Chosen — Hex](https://slaythespire.wiki.gg/wiki/Chosen) | Les cartes non offensives ajoutent des Dazed dans la pioche. | La menace touche la qualité des mains. Chez nous, des parasites temporaires de combat seraient distincts du stock ; supprimer ou voler définitivement une rare ferait payer deux fois l'échec. |

Les valeurs de puissance qui varient avec l'Ascension ne sont pas mélangées. Les sites communautaires consultés ne fournissent pas de taux de victoire exploitables pour cette étude.

## 6. Comparaison des règles, au-delà des noms de sorts

| Question de gameplay | Exemples étudiés | État local | Direction utile |
|---|---|---|---|
| Où puis-je déplacer une cible ? | Symétrie Xélor, Entourloupe, Nether Swap | Poussée/attraction nombreuses ; échange V1 plus limité | Ajouter une destination construite, pas seulement une case de portée. |
| Que puis-je faire d'une ressource déjà préparée ? | Auras Kasaï, armure Justelame, Body Slam | Garde conditionnelle, Marque ; Répercussion V1 | Au moins deux débouchés viables pour un moteur de classe. |
| Puis-je attendre la bonne fenêtre ? | Préparations ennemies, Well-Laid Plans | Intentions et préparations G ; pas de rétention dédiée V1 | Rendre une carte utile plus fiable avant de la rendre plus forte. |
| Comment le monstre réagit-il à mon choix ? | Mérulette, parade, Nob, Chosen | Soutiens et priorités déjà riches ; moins de réactions à catégories de cartes | Quelques réactions lisibles, sans taxe permanente sur les copies. |
| Puis-je résoudre autrement qu'en frappant ? | Grym, bombes, formation Royal Slug | Cases d'invocation à occuper, lignes de vue à rompre, terrain | Réutiliser ces réponses dans les rencontres du laboratoire. |
| Quelle est la vraie contrepartie ? | Concentration, dette de PA, épuisement, conversion de garde | PA + copie consommée + risque de position | Toujours chiffrer les trois coûts, et ne pas compter deux fois la même contrainte. |

La suite opérationnelle, les calculs et les propositions sont dans [Audit et priorités](AUDIT_ET_PRIORITES.md).
