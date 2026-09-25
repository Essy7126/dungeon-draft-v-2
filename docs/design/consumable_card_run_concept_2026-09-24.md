# Proposition — Les techniques volées aux Enfers

Date : 24 septembre 2026. Statut : concept à prototyper, aucune modification du gameplay. Les chiffres proposés ne sont pas un équilibrage validé. Examen du code et calculs de stocks, sans partie jouée pour cette variante.

Révision de cadrage : la proposition ci-dessous est historique. La demande suivante écarte la récupération des techniques ennemies et recentre le système sur les drops, l'économie et un deck de 30 cartes maximum. Voir `consumable_card_economy_2026-09-24.md`, qui remplace ce cadrage.

## Verdict

Oui, transformer chaque exemplaire de carte en consommable peut donner à Dungeon Draft une identité forte : on prépare une expédition, puis on renouvelle ses moyens de combattre avec ce que l'on rencontre. Le plaisir recherché devient l'improvisation maîtrisée, la récupération et l'arbitrage entre puissance immédiate et possibilités futures.

Ce changement diminue en revanche la garantie de rejouer régulièrement un combo précis. Si l'objectif prioritaire reste la répétition d'un moteur de deck perfectionné, cette proposition lui convient moins. Il faut préserver une identité permanente au personnage pour que le renouvellement des cartes ne devienne pas une succession de builds subis.

## 1. Contrat des cartes

- Départ avec **15 exemplaires**, sélectionnés dans un catalogue de départ équilibré. Deux exemplaires d'une même technique représentent deux utilisations. Un budget de départ empêche de choisir quinze techniques exceptionnelles.
- Une carte effectivement jouée disparaît définitivement du stock de cette run. Sa famille reste connue du codex et d'autres exemplaires peuvent être obtenus.
- Une carte simplement piochée, conservée, défaussée en fin de tour ou remplacée n'est pas consommée. Les cartes inutilisées peuvent revenir en main ; les cartes jouées ne reviennent jamais.
- Les PA, les déplacements, les contraintes de ciblage et les contreparties tactiques restent nécessaires : posséder dix cartes puissantes ne permet pas de toutes les jouer immédiatement.
- Attaque et garde d'arme restent disponibles sans carte. Elles évitent le blocage complet, mais leur utilisation prolongée devra être mesurée : une économie optimale fondée sur des dizaines de tours d'attaques gratuites serait un échec.
- Pour un premier prototype, conserver la main actuelle et la recomposition existante afin d'isoler l'effet du changement. Tester une main plus grande ensuite seulement si la perte des cartes provoque trop de mains inutilisables.
- Stock limité à 24 exemplaires, tous dans le circuit de pioche. Pas de deuxième réserve dans ce premier prototype. Ce plafond est une hypothèse : il crée de la circulation mais peut pénaliser les cartes situationnelles. Les récompenses restent dans un plateau temporaire jusqu'au choix ; aucune destruction automatique du surplus.

L'interface distingue sans ambiguïté « jouée : consommée » et « défaussée : conservée ». Le compteur de réserve et les prochaines sources d'approvisionnement doivent être visibles.

## 2. Le personnage reste, ses techniques circulent

Classe, maîtrises, équipement et passifs portent la progression durable de la run. Les améliorations importantes s'appliquent à une famille ou à une règle de combat plutôt qu'à un seul exemplaire condamné à disparaître.

Exemples de directions, non implémentées :

| Identité | Règle permanente possible | Cartes recherchées |
|---|---|---|
| Duelliste | La première esquive réussie prépare une riposte | Déplacement, attaque précise, parade |
| Géomancien | La première collision du tour renforce le prochain bouclier | Poussée, obstacle, charge |
| Pyromancien | Une cible enflammée laisse une braise exploitable à sa mort | Propagation, attraction, explosion |
| Pilleur | Une récupération en combat accorde un avantage de positionnement | Désarmement, mobilité, contrôle |

Ces identités doivent fonctionner avec plusieurs familles de cartes. Une classe qui exige une carte nommée rare serait trop dépendante du butin. Éviter les passifs de duplication illimitée, qui annuleraient le principe consommable et domineraient l'économie.

## 3. Un butin lisible et exploitable

Hypothèse de départ : six exemplaires après un combat normal, neuf après un élite. Le butin du boss final ne finance pas les combats qui le précèdent et ne doit pas entrer dans leur budget.

Un paquet normal comporte :

1. Trois cartes de ravitaillement : une offensive, une défensive et une de mobilité ou contrôle. Compatibilité avec les maîtrises vérifiée ; une de ces cartes au moins appartient à la classe principale.
2. Deux trophées liés à la famille ennemie : un gardien donne des protections ou des poussées, un archer des tirs ou des retraites. Les familles possibles sont annoncées avant le combat.
3. Une carte choisie parmi trois propositions, pour orienter le build.

L'élite ajoute trois exemplaires, dont une technique distinctive garantie. Le nombre exact de cartes rares reste à régler. La difficulté devrait augmenter l'exigence tactique avant de supprimer le ravitaillement minimal : sinon un joueur en difficulté perd aussi les moyens de se rétablir.

