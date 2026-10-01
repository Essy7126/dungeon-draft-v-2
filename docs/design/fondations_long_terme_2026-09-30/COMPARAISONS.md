# Comparer des mécanismes, puis choisir pour Dungeon Draft

Recherche consultée le 30 septembre 2026. Les sources ci-dessous sont celles des
développeurs, éditeurs ou auteurs des règles. Une conférence de 2019 ou une
annonce de 2025 décrit cette version ou cette intention, pas nécessairement
l'ensemble du jeu actuel. Les transpositions sont nos propositions.

## Sept références complémentaires

| Référence | Mécanisme ou démarche documenté | Ce que nous pouvons en tirer | Adaptation à nos contraintes |
|---|---|---|---|
| **Slay the Spire** | Mega Crit vise une utilité pour chaque carte ; mesure, retours de joueurs et itération se complètent. L'Ascension permet de distinguer les niveaux de compétence. | Comparer les choix dans leur contexte et garder des cartes de situation. | Nos copies disparaissent pendant la run : ajouter le coût d'épuisement et les possibilités de remplacement aux évaluations. |
| **Into the Breach** | Intentions visibles, résolution déterministe pendant le tour joueur ; contraintes de lisibilité et de durée guident les armes et les rencontres. | Produire de la profondeur avec l'espace, le délai et les objectifs. | Nos combats doivent éprouver des styles différents ; les déplacements et contrôles se mesurent en actions ennemies évitées, pas en « dégâts équivalents » fixes. |
| **Monster Train** | Deux clans fournissent le contenu ; améliorations combinables, duplication et choix de route transforment le répertoire. | Relier construction du personnage, modification des cartes et trajet. | Une duplication chez nous est du stock supplémentaire qui permet plusieurs combats ; son prix doit couvrir cette économie, au-delà de la meilleure carte du deck. |
| **Hades II** | Les aspects cachés annoncés en juin 2025 donnent de nouveaux styles aux armes ; la refonte des Flammes vise aussi un maniement plus vif. | Une évolution peut changer la cadence et le geste utile, pas seulement le total. | Donner des formes et des objets qui changent le tour : attaque rapide, attente, zone, repositionnement. Les classes conservent leur identité par leur géométrie et leurs passifs. |
| **Grim Dawn** | Pouvoirs de Dévotion associés à des compétences ; compatibilité du déclencheur explicite. L'ordre des conversions interdit de convertir plusieurs fois la même portion. | Un langage de déclencheurs et de provenance permet beaucoup de combinaisons vérifiables. | Associer les effets aux événements et aux sources. Pour une conversion de garde ou un écho de dégâts, préciser ce qui est déjà valorisé et ce qui peut réagir. |
| **Gloomhaven, deuxième édition** | Coûts d'amélioration plus élevés pour les effets multicibles, y compris conditionnels ; distinction entre dommage calculé et PV effectivement retirés. | Le nombre de cibles et le résultat réel doivent faire partie du budget. | Tarifer aussi géométrie, copies et horizon de combat. Le drain et les réactions utilisent les PV retirés ou l'absorption réelle, selon leur contrat. |
| **Magic: The Gathering** | Rosewater distingue compréhension, complexité du plateau et complexité stratégique ; une carte simple peut révéler des usages avancés. | Concevoir des briques compréhensibles qui interagissent. | Les normales doivent déjà permettre une construction riche. Les rares peuvent étendre une règle familière, sans introduire un dictionnaire entier. |

Sources directes :

- Slay the Spire : [Anthony Giovannetti, GDC 2019 — diapositives](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf),
  notamment pages PDF 7, 13 et 16 ; [fiche de conférence](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics).
- Into the Breach : [Matthew Davis, GDC 2019 — postmortem](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf),
  pages PDF 8, 14, 21–22, 42–47. Ce document explique les contraintes et les
  essais abandonnés ; il ne fournit pas une formule universelle d'équilibrage.
