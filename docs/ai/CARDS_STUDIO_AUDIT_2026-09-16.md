# Catabase Cartes — audit expérimental gameplay / QA / UX

Statut : **AUDIT TERMINÉ — WORKTREE_CANDIDATE**, vérifié le 16 septembre 2026.
Dépôt : `Essy7126/dungeon-draft-v-2`, branche `main`, HEAD de référence
`8d5e7b9c8e68a9699ff74f813f8630f001db4a02` + variante Cartes locale.
La conception visée est Catabase solo, Achille/Passe-rive, 30–45 minutes,
Facile accessible après quelques essais, Normal exigeant ; pas le trio historique.

## Verdict

**INFÉRENCE : le prototype est suffisamment fonctionnel pour itérer, mais son
intérêt propre de deckbuilding n'est pas encore démontré.** La priorité n'est
pas d'augmenter globalement les statistiques : rendre les décisions lisibles,
donner une valeur situationnelle aux drops, puis reprendre les confrontations
et l'économie avec un pilote compétent pour chaque kit.

180 runs comparatives et 1 493 combats réellement résolus ; 7 tests mécaniques,
71 689 assertions ; 90 contrôles UI et 12 captures neuves à 720p/1080p. Aucun
diagnostic moteur dans les lots retenus. Cela ne certifie ni le plaisir humain,
ni une difficulté juste, ni la durée de 30–45 minutes, ni la CI globale.

## Méthode et limites

- OBSERVÉ : combats avec les vrais GridData, EnemyAI, SpellCaster, PA/PM,
  dégâts, équipement, progression, continuité des PV et deux sauvegardes/reprises.
  Le banc n'exécute pas les animations/HUD pendant les runs headless.
- Trois graines appariées 7201/7202/7203, six **presets complets**, pas six armes
  isolées : les presets diffèrent aussi en protection, techniques et reliques.
  Un écart ne démontre donc pas la responsabilité de l'arme seule.
- Le héros simulé est le profil de règles `achilles`, présentation par défaut.
  Passe-rive n'a pas fait l'objet d'une campagne visuelle/animation séparée.
  Les itinéraires suivent `seeded_lane_v1` : pas d'optimisation exhaustive des
  branches, et le déploiement utilise la première case de départ autorisée.
- Le bot historique `balanced` dépense en réalité ses points en Vitalité
  prioritaire ; `pressure` en Puissance. Ce ne sont pas des joueurs moyens,
  ni un mélange 50/50 de statistiques. Les stratégies ont accès aux règles et
  aux états publics, pas aux prochaines cartes.
- Bots supplémentaires : `pilot` utilise le deck initial avec soin/conservation/
  recomposition ; `adaptive` remplace les techniques via un score explicite,
  vend le surplus et achète sous conditions ; `liquidate` vend sans changer le
  deck ; `swarm` ajoute jusqu'à 18 ; `speed` utilise l'adaptation avec la politique
  Puissance/pression. Score local, sans recherche exhaustive ni apprentissage.
- `informed` corrige uniquement l'estimation Répercussion du pilote ; `mobility`
  y remplace Second souffle par Feinte au départ ; `curated` reprend l'économie
  adaptative avec soin moins surévalué, ouverture offensive de familles distinctes
  et estimation Répercussion corrigée. Les comparaisons qui changent plusieurs
  règles de pilotage ne permettent pas une attribution causale à une seule carte.
- Le bot sait approcher/tirer/se protéger et utilise certaines spécificités
  d'armes, mais n'optimise pas les collisions, zones préparées, menaces futures,
  toutes les mutations, reliques et routes. Les décès de bots sont des pistes,
  pas des preuves de difficulté humaine ou d'impossibilité.
- Les transactions, distributions et progressions forcées sont des **fixtures**,
  pas des parties gagnées. Les 180 000 tirages réutilisent les pools initiaux ;
  ils valident la loi conditionnelle, pas 180 000 runs indépendantes.
- Tous les profils APPDATA sont isolés. Pas de modification d'équilibrage,
  de sauvegarde joueur, de branche, de commit ou de push pendant l'audit.

## Résultats de référence

