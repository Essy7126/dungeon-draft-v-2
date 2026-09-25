# WAKFU : lecture de 55 sorts et passifs

Lecture directe de WAKFULI le 25 septembre 2026, sélecteur **niveau 245**. Dégâts et soins de base, avant statistiques du personnage. Le numéro de build du **site** ne constitue pas un numéro de patch du **jeu**. Les annonces Ankama confirment la sortie de 1.93 le 22 septembre, dont une refonte Pandawa ; l'alignement de chaque champ de l'encyclopédie avec ce client n'est pas certifié. Voir [sources et contradictions](SOURCES_ET_VERSIONS.md).

Les onglets effets, conditions et description ont été lus ; les icônes PA/PW, allié/ennemi, ligne de vue et portée ont été décodées depuis les éléments affichés. Les restrictions d'états sont parfois contradictoires dans l'interface, notamment « Porteur » et « non Porteur » simultanément : **ces lignes ne forment pas un prédicat de lancement fiable**. Les doublons d'effets ne sont jamais additionnés sans preuve.

## Xélor : 15 élémentaires, 6 actifs spécifiques, 20 passifs spécifiques

Les actifs communs et passifs génériques ne sont pas inclus. Les capacités innées Cadran, Distorsion et Vol du temps ne figurent pas dans cette liste de sorts équipables : leurs règles sont recoupées séparément, sans les compter comme fiches complètes.

PO : intervalle affiché ; `M` : modifiable ; `F` : fixe. Ligne de vue requise sauf mention contraire. Une possibilité de ciblage sur soi est précisée séparément. Le seuil mêlée/distance de WAKFU ne doit pas être copié de DOFUS.

### Élémentaires : ce que fait chaque lancement

