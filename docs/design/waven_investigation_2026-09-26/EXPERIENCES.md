# Expériences : accès au combo et politique marchande

**120 runs exécutés jusqu'à victoire ou défaite, sur la V1 consommable uniquement.** Quatre classes, leur première spécialisation, dix graines chacune (`27001` à `27010`), trois variantes appariées. Le modèle et les coefficients d'origine restent inchangés ; les variantes générées se trouvent dans `artifacts/dev/waven-investigation-2026-09-26/`.

## Protocole fixé avant l'exécution

Même politique de combat `planner`, préparation plafonnée à 20 cartes, progression, drops, marchands finis et attribution de statistiques. Les premières spécialisations sont Exécution, Bastion, Sniper et Pyre.

| Variante | Intervention |
|---|---|
| Référence | Politique existante, instrumentée pour enregistrer stock, deck et main initiale. Son résultat complet a été comparé à celui du module original sur une graine : identité hors instrumentation. |
| Ouverture | Une copie normale existante du deck préparé est garantie parmi les cinq cartes initiales. Priorités : `a01`, `g01`, `r01`, `t03`. Si elle manque : première normale native, puis première normale disponible. Aucun ajout de copie, de place ou de PA. |
| Réapprovisionnement | Après le soin urgent, acheter/troquer pour viser deux copies de chacune des familles prioritaires : `a01/a02`, `g01/g02`, `r01/r02`, `t03/t02`. Un achat unitaire par famille et visite, à 8 or. Un troc ciblé éventuel contre trois normales, avec au moins 18 cartes avant ce troc et conservation du dernier exemplaire de chaque autre normale. Les stocks marchands et deux trocs maximum restent ceux de la V1. Les deux familles sont aussi protégées des trocs génériques et ventes ultérieures. |

Le troisième bras est une **politique composée**, pas le test isolé du prix de 8 or : achats, priorité des trocs et protection de certaines cartes changent ensemble. Les achats habituels continuent ensuite. L'ouverture préparée n'est pas ajoutée au réapprovisionnement ; aucune synergie entre ces deux variantes n'est démontrée.

## Résultats

| Classe / spécialisation | Référence | Ouverture préparée | Achats/trocs ciblés |
|---|---:|---:|---:|
| Assassin / Exécution | 10/10 | 10/10 | 10/10 |
| Gardien / Bastion | 8/10 | 8/10 | 10/10 |
| Arpenteur / Sniper | 7/10 | 7/10 | 10/10 |
| Thaumaturge / Pyre | 4/10 | 7/10 | 8/10 |
| **Total** | **29/40** | **32/40** | **38/40** |

Face à la référence, l'ouverture transforme cinq défaites en victoires, mais transforme aussi deux victoires en défaites. Le réapprovisionnement sauve neuf runs et n'en perd aucun dans cet échantillon. Ce dernier résultat est un signal de sensibilité de la politique ; il n'est pas un taux de victoire attendu pour un joueur.

Les deux échecs persistants du réapprovisionnement sont Thaumaturge, graines `27001` et `27005`, au **combat 3**, avant le premier marchand. Il serait absurde de demander à la boutique de résoudre ce verrou. Un test distinct de l'ouverture Thaumaturge et de cette rencontre devient pertinent.

### Diagnostic complémentaire des deux défaites précoces

Deux relectures instrumentées de ces mêmes runs, avec les règles et la politique de référence inchangées, donnent :

| Graine | Fin | PV perdus dans ce combat | Dont pression | Gestes de garde | État final |
|---|---|---:|---:|---:|---|
| 27001 | Tour 17 | 164,40 | 160,15, soit 97,42 % | 16 | Une brute à 25,09 PV ; quatre cartes de mobilité/pioche préparées encore disponibles. |
| 27005 | Tour 17 | 158,62 | 154,38, soit 97,33 % | 16 | Deux brutes à 39,91 et 37,87 PV ; cinq cartes de garde/mobilité préparées encore disponibles. Aucune attaque de secours utilisée. |

Ce sont des blocages de fin de combat après épuisement de l'offensive préparée, avec 110 or inutilisable avant la halte. Ce n'est pas une élimination rapide par des ennemis surpuissants. La pression ignore la garde ; continuer à en produire ne la résout pas.

Le code de `evaluate()` estime la menace et les gains immédiats ; sa recherche de deux actions ne déroule pas une fin de phase ennemie et n'intègre pas explicitement le coût futur de la pression. **L'attribution causale exacte entre stock offensif, choix précédents et prudence du bot reste à isoler**, mais la trace suffit à invalider une lecture simpliste « le Thaumaturge ne résiste pas ». Tester d'abord l'évaluation de l'urgence et les options de secours avant un buff global. Données : [ECHECS_PRECOCES.json](ECHECS_PRECOCES.json), script [inspect_failures.mjs](inspect_failures.mjs).

## Accès : posséder, préparer, piocher