| Bot historique, même protocole | Normal | Facile |
|---|---:|---:|
| Classique | 4 victoires / 18 | 11 / 18 |
| Cartes, deck de départ intact | 5 / 18 | 11 / 18 |

662 combats atteints sur ces 72 runs ; zéro erreur moteur ou run structurellement
invalide. Les échecs de combat sont conservés comme résultats, pas classés comme
erreurs de tests. Pas d'intervalle de confiance humain : seulement trois graines,
des bots déterministes et des essais fortement appariés.

| Preset | Cartes Normal | Cartes Facile | Profondeurs des défaites Normal |
|---|---:|---:|---|
| Arc | 2/3 | 3/3 | XX |
| Disque | 0/3 | 0/3 | VI, V, X |
| Hampe | 0/3 | 0/3 | V, III, VI |
| Lame | 2/3 | 2/3 | XX |
| Marteau | 1/3 | 3/3 | VI, VI |
| Xiphos | 0/3 | 3/3 | XX, XX, XX |

OBSERVÉ : Disque/Hampe échouent aussi en Classique. Ne pas les « réparer » en
retirant uniquement les cartes. Comparer armure, techniques initiales, pression
à distance, exposition sur le plateau et compétence du pilote.

OBSERVÉ : parmi les victoires Cartes Facile, Arc = 45/48/52 activations du
héros ; Xiphos = 111/118/123. Ce rapport est un signal à investiguer, **pas une
mesure fiable de la durée intrinsèque des armes** : le biais Répercussion
ci-dessous pénalise particulièrement le xiphos.

### Biais du banc identifié avant d'interpréter les armes

OBSERVÉ dans le code : le bot historique classe les attaques avec
`get_scaled_damage()`. Répercussion y porte un marqueur `0,01 × Prouesse` ; ses
vrais dégâts sont injectés dans le CastContext à partir de `1,5 × bronze consommé`.
Le bot ignore donc presque cette option en début de run. Ce problème est dans
**l'évaluateur de tests**, pas dans le résolveur du jeu.

Contre-test `informed`, même xiphos/deck, score tenant compte du bronze réel :
toujours 0/3 victoires Normal, décès XV/XV/XVII plutôt que XX, mais première
salle en 9/8/7 activations. Il dépense aussi sa réserve plus agressivement :
un estimateur plus exact ne donne pas automatiquement une politique optimale.

Contre-test `mobility` : même contrôle informé et même équipement, seul Second
souffle est remplacé au départ par Feinte latérale, choix légal du menu. Salle I
en 7/5/6 activations, zéro PV perdu, contre 9/8/7 et 6/6/0 PV pour `informed`.
Une victoire Normal sur trois, en 92 activations et avec 15 PV restants ; deux
défaites VI/XV. Cela montre une option réelle d'accès au contact, **pas une
solution universelle** ni une preuve qu'il faut supprimer le soin du preset.

### Éprouver la construction de deck

| Politique Cartes supplémentaire | Victoires Normal | Facile | Combats atteints |
|---|---:|---:|---:|
| Pilote soin/conservation, départ inchangé | 2/18 | non testé | 131 |
| Adaptation naïve + achats/ventes | 0/18 | 6/18 | 321 |
| Adaptation corrigée `curated` | 2/18 | non testé | 137 |
| Tout revendre, départ inchangé | 1/6 | non testé | 43 |
| Ajouter jusqu'à 18 cartes | 0/6 | non testé | 38 |
| Puissance/offensive « vitesse » | 0/18 | non testé | 103 |
| Xiphos, estimation corrigée | 0/3 | non testé | 31 |
| Xiphos, estimation corrigée + Feinte | 1/3 | non testé | 27 |

Ces 108 runs complètent les 72 de référence. Les deux lots de six n'utilisent
que 7201 ; les deux lots de trois ne concernent que le xiphos. **Une adaptation
naïve perdante ne prouve pas que modifier son deck est mauvais.** Elle peut
surévaluer le soin et préparer deux exemplaires d'une même famille, voire un
soin à pleine vie. Le pilote corrigé gagne deux fois avec Arc, en 48 activations.
L'ouverture, l'ordre et la situation comptent davantage qu'un score dégâts/PA.