Le hasard porte principalement sur les identités et combinaisons. La quantité minimale, les fonctions présentes et les points d'approvisionnement sont prévisibles. Une meilleure maîtrise peut améliorer un trophée, mais les provisions de base ne dépendent pas d'un combat parfait.

### Extension distinctive : obtenir une technique pendant le combat

Un porteur marqué peut céder une de ses techniques quand on le désarme ou le vainc. Exemple : neutraliser un archer permet de récupérer son tir de recul pour repousser ensuite le gardien. Le butin devient une décision de cible et de positionnement.

Cette carte est prélevée sur le budget de six ou neuf, avec un reçu unique. Un ennemi invoqué ne crée pas de récompense supplémentaire. Un échec de récupération ne supprime pas le ravitaillement garanti de victoire. Pour la première version, distribuer le butin après combat ; ajouter ensuite cette récupération sans multiplier simultanément toutes les règles.

## 4. L'économie doit remplacer, orienter et parfois tenter

Conserver une seule monnaie existante. Les cartes elles-mêmes sont le second bien échangeable ; pas besoin d'ajouter des poussières, cristaux et jetons pour le prototype.

| Transaction proposée | Fonction | Limite |
|---|---|---|
| Trois communes contre deux communes choisies | Réparer un stock mal adapté | Catalogue et nombre d'échanges limités par halte |
| Une rare contre trois communes | Sacrifier la puissance pour retrouver des options | Raretés et valeurs vérifiées |
| Achat d'un paquet fonctionnel | Acheter de la défense ou de la mobilité | Prix et disponibilité annoncés avant la halte |
| Commande au prochain refuge | Préparer un combo plutôt qu'espérer | Paiement immédiat, livraison finie et déterministe |
| Contrat thématique ponctuel | Donner une valeur alternative à un trophée | Une seule exécution par contrat |

Exemple de contrat : remettre deux cartes de feu donne une protection contre le prochain secteur brûlant. Le joueur renonce à deux actions offensives pour sécuriser sa route. Le contrat doit être visible assez tôt pour que conserver ces cartes soit une décision informée.

À titre de grille de test uniquement : commune achat 4/revente 1, rare 10/3, exceptionnelle 20/7. Les revenus actuels devront être recalibrés avant d'utiliser ces prix. Les paquets achetés ne doivent pas laisser de profit immédiat à la revente ; vérifier aussi les cycles qui combinent troc, réductions, contrats et vente. Stock marchand fixe pour la visite, aucune actualisation gratuite exploitable.

Ne pas rémunérer systématiquement la destruction volontaire d'une carte : cela encouragerait la conversion administrative et créerait une nouvelle boucle à équilibrer. Ne pas lier le butin au nombre de cartes dépensées : jouer dans le vide deviendrait rentable.

Les haltes servent d'abord à transformer les ressources disponibles. L'achat massif de cartes ne doit pas devenir une taxe obligatoire sur chaque victoire. Un premier accès à la conversion avant le quatrième combat mérite un test spécifique.

## 5. Budget sur la route actuelle

La route comprend douze combats : huit normaux, trois élites, puis le boss. Avec 15 cartes au départ, six par normal et neuf par élite, **90 exemplaires** sont disponibles au total avant et pendant cette succession. Cela ne garantit ni leur adéquation, ni leur disponibilité au bon moment.

| Hypothèse de dépense par normal / élite / boss | Consommation totale | Solde théorique sur 90 |
|---|---:|---:|
| 4 / 6 / 10 | 60 | +30 |
| 6 / 9 / 12 | 87 | +3 |
| 9 / 12 / 15 | 123 | −33 |

Ces profils sont des hypothèses de sensibilité, pas des comportements observés. Le solde ignore les achats, le plafond, les restrictions d'utilisation et l'ordre de disponibilité.

Un premier calcul séquentiel a également testé quatre cartes gratuites à chacun des trois refuges et six avant le boss : 108 cartes disponibles au total. Avec le plafond à 24, le profil économe déborde de 34 exemplaires et termine avec 14 ; le profil intermédiaire déborde de neuf et termine avec douze. Le profil dépensier ne peut pourtant pas financer sa dépense prévue au quatrième combat : il commence avec six cartes pour un besoin supposé de neuf. Le calcul s'arrête là ; il ne simule ni attaque d'arme, ni victoire, ni achat.

Trace : `artifacts/dev/20260924-consumable-card-concept/budget_scenarios.json`. Le champ `completed` signifie seulement « dépenses hypothétiques financées jusqu'au bout ».

**Décision de design proposée :** retirer les distributions gratuites automatiques des refuges de la première hypothèse, garder les échanges et achats ciblés, puis ajuster à partir du nombre réel de cartes jouées et de la durée des combats. Le système devra pouvoir aider un joueur dont la dépense élevée vient de difficultés de jeu, sans récompenser le gaspillage volontaire. Quinze cartes ne peuvent pas être déclarées suffisantes sans cette mesure.

