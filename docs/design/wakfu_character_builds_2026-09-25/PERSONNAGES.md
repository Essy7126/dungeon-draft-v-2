# Dix-huit façons de construire un personnage

Les directions A/B ci-dessous sont des lectures de design, pas des listes de six passifs dont la compatibilité aurait été testée. Les valeurs et liens précis des nouveaux effets sont dans les [38 fiches complémentaires](LECTURES_COMPLEMENTAIRES.md). Les actifs associés proviennent des [55 fiches initiales](../dofus_wakfu_spell_identity_2026-09-25/WAKFU.md) et des [75 fiches de l'extension](../dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/CLASSES_WAKFU.md). On distingue systématiquement le contrat lu, l'intérêt que nous en déduisons et la limite de preuve.

L'attrait proposé pour chaque classe est une **hypothèse de satisfaction** : exécuter un plan, sauver un allié, transformer une position défavorable. Ce n'est pas une mesure de préférence ou de popularité des joueurs. Pour l'établir, il faudrait confronter ces hypothèses à des entretiens et à des parties observées.

## Xélor — mettre un rendez-vous sur plusieurs effets

**Architecture.** Cadran, heure, dépenses de PW, effets différés et déplacements sont liés. Suspension permet d'intervenir sur l'avancement de l'heure ; Sablier et Contre la montre mettent des événements en attente. Maître du cadran transforme un cycle accompli en fenêtre de résolution, avec une incertitude majeure sur le maintien des échéances initiales.

**A — programmation.** Préparer plusieurs bénéficiaires ou mécanismes, choisir le moment du cycle, puis exploiter leur résolution. L'attrait est de voir converger des actions faibles isolément. Le coût est un tour préparatoire et une installation vulnérable.

**B — renouvellement par élimination.** Assimilation réduit de six la capacité de PW et rend deux PW par mort admissible. Il faut choisir les victimes et éviter de déborder une petite réserve. Le moteur privilégie des fenêtres courtes ; tuer un allié peut financer une action mais détruit son utilité restante.

**Épreuve et transfert.** Déplacer une pièce ou rendre une victime inaccessible suffit à perturber le tour sans interdire tous les sorts. Pour Catabase, emprunter une échéance visible attachée à une famille ou un dispositif, pas le rejouage d'une carte consommée. Ne pas coder Maître du cadran avant d'avoir choisi explicitement « avancer » ou « dupliquer » l'événement.

## Pandawa — faire d'un objet une ancre de placement

**Architecture.** Tonneau, portage, destination de transport et orientation du corps forment une même infrastructure. Soif peut rapprocher du tonneau alors qu'un combattant est porté. La valeur de cette action vient aussi de la position obtenue par ce passager.

**A — transport autour des obstacles.** Marcher droit permet à Téléportono d'ignorer la ligne de vue, en imposant un alignement. Il faut préparer un axe ; la suppression d'une contrainte n'efface pas la géométrie.

**B — bastion mobile.** Fermentation lactique récompense le tour terminé avec le tonneau porté par 20 % des PV max d'armure. Le dos devient une vulnérabilité déterminante : une grande réserve défensive n'est pas un permis d'ignorer l'orientation.

**Épreuve et transfert.** Un adversaire contournant le héros teste cette défense plus finement qu'une simple hausse de dégâts. Pour notre Gardien, un dispositif normal peut fournir une destination ou un abri ; une spécialisation peut échanger visibilité contre alignement. Ne pas importer automatiquement le système complet de portage, qui implique occupation, ciblage et sauvegarde de deux entités liées.

## Féca — choisir quand la protection agit

**Architecture.** Le bouclier n'est pas seulement un montant d'armure. Son bénéficiaire, son déclencheur et sa disponibilité sur cette cible comptent. Maître des boucliers ajoute aussi une dépendance à l'historique du bénéficiaire.

**A — réaction immédiate.** Déclencher sans attendre résout une menace actuelle, mais la cible ne peut retrouver aussi vite ce soutien : deux tours de délai supplémentaires. C'est un choix entre sauvetage ponctuel et cadence.

**B — protecteur exposé.** Armure de combat réduit de 100 % l'armure reçue par le Féca et convertit une partie des dégâts infligés aux alliés en armure. Cette direction déplace les risques vers le protecteur. Le bilan net sur l'allié reste indéterminé sans l'ordre exact dégâts/conversion.

**Épreuve et transfert.** Une seconde menace après le premier bouclier révèle le coût de l'immédiateté. Pour Catabase, une garde à déclenchement choisi mérite une cadence ou une consommation distincte, sans promettre une protection gratuite répétée. L'interface doit annoncer la prochaine disponibilité et l'événement mémorisé.

## Osamodas — distribuer puissance et vulnérabilité

**Architecture.** Le maître et sa créature disposent de contributions différentes. Leur addition ne suffit pas : une invocation ajoute une position, un répertoire et une exposition. Lien animal, Piqûre motivante et les passifs déplacent l'investissement entre ces acteurs.

**A — maître combattant.** Guerrier invocateur augmente les dégâts du maître tout en réduisant dégâts et soins de la créature. Le calcul W08 montre pourquoi ce passif peut diminuer le total d'un build dominé par l'invocation.

**B — deux spécialistes.** Art du dressage permet deux créatures différentes, avec transmission de leurs dégâts reçus au maître. Le gain de fonctions et d'occupation se paie par davantage de chemins par lesquels le groupe peut être blessé.

**Épreuve et transfert.** Des zones frappant plusieurs unités testent une équipe dense ; un objectif distant valorise au contraire deux positions. Pour notre jeu, un familier ne doit pas être traité comme un paquet de dégâts gratuits. Sa durée, ses actions, la provenance de ses morts et sa place dans les plafonds doivent être explicites ; aucune invocation ne doit créer une nouvelle occasion de sac.

## Enutrof — dépenser le territoire et convertir l'équipement

**Architecture.** Gisements, exploitation, Phorzerker et progression des bourses créent des raisons de se déplacer ou d'attendre. Le terrain représente une opportunité consommable ; l'équipement peut être réinterprété par le mode de combat.

**A — investissement distance, sortie mêlée.** Échange asynchrone fait dépendre la maîtrise mêlée de la maîtrise distance en Phorzerker, contre deux points de portée maximale élémentaire. Il rend un ensemble de statistiques compatible avec une autre distance de jeu ; il n'additionne pas deux spécialisations.

**B — réserve défensive au sol.** Protection minérale détruit le gisement sous le personnage pour une résistance temporaire, en empêchant sa réexcavation immédiate. Se protéger ferme une option future.

**Épreuve et transfert.** Un ennemi qui chasse d'un gisement menace l'économie locale des actions. Dans Catabase, reprendre la consommation d'une ressource de salle ou une conversion de statistique plafonnée. Ne pas confondre l'identité Enutrof avec un bonus global de loot : le drop de run doit conserver ses plafonds et son indépendance des invocations.

## Sram — faire d'une victime le passage vers la suivante

**Architecture.** Faiblesse, dos, invisibilité, Hémorragie et Double donnent plusieurs temporalités à l'assassinat. Fourberie prépare un angle ; Mise à mort dépense une préparation ; Assaut létal relie une élimination à une seconde cible.

**A — préparation cachée.** Retenue maintient la discrétion lors de petites attaques directes, avec un seuil de révélation à quatre PA, mais retire l'invisibilité alliée. Le bénéfice est un ordre d'actions plus souple, pas une intouchabilité garantie.

**B — chaîne de victimes.** Avec la Marque létale modifiée, tuer rend deux PA, repositionne le Sram derrière son porteur et y transfère l'Hémorragie. La cible faible devient une ressource tactique qu'il ne faut pas éliminer trop tôt avec un autre acteur.

**Épreuve et transfert.** Une destination occupée ou une victime tuée par un allié doit produire un résultat lisible. Pour notre Assassin, déplacer une marque est plus compatible avec des cartes consommables que ressusciter une copie jouée. Toute récompense sur mort doit spécifier auteur, source, cible initiale et plafond.

## Écaflip — organiser une incertitude manipulable

**Architecture.** Tarot, pioche, couleurs, Veine et Relance structurent la prise de risque. Tout ou rien et Quitte ou double ajoutent des arbitrages de situation ; le personnage ne se réduit pas à un tirage aveugle de dégâts.

**A — tempo avec moins de choix.** Triche rend la première carte gratuite et la remplace, mais réduit la pioche normale. Le joueur valorise une bonne première option ; une mauvaise ouverture devient plus difficile à corriger.

**B — séquence de couleurs.** Tarot divinatoire paie une paire ordonnée par PW ou Veine, avec une limite par tour et une Relance plus coûteuse. Le tirage impose des contraintes ; la décision consiste à accepter la main ou payer pour chercher une autre séquence.

**Épreuve et transfert.** Mesurer simultanément rendement et fréquence des mains sans action souhaitée. Pour Catabase, le filtrage doit rendre l'aléatoire gouvernable sans annuler le drop : regarder/écarter quelques cartes ou préparer une famille. Ne pas confondre le tarot interne WAKFU avec nos objets de carte définitivement consommés.

## Eniripsa — convertir l'attaque en soin et négocier l'urgence

**Architecture.** Reconstitution, résurrection et protections ont des coûts et des fenêtres distinctes. Propagateur peut relier l'action offensive à un prochain secours ; l'ordre d'initiative donne sa valeur réelle à un soin.

**A — alternance offensive.** Médecin sans barrière demande de construire Propagateur par les dégâts, puis de l'encaisser dans un soin monocible. Le soutien participe à l'attaque sans abandonner toute préparation défensive.

**B — soin réparti.** Délai sépare le même soin en deux moments. Ce n'est pas automatiquement un gain : W09 montre un bénéficiaire mourant avant de recevoir la seconde moitié. La pertinence dépend de l'ordre des menaces et des PV manquants aux deux échéances.

**Épreuve et transfert.** Une attaque entre les deux fractions teste la différence entre montant nominal et secours réel. Pour nos cartes, une préparation offensive pourrait améliorer un soutien, mais l'effet doit survivre à la consommation de sa carte source. Éviter de proposer un soin différé sans afficher l'échéance et la survie estimée jusqu'à celle-ci.

## Iop — rendre la montée en puissance compatible avec l'accès à la cible

**Architecture.** Concentration, Courroux, Préparation et PW distinguent construction et libération de puissance. Un gros impact théorique ne vaut rien si la cible n'est pas atteignable au moment voulu.

**A — approche fractionnée.** Mini-Bond donne plusieurs petits déplacements, au coût cumulé de PA et PW. Il peut traverser plusieurs positions utiles, mais trois bonds consomment déjà six PA et trois PW : cette économie appartient à WAKFU, pas à notre base de quatre PA.

**B — récompense reportée.** Démonstration remplace une récupération immédiate par des gains de fin de tour liés à Courroux. Il faut survivre et conserver une cible intéressante pour profiter du capital prochain.

**Épreuve et transfert.** Une cible qui recule teste la réserve de mobilité ; une deuxième vague teste le capital conservé. Notre transposition doit choisir entre financement du tour en cours et du suivant. Donner simultanément dégâts, PA immédiats et réserve future supprime précisément la tension qui rend ce moteur intéressant.

## Crâ — choisir la distance qui active le moteur

**Architecture.** Précision, Affûtage, Insaisissable, balises et plage de portée font de la distance une ressource. Une augmentation de portée minimale peut être autant une contrainte qu'un gain de portée maximale.

**A — proximité volontaire.** Paradoxe du Crâ inverse la condition d'Insaisissable : un ennemi proche devient nécessaire. La même classe peut ainsi chercher la situation qu'un autre build évite.

**B — sacrifier l'accumulation pour résister.** Pointe protectrice consomme Affûtage en fin de tour contre de la résistance. Le choix porte sur une réserve offensive abandonnée, pas sur un bonus défensif ajouté sans contrepartie.

**Épreuve et transfert.** Ennemis mobiles, couloirs et positions ouvertes doivent changer le classement des options. Pour l'Arpenteur, tester une spécialisation inversant une condition de distance avant de multiplier les tirs aux dégâts presque identiques. Garder une solution normale pour sortir d'une mauvaise portée ; la carte rare ne doit pas être le seul moyen de jouer.

## Sadida — investir dans une installation qui peut devoir déménager

**Architecture.** Graines, poupées, Arbre et Engrainé font progresser une présence au fil des tours. Sacrifier ou retransformer une unité n'a pas le même coût selon son ancienneté.

**A — croissance accélérée.** Une poupée gagne plus vite, mais la retransformer consomme ses niveaux. Le déplacement de l'installation devient une perte d'investissement, et non une opération neutre.

**B — territoire fertile.** La proximité de l'Arbre permet la croissance de graines et poupées ; hors de la zone, cette progression s'arrête. Le choix du centre organise les futures actions et la vulnérabilité à une attaque de zone.

**Épreuve et transfert.** Un objectif qui change de case oblige à arbitrer maturité et mobilité. Pour Catabase, un mécanisme normal pourrait accumuler une charge bornée puis être déplacé au prix de cette charge. Éviter un rendement passif illimité quand le dernier ennemi est sans danger : durée, plafond et fin de salle doivent clôturer l'investissement.

## Sacrieur — traverser des seuils, pas simplement rester blessé

**Architecture.** Vie, armure, sacrifice et soin dessinent une trajectoire. Pacte de sang s'intéresse à des passages sous puis au-dessus de seuils ; Jeu dangereux change brutalement l'efficacité du soutien.

**A — oscillation protégée.** Perdre des PV maximum permet d'obtenir de l'armure en franchissant deux seuils. La puissance dépend de la capacité à franchir ces seuils vivant ; le plafond ne garantit pas la survie d'un coup mortel.

**B — fenêtre de secours.** Sous 35 %, le soin est augmenté ; à partir de 35 %, il est fortement diminué. Le soigneur doit anticiper le moment et la taille de l'instance. Un soin qui traverse le seuil exige une règle d'évaluation explicite.

**Épreuve et transfert.** Tester coups groupés, dégâts fractionnés et soins après dégâts plutôt que seulement des moyennes. Pour notre Gardien, préférer une réserve de garde volontairement engagée à une obligation de rester presque mort ; le pouvoir d'anticiper importe davantage que la reproduction des pourcentages.

## Roublard — arbitrer position, maturation et explosion

**Architecture.** La bombe conserve une position et des niveaux ; un mur ou une explosion peut consommer cette infrastructure. Une case occupée peut empêcher la naissance d'une bombe différée.

**A — budget d'action par déplacement.** Tacticien rembourse du PA contre un niveau de bombe, avec deux plafonds. La position se prépare en liquidant un peu de rendement futur.

**B — placement sans croissance.** Démineur rend Ruse gratuite sur bombe, mais retire son gain de niveau. Il facilite la correction d'une installation au lieu de financer simultanément sa croissance. Fugitif constitue une autre façon de programmer sa position, dont le soin ou la stabilisation restent contradictoires dans la source.

**Épreuve et transfert.** Un ennemi qui occupe la future case ou sépare les bombes met le plan sous pression. Pour le Thaumaturge, transformer ou déplacer une zone en payant sa durée est un moteur prometteur. Ne pas convertir une zone dans deux ressources avec retour automatique à la zone initiale : cela ouvre une boucle sans coût net.

## Zobal — changer de rôle et choisir son angle

**Architecture.** Masques, collisions, soin et orientation lient déplacement et fonction. Sarabande change d'usage selon le bénéficiaire ; une collision peut servir au soutien plutôt qu'au seul dégât.

**A — changement financé.** Bas les masques rembourse le premier changement vers un masque différent. Carnaval, dans la lecture précédente, échange le coût PW contre une recharge plus longue : les deux fiches illustrent des axes de flexibilité différents, sans que leur combinaison soit ici certifiée.

**B — côté privilégié.** Virevolte récompense le flanc et pénalise la face. Le rendement dépend du taux réel d'accès au côté ; W07 montre qu'un bonus affiché de 25 % peut produire un gain moyen bien plus faible.

**Épreuve et transfert.** Une carte étroite ou un ennemi bloquant un flanc doit réduire les choix sans les annuler tous. Dans Catabase, différencier déplacement, collision valide et échec de déplacement avant d'ajouter des déclencheurs de soin. Un bonus de changement de posture doit avoir une limite portée par le personnage, pas par chaque copie consommée.

## Ouginak — arbitrer vitesse de conversion et taille de réserve

**Architecture.** Proie désigne la poursuite ; Rage finance plusieurs usages ; Apaisement transforme toute cette réserve en défense et mobilité. Le personnage peut dépenser son offensive pour tenir.

**A — cycle court.** Chasse ouverte donne plus vite les ressources liées à l'attaque de Proie, mais réduit de dix la capacité de Rage. La réserve déborde plus facilement ; l'intérêt vient de l'accès immédiat à une action, pas seulement du total gagné.

**B — persistance indirecte.** Digestion diminue les dégâts indirects et en tire Rage et soin dans une limite de cinq activations. Un plafond d'événements empêche de multiplier indéfiniment le rendement par petites instances.

**Épreuve et transfert.** Changer de cible imposée perturbe le plan ; plusieurs petits dégâts testent le compteur. Pour notre run, toute conversion d'une brûlure en ressource doit dire si elle compte par cible, impact, carte ou tour. Les calculs de Digestion sont des plafonds bruts, pas une promesse de soin effectif sans perte par excès.

## Steamer — commander une infrastructure avec ses attaques

**Architecture.** Tourelle, microbots, PS et PW créent plusieurs réserves et positions. Le choix entre automatisme et activation contrôlée, déjà visible avec Exécution, transforme l'ordre des décisions.

**A — commande élémentaire.** Substitution mécanique donne aux sorts Eau/Terre un usage sur la tourelle : échange ou attraction. Le premier déclenchement rend du PA ; la tourelle utilise aussi du PW. L'infrastructure n'est pas gratuite sous prétexte que le sort existe déjà pour attaquer.

**B — pointe préparée.** Patience permet de dépasser temporairement le maximum de PS, mais réduit le maximum de PW. Il faut remplir avant de profiter du surplus ; son caractère non régénérable interdit de le traiter comme deux points permanents de capacité normale.

**Épreuve et transfert.** Détruire ou déplacer la tourelle réduit les branches disponibles. Nos salles à Réservoirs fournissent déjà un point d'appui : mieux vaut y ajouter un choix de commande qu'introduire immédiatement une seconde classe entière de dispositifs redondants.

## Eliotrope — rendre le réseau lisible pour toute l'équipe

**Architecture.** Portails, état du lanceur et trajet d'un sort modifient son rendement. Une même position n'est utile que si une entrée et une sortie restent disponibles au bon moment.

**A — départ temporaire.** Disciple du portail crée un portail sous le héros après Exaltation, mais bloque le lancement de Portail pour le reste du tour et détruit cette entrée à la fin. L'ordre « construire puis basculer » devient important.

**B — réseau à échéance courte.** Espace-temps impose deux tours aux portails de toute l'équipe. La fiche seule n'expose pas son bénéfice : cette direction reste un cas d'étude incomplet, pas une recommandation d'optimisation. Ses interactions avec les innés doivent être établies.

**Épreuve et transfert.** Tester la disparition d'une sortie entre deux tours alliés. Dans Catabase, une paire de relais temporaires pourrait ouvrir une option de portée, mais un graphe de portails arbitraire augmenterait beaucoup les coûts d'interface et de prévisualisation. Commencer par une paire, une propriété claire et une expiration annoncée.

## Huppermage — écrire une commande avec l'ordre des éléments

**Architecture.** Les runes, leur ordre d'acquisition, le Feu-Follet et la Brise quadramentale donnent des fonctions différentes à une séquence. Flèche de lumière et Principio Valere ne changent pas seulement de coefficient : leur branche dépend de la dernière rune. Runification dépense les runes plutôt que de laisser toute préparation disponible après le gain.

**A — accès temporaire au répertoire.** Dynamo ouvre les sorts manquants de l'élément de la dernière rune générée, avec disparition des runes en fin de tour. Choisir un élément prépare donc les actions accessibles ensuite ; conserver une réserve indéfiniment n'est plus possible.

**B — conversion au maximum.** Plénitude favorise la récupération de runes sur Feu-Follet pour construire Abondance, mais n'autorise sa dépense qu'au maximum. L'attrait est une séquence achevée au bon moment ; le risque est de payer sa préparation sans atteindre la fenêtre. Le rendement numérique d'Abondance reste à établir, sans le déduire du seul nombre de niveaux.

**Épreuve et transfert.** Un élément indisponible ou un Feu-Follet inaccessible teste l'autonomie du moteur. Pour le Thaumaturge consommable, une petite conversion de secours doit éviter qu'une couleur manquante bloque toute la main. Si l'ordre des cartes crée une commande, mémoriser cet ordre sur le héros ; une copie temporairement créée ne doit pas devenir un objet revendable ni annuler le besoin de sacs.
