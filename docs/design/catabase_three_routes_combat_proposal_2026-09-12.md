# Trois voies, trois familles de combats — proposition du 12 septembre 2026

Recherche et conception demandées par Paolo. Aucun changement de gameplay appliqué. Les compositions et chiffres ci-dessous sont des hypothèses de prototype, sans équilibrage par des parties jouées. Les constats sur l'existant proviennent d'une lecture des sources ; les anciennes validations ne prouvent pas ces propositions.

**Direction : porte = pression physique et formations ; puits = magie et altérations ; barque = attrition, protections et prédateurs aquatiques.** Le terrain soutient ces identités. Le premier travail porte sur les unités et leurs interactions.

Références et transposition :

- [Battle Brothers, billet des développeurs sur les Ancient Dead](https://battlebrothersgame.com/dev-blog-85-ancient-dead-part/) : boucliers devant, armes d'hast derrière ; la formation fournit leur force et le terrain difficile la fragilise. Pour Catabase : une formation physique dont les avantages disparaissent quand Achille la sépare. Les archers ci-dessous sont notre adaptation, pas une description des légions de Battle Brothers.
- [Into the Breach, présentation officielle](https://subsetgames.com/itb.html) : les attaques ennemies sont annoncées. Pour Catabase : annoncer surtout les préparations dangereuses et laisser une activation complète à Achille pour répondre.
- [Divinity: Original Sin 2, manuel officiel Xbox](https://dlassets-ssl.xboxlive.com/public/content/6778dff3-8d6c-4615-a8a3-1f1770057d09/GameManual/9e540603-b9bb-44a0-83cd-bb98f1d40b32/nb-NO/index.html) : armures physique/magique, statuts et interactions de surfaces. Pour Catabase : exploiter les défenses séparées et les interactions lisibles. Je ne recommande pas d'importer ses deux réserves d'armure conditionnant les contrôles : notre héros solo et notre mitigation ont d'autres contraintes.

**L'existant permet déjà de commencer.**

Le resolver sépare physique/magique et élément : feu, glace, foudre, ombre, sacré, terre. Armure et résistance magique utilisent D/(D+100), puis les résistances élémentaires constituent un autre facteur. Exemple théorique : 40 dégâts magiques de feu contre 25 résistance magique et 20 % résistance feu donnent 25,6, arrondis à 26 avant tout autre modificateur. Ces défenses sont des valeurs de mitigation ; le bouclier constitue une protection distincte.

Les ressources exposent retraits PA/PM, dégâts périodiques, modifications plates de stats, durée, retrait à la mort de la source, poussée, attraction, collision, portée minimale, attaques différées et limites d'utilisation. L'armure de proximité et la réduction du premier déplacement forcé existent. Le vol de vie plafonné et des purges existent dans des modificateurs de sorts : leur branchement sur de nouveaux ennemis reste à vérifier.

Sources locales : `core/damage_resolver.gd`, `data/status/status_data.gd`, `data/spell.gd`, `data/unit_data.gd`, `units/unit.gd`, `core/expedition/expedition_spell_modifier.gd`, catalogues d'évolution et de rencontres.

Le kit initial comporte Frappe physique 3 PA au contact, Tir physique 3 PA à portée 2–6, Percée 1 PA et Garde 2 PA. La Percée nécessite un passage libre. Toute première rencontre doit être praticable sans magie, zone, purge ou attraction. Un retrait de 1 PA supprime déjà Frappe + Percée + Garde (6 PA).

Attention au sens des chiffres : une baisse plate de résistance magique ne crée pas de vulnérabilité sous zéro dans la mitigation actuelle après pénétration. Le multiplicateur de statut actuel concerne tous les dégâts. Une vulnérabilité consommable limitée au magique est une extension. Les dégâts périodiques doivent choisir explicitement leur mitigation ; les statuts génériques peuvent ignorer les défenses par défaut.

**La porte : vaincre une organisation militaire morte.**

| Unité proposée | Profil à essayer | Règle et faiblesse |
|---|---|---|
| Hoplite des sépultures | PV élevés, 2 PM, armure 30, faible résistance magique | +10 armure par allié adjacent, maximum deux. Tuer un voisin ou séparer la formation retire ce bonus. Une frappe par activation |
| Archer des brumes | Fragile, 3 PM, portée 3–6 | Tir physique ; repositionnement borné. Le contact et le couvert coupent son tir ; faible coup de secours au contact |
| Éclat d'ossements | Très fragile, 3 PM, armure nulle | Une petite attaque de contact, aucune résurrection. Chaque élimination diminue immédiatement le nombre d'attaques |
| Centurion sans nom | PV intermédiaires, 2 PM | Prépare une volée renforcée pour les tireurs proches au lieu d'attaquer. Deux commandements maximum ; perdre la source supprime la préparation |

30 armure correspond à environ 23 % de réduction, 50 à 33 %. Le physique reste utilisable contre l'hoplite. PV et dégâts seront calibrés sur le kit au seuil concerné.

Trois rencontres :

1. **Rempart et flèches : un hoplite, deux archers.** Deux lignes de tir et un flanc praticable. Briser le front, contourner ou utiliser les couverts sont trois plans. Punition : rester sous les deux tirs en attaquant le défenseur. Vérifier réellement les lignes de vue ; ne pas supposer que les tirs traversent les alliés.
2. **Levée des os : quatre éclats, puis cinq plus tard.** Deux accès et premier contact décalé. Un impact réussi du kit de référence peut en tuer un ; les zones accélèrent sans devenir obligatoires. Punition : répartir les dégâts et laisser tous les petits ennemis vivants. Leur nombre remplace une partie de leurs statistiques individuelles.
3. **Commandement silencieux : hoplite, archer, centurion.** Une activation de réponse avant la volée. Tuer le tireur ou le commandant fonctionne ; couper la ligne ou garder son bouclier aussi. Punition : ignorer une synergie annoncée.

Offres de récompenses : armure, boucliers, zones et séparation. Plusieurs orientations au marchand ; aucun achat obligatoire.

**Le puits : défaire une préparation magique avant son exploitation.**

| Unité proposée | Profil | Règle et faiblesse |
|---|---|---|
| Œil de la Faille | Fragile, 0–1 PM, faible armure | Fissure occulte : prochaine attaque magique +25 %, une charge. Annoncée, armée après la prochaine activation d'Achille, durée courte ; disparaît avec l'œil |
| Larve de scorie | PV moyens, 2 PM | Projectile magique de feu ; au contact, morsure physique modeste. Couvert ou engagement réduisent la pression magique |
| Murmureuse d'obsidienne | Fragile, 2 PM | −1 PA pendant une activation ; délai de trois activations de la lanceuse. Le contrôle prend son action, sans grosse attaque supplémentaire |
| Géode vivante | PV élevés, 2 PM | Prépare une ligne de dégâts magiques de terre. Après résolution, perd temporairement une partie de sa protection. Ouverture exploitable physiquement |

Trois rencontres :

1. **Fissure et braise : un œil, une larve.** Introduction de la préparation et de l'exploitant. Tuer l'un ou l'autre, se couvrir ou garder un bouclier sont des réponses. La marque ne doit jamais être posée et consommée avant une activation de réponse du joueur. Le bonus remplace une part des dégâts ordinaires.
2. **Voix sous la roche : une murmureuse, deux larves de budget réduit.** −1 PA contraint le plan du tour. Tuer la source ou rompre sa ligne restent possibles. Un seul retrait PA initial, non cumulable. Punition : continuer à s'exposer comme si toutes les actions étaient disponibles.
3. **Cœur de la géode : une géode, un œil.** Préparer sa position et son offensive pour l'ouverture. Punition : rester dans la ligne annoncée en étant marqué. La géode n'est jamais invulnérable à tout le kit initial.

Plus tard : −1 PM, brûlure, baisse de Prouesse, baisse de résistance sur des héros qui en ont effectivement. Présenter chaque effet avant ses combinaisons. Pas de stun complet répétable contre le héros solo. Offres : résistance magique/feu, purge, protection ponctuelle contre un malus, mobilité. Les outils avancés améliorent une réponse déjà possible.

**La barque : battre ceux qui récupèrent ce qu'on leur laisse.**

Identité distincte du puits : drain, carapaces, soins limités et chasse rapide. Physique fréquent ; froid ou ombre sur certains rôles. Aucun nouvel élément « eau » n'est nécessaire.

| Unité proposée | Profil | Règle et faiblesse |
|---|---|---|
| Sangsue stygienne | Fragile, 3 PM, faible armure | Morsure physique : récupère 50 % des PV réellement retirés, avec plafond. Le bouclier empêche le drain ; ni dégâts absorbés ni dégâts excédentaires ne produisent de soin |
| Noyé à crochets | PV moyens, 3 PM | Contact physique ; attraction annoncée d'une case en version vétérane. Garder une sortie et empêcher les contacts simultanés |
| Carcin d'obole | PV moyens à élevés, 2 PM | +40 armure en carapace. Après sa lourde pince, perd ce bonus jusqu'à sa prochaine activation. Provoquer l'attaque, se protéger, puis exploiter l'ouverture |
| Chantre des eaux mortes | Fragile, 2 PM | Deux soins par combat, espacés d'une activation, portée courte. Tuer le soutien, isoler son allié ou achever avant son soin |

Trois rencontres :

1. **Affamés du ponton : sangsue et deux noyés légers.** Le bouclier protège les PV et empêche la sangsue de se soigner. Punition : subir ses morsures tout en dispersant les dégâts.
2. **Obole sous la carapace : carcin et deux sangsues fragiles.** Nettoyer les prédateurs pendant la fermeture, ou provoquer une pince et exploiter son ouverture. Punition : s'obstiner sur la cible protégée en laissant les sangsues récupérer.
3. **Chant des noyés : chantre et deux noyés.** Atteindre le soutien ou concentrer assez de dégâts pour tuer avant le soin. Punition : laisser plusieurs cibles blessées recevoir le rendement maximal des soins. Le soin total est inclus dans le budget de PV du groupe.

Le drain plafonné a un précédent dans les sorts ; la sangsue n'existe pas encore. La carapace conditionnelle demande un comportement supplémentaire. Les limites de soins existent déjà. Offres : boucliers, dégâts concentrés, endurance, vol de vie ; anti-soin facultatif, jamais requis pour vaincre le premier soigneur.

**Contrat de difficulté proposé.**

- Deux rôles maximum lors de la première rencontre, une synergie principale, deux réponses accessibles au kit initial.
- Une activation entière d'Achille pour répondre à une grosse préparation. Définir le timing par activation, pas par un vague « tour ».
- Un seul retrait PA de −1 initialement. Un ralentissement ne doit pas rendre inévitable une attaque de zone. Pas de boucle de contrôle.
- Le soutien dépense son action : soin, protection et attaque pleine ne s'ajoutent pas gratuitement.
- Budgéter PV après mitigation, boucliers, soins disponibles, accès aux cibles, dégâts effectivement applicables et actions retirées. Le nombre d'ennemis seul ne mesure rien.
- Pas de forte esquive aléatoire ni de critique surprise pour fabriquer la difficulté des premiers groupes. Protections et ouvertures lisibles.
- Une unité mineure doit vraiment pouvoir mourir vite. Réussir à briser la formation doit faire chuter sa pression immédiatement.
- Les traits défensifs doivent laisser une issue au physique de départ. Magie, zones et déplacements spécialisés sont des avantages de build.

Nouvelles stats : exploiter d'abord la résistance au déplacement existante et les défenses actuelles. Une éventuelle Ténacité peut venir ensuite si les combats montrent un besoin ; ajouter de la résistance aux contrôles ne doit pas créer un équipement obligatoire. Nouvelles règles prioritaires : marque magique consommable et carapace avec ouverture.

Modes ultérieurs : **Percée**, tuer un gardien ouvre une sortie ; **Interception** aquatique, atteindre un porteur avant son départ donne un bonus facultatif ; **Rituel** souterrain, détruire une source interrompt une préparation d'élite. Les récompenses et l'XP sont définies par l'étape. Aucun farm de renforts, et une sortie anticipée n'accorde pas automatiquement le butin plus coûteux d'une élimination totale.

**Intégration et validation proposées.**

II : hoplite + archer ; œil + larve ; sangsue + noyé. III : combinaison connue renforcée. IV : préparation à la halte. V–VI : variation et synthèse. Comme le puits et la porte partagent V puis un embranchement VI, annoncer la dominante de leurs rencontres communes pour permettre une réorientation. La barque garde sa continuité jusqu'à VII ; budgéter ensemble son élite VI et l'épreuve commune VII.

L'identité des monstres devrait être indépendante de la récompense : le catalogue actuel sélectionne ses groupes par profondeur et famille de butin. Une version future doit distinguer voie stable, archétype, grade et récompense. Le miroir de carte doit aussi préserver les relations narratives entre lieux.

Premier travail : trois salles grises, une par voie, avec le kit initial, puis des builds défensif et offensif mobile au niveau correspondant. Relever durée, PV perdus, PA/PM retirés, soins et boucliers ennemis effectifs, première cible et cause de la plus grosse punition. Rejouer en changeant volontairement de stratégie : vérifier une deuxième réponse réellement viable.

Critère de réussite : le joueur comprend la combinaison ennemie, réussit à la briser et sent immédiatement la pression diminuer. Les trois voies doivent donner trois raisons différentes de modifier son tour.