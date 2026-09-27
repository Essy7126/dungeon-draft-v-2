# Ce que le joueur verra

Maquette de parcours textuelle pour l'implémentation. Les exemples sont des états proposés, pas des captures du jeu actuel. Conserver la galerie d'apparences et le travail visuel de sélection en cours.

## 1. Sélection et première préparation

Parcours V2 : apparence → classe → préparation → récapitulatif et départ. La difficulté Standard V2 est indiquée dans le récapitulatif ; pas d'étape de choix sans autre option calibrée. Les sélecteurs de difficulté historiques restent liés aux anciens profils. La création propose les presets de cinq familles × trois, puis autorise les ajustements jusqu'à 15 copies normales. Les fonctions essentielles restent visibles : dégâts, défense, mobilité, préparation. Le système signale les manques, il ne refuse pas une composition atypique légale.

```text
GARDIEN — tenir, déplacer, riposter
La première attaque absorbée par votre garde renvoie des dégâts.

Préparées 15/15       Familles 5       Ouverture : Garde ferme
[Garde ferme ×3] [Heurt du rempart ×3] [Repousser ×3]
[Trait court ×3] [Pas latéral ×3]

Une carte jouée est dépensée pour cette aventure.
Ses améliorations restent acquises à toute sa famille.

[Personnaliser]                                  [Commencer]
```

Les informations de coefficient apparaissent au survol avec les valeurs au niveau actuel. La normale préparée est une copie possédée ; choisir une famille affiche les exemplaires puis désigne un UID. Le preset la sélectionne de façon visible, le joueur peut retirer ce choix.

Dans la sélection Thaumaturge, deux presets décrits simplement : **Standard — préparer et frapper**, **Terrain — eau, givre et vapeur**. Aucun second achat ni déblocage n'est requis.

## 2. Combat : coûts et conséquences avant validation

La main affiche le coût, la portée minimale/maximale, les effets et le nombre de copies de cette famille encore accessibles pendant ce combat. Le stock laissé en réserve est distingué de la pioche disponible. Les deux secours restent à un emplacement fixe, hors de la main.

```text
PV 150/240   Garde 46   PA 2/4   PM 2/3   Tour 5
Préparées restantes 11   Pioche 4   Défausse 2   Réserve hors combat 9

Répercussion — portée 1–3 — 2 PA
Garde engagée :  [0] [8] [16] [24] [32]   réglage précis
Prévision : 76 dégâts bruts ; garde après action 14
Copie dépensée : Répercussion, exemplaire 1 sur 2

Sur le plateau : cible, déplacement, zones résultantes et ripostes annoncées.
```

Ce panneau ne donne pas de score automatique de « meilleur coup ». Il montre les conséquences connues. Dégâts réellement attendus après protections, seuils de mort et garde restante sont calculés avec le résolveur commun. Une zone de vapeur future affiche aussi la ligne de vue qu'elle ferme.

Le texte « Dépensée » et une animation courte retirent la carte lors de l'engagement logique. Annuler le ciblage restitue la sélection sans coût. Pas de confirmation supplémentaire à chaque carte normale ; le choix de cible et la prévision constituent la validation.

Ancre de repli est une commande contextuelle affichée près des déplacements, avec coût 1 PM et destination surlignée. Une case occupée affiche la raison. Relais ouvre un choix de cible après la résolution ; **Passer** est toujours disponible. Le choix en attente peut être sauvegardé.

## 3. Intention, terrain et pression

Chaque intention préparée montre source, cases, échéance et dégâts. Une intention annulable précise la condition utile : quitter la case, briser la ligne de vue, occuper une dalle. Une modification de position met immédiatement la prévision à jour.

Les ressources bornées se voient : une charge de parade, garde de soutien avec sa source, phases restantes d'une surface. La couleur seule ne porte aucune information indispensable ; forme, icône et texte la complètent.

À partir du tour 8 : « Fin du prochain tour : pression de X PV, traverse la garde ». Montrer l'aggravation du tour suivant. Si l'ennemi final peut être éliminé avant, la prévision l'indique ; ne pas afficher une perte déjà annulée par la victoire.