- Monster Train : [présentation officielle du jeu par Shiny Shoe](https://store.steampowered.com/app/1102190/Monster_Train/),
  sections sur les lieux, les clans et les améliorations. Référence au premier
  jeu ; pas de chiffres importés des guides communautaires du deuxième.
- Hades II : [Supergiant, The Unseen Update, 17 juin 2025](https://www.supergiantgames.com/blog/hades2-unseen-update/).
  Exemple historique d'évolution des comportements, pas inventaire actuel des
  bénédictions ni assertion sur le meilleur build.
- Grim Dawn : [guide officiel — Dévotion](https://www.grimdawn.com/guide/character/devotion/)
  et [guide officiel — combat et conversion](https://www.grimdawn.com/guide/gameplay/combat/).
  Nos bornes, nombres et durées ne sont pas ceux de cet ARPG.
- Gloomhaven : [FAQ officielle deuxième édition](https://cephalofairgames.github.io/gloomhaven2e-faq/),
  sections 4.1, 5.1 et 5.2 ; [page officielle de ressources](https://cephalofair.com/pages/gloomhaven).
  Le PDF 2025 lié par l'éditeur a été identifié, mais son contenu Google Drive
  n'est pas lisible par l'outil utilisé ; aucune règle détaillée supplémentaire
  n'en est déduite.
- Magic : [Mark Rosewater — Lenticular Design](https://magic.wizards.com/en/news/making-magic/lenticular-design-2014-12-15),
  republication officielle du 16 décembre 2014. Référence de conception, pas
  justification pour importer la pile complète de Magic dans Godot.

## Le cas Waven est particulièrement utile pour notre décision

Dans [Community Update #2 du 5 août 2025](https://steamcommunity.com/app/2343650/allnews/?l=french),
Ankama décrit une refonte visant une identité propre aux héros et environ
150 sorts transversaux. Le studio explique aussi pourquoi il retire alors
des couches d'objets et de compétences : interactions difficiles à lire,
personnalisation qui converge vers une seule meilleure voie, faible plaisir
immédiat. Ce sont les intentions de cette annonce, pas un contrôle du client
Waven de septembre 2026.

Notre choix : garder cartes, équipement et reliques, mais donner à chaque
couche un rôle distinct. Les maîtrises orientent les composantes ; les cartes
fournissent les actions ; l'équipement ajuste l'accès et le rythme ; les reliques
changent les relations entre actions. Une couche qui ajoute seulement un
deuxième calcul obligatoire pour obtenir le même style doit être reconsidérée.

La recherche n'a pas permis de rouvrir des devblogs primaires Dofus/Wakfu assez
précis et datés pour confirmer leurs règles actuelles. Les notes historiques du
dépôt restent accessibles ; elles ne deviennent pas des sources fraîches.
Nos décisions chiffrées viennent du moteur Dungeon Draft et du laboratoire,
pas d'un souvenir des paliers d'un autre jeu.

## Ce que les comparaisons ne permettent pas de conclure

Ces sources documentent des choix de conception ; elles ne prouvent pas que
les mêmes choix seront plaisants ici. Nos interprétations à éprouver :

1. Une carte doit avoir au moins une situation où elle change la meilleure
   décision, avec un accès réaliste avant l'occasion de l'utiliser.
2. Une montée intéressante peut changer la fiabilité, le coût ou le moment de
   résolution autant que la quantité produite.
3. Un combo très puissant mérite d'exister quand il est lisible, acquis et
   limité par des ressources réelles. La recherche de puissance fait partie du
   plaisir d'un roguelite solo.
4. Le joueur doit pouvoir anticiper l'effet qu'il prépare : coût, portée, cible,
   condition, durée et quantité visible. L'incertitude du butin peut coexister
   avec une résolution de combat prévisible.

Un excellent taux de victoire global peut masquer une voie inaccessible, des
choix obligatoires ou des tours répétitifs. Les calculs servent à trouver ces
cas et à préparer les essais ; les sessions de jeu arbitrent le plaisir.
