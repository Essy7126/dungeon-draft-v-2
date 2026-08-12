# Contrat temporel des statuts de terrain

Statut : **WORKTREE_CANDIDATE**. Autorité :
`ArenaTerrainStatusTimingService`, moteur de surface existant et `Unit`.

## Début d'activation

```text
1. résoudre les statuts déjà présents
2. appliquer leurs ticks
3. décrémenter ou expirer
4. lire le terrain permanent
5. lire la surface temporaire
6. appliquer ou rafraîchir le statut de terrain
```

Le statut appliqué à l'étape 6 ne reticke pas dans la même activation. La fin
d'activation exclut les statuts appartenant aux terrains.

Une entrée résout l'effet direct, puis applique/rafraîchit le statut. Pour
`poison`, `burn`, `wet` et `frozen`, un `status_id` produit une seule instance et
une durée égale au maximum entre durée restante et nouvelle durée.

- Poison : 4 dégâts magiques au début d'activation, durée 3, défense ignorée,
  non esquivable ;
- Lave : 15 dégâts d'entrée ;
- Brûlure : 6 dégâts périodiques, sans fusion avec la Lave ;
- Eau électrifiée : 20 dégâts Foudre existants, Mouillé et Choc.

Les logs distinguent `[TERRAIN]` et `[STATUT]`.

Une entrée volontaire électrifiée consomme les actions et termine le mouvement
courant, sans supprimer aussi l'activation suivante. Une entrée forcée hors
activation applique un `shock` qui saute la prochaine activation une fois. Le
verrou `(unit, round, electrified_region)` limite à un Choc par round, y compris
après plusieurs cellules ou une sortie/réentrée.