## 6. Exemple d'une décision que le jeu actuel offre moins

Le joueur possède une Tempête, deux Parades et une Téléportation. Une Tempête termine maintenant un combat dangereux et évite des blessures ; la conserver prépare le prochain groupe d'ennemis ; la troquer finance plusieurs techniques ordinaires. Ces trois valeurs se concurrencent.

Il choisit un détour annoncé comme riche en cartes de déplacement, dépense sa Téléportation pour récupérer un trophée pendant le combat, puis utilise les nouvelles mobilités avec son passif de duelliste. Il a changé ses moyens sans perdre son identité.

La carte rare peut être spectaculaire : sa consommation autorise des effets plus décisifs. Elle ne doit pas être simplement une attaque ordinaire avec 10 % de dégâts de plus. Exemples à tester : inverser les positions de deux ennemis, convertir une zone dangereuse en protection, déclencher les marques accumulées, sauver une unité d'une attaque annoncée. Chacun doit résoudre des situations identifiables plutôt que surpasser toutes les cartes communes.

## 7. Faisabilité dans le code actuel

La base existe : exemplaires identifiés, inventaire, boutiques, vente, récompenses et reçus de butin. Les sorts et leurs résolutions restent réutilisables. Le chantier principal porte sur le cycle de vie des exemplaires, les contrats de sauvegarde et l'économie.

- `core/expedition/catabase_cards.gd`, `consume` : actuellement l'exemplaire joué rejoint la défausse. Il faut une consommation persistante et son retrait de toutes les piles pertinentes.
- Même fichier, `begin_combat` et `_draw` : reconstitution depuis le deck actif et recyclage de la défausse. Le recyclage ne doit concerner que les cartes encore possédées et inutilisées.
- `core/expedition/class_cards.gd`, `valid_deck` : contrat actuel de dix cartes exactement, incompatible avec un stock qui diminue. Il faut valider un stock variable, y compris vide avec les actions d'arme disponibles.
- `class_cards.gd`, `grant_loot`, et le catalogue de drops : remplacer les quantités aléatoires parfois nulles par des paquets garantis et traçables.
- `buy`, `sell` et sauvegarde : ajouter le troc comme transaction atomique ; prévenir duplication par rechargement ou annulation d'une vente après réutilisation d'un exemplaire.
- Vérifier le lien avec les limites d'usage et délais par famille de sort : deux exemplaires ne doivent pas contourner accidentellement une limite tactique existante.
- Versionner les sauvegardes et isoler ce contrat de règles. Ne pas convertir silencieusement les runs existantes.

La dépense est engagée une seule fois quand le lancement du sort est accepté. Une cible invalide ou une annulation préalable ne consomme rien ; une attaque légalement lancée puis esquivée consomme la carte. Effet et inventaire doivent rester cohérents en cas d'interruption ou de reprise.

## 8. Prototype et critères de décision

Commencer avec un sous-catalogue couvrant attaques, défense, mobilité et contrôle, puis deux identités permanentes contrastées. Utiliser la route existante, des drops déterministes pour les premiers essais et un marchand avec conversion. Ajouter le hasard et la récupération pendant combat après avoir mesuré ce socle.

Mesurer par combat : stock initial/final, cartes jouées par fonction, tours aux seules actions d'arme, cartes réellement utilisables, blessures, temps passé en inventaire, surplus abandonné, achats et échanges. Mesurer également les cartes rares gardées toute la run et demander pourquoi : conservation stratégique et peur de manquer ne sont pas équivalentes.

Comparer à la version actuelle avec les mêmes rencontres et plusieurs niveaux d'expérience. Les tests automatiques nécessaires à une implémentation couvriraient consommation unique, ciblage invalide, défausse sans destruction, absence de résurrection au combat suivant, reprise de sauvegarde, troc sans duplication, stock vide et plafonds. Ils n'ont pas été exécutés pour cette proposition.

Critères qualitatifs : le joueur dépense volontiers une bonne carte ; il peut expliquer pourquoi il choisit une route ou un troc ; son identité reste reconnaissable ; une mauvaise rencontre ne le condamne pas mécaniquement à plusieurs combats d'attrition. Arrêter ou revoir la variante si l'optimisation dominante consiste à ne jamais jouer les cartes, si les marchands sont des péages obligatoires, ou si les manipulations d'inventaire prennent le dessus sur les décisions tactiques.

## Référence externe directement pertinente

Dans [l'entretien Nintendo avec les créateurs de Paper Mario: Sticker Star](https://iwataasks.nintendo.com/interviews/3ds/papermario/0/3/), l'équipe explique avoir rencontré la peur d'épuiser les attaques consommables. Elle décrit un approvisionnement abondant et des usages différenciés pour encourager leur utilisation. C'est un retour de développement pertinent pour notre hypothèse, pas une preuve que notre proposition sera plaisante ou équilibrée. La récupération rapide et satisfaisante y est également discutée : notre écran de butin devra éviter de transformer six acquisitions en six manipulations répétitives.
