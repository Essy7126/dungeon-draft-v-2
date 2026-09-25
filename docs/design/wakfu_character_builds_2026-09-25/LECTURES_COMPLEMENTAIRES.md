# Lectures complémentaires : contrats et décisions

Lecture du 2026-09-25, niveau 245. 38 fiches, 18 classes ; 36 identifiants supplémentaires et 2 relectures par rapport aux deux dossiers précédents. Ensemble : 166 identifiants WAKFU distincts.

Les contrats sont des reformulations des fiches consultées ; les analyses sont originales. Le niveau de preuve et les contradictions sont détaillés dans [SOURCES_ET_LIMITES.md](SOURCES_ET_LIMITES.md). Généré depuis [lectures.tsv](lectures.tsv) ; modifier cette source puis relancer le générateur.

## Huppermage

### [Dynamo](https://wakfuli.com/encyclopedia/spells/huppermage?spell=5579) — passif, 5579

**Contrat lu.** Les runes disparaissent en fin de tour. La dernière rune générée donne accès aux sorts manquants de son élément.

**Décision et équilibrage.** Le choix élémentaire devient aussi un choix d'accès au répertoire ; la réserve ne peut plus être reportée librement.

**Limite de preuve.** Durée exacte de l'accès et interaction avec les sorts déjà équipés à reproduire dans le client.

### [Plénitude](https://wakfuli.com/encyclopedia/spells/huppermage?spell=5585) — passif, 5585

**Contrat lu.** Récupérer une rune sur un Feu-Follet donne 30 Abondance ; cette ressource ne se dépense qu'à son maximum.

**Décision et équilibrage.** Remplace de petits décaissements par une fenêtre de conversion préparée.

**Limite de preuve.** Ne pas déduire le multiplicateur d'Abondance de son seul nombre de niveaux.

## Écaflip

### [Triche](https://wakfuli.com/encyclopedia/spells/ecaflip?spell=5251) — passif, 5251

**Contrat lu.** Première carte du tour gratuite, puis pioche d'une carte ; pioche normale de début de tour réduite à une carte.

**Décision et équilibrage.** Le gain de tempo s'achète avec moins de choix à l'ouverture du tour.

**Limite de preuve.** Distinguer pioche normale et effets de Relance ; toutes les cartes ne deviennent pas gratuites.

### [Tarot divinatoire](https://wakfuli.com/encyclopedia/spells/ecaflip?spell=5246) — passif, 5246

**Contrat lu.** Deux cartes blanches consécutives rendent 1 PW ; deux noires donnent 25 Veine ; déclenchement limité à une fois par tour. Relance coûte 3 PA.

**Décision et équilibrage.** La couleur et l'ordre comptent autant que l'effet individuel ; relancer paie la recherche d'une séquence.

**Limite de preuve.** Ne pas transformer plusieurs paires en plusieurs remboursements ; les cas mixtes demandent un contrôle du compteur partagé.

## Pandawa

### [Marcher droit](https://wakfuli.com/encyclopedia/spells/pandawa?spell=8595) — passif, 8595

**Contrat lu.** Téléportono ne demande plus de ligne de vue, mais son lancement doit être en ligne.

**Décision et équilibrage.** Échange une contrainte d'obstacle contre une contrainte d'alignement.

**Limite de preuve.** Ne change pas à lui seul la portée ni la validité des cases de destination.

### [Fermentation lactique](https://wakfuli.com/encyclopedia/spells/pandawa?spell=8597) — passif, 8597

**Contrat lu.** Fin de tour avec son tonneau porté : armure égale à 20 % des PV maximum. Un dégât direct de dos pendant ce portage retire l'armure.

**Décision et équilibrage.** La défense dépend d'un objet et de l'orientation, donc du placement adverse.

**Limite de preuve.** Une ligne isolée 245 Armure est aussi affichée : elle n'est pas ajoutée aux 20 %. Ordre retrait/impact non établi.

### [Soif](https://wakfuli.com/encyclopedia/spells/pandawa?spell=6844) — actif, 6844

**Contrat lu.** 2 PA ; portée affichée 2–4 ; se rapproche du tonneau ciblé, utilisable en portant un combattant ; deux usages par tour.

