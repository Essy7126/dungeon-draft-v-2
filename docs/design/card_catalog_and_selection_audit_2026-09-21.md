# Cartes : sélection, catalogue et profondeur — 21 septembre 2026

## Verdict

Les classes disposent maintenant de départs distincts, sélectionnables avant la
cinématique. Le catalogue public compte **112 familles**, mais ce nombre ne
signifie pas 112 mécaniques : il utilise 29 codes d'effet, dont plusieurs sont
des variantes de dégâts ou de zone. La progression remplace effectivement le
deck sur les parcours longs. L'accès précoce aux combinaisons, les secours trop
dominants et certaines interactions incomplètes limitent encore la profondeur.

Cette livraison corrige la sélection et les départs. Les chantiers de profondeur
identifiés ci-dessous sont des recommandations ; ils ne sont pas présentés comme
des systèmes déjà implémentés.

## Sélection livrée

Apparence → classe → cinq techniques parmi sept → difficulté → revue du départ.
Deux copies par technique, dix cartes, quatre en main. La préparation suit le
personnage jusqu'au seuil, qui lance le premier combat avec ce deck sans second
choix. Un deck incomplet bloque la continuation. Revenir sur une classe conserve
son brouillon pendant la sélection. Les spécialisations sont expliquées, puis
restent choisies au niveau 4.

| Classe | Couleur | Identité du départ | Exemples de choix |
|---|---|---|---|
| Assassin | Violet `#BE78DE` | Marquer, se déplacer, exploiter une ouverture | Faille furtive + Lame opportuniste ; Approche oblique + Premier guet-apens ; saignement ou dague à distance |
| Gardien | Or `#E4B76A` | Garde, contrôle de position, riposte | Rempart d'apprenti + Heurt sous couvert ; poussée/attraction + Punir le déséquilibre ; affaiblissement ou mobilité |
| Arpenteur | Vert `#73C89C` | Distance, entrave et mouvement | Entraver la poursuite + Flèche de recul ; Pas d'éclaireur + Tir d'escarmouche ; marque + Suivre la piste |
| Thaumaturge | Bleu `#69BDF0` | Préparation magique, regroupement, zone et durée | Tracer le sceau + Réveiller le sceau ; attraction + Gerbe de cendres ; givre, brûlure ou protection |

Il existe 21 compositions de cinq familles par classe, soit 84 compositions de
départ avant les choix de difficulté et d'apparence. Ce décompte combinatoire
n'affirme pas qu'elles soient toutes aussi bonnes. Les sept cartes d'une classe
ne sont jamais toutes équipées au départ.

Le personnage reste visible ; étapes, coût PA, portée, effet, valeurs de départ
et contenu du deck sont accessibles. Le nom sélectionné remplace l'appel à
« incarner Achille ». Couleur, nom de classe et intitulés restent redondants pour
ne pas demander de reconnaître une classe uniquement par sa couleur.

Les `i_*` sont les nouveaux départs. Les 28 anciennes `s_*` restent lisibles dans
les sauvegardes, hors catalogue de choix et hors butin. Elles ne sont pas
converties silencieusement en nouvelles cartes.

## Inventaire mesuré

Export reproductible par `tools/build_system_lab/card_catalog_audit.tscn` :
[table complète CSV](../../artifacts/dev/cards-catalog-20260921/cards.csv),
[données JSON](../../artifacts/dev/cards-catalog-20260921/report.json).
Chaque ligne comprend classe, rareté, PA, portée, effet, rôle, coefficients,
dégâts à Prouesse 20 aux maîtrises 0/2/4, garde, recharge et description.

| Classe | Initiation | Usuelles | Rares | Épiques | Total public |
|---|---:|---:|---:|---:|---:|
| Assassin | 7 | 15 | 4 | 2 | 28 |
| Gardien | 7 | 15 | 4 | 2 | 28 |
| Arpenteur | 7 | 15 | 4 | 2 | 28 |
| Thaumaturge | 7 | 15 | 4 | 2 | 28 |
| **Total** | **28** | **60** | **16** | **8** | **112** |

84 familles peuvent être trouvées/achetées. Les 28 définitions de compatibilité
portent à 140 le nombre de familles résolubles, sans augmenter l'offre publique.
Coûts : **21 cartes à 1 PA, 68 à 2 PA, 23 à 3 PA**. La distribution concentre
61 % du catalogue sur 2 PA. Seule la classe Thaumaturge produit par défaut des
dégâts magiques ; emprunter ses cartes permet aux autres de changer de profil.

