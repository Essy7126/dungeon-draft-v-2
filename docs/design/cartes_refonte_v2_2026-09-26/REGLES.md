# Contrat de règles — Cartes V2

Version `2.0.0-design.1`, profil `catabase_cards_consumable_v2`. **Contrat prêt à implémenter ; coefficients provisoires, pas version jouable validée.** Le [manifeste](manifest.json) contient les 48 familles, les quatre classes, huit spécialisations, 18 équipements, huit reliques, courbes et tables économiques. Ce document fixe leur ordre et leurs limites. Un conflit entre texte et manifeste doit être résolu avant le portage, jamais par un choix silencieux du développeur.

## 1. Run, identité et préparation

- Une run solo de 20 profondeurs, 12 rencontres et huit haltes ; personnage niveau 1, 40 or, sans équipement initial.
- Un profil de difficulté Standard V2 pour cette première mise en place. Aucun multiplicateur des difficultés historiques n'est appliqué à ces courbes. Les anciens choix restent disponibles pour leurs profils ; de nouvelles difficultés V2 nécessiteront leur propre calibration.
- 15 copies normales au départ, librement choisies parmi huit communes et quatre normales de la classe ; trois copies maximum par famille. Les cinq familles × trois constituent les presets, pas une contrainte de création.
- Quatre classes, deux spécialisations par classe. Spécialisation définitive au niveau 4. **Passif de classe et spécialisation coexistent**, avec compteurs distincts. Cette règle remplace la substitution actuellement utilisée dans Godot, uniquement pour V2.
- Les caractéristiques, équipements, reliques et améliorations restent acquis pendant la run. Aucun transfert de puissance, d'or ou de cartes entre runs ; seules les découvertes et les résultats demeurent.
- Réserve sans plafond arbitraire ; deck préparé de 0 à 30 copies, trois maximum par famille. Une préparation vide est sauvegardable ; partir avec elle affiche les conséquences et reste possible.
- Composition et équipement modifiables uniquement hors combat. Une copie en réserve ne rejoint jamais un combat commencé.

## 2. Vie d'une copie et accès au plan

Chaque exemplaire a un UID stable, un `family_id`, une origine (`initial`, `loot`, `purchase`, `trade`) et son reçu d'acquisition. Les améliorations appartiennent à la famille, pas à l'UID.

Lors d'une résolution légale et engagée, la copie est retirée de la main et devient **consommée pour toute la run**. Elle ne retourne pas dans la défausse. Une cible valide qui absorbe tous les dégâts consomme bien la copie ; une annulation ou une action illégale ne consomme ni copie, ni PA, ni limite de famille.

Les zones actives `main/pioche/défausse` sont disjointes. `deck_prepared` est une sélection d'UID, pas une quatrième zone physique. Après combat, les copies survivantes restent sélectionnées si elles l'étaient ; les UID consommés en sont retirés. Un journal compact conserve les consommations sans rendre ces UID jouables.

Avant le combat, le joueur peut désigner **une copie normale préparée** pour l'ouverture. Elle occupe un emplacement de main. Les autres sont tirées sans remise ; aucune duplication ni réduction de PA. Une référence devenue invalide est retirée explicitement, sans substitution automatique vers une rare.

Main remplie jusqu'à cinq au début de chaque tour, modifiée par équipement, plafond sept. Les cartes inutilisées vont en défausse en fin de tour ; la pioche vide remélange la défausse. Les cartes consommées ne reviennent jamais. Limite : une carte par famille et par tour, quelles que soient les copies en main.

L'amélioration de Garde brève permet de retenir une autre carte jusqu'à la prochaine transition. Une seule copie retenue ; elle occupe une place parmi les cinq et ne réduit pas son coût. Ce choix est facultatif. L'effet remplace le supplément de garde de l'ancienne amélioration. Aucun filtrage commun supplémentaire n'est ajouté à cette version.

## 3. Tour, PA, PM et gestes de secours

Quatre PA, trois PM de base ; PM maximum borné entre 1 et 5 par l'équipement. Aucun report global. Attaque de secours à 1 PA : 0,28 P physiques au contact. Garde de secours à 1 PA : 0,25 P. Chaque geste une fois par tour, hors pioche et sans consommation.

Les secours ne déclenchent pas les passifs d'impact direct de carte, les marques, les récompenses de mise à mort ni le vol de vie. La garde de secours peut absorber une attaque et déclencher le renvoi du Gardien.

Ordre d'une ronde : début du héros → actions du héros → activations ennemies dans l'ordre stable affiché → résolution de salle → pression → vérification de fin. Mort du héros : défaite, y compris simultanément au dernier ennemi. Dernier ennemi mort avec héros vivant : victoire immédiate avant la pression.

