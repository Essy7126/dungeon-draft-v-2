# Catabase expérimentale — construire son chemin et son Achille

> **Cadre remplacé par la [V3 intégrée à Catabase](catabase_run_recomposable_v3.md).** Le prototype séparé de douze étapes est abandonné : départ canonique fixe, environ quinze combats et cinq haltes, dix nouvelles maps. Ce document conserve l'historique de conception.

**Cadre de conception V2 — 7 septembre 2026.** Ce document intègre le nouveau topo du propriétaire du projet. Il devient la référence de conception pour la run expérimentale et prend priorité sur les restrictions de la [proposition de kit V1](achilles_kit_recomposable_v1.md). L'[audit de l'existant](achilles_kit_audit_2026-09-07.md) reste une description du code examiné, pas de cette cible.

**Statut : prototype runtime implémenté.** La carte à douze profondeurs, le kit recomposable quatre à six sorts, les récompenses, la sauvegarde et l'écran d'expédition sont branchés dans le projet. Les concepts particuliers de hubs, salles spéciales, malus, mini-boss et boss restent à enrichir ensuite. Les paramètres chiffrés ci-dessous restent des hypothèses de premier playtest.

Le détail des contrôles reproductibles se trouve dans [`tests/expedition/README.md`](../../../tests/expedition/README.md). Les probes couvrent la topologie, la construction, la session, l'interface et une vraie victoire jouée dans une scène de combat.

## 1. La promesse du jeu

**Je prépare un Achille, je choisis les occasions de le faire grandir, puis j'adapte mon plan à ce que la descente me révèle.**

Le combat, le build et la carte doivent se répondre. Un choix de route engage les PV, les ressources et les capacités que le joueur possède maintenant, mais aussi celles qu'il espère obtenir. Un choix de sort change les chemins qu'il peut raisonnablement envisager. Une découverte peut justifier de changer de projet sans effacer toutes les décisions précédentes.

L'inconnue utile ressemble à : « Cette branche me donne un apprentissage élémentaire. Je ne sais pas lequel ; je sais que je devrai traverser un combat difficile avant de retrouver une occasion de récupération. » Le joueur raisonne avec des informations incomplètes dont il connaît les limites.

| Demande du propriétaire | Conséquence de conception |
|---|---|
| Choisir son parcours sur une carte | Vrai graphe de destinations et de connexions, avec branches, renoncements et convergences |
| Visibilité et incertitude | Distinguer informations certaines, indices et contenu inconnu ; permettre d'anticiper plusieurs étapes |
| Combats normaux/difficiles, hubs, spécial, caché, « ? » | Séparer la fonction réelle d'un nœud de ce que le joueur en sait |
| Builds spécialisés, hybrides, paris | Plusieurs moteurs de jeu viables, des interactions entre eux et des engagements explicites |
| Contrôle, mobilité, mêlée, distance, armure, PV, esquive, soin, éléments | Chaque axe doit changer une action ou une décision ; il ne suffit pas de lui attribuer un bonus de stat |
| Quatre sorts initiaux remplaçables ou améliorables | Collection de techniques connues distincte des techniques équipées |
| Possibilité de cinq ou six sorts et de cartes enseignant un sort | Capacité du kit évolutive ; apprentissage, mutation et emplacement supplémentaire sont trois récompenses différentes |

**Paramètres proposés, à tester :** douze étapes parcourues, sept à neuf combats, cinq emplacements au niveau 5, offre d'un sixième à l'étape VIII, dix points de maîtrise, six voies martiales et trois affinités élémentaires. Ces nombres ne sont pas des exigences déjà arrêtées par le propriétaire.

## 2. Ce qui change par rapport à la V1

- **Quatre emplacements deviennent le départ**, avec un plafond expérimental de six. Les quatre sorts initiaux restent remplaçables.
- **Dix à quinze salles désignent un parcours**, composé de combats et de destinations hors combat. Le nombre de nœuds dessinés sur la carte est supérieur au nombre visité.
- **Le plafond de deux doctrines est retiré.** Les points, les prérequis, les incompatibilités et les emplacements limitent le build. Investir dans trois directions doit être possible, avec un coût de profondeur.
- **Les nouveaux axes dépassent le seul kit martial V1.** PV, esquive, guérison et éléments deviennent des orientations à concevoir, avec leurs propres actions.
- **Rééquiper les sorts connus reste libre entre les étapes.** Le remboursement intégral de toutes les maîtrises avant chaque combat n'est plus la règle de la run expérimentale.
- **Le budget de douze achats à un point est remplacé.** La V1 ne permettait que sept acquisitions compatibles dans une doctrine : le spécialiste ne pouvait pas employer utilement ses douze points. Le nouveau modèle doit financer aussi bien une spécialisation qu'un mélange.

Les techniques déjà imaginées — Crochet, Heurt, Fauchage, Pas du chasseur, Rempart, Bond, Lance du retour — restent des candidats. Leur présence dans la V1 ne verrouille plus le catalogue complet du personnage.

## 3. La carte : comprendre ce que l'on choisit

### Une route de douze étapes, plusieurs futurs possibles

Premier format : douze profondeurs de carte, environ vingt-cinq à trente destinations proposées, généralement deux ou trois sorties aux carrefours. Une branche engage plusieurs étapes avant de retrouver une convergence. Quelques traversées communes portent les grands jalons. Le joueur ne peut pas visiter successivement toutes les options d'un embranchement.

