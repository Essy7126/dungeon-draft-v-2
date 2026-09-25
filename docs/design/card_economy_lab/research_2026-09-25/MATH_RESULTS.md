# Calculs exécutés et limites de l'expérience

25 septembre 2026. Node v24.19.0, graine 25092026, 16 cas de 20 000 parcours : **320 000 simulations de budget**. Ce nombre ne désigne ni des parties jouées ni des victoires simulées.

## Reproduction

Depuis la racine du dépôt :

```powershell
node --test --test-isolation=none docs/design/card_economy_lab/simulate.test.mjs docs/design/card_economy_lab/research_2026-09-25/systems_math.test.mjs
node docs/design/card_economy_lab/research_2026-09-25/systems_math.mjs --runs 20000 --seed 25092026 --out artifacts/dev/card-economy-systems
```

Le nouveau programme importe le modèle de stock parent. Il ajoute l'audit de monotonie, la courbe candidate, l'extraction de progression depuis deux fichiers du jeu, une comparaison structurelle partielle du catalogue et des exemples mathématiques. Il ne charge ni Godot ni une sauvegarde.

Les sorties détaillées sont `artifacts/dev/card-economy-systems/systems.json` et `systems.csv`. Le JSON contient les paramètres, empreintes des sources lues, version Node, graine, résultats exacts, premier manque par combat et intervalles. Un instantané portable des seize expériences est conservé dans [RESULTS.csv](RESULTS.csv).

## Hypothèses communes

* Branche Airain : 32 ennemis avant le boss ; le butin après le boss est exclu.
* Départ : 15 exemplaires ; maximum 30 mobilisables par combat ; réserve agrégée.
* Central : 3 cartes au premier combat, 6 aux normaux suivants, 9 aux élites, 12 au boss ; total 84.
* Intensif : 3 au premier combat, 9 aux normaux suivants, 12 aux élites, 15 au boss ; total 117.
* Utilité 1 : tout drop compte comme un exemplaire utilisable. Utilité 0,7 : chaque carte droppée compte avec une probabilité indépendante de 70 %. Initiales et achats restent utilisables.
* Sans commerce ou ravitaillement aux étapes après combats 5, 7, 10, 11. Magasin : lot de six normales à 36 or, maximum deux par visite, achat tant que stock inférieur à quinze et or suffisant. Or initial 40, revenus 35/65.
* Pas de revente, soins, achat d'équipement, pioche, composition réelle, différence de puissance entre raretés, durée ou tactique. La consommation est une entrée fixe, pas une conséquence de la simulation.

**Le « 70 % » est un stress de pertinence, pas une règle d'accès par classe.** Les familles étrangères du mode actuel sont jouables au rang zéro. L'hypothèse indépendante ne reproduit pas un pool cohérent de sacs thématiques.

## 1. Monotonie

Le contrôle trouve deux baisses dans la variante historique `early_supply`, entre premier et deuxième palier : normale A 0,75→0,70 ; normale B 0,15→0,10. Base et nouvelle candidate n'ont aucune baisse par canal.

La candidate remplace les deux canaux normaux par : `(0,75 ; 0,15)`, `(0,80 ; 0,20)`, `(0,90 ; 0,30)`, `(0,95 ; 0,45)`. Tous les autres canaux restent identiques. Le fichier parent de configuration n'est pas modifié.

L'espérance de normales pré-boss passe de 93 à 108 : 16,2 / 30 / 32,4 / 29,4 par tranche. La dernière tranche ne contient que les combats 10–11 dans ce budget ; le boss ne le finance pas. Les taux augmentent, mais les effectifs rendent le total par tranche non monotone.

## 2. Résultats principaux

Pourcentages de financement des douze demandes, arrondis à deux décimales. « Stock médian » porte seulement sur les parcours financés et après paiement du boss.

