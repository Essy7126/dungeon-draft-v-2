# Variantes de run comparées

Toutes les cases ci-dessous utilisent les **mêmes dix graines 10001–10010** et la première spécialisation de chaque classe. La référence est le sous-ensemble correspondant des 25 graines principales, pas leur moyenne complète. Une case compte des victoires sur dix, avec une incertitude importante.

| Variante | Assassin | Gardien | Arpenteur | Thaumaturge |
|---|---:|---:|---:|---:|
| V1 retenue, sous-ensemble apparié | 10/10 | 8/10 | 9/10 | 8/10 |
| Une action anticipée | 0/10 | 0/10 | 3/10 | 0/10 |
| Dépense facile, une action anticipée | 1/10 | 1/10 | 4/10 | 3/10 |
| Très économe, une action anticipée | 0/10 | 0/10 | 0/10 | 0/10 |
| Aucune carte rare ou supérieure | 9/10 | 8/10 | 8/10 | 8/10 |
| Aucun achat ni troc au marchand | 8/10 | 6/10 | 8/10 | 5/10 |
| Aucun équipement trouvé ou acheté | 10/10 | 7/10 | 10/10 | 7/10 |
| Aucune relique trouvée ou garantie | 9/10 | 7/10 | 9/10 | 8/10 |
| Préparation maximale 15 | 8/10 | 1/10 | 5/10 | 4/10 |
| Préparation maximale 30 | 9/10 | 8/10 | 10/10 | 7/10 |
| Aucune carte jouée | 0/10 | 0/10 | 0/10 | 0/10 |
| Anciennes tailles et probabilités des sacs normaux | 9/10 | 6/10 | 8/10 | 5/10 |

Les variantes de politique modifient à la fois la valeur accordée à la sécurité/aux copies et leur anticipation ; elles ne sont pas des profils de compétence humaine. Les autres variantes gardent le contrôleur de référence. Les achats et l’équipement peuvent modifier le stock, la pioche et la trajectoire : les différences ne sont pas toutes monotones. Aucune conclusion fine n’est fondée sur un écart d’une victoire sur dix.

Sans équipement, le budget épargné reste disponible pour les achats de cartes et soins. Sans marchand, les refuges gratuits restent actifs. Sans relique, l’Obole et les autres effets disparaissent mais les taux de cartes restent identiques. La variante sans rare retire seulement les cartes rares/légendaires/dieu/immortelles, pas les élites.

## Exemple observé : Gardien/Bastion, graine 10001

Chaque ligne provient du modèle, pas d’une partie humaine. « Stock après récompenses » inclut la réserve et les éventuels achats/trocs ; il ne faut pas le confondre avec la taille du deck engagé.

| Combat | Niveau | Tours | Copies jouées | Secours offensifs | PV à la victoire | Cartes engagées | Stock après récompenses | Or après services |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1 | 3 | 3 | 0 | 100.0 % | 15 | 14 | 75 |
| 2 | 2 | 5 | 7 | 0 | 100.0 % | 14 | 11 | 110 |
| 3 | 3 | 8 | 5 | 0 | 89.7 % | 9 | 18 | 80 |
| 4 | 4 | 7 | 8 | 0 | 91.5 % | 17 | 22 | 115 |
| 5 | 5 | 6 | 12 | 1 | 77.7 % | 20 | 20 | 120 |
| 6 | 6 | 6 | 7 | 1 | 91.0 % | 18 | 21 | 155 |
| 7 | 7 | 5 | 12 | 2 | 85.9 % | 20 | 23 | 129 |
| 8 | 8 | 7 | 12 | 4 | 96.7 % | 20 | 27 | 164 |
| 9 | 9 | 4 | 5 | 3 | 94.8 % | 20 | 34 | 199 |
| 10 | 10 | 9 | 13 | 4 | 92.5 % | 20 | 36 | 214 |
| 11 | 11 | 4 | 7 | 2 | 89.6 % | 20 | 40 | 169 |
| 12 | 12 | 10 | 13 | 5 | 91.3 % | 20 | 27 | 169 |

Bilan des copies : 15 initiales + 120 trouvées + 6 achetées, avec les trocs et ventes de la politique, donnent 27 restantes après 104 consommées. Dépenses : 36 or de sacs, 310 d’équipement, 0 de soins. Or final : 169. Le contrôle de conservation dans le modèle inclut séparément chaque entrée et sortie ; cette ligne d’exemple ne déduit pas le troc à partir d’un solde approximatif.

Les détails des 640 trajectoires se régénèrent dans `artifacts/dev/consumable-v1/runs.json`. Les synthèses et intervalles par groupe sont dans [run_summary.csv](run_summary.csv).