La politique de surcharge atteint 3,17 familles en moyenne sur 260 tours
échantillonnés, contre 2,78 sur 735 pour `curated`, sans meilleure réussite.
C'est une indication que **variété disponible et qualité du plan sont différentes**,
pas une preuve que tous les decks de 18 sont faibles. `curated` réalise 15 achats,
73 intégrations et 151 ventes sur ses 18 essais. Les intégrations mélangent copies
de maîtrise, achats et drops : on ne peut pas en tirer un taux d'adoption du butin.
Les PA non dépensés et l'absence de cible offensive au début du tour ne signifient
pas automatiquement « tour mort » : déplacement et préparation restent possibles.

### Speedrun : indicateur d'efficience, pas record chronométré

- Meilleure victoire Classique Normal observée : Arc, 7203, **43 activations**,
  86 sorts et 51 actions de déplacement.
- Meilleures victoires Cartes Normal : Arc `curated`, 7201/7203,
  **48 activations**, respectivement 99/101 sorts et 63 déplacements.
- Meilleure victoire Cartes Facile : Arc initial, 7203, **45 activations**,
  85 sorts et 52 déplacements.
- La politique offensive Puissance échoue 18/18, au plus tard en XV. Elle
  modifie aussi les priorités de récompense : ce n'est ni une preuve que la
  Puissance est mauvaise, ni une recherche optimale de speedrun.

Les secondes headless sont explicitement nommées `machine_seconds_NOT_playtime`
dans les CSV. Aucun record humain n'est annoncé. Exemple de budget, **pas mesure** :
si les menus prennent 8 minutes, une run 30–45 minutes laisse environ 28–46 secondes
par activation sur 48 tours, mais 14–24 sur 92. Ces secondes doivent inclure
réflexion, saisie, animations et réponse ennemie. Le rythme doit donc être validé
par profil et par segment de jeu, pas à partir du seul nombre de salles.

## Solidité mécanique

7 tests ciblés, **71 689 assertions PASS**, zéro diagnostic moteur :

- 180 000 tirages pondérés dans 18 cas conditionnels (6 presets × 3 phases de poids).
- 6 000 tentatives de transactions : 2 562 mouvements de deck, 1 095 ventes,
  1 003 annulations acceptées ; les rejets sont normaux. Deck légal et solde
  non négatif après chaque tentative ; 60 reprises JSON.
- 30 000 mains sur 6 × 1 000 séquences de cinq tours, sans jouer de sort :
  conservation de chaque copie dans une seule zone ; ouverture préparée constante.
- Parcours de récompenses I–XX forcés sur les six presets ; élites conformes.
- Une carte vendue laisse sa connaissance dans le grimoire, mais ne recrée pas
  de copie gratuite lors de `sync_learned`. Ce n'est pas un exploit de duplication.
- 1 000 séquences complètes route/butin, graines 9000–9999, pool initial figé,
  sans combat ni montée de niveau ; statistiques économiques ci-dessous.
- Répercussion résolue par le vrai SpellCaster : bronze 10/30/80, marqueur
  statique 0, mais contributions réelles avant mitigation 15/45/45 avec le
  plafond de dépense du profil testé. Le défaut de l'ancien évaluateur est confirmé.

Dette constatée : `recompose()` accepte un appel direct après la fin d'activation
du héros si les PA restent présents. L'UI réelle vérifie le tour et bloque le
bouton ; **pas d'exploit joueur démontré**. Renforcer l'autorité du modèle avant
de multiplier les entrées (raccourcis, manette, tutoriel, replay).

## Risques de conception à traiter

### 1. Une main de sorts n'est pas encore un deckbuilding riche

OBSERVÉ : départ 6 Gestes + 3 copies de technique A + 3 de B. Quatre cartes de
l'ouverture sont fixées ; à 4 cartes, cela donne trois familles et quatre sorts
potentiels, car Geste propose deux actions. En moyenne, les mains suivantes du
test de pioche comptent 2,50 familles, pas quatre décisions indépendantes.
87 mains sur 4 000 après ouverture n'ont aucun Geste (2,175 %) dans chaque preset.
Ce chiffre vaut pour la loi de pioche isolée sans jeu/conservation/recomposition.

