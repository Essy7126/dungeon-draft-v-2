# Journal des hypothèses mises à l’épreuve

Ce journal sépare les explorations des vérifications finales. Les premiers résultats ne sont pas cumulés avec les derniers pour gonfler un nombre de simulations favorables. Les graines 1–10 servent au réglage ; 10001–10025 à la comparaison finale. La même graine ne garantit pas la même main après un changement de stock.

## A. Erreur de raisonnement initiale : quantité disponible = run jouable

Les études précédentes simulaient surtout une demande de cartes fixée à l’avance. Le nouveau modèle déduit la consommation des actions. Il reproduit ainsi un risque absent d’un simple bilan de stock : il reste des gardes et des déplacements, mais pas assez d’attaques pour payer le prochain groupe.

Un premier essai à la graine 2026 terminait avec l’Assassin et une politique regardant deux actions ; les trois autres classes échouaient au troisième combat. Avec une politique à une action, l’Assassin échouait lui-même au deuxième. Il fallait donc séparer insuffisance du contrôleur et insuffisance du ravitaillement.

Correction du banc d’essai : recherche de deux actions ; conservation de l’automate à un choix comme témoin. Corrections de règles découvertes pendant les contrôles : drain sur un coup létal, reprise exacte de la pioche, fin de combat avant pression, boucliers des prêtres, dette du sablier, plafonnement du vol de vie après bonus de soin, retrait de la copie seulement après validation. Les tests de témoin d’amélioration ont aussi été adaptés : une meilleure portée ne se mesure pas contre une cible déjà proche, et un meilleur soin ne se mesure pas à demi-vie lorsque les deux versions rendent déjà tous les PV.

## B. Comparaison des arrivées de normales

Trois variantes, dix graines par classe, avant réduction de la marche initiale et avant révision du Gardien. Cartes natives, économie et contrôleur identiques dans ce pilote ; le contenu exact des sacs change avec leur taille.

| Variante | Normales par mob et palier | Assassin | Gardien | Arpenteur | Thaumaturge |
|---|---|---:|---:|---:|---:|
| Deux sacs de 3, jets initiaux 75 %/15 % | 2,7 / 3 / 3,6 / 4,2 | 8/10 | 0/10 | 1/10 | 2/10 |
| Sac de 2 garanti + sac de 2 à 50/60/75/90 % | 3 / 3,2 / 3,5 / 3,8 | 9/10 | 0/10 | 3/10 | 3/10 |
| Sac de 3 garanti + carte à 0/10/20/30 % | 3 / 3,1 / 3,2 / 3,3 | 10/10 | 1/10 | 4/10 | 2/10 |

Ces petits échantillons ne classent pas finement deux variantes proches. Ils montrent surtout que garantir des cartes ne résout pas, seul, la difficulté économique. Le deuxième modèle est retenu comme point de départ : garantie lisible, variance moindre et hausse du nombre de petits sacs sur la run.

## C. Séparer la marche de difficulté et le drop

Le budget de PV ennemis passait de 1,4 P au premier combat à 4,2 P au deuxième, puis 6 P au troisième. Avec seulement quinze consommables au départ et le premier marchand après le troisième, cette montée vidait le stock avant que les décisions économiques existent.

Essai : deuxième combat 3 P, troisième 4,2 P, reste inchangé, sacs de deux retenus. Sur dix graines : Assassin 9 victoires, Gardien 2, Arpenteur 8, Thaumaturge 6. Les échecs du Gardien se déplacent surtout vers les combats 7–8 : le problème initial est réduit, mais la défense conserve un coût d’attrition disproportionné.

Les deux attaques normales du Gardien sont ensuite ajustées : Heurt du rempart 1 P +0,5 P sous garde ; Repousser 0,8 P. Cela donne des attaques ordinaires utiles sans transformer la garde en condition nécessaire à tous les sorts. L’étape s’accompagne du passage des achats au module transactionnel et d’identifiants de copies marchandes différents ; les variations de victoire de ce petit essai ne sont donc pas attribuées au seul buff de dégâts.