Pour le premier prototype, un parcours résout exactement un nœud par profondeur. Une salle secrète révélée peut remplacer une destination de cette profondeur ; elle ne donne pas automatiquement une étape et une récompense supplémentaires. Dans le canevas de référence de la section 9, les remplacements secrets et les « ? » respectent les fonctions autorisées à leur profondeur : on ne supprime pas un combat fixe et on n'ajoute pas un combat en dehors des profondeurs prévues. D'autres canevas pourront répartir autrement leurs combats, avec un budget de parcours explicitement validé. Les véritables détours qui allongent la run appartiendront ensuite au format 10–15 étapes, avec leur prix et leur budget explicites.

Le nombre de combats, la profondeur, le nombre de nœuds visités et le niveau du héros sont des compteurs séparés. Un hub n'est pas un combat vide et une montée de niveau n'est pas un déplacement sur la carte.

### Quatre catégories d'information

| Information | Visible quand ? | Usage |
|---|---|---|
| Structure principale : connexions, grandes convergences, fin de parcours | Dès le départ, hors passages secrets | Se projeter et comprendre ce qu'un embranchement ferme |
| Nature/menace des prochaines destinations et famille de récompense annoncée | Généralement les deux prochaines profondeurs | Prendre une décision informée avec le kit et les PV actuels |
| Nature lointaine, services exacts, contenu d'une récompense | Selon indices, reconnaissance et proximité | Conserver une part d'incertitude et une valeur à l'information |
| Passages cachés | Après découverte ou indice suffisant | Ouvrir une possibilité nouvelle, sans obliger une connaissance externe arbitraire |

Les hubs et grands jalons peuvent être identifiables plus loin que les rencontres ordinaires. Leur existence visible ne révèle pas nécessairement tout leur inventaire. La fiche d'un chemin doit montrer la prochaine occasion **connue** de récupération, sans inventer une garantie quand elle n'existe pas.

Avant de confirmer un déplacement, afficher : destination, risque connu, récompense garantie ou famille garantie, coût immédiat éventuel, chemins rendus inaccessibles et prochain point de convergence. Inspecter n'engage rien. La carte ne désigne pas un chemin « optimal » à la place du joueur.

### « ? » et « caché » ne sont pas des contenus

Un nœud a une fonction réelle : combat, élite, hub, événement, cache, épreuve majeure, boss. Il a aussi un état de connaissance : révélé, partiellement connu, inconnu ou secret non découvert.

Un « ? » peut donc contenir un combat. Sa fiche indique le domaine du risque : « rencontre ou ressource, combat possible », par exemple. Une inconnue ne transforme pas secrètement une promesse de sécurité en combat létal obligatoire. Une option irréversible proposée dans un événement expose son prix avant acceptation.

Une salle cachée doit avoir plusieurs voies de découverte possibles au niveau du système : indice obtenu, choix d'exploration ou propriété de build pertinente. Aucun passage nécessaire à un build ne repose uniquement sur une combinaison secrète. Une fois découverte, la connexion reste connue ; une option encore verrouillée affiche la condition comprise par le joueur.

### L'incertitude ne doit pas changer derrière le joueur

Le contenu d'une destination est déterminé pour la run ; le révéler ne relance pas le tirage. Réouvrir la carte ou charger une sauvegarde conserve les inconnues et les informations déjà acquises. Les offres connues ne s'adaptent pas silencieusement pour contrer le build après son engagement.

Une récompense annoncée « apprentissage de contrôle » contient une option valide de cette famille ou sa conversion explicitement annoncée. Le nom précis peut être inconnu. Ce contrat permet de parier sur une famille sans exiger la certitude d'obtenir une carte exacte.

## 4. Les chemins doivent répondre au build

Chaque embranchement oppose des valeurs différentes : sécurité maintenant, qualité d'équipement, nouvelle technique, information, correction du build ou accélération d'un pari. Éviter une branche qui donne à la fois moins de risque, plus de soin et une meilleure récompense.

Trois décisions représentatives :

1. **Achille mêlée/contrôle, Garde rangée.** L'élite annonce une formation rapprochée et une récompense liée au placement. Le chemin normal garantit une protection plus modeste. Son combo Crochet/Fauchage rend l'élite attractive ; ses PV restants peuvent rendre le chemin normal préférable. La synergie ouvre une opportunité, sans supprimer le risque.
2. **Achille distance, tentation élémentaire.** Une branche conduit à un apprentissage élémentaire annoncé ; une autre approfondit les trajectoires et mène plus vite à un hub connu. Il choisit entre bifurcation et spécialisation, avec des conséquences visibles au-delà de la prochaine salle.
3. **Achille PV/soin, pari temporaire.** Un pacte propose une récompense connue après deux combats sans soin. Le joueur connaît le prix immédiat et les sorties possibles. Il peut refuser, accepter, ou renoncer ensuite au gain ; son personnage reste jouable sans gagner le pari.

Un build « pari » ne dépend pas d'un objet indispensable à 5 % de chance. Le pari porte sur une contrainte qu'on accepte ou sur l'intérêt d'une opportunité inconnue mais bornée. Un résultat médiocre doit permettre de continuer avec un plan moins ambitieux.

## 5. Quatre, cinq, puis éventuellement six sorts

### Règle recommandée

