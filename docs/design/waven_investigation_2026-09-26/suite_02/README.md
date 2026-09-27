# Suite de l'audit : ce qui produit réellement les gains

26 septembre 2026. **440 nouvelles runs comparatives terminées**, sur dix nouvelles graines par classe (`28001–28010`), les quatre premières spécialisations, et onze variantes. Les règles de combat, drops et marchands sont celles de la V1 précédente. Aucun gameplay Godot modifié.

**Le résultat confirme l'intérêt du renouvellement, mais simplifie la recommandation : commencer par rendre l'achat unitaire utile et visible.** La politique d'urgence du bot apporte un gain comparable. En revanche, simuler la phase ennemie avec une mauvaise fonction de décision dégrade fortement les résultats. Le modèle n'est donc pas encore une mesure neutre de la difficulté du jeu.

Le [protocole](PROTOCOLE.md) et les poids des politiques ont été fixés avant cette série. Les résultats négatifs sont conservés. Les 34 victoires de référence ci-dessous ne remplacent pas les 29/40 précédentes : il s'agit d'autres graines, avec le même modèle de départ.

## 1. Achats, trocs, protection : les huit combinaisons

Trois facteurs : **A** = acheter à l'unité pour rétablir deux normales ciblées ; **T** = troquer trois normales pour une pièce ciblée manquante ; **P** = protéger ces deux familles des ventes et trocs génériques. Le soin urgent reste prioritaire. Même stock fini, prix et limites qu'auparavant.

| Variante | Victoires / 40 | Défaites sauvées / victoires perdues face à la référence | Dépense moyenne en cartes | Stock final moyen |
|---|---:|---:|---:|---:|
| Référence | 34 | — | 18,90 or | 29,80 |
| A | **39** | +6 / −1 | 65,70 or | 34,28 |
| T | 37 | +4 / −1 | 31,50 or | 27,68 |
| A + T | **39** | +5 / −0 | 71,50 or | 33,68 |
| P | 34 | +0 / −0 | 18,90 or | 29,80 |
| A + P | 39 | +6 / −1 | 65,70 or | 34,28 |
| T + P | 37 | +4 / −1 | 31,50 or | 27,68 |
| A + T + P | **39** | +5 / −0 | 71,50 or | 33,68 |

Les coûts moyens sur l'ensemble des runs incluent des durées différentes. Les résultats complets donnent aussi les différences sur les victoires communes.

**L'achat unitaire est le levier principal de cet essai.** Il utilise une règle déjà disponible, sans buff. Le troc seul aide aussi, mais retirer trois copies a un coût de réserve que l'or ne décrit pas. La dépense en cartes du bras T provient des sacs habituels : le troc lui-même ne coûte pas d'or.

Ajouter T à A ne change pas le total de victoires, mais **change leur identité** : une run sauvée et une autre perdue. Sur les 38 paires gagnées avec A comme avec A+T, ce dernier consomme 1,42 copie de moins, dépense 5,16 or de plus en cartes et termine avec 5,34 or de moins. On ne peut donc pas conclure que le troc ne sert à rien ; son avantage est conditionnel.

Pour P, les **160 paires de résultats complets sont strictement identiques** avec et sans protection, à autres facteurs constants. La protection n'a aucun effet observé sur ces trajectoires. Cela ne prouve pas qu'un verrou de favoris est inutile pour un humain ou pour d'autres cartes ; cela empêche simplement de lui attribuer les gains de cet essai.

Le plan factoriel révèle une redondance entre A et T : A seul ajoute cinq victoires, T seul trois, mais leur combinaison cinq. L'interaction arithmétique vaut `5 − 5 − 3 = −3`, car ils résolvent en partie les mêmes manques et modifient les stocks futurs. Il ne faut pas additionner leurs gains isolés pour promettre huit victoires de plus. Les contributions moyennes selon les quatre contextes sont +3,5 victoires pour A, +1,5 pour T et zéro pour P, sur ce lot de 40 cas ; aucune causalité humaine n'est déduite de ces moyennes.

## 2. Pourquoi l'achat ciblé pèse autant

Dans un sac de normales, une famille précise commune/native a une probabilité de `0,70 / 12 = 5,833 %` par copie. Avec six copies par sac :