## 4. Bilan : acquisitions et décisions séparées

Ordre : résultat de combat → sacs et contenus reçus → progression → préparation ou halte. Un sac s'ouvre en montrant ses exemplaires ; le joueur ne choisit pas une carte parmi trois. Revenir à l'écran ne rejoue pas le tirage ni le reçu.

```text
Victoire — 3 ennemis vaincus
5 copies dépensées ; 10 préparées survivantes
Butin reçu : [sacs] → [exemplaires et provenance]

Garde ferme : 1 préparée + 2 en réserve
Heurt du rempart : 0 préparée + 1 en réserve
Prochain marchand : après cette étape

[Voir le bilan] [Préparer la suite]
```

Ces nombres illustrent l'affichage ; ce n'est pas une prédiction du butin d'un combat précis. Le suivi de deux familles affiche leur état même lorsqu'aucune nouvelle copie n'est tombée.

Une montée de niveau présente les choix restants une fois. Caractéristique, amélioration familiale et spécialisation ont leur propre reçu. Un point familial peut rester en attente. La fiche d'amélioration montre le changement de règle et son coût d'opportunité, par exemple moins de garde supplémentaire en échange d'une rétention.

## 5. Marchand : rendre la précision visible

```text
Or : 72                         Prochaine halte : profondeur 7

Compléter vos familles suivies
Garde ferme     8 or    stock 1     possédées 3 / préparées 1
Heurt du rempart 8 or   stock 1     possédées 1 / préparées 0

Sac de 6 normales   36 or   stock 2
Troc : 3 normales choisies → 1 normale choisie   reste 2
Soin : +30 % PV max 25 or
[Équipements] [Reliques accessibles] [Réaffecter une amélioration]
```

L'achat affiche immédiatement l'UID reçu et sa destination en réserve. Aucun ajout automatique au deck : un bouton explicite « Préparer » réalise l'action hors combat. Au troc, les trois copies données et la copie obtenue sont visibles ensemble ; refuser n'a aucun effet.

Suivre une famille n'est pas une interdiction de la vendre. Une vente d'une copie désignée pour l'ouverture indique qu'elle retire ce choix. Les équipements du même emplacement se comparent avec les statistiques finales et les conséquences sur PV/PM/portée. Les changements de santé ne doivent jamais créer un soin par aller-retour d'équipement.

## 6. Reprise, anciennes parties et fin

L'écran Continuer identifie discrètement la règle de la partie sauvegardée. Une ancienne partie reste jouable avec son ancien catalogue ; Nouvelle partie Cartes basculera sur V2 après validation. Le joueur ne reçoit pas un inventaire converti au milieu de son aventure.

Une interruption V2 reprend la dernière action complète, éventuellement sur un choix de relais ou de récompense en attente. Aucun tour adverse n'est sauté, aucune carte consommée n'est rendue. Si une écriture échoue, expliquer l'échec et proposer de réessayer ; ne pas continuer des actions qui ne pourront être sauvegardées.

En fin de run : résultat, cause de défaite le cas échéant, découvertes, familles jouées, copies restantes et dernières décisions. Ne pas donner de bonus de score pour garder une rare jusqu'à la mort. La nouvelle run recrée sa préparation initiale.

## 7. Quatre observations humaines avant bascule publique

1. Après deux combats, le joueur peut expliquer la différence entre une copie consommée et une amélioration conservée.
2. Face à un soutien ou une intention préparée, il trouve au moins une réponse sans infliger directement plus de dégâts.
3. Au premier marchand, il comprend l'achat ciblé et son coût face au soin/équipement.
4. Après une défaite, il peut identifier un choix qu'il aurait changé ; les traces permettent de confirmer ou nuancer son explication.

Ce sont des objectifs d'observation, pas des résultats déjà obtenus. Les retours sur durée, fatigue de préparation et réticence à jouer une rare doivent guider la calibration.
