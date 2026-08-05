# Architecture du preview Arena

`ArenaRuntimePreview` est un `SubViewportContainer` possédant son monde de preview. Chaque reconstruction : clone l’ArenaDefinition, appelle `ArenaRuntimeBridge`, construit le vrai `GridData` et le vrai `Pathfinder`, configure `PaintedGridView`, puis appelle `ArenaVisualAssembler`.

Les vues sont :

- **Logique** : grille, types, spawns et diagnostics ;
- **Art** : background/foreground, terrains, murs et props sans debug ;
- **Jeu** : Art plus vrais `UnitView` alimentés par les `UnitData` du trio et de la rencontre.

Le renderer conserve le Y-sort, les murs dynamiques, l’occlusion/foreground et la caméra de la salle. Les UnitData dont la scène optionnelle est 3D utilisent le fallback `SpriteFrames` de UnitView dans ce viewport 2D.

Les demandes lourdes sont débouncées et identifiées par génération ; les options légères ne reconstruisent pas tout. `cleanup_preview()` libère le monde précédent. La parité est vérifiée par la même signature structurelle que le runtime. Aucun singleton de run n’est instancié ou modifié.