INFÉRENCE : le risque est de conserver la rotation classique en lui ajoutant
une disponibilité aléatoire et du travail d'inventaire. Les contraintes PA,
portée, usages partagés et main doivent produire des décisions différentes,
pas seulement interdire une action attendue.

RECOMMANDATION : tester un petit noyau de cartes qui transforme l'espace ou
l'ordre des actions : déplacement + ligne de tir, collision qui recycle une
carte, protection conditionnée à une position, choix entre une carte conservée
et un bénéfice immédiat. Réutiliser les résolveurs existants. Ne pas commencer
par produire des dizaines de cartes « même effet, +20 % ».

### 2. Raretés et progression : cinq couleurs, moins de cinq pools vivants

OBSERVÉ : les six axes martiaux sont ouverts au départ ; les pools initiaux
Arc/Disque/Lame/Marteau sont identiques (14 familles). Hampe en ajoute trois,
Xiphos avec Urne en ajoute une. Sans Serment/Urne, Mythique/Légendaire ont un
taux effectif nul, même si le tableau nominal possède des poids pour ces rangs.
La seule famille légendaire du tableau est Répercussion. La rareté est attachée
à une famille ; le niveau affiché suit le héros, pas une XP par copie.

RECOMMANDATION : annoncer les prérequis réels et montrer le niveau d'effet
calculé. Donner un rôle identifiable à chaque rareté : fiabilité courante,
outil spécialisé, pivot de build, transformation sous contrainte. Une légendaire
ne doit pas être nécessaire à la victoire. Ne pas vendre cinq progressions
de puissance tant que le catalogue ne les exprime pas.

### 3. Économie : vendre ou jouer doit être un arbitrage, pas une corvée

OBSERVÉ : achat/revente 50/8, 75/12, 110/20, 160/32, 230/50. Pas de boucle
achat-revente profitable aux prix fixes. Le deck initial est lié/non revendable.
Les oboles servent aussi aux armes/objets/Péage ; l'argent ne peut être équilibré
comme une monnaie de cartes isolée. Les anciennes fournitures +40 oboles sont
retirées uniquement dans Cartes.

Sur les **1 000 séquences de butin avant Pâris**, pool initial Marteau de 14
familles figé, sans progression/découverte :

| Mesure | Moyenne | Minimum observé | Maximum observé |
|---|---:|---:|---:|
| Cartes obtenues | 16,77 | 14 | 23 |
| Familles différentes obtenues | 9,40 | 5 | 13 |
| Valeur si tout était revendu | 212,53 oboles | 156 | 304 |

Les bornes sont celles de cet échantillon, pas des garanties de production.
Il n'y a pas de drop de carte après le boss final dans le code actuel.
Sur une route à onze récompenses de fournitures avant le boss, Classique peut
apporter 440 oboles supplémentaires. La revente simulée ne les remplace qu'à
48,3 % en moyenne, soit **227,47 oboles de moins**, avant toute carte conservée.
Ce n'est pas une comparaison à valeur totale égale : Cartes reçoit les cartes
et peut choisir d'autres récompenses ; Classique renonce à ces autres choix.
C'est toutefois un changement de budget à vérifier auprès des mêmes services,
pas un simple ajout gratuit d'économie à l'équilibrage antérieur.

RECOMMANDATION : budgets de référence à l'entrée de chaque marchand/refuge,
avec trois politiques explicites (conserver, remplacer, vendre). Ne pas combler
automatiquement les 227 oboles : tester d'abord si conserver une bonne carte
rend impossible un achat de survie nécessaire. Séparer frustration économique
et arbitrage volontaire ; garder le Péage dans les dépenses de combat.

RECOMMANDATION : mesurer par famille les drops obtenus, réellement intégrés,
joués au combat, gardés en réserve et vendus. Une carte très souvent vendue peut
être une récompense monétaire intentionnelle, mais si presque tous les drops le
sont, le deckbuilding ne porte pas la progression. Conserver 12–18 librement
ne garantit pas l'intérêt de 18 : documenter la dilution et fournir une raison
concrète de grossir le deck, pas un bonus de taille arbitraire.

