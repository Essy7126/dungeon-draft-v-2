# Architecture de l'historique Arena Studio 1.1

## Autorité et isolation

Chaque `ArenaEditSession` possède une working copy `ArenaDefinition` et un
`StudioHistoryController`. Il n'existe ni enregistrement parallèle dans
`EditorUndoRedoManager`, ni pile globale partagée. Deux maps ouvertes ont donc
deux historiques indépendants. Encounter Studio conserve son mécanisme ; la
barre de Dungeon Draft Studio ne fait que déléguer à l'onglet actif.

Le contrôleur conserve au plus 100 actions. Une entrée contient un nom et les
snapshots complets avant/après. Il expose Undo, Redo, `jump_to`, les noms des
actions, l'index courant et les signaux de changement. Une nouvelle action
après Undo tronque la branche Redo.

## Transactions

À l'appui, Arena Studio capture le snapshot initial. Les `MouseMotion` ne font
que prévisualiser la transformation canonique. Le relâchement enregistre une
seule entrée si le contenu a réellement changé. Une annulation restaure le
snapshot sans créer d'entrée. Les répétitions des flèches sont regroupées par
un délai court en une action « Déplacer la grille au clavier ».

## État sauvegardé

Le dirty state compare le SHA-256 du JSON déterministe de la working copy au
fingerprint sauvegardé. Revenir au même contenu par Undo ou par un autre chemin
rend la session propre. Sauvegarder déplace le marqueur sans effacer
l'historique ; un point sauvegardé est indiqué dans le menu Historique.

## Barre partagée et raccourcis

La barre principale affiche toujours Annuler, Rétablir et Historique. Les
infobulles reprennent le nom de l'action. Ctrl+Z annule, Ctrl+Shift+Z et Ctrl+Y
rétablissent. Les champs `LineEdit`, `TextEdit`, `CodeEdit` et l'éditeur interne
d'un `SpinBox` gardent leur Undo local. Si un geste est actif, le premier
raccourci l'annule sans consommer aussi l'action précédente.
