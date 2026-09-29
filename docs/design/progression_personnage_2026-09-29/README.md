# Monter un personnage dans Dungeon Draft

29 septembre 2026 — proposition acceptée sous le nom **Prototype v1** et intégrée dans la run Cartes existante. Le [contrat courant](../../current/prototype_v1.md) décrit l'implémentation ; les résultats et l'audit ci-dessous conservent leur référence historique, antérieure à cette intégration. Cette étude prolonge les [fondations communes des statistiques et des cartes](../fondations_stats_cartes_2026-09-28.md). [Enquête comparative et sources](RECHERCHE.md), [parcours niveau par niveau](PARCOURS.md), [résultats chiffrés](CALCULS.json), [script reproductible](calculs.py).

## 1. La proposition

Le personnage se construit par une **classe permanente**, des **maîtrises élémentaires investies à chaque niveau**, quelques **aptitudes générales**, des **perfectionnements de sorts**, et les **cartes/équipements obtenus pendant la traversée**. Les éléments restent accessibles à toutes les classes. Aucun couple élémentaire ne demande un talent spécial ou une combinaison prédéfinie pour fonctionner.

Le budget est fini et commun : douze niveaux, 26 points élémentaires, trois points d'aptitude, une spécialisation de classe, trois emplacements de perfectionnement. Les cartes et l'équipement apportent les occasions d'exploiter ces choix. Les paramètres ci-dessous constituent une configuration précise à essayer ; ils ne sont pas présentés comme un équilibrage validé.

## 2. Ce que fait réellement notre run aujourd'hui

Audit sur HEAD `86018f9c7ea0f13f1dde868b6fcafe95e8b620f1`, avec empreintes des sources dans CALCULS.json. Des modifications étrangères à cette étude existaient dans le workspace ; elles ont été préservées.

- Les onze premières victoires donnent chacune un niveau. Le niveau 12 est atteint après le combat 11, à la profondeur 17, **avant** Pâris à la profondeur 20. Le total effectivement versé est 2 440 XP. Les 345 XP du dernier rang du catalogue ne sont pas attribués par l'économie au boss.
- Les attributs actuels distribuent six points au total entre Power, Vitality et Resolve. La spécialisation arrive au niveau 4 et les améliorations de famille aux niveaux 4, 8 et 12.
- La Puissance de base passe de 18 à 112 ; les PV de 110 à 675. Une hausse de niveau ajoute aux PV courants la hausse du maximum : elle conserve la quantité absolue de PV manquants, sans soigner intégralement.
- Une copie jouée disparaît pour la run. Les améliorations de famille s'appliquent aux copies présentes et futures ; c'est une base utile à conserver.
- Le personnage dispose de quatre PA, trois PM, une main initiale de cinq, six emplacements d'équipement et deux de relique. L'attaque de secours est encore commune dans ce système : l'identité permanente des classes reste un chantier à réaliser.

Sources : [catalogue](../../../data/cards/consumable_v2/catalog.json), [état](../../../core/expedition/consumable_cards_state.gd), [économie](../../../core/expedition/consumable_card_economy.gd), [intégration](../../../core/expedition/consumable_cards_integration.gd), [route v6 active](../../../core/expedition/catabase_route_v6.gd). Cette lecture ne prouve pas une exécution en jeu.

## 3. Création et montée de niveau, exactement

**Au départ :** choisir sa classe, disposer de son attaque de base propre et de son passif, recevoir quatre points élémentaires. Le kit de départ doit permettre d'exploiter les orientations proposées à l'écran ; afficher six maîtrises si plusieurs n'ont aucun répertoire normal jouable serait trompeur. Le joueur peut conserver des points sans les dépenser. La classe ne change pas pendant la run.

**Après chaque victoire des combats 1 à 11 :** recevoir la récompense XP actuelle, gagner le niveau, appliquer sa croissance de base et recevoir deux points élémentaires. Les points sont dépensables pendant la préparation, jamais pendant le combat. L'écran montre le résultat avant/après sur les cartes possédées, et non seulement une nouvelle valeur de statistique. On peut grouper plusieurs affectations puis valider une transaction atomique.

| Niveau | Décision nouvelle, en plus de +2 points élémentaires dès le niveau 2 |
|---|---|
| 1 | Classe, noyau permanent, quatre points de départ |
| 2 | Première adaptation au butin |
| 3 | Première aptitude générale |
| 4 | Spécialisation de classe + premier perfectionnement |
| 5 | Consolidation ou ouverture d'un autre élément |
| 6 | Deuxième aptitude générale |
| 7 | Consolidation ou ouverture |
| 8 | Deuxième perfectionnement ; réorientation complète disponible au refuge suivant |
| 9 | Troisième aptitude générale |
| 10 | Consolidation ou ouverture |
| 11 | Dernier refuge ordinaire accessible après la montée |
| 12 | Troisième perfectionnement, puis préparation finale avant le boss |