| Moment | Capacité | Fonction |
|---|---:|---|
| Départ | 4 | Faire sentir les premiers remplacements et sacrifices |
| Niveau 5 | 5 | Accueillir une nouvelle fonction ou conserver une réponse que le joueur aurait dû abandonner |
| Jalon VIII dans le format douze | Choix de passer à 6 | Opposer largeur du kit et transformation profonde d'une technique |

Le cinquième emplacement est garanti par le niveau, avec une progression minimale permettant de l'obtenir après IV sur chaque chemin normal. Aucun point de maîtrise n'est nécessaire pour l'ouvrir.

Pour le sixième, recommandation de prototype : une **offre de jalon accessible par tous les chemins** propose « +1 emplacement » ou une transformation structurelle d'une technique connue. Les options coûtent la même opportunité ; la mutation ne consomme pas en plus des points. Elle doit changer ciblage, cadence, réaction ou fonction, avec une éventuelle contrepartie. C'est une récompense de jalon identifiée et indépendante du budget : cette forme précise n'est pas aussi achetable dans l'arbre normal, et elle ne peut pas être remboursée contre des points. Le slot et cette transformation sont exclusifs pour cette offre. Leur puissance comparable reste à éprouver. Un simple +10 % dégâts n'est pas un concurrent crédible à un sixième bouton.

Cette offre est indépendante du contenu particulier du nœud VIII : le joueur ne doit pas choisir un unique hub pour avoir le droit à six sorts. L'interface distingue récompense de progression et récompense de destination.

**Alternative de secours à tester :** sixième garanti au niveau 9 si aucune mutation ne rivalise proprement avec l'emplacement. L'objectif est la construction du personnage, pas défendre un choix qui serait illusoire en pratique.

Conserver 6 PA et 3 PM de base pendant le premier essai. Les emplacements supplémentaires élargissent les réponses ; ils n'accordent pas automatiquement des actions supplémentaires. L'équilibrage des objets donnant des PA reste distinct.

### Ce que donne exactement une carte

| Carte ou objet | Conséquence | Lorsque les slots sont pleins |
|---|---|---|
| **Apprentissage** | Le sort rejoint la collection jusqu'à la fin de la run | L'équiper en remplaçant un sort ou le garder en réserve |
| **Mutation** | Une nouvelle forme de sort devient disponible, avec exclusions annoncées | Remplace sa forme dans le même slot |
| **Mémoire élargie** | Ouvre le sixième emplacement, maximum six | Aucun septième ; l'offre prévoit une alternative connue |
| **Équipement accordant une technique** | Technique disponible tant que cet objet reste équipé | Occupe un emplacement de sort normal ; le retrait de l'objet invalide ce droit |

La carte d'apprentissage est consommée et son savoir reste acquis pour la run. Un équipement n'enseigne définitivement un sort que si son effet le dit explicitement. Aucune attaque d'arme passive ou action cachée hors de la limite des slots n'apparaît par accident.

Mémoire élargie ne rejoint un éventuel pool exceptionnel qu'après l'ouverture du cinquième emplacement ; son acquisition est mémorisée. Si elle a déjà été acquise avant VIII, le jalon propose des options valides de même catégorie de puissance, sans cumuler un septième slot ni accorder une carte inutile.

### Six slots doivent rester disputés

Le catalogue découvert doit finir par offrir plus de techniques désirables que de places. Le parcours spécialiste ci-dessous n'enseigne que trois sorts en plus des quatre bases : sept connus pour six slots laisseraient très peu de sacrifices. Exiger donc, dans chaque chemin proposé, au moins deux occasions supplémentaires de découverte d'une technique avant VIII, avec une option compatible avec l'orientation choisie. Le joueur peut préférer leur alternative de mutation ou de ressource ; ce renoncement devient son choix. Les techniques précises restent inconnues tant que l'offre ne les révèle pas. Les quatre techniques initiales ne bénéficient d'aucune réserve permanente. Pas de raccourci gratuit pour garder Garde et Percée hors du kit.

Observer explicitement si le cinquième et le sixième servent toujours à remettre Garde et Percée. Si oui, il faut examiner les alternatives défensives, la nécessité imposée par les ennemis et les récompenses concurrentes. Augmenter artificiellement les coûts de tous les sorts pour rendre six slots pénibles ne résoudrait pas le problème.

## 6. Achille : six voies et des affinités qui se croisent

Les trois doctrines actuelles peuvent rester les portes d'entrée lisibles. Chacune expose deux voies ; les points ne ferment pas les autres doctrines. Les familles ci-dessous structurent le catalogue, sans devenir des classes obligatoires ou des kits prédéfinis.

| Doctrine / voie | Moteur de jeu | Exemples de techniques | Sacrifice et faiblesse |
|---|---|---|---|
| **Colère — Briseur** | Attirer, regrouper, frapper au contact, poursuivre | Crochet, Fauchage, Bond | Exposition de mêlée, faible rendement sur cibles dispersées |
| **Colère — Sang héroïque** | Investir des PV dans une fenêtre de puissance, reprendre une part des blessures sous conditions | Entaille sacrificielle, Défi mortel, Moisson vitale | Dette de PV réelle, sacrifice non récupérable gratuitement, risque de burst adverse |
| **Chiron — Chasseur** | Préparer les lignes, viser à distance, déplacer l'origine d'une attaque | Trait de rupture, Tir de traverse, Lance du retour | Ligne coupée, cible trop proche, préparation parfois perdue |
| **Chiron — Danseur** | Choisir une menace à éviter, changer d'appui, contre-attaquer | Pas du chasseur, Feinte, Contretemps | Défense ciblée et temporaire ; autres angles, zones et attaques multiples |
| **Éaque — Airain** | Réduire un impact, tenir un front, convertir protection et placement | Garde orientée, Heurt, Rempart | Flancs, attaques qui contournent la protection, coût de la conversion |
| **Éaque — Endurance** | Encaisser, choisir quand consacrer des PA à récupérer, gérer une réserve de soin limitée | Second souffle, Purification, Serment de survie | Moins de suppression de menaces, réserve finie, forte pression continue |