| Table | Profil | Utilité | Commerce | Financement | Stock médian |
|---|---|---:|---|---:|---:|
| Base | Central | 100 % | Aucun | 73,14 % | 37 |
| Candidate | Central | 100 % | Aucun | 98,85 % | 50 |
| Base | Central | 100 % | Refuges | 79,18 % | 41 |
| Candidate | Central | 100 % | Refuges | 99,12 % | 50 |
| Base | Central | 70 % | Aucun | 12,10 % | 13 |
| Candidate | Central | 70 % | Aucun | 65,67 % | 17 |
| Base | Central | 70 % | Refuges | 32,23 % | 21 |
| Candidate | Central | 70 % | Refuges | 81,81 % | 23 |
| Base | Intensif | 100 % | Aucun | 1,14 % | 18 |
| Candidate | Intensif | 100 % | Aucun | 36,07 % | 24 |
| Base | Intensif | 100 % | Refuges | 3,57 % | 23 |
| Candidate | Intensif | 100 % | Refuges | 47,67 % | 26 |
| Base | Intensif | 70 % | Aucun | 0 observé | Non défini |
| Candidate | Intensif | 70 % | Aucun | 0,11 % | 3 |
| Base | Intensif | 70 % | Refuges | 0,02 % | 8 |
| Candidate | Intensif | 70 % | Refuges | 2,76 % | 7 |

Zéro observé n'est pas une probabilité nulle : pour 0/20 000, la borne supérieure de Wilson bilatérale à 95 % est environ 0,0192 %. Les quantiles calculés sur quatre succès ou vingt-deux succès sont particulièrement peu robustes ; consulter le nombre d'observations, pas seulement la médiane.

Pour le cas central sans commerce, les intervalles de Wilson à 95 % sont : base **[72,516 % ; 73,745 %]**, candidate **[98,687 % ; 98,984 %]**. Une propagation exacte indépendante de l'échantillonnage donne respectivement **73,4393 %** et **98,8857 %** sous les mêmes hypothèses agrégées. Le cas intensif candidate donne **36,2262 %** exactement, contre 36,065 % estimés.

Les résultats de la base diffèrent légèrement de ceux du premier rapport parce que la graine a changé. Ils ne remplacent pas rétroactivement son instantané. Cette différence est compatible avec l'incertitude d'échantillonnage.

**Décision :** ne retenir aucune de ces tables comme équilibre final. Elles démontrent un conflit entre sécurité initiale, surplus tardif et pertinence. Elles n'évaluent pas encore le rôle du troc, de la rareté sur les dépenses, de l'équipement ou des gestes de secours.

## 3. Rareté extrême et taille d'échantillon

Sur la route Airain complète avant boss, le canal Immortel n'est ouvert que pour sept ennemis au dernier palier :

```text
p_run = 1 − (1 − 0,0002)^7 = 0,00139916028
E[nombre de cartes] = 7 × 0,0002 = 0,0014
P(au moins une découverte en R runs) = 1 − (1 − p_run)^R
```

Environ 2 140 runs indépendantes donnent 95 % de chances d'au moins une découverte. À 20 000 runs, on attend environ 28 runs avec découverte. Une approximation normale visant une demi-largeur de confiance relative de 20 % donne :

```text
n ≈ 1,96² × (1−p) / (p × 0,2²) ≈ 68 546 runs
```

Ce dernier calcul planifie une précision sur la **fréquence**, pas sur la puissance de la carte ou la satisfaction. Des intervalles exacts/rares sont préférables après observation. Les runs interrompues avant la fenêtre de drop réduisent l'exposition ; ces calculs supposent qu'on atteint tous les jets.

## 4. XP : extraction du dépôt

Hypothèse : départ niveau 1 sans XP, récompenses fixes de la route seulement, multiplicateur un et tous les combats gagnés. Les valeurs ne sont pas recopiées dans le programme : il lit les tableaux du GDScript et du fichier de profil. Une syntaxe non reconnue provoque une erreur.