| Achat | Coût | Résultat pertinent pour un besoin précis |
|---|---:|---|
| Une normale choisie | 8 or | Une copie certaine, sous réserve du stock marchand. |
| Deux normales choisies de familles différentes | 16 or | Les deux fonctions renouvelées une fois. |
| Sac aléatoire de six normales | 36 or | 0,35 exemplaire attendu d'une famille précise ; 30,28 % de chance d'en obtenir au moins un. |
| Même sac, deux familles recherchées acceptables | 36 or | 0,70 exemplaire attendu de l'une ou l'autre ; 52,49 % de chance d'en obtenir au moins un. |

Le ratio `36 / 0,35 = 102,86 or` est le coût par exemplaire ciblé **en espérance dans les sacs**, pas une stratégie d'achat illimitée : le marchand ne vend que deux sacs, et les autres cartes ont une utilité. Le ratio pour l'une ou l'autre des deux familles est 51,43 or. À l'inverse, le sac fournit beaucoup plus de volume et peut ouvrir une autre construction.

L'achat ciblé coûte seulement 33,3 % de plus que le prix moyen d'une carte du sac (`8 contre 6`). Pour préserver un duo connu, sa précision vaut donc énormément. Cela peut être une bonne propriété : les sacs apportent la diversité et les achats la continuité. Mais si presque tous les joueurs rachètent les mêmes deux normales, le jeu risque de transformer sa promesse d'adaptation en abonnement à un combo.

**Je ne recommande pas de monter le prix sur cette seule simulation.** Les variables à observer sont : diversité des familles jouées après une halte, choix entre soins et renouvellement, part du stock réellement utilisable et fréquence des combats où le combo devient impossible. Les prix doivent servir ces décisions, pas faire redescendre arbitrairement un taux de victoire de bot.

Le troc représente trois or de revente abandonnée, mais aussi trois options tactiques consommables. Sa vraie contrepartie n'est pas seulement monétaire. Conserver une normale surnuméraire peut être utile pour les combats suivants, même si trois copies seulement entrent dans un deck de combat.

## 3. Le bot : une urgence utile, une anticipation mal formulée

Deux politiques distinctes ont été testées, sans modifier la pression du jeu :

- **Urgence** : somme de la pression des quatre prochaines fins de tour, divisée par les PV courants et plafonnée à 1. Cette valeur réduit le poids de la sécurité et du coût des copies, et augmente l'intérêt d'approcher une cible. Les constantes sont fixées dans le script, sans ajustement après résultats. Avant l'entrée de la pression dans cet horizon, le choix reste celui de la politique de départ.
- **Phase simulée** : évaluer chaque candidat après résolution de la prochaine phase ennemie sur une copie du combat, en retirant la seconde estimation de menace et les défenses qui vont expirer. L'horizon reste de deux actions du héros parmi six premiers candidats présélectionnés. Ce n'est pas une recherche d'un tour complet, ni une IA optimale.

| Classe | Référence | A/T/P | Urgence seule | Phase simulée seule | Urgence + A/T/P |
|---|---:|---:|---:|---:|---:|
| Assassin | 10/10 | 10/10 | 10/10 | **2/10** | 10/10 |
| Gardien | 8/10 | 9/10 | 9/10 | 7/10 | 10/10 |
| Arpenteur | 9/10 | 10/10 | 10/10 | 7/10 | 10/10 |
| Thaumaturge | 7/10 | 10/10 | 10/10 | 5/10 | 10/10 |
| **Total** | **34/40** | **39/40** | **39/40** | **21/40** | **40/40** |

L'urgence seule sauve cinq runs, sans perte face à la référence dans ce lot. Avec le renouvellement complet, elle sauve une run supplémentaire par rapport à chacun des deux leviers utilisés seuls.

Sur les 34 paires où référence et urgence gagnent, l'urgence consomme seulement **0,24 copie supplémentaire** en moyenne, avec la même dépense moyenne en cartes. Le gain n'est donc pas ici une fuite générale en avant dans la consommation. Avec urgence+A/T/P, la différence face à la référence sur les 34 victoires communes est de **deux copies consommées en moins** et **50,59 or de plus en achats de cartes**.

### Pourquoi la phase simulée échoue