### Distinguer les axes voisins

**Armure** : empêcher une partie du dommage avant de le subir. **PV** : disposer d'une plus grande marge et pouvoir engager cette marge dans une action. **Soin** : réparer une blessure au prix d'un sort, de PA et d'une réserve. **Esquive** : éviter une attaque identifiée ou profiter d'une fenêtre de mobilité. Chacun doit permettre une construction dominante sans absorber gratuitement les avantages des trois autres.

Le contrôle traverse plusieurs voies : attirer, pousser, modifier un chemin, retirer une possibilité de déplacement, imposer une fenêtre de vulnérabilité. Les pertes complètes de tour ne doivent pas être la réponse standard à chaque menace, particulièrement avec un héros solo.

### Les éléments doivent pouvoir porter un build

Un catalogue commun d'affinités, accessible aux différentes doctrines, propose de vrais sorts élémentaires **et** des infusions de techniques. L'équipement les renforce ; il n'est pas leur unique porte d'entrée. Une orientation élémentaire annoncée comme principale doit recevoir son propre chemin complet de spécialisation ; sinon elle reste présentée comme une option d'hybridation jusqu'à ce que ce contenu existe.

| Affinité proposée | Nouveau problème tactique | Exemple de sort autonome | Exemple d'hybride |
|---|---|---|---|
| **Feu** | Pression différée et cases dangereuses | **Trait de braise**, 3 PA : projectile moins immédiat que Tir, pose une braise temporaire annoncée sur la case touchée | Crochet/Heurt amènent une cible vers une zone dangereuse ; le déplacement fait partie du combo |
| **Glace** | Contraindre une route et préparer un espace | **Entrave de givre**, 2 PA : faible impact et pénalité de déplacement temporaire bornée | Un Chasseur gagne une fenêtre de distance ; un Airain contrôle l'accès à son front |
| **Foudre** | Préparer une propagation dans une formation | **Arc fulgurant**, 3 PA : budget de dégâts partagé entre jusqu'à trois cibles reliées, chaque cible touchée une seule fois | Un Briseur rapproche les ennemis avant le sort ; une cible isolée reste moins rentable |

Ces exemples sont des pistes de catalogue avec coûts provisoires. L'élément conserve sa règle d'interaction et son type de défense explicites : « feu » ne signifie pas automatiquement « ignore l'armure ». Une infusion occupe une transformation du sort concerné, avec une contrepartie de dégâts immédiats, de coût ou de ciblage à définir. Elle ne se superpose pas sans limite à toutes ses autres mutations.

### Quelques actions nouvelles à préciser ensuite

- **Entaille sacrificielle, 2 PA** : annonce un coût en PV puis un impact de mêlée renforcé. Le paiement est refusé s'il tuerait Achille. Le sacrifice ne déclenche ni bonus de blessure ennemie, ni esquive, ni réserve de récupération issue de dégâts ennemis.
- **Moisson vitale, 3 PA** : dégâts de mêlée et récupération liée aux PV ennemis effectivement retirés, pas à l'overkill. Elle consomme la réserve de récupération du combat ; attaquer une invocation en boucle ne la recharge pas.
- **Feinte, 2 PA** : choisir un appui et une menace de mêlée frontale ; éviter la première attaque admissible jusqu'à la prochaine activation, avec une seule fenêtre de déplacement légale. Les zones, terrains et autres angles ne sont pas annulés. La prévisualisation définit précisément la couverture. Une activation de récupération est une hypothèse à tester.
- **Second souffle, 3 PA** : guérison limitée et annoncée, avec au plus deux usages par rencontre. Le slot et les PA consacrés au soin remplacent une action offensive ; le quota ne revient pas en changeant l'équipement.
- **Purification, 1 ou 2 PA à arbitrer** : retire une famille annoncée de malus, sans guérison universelle implicite. Ne justifie aucun passage imposant ce seul sort pour survivre.

Les réactions de ces nouvelles actions devront conserver les limites communes de fréquence et de déplacements de la V1, après revue des interactions avec soins et éléments. Aucun nom de sort n'est une promesse d'implémentation terminée.

## 7. Spécialiste, hybride et pari doivent tous fonctionner

### Le spécialiste

Il accède tôt à sa règle structurante puis l'approfondit. Sa faiblesse reste identifiable. Un spécialiste Endurance doit avoir de vrais choix jusqu'à la fin, sans être forcé d'acheter Chiron pour utiliser les derniers points.

**Budget total de run proposé : dix points**, avec coûts différenciés et sept acquisitions compatibles possibles dans une voie :

| Investissement possible d'un spécialiste | Coût total |
|---|---:|
| Deux apprentissages simples à 1 point | 2 |
| Une mutation structurante | 2 |
| Deux liaisons à 1 point | 2 |
| Une signature | 2 |
| Une légende | 2 |
| **Total** | **10** |

