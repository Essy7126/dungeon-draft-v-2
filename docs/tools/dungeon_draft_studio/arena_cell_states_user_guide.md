# Comprendre les cases dans Arena Studio

Statut : **WORKTREE_CANDIDATE**

## Retirer une case

L'outil **Retirer une case** enlève réellement la case de la forme de l'arène.
Le décor de fond peut rester visible à cet endroit, mais aucune dalle tactique
ne doit apparaître dans Canvas, Art, Jeu ou Tester. Un clic droit avec l'outil
d'ajout produit le même retrait.

## Peindre VOID

`VOID` conserve éventuellement une définition technique pour l'édition, mais
la case est un trou : pas de dalle, pas de clic tactique, pas de déplacement et
pas de surface dynamique. Utilisez VOID pour dessiner un vide explicite ;
utilisez Retirer pour sortir la coordonnée du document.

## Bordure

Une bordure existe encore dans l'arène. Elle peut rester visible selon la
politique de sol, mais les personnages ne peuvent pas l'utiliser. Elle n'est
donc pas équivalente à une case retirée.

## Obstacle et case non jouable

Un obstacle, de la lave bloquante ou un mur logique peuvent rendre une case non
jouable tout en gardant sa dalle. Arena Studio sépare volontairement la
visibilité du sol et la praticabilité.

## Vérifier la forme

1. Retirez la case dans le Canvas.
2. Ouvrez **Art** : seul le background doit être visible dans le trou.
3. Ouvrez **Jeu** : la même forme doit être conservée.
4. Lancez **Tester**. Un nouveau contexte temporaire est créé à chaque clic.
5. Dans le diagnostic **TOPOLOGIE**, vérifiez :

```text
Cases retirées rendues : 0
Coordonnées inattendues : 0
Coordonnées manquantes : 0
```

Le mode Logique peut afficher un contour et les coordonnées d'un trou. Ce
contour est une aide de diagnostic et ne doit jamais devenir une dalle pleine.

Après Undo ou Redo, Art, Jeu et Tester doivent être recalculés avant toute
production ou intégration à une run.

