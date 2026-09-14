# Catabase — relier Achille, les rencontres et la run

Recherche complémentaire du 12 septembre 2026. Proposition de conception, non implémentée. Lecture du code et de sources de développeurs ; aucune session de jeu ni validation d'équilibrage effectuée pour ce document.

Complète `catabase_three_routes_combat_proposal_2026-09-12.md`. Le sujet ici est la progression des décisions, plutôt qu'un nouveau catalogue de monstres.

## 1. Diagnostic à partir du projet

Sources locales principales : `core/expedition/expedition_build_catalog.gd`, `expedition_build_state.gd`, `expedition_session.gd`, `expedition_route_itineraries.gd`, `catabase_monster_encounter_catalog.gd`, `expedition_equipment_catalog.gd`, `data/units/allies/achilles.tres`, les quatre sorts de départ dans `data/spells/achilles/` et `core/damage_resolver.gd`.

- Achille commence avec 6 PA, 3 PM, Frappe (3 PA), Tir (3), Percée (1), Garde (2). Les quatre fonctions sont lisibles, mais leurs interactions de départ sont limitées.
- Dès la première victoire, les deux points permettent une racine de doctrine et une technique. Crochet, Marque, Heurt, Entaille, déplacements et soins bornés existent déjà. Le premier embranchement peut donc éprouver une première spécialisation.
- La run distribue 24 points de maîtrise. Elle conserve quatre emplacements jusqu'au niveau de champion 5, puis cinq ; au palier XII, choix entre un sixième emplacement et Tempête. Apprendre, équiper et améliorer sont des décisions distinctes.
- Les formes évoluées comportent déjà des compromis : plus de portée contre un PA supplémentaire, poussée contre attaque en ligne, puissance contre sacrifice ou délai. Il faut préserver et rendre utiles ces différences.
- Les trois nœuds II ont pour récompenses healing, armor, control. Le catalogue d'ennemis retourne pour les trois le même duo de brutes. La récompense et le palier pilotent actuellement la composition, sans identité de biome explicite à cet endroit.
- Le catalogue tardif possède pourtant des situations construites : attraction + exécuteur, boucliers + archers, terrain brûlant + pousseurs, soins dépendant de porteurs. Le problème est leur distribution et leur articulation avec la progression, pas l'absence absolue de comportements.
- Les offres de techniques apparaissent à III, VI, X, XIV, XVIII et sur les élites ; l'offre vise une famille annoncée quand possible. L'équipement est sélectionné séparément, par graine et nœud, sans garantie explicite de pertinence pour la préparation actuelle.
- Les haltes ont déjà des fonctions exclusives : repos, équipement, découverte, information. Elles peuvent donner du sens aux trajets sans ajouter une économie parallèle.

Deux points à vérifier en jeu : Frappe d'ouverture applique sa réduction d'armure après l'impact et annonce une expiration à la prochaine activation de la cible ; elle favorise donc surtout un second impact rapide. Une réduction d'armure n'est pas non plus un gain universel contre une cible déjà à zéro, puisque la défense effective est bornée à zéro. Garde expire au début de l'activation suivante : une future riposte différée devra avoir son propre état, indépendant du bouclier.

## 2. Ce que la recherche apporte