Les prérequis servent la cohérence du mécanisme, pas le remplissage de cases. Une voie n'est déclarée complète qu'après vérification de plusieurs chemins légaux de dix points, avec tous leurs sorts et effets utilisables : au moins deux mutations alternatives et deux aboutissements exclusifs doivent fournir des décisions internes au spécialiste. Un unique chemin qui achète tout ne suffit pas. Le coût deux d'une mutation se justifie par son changement de fonctionnement, pas par deux achats de +5 %.

### L'hybride

Il gagne une interaction entre deux mécanismes : attirance + foudre, esquive + contre, PV + récupération, écran + tir. Il retarde ou abandonne une partie de la profondeur d'une voie. Les emprunts à une troisième doctrine restent possibles ; le budget les fait payer.

Une jonction n'exige pas deux arbres complets. Proposition : une liaison d'un point avec deux investissements pertinents de chaque côté, et les techniques nécessaires connues. L'interface explique le combo avec les sorts réellement présents. Une condition impossible après un remplacement est signalée.

### Le pari

Il accepte une contrainte mesurable sur un horizon annoncé. Le pacte peut demander de limiter le soin pendant deux combats, de garder une capacité risquée ou de renoncer à un service en échange d'une récompense déterminée. Une sortie connue peut coûter la récompense ou une ressource ; elle ne détruit pas arbitrairement le build.

Le pari n'est pas réservé aux PV faibles. Il peut porter sur une préparation lente, une prédiction de trajectoire, un équipement à contrepartie, une route sans récupération immédiate ou une affinité moins polyvalente.

### Six constructions à viser en validation

| Construction | Noyau | Variante de fin de run | Risque à préserver |
|---|---|---|---|
| **Briseur** | Crochet + Fauchage + offensive de contact | Ajouter Heurt et Bond, garder ou retirer la Garde | Entrée ratée et formation qui se disperse |
| **Chasseur d'orage** | Tir + Pas + Arc fulgurant | Tir de traverse et contrôle pour préparer la chaîne | Encerclement et manque de cibles reliées |
| **Danseur** | Feinte + Pas + Contretemps | Distance courte ou contre de mêlée selon ses découvertes | Réponse à un angle, pas à tout le tour ennemi |
| **Forteresse** | Garde + Heurt + Rempart | Conversion offensive ou amélioration du maintien de position | Domine un front, doit encore gérer les flancs |
| **Sang et souffle** | Entaille sacrificielle + Moisson + Second souffle | PV élevés, récupération limitée, pari de puissance | Les auto-dégâts ne créent pas eux-mêmes de soin gratuit |
| **Maître des braises** | Trait de braise + contrôle spatial | Infusion de mêlée ou approche à distance | Pression différée, limites des zones et occasions de contact |

Ces noyaux ne remplissent volontairement pas tous les slots : les compléments doivent émerger de la route, de l'équipement et des préférences du joueur.

## 8. Statistiques et équipement : soutenir les choix

Le projet possède déjà Vitalité, Puissance, Résolution et Sagesse, ainsi que des statistiques runtime d'armure, résistance, esquive et critique. La première extension ne nécessite pas une caractéristique nouvelle pour chaque voie.

Conserver une Prouesse commune comme socle utilisable par les attaques physiques et élémentaires, puis différencier coûts, conditions et géométries. Le joueur qui découvre une technique de foudre ne doit pas devoir refaire toutes ses statistiques pour qu'elle fonctionne. Les coefficients de soin doivent emprunter un calcul partagé avec le combat et les aperçus ; ce raccordement n'existe pas encore comme celui des dégâts.

Surveiller trois cumuls : PV qui donnent à la fois toute l'attaque, toute la survie et tout le soin ; armure convertie en dégâts sans rien perdre de sa protection ; esquive presque permanente combinée à une récupération gratuite. Les caractéristiques doivent offrir des arbitrages, pas un investissement qui augmente tout.

Les objets peuvent combler une faiblesse, soutenir un mécanisme, enseigner conditionnellement une technique ou proposer un pari. Montrer l'effet sur le kit courant : « −Garde » n'est pas un sacrifice effectif pour un héros qui n'utilise aucune Garde. Aucun malus cosmétique ne doit faire passer un objet pour un risque réel.

Les techniques centrales d'une orientation restent accessibles par les apprentissages garantis. Les objets donnent des variantes, des accélérations et des exceptions ; l'objet parfait n'est pas nécessaire pour que la première moitié du build fonctionne.

Pour tester les mécaniques, comparer d'abord les héros à niveau et équipement égaux. La croissance actuelle jusqu'à 600 PV et 100 Prouesse au niveau 10 doit être recalibrée séparément pour la run longue ; elle n'est pas validée par ce document.

## 9. Cadence d'une run de douze étapes

L'expédition donne une progression minimale après la **résolution unique** d'une étape, qu'il s'agisse d'un combat ou d'une interaction hors combat. Une simple ouverture d'écran, un achat supplémentaire au hub ou une relecture d'événement ne donne rien. Les primes des élites récompensent surtout qualité, ressources et possibilités, sans devenir nécessaires pour obtenir les premiers slots.