Début du héros : expirer l'ancienne garde → appliquer la garde différée d'Urne → réinitialiser les compteurs de ronde → PA/PM → mémoriser la case d'ancre → remplir la main. Les ressources de fin de combat ne se réinitialisent pas lors d'une transition de phase du boss.

## 4. Déplacements et résolution

Distances de Manhattan, déplacements orthogonaux. Marche : un PM par case libre. Déplacement de carte : PA et copie, pas de PM. Téléportation : traverse les obstacles, destination libre. Permutation : deux unités valides, boss exclus. Un boss ne subit qu'une case de déplacement forcé par effet.

« Cases parcourues » : somme des cases de marche volontaire et des déplacements volontaires de carte ; une téléportation de carte compte sa distance de Manhattan. Déplacements subis, permutation et retour d'Ancre exclus. Les seuils sont évalués avant l'impact de la carte concernée. Les retours à pied peuvent compter mais ne créent aucun remboursement ; chaque déclencheur conserve son plafond.

Les poussées/attractions suivent l'axe dominant, horizontal en cas d'égalité. Mur, unité et bord arrêtent le mouvement. Choc de masse n'accorde sa garde que si le déplacement demandé rencontre réellement un **mur ou obstacle fixe**. Un bord, une unité, une immunité ou le plafond de déplacement du boss ne qualifient pas.

Visée selon le service commun de ligne de vue. Les maps V2 de référence doivent reproduire les mêmes cellules légales que les fixtures 7 × 7. La vapeur bloque la vision ; ne pas copier le Bresenham simplifié du laboratoire si cela diverge du moteur. Toute divergence restante doit être arbitrée par une fixture explicite avant publication.

Pluie de pointes : axe dominant lanceur–centre, égalité horizontale ; la ligne de trois cellules est perpendiculaire à cet axe et centrée sur la case choisie. Retirer les cellules hors grille, solides ou sans ligne de vue depuis le lanceur ; une unité n'est touchée qu'une fois. Pour Convergence, résoudre les attractions par distance croissante au centre puis UID ; une case occupée bloque le déplacement concerné sans annuler les autres.

Ordre d'une carte : validation complète des choix et du coût → engagement atomique PA/copie/usage → capture des conditions avant impact → effets ordonnés → morts et effets autorisés → déplacements → terrain → pioche → choix secondaire éventuel → journal et checkpoint. Exceptions explicites : Convergence attire avant son impact ; Répercussion prélève avant son impact ; le retour d'Ancre est une commande séparée. Aucun contrôle d'entrée ne peut engager une seconde action pendant une résolution.

## 5. Dégâts, garde, états et arrondis

P = puissance du héros après ses caractéristiques. Les formules PV/P/résistances et les courbes de niveau sont celles du manifeste. Bonus d'une même étape additifs ; étapes différentes multiplicatives. Ordre : effet de carte/condition → bonus d'équipement → bonus de classe/spécialisation → marque existante → résistance → garde → PV. Soin sur PV réellement manquants ; drain sur PV effectivement retirés, sans sur-dégâts.

**Godot conserve des valeurs entières.** Arrondir à l'entier le plus proche, `.5` vers le haut, une seule fois par quantité finale de dégâts, garde ou soin. Les facteurs internes restent réels. Appliquer ensuite le stock entier de garde puis les PV. La prévision utilise la même fonction que la résolution. Les résultats flottants de V1 ne sont pas des valeurs de mort autoritaires dans V2.

Garde plafonnée à 2,5 P après conversion en entier, expiration au début du prochain tour du héros. « Garde absorbée » compte seulement les points réellement dépensés contre une attaque ; expiration et sacrifice n'en font pas partie. La résistance physique et la résistance magique sont distinctes, chacune plafonnée à 40 %. Le percement ignore la résistance concernée, pas la garde.

Marque : bonus au prochain impact direct de carte sur cette cible ; maximum entre marques concurrentes, jamais addition. Durée ordinaire deux phases ennemies. Une carte qui frappe puis marque consomme d'abord l'ancienne marque, puis pose la nouvelle. Capturer son existence et sa valeur avant le coup pour les conditions et le Relais.

Brûlure magique et saignement physique sont deux statuts distincts. Pour chacun : applications non additives, conserver le tic le plus fort et la durée la plus longue. Ils peuvent coexister. Tics au début de l'activation de la victime ; ne déclenchent pas les passifs de carte ou récompenses d'élimination directe.

Entraves non additives : conserver la réduction la plus forte. Le gel V2 est une entrave de 1 PM, pas un étourdissement. Faiblesse, stase, anti-létal et soins extraordinaires gardent les contrats V1 : un Décret protège un impact, la stase interdit son renouvellement pendant trois activations et devient affaiblissement sur boss. Pression exclue de l'anti-létal.