Le bras « phase simulée » sauve trois défaites, mais perd seize victoires de la référence. Une trace précise, Assassin graine `28001`, montre le problème : au combat 2, le héros finit par rester à distance d'un ennemi à 19 PV. Aux tours 8 et 17, il termine sans agir avec quatre PA et trois PM. Il ne subit aucune attaque ennemie durant ce combat et perd ses 135 PV exclusivement à la pression.

La simulation locale peut correctement prédire une phase tout en favorisant l'inaction. Si progresser vers une élimination exige plusieurs tours, payer un dégât maintenant paraît mauvais ; la valeur de cette progression est mal représentée. Ajouter à tous les candidats une même perte de pression future ne les départage pas non plus. À l'approche d'une mort certaine sur l'horizon court, plusieurs actions peuvent recevoir la même valeur terminale.

Ce résultat condamne **cette formulation de politique**, pas le principe d'anticiper les intentions. Il justifie de garder les contre-exemples et d'examiner l'horizon, l'objectif et les actions rejetées avant de baptiser un bot « plus intelligent ».

### Pourquoi 40/40 ne ferme pas le sujet

La série ne couvre que dix graines par classe et une spécialisation chacune. Les anciennes graines difficiles n'ont pas servi à régler les poids. Deux relectures de l'urgence seule sur les cas connus montrent :

| Thaumaturge | Référence connue | Urgence seule |
|---|---|---|
| 27001 | Défaite au combat 3, tour 17 | Combat 3 gagné au tour 11 ; run perdue au combat 7. |
| 27005 | Défaite au combat 3, tour 17 | Toujours défaite au combat 3, désormais au tour 15. |

**La graine 27005 reste donc un contre-exemple.** Les marchands arrivent après ce combat ; la combinaison urgence+A/T/P ne change pas ce préfixe. L'amélioration du bot ne garantit ni toutes les victoires ni l'absence d'un vrai problème d'accès aux outils offensifs. Il faut garder ce cas lors du prochain essai, sans le confondre avec une nouvelle confirmation indépendante.

## 4. Critique de notre propre idée : Faille transmissible

Le prototype précédent remplaçait les `+0,15 P` de dégâts de la maîtrise de Frapper la faille par une marque transférée après élimination, de valeur `0,20 P` et durée un tour. L'idée spatiale est intéressante, mais son contrat temporel était trop vague.

Les scénarios exécutés dans le moteur V1 montrent trois contraintes :

1. `markTurns = 1` disparaît pendant la phase ennemie : aucune transmission utilisable au prochain tour du héros.
2. Frapper la faille ne peut pas être rejouée ce même tour, même avec assez de PA : la famille est déjà utilisée.
3. Le geste de secours ne consomme pas la marque dans la V1 actuelle. Il ne bénéficie donc pas de son bonus.

La promesse doit devenir soit **un relais vers une autre attaque ce tour-ci**, soit une marque qui persiste explicitement jusqu'au prochain tour du héros. Ces deux usages ont des budgets et des plafonds différents. Aucun n'est intégré ici.

### Des dégâts en plus ne valent pas toujours leur valeur nominale

Scénario à P40 : une victime porte déjà une marque de 18 ; deux ennemis sont voisins. Trois PA sont disponibles. Frapper la faille inflige 78 avant résistance dans la version de base, 84 avec l'amélioration actuelle. Ensuite le héros marche d'une case et utilise Estoc sur le voisin. Les ennemis n'ont pas de résistance dans cette fixture.

| PV de la première victime | Maîtrise actuelle : dégâts effectifs totaux sur les deux cibles | Prototype de transfert émulé | Lecture |
|---|---:|---:|---|
| 76 | 108 | **116** | Les six dégâts d'amélioration auraient été excédentaires sur la victime ; la transmission apporte huit dégâts utiles. |
| 80 | **112** | 100 | Le prototype laisse deux PV à la victime, ne transmet rien et empêche aussi le bonus d'isolement contre le voisin. |
| 90 | **106** | 100 | Aucune version ne tue ; l'amélioration de dégâts conserve son avantage. |

Le total concerne la séquence exécutée, pas le meilleur coup possible de chaque position. Les marques transférées sont injectées après le kill pour **émuler** le prototype ; celui-ci n'est pas une carte implémentée. Toutes les autres actions passent par la légalité du moteur.