Pour le premier profil expérimental, les seuils XP existants 100/220/360/520 peuvent servir de planchers cumulés après I/II/III/IV : niveaux 2/3/4/5 garantis sans Sagesse. Ces seuils sont cumulatifs : relever l'XP au plancher manquant ou attribuer les gains de référence 100/120/140/160, sans additionner 100 + 220 + 360 + 520. Si des primes de Sagesse ou d'XP restent activées, elles peuvent avancer le niveau 5 et son slot ; le plancher est une garantie minimale, pas une interdiction d'arriver plus tôt. Définir explicitement cette récompense d'expédition remplace le raisonnement actuel « seule une victoire accorde de l'XP ». L'XP de combat historique ne doit pas être ajoutée une seconde fois au même budget sans décision d'équilibrage. Désactiver aussi les anciennes attributions de points de maîtrise par niveau et les leçons achetables dans ce profil : les dix points ci-dessous sont l'unique financement en points de l'arbre.

| Étape | Fonctions possibles, à peupler ensuite | Progression du kit proposée |
|---|---|---|
| Départ | Choisir une orientation et inspecter les routes | 4 sorts, 2 points de maîtrise ; choix immédiat entre apprentissages à 1 et mutation à 2 |
| I | Combats normaux distincts | +1 point ; niveau 2 garanti |
| II | Combats normaux distincts | +1 point ; niveau 3 garanti |
| III | Combat normal/élite ou événement « ? » | Niveau 4 garanti et récompense de destination ; aucun point de maîtrise ajouté |
| IV | Combats avec pressions différentes | +2 points ; niveau 5 garanti, cinquième slot, signatures accessibles |
| V | Hub, spécial, cache | +1 point ; récupération, découverte ou correction du build selon route |
| VI | Épreuve majeure / mini-boss, contenu à concevoir | +2 points ; légendes accessibles |
| VII | Combat | +1 point ; budget total de dix atteint |
| VIII | Hub, spécial ou événement | Offre commune : sixième slot ou mutation majeure ; récompense de destination séparée |
| IX | Combat difficile ou événement à enjeu | Équipement, apprentissage de découverte ou pari |
| X | Combat | Éprouver la forme mûre du personnage |
| XI | Préparation, hub ou opportunité | Dernier ajustement ; pas de transformation indispensable réservée à cette étape |
| XII | Boss | Épreuve finale du personnage construit |

Ce canevas comporte sept combats fixes — I, II, IV, VI, VII, X, XII — et deux facultatifs en III et IX : **sept à neuf combats**. Une signature achetée après IV peut être jouée en VI, VII, X, XII, et éventuellement IX. Une légende achetée après VI peut être jouée en VII, X, XII, et éventuellement IX. Compter ces combats réels évite de confondre quatre dernières étapes et quatre occasions de jouer un sort.

Le total des points est `2 + 1 + 1 + 0 + 2 + 1 + 2 + 1 = 10`. Exemple spécialiste légal : deux apprentissages au départ, économie du point I, mutation après II, pratique du kit en III, signature après IV, première liaison après V, légende après VI, seconde liaison après VII. Autre départ possible : une mutation immédiatement, puis les deux apprentissages après I et II ; le budget avant IV reste identique. Ce calendrier donne de la profondeur tôt et du temps pour la pratiquer.

Les gates de signature/légende demandent également les techniques et investissements cohérents dans la voie ; les deux apprentissages plus la mutation suffisent au prérequis de signature dans le chemin ci-dessus. La légende demande sa signature. Un choix de branche ne doit pas empêcher d'obtenir les points garantis à ces jalons.

Les acquisitions de sorts offertes par une destination sont des récompenses supplémentaires **de répertoire**, pas des points automatiques permettant d'acheter tous les sommets. Leur rythme doit fournir une option de découverte ou d'amélioration régulièrement, sans imposer un nouveau bouton à chaque étape.

Pour dix étapes, resserrer les phases en conservant au moins deux vrais combats après la transformation finale avant le boss si le contenu le permet. Pour quinze, ajouter des occasions d'employer le build et des bifurcations ; ne pas augmenter automatiquement son budget de points ou son plafond de sorts. Les variantes seront calibrées après le premier parcours de douze.

Le nombre d'étapes ne fixe pas la durée. Mesurer combats, lecture des offres, carte et transitions séparément. Réutiliser les cartes existantes permet de construire vite le prototype ; ce n'est pas une preuve que la run sera courte à jouer.

## 10. Engagement, adaptation et récupération

### Les gestes toujours disponibles

Sur la carte, entre deux étapes et avant engagement : inspecter le personnage, rééquiper les sorts appris, choisir leurs formes déjà acquises, équiper les objets possédés, lire les incompatibilités et préparer son kit. Ces gestes ne dépendent pas de trouver un hub.

Après engagement dans une rencontre inconnue, la révélation n'offre pas un remboursement intégral permettant de reconstruire le héros en contre parfait. Le kit de combat est fixé avant son déploiement ; les contenus qui enseignent une technique avant une épreuve peuvent offrir un ajustement explicitement prévu. Les menus ne sont pas une manière de changer de kit au milieu d'un combat.

### Le rôle d'un hub

Un hub apporte des services finis qui peuvent justifier un détour : soin, réorientation, forge, information, offre spéciale ou autre concept à inventer. Ces services ne restent pas accessibles gratuitement après chaque combat en parallèle de la carte. Les gestes de base du kit restent accessibles partout entre les étapes.

Proposition : première correction d'une acquisition après son essai remboursable une fois dans la run ; ensuite réorientation via une occasion annoncée, avec budget et retrait cohérent des dépendances. Le remboursement restitue uniquement les points effectivement dépensés ; une technique ou transformation offerte ne peut pas être convertie en points gratuits. Le coût exact est à concevoir avec l'économie des hubs. Le laboratoire de développement peut conserver un respec libre, clairement distinct de la règle jouée.