**Décision et équilibrage.** Le tonneau sert de destination de transport ; le portage d'un allié reste compatible avec l'approche.

**Limite de preuve.** Coût PA confirmé visuellement. Distance parcourue, obstacles et opérateur exact du mouvement non certifiés ici.

## Roublard

### [Tacticien](https://wakfuli.com/encyclopedia/spells/rogue?spell=7982) — passif, 7982

**Contrat lu.** Déplacer une bombe rend 1 PA et lui enlève un niveau ; au plus un remboursement par sort et trois PA par tour.

**Décision et équilibrage.** Transformer une réserve de puissance future en budget d'action immédiat donne une raison de déplacer plutôt que seulement faire exploser.

**Limite de preuve.** Sort déplaçant plusieurs bombes et perte de niveaux après atteinte du plafond à vérifier ; le calcul ne suppose pas de remboursement supplémentaire.

### [Démineur](https://wakfuli.com/encyclopedia/spells/rogue?spell=6484) — passif, 6484

**Contrat lu.** Ruse sur une bombe ne coûte plus de PA mais ne lui donne plus de niveau.

**Décision et équilibrage.** Le placement devient disponible sans investissement de croissance associé.

**Limite de preuve.** La fiche déplie aussi Fourbe/Fuyard : leurs lignes ne sont pas toutes des bonus supplémentaires de Démineur.

### [Fugitif](https://wakfuli.com/encyclopedia/spells/rogue?spell=6488) — passif, 6488

**Contrat lu.** Début de tour : échange avec la bombe la plus proche à quatre cases au plus.

**Décision et équilibrage.** Le placement de la bombe prépare la position du tour suivant et peut aussi imposer une destination gênante.

**Limite de preuve.** Contradiction : Effets ajoute un soin de 10 % PV max ; Description parle de stabilisation de la bombe. Aucun cumul soin/stabilisation certifié.

## Sacrieur

### [Jeu dangereux](https://wakfuli.com/encyclopedia/spells/sacrier?spell=7214) — passif, 7214

**Contrat lu.** Sous 35 % de vie : soins reçus +100 % ; à partir de 35 % : soins reçus −75 %.

**Décision et équilibrage.** Le soutien doit choisir son moment : un grand soin peut être efficace dans le danger et faible juste au-dessus du seuil.

**Limite de preuve.** Instant de lecture du seuil pour un soin traversant 35 % et ordre avec autres modificateurs à tester.

### [Pacte de sang](https://wakfuli.com/encyclopedia/spells/sacrier?spell=5053) — passif, 5053

**Contrat lu.** PV maximum −30 %. Passer sous 20 % donne 15 % des PV max en armure, une fois par tour ; repasser au-dessus de 40 % donne aussi 15 %, une fois par tour.

**Décision et équilibrage.** Le moteur récompense des traversées de seuils, contre une capacité d'absorption brute réduite.

**Limite de preuve.** Être déjà sous le seuil ne suffit pas. Résolution d'un coup mortel et interaction entre compteurs à reproduire.

## Féca

### [Maître des boucliers](https://wakfuli.com/encyclopedia/spells/feca?spell=6991) — passif, 6991

**Contrat lu.** Les boucliers déclenchent leur effet immédiatement, mais leur délai sur la cible augmente de deux tours. Goutte reprend le dernier retrait PA/PM ; Lame de fond le dernier élément subi, Feu par défaut.

**Décision et équilibrage.** Troque répétition et anticipation contre réponse immédiate, tout en rendant l'historique de cible pertinent.

**Limite de preuve.** Ordre de mémorisation de l'attaque et de déclenchement à certifier ; aucune suppression du délai de cible.

### [Armure de combat](https://wakfuli.com/encyclopedia/spells/feca?spell=6996) — passif, 6996

**Contrat lu.** Armure reçue par le Féca −100 % ; la moitié des dégâts infligés aux alliés devient de l'armure.

**Décision et équilibrage.** Oriente vers la protection d'autrui et rend le coût du soutien visible sur la survie propre.

**Limite de preuve.** Base de conversion avant/après résistances et coexistence avec les dégâts alliés non suffisamment explicites pour un bilan net.

## Osamodas

