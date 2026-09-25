# Calculs de l'extension

Exécution réussie : **16 cas, 32 assertions**. [Résultats complets et hypothèses](resultats_calcules.json). Les modèles n'exécutent ni Godot ni DOFUS/WAKFU ; ils vérifient les conséquences arithmétiques des contrats retenus et des prototypes explicitement inventés.

```powershell
node docs/design/dofus_wakfu_spell_identity_2026-09-25/extension_classes_bestiaire/calculs.mjs
```

## Accès aux réponses et préparation de deck

Pour N cartes, K réponses, main h sans remise :

`P(au moins une réponse) = 1 − C(N−K,h)/C(N,h)`.

Avec trois A et trois B disjoints :

`P(A et B) = 1 − 2 C(N−3,h)/C(N,h) + C(N−6,h)/C(N,h)`.

| Deck / main cinq | Une réponse parmi trois copies | Au moins un A et un B |
|---|---:|---:|
| 15 cartes | 73,63 % | 51,45 % |
| 30 cartes | 43,35 % | 16,53 % |

Un plafond de trente ne doit pas devenir une obligation de remplir trente places. Si une rencontre impose deux outils précis dès le premier tour, la disponibilité s'effondre. Une commande de salle coûtant 2 PA résout la dépendance de main dans le modèle logique, **pas** son accessibilité spatiale : chemin, tacle, zone dangereuse et PA restants doivent encore être vérifiés.

## Paiements et temporalité

| Cas | Résultat | Interprétation |
|---|---|---|
| Commande coût 1 PA puis remboursement 1 | Impossible avec zéro ; possible avec un, solde inchangé | Coût net nul ≠ coût d'accès nul ; une copie est tout de même dépensée dans notre adaptation. |
| Protection ×0,5 maintenant puis ×1,5 après ; impacts 120 puis 40 | 120 reçus au lieu de 160 | L'effet aide si le risque est surtout immédiat. |
| Même protection ; impacts 40 puis 120 | 200 au lieu de 160 | L'ordre renverse sa valeur. |
| Trois poses de bombes conservées, coût 2 + nombre déjà posé | 2+3+4 = 9 PA sur au moins deux tours | Le moteur préparé coûte davantage que trois fois le prix initial. |
| Tout ou rien : 60 % PV contre 40 %, base 98 | Risque 70 %, auto-dégâts moyens bruts 68,6 | Exemple intérieur aux bornes ; pas d'hypothèse sur le clamp aux extrêmes. |
| Hémophilie : N245, dix niveaux convertis | 98 de base, différés, catégorie mêlée | Changer le timing et la catégorie change aussi les synergies de build. |

Sources des sorts : fiches individuelles dans [DOFUS](CLASSES_DOFUS.md) et [WAKFU](CLASSES_WAKFU.md). Aucun de ces calculs ne contient une panoplie complète, une résistance de cible ou une estimation de taux de victoire.

## Composition, zone et attrition

Le prototype de pression compare quarante dégâts en un impact ou en quatre impacts de dix. Les PV restants sont identiques, mais seul le second franchit le seuil choisi. Le cas létal vérifie aussi l'absence de charge après mort. C'est une **convention de notre prototype**, pas une affirmation sur l'ordre interne de WAKFU.

L'anneau mobile vérifie qu'une poussée peut placer simultanément un ennemi **et le héros** dans la zone. Une meilleure rentabilité offensive ne signifie donc pas automatiquement une meilleure décision. Le modèle simultané conserve tous les occupants initiaux : tuer le chef au premier impact ne sauve pas les autres d'une explosion déjà engagée.

| Modèle | Résultat |
|---|---|
| Réservoir local, six charges protégées | 132 dégâts avant défense ; coût total 7 PA avec la décharge, soit 18,86 dégâts/PA nominal. |
| Trois charges volées | 66 dégâts disponibles ; jusqu'à 36 PV ennemis restaurés ; écart maximal de pression de 102. |
| Boss fictif 360 PV, attaques effectives 30, sans soin | 12 copies et 24 PA si chaque attaque coûte 2 PA. |
| Même boss, trois soins de 60 | 18 copies et 36 PA ; empêcher un soin économise deux copies nominales. |
| Renfort T1 puis chaque quatre tours, éliminé entre appels | Quatre renforts possibles en treize tours même avec plafond de vivants ; un budget total de deux borne l'attrition. |
| Six événements de mort, deux ennemis initiaux, identité conservée | Deux éligibilités au butin ; les résurrections et invocations n'en ajoutent pas. |

## Un piège de transposition équipe → solo

Prototype abstrait : une jauge conserve la moitié de sa valeur puis gagne trois à chaque tour. `p(t+1)=0,5p(t)+3`. Depuis zéro, elle tend vers six sans l'atteindre. Un seuil de douze est impossible, quel que soit le nombre de tours. Un seuil de cinq devient accessible au troisième tour. Copier une exigence collective dans un jeu solo peut donc produire un verrou mathématique, pas simplement un combat difficile.

## Ce qui reste à éprouver

Ces cas n'intègrent ni toutes les mains successives, ni déplacement complet, ni IA, ni résistances, ni reliques, ni économie d'une run entière. Ils détectent des erreurs de conception avant ces essais. Ils ne prouvent pas l'équilibrage de nos quatre prototypes ou de l'ensemble des 155 fiches lues.