Une route ne doit pas être invalidée faute de droit à ouvrir l'inventaire. À l'inverse, le hub perd son intérêt si tous ses services sont permanents. Cette séparation fait partie de la boucle centrale.

### Soin et esquive : deux axes qui demandent un contrat strict

**Soin :** pas d'attente infinie avec le dernier ennemi pour sortir automatiquement à 100 % PV. Proposition initiale à mesurer : soins produits par capacités et passifs partagent une réserve par rencontre, indexée sur les PV max à l'entrée ; base expérimentale de 20 %, pouvant être portée à 30 % par une vraie spécialisation. Les consommables et soins de destination restent des ressources finies distinctes. La réserve s'affiche dans les fiches concernées et ne se recharge ni par auto-dégâts, changement de max PV, équipement, invocation ni rechargement. Les sorts de soin peuvent réparer des blessures antérieures : une voie de guérison doit servir l'endurance de la run. Ses sorts ont aussi leurs quotas et coûts en PA.

Ce plafond est une hypothèse anti-boucle, pas un verdict d'équilibrage. Si la limite rend le soigneur frustrant, préférer un nombre fini de charges bien réparties et des coûts cohérents, tout en conservant l'impossibilité de produire du soin illimité. Le sursoin ne produit pas en retour une nouvelle réserve de soin.

**Esquive :** priorité à une protection choisie et lisible contre une attaque admissible, avec réaction et déplacement définis. L'esquive aléatoire existante peut être un complément statistique. Elle ne suffit pas à définir la survie du Danseur. Les attaques de zone, terrains et angles non couverts constituent des limites annoncées ; aucune immunité universelle implicite.

**Conversion :** un sacrifice de PV est un paiement, une perte de Garde est une consommation, une blessure ennemie est un dommage. Les trois événements ne sont pas interchangeables pour les déclencheurs. Cette distinction empêche plusieurs boucles auto-dégâts → soin → bouclier → dégâts.

## 11. Récompenses et information

Une offre structurante peut présenter trois directions : approfondir le projet actuel, ouvrir une bifurcation, conserver une ressource ou accepter une surprise bornée. Au moins une option doit être légale et utile au personnage ; les doublons ont une conversion explicitement annoncée.

La garantie de compatibilité ne doit pas générer exactement la même run à chaque choix de doctrine. Le joueur sécurise l'accès au moteur principal dans l'arbre ; la route distribue ses variantes. La variété concerne les solutions rencontrées et les occasions de les employer.

À la sélection d'une carte, montrer :

- ce qui est appris, transformé ou équipé ;
- coût éventuel, permanence jusqu'à la fin de run ou dépendance à un objet ;
- technique qui quitterait le kit si on confirme ce remplacement ;
- mutations et liaisons qui deviendraient inactives ;
- effet concret sur un tour, sur la survie ou sur les prochaines routes connues.

La carte doit afficher les garanties et les inconnues, sans estimer une probabilité de réussite qu'aucun modèle n'a mesurée. Une recommandation éventuelle est explicable par des faits — manque de soin, récompense de contrôle, présence d'un hub — et non par une note opaque de puissance.

## 12. Ancrage dans le projet actuel

Ces constats sont issus d'une lecture statique du dépôt, pas d'une nouvelle exécution moteur.

| Fondation | État actuel vérifié | Travail à prévoir |
|---|---|---|
| Parcours | [RunData](../../../data/runs/run_data.gd), ligne 41 : liste ordonnée de salles. [GameManager](../../../core/game_manager.gd), lignes 1039–1069 : incrément d'indice puis chargement | Graphe de destinations et navigation explicite ; garder le flux historique compatible |
| Types de nœuds | [Validation RunData](../../../data/runs/run_data.gd), vers ligne 86 : rencontre obligatoire en mode combat unique | Distinguer destination de carte et `RoomData` de combat ; hub/événement ne deviennent pas des combats vides |
| Choix du hub | [Archiviste](../../../hub/ui/archivist_panel.gd), ligne 105 : choix d'une salle de départ | Ne pas confondre ce sélecteur avec une carte de run |
| Camp | [ChampionCampService](../../../core/run_content/champion_camp_service.gd), lignes 8–28 : services transactionnels existants | Autoriser les services selon le nœud courant ; conserver l'accès au kit hors service marchand |
| Récompenses | [OdysseyRewardService](../../../core/run_content/odyssey_reward_service.gd), lignes 77–104 : offres seedées mémorisées | Graines indépendantes par instance de nœud et usage ; distinguer jalon garanti et butin de route |
| Emplacements | [SpellLoadoutState](../../../characters/progression/spell_loadout_state.gd), lignes 14–77 : connus/équipés, capacité à l'initialisation | Extension 4→5→6 en cours de run sans réinitialiser la collection ; UI/HUD, transactions et sauvegarde |
| Stats et éléments | [Spell](../../../data/spell.gd), lignes 7, 69, 87, 95, 127 ; [DamageResolver](../../../core/damage_resolver.gd), lignes 108–129 | Contenu Achille et règles d'interaction ; ne pas confondre présence d'un type avec build déjà jouable |
| Soin | [SpellScalingResolver](../../../core/spell_scaling_resolver.gd), ligne 40 ; [SpellCaster](../../../core/spell_caster.gd), vers ligne 987 | Le soin suit encore ses champs propres ; nouveau scaling partagé, quotas et provenance des blessures |
| Équipement | [ItemDefinition](../../../data/items/item_definition.gd), lignes 14–48 ; [modificateurs](../../../data/items/item_stat_modifier_data.gd), ligne 10 | Enseignement/technique conditionnelle et filtres des nouveaux sorts ; exposition homogène des résistances élémentaires |
| Persistance | [Snapshot actuel](../../../core/game_manager.gd), lignes 696–716 | Sauvegarde complète aux frontières de nœud : carte, seed, route, phase, révélations et kit ensemble |

