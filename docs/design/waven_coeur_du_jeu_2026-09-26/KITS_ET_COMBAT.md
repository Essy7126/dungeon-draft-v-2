# Comprendre les moteurs de combat de WAVEN

26 septembre 2026. Lecture documentaire des cartes et infobulles, pas playtest. Ce dossier traite principalement du système Aventure historique. Les identifiants de sources renvoient au [registre daté](SOURCES.md). Les chiffres de P17 sont ceux de mai 2024 ; les constructeurs peuvent conserver des fiches anciennes.

## 1. L'unité d'analyse pertinente : une chaîne d'événements

Une carte a au moins six propriétés utiles : coût immédiat, cible légale, effet propre, événements produits, ressources générées et position finale. Son nombre de dégâts ne résume qu'une partie de sa valeur.

Pour examiner un build, je reconstruis cette chaîne :

`état initial → action payée → déplacement/attaque/soin → passif → équipement → ressource ou carte générée → prochaine action légale`.

Puis je cherche quatre limites : la ressource qui manque, la case inaccessible, le déclenchement plafonné et l'ennemi qui sanctionne la séquence. Cette lecture explique mieux les différences entre héros qu'un classement de dégâts moyens par PA.

Attention à deux confusions : une attaque n'est pas tout dégât infligé, et un événement de soin n'est pas nécessairement équivalent à une quantité de PV effectivement restaurée. Les textes consultés ne suffisent pas à trancher tous les cas de soin sur cible pleine ou de dégâts indirects. Ces frontières doivent rester des questions de moteur, pas des hypothèses cachées.

## 2. Huit héros, huit moteurs

Les statistiques nues affichées dans les bases donnent cet ordre de grandeur. Elles ne décrivent pas les caractéristiques d'un personnage équipé de niveau 50. Les critiques de Piven divergent entre bases et ne sont pas utilisés ici. [WavenDB](https://wavendb.com/gods), [Waven Build](https://www.waven-build.com/bestiaire/weapons).

| Héros | PV affichés | ATK affichée | PM affichés | Ressource tactique à examiner |
|---|---:|---:|---:|---|
| Pikuxala | 394 | 28 | 3 | Téléportations réussies et alignements |
| Justelame | 387 | 32 | 3 | Armure disponible au moment du déclenchement |
| Kasaï | 399 | 32 | 3 | États élémentaires et auras Épée |
| Apostruker | 402 | 22 | 3 | Événements de soin et lignes de tir |
| Piven | 385 | 20 | 3 | Auras accumulées puis libérées |
| Pramium | 392 | 28 | 3 | Mécanismes vivants et attaques des compagnons |
| Orishi | 398 | 24 | 3 | Assemblage et activation des pièges |
| Sourokan | 398 | 28 | 3 | Déclenchement des pièges et position d'arrivée |

### Pikuxala : le trajet devient une attaque

