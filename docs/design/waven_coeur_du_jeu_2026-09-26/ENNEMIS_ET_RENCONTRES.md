# Ennemis : ce qui oblige le build à changer de plan

Les pages complètes de [La Piscine](https://waven.fandom.com/fr/wiki/La_Piscine) et du [Collecteur](https://waven.fandom.com/fr/wiki/Le_Collecteur) ont été lues dans le navigateur. Leur version n'est pas datée de façon fiable : les règles ci-dessous sont des relevés communautaires à confirmer dans un client donné. Aucun chiffre de DOFUS ou de WAKFU n'est utilisé pour combler les lacunes de WAVEN.

## 1. Sept ennemis, des contraintes différentes

| Ennemi | Règle documentée | Conséquence tactique que j'en tire |
|---|---|---|
| Odaim | Début sans ennemi autour : armure alliée égale à 50 % de son ATK. | Aller au contact peut économiser plus de dégâts futurs qu'une attaque immédiate. |
| Écurouille | Attaqué : Gland posé ; devient un Chêne soigneur. Le Gland peut être déclenché/détruit par occupation. | Les attaques dispersées préparent une dette de terrain ; déplacement et concentration des dégâts deviennent des réponses. |
| Kralamar | Trois Cartouches Encrées ; attaque ou sort sur un ennemi consomme une charge et provoque une riposte. | Plusieurs petites actions ne sont plus forcément préférables à une grosse. Le danger dépend de l'événement déclenché, pas seulement du dommage infligé. |
| Kironex | Diffuse Toxique ; laisse un Gel Hydrotoxique après sa mort. | Éliminer la source ne suffit pas à rendre sa zone sûre. La position du cadavre compte. |
| Fizall | Toxique augmente son ATK de 100 % ; peut se soigner lorsque le héros s'éloigne. | Il faut rompre une synergie tout en contrôlant la distance, pas simplement fuir. |
| Rarpie | +25 % ATK par autre rat ; attaquée, fait intervenir un autre rat sous condition spatiale. | Les petits ennemis sont des multiplicateurs de la menace centrale. |
| Rarpine | Traverse les adversaires alignés ; contraintes de case derrière la cible/bord ; Infection conditionnelle. | Un bord peut devenir une protection. La même géométrie n'a pas la même valeur contre un autre groupe. |

Sources des règles : [Le Collecteur](https://waven.fandom.com/fr/wiki/Le_Collecteur) et [La Piscine](https://waven.fandom.com/fr/wiki/La_Piscine). Les conséquences sont mon analyse ; elles ne sont pas des traces de combat exécutées.

## 2. Reconstruire une rencontre : La Piscine

Le relevé décrit Fizall avec deux Kironex. Les Flaques d'Eau permettent de rejouer déplacement et attaque lorsqu'on s'y arrête ; elles ne rendent pas de PA. L'ennemi peut aussi les exploiter. Toxique produit des dégâts proportionnels aux PV max de la cible. Les résidus des Kironex maintiennent une menace après leur mort. [Règles de la quête](https://waven.fandom.com/fr/wiki/La_Piscine).

**Mon analyse de la séquence.** Le tour se prépare en deux temps : chercher une chaîne d'attaques puis préserver une case de sortie. Consommer toutes les opportunités de frappe peut être inférieur à s'arrêter une attaque plus tôt dans une position sûre. L'existence du terrain n'est donc pas automatiquement un bonus : il crée aussi des cases dangereuses où terminer à proximité de l'ennemi.

Avec quatre rejouements disponibles et une attaque initiale, le budget atteint cinq attaques. Cela ne signifie pas cinq tours de sorts : aucun PA n'est récupéré par ce mécanisme. Une formule qui multiplie tous les dégâts du tour par cinq serait erronée.

Trois sources à 5 % des PV max représentent 15 % bruts : 300 pour 2 000 PV, 600 pour 4 000. Doubler les PV ne réduit pas cette fraction. Cela ne prouve pas que le dommage ignore toute protection ; cela montre seulement que le gain de PV seul ne résout pas la contrainte de position.

Le problème de décision est donc :

1. Déterminer quelles sources doivent être séparées avant la phase adverse.
2. Choisir où tuer pour que le résidu ne coupe pas la sortie.
3. Réserver une destination après la dernière attaque.
4. Éviter une fuite si longue qu'elle permet une récupération ennemie.

Ce type de rencontre évalue une compétence précise. Un bot qui ne valorise que dégâts et PV perdus peut ignorer le terrain persistant ou provoquer lui-même les rejouements adverses. Ses défaites ne suffisent alors pas à conclure que la classe manque de dégâts.

## 3. Trois formes de contre-jeu

### Supprimer une condition vaut parfois mieux que frapper

Dans un scénario où Odaim protège trois alliés, empêcher son déclenchement retire `3 × 0,5 × ATK = 1,5 ATK` d'armure distribuée. Ce total n'est pas équivalent à autant de dégâts instantanés : encore faut-il avoir prévu d'attaquer ces cibles avant disparition de la protection. Il fournit toutefois une valeur au contact et au déplacement forcé.

Un bon indicateur est donc l'**effet adverse évité**, avec sa date et ses bénéficiaires, et pas seulement le nombre de cases parcourues.

### Le nombre d'actions peut devenir un coût

Kralamar est un contrepoint aux héros qui rentabilisent une série de petits événements. Trois ripostes finies ne ressemblent pas à une taxe illimitée sur chaque carte. L'analyse doit vérifier ce qui vide les charges, leur éventuel renouvellement et l'acteur qui encaisse. Les textes lus ne donnent pas ici un dommage de riposte suffisamment sûr pour optimiser numériquement la séquence.

Pour Catabase, c'est une piste plus ciblée qu'un malus générique contre toutes les classes : un ennemi peut rendre temporairement coûteuse la multiplication des actions, à condition d'annoncer ses charges et d'offrir une réponse accessible.

### La composition crée la difficulté

Avec trois autres rats, la règle décrite de Rarpie donne `1 + 3 × 0,25 = 1,75` fois son ATK, avant autres effets. Retirer un soutien fait baisser la menace centrale en plus d'éliminer sa propre action. Une attaque de zone modérée peut ainsi économiser davantage de dégâts futurs qu'une grosse frappe sur le chef.

Les conditions de traversée des Rarpines montrent une autre dépendance : la qualité d'une case dépend du groupe rencontré. Le coin peut bloquer une manœuvre ennemie et, dans une autre salle, empêcher une sortie. Cette variabilité est une bonne source de profondeur si le joueur peut la prévoir.

## 4. Les notes de développeurs confirment l'importance de ces détails

La 0.23 corrige notamment le déclenchement des attaques adjacentes de Taure, des auras de Groin d'Acier en coopération et l'usage de sorts de clan en présence des membres concernés. Certaines rencontres passent à cinq monstres ; des quêtes obtiennent des points de reprise. [Ankama, 0.23](https://forum.waven-game.com/en/44-patchnotes-fr/6463-version-23-fr).

**Mon interprétation.** Ces correctifs touchent la règle réelle d'une rencontre : quels acteurs existent, qui réagit, combien d'événements sont créés, combien de préparation est perdue après un échec. Ils ne peuvent pas être résumés par une variation moyenne des PV des ennemis.

Les plans Bouftou crédités à Girmaqua montrent aussi des branches, conditions et compositions qui évoluent par palier. Ils servent à comprendre la structure d'un donjon, pas à attribuer des statistiques actuelles aux monstres. [Plans](https://wavendb.com/donjons).

## 5. Ce qui manque pour un audit quantitatif complet

Je n'ai pas trouvé de table suffisamment fiable des PV/ATK de chaque espèce à chaque niveau. Je ne fournis donc pas de faux nombre de tours pour tuer un boss ni de courbe de difficulté reconstruite à partir d'autres jeux.

Pour compléter proprement cette partie dans le client, la fiche minimale d'une rencontre serait :

| Donnée | Pourquoi elle est nécessaire |
|---|---|
| Version, mode, palier, solo/coop | Fixe les règles et le contexte de comparaison. |
| PV max, ATK, PM, protections de chaque acteur | Permet les seuils de mort et la menace de déplacement. |
| Passifs avec timing et limite | Évite de confondre « par attaque », « par cible » et « par tour ». |
| Plateau et cases de départ | Rend la séquence reproductible. |
| Ordre des événements et ressources avant/après | Permet de valider les chaînes étudiées dans les kits. |
| Durée réelle, pas seulement nombre de tours | Rend comparables farm, animation et temps de décision. |

Cette limite concerne les coefficients et la reproductibilité, pas l'existence de décisions identifiées dans les règles lues. Aucun de ces relevés manquants n'est présenté comme accompli.