### [Guerrier invocateur](https://wakfuli.com/encyclopedia/spells/osamodas?spell=7331) — passif, 7331

**Contrat lu.** Dégâts infligés du maître +20 % ; dégâts et soins de l'invocation −20 %.

**Décision et équilibrage.** Déplace la contribution vers le maître. La même fiche peut augmenter ou réduire le total suivant la répartition des actions.

**Limite de preuve.** Les calculs isolent ces bonus sans autres modificateurs ; ils ne reproduisent pas toute la formule des dommages du jeu.

### [Art du dressage](https://wakfuli.com/encyclopedia/spells/osamodas?spell=7343) — passif, 7343

**Contrat lu.** Deux créatures différentes peuvent coexister ; leurs dégâts reçus sont transmis à l'Osamodas. Malinvocation dure un tour ; deux exemplaires de la même créature restent interdits pour ce maître.

**Décision et équilibrage.** Deux positions et deux répertoires s'achètent par une vulnérabilité partagée.

**Limite de preuve.** Ordre des résistances, portée du lien et coefficient exact de transmission ne sont pas extrapolés.

## Enutrof

### [Échange asynchrone](https://wakfuli.com/encyclopedia/spells/enutrof?spell=8272) — passif, 8272

**Contrat lu.** En Phorzerker, la maîtrise mêlée se base sur la maîtrise distance ; portée maximale des élémentaires réduite de deux.

**Décision et équilibrage.** Un investissement d'équipement peut alimenter un autre mode, sans demander deux statistiques concurrentes.

**Limite de preuve.** Copie/conversion ne signifie pas addition des deux maîtrises ; ordre avec bonus temporaires à certifier.

### [Protection minérale](https://wakfuli.com/encyclopedia/spells/enutrof?spell=8277) — passif, 8277

**Contrat lu.** Finir sur un gisement le détruit et donne 100 résistance pour un tour ; ce gisement ne peut être excavé pendant un tour.

**Décision et équilibrage.** Consomme une opportunité spatiale future pour survivre maintenant.

**Limite de preuve.** Ne pas confondre destruction d'une case et suppression de tous les gisements.

## Sram

### [Retenue](https://wakfuli.com/encyclopedia/spells/sram?spell=5124) — passif, 5124

**Contrat lu.** L'invisibilité ne peut plus viser un allié ; celle du Sram est perdue sur un sort de dégâts directs coûtant au moins quatre PA.

**Décision et équilibrage.** Autorise la préparation par petites attaques, contre la flexibilité du camouflage allié.

**Limite de preuve.** Seuil de coût avant/après réduction et autres causes de révélation à contrôler ; ce n'est pas une immunité générale.

### [Assaut létal](https://wakfuli.com/encyclopedia/spells/sram?spell=8511) — passif, 8511

**Contrat lu.** Modifie la Marque létale du Double : une mort causée par le Sram rend deux PA, téléporte le Sram derrière le porteur et y transfère l'Hémorragie de la victime.

**Décision et équilibrage.** La victime devient un relais vers une seconde cible ; les positions et l'ordre des exécutions portent le combo.

**Limite de preuve.** Validité de la destination, plafond et provenance des mises à mort doivent être établis avant toute boucle chiffrée.

## Iop

### [Mini-Bond](https://wakfuli.com/encyclopedia/spells/iop?spell=5103) — passif, 5103

**Contrat lu.** Bond coûte deux PA et un PW, avec portée fixe 1–2 et trois utilisations par tour.

**Décision et équilibrage.** Fractionne l'accès à la mêlée en déplacements courts qui consomment deux budgets.

**Limite de preuve.** Trois lancements ne prouvent pas un trajet libre de six cases ; destinations et obstacles restent déterminants.

### [Démonstration](https://wakfuli.com/encyclopedia/spells/iop?spell=8415) — passif, 8415

**Contrat lu.** Fin de tour : chaque niveau de Courroux rend un PW et donne 15 Préparation ; supprime la récupération immédiate de PW à 100 Concentration.

**Décision et équilibrage.** Déplace la récompense après le tour et augmente la valeur de préparer le suivant.

**Limite de preuve.** Acquisition et plafond de Courroux non reconstruits ici ; ne pas créditer la réserve avant la fin du tour.

