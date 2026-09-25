# Grammaire des cartes et interactions

Ce document complète les 370 fiches : les effets nommés propres aux cartes (Corruption, Rushdown, etc.) sont définis dans leur fiche ; les règles partagées sont précisées ici. On étudie Slay the Spire 1 après les changements d’équilibrage de la version 2.2. Aucun client du jeu n’a été exécuté pour cette étude. Les détails de file d’actions non reproduits restent des points de vérification avant une implémentation.

## 1. Ce qui circule, ce qui disparaît, ce qui persiste

| Opération | Contrat | Conséquence de conception |
|---|---|---|
| Piocher | Déplace une carte de pioche vers la main ; si nécessaire, remélange la défausse. Pioche normale : 5 par tour ; capacité normale de main : 10. | La quantité de cartes vues et la qualité des cartes vues sont deux leviers différents. |
| Mettre en main | Cherche ou transfère une carte sans nécessairement la piocher : Seek, Hologram, Violence. | Ne déclenche pas automatiquement Void, Deus Ex Machina ou Evolve ; No Draw ne signifie pas aucune carte supplémentaire possible. |
| Défausser volontairement | Déplace de la main vers la défausse pendant les actions. | Déclenche les récompenses dédiées ; la défausse automatique de fin de tour ne déclenche pas Reflex/Tactician. |
| Épuiser | Retire l’exemplaire du cycle du combat, avec une pile dédiée. | L’exemplaire du deck revient au prochain combat. Feel No Pain/Dark Embrace peuvent transformer ce retrait en récompense. |
| Retirer du deck | Suppression hors combat de l’exemplaire permanent. | Change les prochains combats et peut déclencher le coût de Parasite. Ce n’est pas Épuisement. |
| Éthérée | Une carte encore en main à la fin du tour s’épuise. | Un effet de rétention ne neutralise pas Éthérée. L’amélioration d’Apparition/Echo Form change donc leur accessibilité temporelle. |
| Pouvoir joué | Devient un effet installé, sans revenir dans le cycle de pioche normal. | Ce retrait n’est pas un Épuisement : aucun carburant automatique de ce type ; Exhume ne récupère pas le pouvoir installé. |
| Créer | Produit une nouvelle carte de combat ; Anger, Shiv, Smite, Discovery… | Création et pioche ne sont pas interchangeables. La nouvelle carte n’entre normalement pas dans le deck permanent. |
| Copier | Duplique l’état pertinent d’un exemplaire existant ; Dual Wield, Nightmare. | L’état copié peut comprendre améliorations ou réductions ; il ne faut pas remplacer la copie par une carte de base neuve. |
| Doubler un jeu | Burst, Double Tap, Amplify, Echo Form ou Omniscience produisent une deuxième résolution. | Ce n’est pas simplement doubler la valeur finale : paiements annexes, compteurs et mutations peuvent être répétés. |
| Retain | Conserve une carte en main au lieu de la défausser. | Rend possible le rendez-vous de deux pièces ; réduit cependant l’espace libre. |
| Ne pas défausser | Runic Pyramid empêche la défausse normale. | N’est pas le déclencheur Retain d’Establishment ; même résultat visuel, contrat différent. |
| Innée | Place la carte dans la main d’ouverture, sous les règles de capacité. | Fiabilité contre coût de place ; un bonus d’ouverture n’est pas une pioche gratuite. |
| Améliorer | Modifie le contrat d’une carte, généralement une fois. | Changer une règle, un coût ou un ciblage peut être plus important que les dégâts. Searing Blow est l’exception répétable ; Burn+ vient d’un ennemi. |
| Améliorer temporairement | Armaments, Apotheosis : modification limitée au combat. | Ne remplace pas un investissement permanent de feu de camp. Master Reality concerne la création future, pas toutes les cartes passées. |
| Croître dans la run | Feed, Lesson Learned, Genetic Algorithm, Ritual Dagger. | La récompense survit au combat, avec déclencheur précis ; les copies temporaires et les exemplaires permanents ne sont pas à confondre. |
| Fatal | Le coup doit tuer une cible éligible ; les minions n’accordent pas les récompenses Fatal. | Ne pas confondre avec tout remboursement sur mort : Sunder n’emploie pas cette même restriction. |
| Scry | Consulte jusqu’à N cartes au-dessus de la pioche ; défausse celles choisies. | Sélection sans pioche intrinsèque. Cut Through Fate ajoute séparément une pioche ; Weave et Nirvana réagissent au Scry. |
| Transformer | Remplace une carte par une autre selon un pool. | Différent de l’amélioration ; ne garantit pas une carte de même fonction ou rareté. Pas un système de crafting fiable. |

