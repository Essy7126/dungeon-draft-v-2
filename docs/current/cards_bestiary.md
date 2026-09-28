# Bestiaire des nouvelles runs Cartes

Révision de bestiaire 1, ajoutée le 28 septembre 2026 à Cartes consommables
(règles 4, route 6). Elle est choisie à la préparation d'une nouvelle partie.
Une sauvegarde sans `bestiary_revision` conserve la révision 0 et ses rencontres.
Le graphe canonique de la route, son empreinte et les ressources natives ne sont
pas modifiés. Classique et les laboratoires conservent leurs règles.

## Rencontres et intentions

| Profondeur / combat | Composition ajoutée | Décisions recherchées |
|---|---|---|
| 2 / 2 | Mêlée + archer squelettes ; compagnon de branche conservé sur les chemins à trois ennemis | Approcher le tireur, séparer les voisins du combattant de mêlée |
| 6 / 5, élite | Centurion de glace + chef rouge + mêlée + archer | Prioriser le commandant, quitter le contact avant Sentence, occuper les cases d'invocation |
| 8 / 6 | Dialecticien à la place du conducteur, deux compagnons de branche | Isoler le soutien, choisir entre concentrer les dégâts et poursuivre le mage |
| 17 / 11 | Dialecticien à la place du premier lanceur, deux compagnons | Retrouver le soutien avec des valeurs de fin de run |

Il existe **un centurion de glace** dans les définitions intégrées ; le chef rouge,
le squelette de mêlée et l'archer forment le reste de la famille.
Les autres rencontres conservent les rôles Cartes et les quatre variantes
obligatoires. Les mécaniques de salle continuent à fonctionner.

## Identité conservée, valeurs adaptées

Les cinq ennemis passent par `EnemyAI`, `EnemyTurnRunner` et `SpellCaster`, avec
leurs scènes, animations et identifiants de sorts d'origine. Les autres ennemis
continuent d'utiliser l'exécution générique Cartes. Les dégâts directs et différés
des kits natifs appliquent la défense linéaire Cartes, Faiblesse, la réduction du
premier coup et les réactions du Gardien.

| Ennemi | PA / PM | Rôle et contraintes |
|---|---|---|
| Mêlée | 4 / 3 | Lame une fois par activation ; +30 % arrondis contre la marque du commandant lié ; +8 armure par voisin vivant orthogonal, allié **ou ennemi**, deux voisins maximum |
| Archer | 2 / 2 | Un tir physique par activation, portée native de six cases et ligne de vue |
| Chef rouge | 6 / 2 | Coup du chef ou Sentence annoncée ; Sentence vaut 1,65 frappe, pousse de 1 et consomme l'activation suivante même si la cible échappe ; résistance au premier déplacement forcé conservée |
| Centurion | 6 / 2 | Marque liée à sa source, lance de givre et retrait de 1 PM, égide de +20 résistance magique, deux types d'invocation annoncée |
| Dialecticien | 4 / 2 | Axiome à distance ; Réfutation au contact et poussée ; Maïeutique ; Aporie −2 PM sans étourdissement ; Égide du Logos |

Le centurion privilégie la marque, puis les invocations et la protection avant
sa lance, selon son IA native. La marque s'efface à sa mort. Le chef ne peut
être relevé que lorsque le centurion est à 50 % de PV ou moins et qu'aucun chef
n'est vivant ou annoncé. Chaque invocation dispose d'**une tentative**, également
décomptée si la case est bloquée, si le lanceur meurt ou si Stase interrompt
l'annonce. Les renforts peuvent agir plus tard dans le même round : c'est la
sémantique existante de la file de tours.

Le soin du Dialecticien vaut `arrondi(0,4 × prouesse de référence)`, son bouclier
`arrondi(0,45 × prouesse)`. Les relances et durées natives sont conservées. Axiome
est borné à un lancer par activation pour ne pas doubler le budget offensif du
soutien. Réfutation vaut 60 % de sa frappe de référence.

## Budget vérifiable

Les PV initiaux sont répartis selon les poids du pack, dans le budget de PV déjà
défini pour ce combat. Poids natifs : mêlée 2,4 ; archer 1,2 ; chef 3 ; centurion
1,8 ; philosophe 1,5. Les valeurs des ennemis restent indépendantes du build du
joueur. La difficulté facile applique les multiplicateurs existants (PV ×0,9,
frappes ×0,8).

Pour l'élite de profondeur 6, prouesse 40 et budget 8,4 :

| Entrée | PV standard |
|---|---:|
| Centurion | 57 |
| Chef initial | 94 |
| Mêlée initiale | 75 |
| Archer | 38 |
| Invocation normale au maximum | 28 |
| Chef relevé au maximum | 44 |
| **Total maximal créé** | **336** |

Ainsi, 264 PV sont présents au départ et 72 PV sont réservés aux renforts, dans
les 336 PV de budget. Cette égalité ne prouve pas une difficulté équivalente :
soins, armure, contrôle, occupation des cases et délai des renforts influencent
la durée du combat. Une campagne de joueurs reste nécessaire pour ajuster ces
coefficients. Les tests vérifient les budgets sur les branches et les deux
difficultés ; ils ne mesurent pas un taux de victoire.

Le nombre d'ennemis initiaux est conservé. Seuls ces ennemis sont engagés dans
le registre de butin : invoquer, annuler ou recharger ne crée pas de tirage
supplémentaire. Aucun taux de drop ni prix n'est changé dans ce lot.

## Aperçu, sauvegarde et reprise

`consumable_enemy_profile.gd` projette la même définition dans l'aperçu public et
dans la salle avant la création des unités. Les fiches montrent les PA, PM,
PV, sorts, dégâts, soins, boucliers, relances et limites réellement utilisés
par les nouvelles runs. Les profils des anciennes sauvegardes restent distincts.

Les checkpoints de révision 3 ajoutent les invocations bornées, les budgets
déjà dépensés, les annonces en attente, l'orientation et la résistance au premier
déplacement forcé. Les références sont des identifiants stables, jamais des
ressources sérialisées arbitraires. Les anciens checkpoints 1/2 restent rattachés
au bestiaire 0. Les copies consommées et les engagements de butin sont conservés.

## Vérification reproductible

- `./dev.ps1 test consumable-v2` : règles, vraie légion, invocations, annonces,
  reprise et douze scènes réelles. Les passages de route des fixtures déclarent
  la victoire pour atteindre la salle ; ils ne simulent pas une campagne gagnée.
- `./tools/consumable_cards/verify_bestiary.ps1` : quatre salles publiques,
  huit captures en 1280×720, deux phases ennemies réelles par salle ; le héros
  passe sans jouer de carte. Consulter `observations.json`, les logs et les images
  sous `artifacts/dev/`, puis inspecter les captures.
- Les validations transversales requises et les résultats effectifs du lot
  figurent dans [la fiche de suivi](../ai/BESTIAIRE_CARTES_2026-09-28.md).
