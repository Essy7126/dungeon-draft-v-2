# Contrat du brush de terrain permanent

## Autorité

L’unique entrée publique de sélection est :

```gdscript
ArenaPermanentTerrainPaintService.get_paintable_permanent_terrains(
    arena, include_disabled
)
```

L’unique entrée UI de mutation est :

```gdscript
ArenaDynamicEditingService.paint_permanent_terrain(arena, cell, terrain_id)
```

Le helper bas niveau `paint_terrain()` reste réservé aux opérations internes et
au retrait `void`; il ne constitue pas une autorisation produit.

## Conditions d’activation

Une entrée permanente est active si et seulement si :

1. son `stable_id` existe dans `ArenaCatalogService` ;
2. sa définition est déclarée productible (`dynamic_catalog`) ;
3. sa texture existe et respecte le contrat visuel 256×128 ;
4. le thème courant l’autorise ;
5. le profil modulaire courant l’autorise ;
6. le mode PAINTED ne confie pas déjà le sol à l’image peinte ;
7. la politique HYBRID ne masque pas ce terrain ;
8. sa projection GridData est certifiée identique à la working copy.

Le dropdown et le brush interrogent la même décision. Une entrée désactivée ne
peut donc pas muter le document, même si un appel UI erroné est émis.

## Raisons stables

Les principaux `reason_code` sont : `catalog_missing`,
`not_production_placeable`, `permanent_texture_missing`,
`invalid_visual_contract`, `theme_unsupported`, `profile_unsupported`,
`painted_mode`, `hybrid_floor_hidden`, `hybrid_base_hidden`,
`runtime_grid_uncertified` et `topology_tool_required`.

Les entrées informatives restent visibles, grisées et accompagnées d’une raison
lisible. `void` n’est jamais présenté comme un pinceau de sol : il relève de la
topologie. `lava` est inactive tant que sa projection WALL/HOLE diverge.

## Mutation et parité

Pour une entrée active :

```text
dropdown actif
→ garde paint_permanent_terrain
→ terrain_id dans ArenaEditSession.working_arena
→ une action d’historique par stroke
→ canvas incrémental
→ preview runtime
→ copie temporaire user:// du test direct
→ scène de bataille modulaire
```

Le contrat exige un nœud de sol par cellule attendue, aucun doublon, la même
texture résolue et le même fingerprint après save/reload. La grille, la
sélection et les highlights utilisent le même polygone de cellule que les
dalles.

RECOMMANDATION — toute future entrée de palette doit être ajoutée au catalogue,
au thème et au profil, puis certifiée par le service. Ne pas réintroduire de
tableau d’identifiants dans l’UI.

