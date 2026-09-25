# Drops de sacs par monstre — progression standard

**Suite de l'étude :** le [laboratoire de reprise](card_economy_lab/README.md) approfondit cette base avec des recherches, vingt concepts de cartes et des calculs reproductibles. Il corrige les effectifs hypothétiques ci-dessous avec ceux lus dans la route : 32 à 33 monstres pré-boss, au lieu des 43 de l'exemple. La table initiale reste le témoin ; aucune modification du gameplay n'est appliquée.

24 septembre 2026. Proposition théorique corrigée selon la demande utilisateur. Aucun gameplay modifié. Les probabilités et espérances ci-dessous ont été calculées, mais aucun combat ni test joueur ne valide cet équilibrage.

## Intention et périmètre

Chaque monstre possède une table de drops. À sa défaite, il peut produire plusieurs sacs de cartes de différentes qualités. Les cartes normales faibles deviennent abondantes au fil de la run ; les qualités supérieures deviennent progressivement accessibles mais restent nettement plus rares. Les cartes n'ont pas à correspondre aux techniques utilisées par le monstre.

Cette base ne comprend ni prospection, ni maîtrise, ni caractéristique, ni relique, ni performance de jeu, ni bonus de monstre élite, ni protection contre la malchance. On fixe d'abord la progression intrinsèque du butin. L'inspiration Dofus concerne la logique de tables attachées aux monstres ; ces chiffres ne prétendent pas reproduire ses formules ou ses versions.

On conserve comme contexte quinze exemplaires au départ, un deck préparé de trente exemplaires maximum, une réserve séparée et la consommation définitive des exemplaires joués. Les cartes non jouées restent possédées.

## Un sac a un contenu explicite

| Sac | Contenu fixe |
|---|---|
| Normal | 3 cartes normales |
| Élite | 2 cartes élites |
| Rare | 1 carte rare |
| Légendaire | 1 carte légendaire |
| Divin | 1 carte de rang Dieu |
| Immortel | 1 carte immortelle |

Les six rangs constituent une proposition de nomenclature, pas une migration du catalogue actuel. « Élite » qualifie ici la carte, indépendamment du type de monstre.

Pas de second jet de rareté à l'ouverture : un sac rare contient réellement une carte rare. Le hasard restant choisit l'identité dans le catalogue du rang. Pour la base mathématique, tirage uniforme par famille de carte éligible dans ce catalogue ; doublons autorisés. Les exclusions de compatibilité doivent être visibles et leur impact évalué avant implémentation. La disponibilité d'un rang suppose un catalogue suffisamment fourni : ne pas créer six couches de cartes numériques presque identiques pour remplir la table.

Chaque monstre a un jet pour le sac normal A, un autre pour le sac normal B, puis un jet indépendant par qualité supérieure. Il peut donc lâcher deux sacs normaux et un sac rare simultanément. Les pourcentages ne sont pas les parts exclusives d'une même roue et ne doivent pas totaliser 100 %.

## Table standard par monstre

Le numéro de combat est sa position prévue dans la progression, pas un compteur que le joueur peut augmenter en répétant une rencontre. Les douze combats actuels servent de grille de prototype. Tous les monstres éligibles d'un même palier utilisent ici la même table, pour isoler l'évolution standard.

| Jet indépendant | Combats 1–3 | Combats 4–6 | Combats 7–9 | Combats 10–12 |
|---|---:|---:|---:|---:|
| Sac normal A | 55 % | 70 % | 85 % | 95 % |
| Sac normal B | 0 % | 10 % | 25 % | 45 % |
| Sac élite | 5 % | 10 % | 18 % | 28 % |
| Sac rare | 0,5 % | 1,5 % | 4 % | 8 % |
| Sac légendaire | 0 % | 0,1 % | 0,4 % | 1 % |
| Sac divin | 0 % | 0 % | 0,03 % | 0,15 % |
| Sac immortel | 0 % | 0 % | 0 % | 0,02 % |

Un rang fermé à 0 % est explicitement inaccessible à ce stade. Le début conserve une petite possibilité de rare, sans qu'une telle carte soit attendue. La hausse des chances des sacs supérieurs ne remplace jamais les sacs normaux : le joueur gagne à la fois davantage de provisions et davantage d'occasions exceptionnelles.

Le boss utilise la table standard à ce stade d'étude : aucun multiplicateur caché. Sa table spéciale éventuelle sera une autre couche de conception. Son butin ne finance pas les combats précédents et n'entre pas dans le budget avant boss.

## Quantités ressenties par combat

Pour un groupe de m monstres et des probabilités pA et pB : espérance des cartes normales = 3 × m × (pA + pB). Pour les élites : 2 × m × pÉlite. Pour un sac à une carte : m × p.

| Palier | Taille illustrative du groupe | Sacs normaux moyens | Cartes normales moyennes | Cartes élites moyennes | Cartes rares moyennes |
|---|---:|---:|---:|---:|---:|
| Combats 1–3 | 3 | 1,65 | 4,95 | 0,30 | 0,015 |
| Combats 4–6 | 4 | 3,20 | 9,60 | 0,80 | 0,060 |
| Combats 7–9 | 4 | 4,40 | 13,20 | 1,44 | 0,160 |
| Combats 10–12 | 5 | 7,00 | 21,00 | 2,80 | 0,400 |

Les tailles de groupe sont des hypothèses, pas un inventaire des rencontres réelles. Le moteur de calcul devra utiliser la composition effective de chaque combat. À trois monstres constants, la progression des normales reste 4,95 → 7,20 → 9,90 → 12,60 : l'amélioration ne vient donc pas seulement de groupes plus grands.