### 4. Difficulté : distinguer accès, menace et longueur

RECOMMANDATION : examiner d'abord III–VI et les rencontres de VI avant le premier
refuge ; utiliser les traces de coups/positions et comparer plusieurs protections.
Pour Xiphos, distinguer une vraie faiblesse contre Pâris d'une victoire possible
mais trop longue. Une hausse globale des PV allongerait aussi les builds déjà lents.
Préserver la difficulté par des priorités, lignes, préparations et fenêtres de
contre-jeu lisibles, avec récupération limitée, plutôt que par une taxe permanente.

### 5. Les contraintes doivent être explicables avant le clic

OBSERVÉ par lecture : les boutons de la main consultent `actor.can_use_spell`,
qui connaît PA, recharge et quotas, mais pas les prérequis de terrain/arme/Urne
validés ensuite par SpellCaster. « Retour » peut donc paraître sélectionnable
avant de lancer le disque ; Répercussion avant d'avoir du bronze. Le vrai cast
est protégé, mais l'interface doit distinguer **payable**, **préparé** et
**cible valide**, afficher le motif et la ressource manquante.

RECOMMANDATION : afficher une seule explication prioritaire (pas une liste de
conditions), l'état du disque/Urne/Péage et une fiche de dégâts calculés avec
ses hypothèses. C'est également nécessaire pour tester justement ces builds.

## Lecture visuelle et charge mentale

Probe neuf terminé : **90 contrôles PASS, 12 captures**, titre, main de quatre
et six cartes, butin, réserve, boutique, en 1280×720 et 1920×1080. Vérification
visuelle complémentaire des captures ; les états butin/refuge sont préparés
par fixtures, pas obtenus par une victoire humaine. Conservation, réduction
de la main et achat utilisent les vrais contrôles UI.

- La main prend une grande bande au-dessus du HUD, tandis que l'ancien HUD de
  sorts est en grande partie vide. À six cartes, son rectangle couvre **16,96 %
  du viewport 720p** et **7,84 % en 1080p**, sans espace plateau réservé ; le bas
  de l'ennemi est effectivement masqué sur la capture 720p.
- À six cartes, estimation de **9 boutons tronqués à 720p, 8 à 1080p**,
  confirmée qualitativement à l'image. Le coût PA reste visible,
  mais pas assez d'information pour comparer effet, portée et restriction.
- La réserve montre les copies une par une : les six Gestes occupent les premières
  lignes et repoussent les nouveautés sous le défilement.
- Un menu déroulant global de remplacement demande de mémoriser la carte cible,
  puis d'aller cliquer la nouvelle ; le défaut « ajouter » peut diluer le deck.
- Le butin acquis et la récompense complémentaire choisie sont correctement
  distingués en texte, mais rivalisent dans un long écran défilant.

RECOMMANDATION prioritaire : main intégrée au HUD avec espace plateau réservé ;
fiche de survol chiffrée ; réserve groupée par famille avec compteur ; panneau
comparatif entrant/sortant ; nouveautés en premier. La belle peinture actuelle
n'est pas le problème central : la hiérarchie d'information l'est.

![Main de six cartes, capture réelle 720p](../../artifacts/catabase_run_balance_validation/audit_ui_20260916/cards_combat_six_1280x720.png)

**Performance non concluante** : 120 échantillons `Performance.TIME_PROCESS`
par résolution, scène immobile, renderer local hors écran. Valeurs instables
après captures GPU et monitor rafraîchi moins souvent que l'échantillonnage
possible ; ce n'est pas une mesure directe d'intervalle de présentation.
Les médianes observées 355,57 ms/17,52 ms et p95 426,14 ms/819,08 ms ne doivent
pas être convertis en FPS du jeu. Les 826 draw calls observés constituent un
point à profiler, pas un verdict GPU. Mesurer séparément le vrai jeu au premier
plan, après chauffe, avec animations et combats chargés sur matériel cible.

## Comparaisons transférables, pas imitation de catalogue

- **Slay the Spire** : Giovannetti décrit l'itération, les métriques, les testeurs
  experts et l'observation ; les données ne remplacent pas un jugement de design.
  Appliquer ici les taux d'intégration/jeu/vente par contexte et compétence, pas
  copier un taux de victoire agrégé. [Slides GDC 2019](https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf).