Répartition notable des effets : 12 déplacements, 8 poussées, 8 gardes,
7 attractions, 7 marques, 7 attaques conditionnées par une marque, 7 frappes
simples. Les surfaces persistantes occupent seulement 5 familles ; stase et
attraction avec perte de PA en occupent 2 chacune. Aucun sort de ce catalogue
joueur n'invoque une unité. « Envoûté » attire et retire 1 PA : il ne retourne pas
l'équipe ni ne donne le contrôle de la cible.

Les illustrations d'initiation et avancées réutilisent explicitement les
illustrations peintes des 60 techniques de base. Les sept choix d'initiation
d'une même classe ont des silhouettes distinctes ; les 112 familles n'ont pas
112 illustrations uniques. L'étape artistique suivante doit viser les rares
qui changent réellement le jeu, plutôt que masquer cette réutilisation.

## Puissance et stats

Comparaison normalisée à **20 Prouesse, maîtrise 2**, sans armure, résistance,
passif de classe, critique ni bonus conditionnel. Ce n'est pas un classement de
puissance totale : une poussée sur une dalle ou une attaque de zone dépend du
contexte. Les valeurs de l'interface utilisent le personnage réel, pas Prouesse 20.

| Progression | Initiation | Usuelle | Épique |
|---|---|---|---|
| Assassin | Lame opportuniste : 9 dégâts, 2 PA, +7 sur cible marquée | Frapper l'ouverture : 19 dégâts, 2 PA, +13 sur cible marquée | Moisson : 26 dégâts, 3 PA, +29 si PV ≤35 % |
| Gardien | Rempart d'apprenti : 15 garde, 2 PA | Garde brève : 19 garde, 2 PA | Bastion vivant : 43 garde, 3 PA |
| Arpenteur | Flèche d'éclaireur : 13 dégâts, 2 PA, portée 2–4 | Trait tendu : 24 dégâts, 2 PA, portée 2–4 | Prime de la traque : attaque conditionnelle marquée, portée 2–6 |
| Thaumaturge | Gerbe de cendres : 10 dégâts/cible, 3 PA | Éclat de braise : 19 dégâts/cible, 3 PA | Couronne de cendres : 32 dégâts/cible, 3 PA |

Les cartes acquises gagnent 10 % par rang de maîtrise : +20 % au départ dans la
classe principale, jusqu'à +40 %. Les autres classes commencent au rang 0 et
plafonnent au rang 2. Leurs cartes sont jouables dès l'acquisition ; investir
dans une maîtrise étrangère est un coût d'opportunité, pas un déverrouillage.
Une amélioration individuelle nécessite le rang 3 et deux points : elle est donc
réservée à la classe principale.

L'initiation ne bénéficie pas du multiplicateur de maîtrise ; elle reste
proportionnelle à la Prouesse. Certains outils de mobilité peuvent donc rester
utiles longtemps, et l'amélioration individuelle reste possible. C'est un
choix contextuel acceptable ; ce qui manque serait une raison mécanique de
remplacer ou conserver chaque outil, au-delà du coefficient de dégâts.

**Point sensible :** Frappe de secours inflige 55 % de Prouesse pour 2 PA,
toujours disponible. Elle dépasse plusieurs attaques initiales tant que leurs
conditions ne sont pas remplies. Se protéger coûte 1 PA pour 20 % de Prouesse en
garde. Ne pas simplement les affaiblir avant de vérifier l'accessibilité des
combos et les tours sans carte jouable : ce serait surtout augmenter les morts.

## Drops et économie

Les cartes sont des objets du reçu de victoire et arrivent en réserve ; aucun
choix systématique de trois cartes. Le deck reste à dix copies, deux maximum par
famille. Le remplacement entre combats constitue la décision de construction.

La **Résonance** vaut `10 + min(profondeur,20) + danger + mémoire`, plafonnée à
100. Danger : +20 élite, +35 boss. Mémoire : +15 par combat sans carte, maximum
+45. Elle ne récompense ni la vitesse du combat ni les dégâts subis.

Deux jets pour un combat normal, trois pour un élite, quatre pour un boss.
70 % des cartes visent la classe principale ; les 30 % restants sont répartis
entre les trois autres. Les rares arrivent à partir de profondeur 4, les épiques
à partir de 10. Les poids de rareté sont normalisés par nombre de familles :
100 / `(10 + 0,3R)` / `(2 + 0,15R)`, pour les paliers déjà accessibles.