## D. Révision R1 complète : résultat défavorable conservé

[Le résumé R1](iteration_r1_run_summary.csv) contient 640 runs et ses [métadonnées](iteration_r1_metadata.json). Le contrôleur, les cartes, les shops et les drops sont ceux précédant le dernier changement de passif. En série principale de 25 graines par spécialisation :

| Classe | Spécialisation 1 | Spécialisation 2 |
|---|---:|---:|
| Assassin | 24/25 | 23/25 |
| Gardien | 3/25 | 10/25 |
| Arpenteur | 23/25 | 20/25 |
| Thaumaturge | 18/25 | 16/25 |

La garde fonctionnait techniquement et améliorait certaines situations isolées, sans financer assez bien une succession de combats. Augmenter le drop uniquement pour le Gardien aurait masqué cette différence par une règle économique de classe difficile à expliquer. Augmenter globalement les sacs aurait surtout accru le surplus des autres classes.

## E. Correction structurelle du Gardien

Remplacer « prochaine poussée +1 case après garde absorbée » par un petit renvoi lors de la première attaque partiellement absorbée du tour. Le renvoi ne déclenche ni vol de vie ni récompense de meurtre direct, et n’utilise aucune nouvelle copie. L’objectif est de faire de la défense une contribution à la victoire, donc à l’économie des consommables.

Pilote séparé, graines 1–10 :

| Renvoi | Bastion | Broyeur | Consommation moyenne, toutes tentatives Bastion / Broyeur |
|---|---:|---:|---:|
| 0,25 P | 8/10 | 7/10 | 81,8 / 82,5 |
| 0,40 P | 10/10 | 10/10 | 95,6 / 94,7 |
| 0,55 P | 9/10 | 9/10 | 86,4 / 90,9 |

Retenu : **0,25 P**, le plus petit changement testé, pas la valeur maximisant les victoires de ce petit échantillon. La consommation moyenne plus haute dans une variante peut simplement venir de davantage de combats atteints. Elle n’est pas une preuve de moins bonne efficacité ; comparer aussi les trajectoires et les seuls vainqueurs.

Résultats transportables : [guardian_pilot.json](guardian_pilot.json). Le pilote est reproductible avec `node docs/design/consumable_v1/pilot_guardian.mjs`. La campagne finale repart ensuite sur les graines de vérification et recalcule aussi les objets, les cartes et les variantes de run ; elle n’ajoute pas les résultats R1 aux victoires de la V1 retenue.

## F. Décisions à ne pas transformer en certitudes

L’amélioration du Gardien sous un contrôleur ne prouve pas une préférence des joueurs. Une politique très prudente peut mal jouer une carte qui demande une prise de risque. Un objet qui donne plus de portée peut changer toute une trajectoire et parfois faire moins bien dans un petit lot. Les différences faibles sur dix graines sont des hypothèses à investiguer, pas des verdicts de nerf.

La révision finale ferme les règles et fournit des paramètres révisables. Les réserves de validation et les critères humains restent explicites dans le bilan et le guide de reprise.

## G. Audit final des résultats livrés

La revue de l’exemple complet a révélé un défaut d’historique : une transaction copiait l’état et détachait la référence de la ligne de combat encore utilisée pour écrire les récompenses. L’inventaire réel et les parties étaient corrects, mais certaines lignes n’affichaient pas le stock et l’or après services. Le modèle écrit désormais dans la dernière ligne effectivement conservée. Un test compare le stock après récompenses au stock avant consommation du combat suivant.

Les **640 runs finales ont toutes été rejouées** après cette correction. Victoire/défaite, consommations, stock final, or, achats, drops, secours, dépenses et usages de cartes sont identiques pour chacune ; les nouvelles traces passent toutes les continuités. Le tableau d’exemple a été régénéré. Ce sont des reprises de vérification, pas 640 nouvelles graines à ajouter à la taille de l’échantillon. La suite complète termine à 212 tests réussis.