**Des actions simples qui se modifient mutuellement.** Greg Kasavin explique que Hades reprend de Transistor la profondeur issue des propriétés combinées et des systèmes reliés. Application proposée : consacrer les prochains efforts à des interactions entre techniques, équipement et adversaires. Source primaire : [Supergiant, The origins of Hades, 2021](https://blog.playstation.com/2021/08/05/the-origins-of-hades-out-next-week-on-ps5-ps4).

**La menace doit être intelligible pour que le déplacement ait une valeur.** Le postmortem de Matthew Davis montre comment les attaques annoncées, les objectifs et les contraintes de lisibilité ont guidé Into the Breach, jusqu'à limiter les types d'attaques. Application proposée : annoncer les attaques décisives et concevoir leurs réponses en même temps que les ennemis. Cela n'exige pas de rendre tout Catabase déterministe. Source primaire : [GDC 2019, Into the Breach Design Postmortem](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf), diapositives 13–21, 30–35, 44–46.

**Les choix de run doivent dépendre de la situation.** Dans son billet de développement de juin 2025 sur Slay the Spire 2, Mega Crit décrit des événements variant selon l'acte et l'état du joueur, avec des compromis parfois défavorables. Application proposée : les souvenirs et les haltes interrogent la préparation actuelle, les PV et le prochain danger. C'est une piste de conception, pas une affirmation sur l'état actuel de STS2. Source primaire : [Neowsletter, juin 2025](https://www.megacrit.com/news/2025-6-12-neowsletter-issue-11/).

**Une option doit avoir une situation où elle mérite sa place.** Anthony Giovannetti présente un équilibre obtenu par itérations, retours et mesures, tout en distinguant données et conclusions. Application proposée : vérifier la raison de choisir un sort ou un chemin ; un taux de victoire global seul ne suffit pas. Source primaire : [GDC 2019, Metrics Driven Design and Balance](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf), diapositives 6, 12, 15, 20.

Les propositions suivantes sont notre synthèse pour Catabase ; ces références ne prouvent pas leur efficacité.

## 3. Donner une manière de combattre à Achille

Conserver le premier combat à quatre techniques et utiliser les deux points de sa récompense pour construire une première boucle. Chaque exemple ci-dessous respecte quatre emplacements et 6 PA ; les distances, cases libres et lignes de vue restent nécessaires.

| Orientation | Équipement de sorts possible après I | Tour significatif | Renoncement réel |
|---|---|---|---|
| Briseur | Frappe d'ouverture, Crochet, Percée, Garde | Crochet 2 attire un ennemi à deux cases ; Frappe 3 ; Percée 1 peut sortir du contact | Tir retiré ; aucune Garde dans ce tour à 6 PA |
| Chasseur | Tir de guet, Marque, Percée, Garde | Marque 2 puis Tir 3 à une distance valide ; Percée 1 pour se replacer | Frappe retirée ; garder la cible à distance et une sortie devient essentiel |
| Sang | Frappe d'ouverture, Entaille, Percée, Garde | Frappe 3 puis Entaille 2, qui profite de la réduction d'armure ; Percée 1 | Sacrifice de PV, pas de bouclier ce tour ; mauvais échange si la cible ne justifie pas ce coût |
| Airain | Frappe, Heurt, Percée, Garde d'Éaque | Frappe 3 + Heurt 2 pour éloigner la cible, ou Garde 2 + Frappe 3 pour tenir | Tir retiré ; défense et poussée ne rentrent pas toutes deux avec Frappe |

Ces séquences ne doivent pas devenir des rotations obligatoires. Face à une autre disposition, le joueur doit vouloir changer de cible, conserver Garde, utiliser ses PM autrement ou interrompre sa séquence.

### Trois améliorations ciblées à prototyper

1. **Colère : une ouverture réellement exploitable.** Comparer la durée actuelle de Frappe d'ouverture à une ouverture consommée par le prochain impact physique, disponible pendant deux activations de la cible. Réutiliser le principe des vulnérabilités à charges déjà employé pour Marque ; définir explicitement leur coexistence. Tester le bénéfice contre faible et forte armure avant de choisir entre réduction de défense et bonus de dégâts. Aucun gain sur le coup qui crée l'ouverture.
2. **Chiron : une cible préparée et un angle à conserver.** Marque + Tir fonctionnent déjà. Leur intérêt vient d'ennemis qui avancent, de lignes qui se ferment et de la possibilité de tuer un soutien à la place de la cible marquée. Commencer par les rencontres et les formes existantes, sans nouvelle jauge.
3. **Éaque : transformer une bonne défense en initiative offensive.** Nouvelle mutation proposée : si le bouclier de Garde absorbe réellement des dégâts ennemis, gagner une charge de riposte pour le prochain Heurt. Une charge maximum, expiration en fin de prochaine activation d'Achille, effet modeste à régler. Pas de déclenchement sur sacrifice, terrain auto-infligé ou simple lancement de Garde. La charge peut survivre à la disparition du bouclier. Cette mutation remplacerait une option existante dans le prototype, sans s'ajouter gratuitement à toutes les doctrines.

Une synergie doit amplifier une décision réussie sans effacer son coût : éviter les restitutions répétables de PA, les soins illimités et les bonus obtenus en marchant artificiellement dans un coin sûr.

## 4. Faire des trois routes trois problèmes de combat

| Route | Question dominante | Variations à combiner progressivement | Ce qui doit rester possible |
|---|---|---|---|
| Porte, ossements | Comment désorganiser une force physique organisée ? | Front protecteur, arrière dangereux ; nuée fragile ; garde qui avance et découvre son tireur | Contourner, isoler, absorber une salve ou éliminer rapidement un flanc |
| Puits, profondeurs | Quelle préparation ennemie dois-je interrompre, et laquelle puis-je encaisser ? | Marque puis impact magique ; canalisation ; ralentissement précédant une zone | Tuer la source, rompre sa ligne, déplacer la menace ou sortir de la zone, sans exiger une purge équipée |
| Barque, eaux | Quand attaquer pour que mes dégâts restent acquis ? | Soin limité ; vol de vie ; carapace qui s'ouvre après une attaque ; protecteur séparé de son soutien | Concentrer les dégâts, bloquer une morsure avec Garde, forcer une ouverture ou isoler le soigneur |

Le bateau reste l'élément de continuité du voyage : embarquements, pontons, épaves, lieux d'accostage et adversaires qui remontent avec le convoi. L'identité aquatique peut venir du rythme des ennemis sans ajouter une statistique de dégâts Eau.

Chaque rencontre devrait contenir une menace principale, une interaction qui la renforce, un point faible observable et au moins deux réponses accessibles à ce stade. Sur les premiers combats, deux rôles suffisent. Les contrôles qui retirent des actions demandent une vigilance particulière : Achille est seul, une activation perdue supprime toute l'action du joueur.

Un exemple de dilemme à rechercher : l'archer prépare un tir dangereux derrière un garde. Attirer le garde ouvre la ligne de tir vers l'archer, mais laisse Achille exposé ; engager l'archer économise les PV menacés par le tir, mais abandonne une cible presque morte ; garder sa position permet Garde et une élimination sûre. Les chiffres et le terrain doivent rendre ces réponses alternativement intéressantes.

### Une menace annoncée doit avoir une règle précise

- Un tir visant une **case** peut être évité en la quittant ; il ne suit pas silencieusement Achille.
- Une attaque visant une **unité** indique si elle exige encore la portée et la ligne de vue à sa résolution.
- Une canalisation indique ce qui l'interrompt : mort, déplacement, rupture de ligne ou effet dédié. Déplacer n'annule pas automatiquement tous les sorts.
- Montrer le coût de l'erreur : zone, cible, moment de résolution, dégâts et statut principaux. Les chances de critique/esquive peuvent subsister, mais une esquive heureuse ne doit pas être l'unique issue d'une attaque décisive.

## 5. Utiliser les carrefours pour faire évoluer le joueur

La révision 4 suit vingt paliers, généralement quinze combats et cinq haltes. Avant VII, II, III, V et VI sont des combats et IV une halte. Une branche visuellement longue ne signifie donc pas automatiquement davantage de combats. Comparer l'attrition, les élites, l'XP, le butin et l'accès aux soins jusqu'à la réunion.

| Segment | Travail demandé au joueur | Rôle du carrefour ou de la halte |
|---|---|---|
| I–III | Comprendre les quatre gestes, puis essayer une première combinaison | Le choix d'entrée annonce le problème et le service accessible à IV |
| IV–VII | Perfectionner cette combinaison face à une variation | IV : réparer, acheter ou chercher une autre possibilité ; VII : première épreuve commune |
| VIII–XI | Ajouter une réponse qui manque, ou assumer une spécialisation | Découvertes et récompenses permettent un complément réellement jouable |
| XII–XV | Choisir entre davantage de souplesse et une mutation, puis affronter deux menaces liées | XII prépare un changement de composition ; XV vérifie l'adaptation |
| XVI–XX | Exploiter son identité et gérer sa faiblesse | Derniers risques, préparation finale, puis Pâris avec des réponses multiples |

Les convergences peuvent conserver des traces narratives sans multiplier les boss : au premier carrefour, des captifs amenés par le fleuve, des gardes de la porte et des entraves issues des profondeurs expliquent la rencontre. Une conséquence choisie plus tôt peut enlever un soutien, déplacer une entrée ou modifier une récompense. Limiter d'abord cela à **une conséquence explicite par segment**, annoncée avant le choix ; aucune adaptation secrète des ennemis au build.

Il faut des identifiants stables de biome et de rencontre indépendants des récompenses et de la position graphique. Deux routes qui se rejoignent tôt peuvent proposer ensuite une bifurcation commune ; l'itinéraire initial conserve sa valeur par l'expérience acquise, les objets et une conséquence racontable.

## 6. Récompenses et préparation : spécialiser, compléter, économiser

L'offre de récompense existante contient déjà technique, équipement et provisions selon le palier. Améliorer d'abord sa pertinence, à budget constant.

- Aux jalons importants, garantir au moins une proposition utilisable avec ce qui est découvert. Montrer si une technique remplace un sort équipé ou restera en réserve.
- Offrir une tension entre un élément qui renforce le style actuel, un outil pour la prochaine menace annoncée, et les ressources pour une halte. Ce sont des fonctions de choix ; il ne faut pas ajouter trois récompenses cumulatives.
- Conserver des offres hors spécialisation : un objet de poussée peut donner envie d'essayer Heurt. Éviter toutefois une succession d'offres qui demandent toutes une branche encore inaccessible.
- Distinguer le choix durable des points investis et l'ajustement libre de la barre entre combats. Voir la prochaine famille ennemie doit permettre de changer un ou deux sorts connus, sans imposer un remboursement permanent de l'arbre.

Exemple : Achille dispose de Frappe, Crochet, Percée et Garde. Une récompense propose le Levier des Myrmidons, qui valorise une cible déplacée ; une technique connue ou accessible répond au groupe annoncé ; les provisions financent la prochaine halte. Le joueur choisit entre renforcer son ouverture, gagner une réponse aux ennemis suivants, ou préserver sa run. Les objets déjà présents suffisent à commencer ce test.

Événement narratif proposé pour le Léthé : à une halte, oublier une technique de réserve en échange d'une autre technique proposée et entièrement visible, ou garder son répertoire et recevoir une petite compensation. Présélectionner les deux côtés de l'échange, protéger les prérequis et les formes, et demander de confirmer la perte explicite. Cette transaction est nouvelle ; elle doit rester hors du premier prototype de combat.

## 7. Objectifs et statistiques supplémentaires : sélection stricte

Introduire plus tard un objectif occasionnel par segment, avec les mêmes commandes de combat. Exemple de barque : des ennemis arriment le passage ; éliminer ou repousser deux porteurs d'entraves ouvre une sortie. Gagner par la sortie ou par élimination, sans double récompense, renforts infinis ni collecte répétable. L'ennemi restant crée un choix entre économiser des PV et terminer le combat pour une récompense secondaire annoncée.

Ne pas généraliser la défense d'un objet fragile : en solo, cela peut retirer trop de liberté et défavoriser certaines spécialisations. Les combats ordinaires doivent être intéressants avant cette extension.

Priorité aux statistiques présentes : armure et résistance magique, PA/PM, portée, Force et déplacement, boucliers et réserves de soin. Un nouveau statut temporaire lisible a davantage de valeur immédiate qu'une nouvelle caractéristique à monter. La riposte proposée est un état de combat à une charge, pas une nouvelle ressource de run.

## 8. Prototype recommandé et critères de décision

Construire d'abord une tranche I–VII, avec les trois entrées et leur halte IV. Garder les quatre sorts initiaux, les deux premiers points, les coûts et les budgets de récompense. Utiliser les ennemis et effets existants pour obtenir une version minimale de chaque problème. Comparer ensuite séparément l'ouverture prolongée et la riposte à la version témoin.

La première expérimentation croise trois préparations — Briseur, Chasseur, Airain — avec les trois familles, à statistiques et terrains documentés. Faire varier les dispositions, puis jouer le segment complet avec PV, récompenses et haltes persistants. Quelques réussites isolées ne valident pas la run.

À observer :

- Le joueur peut-il expliquer pourquoi il a choisi sa cible et sa séquence ?
- Change-t-il de plan entre deux variantes d'une même famille ?
- Les déplacements et Garde préviennent-ils une perte concrète, ou servent-ils seulement à dépenser les PA restants ?
- Combien de tours sont sans décision utile : marche, poursuite, nettoyage d'un ennemi inoffensif ?
- Quelles techniques sont rarement équipées, et faute de puissance, d'occasion ou de compréhension ?
- À arrivée comparable au carrefour : PV, soins consommés, XP, or, équipement, durée, élites traversées. Séparer novices et joueurs connaissant déjà la rencontre.
- Une route reste-t-elle choisie avec plusieurs préparations ? Un itinéraire meilleur dans toutes les situations demande une révision.

Réussite recherchée : le joueur peut dire « j'ai choisi cette route parce que mon Achille sait répondre à ce danger, mais je devrai corriger cette faiblesse avant le prochain carrefour ». Les valeurs chiffrées des nouvelles propositions resteront des hypothèses jusqu'à ces essais.

## État du travail

Recherche et lecture de sources terminées. Seul ce document a été ajouté pendant cette recherche complémentaire. Aucun changement au gameplay, aucun test moteur lancé ; le prochain travail concret est la tranche jouable I–VII et sa comparaison avec la version actuelle.