| Sort / source | Coût ; portée ; limites | Effets lus et identité |
|---|---|---|
| [Perturbation](https://wakfuli.com/encyclopedia/spells/xelor?spell=750) | 3 PA ; 2–3 M, en ligne ; 3/t | Feu 83, critique 104, zone. La parité de l'heure modifie son orientation ; forme exacte à confirmer. Attaque qui demande de préparer la géométrie du tour. |
| [Suspension](https://wakfuli.com/encyclopedia/spells/xelor?spell=751) | 4 PA ; 3–4 M ; 2/t | Feu 131, CC 164 ; stabilise le lanceur pour le tour. Sur Cadran : gèle l'heure, +2 charges, puis +1 par PW dépensé, rembourse 2 PA ; prochain lancement sur Cadran : libère les charges en avançant l'heure, rembourse 2 PA. |
| [Éclair obscur](https://wakfuli.com/encyclopedia/spells/xelor?spell=752) | 5 PA ; 3–4 M ; 3/t, 2/cible | Feu 97 puis rebond 181 sur ennemi à 1–2 cases ; CC 122/227. La cible prioritaire peut être **la seconde**. Sélection du rebond en cas d'égalité non établie. |
| [Aiguille](https://wakfuli.com/encyclopedia/spells/xelor?spell=754) | Jusqu'à 4 PA ; 2–4 M ; 2/t | Feu 111, CC 139 ; tuer un combattant rembourse le coût. La note 1.92 précise : lançable avec 1, 2 ou 3 PA restants, dégâts inchangés. C'est un finisseur et un outil d'utilisation du reliquat de PA. |
| [Poussière](https://wakfuli.com/encyclopedia/spells/xelor?spell=753) | 3 PA ; 3–5 F, sans LDV ; 2/cible | Feu 105, CC 132 ; chaque usage augmente de 2 la portée minimale **et** maximale. L'attaque chasse progressivement les cibles proches de sa fenêtre légale. Réinitialisation à confirmer. |
| [Martel'heure](https://wakfuli.com/encyclopedia/spells/xelor?spell=749) | 3 PA ; 1–4 M, en ligne ; 4/t, 2/cible | Eau 83, CC 104, −1 PA ; les effets sont réappliqués aux cibles précédentes. L'ordre d'acquisition des cibles distribue les répétitions. Déduplication, durée de mémoire et validité des anciennes cibles à vérifier. |
| [Ralentissement](https://wakfuli.com/encyclopedia/spells/xelor?spell=775) | 1 PA + 1 PW ; 1–3 M, soi possible ; 3/t, 2/cible | Eau 35, CC 44, aux ennemis ; +15 Volonté au lanceur ; retrait affiché 2 PA sur combattant. Change aussi l'heure par la dépense de PW. L'ordre exact du bonus de Volonté reste à vérifier. |
| [Horloge](https://wakfuli.com/encyclopedia/spells/xelor?spell=763) | 5 PA ; 1–3 M, en ligne ; 2/t, 1/cible | Eau 182, CC 228, **à la fin du tour de la cible** ; effet doublé selon le compteur de 12 PW régénérés. Ne pas compter automatiquement un deuxième impact immédiat. |
| [Sablier](https://wakfuli.com/encyclopedia/spells/xelor?spell=783) | 3 PA ; 1–2 M ; 4/t, 1/cible | Pose un état ; au début du tour du porteur : Eau 121, CC 152, et déclenchement d'autres Sabliers en zone. Portée de contagion, visites répétées et consommation de l'état doivent être établies avant une simulation. |
| [Désynchronisation](https://wakfuli.com/encyclopedia/spells/xelor?spell=1417) | 4 PA ; 3–6 F ; 2/t | Eau 102, CC 127, en zone, −3 PA ennemis. Sur Cadran : +6 heures et remboursement 2 PA, une fois/tour. Outil d'attaque ou accélérateur d'horloge, selon la cible. |
| [Pointe-heure](https://wakfuli.com/encyclopedia/spells/xelor?spell=767) | 2 PA ; 2–4 M ; 2/t, 1/cible | Air 60, CC 76, ennemis ; téléporte plus loin, échange si case occupée ; rembourse 1 PA en cas d'échange. Note 1.92 : deux cases en axe, une case diagonale en diagonale. Ce n'est pas une poussée avec collision. |
| [Tempus fugit](https://wakfuli.com/encyclopedia/spells/xelor?spell=765) | 3 PA ; 1–4 M, soi possible ; 3/t, 2/cible | Air 76, CC 95, ennemis ; transport vers l'heure courante à six cases au plus. Sur Cadran : déplacement de celui-ci vers l'heure et remboursement 2 PA. Le guide parlant de quatre cases est antérieur à cette règle. |
| [Paradoxe](https://wakfuli.com/encyclopedia/spells/xelor?spell=1418) | 4 PA ; 1–3 M, soi possible, sans LDV ; 2/t, 1/cible | Air 102, CC 127, en zone et symétrie autour du centre ciblé. Dessin/rayon exacts de la zone non certifiés. La cible sert aussi d'axe de construction spatiale. |
| [Symétrie](https://wakfuli.com/encyclopedia/spells/xelor?spell=772) | 3 PA ; 1–3 F ; 3/t, 1/cible | Air 76, CC 95. Heure paire : lanceur autour de la cible ; impaire : cible autour du lanceur. Échange si destination occupée. Restriction liée à Heure courante affichée sans sujet suffisamment clair. |
| [Retour spontané](https://wakfuli.com/encyclopedia/spells/xelor?spell=771) | 3 PA ; 1–3 M ; 3/t, 2/cible | Air 98, CC 123, ennemis ; annule le dernier déplacement hors PM ayant eu lieu pendant le tour du Xélor. Historique **du tour**, pas nécessairement dernier déplacement de la cible frappée. |

### Actifs : l'infrastructure et les assurances du plan

| Sort / source | Coût ; portée ; limite | Contrat, utilité et inconnue |
|---|---|---|
| [Dévouement](https://wakfuli.com/encyclopedia/spells/xelor?spell=2839) | 4 PW ; 1–3 M, soi possible ; 1/t | Alliée : +3 PA au début de son tour, pour un tour. La répétition de la ligne +3 dans la fiche ne signifie pas +6. Convertit une réserve en puissance future ; l'accélération de ce délai peut être plus importante que le montant. |
| [Contre la montre](https://wakfuli.com/encyclopedia/spells/xelor?spell=776) | 2 PA ; 1–3 M, soi possible ; 1/t | Fin du tour cible : retour au début de son tour. Sur Xélor ou sa propre invocation : position **au lancement**. Échange si occupée ; même cible indisponible quatre tours. Une assurance de repli dont la mémoire dépend du bénéficiaire. |
| [Sinistro](https://wakfuli.com/encyclopedia/spells/xelor?spell=777) | 2 PA ; 2–5 F ; 1/t ; un maximum de base | Fin de tour Xélor : soin allié de 2 % des PV manquants par charge, +1 PA par cinq charges, en croix. Note 1.92 : croix de deux cases. Génération/plafond des charges non décodés. |
| [Rouage](https://wakfuli.com/encyclopedia/spells/xelor?spell=766) | 2 PA ; 1–3 M, en ligne, sans LDV ; 1/t ; un maximum de base | Fin de tour Xélor : 20 Lumière par charge autour de la pièce. La description lie les charges aux déplacements de combattants ; quantité par événement et plafond non établis. Le placement nourrit des dégâts différés. |
| [Prémonition](https://wakfuli.com/encyclopedia/spells/xelor?spell=757) | 3 PA ; 1–4 M, soi possible ; relance 2 tours | Mémorise les PV, restitue cette valeur au prochain tour Xélor ; annulation avec variation de 50 % des PV. Sur case vide : téléportation différée du lanceur. Base du seuil et cumul des variations inconnus. Ne prouve pas une résurrection. |
| [Régulateur](https://wakfuli.com/encyclopedia/spells/xelor?spell=5344) | 3 PW ; 1–2 F, sans LDV ; 1/t ; un maximum de base | Redirige les dégâts directs destinés aux autres mécanismes du Xélor : Cadran, Sinistro, Rouage. Préserve une installation en concentrant sa vulnérabilité. Les dégâts indirects ne sont pas inclus par le texte lu. |

### Passifs : ils changent la manière de jouer les mêmes sorts

| Passif / source | Règle lue | Décision de build et prix réel |
|---|---|---|
| [Maître du cadran](https://wakfuli.com/encyclopedia/spells/xelor?spell=758) | Un cycle complet d'heure déclenche immédiatement les effets délayés. | Acheter du **temps d'effet** ; rend préparation, PW et timing solidaires. Ordre et nombre de déclenchements à auditer. |
| [Promptitude](https://wakfuli.com/encyclopedia/spells/xelor?spell=5352) | Heure paire : sans ligne de vue, mais lancement en ligne. Description : sorts élémentaires. | Traverse un obstacle au prix de l'alignement. Un changement de règle de ciblage, pas une augmentation générale de puissance. |
| [Présage](https://wakfuli.com/encyclopedia/spells/xelor?spell=5351) | +1 PW lors d'un retrait PA, une fois par combattant selon l'icône ; période de remise à zéro non précisée ; supprime la régénération liée aux PA restants. | Remplace l'épargne par l'entrave comme revenu. Faible contre cible résistante ou hors portée. |
| [Tique, Taque](https://wakfuli.com/encyclopedia/spells/xelor?spell=5353) | Tour impair +20 Volonté ; pair −20. | Planifier les tours de contrôle. **Parité du tour**, pas de l'heure. |
| [Taque, Tique](https://wakfuli.com/encyclopedia/spells/xelor?spell=764) | Tour impair −20 % DI ; pair +20 %. | Répartir les ressources entre préparation et offensive ; mauvaise ouverture si la menace exige de tuer immédiatement. |
| [Horlogerie](https://wakfuli.com/encyclopedia/spells/xelor?spell=761) | Début de tour : téléportation à l'heure, échange si occupée ; Cadran à deux tours de relance. | Automatise l'accès à la bonne case, ralentit le remplacement du support détruit. |
| [Mémoire](https://wakfuli.com/encyclopedia/spells/xelor?spell=756) | +6 PW ; −2 PM maximum. | Plus de réserve contre moins de mobilité hors infrastructure. Le prix n'est pas « négligeable » sur toutes les cartes. |
| [Cours du temps](https://wakfuli.com/encyclopedia/spells/xelor?spell=785) | Transposition causée par le Xélor : +1 PA si Distorsion active, sinon +1 PW ; Distorsion à trois tours de relance. | Rentabilise les **échanges**, pas tout déplacement ; privilégie certaines configurations et ralentit les fenêtres de buff. |
| [Contre-horaire](https://wakfuli.com/encyclopedia/spells/xelor?spell=7184) | Tours pairs : inversion de rotation de l'heure. | Change l'itinéraire optimal ; coût d'apprentissage et de prévision, même sans malus numérique affiché. |
| [Déjà vu](https://wakfuli.com/encyclopedia/spells/xelor?spell=7185) | Heure impaire : −25 % DI ; 25 % vol de vie. | Convertit une partie de l'offensive en survie ; ne crée pas un soin fixe. |
| [Connaissance du passé](https://wakfuli.com/encyclopedia/spells/xelor?spell=7186) | Cadran +50 % PV ; coût supplémentaire 2 PW. | Durabilité contre investissement. **La fiche actuelle ne donne pas +2 PA/+2 PW par cycle via ce passif.** |
| [Présages violents](https://wakfuli.com/encyclopedia/spells/xelor?spell=7187) | +30 % dégâts indirects ; l'heure inflige 111 au combattant qui y commence son tour. | L'ancienne case de confort devient dangereuse. Élément du 111 non retenu ici faute de recoupement de l'icône. |
| [Dimension sombre](https://wakfuli.com/encyclopedia/spells/xelor?spell=7188) | Heure : +30 Volonté ; retrait PA seulement depuis l'heure ou avec Ponctualité. | Renforce le contrôle en échange d'une contrainte spatiale vérifiable par l'adversaire. |
| [Ralentissement du temps](https://wakfuli.com/encyclopedia/spells/xelor?spell=7189) | Cadran agrandi, anneau de taille 6 au lieu de 3 ; élémentaires lançables seulement depuis une heure si Cadran présent. | Gagne du territoire mais dépend davantage de cases prédéterminées. |
| [Rémanence](https://wakfuli.com/encyclopedia/spells/xelor?spell=7190) | Invocations transparentes aux lignes de vue ; +1 Sinistro et +1 Rouage maximum. | Plus de pièces et moins d'obstruction alliée ; les ennemis voient aussi à travers. |
| [Mécanismes spécialisés](https://wakfuli.com/encyclopedia/spells/xelor?spell=7191) | Invoquer un mécanisme échange sa place avec le Xélor, jusqu'à six cases. | Une invocation devient un déplacement ; prépare Cours du temps mais peut ruiner la position choisie. |
| [Permutation momentanée](https://wakfuli.com/encyclopedia/spells/xelor?spell=7192) | Fin du tour : échange avec Cadran ; celui-ci gagne 100 Résistance élémentaire. | La position finale du joueur devient la future implantation du mécanisme. Effet automatique potentiellement contraignant. |
| [Mage de combat](https://wakfuli.com/encyclopedia/spells/xelor?spell=7193) | À distance ≤2 : retrait PA remplacé par −3 % DI, un tour, plafond affiché 30. | Transforme le contrôle en réduction offensive. Un « −PA » visuel du sort ne représente plus le résultat effectif du build. |
| [Flétrissement](https://wakfuli.com/encyclopedia/spells/xelor?spell=7195) | À distance ≥3 : retrait PA remplacé par dégâts 24 en début de tour. | Convertit l'entrave en dégâts indirects. Quantité par unité de retrait et cumul à vérifier ; pas de contrôle PA simultané supposé. |
| [Assimilation](https://wakfuli.com/encyclopedia/spells/xelor?spell=7196) | −6 PW maximum ; tuer un combattant, alliés/invocations compris, rend 2 PW. | Réserve réduite contre revenu de mise à mort. Meilleur avec des victimes accessibles ; risque d'exploitation par créations sacrifiables. |

### Les trois horloges à ne pas confondre

1. **Le numéro du tour** commande Tique/Taque et Contre-horaire.
2. **L'heure courante** commande Symétrie, Promptitude, Déjà vu et le placement.
3. **La file des événements différés** contient les effets futurs ; Maître du cadran peut provoquer une résolution immédiate. La [relecture complémentaire](../wakfu_character_builds_2026-09-25/LECTURES_COMPLEMENTAIRES.md) souligne que la description ne prouve pas l'annulation de l'échéance initiale : déclenchement supplémentaire et simple avance restent à distinguer dans le client.

La puissance vient de leur coordination. Un simple buff « +20 % si tu t'es déplacé » ne produit pas le même jeu. Il récompense un fait binaire ; ici, le joueur prépare l'ordre de plusieurs événements et doit conserver les bons supports vivants.

### Capacités innées et changement 1.92

Le [guide MethodWakfu](https://methodwakfu.com/bien-debuter/classes/la-classe-xelor/) décrit douze PW natifs, une régénération liée aux PA conservés, un déplacement sur les heures payé en PW et Vol du temps comme conversion croissante PW → PA. Ces éléments expliquent les dépendances du kit ; ce guide contient aussi des règles devenues obsolètes. Il ne suffit pas à certifier une rotation actuelle.

Le [relevé de la mise à jour 1.92](https://wakfu.wiki.gg/wiki/Update_1.92), accessible dans l'index de recherche, donne les corrections décisives : gain de ressources transféré au Cadran, +2 PA limité à une fois par tour lors d'un cycle et +2 PW ; Distorsion coûte 1 PW plus un PW par niveau de cycle ; Aiguille accepte les reliquats ; Tempus passe à six cases ; Connaissance du passé devient un bonus de PV. Cela explique pourquoi additionner le guide ancien et la fiche récente inventerait des gains.

Le coefficient de croissance des dégâts de Distorsion reste contradictoire entre les sources consultées : il n'entre dans aucun calcul présenté comme actuel.

### Les enchaînements importants — et leurs limites

**Pointe-heure + Cours du temps.** Un échange donne un remboursement propre au sort et peut déclencher celui du passif. Sous Distorsion, le coût net théorique passe de 2 à 0 PA. Il faut cependant disposer des 2 PA au départ, avoir une case occupée compatible, une cible encore légale, et respecter 2 usages par tour et 1 par cible. Le remboursement retire un coût ; il ne supprime pas les autres contraintes. Voir le [modèle de calcul](CALCULS.md).

**Suspension + cycle.** Geler l'heure permet de dépenser sans déclencher immédiatement, puis de libérer l'avancement. Ce contrôle du moment peut servir à placer un allié, poser un effet différé ou empêcher un déclenchement prématuré. Ce n'est pas simplement un raccourci pour « obtenir plus de dégâts ». Il faut tester la résolution de plusieurs cycles libérés ensemble et leur interaction avec les plafonds par tour.

**Aiguille et l'ordre des dépenses.** À 4 PA restants, le coût est 4 ; à 1 PA restant, il est 1 pour le même dégât de base documenté. Cela rend parfois préférable une autre action d'abord. Mais attendre peut sacrifier une portée, une cible ou un bonus. Le remboursement sur élimination est une condition de résultat, non une permission de lancer sans PA.

**Retour spontané et la mémoire.** Une autre téléportation entre la préparation et le retour peut remplacer le déplacement mémorisé. L'ordre de lancement est donc une ressource. La bonne interface doit montrer l'événement qui sera annulé, pas seulement une flèche vers la cible sélectionnée.

**Maître du cadran et Dévouement.** Avancer le moment où arrivent les PA peut changer le tour qui décide du combat. Mais une simulation fidèle exige l'ordre de mise en file, les catégories éligibles, la consommation des effets et les plafonds de gains. La note 1.92 corrige précisément un excès de remboursement de Cours du temps avec plusieurs passifs : une preuve historique que le cumul d'événements mérite des tests, pas seulement un budget de dégâts.

## Pandawa : huit lectures et un problème de fiabilité explicite

La refonte est annoncée livrée le 22 septembre 2026. Plusieurs fiches affichent encore des branches que la présentation ne distingue pas correctement. Ces lignes sont exploitables pour étudier les **décisions**, pas pour certifier un simulateur de la refonte. Les valeurs manifestement ambiguës restent signalées.

| Sort / source | Coût/portée affichés | Effet et identité ; réserve de lecture |
|---|---|---|
| [Souffle Enflammé](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4702) | 2 PA ; 1–3 M, ligne ; 4/t | Feu 60 ennemis / soin 33 alliés, en ligne ; consomme Imbibé pour debuff résistance ennemi ou buff dégâts allié. États de niveaux 100/20 affichés : leur conversion numérique exacte n'est pas certifiée. |
| [Souffle Laiteux](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4707) | 2 PA ; 1–3 M, ligne ; 3/t | Eau 65 / soin 35 ; Ivre : pousse d'une case ; applique Imbibé ; jeter peut rapprocher le lanceur. Des lignes Cyanose/soin apparaissent sans conditions suffisantes : ne pas additionner 245 dégâts à tous les lancers. |
| [Fontaine de Laiqueur](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4711) | 4 PA + 1 PW ; 1–5 M, soi possible ; 1/t | Eau 152, bénéfice PM aux alliés ; sur tonneau, zone accrue et attraction de deux cases ; +1 PM au Pandawa par cible touchée. Rayons et conditions Porteur incomplets. Convertit une formation en mobilité. |
| [Six Roses](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4713) | 4 PA ; 1–1 ; 2/t | Terre et armure ; consommation d'Imbibé pour résistance/tacle ; tonneau porté : coût −1 PA ; description : efficacité liée aux PM restants. Valeurs 245/319 affichées dans des branches non résolues : **pas de rendement chiffré validé**. |
| [Lucha L'ambrée](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4715) | 4 PA ; 1–4 M, ligne ; 3/t | Terre en zone ; en portant : coût −1 PA et jet avant dégâts. Conditions Porteur/non-Porteur affichées ensemble, contradiction vue aussi à l'écran. Le 245 affiché n'est pas retenu comme coefficient final certifié. |
| [Happy Hour](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4721) | 2 PA + 1 PW ; 1–4 M, soi possible ; relance 3 tours | Réduit le coût des neutres d'un PA pour un tour ; tonneau : bénéfices aux alliés proches. Les lignes +2 PA/+1 PA ne précisent pas assez leurs bénéficiaires ; aucune somme arbitraire. Choisir un tour de soutien préparé. |
| [Ether](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4719) | 2 PA + 1 PW ; 1–4 F, soi possible ; relance 2 tours | Stabilise ; allié intaclable, ennemi incapable de tacler, un tour. Empêcher un déplacement et libérer la marche ne se contredisent pas : ce sont deux familles de mouvement. Conditions d'état à recouper. |
| [Gueule de bois](https://wakfuli.com/encyclopedia/spells/pandawa?spell=4720) | 2 PA + 1 PW ; 1–3 M, soi possible ; 1/t | Sur soi : armure 10 % PV max, état défensif et sortie d'Ivresse ; allié : soin différé sur trois tours ; tonneau : poussée de trois cases autour. Montants de soin/résistance non décodés. |

**Identité commune.** Le type de cible est un choix de mode : ennemi, allié, tonneau, soi ou combattant porté. Le tonneau donne un centre spatial à des effets ; Imbibé prépare une conversion. Cette richesse a un coût d'interface : le joueur doit savoir quelle branche il va réellement résoudre avant de lancer. Des descriptions aplaties peuvent donner l'illusion de sorts surchargés ou absurdes.

## Féca : six manières de défendre

| Sort / source | Coût, portée, limite | Contrat lu et décision |
|---|---|---|
| [Goutte](https://wakfuli.com/encyclopedia/spells/feca?spell=6972) | 2 PA ; 1–3 M, soi possible, sans LDV ; 3/t | Ennemi : Eau 55 ; allié : bouclier contre prochaine entrave, retrait diminué de 3 et gain de 2 PA au Féca ; case vide : glyphe fluvial niveau 33. L'adversaire peut éviter de déclencher la protection. Restrictions d'états non certifiées. |
| [Orbe défensif](https://wakfuli.com/encyclopedia/spells/feca?spell=6978) | 3 PA ; 1–3 M, soi possible | Ennemi : Terre 83 ; allié : si aucun dommage subi avant le prochain tour Féca, 499 armure et 1 PW ; vide : glyphe niveau 50. Récompense une cible mise à l'abri. Une attaque minime peut détruire une grosse valeur future. |
| [Rempart](https://wakfuli.com/encyclopedia/spells/feca?spell=6980) | 3 PA ; 1–3 M, soi possible | Terre 91 sur ennemi ; bouclier allié : au début de son tour, 166 armure par ennemi au contact et Enflammé (12 % du niveau) ; vide : glyphe niveau 54. Bénéficie au personnage exposé, à l'opposé de l'Orbe. |
| [Immunité](https://wakfuli.com/encyclopedia/spells/feca?spell=6982) | 2 PA ; 1–6 F, soi possible ; relance 4 tours | Immunité un tour, état Indolore quatre tours ; cible ne doit pas déjà avoir Indolore. Une autre restriction Pacifié est affichée de façon à recouper. Protection absolue mais fenêtre rare et anti-chaînage par cible. |
| [Trêve](https://wakfuli.com/encyclopedia/spells/feca?spell=6983) | 1 PW ; global ; relance 3 tours | +100 Résistance élémentaire à **toutes** les entités pour un tour. Retarde aussi les dégâts de son équipe ; ce n'est pas l'arrêt complet de tout dégât. |
| [Provocation](https://wakfuli.com/encyclopedia/spells/feca?spell=6985) | 4 PA + 1 PW ; 1–1 ; relance 3 tours | Cible : −2 PM max un tour ; lanceur : −20 PM max ce tour ; les deux sont stabilisés. Conditions Déstabilisé affichées. Favorise le maintien au contact ; ne prouve pas une obligation d'IA d'attaquer le Féca. |

**La question d'équilibrage utile n'est pas « combien d'armure donne le Féca ? ».** Elle est : quelle menace doit-il identifier, quelle condition doit-il préserver, et que peut faire l'ennemi pour rendre son choix mauvais ? L'Orbe promet un gain si l'allié reste intact ; Rempart valorise un encerclement ; Goutte anticipe une entrave ; Immunité couvre une fenêtre ; Trêve échange des dégâts présents contre du temps. Leur donner le même résultat inconditionnel supprimerait précisément leur identité.

## Limites des conclusions de build

Les tables permettent d'identifier des moteurs, pas de publier un équipement « meilleur du jeu ». Manquent notamment : plafonds de certains états, coûts d'emplacement des passifs selon niveau, coefficients complets, rotations ennemies, statistiques de combats et vérifications dans le client. Aucun taux de victoire, classement de popularité ou test Ankama n'est inventé.

Pour mesurer le plaisir et la maîtrise, tester trois profils : joueur qui découvre le kit, joueur qui connaît une ouverture, joueur qui adapte sa séquence. Le critère intéressant est le gain obtenu en **changeant correctement de plan**, pas la seule longueur du combo récité.
