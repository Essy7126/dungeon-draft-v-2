@tool
class_name TerrainGridAlignmentService
extends RefCounted

## Traduit la transformation affine runtime de la grille vers les mêmes mots
## que l'Inspecteur d'un Node2D : position, rotation, échelle et inclinaison.
## La base est le losange isométrique natif d'ArenaDefinition ; les valeurs
## 0° / (1, 1) / 0° représentent donc une grille isométrique non transformée.

const BASE_AXIS_X := Vector2(48.0, 24.0)
const BASE_AXIS_Y := Vector2(-48.0, 24.0)


static func settings_from_arena(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {}
	var base := Transform2D(BASE_AXIS_X, BASE_AXIS_Y, Vector2.ZERO)
	var current := Transform2D(arena.axis_x, arena.axis_y, arena.grid_origin)
	var relative := current * base.affine_inverse()
	return {
		"position": relative.origin,
		"rotation_degrees": rad_to_deg(relative.get_rotation()),
		"scale": relative.get_scale(),
		"skew_degrees": rad_to_deg(relative.get_skew()),
		"grid_size": arena.grid_size,
	}


static func snapshot_from_settings(settings: Dictionary) -> Dictionary:
	var position := settings.get("position", Vector2.ZERO) as Vector2
	var scale := settings.get("scale", Vector2.ONE) as Vector2
	var rotation := deg_to_rad(float(settings.get("rotation_degrees", 0.0)))
	var skew := deg_to_rad(float(settings.get("skew_degrees", 0.0)))
	if not GridTransformService.is_vector_finite(position) \
			or not GridTransformService.is_vector_finite(scale) \
			or not is_finite(rotation) or not is_finite(skew):
		return {"ok": false, "error": "Un réglage contient une valeur invalide."}
	if absf(scale.x) < GridTransformService.MIN_SCALE_FACTOR \
			or absf(scale.y) < GridTransformService.MIN_SCALE_FACTOR:
		return {"ok": false, "error": "L'échelle doit rester supérieure à 0,01."}
	var base := Transform2D(BASE_AXIS_X, BASE_AXIS_Y, Vector2.ZERO)
	var relative := Transform2D(rotation, scale, skew, position)
	var resolved := relative * base
	var snapshot := GridTransformSnapshot.new(
		resolved.origin, resolved.x, resolved.y
	)
	var validation := GridTransformService.validate_snapshot(snapshot)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true, "snapshot": snapshot}


static func centered_snapshot(image_size: Vector2i, grid_size: Vector2i) -> GridTransformSnapshot:
	var center := Vector2(image_size) * 0.5
	var offset := (
		float(maxi(grid_size.x - 1, 0)) * 0.5 * BASE_AXIS_X
		+ float(maxi(grid_size.y - 1, 0)) * 0.5 * BASE_AXIS_Y
	)
	return GridTransformSnapshot.new(center - offset, BASE_AXIS_X, BASE_AXIS_Y)


static func confirmation_anchors(snapshot: GridTransformSnapshot) -> Dictionary:
	if snapshot == null:
		return {"cells": [], "pixels": []}
	return {
		"cells": [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN],
		"pixels": [
			snapshot.origin,
			snapshot.origin + snapshot.axis_x,
			snapshot.origin + snapshot.axis_y,
		],
	}
