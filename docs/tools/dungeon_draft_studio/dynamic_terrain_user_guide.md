# Guide utilisateur — Surfaces dynamiques

Statut : **WORKTREE_CANDIDATE**

## Dans Arena Studio

Ouvrir l’arène puis choisir la vue **Jeu**. Le panneau **SIMULER UN SORT DE
TERRAIN** propose :

- **Appliquer · Boule de feu** : vraie Spell, croix rayon 2, lave 3 tours,
  15 dégâts de terrain à l’entrée ;
- **Appliquer · Mur de glace** : vraie Spell et vraie croix rayon 3 ;
- **Appliquer · Eau (fixture)** : `eau.tres`, sans créer de sort de production ;
- **Avancer d’un tick** ;
- **Déplacer une fixture** pour déclencher un effet d’entrée ;
- **Effacer les surfaces** ;
- **Réinitialiser** la projection depuis la working copy inchangée.

La cible est la dernière cellule survolée, ou la première cellule jouable si
aucun survol valide n’existe. Le bandeau de statut indique la source, la cible,
la taille de zone, les cellules modifiées, les IDs stables, la durée, le trigger
et les dégâts de terrain.

## Lire l’inspecteur

L’inspecteur distingue deux sections :

```text
TERRAIN DE BASE
Pierre — praticable

SURFACE ACTIVE TEMPORAIRE
Lave — 2 rounds — à l’entrée — 15 dégâts
Source : Boule de feu / Mage
Danger IA : 3
```

Le terrain de base est la valeur qui reviendra à expiration. Une surface active
ne signifie jamais que l’`ArenaDefinition` a été modifiée.

## Recette de vérification manuelle

1. Ouvrir la run principale et la salle forestière intégrée.
2. Déployer le trio et sélectionner le Mage.
3. Lancer Boule de feu sur une croix de neuf cases éligibles.
4. Vérifier neuf textures lava et aucune dalle pierre visible dessous.
5. Entrer sur une dalle et vérifier les 15 dégâts de terrain.
6. Avancer trois ticks : 3 → 2 → 1 → expiration.
7. Vérifier le retour exact des neuf dalles pierre.
8. Lancer Mur de glace et vérifier texture ice / CellType ICE.
9. Dans Studio, appliquer la fixture eau et vérifier texture water / Mouillé.
10. Tester feu + eau (vapeur sans dalle) et feu + glace (eau).
11. Quitter et rouvrir Studio ; confirmer que la map canonique est inchangée.

## Diagnostic

Le runner de trace écrit uniquement sous `user://` et rapporte :

- le chemin exact de la run, de la salle, de la Spell et du TerrainEffectData ;
- les coordonnées `terrain_changed` ;
- les types GridData et durées par tick ;
- les rôles, terrains et visibilités des nœuds par cellule ;
- le fingerprint avant/après.

Le runner de captures écrit dans
`artifacts/dynamic_terrain_tile_replacement/captures/`. Le fichier
`capture_metrics.json` est l’index de vérité des 52 PNG.

## Limites connues

- La persistance entre salles/scènes est hors périmètre.
- Aucune Spell eau de production n’est ajoutée.
- La vapeur n’a pas d’asset de dalle ; le sol de base reste visible.
- Les previews rapides legacy peuvent encore employer des `SurfaceConfig` comme
  fixtures explicites. Le mode **Simuler un sort** n’en consomme aucune valeur
  gameplay.