P17 fixe le passif PvE à 60 % de l'ATK contre les ennemis alignés jusqu'à deux cases, par téléportation. Quatre options l'orientent : Instabilité augmente temporairement l'ATK ; Efficacité crée de la réserve ; Maîtrise échange des positions et obtient Poussette ; Puissance fournit un Cadran et des Failles. P20 précise que Poussette nécessite un échange réussi. [0.17](https://forum.waven-game.com/en/44-patchnotes-fr/5428-version-17-fr), [0.20](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr).

**Mon analyse.** Il faut distinguer le nombre de téléportations du nombre de contacts utiles. Sur un plateau théorique 7 × 7, cette croix couvre huit cases au centre, quatre dans un coin. Deux déplacements peuvent toucher quatre fois au total, une fois, ou aucune. Un bonus de déplacement peut donc augmenter le rendement sans changer les dégâts imprimés d'une carte.

Avec ATK constante 203, deux téléportations touchant chacune deux ennemis produisent `203 × 0,60 × 2 × 2 = 487,2` dégâts bruts de passif. C'est un scénario géométrique, hors Instabilité, protection et arrondis, pas un résultat observé en jeu.

Saut à 3 PA permet un aller-retour. Avec Efficacité et deux événements réussis, deux PA de réserve sont créés : coût net éventuel d'un PA, **mais trois PA restent nécessaires au départ**. Le temps de conversion et le choix de ce passif constituent des coûts. Un retour sur case occupée ou un échange invalide doit être traité avant de promettre la boucle.

L'intérêt tactique existe si plusieurs destinations restent concurrentes : dégâts immédiats, protection d'un allié, maintien d'une ligne, éloignement d'un danger. Si le même aller-retour domine partout, la mobilité devient une formalité répétée.

### Justelame : conserver sa défense peut produire de l'offensive

Le constructeur décrit une acquisition d'armure par Mêlée, plafonnée une fois par tour pour le passif de base. Les quatre options portent sur une frappe utilisant 65 % de l'armure, une acquisition selon les ennemis proches, un gain d'ATK à la perte d'armure, et une émission de fin de tour à 30 %. Ce sont des options de construction, pas quatre effets supposés actifs ensemble. [Fiches Waven Build](https://www.waven-build.com/bestiaire/weapons).

**Mon analyse.** L'armure est à la fois protection et base de plusieurs effets. Un monstre qui l'entame peut donc retirer de l'offensive future. À l'inverse, une lecture de l'armure qui ne la consomme pas bénéficie plusieurs fois du même investissement. Comparer ce héros à une dépense de garde exige de suivre le stock restant après chaque action.

Le correctif 0.20 réduit Anneau Fer de 20 % à 15 % des PV max et plusieurs bonus d'armure de 20 % à 10 %. [Note officielle](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr).

Dans un scénario à 2 000 PV, avec quatre bonus supposés additifs et sans autre modificateur :

| Quantité modélisée | Avant | Après |
|---|---:|---:|
| Armure provenant de ce montage | 720 | 420 |
| Supplément de frappe à 65 % | 468 | 273 |
| Émission à 30 % | 216 | 126 |

La baisse composée vaut **41,67 %** pour ces composantes, contre 25 % pour l'effet de base de l'anneau pris isolément. Ce n'est ni une mesure du DPS total du héros ni une preuve de l'ordre réel des bonus : c'est une sensibilité conditionnelle à vérifier dans le client.

### Kasaï : fabriquer, conserver ou consommer un état

Les fiches associent application d'état et aura Épée. Attaque permet une attaque supplémentaire lors de la consommation d'un état, une fois par tour ; Explosion récompense son application ; Puissance valorise les auras possédées ; Surcharge relie les sorts élémentaires de coût élevé à l'application. P23 précise une cible ennemie pour cette dernière. [Fiches](https://www.waven-build.com/bestiaire/weapons), [0.23](https://forum.waven-game.com/en/44-patchnotes-fr/6463-version-23-fr).

**Mon analyse.** La décision intéressante est le moment de consommation : bénéficier immédiatement d'une attaque, ou maintenir une condition pour un autre effet. Les états ne sont plus seulement des dommages différés. Le plafond par tour empêche de lire chaque nouvelle application comme une nouvelle attaque gratuite.

Le coût imprimé d'un sort ne suffit pas non plus à décider s'il qualifie un déclencheur de coût : coût de base ou coût payé après réduction ? Sans test, ne pas transformer une réduction de PA en certitude de combinaison avec Surcharge.

### Apostruker : le soin peut être un événement offensif

P17 donne 50 % de l'ATK sur les ennemis alignés à chaque soin du héros. Apostrocius, Maîtrise, Puissance et Soin modifient respectivement les auras, la montée en puissance, les effets autour des attaques et la transmission des soins alliés au passif. [Note 0.17](https://forum.waven-game.com/en/44-patchnotes-fr/5428-version-17-fr).

**Mon analyse.** Un petit soin répété peut créer davantage de déclenchements qu'un gros soin unique. Mais il ne faut pas compter gratuitement tous les soins de l'équipe : sélection du passif, bénéficiaire, ordre et validité de l'événement importent. Les mentions de « VIE » ne sont pas automatiquement des PV maximum.

Il faut mesurer trois rendements séparés : PV réellement restaurés, dégâts secondaires utiles, et temps réel consommé par les animations. Le classement Guidactik signale justement une lenteur d'animation pour Apostruker malgré son efficacité de farm. Cela ne prouve pas un temps universel par combat. [Retour d'essais](https://guidactik.com/waven/quelle-classe-choisir-sur-waven-tier-list/).

### Piven : l'ordre de libération change la valeur du stock

Les options lues sont Audace, Maître, Ciblage et Renforcement. Elles étendent les cibles ou les dégâts des libérations et peuvent accroître l'ATK au fil de celles-ci. Le guide de Seyeshean prépare cinq Mires Motivantes puis Artillerie, avec Renforcement et Audace, pour un tour de décharge et de financement. Ataraxie, Carquois et Recharge servent l'accès ou la préparation ; le placement recherche plusieurs ennemis alignés. [Guide détaillé](https://guidactik.com/waven/guide-et-build-cra-arc-piven-sur-waven/), [fiches de passifs](https://www.waven-build.com/bestiaire/weapons).

**Mon analyse.** Le stock d'auras vaut aussi ce qu'il rend possible après sa libération. Un remboursement peut prolonger la séquence ; il ne rend pas le coût de préparation nul. La fragilité est temporelle : délai de mise en place, main, ennemis survivants et alignement au tour de décharge.

Avec cinq libérations à 60 % et une ATK fixe A, on obtient `3A` par cible touchée cinq fois. Supposons maintenant, **uniquement pour illustrer l'ordre**, une augmentation additive de `0,5A` par libération : appliquer le gain après chaque effet donne `6A`, avant chaque effet `7,5A`. Ce ne sont pas les coefficients calculés du vrai build. L'écart montre pourquoi une fiche de passif ne remplace pas un journal de résolution. La 0.19 contient précisément un correctif d'interaction Audace/Renforcement. [Correctif](https://forum.waven-game.com/en/44-patchnotes-fr/5880-version-19-fr).

### Pramium : investir sur le plateau pour multiplier les activations

Les options lues relient construction des Sinistros aux jauges, attaques des compagnons aux activations, Activation au rejouement d'un compagnon, et apparition des compagnons à la transformation des mécanismes. [Fiches Pramium](https://www.waven-build.com/bestiaire/weapons).

**Mon analyse.** Avec l'option correspondante, quatre mécanismes et trois attaques de compagnons représentent douze occasions d'activation. Ce n'est pas douze effets garantis : les mécanismes doivent exister, rester valides et avoir un effet disponible. Leur occupation du terrain et leur survie sont des coûts.

Il faut suivre les investissements dans cet ordre : cartes et PA de pose, ressources d'invocation, délai avant rendement, activations utiles, perte lors de la destruction. Le héros est particulièrement sensible au niveau des compagnons ; le classement de joueurs le relève aussi. Une version avec invocations fragiles ne peut pas être extrapolée à partir d'un build complètement amélioré. [Retour d'essais](https://guidactik.com/waven/quelle-classe-choisir-sur-waven-tier-list/).

### Orishi et Sourokan : une zone posée n'est pas encore une action gagnée

Orishi dispose d'options de collision, de bonus selon les pièges posés, de dégâts d'assemblage et de réduction de main après un assemblage assez grand. Sourokan propose téléportation offensive au déclenchement, dégâts autour des pièges, génération et renforcement de pièges. Les valeurs de Sourokan divergent selon la version : aucun coefficient actuel n'est arbitré ici. [Fiches](https://www.waven-build.com/bestiaire/weapons).

**Mon analyse.** Il faut distinguer pose, regroupement, déclenchement, destruction et case d'arrivée. Un piège puissant mais jamais activé est un investissement perdu ; un piège faible qui force un détour peut déjà modifier le combat. Pour juger ces kits, le nombre de pièges actifs importe moins que le nombre de réponses ennemies réellement modifiées.

## 3. Un deck lu carte par carte

Fixture : [« test » de Fluffy](https://www.waven-build.com/builds/10898). Son ancienneté affichée est incohérente ; je ne lui attribue pas une réputation d'expert. Les valeurs ci-dessous sont celles affichées avec le curseur 50, dans ce contexte de construction. Elles ne sont pas des dégâts de base garantis à tous les joueurs.

| Sort | PA | Jauges affichées | Valeur / fonction principale relevée |
|---|---:|---|---|
| Téléportation Flexible | 6 | 2 air | Téléportation ≤ 3 ; zone 65 |
| Sinistro Air | 3 | 1 air | Construction ou transformation |
| Téléport Offensif | 4 | 1 air | Téléportation ≤ 2 ; zone 53 |
| Flot Albuera | 3 | 1 eau | 30 ; réserve conditionnelle |
| Harmonie Temporelle | 4 | 1 eau | Téléportation/échange ; soin 22 |
| Saut Pikuxala | 3 | 0 | Aller-retour à une case |
| Téléportation Pikuxala | 6 | 1 éther | Aller-retour ; zone 50 % ATK |
| Bouclier Albuera | 2 | 1 terre | 19 ; bouclier conditionnel |
| Feu Nécrome | 3 | 1 feu | 53 ; drain conditionnel |
| Téléport Compulsif | 3 | 1 feu | 38 puis déplacement |
| Fuite Pikuxala | 4 | 0 | 50 % ATK puis retour |
| Onde Magnétique | 3 | 1 terre | 57 ; état Boueux |
| Choc Temporel | 3 | 1 air | 46 ; état Éventé |
| Flétrissement | 4 | 1 air | 46 ; rebond 49 conditionnel |
| Midi Pile | 3 | 1 feu | 80 |

Le coût imprimé total est 54 PA, soit 3,6 par carte. Ce n'est pas une estimation du nombre de cartes jouables par tour : réserve, génération, réduction, cartes temporaires et disponibilité changent le budget.

**Ce que cette lecture révèle.** Téléport Compulsif endommage avant de déplacer ; Téléport Offensif déplace avant sa zone. Même proximité sémantique, états intermédiaires différents. Saut n'a pas de jauge imprimée mais peut déclencher plusieurs fois le héros. Une carte à dégâts élevés peut donc être moins adaptée à son moteur qu'une carte sans dégâts directs.

Le Pouvoir Pikuxala consulté séparément coûte 2 PA et augmente l'ATK du tour. Il n'est pas compté comme une seizième carte dans la liste. De même, Poussette est une génération à distinguer du deck préparé.

## 4. Équipement, compagnons, niveaux : reconstituer les dépendances

Dans la fixture, les rôles des équipements sont distincts : Âmes exploite une mort par attaque ; Index de Toross convertit les jauges dépensées en ATK, avec plafond ; Cicatrisor fournit un soin de début de tour ; bstiné conditionne une réserve initiale au deck ; Honte de Toross génère Flux de Toross à l'attaque. Une mort par dégâts indirects n'est pas supposée relancer Âmes sans vérification. [Fiches ouvertes dans le build](https://www.waven-build.com/builds/10898).

La présence d'un soin ne suffit pas à prouver une synergie avec un passif d'un autre héros. Il faut reconstruire un build cohérent, avec ses choix exclusifs, plutôt que réunir tous les meilleurs effets du catalogue.

| Compagnon dans la fixture | Coût lu | PV / ATK affichés à 50 | Fonction étudiée |
|---|---|---:|---|
| Champion Croulant | 3 air + 2 terre | 358 / 75 | Échange à l'apparition, pioche |
| Yugo | 7 air | 779 / 163 | Échange à l'attaque, synergies de téléportation |
| Lance Dur | 3 eau + 2 air + 2 feu | 687 / 133 | Repositionnement du héros lié à l'attaque |
| Épinette | 2 air + 2 terre | 338 / 59 | Renouvellement de la main |

Les quatre premières invocations représentent **23 unités de jauge, dont 14 air**. Le total seul masque donc une contrainte de couleur ; conversions, éther et générations supplémentaires exigeraient une trace de partie pour calculer un tour d'invocation. Les effets améliorés des compagnons sont des investissements supplémentaires, pas leurs propriétés gratuites au déblocage.

### Le piège du curseur de niveau

| Affichage du constructeur | Curseur 50 | Curseur 1, mêmes sélections |
|---|---:|---:|
| Bonus PV des équipements | +390 % | +96 % |
| Bonus ATK des équipements | +470 % | +29 % |
| Bonus PV des compétences | +50 % | +50 % |
| Bonus ATK des compétences | +155 % | +155 % |
| Points sélectionnés | 250/250 | 250/250 |
| PV résultants | 2 128 | 969 |
| ATK résultante | 203 | 80 |

Reconstruction exacte de l'affichage, avec arrondi final :

- `394 × (1 + 3,90 + 0,50) = 2 127,6 → 2 128` ;
- `28 × (1 + 4,70 + 1,55) = 203` ;
- `394 × (1 + 0,96 + 0,50) = 969,24 → 969` ;
- `28 × (1 + 0,29 + 1,55) = 79,52 → 80`.

Cela établit une cohérence **du constructeur pour ce montage**. Cela n'établit ni une courbe de progression débutant, ni l'ordre des bonus temporaires du moteur. Les runes restent sélectionnées : 2 910 d'équipement et 1 100 de compagnons, zéro de sort dans cette fixture. Le coût en kamas affiché à 50 est 1 070 300 ; sans taux de gain ni réemploi du compte, aucune durée de farm n'en est déduite.

Une analyse de niveau doit donc séparer niveau du héros, points investis, niveau des cartes/objets/compagnons, runes et ressources déjà possédées. Dire seulement « niveau 50 » masque une grande part de la puissance et du confort.

## 5. Critique : puissance moyenne contre fiabilité

Le joueur ErgotthAE décrit un Pikuxala qui multiplie les téléportations, revendique 359 puis 420 ATK selon la séquence, et environ 45 % de critiques presque triplés. Il signale aussi une faible production de jauges et donc un faible recours aux compagnons. Le témoignage expose un compromis, pas seulement un score spectaculaire. [Message complet](https://www.reddit.com/r/Waven/comments/1jfb4d6/fun_simple_pikuxala_build/).

En prenant **pour illustration** 359 ATK, 45 % et un multiplicateur exactement égal à 3 : l'espérance vaut 682,1, le pic 1 077. Une cible hypothétique à 800 PV n'est pourtant éliminée par cette attaque que dans 45 % des cas, avant protections. Deux attaques indépendantes donnent 69,75 % de chances d'avoir au moins un critique ; deux non-critiques ne font que 718.

Le choix de finir une cible et celui de maximiser les dégâts moyens peuvent donc s'opposer. Pour comparer deux builds, il faut suivre les seuils de mort, les ennemis laissés actifs, le risque du tour suivant et le temps réel, en plus des dégâts.

Calculs et vérifications : [script](calculs.mjs), [résultats JSON](CALCULS.json). Les modèles d'ordre de résolution et de critiques sont explicitement hypothétiques.