Les mentions « consolidation ou ouverture » décrivent des possibilités, pas des choix obligatoires ni une rotation. Le [tableau généré](PARCOURS.md) donne budgets cumulés, combats, profondeurs et XP. Il n'y a aucun point d'élément attribué pour utiliser une carte, tuer une invocation ou terminer un combat lentement.

## 4. Investissement élémentaire : même prix, gain décroissant

Palette de travail : Terre, Eau, Feu, Vent, Nuit, Soleil. Les noms et la couverture de contenu restent à finaliser ; la règle ne dépend pas de six domaines exactement.

Dans chaque élément, un point acheté donne :

- points 1 à 4 : **+3 points de pourcentage** de maîtrise par point ;
- points 5 à 8 : **+2 points de pourcentage** ;
- à partir du point 9 : **+1 point de pourcentage**.

Un point coûte toujours un point de progression. Le rendement se calcule **par élément**, jamais sur la somme des investissements. Ainsi quatre points donnent +12 %, huit donnent +20 %, treize +25 %, vingt-six +38 %. Les bonus d'objets s'ajoutent ensuite et ne font pas franchir artificiellement les tranches d'achat. Le prochain gain est affiché : « 8 investis · +20 % · prochain point +1 % ».

Le niveau 12 donne les comparaisons suivantes, hors objets et aptitudes :

| Répartition des 26 points | Bonus obtenus | Base 20 du premier élément | Base 20, moitié premier/moitié deuxième |
|---|---|---|---|
| 26 / 0 | +38 % / 0 % | 27,6 | 23,8 |
| 13 / 13 | +25 % / +25 % | 25 | 25 |
| 9 / 9 / 8 | +21 % / +21 % / +20 % | 24,2 | 24,2 |
| 5 / 5 / 4 / 4 / 4 / 4 | +14 % / +14 % / +12 % × 4 | 22,8 | 22,8 |

Le monoélément possède le meilleur plafond sur son domaine ; l'hybride a de meilleurs résultats sur un répertoire partagé. Un sort utilitaire sans élément conserve son intérêt. La différence mono/bicolore sur un sort pur reste ici d'environ 10,4 % : c'est une segmentation modérée, à mesurer face à la valeur réelle des effets utilitaires et des équipements.

**La répartition égale n'est pas une obligation.** L'énumération de toutes les allocations sur deux domaines donne 18/8 comme optimum pour une contribution de base répartie à 65/35. À 80/20, elle donne 26/0. À 50/50, plusieurs répartitions entre 8/18 et 18/8 sont équivalentes dans ce modèle linéaire des effets. Le catalogue, les besoins de garde/soin et l'équipement départagent ensuite ces possibilités. Ces poids mesurent une contribution de base pertinente, pas simplement le nombre de cartes dans le deck ; on ne somme pas arbitrairement PV soignés et dégâts infligés comme une même utilité.

**Pourquoi ce modèle ?** À 26 points, une règle linéaire de +2 % donne +52 % en mono contre +26 % dans chacun de deux domaines. Des coûts par rang croissants de 1/2/3 donnent un arbitrage comparable à notre proposition, mais peuvent laisser des points temporairement inutilisables. Nous retenons les gains décroissants pour obtenir un choix à chaque montée, sans un deuxième compteur de prix. Les cassures de pente à 4 et 8 sont des réglages de rendement, pas des portes vers des capacités.

## 5. Aptitudes : préciser un personnage à éléments identiques

Un point aux niveaux 3, 6 et 9, dans un budget séparé. Quatre aptitudes initiales, accessibles à toutes les classes, jusqu'à trois rangs chacune :

| Aptitude | Gain par rang du prototype | Effets admissibles |
|---|---|---|
| Vitalité | +8 % PV maximaux de base | PV maximaux, hors multiplicateur élémentaire |
| Protection | +10 % de garde créée | Quantités originales de garde |
| Contact | +6 % de dégâts directs au contact | Distance réelle 1 |
| Distance | +6 % de dégâts directs à distance | Distance réelle au moins 3 |

Les trois points peuvent aller dans une seule aptitude ou plusieurs. À distance 2, ni Contact ni Distance : conserver le contrat actuel tant qu'une décision distincte ne le remplace pas. Les effets périodiques n'obtiennent pas ces deux bonus dans ce prototype. Une conversion ou un drain n'amplifie pas deux fois une même quantité déjà calculée.