| Mesure sur tous les combats effectivement atteints | Référence | Ouverture | Réapprovisionnement |
|---|---:|---:|---:|
| Combats observés | 445 | 452 | 462 |
| Deux familles ciblées présentes en stock | 65,84 % | 69,47 % | 78,35 % |
| Deux familles ciblées dans la main initiale | 14,61 % | 33,63 % | 23,81 % |
| Combats gagnés par run, moyenne | 10,85 | 11,10 | 11,50 |

Sur cet échantillon, le bot prépare toujours les familles ciblées lorsqu'elles sont toutes deux disponibles : stock et deck ont donc le même taux. Cela ne veut pas dire que toute carte utile du stock est préparée.

Les pourcentages sur l'ensemble des combats portent sur des trajectoires différentes : les variantes qui survivent davantage voient aussi plus de combats tardifs. Ils sont descriptifs, pas une estimation causale isolée de l'effet de pioche. Au **premier combat**, comparable pour les 40 cas et sans achat possible : 21 mains contiennent les deux familles avec la référence, 31 avec l'ouverture, 21 avec le réapprovisionnement.

L'écart entre une formule théorique de main et le taux sur une run est normal : les copies disparaissent, les familles changent de nombre et le deck évolue. Posséder une famille ne garantit pas que la bonne cible, la portée et les PA permettent la combinaison.

## Coût réel

| Mesure moyenne par run exécutée | Référence | Ouverture | Réapprovisionnement |
|---|---:|---:|---:|
| Or consacré aux cartes | 19,80 | 22,50 | 65,00 |
| Or à l'issue de la run | 228,93 | 222,70 | 197,28 |
| Copies consommées | 82,80 | 83,95 | 84,70 |

Le réapprovisionnement a réellement réalisé **235 achats unitaires** et **95 trocs ciblés** : 1 880 or et 285 normales cédées contre 95 copies choisies, sur les 40 runs. En moyenne : 47 or d'achats ciblés et 7,125 normales données, pour 5,875 achats et 2,375 sorties de troc. Le solde économique du troc est bien négatif en quantité : trois copies deviennent une.

Ne pas lire « 84,70 > 82,80 » comme une inefficacité : les runs ciblés vont plus loin. Sur les **29 paires gagnées dans les deux variantes**, le réapprovisionnement consomme **2,03 copies de moins**, dépense **44,14 or de plus en cartes**, et termine avec **29,52 or de moins** en moyenne. Le reste des dépenses et revenus peut aussi changer avec la trajectoire.

L'or final élevé dans les trois bras est un autre signal : le bot conserve beaucoup de monnaie. Il ne démontre pas encore une tension optimale entre soin, cartes, équipement et reliques. Le résultat mesure surtout l'effet d'utiliser des options marchandes déjà disponibles.

## Ce que l'on peut conclure

1. Le diagnostic « la classe manque de dégâts » était insuffisant pour expliquer plusieurs échecs du bot.
2. La V1 possède déjà un moyen de rétablir une fonction perdue ; l'exploiter change beaucoup les résultats.
3. La préparation d'une normale améliore réellement l'accès, mais n'améliore pas uniformément les victoires de chaque classe.
4. Le début de run Thaumaturge reste un point d'investigation indépendant des boutiques.

Ce que l'on ne peut pas conclure : équilibre final, confort de l'interface, plaisir de consommer les cartes, temps de réflexion humain, généralisation aux huit spécialisations, combinaison des variantes, ou équivalence Godot/V1. Dix graines par classe restent peu ; les mêmes numéros de graine entre classes peuvent partager des structures aléatoires. Aucun test de significativité ne traite les 40 cas comme des observations humaines indépendantes.

## Reproduction et contrôles

```powershell
node docs/design/waven_investigation_2026-09-26/calculs.mjs --check
node docs/design/waven_investigation_2026-09-26/experiences.mjs --contracts-only
node docs/design/waven_investigation_2026-09-26/verifier.mjs
node docs/design/waven_investigation_2026-09-26/experiences.mjs
```

La dernière commande réexécute les 120 runs et régénère les résultats. Les variantes sont produites par substitutions à ancrage unique, qui échouent si le source ne correspond plus. Les quatre sources V1 sont hachées ; le vérificateur refuse des résultats dont les sources ont changé.

Contrats spécifiques : 132 ouvertures, dont deck vide, une seule carte, absence de normale ; conservation et unicité des copies ; taille de main ; garantie de la copie choisie. Vérification des 120 exécutions, 1 359 observations de combat et 330 transactions ciblées ; identité des combats avant le premier marchand entre référence et réapprovisionnement. Les transactions utilisent le service existant, qui valide budgets, stocks finis et conservation d'inventaire.

Les deux suites existantes `consumable_v1/model.test.mjs` et `consumable_v1/contracts.test.mjs` ont également été réexécutées : **199 tests réussis, zéro échec ou test ignoré**. Leur journal est `artifacts/dev/waven-investigation-2026-09-26/v1-tests.log`. Aucun test runtime Godot n'est revendiqué pour cette livraison documentaire.

Les contrats ne transforment pas le solveur automatique en joueur optimal. Données complètes : [EXPERIENCES.json](EXPERIENCES.json), [VERIFICATION.json](VERIFICATION.json). Les journaux complets sont dans `artifacts/dev/waven-investigation-2026-09-26/`.