Le moteur possède déjà dégâts physiques/magiques et éléments, soin, esquive aléatoire, poussée/attraction, boucliers et terrains. Leur simple présence ne valide pas les nouvelles orientations d'Achille. Le catalogue et les liens de progression restent à construire.

## 13. Contrat technique du futur prototype

Séparer les données de parcours des données de combat :

- `RunMapDefinition` : graphe et règles de génération ;
- `RunNodeDefinition` : identifiant, profondeur, contenu, connexions, récompense, politique de révélation ;
- `RunMapState` : instance de graphe, nœud courant, historique, accès secrets, révélations, offres et transactions ;
- profil de progression : jalons, niveau, points et droits d'emplacements ;
- collection/kit : sorts appris, emplacements ordonnés, mutations, liaisons et droits liés à l'équipement.

Une commande de destination valide l'arête accessible, l'état attendu, les coûts et l'absence de récompense en attente. Elle enregistre l'engagement une fois, puis ouvre le bon contenu. Un nœud terminé rend la main à la carte. La victoire de run dépend d'un objectif terminal, pas du dernier indice d'un tableau.

Pour la seed, dériver des tirages distincts depuis `run_seed + node_instance_id + purpose`. Révéler un nœud ne décale pas les récompenses futures. Deux destinations utilisant la même rencontre source ont deux identifiants d'instance ; la déduplication ne doit pas supprimer les gains de la seconde.

La reprise sauvegarde ensemble PV, build, inventaire, monnaie, points, slots ouverts, graphe réalisé, contenu des inconnues, informations révélées, phase et récompenses déjà traitées. Pas de génération renouvelée au chargement. Une sauvegarde de combat en cours resterait un contrat supplémentaire ; la première cible est une reprise fiable aux frontières de nœud.

## 14. Ordre de construction recommandé

1. **Carte et circulation.** Profil expérimental isolé, graphe écrit à la main, combats existants réutilisés, un hub et un événement fonctionnels minimaux, retour carte après résolution. Pas besoin de produire les concepts définitifs pour vérifier un choix de route.
2. **Kit qui évolue.** Apprendre et remplacer, cinquième emplacement, offre du sixième, persistance complète. Une carte d'apprentissage et une mutation doivent fonctionner de bout en bout.
3. **Contrastes de builds.** Couvrir au minimum mêlée/contrôle, distance/mobilité, armure, PV/risque, esquive, soin et une affinité élémentaire. Utiliser peu de sorts mais des verbes distincts. Les primitives déjà présentes sont prioritaires ; les signatures les plus complexes viennent ensuite.
4. **Économie de douze étapes.** Garanties de progression, ressources, sept à neuf combats et choix de préparation. Revoir les plafonds de soin/achats actuels, sans fabriquer douze nouvelles cartes graphiques.
5. **Épreuves adaptées.** Concevoir rencontres, malus, salles spéciales, mini-boss et boss à partir des faiblesses et combinaisons effectivement observées.

L'étape 3 doit démontrer tous les axes demandés avant de déclarer le personnage complet. Trois bons sorts offensifs prouvent la recomposition ; ils ne prouvent pas encore le jeu de build décrit ici.

## 15. Conditions pour valider cette direction

- Un joueur comprend au moins deux chemins crédibles et ce qu'il abandonne, sans connaître tous leurs contenus.
- Chaque parcours légal du profil de référence atteint les premiers jalons de kit à temps ; le chemin riche en combats n'est pas obligatoire pour obtenir le cinquième slot.
- Une orientation principale fonctionne sans attendre un objet rare précis ; chaque spécialiste peut employer son budget de dix points légalement.
- Il existe plusieurs kits viables de cinq et six sorts, avec au moins un remplacement assumé d'une sécurité initiale.
- Deux builds conduisent à des préférences de route différentes dans une même carte, et l'état des PV peut inverser ce choix.
- Une carte enseignant un sort, un emplacement gagné, un item accordant une technique et une mutation ont des conséquences distinctes, correctement persistées. La mutation du jalon VIII n'est pas achetable une seconde fois ou remboursable en points.
- Un « ? » révélé puis rechargé conserve son contenu ; aucune offre ou récompense n'est dupliquée.
- Attendre davantage ne permet pas de générer un soin infini ; les sacrifices ne financent pas eux-mêmes leur remboursement.
- L'esquive et les éléments ont des conséquences tactiques visibles, avec preview et résolution concordantes.
- Signature puis légende sont réellement utilisées dans plusieurs combats ; compter leurs usages, pas seulement leur présence dans le codex.

Mesurer aussi temps de carte, temps de camp, usage des sorts, abandons de sorts, taux de sélection du sixième slot, réorientations, réserves de soins, combats par parcours et raisons des morts. Ces critères sont un protocole futur : aucune satisfaction, durée ou victoire n'a été mesurée par la rédaction de cette V2.