## 6. Contrats des moteurs de classe

### Assassin

Passif : premier impact direct contre une cible sans allié adjacent avant le coup, +0,25 P ; une fois par ronde. Exécuteur conserve son bonus V1. Le Relais remplace la spécialisation Embusqué dans ce profil.

Relais : première élimination directe d'une cible portant une marque non issue d'un relais. Après résolution complète de la carte, choix optionnel d'un ennemi à deux cases ou moins de la victime, sans ligne de vue exigée. Marque transmise : `min(valeur capturée, 0,20 P)` ; expire à la **fin de la prochaine activation du héros**, même si aucune phase ennemie n'a eu lieu entre-temps. Elle ne se retransmet pas. Plusieurs morts dans une zone : seule la première cible éligible par ordre stable des UID ouvre le choix. Refuser ou ne trouver aucune cible ferme le déclencheur de cette ronde.

### Gardien

Premier coup adverse dont la garde absorbe au moins un point : renvoi 0,25 P physique après le coup, uniquement si le héros vit encore. Une fois par ronde ; aucun renvoi récursif ni récompense de mort directe. Bastion augmente de 25 % la première garde de carte ; Percuteur conserve son supplément de 0,25 P sur la première poussée effectivement réalisée. Ils possèdent leur compteur propre.

Répercussion : choix de S entre zéro et `floor(min(garde actuelle, 0,80 P))`, en points entiers ; l'interface peut proposer 0/25/50/75/100 % du maximum et un réglage précis. Dégâts bruts `0,70 P + 1,50 S`. La garde sacrifiée n'alimente ni Urne ni Dette du bronze. L'amélioration donne une portée de quatre, aucun supplément de dégâts. Le champ technique `guardSacrificeStep` n'est qu'un pas d'affichage proportionnel, jamais une contrainte de paiement fractionnaire.

### Arpenteur

Ancre remplace le +1 PM de classe. Après un impact direct de carte à distance au moins trois, le retour devient disponible jusqu'à la fin du tour. Il coûte 1 PM, une fois, vers la case de début de tour si libre et à trois cases ou moins. C'est une téléportation volontaire ; effets d'arrivée ordinaires, mais aucune contribution aux compteurs de mouvement. Si l'arrivée devient illégale, la commande reste indisponible sans coût.

Tireur garde son bonus à longue portée. Escarmoucheur pioche après la première carte offensive résolue avec deux cases parcourues ; garde et déplacement seuls ne qualifient pas. Cette pioche peut s'ajouter à Tir de relais, mais chacune est bornée et la limite de main s'applique dans l'ordre carte puis spécialisation. Ni copie ni PA rendus.

### Thaumaturge

Premier statut direct admissible **ou** première vraie transformation de surface : +0,20 P de garde, un compteur partagé. Une simple pose d'eau, un rafraîchissement ou un tic ne qualifient pas. Pyre conserve le +0,10 P par tic à la première brûlure directement posée du tour et Frost sa garde sur la première entrave directe, selon les contrats V1 du catalogue. L'effet de Pyre est attaché à cette brûlure pour tous ses tics ; il n'ajoute pas un déclenchement par tic.

## 7. Surfaces : un profil branché sur le service existant

Deux groupes de surfaces créées par le héros actifs au maximum ; une nouvelle pose retire le groupe le plus ancien, UID en dernier départage. Une transformation conserve le groupe de sa cellule ; elle ne crée pas une troisième place. Terrain permanent de la map jamais supprimé. V2 ne transforme que les cellules dynamiques admissibles du combat ; les surfaces ennemies ont une provenance propre.

Onde du Léthé pose l'eau deux phases après son impact en croix. L'eau seule n'inflige rien. Trait de givre frappant une cellule d'eau y demande une entrée glace : glace deux phases, entrave de 1 PM au début d'activation d'un ennemi présent. Braise tenace y demande une entrée feu : vapeur une phase, bloque la vision sans dégâts. Améliorations : glace trois phases, vapeur deux. Résolution de l'impact avant changement de visibilité.

Les sorties `feu+eau=vapeur`, `glace+eau=glace`, `feu+glace=eau` viennent de `TerrainInteractionResolver`. Aucun second résolveur parallèle. L'adaptateur V2 fournit durée, effets, propriété, compteur et prévision ; il ne modifie pas les définitions partagées de terrain ni les comportements des anciens profils.