## Crâ

### [Paradoxe du Crâ](https://wakfuli.com/encyclopedia/spells/cra?spell=6955) — passif, 6955

**Contrat lu.** Insaisissable demande désormais au moins un ennemi à trois cases ou moins.

**Décision et équilibrage.** Inverse la condition d'un même moteur et rend possible une recherche volontaire de proximité.

**Limite de preuve.** Les autres propriétés d'Insaisissable ne sont pas redéfinies par ce seul passif.

### [Pointe protectrice](https://wakfuli.com/encyclopedia/spells/cra?spell=7795) — passif, 7795

**Contrat lu.** En fin de tour, tout Affûtage est consommé et converti en résistance à raison d'un point par niveau.

**Décision et équilibrage.** L'investissement offensif peut être dépensé pour passer une fenêtre de menace.

**Limite de preuve.** Durée décrite pour le tour à venir ; plafond d'Affûtage et arbitrage avec d'autres consommateurs à vérifier.

## Sadida

### [Croissance accélérée](https://wakfuli.com/encyclopedia/spells/sadida?spell=8152) — passif, 8152

**Contrat lu.** Les poupées gagnent un niveau d'Engrainé supplémentaire en fin de tour ; repasser en graine via Engrènement consomme tous leurs niveaux.

**Décision et équilibrage.** L'accélération de croissance rend plus cher le recyclage d'une installation déjà développée.

**Limite de preuve.** Ne pas attribuer cette croissance supplémentaire aux graines ; empilement avec Terrain fertile non certifié.

### [Terrain fertile](https://wakfuli.com/encyclopedia/spells/sadida?spell=8151) — passif, 8151

**Contrat lu.** Près de son Arbre, poupées et graines gagnent un niveau supplémentaire d'Engrainé en fin de tour ; hors de cette zone elles n'en gagnent pas.

**Décision et équilibrage.** Le territoire protégé devient la condition de progression des unités.

**Limite de preuve.** Rayon exact non décodé ; impossible de calculer une couverture de grille fiable à partir de cette lecture seule.

## Eniripsa

### [Délai](https://wakfuli.com/encyclopedia/spells/eniripsa?spell=5451) — passif, 5451

**Contrat lu.** La moitié du soin direct arrive immédiatement, l'autre au début du tour du bénéficiaire via Délai.

**Décision et équilibrage.** Même montant nominal, mais capacité de sauver une cible différente suivant l'initiative ennemie.

**Limite de preuve.** Plafond PV, résistance aux soins et autres modificateurs aux deux instants à vérifier.

### [Médecin sans barrière](https://wakfuli.com/encyclopedia/spells/eniripsa?spell=628) — passif, 628

**Contrat lu.** Propagateur se construit par les dégâts plutôt que par les soins ; le prochain soin monocible le consomme pour ajouter un soin Lumière lié à ses niveaux.

**Décision et équilibrage.** L'attaque prépare le secours, au lieu d'opposer deux tours sans relation.

**Limite de preuve.** Coefficient par niveau non décodé ; aucun rendement dégâts/soins inventé.

## Zobal

### [Bas les masques](https://wakfuli.com/encyclopedia/spells/masqueraider?spell=7094) — passif, 7094

**Contrat lu.** Changer vers un masque différent rend deux PA, une seule fois par tour.

**Décision et équilibrage.** Le premier changement peut financer une autre action ; répéter le changement n'est pas une source illimitée.

**Limite de preuve.** Vérifier le moment du remboursement et le coût réel du changement avec les autres passifs.

### [Virevolte](https://wakfuli.com/encyclopedia/spells/masqueraider?spell=7105) — passif, 7105

**Contrat lu.** Dégâts infligés de côté +25 % ; de face −25 %.

**Décision et équilibrage.** Le joueur cherche un angle précis ; une carte étroite réduit la valeur effective du passif.

**Limite de preuve.** Le dos n'est pas déclaré modifié ; calculs sans autres bonus ni multiplicateurs d'orientation.

## Ouginak

### [Chasse ouverte](https://wakfuli.com/encyclopedia/spells/ouginak?spell=7554) — passif, 7554