Cet exemple corrige deux simplifications de l'audit : « −6 maintenant contre +8 ensuite » ignore les dégâts excédentaires ; inversement, une maîtrise qui change l'usage n'est pas automatiquement meilleure qu'un bonus de dégâts. Les seuils de kill et l'isolement doivent apparaître dans l'aperçu.

## 5. Ce que je changerais dans les priorités de conception

| Priorité | Proposition concrète | Pourquoi maintenant |
|---|---|---|
| P0 | Afficher les normales achetables à l'unité et le nombre préparé / en réserve. | C'est le levier marchand le plus simple qui explique la majorité du signal mesuré. |
| P0 | Afficher la prochaine pression en PV, son caractère inévitable par la garde, et son aggravation. | Une bonne défense contre les ennemis peut masquer une mort certaine en temporisant. |
| P0 laboratoire | Conserver plusieurs politiques de jeu et les graines d'échec connues. | Le classement des classes dépend fortement du pilotage. Un seul taux de victoire n'est pas une preuve d'équilibre. |
| P1 | Distinguer quantité de cartes et fonctions encore disponibles. | Quatre cartes de mobilité/pioche peuvent constituer un stock réel mais aucune offensive pour finir une brute. |
| P1 | Garder les trocs comme choix d'adaptation, avec trois cartes cédées clairement montrées. | Leur contribution est réelle mais se recouvre avec les achats ; pas besoin d'automatiser tout le marchand. |
| P1 contenu | Spécifier la fenêtre exacte des maîtrises de relais et les conditions d'élimination. | Les cas de Faille transmissible produisent des décisions intéressantes seulement si leur durée est comprise. |
| P2 | Favoris protégés, nouvelles jauges, compagnons complets. | Aucun effet de la protection dans ce lot ; les autres ajouts ne sont pas nécessaires pour expliquer les gains. Leur intérêt doit venir d'un besoin distinct. |

Le lien avec l'étude WAVEN précédente est ici un principe de conception : une règle de héros et ses conversions doivent produire une décision compréhensible. Cette suite ne prétend pas apporter de nouvelles données sur la version actuelle de WAVEN ; ses nouvelles preuves concernent Catabase.

## 6. Preuves et limites

- **320 runs** pour le plan factoriel marchand et **120** pour les trois politiques supplémentaires. Les références sont réutilisées, pas comptées deux fois. Trois relectures diagnostiques sont séparées de cette série.
- **440 conservations d'inventaire**, **5 111 observations de combat**, **2 127 transactions ciblées** vérifiées. Vérification du préfixe identique avant marchand pour les huit politiques économiques ; cohérence des résultats avec les SHA-256 des quatre sources V1.
- Identité de la baseline instrumentée avec le modèle original sur un cas ; reproduction du bras complet précédent ; quatre contrôles de non-mutation par la simulation de phase et quatre contrôles du comportement précoce de l'urgence.
- Calculs marchands, pression et six micro-scénarios de transfert vérifiables par `--check`. Les résultats négatifs ne sont pas retirés.
- Aucune validation du ressenti, de l'ergonomie ou de la durée de réflexion humaine. Pas de test Godot revendiqué. Pas de conclusion sur les autres spécialisations ou sur une difficulté optimale.

Reproduire depuis la racine :

```powershell
node docs/design/waven_investigation_2026-09-26/suite_02/executer.mjs --contracts-only
node docs/design/waven_investigation_2026-09-26/suite_02/executer.mjs
node docs/design/waven_investigation_2026-09-26/suite_02/executer.mjs --pilotage
node docs/design/waven_investigation_2026-09-26/suite_02/analyser.mjs
node docs/design/waven_investigation_2026-09-26/suite_02/micro_scenarios.mjs --check
node docs/design/waven_investigation_2026-09-26/suite_02/diagnostics.mjs
```

Résultats complets : [marchand](MARCHAND.json), [pilotage](PILOTAGE.json), [synthèse et vérifications](SYNTHESE.json), [micro-scénarios](MICRO_SCENARIOS.json), [diagnostics et traces](DIAGNOSTICS.json). Scripts et politiques : [laboratoire](laboratoire.mjs), [exécution](executer.mjs), [analyse](analyser.mjs). Journaux et variantes générées : `artifacts/dev/waven-investigation-2026-09-26/suite_02/`.
