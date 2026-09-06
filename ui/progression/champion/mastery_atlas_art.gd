class_name MasteryAtlasArt
extends RefCounted
## Original paintings indexed by authored gameplay IDs, without editing game rules.
## Generated from tools/mastery_atlas_art/manifest.json. Frames are cached and shared.

const VERSION := 2
const SHEETS := {
  &"wrath": {
    &"path": "res://asset/ui/progression/mastery_atlas/icons_v2/wrath_sheet.png",
    &"columns": 3,
    &"rows": 3,
    &"accent": "c99b70"
  },
  &"chiron": {
    &"path": "res://asset/ui/progression/mastery_atlas/icons_v2/chiron_sheet.png",
    &"columns": 3,
    &"rows": 3,
    &"accent": "a6b99a"
  },
  &"aeacus": {
    &"path": "res://asset/ui/progression/mastery_atlas/icons_v2/aeacus_sheet.png",
    &"columns": 3,
    &"rows": 3,
    &"accent": "8eafc5"
  },
  &"heroic": {
    &"path": "res://asset/ui/progression/mastery_atlas/icons_v2/heroic_sheet.png",
    &"columns": 3,
    &"rows": 3,
    &"accent": "d8bb79"
  },
  &"attributes": {
    &"path": "res://asset/ui/progression/mastery_atlas/icons_v2/attributes_sheet.png",
    &"columns": 2,
    &"rows": 2,
    &"accent": "c9b493"
  }
}
const NODE_REGIONS := {
  &"achilles_wrath_focused_fury": [
    "wrath",
    0,
    0
  ],
  &"achilles_wrath_opening_slash": [
    "wrath",
    1,
    0
  ],
  &"achilles_wrath_murderous_momentum": [
    "wrath",
    2,
    0
  ],
  &"achilles_wrath_execution": [
    "wrath",
    0,
    1
  ],
  &"achilles_wrath_blood_for_blood": [
    "wrath",
    1,
    1
  ],
  &"achilles_wrath_victorious_step": [
    "wrath",
    2,
    1
  ],
  &"achilles_wrath_break_formation": [
    "wrath",
    0,
    2
  ],
  &"achilles_wrath_scourge_of_troy": [
    "wrath",
    1,
    2
  ],
  &"achilles_wrath_irrepressible_wrath": [
    "wrath",
    2,
    2
  ],
  &"achilles_chiron_centaur_eye": [
    "chiron",
    0,
    0
  ],
  &"achilles_chiron_pelion_reach": [
    "chiron",
    1,
    0
  ],
  &"achilles_chiron_close_shot": [
    "chiron",
    2,
    0
  ],
  &"achilles_chiron_impossible_angle": [
    "chiron",
    0,
    1
  ],
  &"achilles_chiron_stopping_arrow": [
    "chiron",
    1,
    1
  ],
  &"achilles_chiron_piercing_arrow": [
    "chiron",
    2,
    1
  ],
  &"achilles_chiron_mobile_hunt": [
    "chiron",
    0,
    2
  ],
  &"achilles_chiron_death_line": [
    "chiron",
    1,
    2
  ],
  &"achilles_chiron_centaur_volley": [
    "chiron",
    2,
    2
  ],
  &"achilles_aeacus_active_guard": [
    "aeacus",
    0,
    0
  ],
  &"achilles_aeacus_directional_guard": [
    "aeacus",
    1,
    0
  ],
  &"achilles_aeacus_bronze_anchor": [
    "aeacus",
    2,
    0
  ],
  &"achilles_aeacus_riposte": [
    "aeacus",
    0,
    1
  ],
  &"achilles_aeacus_arrow_wall": [
    "aeacus",
    1,
    1
  ],
  &"achilles_aeacus_broken_shield": [
    "aeacus",
    2,
    1
  ],
  &"achilles_aeacus_mobile_bastion": [
    "aeacus",
    0,
    2
  ],
  &"achilles_aeacus_counter": [
    "aeacus",
    1,
    2
  ],
  &"achilles_aeacus_myrmidon_rampart": [
    "aeacus",
    2,
    2
  ],
  &"achilles_summit_wrath": [
    "heroic",
    0,
    0
  ],
  &"achilles_summit_chiron": [
    "heroic",
    1,
    0
  ],
  &"achilles_summit_aeacus": [
    "heroic",
    2,
    0
  ],
  &"achilles_junction_battlefield_predator": [
    "heroic",
    0,
    1
  ],
  &"achilles_junction_bronze_avenger": [
    "heroic",
    1,
    1
  ],
  &"achilles_junction_pelion_sentinel": [
    "heroic",
    2,
    1
  ],
  &"achilles_apotheosis_scourge_trojans": [
    "heroic",
    0,
    2
  ],
  &"achilles_apotheosis_fate_shot": [
    "heroic",
    1,
    2
  ],
  &"achilles_apotheosis_invincible_hero": [
    "heroic",
    2,
    2
  ]
}
const ATTRIBUTE_REGIONS := {
  &"vitality": [
    "attributes",
    0,
    0
  ],
  &"power": [
    "attributes",
    1,
    0
  ],
  &"resolve": [
    "attributes",
    0,
    1
  ],
  &"wisdom": [
    "attributes",
    1,
    1
  ]
}

static var _icons: Dictionary = {}


static func node_icon(node_id: StringName) -> Texture2D:
	return _icon(node_id, NODE_REGIONS)


static func attribute_icon(attribute_id: StringName) -> Texture2D:
	return _icon(attribute_id, ATTRIBUTE_REGIONS)


static func node_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(NODE_REGIONS.keys())
	return ids


static func attribute_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(ATTRIBUTE_REGIONS.keys())
	return ids


static func node_accent(node_id: StringName) -> Color:
	var region: Array = NODE_REGIONS.get(node_id, [])
	return Color(str(SHEETS[region[0]][&"accent"])) if not region.is_empty() else Color("c9b493")


static func _icon(id: StringName, regions: Dictionary) -> Texture2D:
	if not regions.has(id):
		return null
	if _icons.has(id):
		return _icons[id] as Texture2D
	var path := "res://asset/ui/progression/mastery_atlas/icons_v2/resources/%s.tres" % id
	# Keep the editor usable while an original painting is being imported.
	if not ResourceLoader.exists(path, "AtlasTexture"):
		return null
	var result := load(path) as AtlasTexture
	if result == null:
		return null
	_icons[id] = result
	return result