**Contrat lu.** Capacité de Rage réduite de dix ; attaquer la Proie fait gagner Rage et Traqueur immédiatement.

**Décision et équilibrage.** Échange la taille de réserve contre une conversion plus rapide pendant le tour.

**Limite de preuve.** Quantités gagnées par événement et autres conditions ne sont pas déduites de ce texte.

### [Digestion](https://wakfuli.com/encyclopedia/spells/ouginak?spell=7555) — passif, 7555

**Contrat lu.** Dégâts indirects −15 % ; un déclenchement indirect qualifié donne quatre Rage et soigne 4 % des PV max, au plus cinq fois par tour.

**Décision et équilibrage.** Sacrifie du rendement offensif pour entretenir une ressource et la survie.

**Limite de preuve.** Une fenêtre de cinq déclenchements est calculée ; périmètre du compteur entre tours de combattants, soin excédentaire et sources qualifiées à contrôler.

## Steamer

### [Patience](https://wakfuli.com/encyclopedia/spells/foggernaut?spell=6933) — passif, 6933

**Contrat lu.** Atteindre le maximum de PS donne deux PS supplémentaires non régénérables, qui permettent de dépasser temporairement ce maximum ; PW maximum −2 au début du combat.

**Décision et équilibrage.** La préparation d'une réserve permet une pointe plus haute contre une réserve secondaire réduite.

**Limite de preuve.** Conditions de nouveau déclenchement et réinitialisation non établies ; pas de répétition infinie supposée.

### [Substitution mécanique](https://wakfuli.com/encyclopedia/spells/foggernaut?spell=6932) — passif, 6932

**Contrat lu.** Un sort Eau visant la tourelle échange sa place avec celle du Steamer ; un sort Terre attire d'une case par PA dans la croix affichée 7. Première activation du tour : deux PA rendus. Invocation/amélioration de tourelle : coût un PW.

**Décision et équilibrage.** Le même sort sert de commande spatiale et le premier usage est moins coûteux.

**Limite de preuve.** Signification géométrique exacte de croix 7 et interaction des coûts avec autres passifs à vérifier.

## Eliotrope

### [Espace-temps](https://wakfuli.com/encyclopedia/spells/eliotrope?spell=7205) — passif, 7205

**Contrat lu.** Les portails de toute l'équipe durent deux tours au lieu de persister indéfiniment.

**Décision et équilibrage.** La durée devient une contrainte commune de planification, y compris pour les partenaires.

**Limite de preuve.** Aucun bénéfice compensatoire autonome n'est exposé ; ne pas en inventer ni conclure à l'inutilité sans les innés.

### [Disciple du portail](https://wakfuli.com/encyclopedia/spells/eliotrope?spell=5056) — passif, 5056

**Contrat lu.** Exaltation crée un portail sous le héros, immobile et détruit en fin de tour ; peut dépasser la limite de quatre. Portail ne peut plus être lancé pendant le reste du tour.

**Décision et équilibrage.** Ouvre un départ temporaire au prix de la liberté de reconstruire le réseau ensuite.

**Limite de preuve.** Interaction avec d'autres plafonds, notamment Portail céleste, et restitution de ressources à certifier.

## Xélor

### [Maître du cadran](https://wakfuli.com/encyclopedia/spells/xelor?spell=758) — passif, 758

**Contrat lu.** Quand l'heure accomplit un tour complet, les effets différés s'activent également immédiatement ; exemples cités : Sinistro, Sablier, Contre la montre.

**Décision et équilibrage.** L'horloge transforme une réserve d'effets futurs en fenêtre de résolution.

**Limite de preuve.** La description ne prouve pas l'annulation de l'échéance initiale : ne pas confondre déclenchement supplémentaire et simple avance dans le temps.

### [Assimilation](https://wakfuli.com/encyclopedia/spells/xelor?spell=7196) — passif, 7196

**Contrat lu.** PW maximum −6 ; tuer un combattant, y compris allié ou invocation, rend deux PW.

**Décision et équilibrage.** Une réserve plus petite est renouvelable par élimination ; les cibles sacrifiables ont une valeur de ressource.

**Limite de preuve.** Le plafond de PW reste applicable. Cette éligibilité de ressource n'autorise pas un butin sur les invocations dans Catabase.
