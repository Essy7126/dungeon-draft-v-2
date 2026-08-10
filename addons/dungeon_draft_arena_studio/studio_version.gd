@tool
class_name StudioVersion
extends RefCounted

## Autorité unique de version produit. Les versions de schéma métier restent
## définies par leurs domaines et ne sont jamais dérivées de cette constante.

const PRODUCT_VERSION := "2.0.0"
const PRODUCT_NAME := "Dungeon Draft Studio"
const GENERATED_BY := "dungeon_draft_studio_2_0_0"
const STATUS := &"WORKTREE_CANDIDATE"


static func display_name(compact := false) -> String:
	return "DD STUDIO %s" % PRODUCT_VERSION if compact \
		else "%s %s" % [PRODUCT_NAME.to_upper(), PRODUCT_VERSION]


static func metadata(context := "") -> Dictionary:
	return {
		"studio_product_version": PRODUCT_VERSION,
		"generated_by": GENERATED_BY,
		"status": str(STATUS),
		"context": context,
		"godot_version": Engine.get_version_info().get("string", "unknown"),
		"generated_at": Time.get_datetime_string_from_system(true),
	}