Une moyenne de 4,95 ne garantit pas cinq cartes. Avec trois monstres au premier palier, la probabilité de zéro sac normal est 0,45³ = 9,1125 %. Le joueur pourrait néanmoins recevoir un sac supérieur. Un départ de quinze cartes amortit une mauvaise récompense sans garantir la solvabilité de tous les combats. Il faut mesurer la probabilité d'épuisement avec les consommations réelles avant de choisir un éventuel filet de sécurité ; aucun filet n'est intégré silencieusement à cette table.

## Rareté sur la run

Exemple analytique : trois combats de trois monstres, puis six combats de quatre monstres, puis deux combats de cinq monstres avant le boss. Total : 43 monstres éligibles. Tous les jets supposés indépendants. Le douzième combat est exclu du financement pré-boss.

| Rang | Nombre moyen d'exemplaires obtenus avant boss |
|---|---:|
| Normal | 125,25 |
| Élite | 13,22 |
| Rare | 1,505 |
| Légendaire | 0,160 |
| Dieu | 0,0186 |
| Immortel | 0,002 |

Ces moyennes totalisent environ 140,16 cartes droppées, auxquelles s'ajoutent les quinze initiales. Elles ne disent rien de la qualité du deck résultant, de sa compatibilité ou du moment où une carte nécessaire arrive.

Pour au moins un drop du rang r : P = 1 − produit sur les monstres de (1 − p_r). Cela donne :

- Rare : 78,78 % des runs de ce scénario.
- Légendaire : 14,84 %.
- Dieu : 1,84 %.
- Immortel : 0,20 %.

Une immortelle est donc un événement de l'ordre d'une run sur cinq cents dans ce scénario ; ce n'est pas une promesse à la cinq-centième run. Si l'on souhaite que chaque joueur en voie régulièrement, ce rang ne peut pas conserver ce taux. Les rangs supérieurs ne doivent pas être nécessaires aux builds ordinaires ou à la victoire. Leur fréquence est une décision de produit, pas seulement une question de puissance.

Ces probabilités concernent n'importe quelle carte du rang. Une carte précise parmi dix références équiprobables est beaucoup plus difficile à obtenir : remplacer p par p/10 dans la formule. À titre illustratif, une légendaire précise serait obtenue dans environ 1,6 % des runs, sous cette hypothèse de catalogue constant.

## Économie induite

La précédente proposition de six cartes garanties par victoire et de paquets au choix est abandonnée. Les mobs sont la source principale de volume. Les marchands servent à remplacer des manques, transformer des doublons et préparer une combinaison.

L'abondance des normales crée un stock de travail. Les élites montent en fréquence jusqu'à fournir plusieurs exemplaires par combat tardif. Les rares peuvent changer un plan ponctuel. Les trois derniers rangs sont des trouvailles exceptionnelles ; l'économie ne doit pas permettre de les fabriquer banalement à partir d'un excédent de normales.

Le plafond de trente concerne le deck, pas les cartes possédées. Un combat tardif peut donner plus de vingt normales : elles rejoignent une réserve empilée par identité. « Tout ouvrir » et « déplacer N exemplaires » sont nécessaires pour éviter des dizaines de manipulations par combat. L'ouverture des sacs est une présentation de résultat, pas un moyen de relancer la génération. Leur contenu est enregistré une fois.

Première conséquence sur les prix : une normale ne peut plus conserver une revente élevée sans injecter beaucoup d'or. À une obole la normale, le flux normal du scénario représente 125,25 oboles de valeur brute potentielle ; à deux, 250,50. Ce n'est pas un revenu net : les cartes consommées ne se vendent plus. Fixer le prix seulement après avoir mesuré le surplus réellement vendable et les autres revenus.

Une normale ciblée pourrait rester payante malgré l'abondance générale : on paie son identité précise. Le troc entre normales peut aussi réparer un stock, mais la fusion automatique normale → élite → rare → légendaire supprimerait la rareté des derniers rangs. Elle est exclue de cette base.

Une carte normale est faible par exemplaire, pas nécessairement inutile tardivement. Elle doit encore permettre une petite protection, un déplacement, une préparation ou une attaque peu coûteuse. Si leur efficacité devient nulle, augmenter leur drop fabrique seulement des déchets. À l'inverse, si elles remplacent parfaitement les cartes rares avec les mêmes coûts en PA, le haut de la table perd son intérêt.

## Contrat technique et étapes suivantes

Le catalogue de drop actuel fait des jets au niveau du nœud et utilise notamment une mémoire de sécheresse. Il ne représente donc pas encore cette base par monstre. Une implémentation demanderait une liste de monstres éligibles, leurs identifiants de butin et le palier de rencontre ; les invocations ou résurrections ne produisent pas de nouveaux droits à récompense.

Les drops sont crédités une seule fois, normalement au bilan de victoire, tout en restant attribués à chaque monstre dans le journal. Recharger ou rouvrir un sac ne relance pas les jets. Le traitement d'une fuite devra être défini si cette action existe ; il ne faut pas permettre de tuer le même monstre et de récupérer son butin plusieurs fois.

Avant toute couche de bonus : vérifier les effectifs réels ; mesurer consommations et PA par combat ; calculer les distributions de stock et le risque d'épuisement ; mesurer l'utilité et la revente des normales ; tester la lisibilité des sacs. Une moyenne globale positive n'est pas une validation de survie en début de run.

La maîtrise, la prospection, les caractéristiques, les reliques et la manière de jouer viendront ensuite comme couches explicites. Aucun de ces effets n'est nécessaire pour lire, reproduire ou équilibrer la table standard ci-dessus.
