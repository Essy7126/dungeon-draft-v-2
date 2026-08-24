# Construction dynamique — mode intégré

## Ouverture

Le bouton **Lab** importe d’abord un éventuel transfert autonome vérifié, puis
appelle `show_dynamic_construction()`. Le bouton **DYN** bascule le même mode.
Le centre du Studio conserve `ArenaStudioCanvas`, son `ArenaEditSession`, son
historique, sa sélection et son routeur. Seule la palette contextuelle de
droite devient visible.

La palette expose :

- terrain : VOID, pierre, eau, glace et lave ;
- mur : normal, feu, glace et suppression ;
- spécial : spawn héros/ennemi, objectif, décoration, invocation et retrait ;
- largeur/hauteur de document, bornées de 1 à 64.

Une peinture continue ouvre une transaction au début du trait et la ferme au
relâchement. Terrain, mur, spawn, objectif et décoration passent par
`ArenaDynamicEditingService`, puis par le même historique que les autres
outils Studio.

## Ce qui n’existe plus

Le chemin intégré n’instancie plus `DynamicArenaLab.tscn`, ne remplace plus le
canvas par un `SubViewport` et ne possède plus de second `_unhandled_input`.
Il n’affiche pas les commandes autonomes Nouvelle/Ouvrir/Sauver/Envoyer au
Studio.

## Lab autonome

`tools/labs/dynamic_arena/DynamicArenaLab.tscn` reste exécutable séparément.
Il conserve sa barre de document et son transfert vers le Studio, mais partage
`ArenaDynamicEditingService` et `ArenaInputRouter`. Le transfert ouvre une
nouvelle working copy vérifiée, puis le Studio entre dans le mode intégré.


## Mise à jour — refonte du Studio Terrain (24/08/2026)

La construction dynamique reste le même mode sur le même canvas, la même
session et le même historique. Elle devient un réglage avancé : son bouton
n'apparaît plus en mode guidé, où les étapes `Sols` et `Obstacles et départs`
couvrent le parcours nominal. Le contrat d'interaction et les invariants du
routeur d'entrées sont inchangés.