Bûcher et Jardin conservent leur croix et durée du catalogue. Chaque cellule n'a qu'une surface dynamique résultante ; aucun cumul de deux feux sur la même cellule. Feu : dommage de sa source une fois au début d'activation d'une unité présente, deux camps ; glace : entrave ennemie. L'entrée dans la cellule n'ajoute pas un second tic V2. Durées décrémentées en fin de phase ennemie, après tous les acteurs ; une vapeur d'une phase couvre donc la phase adverse qui suit sa création.

## 8. Économie et progression

Les tables V1 sont conservées pour isoler les changements de combat : sept canaux indépendants par mort initiale éligible, premier sac de deux normales garanti, 70 % du tirage dans le groupe communes+natives et 30 % étrangères. Les 48 familles et leurs raretés sont conservées : **le changement de contenu ne dilue pas les pools**.

Butin déterminé avant le combat avec un flux RNG propre ; révélé après victoire. Invocations, transitions de boss et porteurs sacrifiés ne créent aucun drop. Défaite : aucune acquisition. Le boss clôt la run ; pas de butin consommable sans usage après la fin.

Cinq marchands, stocks finis persistants : deux sacs de six normales à 36 or ; un exemplaire de chaque normale commune/native à 8 ; deux trocs de trois normales contre une normale choisie ; soin 30 % à 25 ; réaffectation d'amélioration familiale à 35. Le reçu indique les trois UID détruits au troc. Réouverture et rechargement ne renouvellent aucun stock.

Les achats ciblés sont présentés dans le parcours principal. Le joueur peut suivre deux familles : le suivi affiche possédé/préparé/disponible chez le marchand ; il ne commande pas d'achat et ne bloque pas une vente. Équipement et reliques n'ont pas de revente. Tous prix, taux et restrictions se trouvent dans le manifeste.

Niveau maximum 12 ; points de caractéristiques aux niveaux 2/4/6/8/10/12 ; améliorations de trois familles distinctes aux niveaux 4/8/12. Points différables. Le niveau augmente les PV actuels du gain de PV max ; équipement conserve la proportion de santé. Les upgrades affectent les copies présentes et futures. Aucun ancien budget de maîtrise ou perfectionnement ne se superpose.

## 9. Salles et pression

P de rencontre = puissance de base du niveau ennemi, indépendante du héros. La version de référence utilise la géométrie 7 × 7 du manifeste ; le port visuel Studio doit produire cette même géométrie jouable.

| Salle | Règle fermée |
|---|---|
| Presse / forge | Après ennemis, ligne 1/3/5 cyclique ; 0,60 P de rencontre au héros, 1,30 P aux monstres. Levier à 1 PA pour choisir la ligne ; une fois par tour. |
| Jardin | Anneau autour du premier ennemi vivant par ordre de spawn ; rayons 2/3/1 ; 0,60 P physique. |
| Convoi | Deux porteurs désignés ; progression vers le relais. Arrivée : sacrifice, chef +0,80 P PV actuels/max et +2 % PVbase en ATK. Sceller à 2 PA annule leur objectif. |
| Sablier | Croix de portée deux ; 0,70 P physique ; différer coûte 1 PA, prochaine explosion ×1,5, impossible de différer deux fois la même dette. |
| Réservoirs | Stocke PA restants à proximité, plafond six. Ennemi proche vole une charge et se soigne de 0,30 P. Décharge à 1 PA : 0,50 P par charge sur le premier ennemi vivant ; vide. |

À partir du tour 9, après les ennemis/salle : perte `2,5 % PV max × (tour−8)`, sans garde/résistance/anti-létal. Prévision du prochain montant permanente dès le tour 8. Tour 24 encore actif : défaite par expiration. Ces paramètres restent ceux du témoin V1 pour la première implémentation ; ils sont un point de calibration prioritaire après observation humaine, pas un engagement de difficulté finale.

## 10. Sauvegarde et fin

Sauvegarde V2 séparée, version de schéma 1, `ruleset_id` et version de contenu obligatoires. Reprise **après la dernière action entièrement engagée**, pas au début du combat. Un arrêt pendant les animations reprend l'état logique engagé sans rejouer les effets.

Checkpoint atomique après chaque action de joueur, chaque activation ennemie et chaque décision de récompense/marchand. Inclure RNG, ordre des acteurs, PV/PA/PM, zones de copies, consommations, états et leurs sources, compteurs, terrain, mécanismes, phase de boss, intentions engagées, choix secondaire en attente et reçus. Le détail technique est dans [INTEGRATION.md](INTEGRATION.md).

Une ancienne run conserve son fichier et son résolveur ; aucune conversion silencieuse de son inventaire. Nouvelle partie Cartes utilisera V2 après les validations prévues. Classique demeure dans son profil. Victoire, défaite et abandon clôturent l'économie de la run et enregistrent les découvertes, sans puissance transférée.
