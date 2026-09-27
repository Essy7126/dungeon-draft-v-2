# Évolution de WAVEN et lecture critique des retours

Il faut distinguer trois objets : l'Aventure construite au fil des correctifs, la refonte annoncée en 2025 et le mode Survie présenté en 2026. Un texte de la refonte ne met pas rétroactivement à jour les anciennes cartes.

## 1. Ce que raconte l'évolution mécanique

| Date | Faits documentés | Interprétation de conception |
|---|---|---|
| Novembre 2023 | Plafonnement de certaines répétitions et conversions ; baisse de la génération de Pramium. | Les événements gratuits et récurrents nécessitent une maîtrise de leur croissance. |
| Mai 2024 | Refonte de Pikuxala et Apostruker ; révision de nombreuses statistiques et de l'économie d'amélioration. | Un changement de géométrie ou de déclencheur peut transformer une classe plus profondément qu'un coefficient. |
| Août–octobre 2024 | Corrections d'interactions ; réduction de plusieurs sources d'armure ; condition de réussite de l'échange Pikuxala explicitée. | La puissance est distribuée dans un kit entier, parfois dans un équipement commun à plusieurs classes. |
| Mars 2025 | Corrections des réactions de clans, des conditions de sorts, de rencontres et de reprises de quête. | La lisibilité et la fiabilité des règles font partie de l'équilibrage. |
| Avril 2025 | Diagnostic de complexité, rétention et objectifs ; présentation d'une refonte. | Le problème déclaré dépasse le manque de cartes ou de contenu. |
| Août 2025 | Projet sans équipement ni fiche de compétences ; redistribution des fonctions entre héros, sorts communs et compagnons. | Simplification de la préparation ; déplacement possible de la profondeur vers la partie. |
| Juin–juillet 2026 | Présentation et démonstration de Survie ; précisions officielles et premiers témoignages d'essai. | Nouvelle structure de compétition et de construction en cours de combat, à analyser séparément. |

