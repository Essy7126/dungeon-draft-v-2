# Correctif d’alignement des terrains permanents

Mission : `ARENA PERMANENT TILE ALIGNMENT AND TERRAIN BRUSH PARITY FIX`.

## Verdict causal

OBSERVÉ — `neutral.tres` chargeait directement la source brute
`raw/neutre.png` (1024×1024), tandis que `stone`, `water`, `ice` et `lava`
chargeaient des sorties normalisées 256×128. Le renderer, le polygone de
cellule, le pivot et le parent de rendu étaient déjà communs. Le décalage était
donc introduit par les bounds de la source, pas par une branche `neutral` du
renderer.

OBSERVÉ — deux listes UI codées en dur alimentaient les palettes historique et
dynamique. Elles contournaient le catalogue, le thème, le profil visuel et le
mode du document. Le brush bas niveau acceptait ensuite des identifiants dont le
plan de rendu ne possédait aucune texture permanente. Cette double autorité
créait les options fantômes.

DÉCISION VALIDÉE — `neutral` passe par le normaliseur déterministe existant,
avec le même crop commun, le même masque losange et la même sortie 256×128 que
les autres terrains permanents. Le catalogue charge désormais
`normalized/neutral.png`. Aucun offset correctif propre à `neutral` n’a été
ajouté.

DÉCISION VALIDÉE — `ArenaTileProjectionService.texture_contract()` impose une
texture 256×128 dont les bounds alpha occupent le canvas normalisé. Le plan de
rendu refuse une texture permanente hors contrat avec
`invalid_tile_visual_contract`.

## Architecture

`ArenaPermanentTerrainPaintService.get_paintable_permanent_terrains()` est la
source de vérité partagée par :

- les deux dropdowns Terrain ;
- leur état actif/inactif et leur motif lisible ;
- la preview du brush ;
- `ArenaDynamicEditingService.paint_permanent_terrain()` ;
- la validation effective avant mutation de la working copy.

Une entrée active doit avoir une définition de catalogue, une texture conforme,
être autorisée par le thème et le profil, et être visible dans le mode courant.
Le thème `forest` déclare explicitement `neutral`.

## Résultat par terrain

| stable_id | logique | praticable | état palette | motif |
|---|---:|---:|---|---|
| `stone` | NORMAL | oui | actif | terrain permanent certifié |
| `neutral` | NORMAL | oui | actif | terrain permanent certifié |
| `water` | NORMAL | oui | actif | terrain permanent certifié |
| `ice` | ICE | oui | actif | terrain permanent certifié |
| `lava` | WALL | non | inactif | parité GridData non certifiée |
| `void` | HOLE/retrait | non | inactif | utiliser Retirer ou clic droit |

DIVERGENCE — le bridge runtime transforme actuellement toute cellule
`playable=false` en `HOLE` avant les overrides. Une lave permanente écrite
`WALL` dans la working copy deviendrait donc `HOLE` dans `GridData`. La mission
interdisant une modification gameplay, `lava` reste visible mais désactivée.

## Preuve de parité directe

OBSERVÉ — aux trois résolutions, le test direct a chargé une copie distincte
sous `user://dungeon_draft_studio/arena_studio/tests/.../arena.tres`.
Le fingerprint working/temporaire/runtime était identique :
`4ac7c1a551587758e0449076a39df03543d830b4138edd58cc3901e43526068c`.
Le runner et le rapport confirment `produced_bundle_loaded=false`.

INCONNU — la correction de la projection gameplay de la lave permanente est
hors périmètre. Elle devra faire l’objet d’une décision distincte.