| Situation, mémoire à zéro | Cartes moyennes théoriques | Probabilité de zéro carte |
|---|---:|---:|
| Normal profondeur 1 | 0,65 | 42,84 % |
| Normal profondeur 4 | 0,67 | 41,50 % |
| Élite profondeur 4 | 1,01 | 25,83 % |
| Normal profondeur 10 | 0,73 | 37,60 % |
| Élite profondeur 10 | 1,09 | 22,46 % |
| Boss profondeur 20 | 1,56 | 10,51 % |

Après trois combats sans carte, un normal de profondeur 1 passe à 1,01 carte
attendue et 21,78 % de chance de n'en donner aucune. **La mémoire réduit la
malchance, elle ne garantit jamais un drop.**

7 200 tirages déterministes ont été exécutés : 300 graines × quatre profondeurs
× trois types × deux mémoires. Ce sont des essais de butin indépendants, avec
certains couples type/profondeur synthétiques, pas 7 200 combats gagnés. Au
premier normal sans mémoire : 204 cartes pour 300 tirages, dont 123 sans carte,
136 cartes natives et uniquement des usuelles. Formules et observations sont
séparées dans le JSON.

La boutique propose six familles différentes, tirées uniformément dans les
quatre classes et les paliers accessibles : environ 25 % natives en moyenne,
contre 70 % en butin. Prix : 50/75/110 oboles pour usuelle/rare/épique, revente
8/12/20. Capital initial : 60. La boutique ne favorise ni les rôles manquants ni
les combos du deck ; c'est un obstacle mesurable à la construction volontaire.
La Résonance n'est actuellement pas une caractéristique que le joueur équipe
ou monte : c'est un calcul de parcours, danger et malchance.

## Douze runs réelles avec les nouveaux départs

Sonde `class_balance_probe.tscn`, graines 2401–2403, quatre classes, pilote
`balanced`, `legacy=false`. **72 combats, 295 activations du héros, 755 sorts
du héros, 356 sorts ennemis.** Processus terminé, code 0, aucune erreur de sonde
ni diagnostic moteur ERROR/WARNING. Le pilote glouton ne planifie pas bien les
combinaisons ; ses résultats ne sont pas un taux de victoire humain.

| Classe | Profondeurs finales, graines 2401 / 2402 / 2403 | Cartes initiales au dernier combat |
|---|---|---|
| Assassin | 5 / 5 / 3 | 8 / 7 / 9 sur 10 |
| Gardien | 5 / 6 / 5 | 8 / 6 / 8 sur 10 |
| Arpenteur | 15 / 15 / 8 | 2 / 2 / 4 sur 10 |
| Thaumaturge | 6 / **20 gagné** / 6 | 7 / 0 / 7 sur 10 |

349 actions utilisent les secours (**46,2 %**), 267 l'initiation (**35,4 %**),
139 des cartes acquises (**18,4 %**). La run gagnante possède 26 copies et a
remplacé les dix initiales avant le dernier combat. Les morts précoces laissent
logiquement moins de temps au renouvellement.

Le pilote ne lance aucune Lame opportuniste, Entaille discrète, Premier
guet-apens ou Heurt sous couvert sur cet échantillon : leur simple présence
dans le deck ne prouve donc pas que le joueur exploite leurs combinaisons.
Pour une main initiale uniforme de quatre cartes sur dix, avec deux copies de
chacune des deux techniques d'un combo, la probabilité d'avoir les deux est
seulement **40,48 %** : `1 − 2×C(8,4)/C(10,4) + C(6,4)/C(10,4)`.
C'est avant recomposition, portée, placement et dépense de PA. L'accès à une
synergie doit donc se mesurer dans la main et sur le terrain, pas dans une
simple liste de cinq familles.
57 sorts ennemis proviennent du catalogue Cartes. Il reste nécessaire de
mesurer leur rôle dans les décisions, pas seulement leur nombre de lancements.

[Runs complètes](../../artifacts/dev/cards-distinct-starters-20260921/report.json),
[agrégation](../../artifacts/dev/cards-distinct-starters-20260921/analysis.json),
[journal](../../artifacts/dev/cards-distinct-starters-20260921/engine.log).

## Priorités pour obtenir plus de profondeur

