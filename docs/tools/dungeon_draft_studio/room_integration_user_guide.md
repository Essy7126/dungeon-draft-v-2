# Intégrer une arène dans une run

Ce parcours ne demande ni Git, ni ouverture de fichier `.tres`, ni manipulation
de Resource Godot.

## Parcours recommandé

1. Ouvrir Arena Studio.
2. Dans **Destination de la salle**, choisir **Principale** ou **Test**.
3. Choisir **Mettre à jour l’arène — recommandé**.
4. Choisir la salle cible. Le numéro affiché est sa position dans la run.
5. Construire ou modifier l’arène, puis contrôler les vues **Logique**, **Art**
   et **Jeu**.
6. Cliquer **Valider**, puis **Tester**.
7. Relire le résultat, la portée, les chemins et les fichiers affectés dans le
   panneau Destination.
8. Cliquer le bouton principal, par exemple
   **Intégrer dans Principale — Mettre à jour salle 3**.

Le Studio produit les ressources, crée un point de récupération, met à jour la
salle, recharge la run et sélectionne immédiatement la salle intégrée.

## Choisir la bonne action

- **Mettre à jour l’arène — recommandé** conserve la rencontre, les vagues, les
  ennemis directs, les récompenses et les règles de combat de la salle. La
  salle reste au même index et garde normalement le même chemin.
- **Créer une nouvelle salle** ajoute la nouvelle salle à la fin de la run.
- **Insérer avant / après** ajoute une nouvelle salle à la position indiquée.
- **Remplacer toute la salle — avancé** remplace la référence complète. Le
  Studio affiche les données gameplay qui ne seront pas reprises. L’ancien
  fichier n’est jamais supprimé.
- **Produire sans intégrer** génère le bundle de production sans modifier la
  RunData.

Si une salle est partagée par plusieurs runs, **Mettre à jour** crée
automatiquement une copie propre à la run choisie. Les autres runs et le fichier
partagé restent inchangés.

## Comprendre les trois objets

- Une **run** est une suite ordonnée de salles.
- Une **salle** contient le gameplay : identité, rencontre ou vagues,
  récompenses, scène et arène.
- Une **arène** contient la partie tactique et visuelle : grille, dalles, murs,
  obstacles, spawns, décor, premier plan et occlusion.

## En cas de blocage

Le bouton d’intégration reste désactivé si la validation échoue, si la run
finale serait invalide, si un autre document possède des changements non
sauvegardés, si la source a changé sur disque ou si une propriété n’a pas de
politique d’intégration.

Le panneau indique la cause. Résoudre le document concerné, relancer la
validation, puis recalculer le plan. Un échec après production conserve le
bundle pour diagnostic mais restaure la salle et la RunData canoniques.

Les boutons **Détacher la fenêtre** et **Réintégrer la fenêtre** déplacent
uniquement la fenêtre du Studio. Ils n’intègrent aucun contenu dans une run.