Cette liste est volontairement petite et extensible. Une aptitude Soin, Zone ou Périodique peut arriver quand assez de contenu la rend réellement comparable. Elle n'est pas débloquée par une combinaison d'éléments. Le choix de Protection ou Vitalité reste possible pour toutes les classes ; leur rendement réel doit être confronté aux dommages évités, aux soins disponibles et à la durée des combats.

Les PA, PM et taille de main ne sont pas distribués à chaque niveau. Un PA supplémentaire représente 25 % de budget d'action de base, sans garantir 25 % de dégâts ; sa valeur combinatoire exige un budget spécifique. Conserver les sources exceptionnelles existantes et les examiner séparément.

## 6. Classe, spécialisation et perfectionnements

**Classe.** L'attaque permanente, le passif et la spécialisation donnent une identité après consommation des cartes de départ. La maîtrise d'un élément ne convertit pas automatiquement cette attaque : elle n'agit que sur ses composantes déclarées. Un personnage doit pouvoir exploiter une orientation avec ses cartes même si son attaque de base ne la couvre pas ; cela impose un contrôle du contenu initial et des récompenses, pas un verrou de classe.

**Spécialisation.** Conserver le choix au niveau 4 parmi les deux propositions de la classe. Ne pas demander des investissements élémentaires pour y accéder. Les spécialisations actuelles doivent être relues avec les nouvelles formules.

**Avantage natif.** Le bonus sur l'origine de classe reste une option de la fondation précédente. Le premier essai chiffré ci-dessous utilise **0 % de bonus natif supplémentaire**, pour isoler l'effet des nouvelles maîtrises. Une variante à +10 % est mesurée séparément. Ce n'est ni un abandon de l'identité des classes, ni la validation d'un nouveau multiplicateur gratuit.

**Perfectionnements.** Conserver les paliers 4/8/12, mais les représenter par un, puis deux, puis trois emplacements affectés à des familles de sorts différentes. Un emplacement améliore toutes les copies actuelles et futures tant qu'il est affecté. Aucun cumul sur une même famille ; seuls les perfectionnements déjà définis pour chaque sort sont utilisés.

À chaque préparation hors combat, le joueur peut les réaffecter gratuitement à une famille possédée, ou laisser un emplacement sur une famille temporairement épuisée. Retirer une affectation retire son amélioration ; cela ne rembourse aucune copie et ne produit aucune carte. Les familles perdues restent visibles pour comprendre la mémoire de la run, mais l'affectation d'un nouvel emplacement exige au moins une copie possédée. Cette souplesse évite d'enfermer un investissement dans des consommables disparus. Elle remplace pour cette fonction l'actuel paiement de 35 oboles ; on ne garde pas deux systèmes concurrents.

## 7. Réorientation : s'adapter sans reconstruire avant chaque ennemi

- Avant le premier combat : répartition libre des points de départ.
- À chacune des haltes des profondeurs 4, 7, 9, 11, 14, 16, 18 et 19 : possibilité de déplacer **jusqu'à deux points élémentaires déjà investis**, gratuitement, une fois par visite. Les corrections inutilisées ne s'accumulent pas. Validation en une transaction ; rouvrir l'écran ou recharger ne rend pas ce droit.
- À partir du refuge de profondeur 11, après le combat 7 et au niveau 8 : **une réorientation complète pour la run**, utilisable là, au refuge de profondeur 16 ou à la préparation finale de profondeur 19. Elle rend tous les points élémentaires et d'aptitude, permet de rechoisir la spécialisation, mais conserve la classe. Le droit peut être gardé pour plus tard. Au niveau 8, on dispose déjà de 18 des 26 points élémentaires et de deux aptitudes : le choix a donc de la matière.
- Les nouveaux points non dépensés restent allouables dans toute préparation. Les perfectionnements ont leur souplesse propre, définie plus haut.

La préparation de profondeur 19 n'attribue pas de récompense ordinaire : cette proposition y ajoute seulement une possibilité explicite de correction. Les deux haltes finales autorisent ainsi jusqu'à quatre déplacements mineurs avant le boss ; c'est voulu dans ce prototype et à mesurer, pas une omission.

Changer Vitalité, équipement ou spécialisation ne soigne pas : conserver le ratio de PV dans une représentation non arrondie, puis arrondir uniquement l'affichage/la résolution prévue. Le soin lié au premier gain de niveau reste distinct et attribué une seule fois. Il faut tester les cycles d'activation et de retrait pour exclure tout soin gratuit.

## 8. Budget de puissance : remplacer, puis mesurer

