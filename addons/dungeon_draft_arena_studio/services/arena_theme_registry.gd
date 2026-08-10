@tool
class_name ArenaThemeRegistry
extends RefCounted


static func resolve(arena: ArenaDefinition) -> Dictionary:
	if arena == null:
		return {
			"ok": false, "requested_theme_id": &"", "theme": null,
			"surface_configs": [], "warning": "arena_missing",
		}
	var requested := arena.theme_id
	if requested == &"" and arena.modular_visual_profile != null:
		requested = arena.modular_visual_profile.theme_id
	var definition := ArenaCatalogService.theme(requested)
	if definition == null:
		return {
			"ok": false,
			"requested_theme_id": requested,
			"resolved_theme_id": &"",
			"theme": null,
			"surface_configs": [],
			"fallback_used": false,
			"warning": "theme_without_surface_configuration:%s" % requested,
		}
	return {
		"ok": definition.validates().is_empty() and not definition.surface_configs.is_empty(),
		"requested_theme_id": requested,
		"resolved_theme_id": definition.stable_id,
		"theme": definition,
		"surface_configs": definition.surface_configs.duplicate(),
		"fallback_used": requested != definition.stable_id,
		"warning": "theme_alias:%s->%s" % [requested, definition.stable_id] \
			if requested != definition.stable_id else "",
	}