| Combat | Profondeur | Niveau avant → après | XP cumulée après | PV de base avant | Prouesse de base avant |
|---:|---:|---|---:|---:|---:|
| 1 | 1 | 1 → 2 | 100 | 110 | 18 |
| 2 | 2 | 2 → 3 | 225 | 135 | 22 |
| 3 | 3 | 3 → 4 | 370 | 165 | 27 |
| 4 | 5 | 4 → 5 | 545 | 200 | 33 |
| 5 | 6 | 5 → 6 | 740 | 240 | 40 |
| 6 | 8 | 6 → 7 | 955 | 290 | 48 |
| 7 | 10 | 7 → 8 | 1 200 | 350 | 57 |
| 8 | 12 | 8 → 9 | 1 465 | 420 | 68 |
| 9 | 13 | 9 → 10 | 1 760 | 500 | 82 |
| 10 | 15 | 10 → 11 | 2 085 | 600 | 100 |
| 11 | 17 | 11 → 12 | 2 440 | 635 | 106 |
| 12 | 20 | 12 → 13 | 2 785 | 675 | 112 |

Le palier 14 à 2 950 XP n'est pas atteint par ces récompenses. Ne pas confondre plafond générique du profil et niveau utile dans cette run. Toute autre entrée d'XP ou reprise de sauvegarde demanderait un autre scénario.

## 5. Comparaison structurelle des cartes

Périmètre volontairement limité : lignes numériques simples de `class_card_catalog.ROWS` et `card_ecosystem_catalog.ADVANCED`, soit 84 lignes. Les starters publics et entrées de compatibilité historique ne sont pas comptés dans cette extraction.

Signature comparée : PA, portée minimale/maximale, coefficient, effet, valeur. Le nom, la classe, le rôle, le type de dégâts déterminé ailleurs et les passifs ne sont pas inclus. Six groupes :

| Familles | Signature commune | Interprétation prudente |
|---|---|---|
| a_step, r_step, t_step | 1 PA, portée 1–2, déplacement 2 | Même verbe ; interactions de classe à examiner |
| a_parry, r_guard | 1 PA, soi, garde 0,35 P | Socle défensif partagé possible |
| a_escape, r_escape, t_escape | 2 PA, portée 1–3, déplacement 3 | Variante de mobilité qui mérite un regroupement conceptuel |
| g_mark, t_mark | 1 PA, portée 1–3, 0,3 P, marque | Type de dégâts et passifs différents |
| r_push, t_push | 2 PA, portée 1–3, 0,6 P, pousse 1 | Type de dégâts et interactions différents |
| a_phantom, r_horizon | 2 PA, portée 1–4, téléportation 4 | Différence d'identité surtout hors du texte de base |

Ce n'est ni un diagnostic automatique de domination ni un motif de suppression de six groupes. Une carte peut remplir un besoin local de classe malgré une signature commune. L'objectif est de rendre ces redondances explicites pour distribuer le budget de complexité.

## 6. Accès en main initiale

Sans remise, main aléatoire de quatre, `N` cartes dont `k` copies : `P = 1 − C(N−k,4)/C(N,4)`.

| Taille du deck | 1 copie | 2 copies | 3 copies |
|---:|---:|---:|---:|
| 15 | 26,67 % | 47,62 % | 63,74 % |
| 20 | 20,00 % | 36,84 % | 50,88 % |
| 30 | 13,33 % | 25,29 % | 35,96 % |

Ce calcul ne comprend pas mulligan, tutorat, conservation, pioche supplémentaire ni ordre imposé. Il expose uniquement le coût de dilution d'un deck plus gros.

## 7. Validation et suite

Cinq nouveaux tests couvrent : régression des taux ; calendrier XP et seuils ; échec explicite du parseur ; différence de variance à espérance égale ; groupes structurels. Les huit tests parents vérifient notamment les calculs de stock et le contrôle par propagation exacte. Résultat de l'exécution combinée consigné dans [WORKLOG.md](WORKLOG.md).

Aucun test de combat ou import Godot n'a été exécuté pour cette recherche. Les prochaines mesures indispensables sont la dépense effective de cartes par rôle/rencontre, la pertinence des drops, le rendement des gestes de secours et les sorties d'or concurrentes. Sans elles, ajouter des décimales aux taux serait une précision trompeuse.