La courbe actuelle multiplie déjà la Puissance de base par 6,22. Les maîtrises **remplacent Power**, et les aptitudes **remplacent Vitality/Resolve** dans ce prototype. On ne conserve pas les anciens points en supplément. Les bonus élémentaires et spécialisés applicables sont additionnés selon les fondations du 28 septembre ; les calculs ci-dessous excluent équipement, passif, spécialisation, défense et arrondi final.

À niveau 12, pour un effet direct de coefficient 1 :

- ancien investissement de six points Power : `112 × 1,30 = 145,6` ;
- nouvelle maîtrise mono seule : `112 × 1,38 = 154,56` ;
- avec trois Contact applicables : `112 × (1 + 0,38 + 0,18) = 174,72`, soit **+20 %** contre la première référence ;
- si l'on ajoutait encore +10 % natif : `185,92`, soit **+27,7 %** contre cette référence.

Le premier essai utilise donc une courbe de Puissance de référence **16, 20, 23, 28, 34, 40, 47, 57, 66, 82, 86, 93**, calculée en ramenant à chaque niveau le maximum mono + Contact vers l'ancien maximum Power, avant arrondi. Ce choix fournit un point de départ contrôlé ; il ne maintient pas tous les profils à égalité. Par exemple, le secours sans élément, les soins et la garde peuvent évoluer différemment. Les équipements actuels n'ont pas tous la même règle de cumul que le modèle proposé.

Pour le premier essai, les PV de base gardent leur courbe actuelle. Trois Vitalité donnent 837 PV au niveau 12, contre 918 pour six Vitality actuels. Le nouveau personnage dispose en parallèle de ses maîtrises : il ne s'agit pas d'une baisse globale de 8,8 % de son efficacité. Les soins de montée, la garde, les dégâts ennemis et la durée des combats doivent être évalués ensemble.

**Limite mathématique.** Les moyennes d'effets ne démontrent pas une victoire. L'économie de PA, les seuils de mise à mort, la portée, la géométrie, l'overkill, la consommation des cartes et les états ennemis déterminent la valeur tactique. Aucune probabilité de victoire n'est annoncée par cette étude.

## 9. Équipement, butin et progression entre runs

Les six emplacements et deux reliques restent une autre source de construction. Un objet peut donner une maîtrise élémentaire et un bonus conditionnel sans créer une nouvelle statistique pour chaque famille de sort. Les gains d'objets ne sont pas des points investis : ils ne changent ni le coût ni les droits de remboursement. Pas d'XP séparée pour chaque objet dans ce premier système.

Une montée augmente la compétence du personnage, pas la rareté de toutes ses cartes. La rareté contrôle disponibilité et budget d'effet ; le perfectionnement conserve son propre axe. Les offres de cartes doivent garantir des possibilités normales jouables, puis proposer aussi des emprunts. Adapter toutes les offres exactement au build supprimerait l'intérêt de la réorientation. Le réglage des offres est un chantier de contenu explicitement nécessaire, pas une règle déjà implémentée.

Entre deux runs, proposition : retour au niveau 1, réinitialisation des investissements, spécialisation, copies, équipement de run et perfectionnements ; conservation du codex, des découvertes et des options de départ débloquées. Ces options ont un budget comparable aux options initiales. Une progression permanente de puissance pourrait constituer plus tard un mode assumé d'accessibilité/progression, avec sa propre courbe. Ce document ne prétend pas décrire exhaustivement les sauvegardes de compte actuelles.

## 10. Ce qui rendra cette proposition prête à intégrer

1. Cartographier les composantes des sorts, compléter les orientations de départ réellement offertes, et donner une attaque permanente distincte à chaque classe.
2. Ajouter les maîtrises, leurs aperçus et l'allocation dans l'état Catabase existant ; migrer ou rembourser explicitement les anciens attributs, sans inventer une seconde run.
3. Réutiliser les services d'amélioration, d'équipement, de halte et du Studio ; modifier les règles d'affectation et de remboursement au même endroit que leurs validateurs.
4. Unifier calcul, prévisualisation, effets différés et sérialisation. Couvrir hybrides, utilitaires, drain, conversion, garde, arrondis et sauvegarde/rechargement.
5. Mesurer des parcours complets : mono/bicolore/tricolore, aptitudes offensives/défensives, répertoire favorable/défavorable, épuisement des familles et corrections. Examiner temps de combat, PV perdus, consommation, choix de récompense et compréhension des montées.

Le changement du moteur commun exigera les validations CI et les tests de combat/cartes adaptés au périmètre. Ils ne sont pas lancés dans cette étude documentaire. Les vérifications présentes portent sur les données lues, les calculs, les liens locaux et les interactions du simulateur. La fiche de suivi est [ici](../../ai/PROGRESSION_PERSONNAGE_2026-09-29.md).
