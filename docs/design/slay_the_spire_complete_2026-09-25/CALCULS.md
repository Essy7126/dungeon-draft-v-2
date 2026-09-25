# Calculs et contre-exemples

Calculs déterministes isolés ; pas moteur StS, pas simulation complète de run, pas validation humaine du plaisir. Les contrats proviennent des [lectures de cartes](README.md) et des [règles transversales](EFFETS_ET_REGLES.md).

47 scénarios, 50 assertions, 3003 mains énumérées pour recouper les probabilités.

Les dégâts supposent des cibles vivantes, sans résistance ou protection non indiquée. Les simulations de poison supposent aucune purge, aucun plafond de pertes de PV et aucune mort avant les tics comptés. Les hypothèses économiques ne remplacent pas les résultats de la V1 existante.

| Cas | Hypothèse | Résultat | Ce que le calcul permet de conclure |
|---|---|---|---|
| M01 | Strike, Force 3, Faible et Vulnérable, aucune autre règle. | 10 | Le résultat est arrondi en entier après les multiplicateurs de cet exemple. |
| M02 | Trois impacts de base 1, cible Vulnérable. | 3 | Arrondir le total donnerait 4 à tort ; chaque impact est un calcul. |
| M03 | Twin Strike normal, Force 3. | 16 | La Force apporte 6 sur deux impacts. |
| M04 | Pummel normal, Force 3. | 20 | La même Force apporte 12 sur quatre impacts. |
| M05 | Sword Boomerang amélioré, Force 3, une cible. | 24 | Quatre impacts ; la source automatique incorrecte 4 × 3 coups aurait donné 21. |
| M06 | Heavy Blade amélioré, Force 3. | 29 | Coefficient de Force 5, mais une seule frappe. |
| M07 | Blade Dance normale, tous les Shiv passent. | 12 | Une carte de départ engendre trois attaques supplémentaires. |
| M08 | Blade Dance normale avec Accuracy normal déjà installé. | 24 | Le pouvoir double ici le résultat, au prix de son installation. |
| M09 | Blade Dance+ avec Accuracy+ installé ; Shiv eux-mêmes non améliorés. | 40 | Ne pas confondre amélioration du producteur et du jeton. |
| M10 | Même situation, jetons également améliorés par un effet distinct. | 48 | Master Reality affecterait un axe supplémentaire. |
| M11 | Ancienne paire normale avant 2.2 : 2 Shiv, Accuracy +3 ; nouvelle : 3 Shiv, +4. | {"avant":14,"apres":24} | Deux petits changements combinés : +71,43 % sur cet exemple conditionnel. |
| M12 | Disarm normal contre cinq frappes de base 6. | {"sans":30,"avec":20} | Réduction totale 10, contre seulement 2 sur un impact unique. |
| M13 | Piercing Wail normal contre cinq frappes de base 6. | 0 | Réponse spectaculaire à un profil précis, pas une réduction proportionnelle universelle. |
| M14 | 5 Poison, cinq activations de la cible, aucune purge. | 15 | Somme finie ; la durée nécessaire compte. |
| M15 | 7 Poison, sept activations de la cible. | 28 | Passer de 5 à 7 ajoute 13 dégâts seulement si tous les tics arrivent. |
| M16 | Même 7 Poison mais combat limité aux trois prochaines activations. | 18 | Le total 28 ne décrit pas ce combat court. |
| M17 | 10 Poison puis Catalyst+ avant le prochain tic ; horizon trois activations. | 87 | Puissance multiplicative sous condition préalable. |
| M18 | 10 Poison puis Catalyst+ doublé par Burst ; horizon trois activations. | {"poison":90,"degats":267} | Deux résolutions multiplient successivement, elles n’additionnent pas deux triplements. |
| M19 | Pressure Points normal trois fois sur la même cible, sans Artefact ni purge. | 48 | La marque persiste et se cumule ; elle ne fonctionne pas comme notre marque consommée au prochain impact. |
| M20 | Deux Pressure Points normaux : même cible ou deux cibles. | {"concentre":24,"disperse":24} | Même total brut, répartition et moment de la première mort différents. |
| M21 | 3 Frost, Focus 2, une fin de tour ; aucun autre déclencheur. | 12 | Production passive, pas coût récurrent de cartes. |
| M22 | Consume normal : 3 Frost/3 emplacements et Focus 0 deviennent 2 Frost/2 emplacements et Focus 2. | {"avant":6,"apres":8} | La perte d’emplacement peut être rentable, hors éventuelle évocation immédiate. |
| M23 | Même échange à Focus 10. | {"avant":36,"apres":28} | Le même sort dégrade ici la production passive ; comparer le produit capacité × puissance. |
| M24 | Fission+ sur trois Frost à Focus 2. | {"blocage":21,"energie":3,"pioche":3} | Version normale donnerait la même énergie/pioche mais zéro blocage d’évocation. |
| M25 | Ténèbres déjà chargé à 40, Dualcast. | 80 | Ne pas recalculer un second orbe neuf. |
| M26 | Double Energy depuis 3 énergie, normal puis amélioré. | {"normal":4,"ameliore":6} | Le coût d’activation précède le doublement. |
| M27 | Recycle normal depuis 3 énergie, épuise une carte X. | 4 | Le X recyclé vaut l’énergie restante après paiement de Recycle. |
| M28 | Meteor Strike avec 5 énergie, trois emplacements déjà pleins de Plasma. | 6 | Trois évocations financent le futur ; emplacements vides ne donnent pas ce remboursement immédiat. |
| M29 | Expunger de quatre impacts, non amélioré, Force 2, Wrath. | 88 | Il faut encore payer 1 énergie et avoir trouvé le jeton après Conjure Blade. |
| M30 | Eruption+ depuis posture neutre puis Strike normal ; aucune autre règle. | 21 | Eruption frappe avant de passer en Wrath. |
| M31 | Début en Calm, Eruption+ puis Inner Peace depuis Wrath. | {"energieNette":0,"cartesJouees":2} | Avec Rushdown et cycle disponible, la paire peut se rembourser ; la pioche n’est pas garantie sans cette installation. |
| M32 | Tantrum+ depuis neutre, Force 2. | 20 | Les impacts précèdent Wrath ; appliquer ×2 ici serait une erreur. |
| M33 | Halt+ en Wrath, Dextérité 3, sans Fragile. | 24 | Deux gains séparés de blocage, donc deux ajouts de Dextérité. |
| M34 | Mantra initial 0, une Prostrate+ par usage. | 4 | Quatre usages franchissent dix ; le surplus n’est pas un nouveau multiplicateur des attaques. |
| M35 | Searing Blow améliorée n fois, n de 0 à 5. | [12,16,21,27,34,42] | Croissance des gains par amélioration ; investissement de plusieurs feux de camp. |
| M36 | Genetic Algorithm entraîné cinq fois, sans bonus extérieur. | {"normal":11,"amelioreDesLeDebut":16} | Valeur disponible après les cinq usages ; ne pas multiplier rétroactivement une ancienne progression. |
| M37 | 40 blocage conservés, Entrench+, puis Body Slam+ sans bonus. | {"blocage":80,"degats":80,"energie":1} | Hors coûts antérieurs de Barricade et de production ; Body Slam ne consomme pas cette réserve. |
| M38 | Une réponse en trois exemplaires, main 5, deck 15 puis 30, mélange uniforme. | {"deck15":73.63,"deck30":43.35} | Le plafond 30 ne devrait pas devenir une obligation de remplissage. |
| M39 | Deux familles différentes, trois copies chacune ; présence des deux dans main 5. | {"deck15":51.45,"deck30":16.53} | Les combinaisons consommatrices de plusieurs familles deviennent peu fiables dans un grand deck. |
| M40 | StS : 3 cartes retenues et pioche normale 5, cap10 ; hypothèse d’ajout de rétention à notre V1 sans changer son remplissage jusqu’à5. | {"stsMain":8,"v1Main":5} | La rétention n’aurait pas la même productivité ; elle n’est pas déjà implémentée dans notre V1. |
| M41 | Préparation de 30 consommables, neuf copies utiles dépensées par combat, aucun drop entre quatre combats. | -6 | Une capacité de deck ne suffit pas à garantir la survie économique ; ceci n’est pas une simulation de notre run avec drops. |
| M42 | Générateur théorique : chaque jeton consommé crée deux nouveaux jetons, quatre générations, sans limite. | [1,2,4,8,16] | Une limite de provenance ou de déclenchement est nécessaire si ces jetons ont un usage ou une valeur économique. |
| M43 | Amélioration de coût 2→1 dans un tour à 3 énergie, cartes utiles abondantes. | {"avant":1,"apres":3} | Une baisse de coût peut changer le nombre d’actions, pas seulement le rendement marginal. |
| M44 | Time Eater : compteur déjà à10, puis tentative de Blade Dance et ses trois Shiv. | {"actionsAvantFin":2,"actionsVoulues":4} | Une création de plusieurs jetons demande assez de places dans le budget de cartes jouées. |
| M45 | Plafond hypothétique 200 pertes de PV par tour, cible800PV. | 4 | Un plafond force au moins quatre fenêtres de dégâts ; ce calcul ne résout ni les tours adverses ni les remises à zéro. |
| M46 | Soin plafonné aux PV retirés : cible4PV, blocage3, attaque12 ; 20PV manquants au héros. | 4 | Ne pas soigner 9 ou 12 à partir d’une victime qui ne possédait plus que4PV. |
| M47 | Dégât évité par mort : trois cibles, intention8 chacune ; tue une cible avant leur activation. | 8 | Le contrôle de la première mort peut dominer un meilleur total de dégâts répartis. |

Reproduire : `node docs/design/slay_the_spire_complete_2026-09-25/calculs.mjs`. Les valeurs attendues sont fixées dans le script. La reproduction prouve la cohérence de ces calculs, pas l’exactitude de tous les cas limites du client original.
