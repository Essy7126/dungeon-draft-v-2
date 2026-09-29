# Intégration et protocole de prototype

Document de conception : aucune de ces modifications n'a été appliquée au moteur.

## État vérifié dans le code

La run publique utilise Catabase et la vraie Battle, vingt profondeurs et douze
combats. Les budgets sont quatre PA, trois PM, cinq cartes en main et quinze
copies au départ, trois au plus par famille. Les copies jouées disparaissent de
la traversée. Le départ offre les quatre normaux de classe et huit communs : un
Assassin ne peut actuellement pas commencer avec Onde du Léthé.

Les trois attributs sont Power/Vitality/Resolve. Le validateur exige exactement
ces trois clés et un total inférieur ou égal à `floor(level/2)`. Les gestes
permanents, communs à toutes les classes, sont une attaque de contact de 0,28 P
et une garde de 0,25 P, chacun pour un PA et une utilisation par tour.

Une marque est capturée puis effacée avant l'impact admissible : le transport
doit être décidé avant cet effacement. Les surfaces sont limitées à deux groupes.
Il n'existe pas de dégâts génériques de collision ; Choc de masse donne de la
garde sur arrêt contre un mur fixe. Ne pas les compter comme déjà implémentés.

Sources : `data/cards/consumable_v2/catalog.json`, `docs/current/cards_v2.md`,
`core/expedition/consumable_card_math.gd`, `consumable_card_modifier.gd`,
`consumable_card_effects.gd`, `consumable_card_terrain.gd`,
`consumable_card_economy.gd` et `consumable_cards_state.gd` dans ce même dossier.
Les empreintes principales sont dans `CALCULS.json`.
HEAD observé : `5b3553c07472180d4af08ce4ebdd5ed42362766f`.
Les changements concurrents n'ont pas été réécrits pour cette étude.

## Identité permanente de classe

Une fois les copies dépensées, les classes doivent encore se jouer différemment.
Pistes à chiffrer, distinctes des maîtrises :

| Classe | Geste permanent candidat | Choix à préserver |
|---|---|---|
| Assassin | Frappe consommant éventuellement une marque existante | Économiser une copie de finisseur, perdre son rendement |
| Gardien | Heurt court avec poussée conditionnée à une garde présente | S'exposer et maintenir une protection |
| Arpenteur | Tir court pouvant participer au déclenchement d'ancre limité | Position et portée contre dégâts immédiats |
| Thaumaturge | Impact magique interagissant avec une surface déjà préparée | Exploiter le terrain sans produire gratuitement les préparateurs |

Leurs coefficients et conditions ne sont pas définitifs. Les gestes garderaient
coût et fréquence bornée. Produire des marques ou brûlures illimitées pourrait
annuler l'intérêt des copies consommables. Le moteur exclut plusieurs procs des
fallbacks : faire participer un geste au passif est un changement de règle.

Éviter Assassin=Nuit et Gardien=Terre comme correspondances imposées. Les classes
orientent positions et risques ; les maîtrises orientent le répertoire. Réévaluer
Relais, contre de garde, ancre et déclencheur partagé du Thaumaturge.

## Accès aux fonctions et économie

Le tirage normal réserve 70 % au groupe « classe OU commun », uniformément parmi
douze familles. Cela représente **23,33 % de vrais natifs**, 46,67 % de communs et
30 % d'étrangers. Une famille normale étrangère précise vaut 2,5 % par copie
normale tirée. Ce n'est pas 70 % de cartes adaptées à une future lignée.

Préparer des départs autour de fonctions compatibles, quelle que soit leur classe
d'origine. Dans les haltes existantes, proposer une offre normale ciblée de
réapprovisionnement ; enregistrer son stock. Mesurer les combats sans préparateur
ou sans consommateur : un sac de finisseurs de la bonne couleur ne suffit pas.
Conserver les trouvailles étrangères utiles sous leur forme normale.

Les achats ciblés existent : utiliser les services de catalogue et d'économie et
les outils Studio. Les probabilités futures nécessitent une simulation de traversée.
Aucun marchand, réserve ou parcours parallèle ne doit être créé.

## Calculs et empilements

Un effet direct utilise `base de niveau × coefficient × facteur de maîtrise`.
Une marque conserve sa valeur après ses modificateurs propres ; elle est consommée
une fois. Une conversion prélève de la garde entière réelle puis applique son
coefficient, sans multiplier une deuxième fois la valeur transférée.

Équipement, passifs, spécialisations, améliorations et reliques ont déjà leurs
bonus. Leur ordre doit être explicite et partagé par l'aperçu et l'exécution.
Ne pas conserver un Power universel investi puis le multiplier encore par la
nouvelle maîtrise. Les contrôles discrets restent fixes : +4 % sur une case n'a
pas de sens ; une variante change la condition, la géométrie ou le compromis.

Le prototype garde la mitigation physique/magique sans ajouter cinq résistances
élémentaires ni une deuxième barre d'armure. Affinité et mitigation seront donc
deux informations à rendre lisibles. Les ennemis contrent aussi les plans par
leurs déplacements et intentions, pas seulement par des pourcentages.

## Sauvegarde et résolution

Versionner le schéma des maîtrises, budgets et variantes ; définir une migration
déterministe sans distribuer deux fois des points ni supprimer une ancienne run.
Le dépôt et l'explosion enregistrent propriétaire, provenance, valeur, case,
échéance et consommation. Aucun recalcul rétroactif après équipement.

Le dépôt arrive après les dégâts de l'onde. **Une cible déjà marquée conserve sa
marque ; le dépôt attend un autre receveur jusqu'à son échéance.** Aucune fusion.
Le dépôt non récupéré expire au plus tard en fin de prochaine phase ennemie ; une
marque récupérée reprend son échéance initiale, pas celle du dépôt. La distinction
évite de supprimer toute marque avant que le héros puisse l'exploiter au tour suivant.
L'explosion résout après les activations de la prochaine phase ennemie, une fois.
Valider les décisions avant paiement : un refus ne dépense ni garde ni copie.
Recharger ne rend pas une carte et ne rejoue pas une réaction résolue.

## Validation à réaliser lors de l'implémentation

Les calculs Python ont été exécutés et les probabilités recoupées par énumération
exhaustive des mains. **Cela ne valide pas Godot.** Sans modification de moteur,
les tests du jeu n'ont pas été relancés pour cette étude.

- Transport : valeur/échéance conservées, aucune duplication avec Relais, surface
  remplacée, cible déjà marquée ou reprise.
- Ébullition : brûlure remplacée, jamais additionnée ; vapeur distincte de l'eau.
- Conversion : garde réellement perdue, héros vulnérable à l'explosion, sortie de
  zone efficace et résolution unique.
- Aperçu : même résultat après résistance, garde, arrondi, équipement et passifs.
- Gestes permanents : limites respectées, aucun générateur infini de ressources.

Exécuter `./dev.ps1 test cards`, les gates CI obligatoires et `all` pour le moteur
commun. Vérifier la vraie Battle, le départ public, deck, progression et reprise
en combat. Les harnais isolés ne prouvent pas l'intégration.

Comparer mono, double et triple domaine à budget, équipement, stock et graines
égaux : cible isolée, groupes dispersés/compacts, boss mobile, surfaces difficiles.
Inclure un témoin jouant des sorts indépendants. Mesurer dégâts utiles, tours,
PV perdus, copies dépensées, disponibilité des fonctions et refus d'une variante.
Aucun taux de victoire ni avantage général n'est revendiqué à ce stade.
