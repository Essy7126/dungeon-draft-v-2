@tool
class_name TerrainSurfaceVisualResolver
extends RefCounted


static func resolve(
		visual_terrain_id: StringName,
		theme_id: StringName = &"forest"
	) -> Dictionary:
	if visual_terrain_id == &"":
		return {
			"ok": false,
			"error": "visual_terrain_id_empty",
			"visual_terrain_id": visual_terrain_id,
			"theme_id": theme_id,
		}
	var definition := ArenaCatalogService.terrain(visual_terrain_id)
	if definition != null and definition.base_texture != null:
		return {
			"ok": true,
			"texture": definition.base_texture,
			"terrain_definition": definition,
			"surface_definition": null,
			"display_name": definition.display_name,
			"render_mode": &"tile_replacement",
			"visual_terrain_id": visual_terrain_id,
			"theme_id": theme_id,
		}
	var surface := ArenaCatalogService.surface_visual(visual_terrain_id)
	if surface == null:
		return {
			"ok": false,
			"error": "visual_not_in_catalog",
			"visual_terrain_id": visual_terrain_id,
			"theme_id": theme_id,
		}
	if surface.texture == null:
		return {
			"ok": false,
			"error": "surface_texture_missing",
			"visual_terrain_id": visual_terrain_id,
			"theme_id": theme_id,
			"surface_definition": surface,
		}
	return {
		"ok": true,
		"texture": surface.texture,
		"terrain_definition": null,
		"surface_definition": surface,
		"display_name": surface.display_name,
		"render_mode": &"tile_replacement",
		"visual_terrain_id": visual_terrain_id,
		"theme_id": theme_id,
	}