- **Into the Breach** : contraintes de lisibilité, menaces annoncées et temps
  perdu réduit ont guidé les règles et les coupes de contenu. Transfert : faire
  du plateau un problème lisible dont les cartes proposent les réponses ; ne pas
  ajouter davantage de sous-systèmes sans contre-jeu visible. Nous ne copions pas
  ses faibles nombres ni son système de trois unités. [Postmortem de Matthew Davis](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf).
- **Monster Train** : ses trois étages et la montée ennemie créent une contrainte
  propre autour de laquelle le deck se construit. Pour Catabase, cette identité
  doit venir des dalles, déplacements et préparations, pas d'une simple couche
  de rareté. [Présentation officielle](https://www.themonstertrain.com/index.html).
- **Fights in Tight Spaces** : la proposition officielle lie explicitement main,
  ressource et position ; l'environnement et les objectifs de protection participent
  aux combats. Transfert : évaluer la valeur d'une carte par les situations qu'elle
  résout, pas seulement ses dégâts/PA. [Présentation du développeur sur Steam](https://store.steampowered.com/app/1265820/).

## Validation humaine indispensable après ce lot

### Ordre de travail recommandé — pas de changement de conception validé ici

| Priorité / nature | Modification proposée | Critère de sortie mesurable |
|---|---|---|
| P1, UX fonctionnelle | Intégrer la main au HUD et réserver le plateau ; montrer noms, coût, cible et restriction | À 720p/1080p, mains de 4/6 : aucun bouton critique tronqué ; aucune unité ou menace masquée par la main ouverte dans les cadrages testés |
| P1, retour de règle | Motif d'indisponibilité cohérent avec les validations du moteur, notamment disque/bronze | Tests « sans disque », « sans bronze », « PA insuffisants », « cible invalide » ; motif correct avant tentative, aucune nouvelle autorisation de cast |
| P1, preuve d'équilibrage | Pilotes compétents par kit, puis ablations armure/technique/déploiement dans III–VI et Pâris | Même graine et même équipement sauf variable étudiée ; traces expliquant accès au contact, dégâts évitables et temps de poursuite ; validation humaine avant buff/nerf |
| P1, boucle de récompense | Réserve groupée, nouveautés visibles, comparaison entrante/sortante et budget par halte | Une carte obtenue se compare/remplace sans chercher parmi les six Gestes ; mesurer jeu/vente par provenance et famille ; aucun double paiement |
| P2, profondeur de deck | Petit lot de cartes à valeur spatiale/conditionnelle, sans refaire les statistiques de base | Pour chaque carte, au moins deux situations où elle change utilement le plan et une où une autre option est préférable ; aucun effet obligatoire pour finir |
| P2, autorité métier | Refuser `recompose()` hors activation du héros dans le modèle | Test direct hors tour refusé sans toucher PA/main ; scénario UI actuel toujours vert |
| P2, économie | Comparer les budgets conserver/remplacer/vendre aux coûts existants | Un tableau par halte, même route ; valeur des cartes jouées et dépenses de survie distinguées ; pas de revente rentable ni récompense duplicable |

Ne pas toucher à tous les leviers en même temps. Commencer par l'information et
la fiabilité du diagnostic ; l'état des tests ne justifie pas un nerf global de
l'Arc ni un buff uniforme Disque/Hampe/Xiphos. Le contraste du xiphos avec Feinte
justifie une expérience sur la mobilité, pas une conclusion universelle.

### Essais humains à réaliser

Protocole recommandé, pas déjà exécuté : 6 débutants du genre + 6 joueurs habitués,
ordre Classique/Cartes contrebalancé, graines consignées, deux premières sessions
sans conseils puis une tentative informée. Tester séparément temps d'apprentissage,
première victoire et maîtrise. Éviter de confondre nouveaux venus au jeu et novices
des deckbuilders. Étude formative : 12 personnes ne donnent pas un taux commercial.

Mesures : durée réelle hors pauses ; temps combat/menu/lecture ; décisions par
tour ; erreurs de compréhension ; causes racontées après une mort ; drops intégrés
et joués ; ventes regrettées ; usage de l'espace ; plaisir de rejouer. Critères de
travail à valider : joueurs capables d'expliquer leur défaite ; sortie du butin
simple en quelques secondes si aucun changement ; changement de plan observable
dans une majorité de rencontres ; temps 30–45 min évalué par preset, pas globalement.

Non couverts ici : émotion/frustration humaines, accessibilité complète et manette,
localisation, plateformes autres que Windows, QA exhaustive de toute combinaison,
stress GPU du pire combat, stabilité plusieurs heures, CI globale, vitesse humaine
record et rétention à long terme. Aucun bot ne certifie ces points.

Le concept initial envisageait également cartes à charges et permanents inédits.
Ils ne sont pas présents dans ce prototype et ne sont donc pas « validés » par
ce lot. L'audit teste le système réellement implémenté, pas tout le jeu futur.

## Reproduire / retrouver les preuves

- `artifacts/catabase_run_balance_validation/audit_cards_starter_20260916/`
- `artifacts/catabase_run_balance_validation/audit_classic_paired_20260916/`
- Les huit autres lots et leurs tailles sont listés dans `studio_analysis/analysis.json`.
- `artifacts/dev/20260916-150146-test-test_unit_test_cards_studio_audit.gd-b1342b08/gut-strict-report.json`
- `artifacts/catabase_run_balance_validation/studio_mechanics/observations.json`
- `artifacts/catabase_run_balance_validation/audit_ui_20260916/report.json`
- `artifacts/catabase_run_balance_validation/audit_ui_20260916/ui_observations.json`
- Agrégats : `studio_analysis/analysis.json`, `runs.csv`, `combats.csv`, `paired.csv`.

Principaux fichiers inspectés : `core/expedition/catabase_cards.gd`,
`expedition_session.gd`, `expedition_build_catalog.gd`,
`catabase_preparation_catalog.gd`, `catabase_first_six_spells.gd`,
`catabase_combat_modifier.gd`, catalogues/états de route, `core/game_manager.gd`,
`core/spell_caster.gd`, `battle/battle.gd`, `ui/expedition/catabase_card_hand.gd`,
`catabase_card_collection.gd`, `expedition_screen.gd`, bancs de validation.

Modifications de cette mission : tests et instrumentation, agrégateur CSV/JSON,
présent rapport, journal et suivi des problèmes. Les modifications de gameplay
préexistantes de la mission Cartes sont conservées ; **aucune règle, valeur de
production ou décision de conception n'a été changée pendant cet audit**.
`CURRENT_STATE`, `DECISIONS` et `BALANCE_BASELINE` ne sont pas requalifiés CURRENT
par cette campagne. Pas de commit ni push.

```powershell
./dev.ps1 test test/unit/test_cards_studio_audit.gd
./tools/catabase_run_balance_validation/run_validation.ps1 -Cards -AuditMode adaptive -Label NOUVEAU_LABEL -Seeds '7201,7202,7203' -Difficulties normal
./tools/catabase_run_balance_validation/ui_probe.ps1 -StudioAudit -Label NOUVEAU_LABEL_UI -TimeoutSeconds 300
# Exécuter analyze_studio_audit.py avec le Python local pour agréger les lots audit_*_20260916 terminés.
```

Un seul processus Godot à la fois. Prendre des labels neufs. Le script statistique
exclut les lots incomplets/échoués et le canari ; les durées machine ne sont jamais
présentées comme des temps de jeu. SHA-256 des principaux fichiers dans analysis.json.

Incidents d'outillage consignés : contrôle PowerShell de `$LASTEXITCODE` remplacé
par la lecture du résultat JSON ; annotation GDScript manquante dans le nouveau
pilote corrigée avant reprise ; filtre de l'agrégateur corrigé pour ne pas exclure
`liquidate` à cause des lettres « ui ». Le lot échoué `audit_liquidate_20260916`
(échec de parsing avant les runs) et le canari sont exclus des 180. Le remplacement
`audit_final_liquidate_20260916` passe. Aucun incident n'est compté comme victoire,
et aucune erreur du nouveau banc n'est présentée comme un bug de production.