Références de règles : [pioche](https://slay-the-spire.fandom.com/wiki/Card_Draw), [épuisement](https://slay-the-spire.fandom.com/wiki/Exhaust), [rétention](https://slay-the-spire.fandom.com/wiki/Retain), [amélioration](https://slay-the-spire.fandom.com/wiki/Upgrade), [duplication par Burst](https://slay-the-spire.fandom.com/wiki/Burst). Les exemples précis sont détaillés dans les catalogues.

Pour Fatal, une mise à zéro provisoire n’est pas toujours une mort éligible : le dernier Darkling du groupe compte, les autres non ; la première phase d’Awakened One ne compte pas. Les effets simplement formulés sur une mort, comme Sunder, ne partagent pas toutes ces exclusions. [Exceptions de Fatal](https://slay-the-spire.fandom.com/wiki/Fatal).

## 2. Énergie : trois temporalités, plusieurs limites

**Coût imprimé**, **coût courant du combat**, **coût de ce tour** et **gratuité au prochain jeu** sont des états distincts. Streamline modifie un exemplaire pour le combat ; Bullet Time agit sur la main de ce tour ; Setup/Forethought réservent une gratuité jusqu’au jeu. Cette distinction influence All for One et Scrape. Une carte gratuite peut toujours coûter une place, une pioche, un compteur adverse et des PV annexes.

Le gain net normal est le gain après paiement moins le coût : Seeing Red normal donne +1 net ; Sneaky Strike conditionnel rembourse ses 2 mais il faut les avancer ; Double Energy normal depuis 3 termine à 4. Les gains différés (Outmaneuver, Charge Battery, Doppelganger) ne permettent pas de se défendre avec de l’énergie qui n’arrivera que demain.

Un coût X dépense l’énergie disponible et utilise ce montant comme paramètre. Le X d’Expunger est au contraire une **valeur mémorisée à sa création** ; jouer Expunger coûte 1. Chemical X augmente de 2 le paramètre d’un effet X, sans ajouter 2 énergie à la réserve. Une duplication d’une carte X réutilise le X initial sans repayer cette énergie. Recycler une carte X rapporte l’énergie restante après paiement de Recycle ; une carte sans coût jouable ne fournit pas une énergie négative. [Énergie](https://slay-the-spire.fandom.com/wiki/Energy), [Recycle](https://slay-the-spire.fandom.com/wiki/Recycle), [Chemical X](https://slay-the-spire.fandom.com/wiki/Chemical_X).

## 3. Dégâts, blocage et pertes de PV

| Règle | Effet à retenir | Erreur à éviter |
|---|---|---|
| Force | Ajout par impact d’attaque ; Heavy Blade possède un coefficient particulier. | Confondre cinq coups avec une attaque cinq fois plus grosse. |
| Dextérité | Modifie les gains de blocage concernés des cartes. | L’appliquer indistinctement à Frost, Metallicize, After Image ou à tous les pouvoirs. |
| Faible | Attaques à 75 % de leur valeur ; les piles prolongent la durée. | Lire Faible 3 comme −75 % ou comme trois applications de −25 %. |
| Vulnérable | Attaques reçues à 150 % ; les piles prolongent la durée. | Amplifier arbitrairement poison, Mark ou Omega. |
| Fragile | Blocage des cartes à 75 % ; durée cumulable. | Réduire toutes les sources de protection du jeu. |
| Arrondis | Les attaques sont évaluées par impact, avec résultat entier. | Arrondir uniquement la somme d’une rafale : M02 montre l’écart. |
| Blocage | Absorbe les dégâts qui le traversent normalement ; disparaît au début du prochain tour de son porteur sans conservation. | Le traiter comme une réduction permanente des statistiques offensives. |
| Perte de PV | Ignore normalement le blocage : Pain, Regret, poison, Mark, sacrifices. | Croire que 50 blocage rend Offering gratuit en santé. |
| Vol/retour de dégâts | Reaper soigne et Wallop protège selon dégâts non bloqués effectivement infligés, limités par la santé de la victime. | Rentabiliser arbitrairement le sur-dégât. |
| Vigor | Bonus de la prochaine carte d’attaque, sur chacun de ses impacts ; consommé par cette attaque. | Bonus permanent ou seulement premier impact. |
| Intangible | Chaque événement de dégât ou de perte de PV est ramené au plus à 1 pendant sa durée. | Immunité complète : une rafale comporte plusieurs événements. |
| Buffer | Annule un nombre donné d’événements de perte de PV. | Confondre deux charges et deux tours protégés. |
| Armure plaquée | Blocage en fin de tour selon sa valeur ; perd une pile par impact d’attaque infligeant des PV. | Confondre Wish avec une création de nouvelles piles à chaque tour. |
| Metallicize | Blocage régulier de fin de tour sans cette usure par impact. | Donner la même vulnérabilité à ces deux protections. |
| Épines et ripostes | Réagissent aux attaques/impacts selon l’effet ; certains effets comptent la carte, d’autres chaque frappe. | Un seul vocabulaire « quand attaqué » sans granularité précise. |

Sources : [Force](https://slay-the-spire.fandom.com/wiki/Strength), [Faible](https://slay-the-spire.fandom.com/wiki/Weak), [Vulnérable](https://slay-the-spire.fandom.com/wiki/Vulnerable), [Intangible](https://slay-the-spire.fandom.com/wiki/Intangible), [protections et buffs](https://slay-the-spire.fandom.com/wiki/Buffs), [discussion du sur-dégât de Wallop](https://www.reddit.com/r/slaythespire/comments/f0vael/). Les formules testées n’incluent pas tous les modificateurs de reliques et d’ennemis ; elles annoncent leurs hypothèses.

La règle générale d’Intangible possède notamment une exception adverse avec The Boot, qui peut relever à 5 un petit dégât d’attaque non bloqué. Ce type d’exception doit rester attaché à sa source, pas intégré à toutes les formules de dégâts. [Interaction documentée](https://slay-the-spire.fandom.com/wiki/Intangible).

## 4. Les quatre moteurs de règles propres aux personnages

### Ironclad : sacrifier, convertir, capitaliser

L’identité ne se réduit pas à la Force. Les PV peuvent devenir énergie, cartes ou Force ; des cartes peuvent devenir blocage, pioche, énergie ou rafale ; le blocage peut devenir dégâts sans être consommé. Ces conversions forment un réseau. Exemple : Power Through apporte deux Wound en main et beaucoup de blocage ; Second Wind convertit ces Wound en blocage ; Feel No Pain valorise chaque épuisement ; Dark Embrace recharge la main. Chaque brique a aussi un usage partiel sans tout le réseau.

Evolve et Fire Breathing se déclenchent à la **pioche** ; Feel No Pain et Dark Embrace à l’**épuisement**. Mettre directement deux Wound en main ne déclenche donc pas les premiers. Cette séparation évite de confondre les moments de valeur. Corruption permet de dépenser très vite les compétences : c’est une accélération et un compte à rebours. La décision porte sur le moment où l’on renonce aux futurs cycles.

### Silent : faire circuler et préparer une fenêtre

Le poison inflige sa valeur au début du tour de la cible, puis perd une pile ; son cumul porte sur l’intensité. Une application plus forte augmente le dommage du prochain tic **et** le nombre potentiel de tics. Catalyst multiplie la réserve, Burst répète cette multiplication. Une purge ou une mort avant l’échéance réduit la valeur réelle. [Poison](https://slay-the-spire.fandom.com/wiki/Poison), [Catalyst](https://slay-the-spire.fandom.com/wiki/Catalyst).

Le paquet Shiv est un paquet de **déclencheurs** autant qu’un paquet de dégâts : chaque jeton constitue une attaque, une carte jouée et un épuisement. Finisher compte les attaques jouées ; Envenom compte les impacts retirant des PV ; Accuracy ne renforce que Shiv. Ces dimensions ne se remplacent pas.

Défausser sert à choisir, financer, piocher, réduire un coût et rendre une condition vraie. Reflex et Tactician isolés sont pourtant des cartes mortes. Well-Laid Plans assemble progressivement une fenêtre sans exiger de trouver toutes les pièces dans le même tirage. Wraith Form achète le temps d’exécuter ce plan tout en dégradant l’avenir.

### Defect : une file de production

| Orbe | Passif de base | Évocation de base | Focus |
|---|---|---|---|
| Foudre | 3 dégâts aléatoires en fin de tour | 8 dégâts aléatoires | Ajoute sa valeur aux deux effets ; Electrodynamics change les cibles. |
| Frost | 2 blocage en fin de tour | 5 blocage | Ajoute sa valeur aux deux gains, avec plancher utile à zéro. |
| Ténèbres | Charge les dégâts de 6 par fin de tour | Dépense la charge sur l’ennemi ayant le moins de PV | Modifie la croissance du passif ; ne rajoute pas une seconde fois Focus à toute la charge stockée. |
| Plasma | 1 énergie au début du tour | 2 énergie | Aucun effet. |

Canaliser remplit le premier emplacement libre ; sans place, le prochain orbe est évoqué pour faire de la place. Loop active le passif du prochain orbe ; Dualcast évoque le même orbe deux fois ; Recursion le recanalise et conserve notamment la charge d’une Ténèbres. Fission normale supprime sans évoquer ; Fission améliorée récupère la valeur d’évocation. [Orbes](https://slay-the-spire.fandom.com/wiki/Orbs), [Focus](https://slay-the-spire.fandom.com/wiki/Focus), [évocation](https://slay-the-spire.fandom.com/wiki/Evoke), [Recursion](https://slay-the-spire.fandom.com/wiki/Recursion).

La vraie ressource est donc le triplet **contenu de la file, ordre, capacité**. Ajouter des emplacements augmente le potentiel passif mais retarde les sorties ; Consume renforce les emplacements restants mais peut diminuer la production totale (M22/M23). Hyperbeam et Reprogram ouvrent une autre voie, qui peut garder Plasma tout en abandonnant les autres orbes.

### Watcher : choisir quand un multiplicateur est acceptable

| Posture | Entrée / sortie | Pendant la posture |
|---|---|---|
| Neutre | Aucun bonus intrinsèque | État sans multiplicateur. |
| Calm | Sortir donne 2 énergie | Pas de multiplicateur d’attaque. |
| Wrath | Entrer peut activer Rushdown | Attaques infligées et reçues ×2. |
| Divinity | Entrer donne 3 énergie ; sortie automatique au début du prochain tour | Attaques infligées ×3, sans le doublement des attaques reçues de Wrath. |

On ne cumule pas les postures. Passer de Calm à Divinity donne le bénéfice de sortie de Calm puis celui d’entrée en Divinity. Dix Mantra déclenchent Divinity en consommant dix ; Brilliance conserve la valeur historique gagnée. Revenir à la même posture ne compte pas comme changement. Quitter une posture vers neutre compte bien pour Mental Fortress et Flurry of Blows. [Postures](https://slay-the-spire.fandom.com/wiki/Stance).

Le texte dans l’ordre est crucial : Eruption et Tantrum frappent **avant** d’entrer en Wrath ; Empty Fist frappe **avant** d’en sortir. Le haut potentiel de dégâts récompense l’assemblage d’une fenêtre sûre. Pressure Points illustre une voie moins connectée : sa marque fonctionne hors attaques, avec peu de bénéficiaires dans le reste du kit.

## 5. Artefact, dettes et exceptions

Artefact annule une application de debuff et dépense une charge. Deux malus appliqués par la même carte peuvent consommer deux charges : poison et marque de mort de Corpse Explosion, Faible et Vulnérable de Shockwave. La quantité d’un malus ne correspond pas au nombre de charges consommées. Une baisse de Force temporaire et sa restitution sont deux effets séparés ; supprimer l’un sans l’autre change le bilan.

L’ordre permet aussi des avantages : Artefact **avant** Biased Cognition peut bloquer le debuff Bias et laisser le Focus acquis ; avant Flex il peut empêcher le futur retrait de Force. La dette de Blasphemy est classée comme un buff dans le jeu : Artefact et Orange Pellets ne constituent pas une annulation ordinaire. Le très gros dégât du début de tour peut être survécu par des protections spécifiques, à condition qu’elles soient actives à cette échéance ; un Intangible qui expire avant ne suffit pas. [Clockwork Souvenir](https://slay-the-spire.fandom.com/wiki/Clockwork_Souvenir), [Blasphemy](https://slay-the-spire.fandom.com/wiki/Blasphemy).

Cette profondeur comporte un coût de lisibilité. Pour Catabase, une dette volontaire doit annoncer sa catégorie, son échéance et ce qui peut la bloquer. Copier une exception invisible parce qu’elle existe dans un jeu reconnu n’est pas une justification de conception.

## 6. Contre-jeu : tester le moteur, pas seulement les PV

| Épreuve adverse | Ce qu’elle vérifie | Réponses possibles |
|---|---|---|
| Gremlin Nob, Enrage | Le joueur dépend-il trop de compétences lentes ? | Attaques efficaces, potions, accepter un coût défensif ponctuel. |
| Sentries et statuts | Le moteur traverse-t-il des pioches encombrées ? | Zone, première mort rapide, épuration, Evolve, défense sans pioche parfaite. |
| Byrds, Flight | Le joueur peut-il fournir plusieurs impacts ? | Rafales, riposte, sources hors attaques ; tous les dégâts bruts ne sont pas équivalents. |
| Snake Plant, Malleable | La rafale déclenche-t-elle de plus en plus de blocage ? | Changer la granularité des attaques, poison, planifier le passage de protection. |
| Spikers, Thorns | La production de petites attaques coûte-t-elle trop de retours ? | Blocage préalable, dégâts hors attaques, moins d’impacts. |
| Awakened One, Curiosity | Les pouvoirs supplémentaires valent-ils leur sanction ? | Installer les essentiels, différer les autres selon la phase, gagner avec les outils déjà posés. |
| Time Eater, Time Warp | Le joueur sait-il finir son tour au bon compteur ? | Préparer les séquences autour de 12 cartes ; le compteur se prolonge d’un tour à l’autre. |
| Corrupt Heart | Le moteur protège-t-il pendant qu’il fonctionne et sur plusieurs tours ? | Blocage associé aux actions, réponses aux rafales et au gros coup ; plafond de pertes de PV empêchant une victoire en une seule fenêtre. |

On ne prétend pas livrer ici leurs fiches complètes par Ascension. Ces adversaires montrent pourquoi une carte peut être utile dans un contexte et mauvaise dans un autre. [Boucles infinies et leurs contres](https://slay-the-spire.fandom.com/wiki/Infinite_Combo), [Heart](https://slay-the-spire.fandom.com/wiki/Corrupt_Heart), [Time Eater](https://slay-the-spire.fandom.com/wiki/Time_Eater).

## 7. Ce qu’un inventaire automatique ne suffit pas à certifier

La source brute contient 146 entrées de pouvoirs internes et 48 mots-clés, mais aussi des descriptions tronquées, des doublons fonctionnels et des éléments retirés : `TODO`, `Opener`, ancien `Live Forever`, etc. **Ce n’est pas une liste de 146 effets actuels certifiés.** Les effets des cartes jouables sont couverts par les contrats reformulés ; les pouvoirs ennemis et de reliques sont abordés lorsqu’ils expliquent ces cartes. L’audit exhaustif des 181 reliques ou de toutes les IA n’est pas le périmètre de cette livraison.

Restent à reproduire dans le client si une transposition dépend précisément d’eux : ordres complets de fin de tour, débordements de main lors des générations imbriquées, duplication au passage du douzième compteur de Time Eater, morts simultanées, choix de cible après une première mort, et conservation de toutes les propriétés lors d’une copie. Le rapport ne déduit pas une certitude sur ces cas d’une simple ligne de texte.