Sources : [0.13.1](https://steamcommunity.com/games/2343650/announcements/detail/3824179810347938047), [0.17](https://forum.waven-game.com/en/44-patchnotes-fr/5428-version-17-fr), [0.19](https://forum.waven-game.com/en/44-patchnotes-fr/5880-version-19-fr), [0.20](https://forum.waven-game.com/en/44-patchnotes-fr/6058-version-20-fr), [0.23](https://forum.waven-game.com/en/44-patchnotes-fr/6463-version-23-fr), [bilan 2025](https://steamcommunity.com/games/2343650/announcements/detail/548983985537024963), [Community Update #2](https://forum.waven-game.com/en/22-news-fr/6657-community-update-2), [Convention 2026](https://forum.waven-game.com/en/22-news-fr/6783-ankama-convention-25-ans-waven).

**Mon diagnostic.** L'histoire des correctifs montre deux difficultés qui se superposent. La première est mathématique : des ressources ou activations se multiplient entre elles. La seconde est cognitive : le joueur doit connaître le timing, le mode, la cible et parfois une exception corrigée plus tard. Augmenter le catalogue peut aggraver la seconde sans résoudre la première.

Cela ne démontre pas que la profondeur est une erreur. Une complexité utile fait choisir entre des séquences. Une complexité peu utile impose de connaître une convention invisible pour que le build fonctionne comme prévu.

## 2. Ce que disent réellement les développeurs

Le bilan d'avril 2025 explique les difficultés du produit et présente une nouvelle direction. La proposition d'août retire équipement et compétences, tout en conservant une identité propre au héros et en intégrant les compagnons au deck. La réserve de PA manuelle est remplacée dans cette proposition par des apports au tour suivant. [Bilan Ankama](https://steamcommunity.com/games/2343650/announcements/detail/548983985537024963), [Community Update #2](https://forum.waven-game.com/en/22-news-fr/6657-community-update-2).

**Lecture critique.** Retirer une couche n'est une amélioration que si les choix qu'elle portait sont inutiles, redondants ou recréés ailleurs. Les anneaux étudiés montrent que les équipements historiques ne sont pas tous des bonus plats : ils peuvent alimenter soin, pioche, génération ou déclenchement. Leur retrait peut clarifier le jeu tout en supprimant des variantes réelles.

Je jugerais donc la refonte sur des situations comparables : deux builds d'un même héros doivent-ils encore résoudre une salle différemment ? Un compagnon changé modifie-t-il l'ordre des actions ? Le joueur peut-il adapter son plan à l'ennemi ? Le nombre de menus retirés ne répond à aucune de ces questions.

Le fil Season Talk d'avril 2026 recueille des questions. Ce n'est pas un rapport de réponses de l'équipe. Les commentaires sur coopération, progression et avenir du jeu montrent les attentes exprimées, sans documenter l'état technique de la refonte. [Fil officiel](https://forum.waven-game.com/en/22-news-fr/6762-season-talk-nouvelles-waven).

## 3. Survie 2026 : une nouvelle économie de décisions

L'annonce décrit quatre joueurs sur quatre plateaux, des vagues et deux monnaies : améliorer son héros ou envoyer des difficultés aux autres. Le deck initial comporte 16 cartes : quatre sorts du héros, un compagnon et onze Impact remplaçables. La main initiale est de cinq, le maximum neuf. Rejouer un compagnon vivant peut le renforcer, le restaurer et réactiver son apparition. Koko confirme les decks préconstruits et le matchmaking solo pour ce mode. [Annonce et réponses officielles](https://forum.waven-game.com/en/22-news-fr/6783-ankama-convention-25-ans-waven).

**Ce que j'en déduis.** La construction du deck devient une décision située : la récompense immédiate, l'ennemi de la vague et la pression des autres joueurs peuvent changer la bonne carte à prendre. L'absence de construction initiale libre ne permet donc pas, à elle seule, de conclure à l'absence de construction stratégique.

En revanche, cela crée trois risques concrets :

1. Si la meilleure amélioration est toujours la même pour un héros, la partie impose une recette après quelques essais.
2. Si conserver ses ressources défensives domine toujours l'agression, la monnaie destinée aux autres perd son intérêt ; l'inverse peut produire un emballement du joueur déjà en tête.
3. Si le compagnon répété produit trop d'apparitions utiles, le moteur de pioche devient aussi un moteur de soin et d'effets gratuits. La boucle change de support ; elle ne disparaît pas nécessairement.

Ces risques sont des hypothèses de design, pas des défauts mesurés de la démonstration. Les coûts, offres, plafonds et règles de ciblage complets n'ont pas été relevés.

### Calcul de l'ouverture annoncée

Hypothèses : tirage uniforme sans remise, pas de mulligan ni de tutorat. Ce calcul utilise une main initiale de cinq, **pas le maximum de neuf**.

| Événement | Probabilité |
|---|---:|
| Compagnon dans l'ouverture | 31,25 % |
| Au moins un des quatre sorts de héros | 81,87 % |
| Deux cartes précises ensemble | 8,33 % |
| Compagnon parmi sept cartes distinctes vues | 43,75 % |

La main contient en moyenne 3,4375 Impact dans ce modèle. Cela ne signifie pas que ces cartes sont inutiles ni que le héros n'a pas d'identité lorsque ses sorts propres sont absents : son passif peut encore jouer ce rôle.

La disponibilité du compagnon n'est qu'une moitié du problème ; il faut aussi pouvoir payer son invocation. Garantir sa présence trop tôt peut ne rien apporter si la ressource manque. À l'inverse, réunir les points nécessaires mais ne pas le voir arriver peut créer un décalage frustrant. Il faut mesurer ces deux dates séparément.

Les 4 368 mains possibles ont été énumérées pour vérifier indépendamment les formules. [Calculs](CALCULS.json).

## 4. Joueurs expérimentés : ce qui constitue une preuve utile

Je privilégie les témoignages qui décrivent un build, sa rotation et ses limites. Leur expertise reste déclarée ou inférée de la précision du propos ; ce dossier ne certifie pas un classement compétitif.

| Source | Signal intéressant | Ce qu'il ne faut pas en conclure |
|---|---|---|
| Seyeshean, guide Piven | Préparation des auras, tour de décharge, alignement et choix d'équipements explicités. | Le temps de farm annoncé n'est pas mesuré ici et le build n'est pas universellement optimal. |
| Timtoobias, classement fondé sur plusieurs builds par classe | Différencie confort, rapidité, dépendance aux compagnons et goût personnel. | Les rangs ne sont pas des coefficients de puissance transposables à tous les contenus. |
| ErgotthAE, Pikuxala | Décrit répétition des téléportations et bénéfices d'équipe, puis admet une économie de jauges faible. | Les nombres revendiqués ne sont pas des statistiques reproduites par cette étude. |
| Discussion du 29 mai 2024 | Oppose ressenti de portée amputée et satisfaction d'un contrôle plus précis des cibles. | Une réaction de lendemain de refonte ne prouve pas le niveau de maîtrise à long terme. |
| salimetnael, 11 juillet 2026 | Déclare avoir joué Survie la veille ; apprécie les compagnons en deck et la construction pendant le combat. | Une démonstration appréciée ne prouve ni équilibre, ni rétention à cent heures. |

Sources : [guide Piven](https://guidactik.com/waven/guide-et-build-cra-arc-piven-sur-waven/), [classement argumenté](https://guidactik.com/waven/quelle-classe-choisir-sur-waven-tier-list/), [build Pikuxala](https://www.reddit.com/r/Waven/comments/1jfb4d6/fun_simple_pikuxala_build/), [réactions à sa refonte](https://www.reddit.com/r/Waven/comments/1d3pdbn/pikuxala_xelor_changes/), [retour d'essai Survie](https://forum.waven-game.com/en/22-news-fr/6783-ankama-convention-25-ans-waven).

### Des désaccords qui portent sur des critères différents

Dans la discussion Pikuxala, blackaerin regrette la portée courte et EyedMoon apprécie de mieux choisir les ennemis touchés. Ces avis ne s'annulent pas : ils évaluent respectivement confort de distance et contrôle spatial. heckx100 insiste sur la nécessité de réapprendre son personnage. Ce troisième point porte sur l'investissement acquis, pas uniquement sur le nouveau rendement. [Discussion](https://www.reddit.com/r/Waven/comments/1d3pdbn/pikuxala_xelor_changes/).

Dans les fils de 2026, des joueurs craignent pour le theorycraft et la progression ; d'autres demandent des raisons de coopérer ou une communication plus concrète. Les inquiétudes avant une démo doivent rester distinctes du retour de salimetnael après essai. Le fil officiel comprend les deux types de messages. [Questions d'avril](https://forum.waven-game.com/en/22-news-fr/6762-season-talk-nouvelles-waven), [annonce et discussion Survie](https://forum.waven-game.com/en/22-news-fr/6783-ankama-convention-25-ans-waven).

**Mon interprétation.** Une communauté investie peut perdre confiance même si la nouvelle mécanique paraît prometteuse : les joueurs n'évaluent pas seulement la prochaine partie, mais aussi la valeur future de ce qu'ils ont appris et accumulé. Ce mécanisme est plausible ; ces fils ne permettent pas de calculer sa fréquence dans toute la population.

## 5. Ce que cette enquête change dans l'audit

- Un héros ne doit pas être évalué uniquement sur son coefficient : il faut étudier ses accès aux événements, ses coûts de préparation et ses contraintes de cible.
- Un équipement partagé peut modifier plusieurs moteurs ; le nerf d'une classe ne se trouve pas nécessairement dans sa fiche.
- Les ennemis définissent la valeur des outils : une séquence de petites actions peut être excellente dans une salle et coûteuse dans une autre.
- La fiabilité de l'ouverture, les seuils de mise à mort, la durée réelle et l'investissement nécessaire sont des axes distincts.
- La refonte annoncée doit être jugée sur les décisions préservées ou créées, avec séparation explicite entre Aventure, projet de refonte et Survie.

Il manque encore un relevé en client pour arbitrer les règles de résolution et mesurer les combats. L'enquête actuelle établit les architectures, les contradictions documentaires et plusieurs conséquences chiffrées ; elle ne prétend pas remplacer ce relevé.