1. **Raccorder les interactions existantes.** `class_card_modifier.gd` reconnaît
   seulement `class_slow` pour les bonus contre une cible ralentie, alors que
   les racines et les dalles créent `class_root`/`ecosystem_ice`. Uniformiser la
   condition mécanique et tester sort → dalle → passif. Les diagnostics
   d'invocation de l'audit du 20 septembre restent à résoudre : type de serviteur,
   plafond et budget de rencontre. Un sort annoncé mais refusé par le moteur
   n'ajoute aucune profondeur.
2. **Rendre les premières boucles réellement accessibles.** Comparer des tours
   complets et des mains, en incluant déplacement, garde perdue et portée
   minimale. Ajouter au pilote des séquences marque→exploitation et
   garde→riposte avant tout rééquilibrage des dégâts globaux. Mesurer usage des
   combos, coût d'approche, tours sans option, dégâts évités et secours.
3. **Faire évoluer le deck par décisions.** Garder les drops aléatoires ;
   expérimenter une piste de loot choisie au refuge, un emplacement de boutique
   lié à un rôle recherché, ou un échange de doublons. Mesurer les cartes
   effectivement équipées, pas seulement les cartes reçues. Conserver des
   cartes utilitaires viables est sain si elles ouvrent une stratégie distincte.
4. **Ajouter des interactions horizontales.** Marques consommables avec plusieurs
   dépenses possibles ; surfaces transformables ; déplacements qui alimentent
   une ressource ; garde transférable ou sacrifiable ; cartes qui récupèrent une
   carte de défausse avec un coût. Chaque nouveau sort doit créer au moins deux
   combinaisons et un arbitrage réel. Aucun de ces systèmes supplémentaires
   n'est livré dans cette modification.
5. **Des groupes ennemis dont on peut casser la coopération.** Priorité à une
   formation qui partage une garde finie, un convoyeur de ressource vers un
   consommateur, et un groupe qui pose puis exploite des surfaces. Séparer,
   voler, détruire ou retourner la ressource doit changer le combat. Les
   intentions annoncées peuvent informer l'interface ; elles ne servent pas
   ici de fondation au gameplay demandé.

## Références de conception

Le découpage apparence/classe/choix de sorts s'inspire des catégories et des
choix de compétences exposés par Larian dans sa présentation officielle de la
[création de personnage de BG3](https://baldursgate3.game/news/community-update-8-character-creation_9)
(article historique du 2 octobre 2020, pas un relevé de son interface actuelle).
Application au projet : navigation persistante, personnage visible, détail du
choix courant et aperçu de ses évolutions.

Le communiqué officiel d'Ankama sur
[Temporis IV](https://static.ankama.com/ankama/cms/file/372/1125833.pdf) présente
une progression modelée par les sorts et équipements collectés. L'extrait
indexé est accessible ; le PDF complet impose une vérification anti-robot.
C'est une référence de collecte et de construction, pas une preuve de nos
probabilités ni une copie de ses règles. L'esthétique conserve les illustrations
et le décor propres au projet.

## Validation

- Cards : **84 tests, 7 186 assertions, PASS strict**, y compris quatre classes
  via configuration publique → cinématique → seuil → premier combat, difficulté
  choisie, reprise et anciens départs.
  [Rapport final](../../artifacts/dev/20260921-195632-test-cards-de4aafb4/summary.json).
- Catalogue : export de 112 familles, 29 codes d'effet, 7 200 tirages, code 0.
- Runs : 12/12 cas complets, code 0 ; limites du pilote explicites ci-dessus.
- Interface : sélection, modification du deck, combat réel, reçu, progression,
  équipement et boutique aux résolutions 1280×720 et 1920×1080 ; rapport final
  [380 contrôles réussis](../../artifacts/dev/cards-selection-ui-20260921-framed/report.json),
  captures inspectées, processus code 0, aucune erreur moteur.
- Catabase : 546 tests exécutés, 16 échecs et erreurs de fermeture.
  La liste des tests échoués correspond exactement à celle du rapport du
  20 septembre (catalogues/illustrations, anciens contrats de sélection et
  seuil, formations, inventaire de reliques). Aucune exception n'a été ajoutée.
  [Rapport courant](../../artifacts/dev/20260921-194645-test-catabase-c42ee564/summary.json).
  Le résultat global reste négatif ; les contrôles ciblés sont détaillés dans
  [la fiche de livraison](../ai/CARDS_SELECTION_2026-09-21.md).
- Les victoires injectées par la sonde UI valident les écrans de récompense,
  elles ne comptent pas dans les 72 combats de l'audit de runs.
