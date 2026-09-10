class_name CatabasePaintedIconCatalog
extends RefCounted
## Compatibility facade: original glyphs first, archived paintings as fallback.
const GLYPHS := preload("res://ui/theme/catabase_icon_library.gd")

const ASSET_ROOT := "res://assets/catabase/painted"
const ICON_ROOT := ASSET_ROOT + "/icons"
const EQUIPMENT_ROOT := ASSET_ROOT + "/equipment"
const SPELL_FAMILIES := {
	"peleid_strike": ["achilles_peleid_strike", "exp_frappe_ouverte", "exp_tempest"],
	"fulminant_dash": ["achilles_fulminant_dash"],
	"pelion_shot": ["achilles_pelion_shot", "exp_tir_de_guet"],
	"bronze_guard": ["achilles_bronze_guard", "exp_garde_eaque"],
	"crochet": ["exp_crochet", "exp_crochet_mutation", "exp_crochet_legend"],
	"fauchage": ["exp_fauchage", "exp_fauchage_signature"],
	"entaille": ["exp_entaille", "exp_entaille_mutation", "exp_entaille_legend"],
	"moisson": ["exp_moisson", "exp_moisson_signature"],
	"rupture": ["exp_rupture", "exp_rupture_mutation", "exp_rupture_legend"],
	"marque": ["exp_marque", "exp_marque_signature"],
	"feinte": ["exp_feinte", "exp_feinte_mutation", "exp_feinte_legend"],
	"contretemps": ["exp_contretemps", "exp_contretemps_signature"],
	"heurt": ["exp_heurt", "exp_heurt_mutation", "exp_heurt_legend"],
	"posture": ["exp_posture", "exp_posture_signature"],
	"souffle": ["exp_souffle", "exp_souffle_mutation", "exp_souffle_legend"],
	"marche": ["exp_marche", "exp_marche_signature"],
	"braise": ["exp_braise", "exp_braise_mutation", "exp_braise_legend"],
	"givre": ["exp_givre", "exp_givre_signature"],
	"foudre": ["exp_foudre"],
	"serment_rempart": ["exp_serment_rempart"],
	"serment_brasier": ["exp_serment_brasier"],
}
const ITEM_IDS := [
	"catabase_levier", "catabase_lame_sang", "catabase_javeline", "catabase_xiphos_danse",
	"catabase_masse_airain", "catabase_fer_braise", "catabase_cuirasse", "catabase_lin_survivant",
	"catabase_sandales", "catabase_sceau_chasse", "catabase_prisme", "catabase_agrafe",
]
const STAT_IDS := ["force", "attack_power", "max_hp", "initiative", "max_mp", "esquive", "armure", "resist_magique", "heal_budget"]
const ROOT_EMBLEMS := {"colere.root": "colere", "chiron.root": "chiron", "eaque.root": "eaque"}
const EMBLEM_IDS := ["colere", "chiron", "eaque", "elements", "serment", "achilles"]
const ROUTE_IDS := ["normal", "elite", "boss", "hub", "merchant", "sanctuary", "lore", "event", "cache", "unknown", "hidden", "current"]


static func spell_family(spell_id: String) -> String:
	for family in SPELL_FAMILIES:
		if SPELL_FAMILIES[family].has(spell_id):
			return String(family)
	return ""


static func spell_candidate_paths(spell_id: String, directory: String = ICON_ROOT) -> Array[String]:
	var family := spell_family(spell_id)
	if family.is_empty():
		return []
	var paths: Array[String] = [directory.path_join(spell_id + ".png")]
	# Tempest needs its own circular silhouette; a thrust would misrepresent it.
	if spell_id != "exp_tempest":
		paths.append(directory.path_join(family + ".png"))
	return paths


static func item_candidate_paths(item_id: String, directory: String = EQUIPMENT_ROOT) -> Array[String]:
	if not ITEM_IDS.has(item_id):
		return []
	return [directory.path_join(item_id + ".png")]


static func node_candidate_paths(node: Dictionary, asset_root: String = ASSET_ROOT) -> Array[String]:
	var paths: Array[String] = []
	var node_id := String(node.get("id", ""))
	if ROOT_EMBLEMS.has(node_id):
		paths.append(asset_root.path_join("tree/emblems/" + String(ROOT_EMBLEMS[node_id]) + ".png"))
	var spell_id := String(node.get("spell_id", ""))
	if not spell_id.is_empty():
		paths.append_array(spell_candidate_paths(spell_id, asset_root.path_join("icons")))
	else:
		var stat: Variant = node.get("stat", [])
		if stat is Array and not stat.is_empty() and STAT_IDS.has(String(stat[0])):
			paths.append(asset_root.path_join("tree/stats/" + String(stat[0]) + ".png"))
	return paths


static func spell_icon(spell_id: String, fallback: Texture2D = null, directory: String = ICON_ROOT) -> Texture2D:
	return _first_texture(spell_candidate_paths(spell_id, directory), fallback)


static func item_icon(item_id: String, fallback: Texture2D = null, directory: String = EQUIPMENT_ROOT) -> Texture2D:
	return _first_texture(item_candidate_paths(item_id, directory), fallback)


static func node_icon(node: Dictionary, fallback: Texture2D = null, asset_root: String = ASSET_ROOT) -> Texture2D:
	return _first_texture(node_candidate_paths(node, asset_root), fallback)


static func stat_icon(stat_id: String, fallback: Texture2D = null, asset_root: String = ASSET_ROOT) -> Texture2D:
	return _named_icon(stat_id, STAT_IDS, "tree/stats", fallback, asset_root)


static func emblem_icon(emblem_id: String, fallback: Texture2D = null, asset_root: String = ASSET_ROOT) -> Texture2D:
	return _named_icon(emblem_id, EMBLEM_IDS, "tree/emblems", fallback, asset_root)


static func route_icon(kind: String, fallback: Texture2D = null, asset_root: String = ASSET_ROOT) -> Texture2D:
	return _named_icon(kind, ROUTE_IDS, "route", fallback, asset_root)


## Drawn map markers share the knowledge filter; inventory paintings stay separate.
static func map_icon(kind: String, fallback: Texture2D = null) -> Texture2D:
	if kind not in ROUTE_IDS:
		return fallback
	return GLYPHS.icon("route", kind, _first_texture(["res://assets/catabase/route_drawn/" + kind + ".svg"], fallback))


static func map_node_icon(node: Dictionary, fallback: Texture2D = null) -> Texture2D:
	return map_icon(route_presentation_kind(node), fallback)


static func route_presentation_kind(node: Dictionary) -> String:
	# Callers pass get_visible_nodes() entries. Never infer a concealed encounter
	# from its title, reward, room, or the underlying catalogue.
	if String(node.get("knowledge", "")) == "unknown" or String(node.get("kind", "")) == "unknown":
		return "unknown"
	var kind := String(node.get("presentation_kind", node.get("kind", "unknown")))
	return kind if ROUTE_IDS.has(kind) else "unknown"


static func route_node_icon(node: Dictionary, fallback: Texture2D = null, asset_root: String = ASSET_ROOT) -> Texture2D:
	return route_icon(route_presentation_kind(node), fallback, asset_root)


static func _named_icon(id: String, allowed: Array, folder: String, fallback: Texture2D, asset_root: String) -> Texture2D:
	if not allowed.has(id):
		return fallback
	return _first_texture([asset_root.path_join(folder).path_join(id + ".png")], fallback)


static func _first_texture(paths: Array[String], fallback: Texture2D) -> Texture2D:
	for path in paths:
		# Translate only the default art root. Custom/missing directories retain
		# their explicit fallback contract for tools and alternative presentations.
		if path.begins_with(ASSET_ROOT + "/"):
			var local := path.trim_prefix(ASSET_ROOT + "/")
			var folder := local.get_base_dir()
			var groups := {"icons": "spells", "equipment": "equipment", "tree/stats": "stats", "tree/emblems": "emblems", "route": "route"}
			if groups.has(folder):
				var glyph := GLYPHS.icon(String(groups[folder]), local.get_file().get_basename())
				if glyph != null:
					return glyph
		if not ResourceLoader.exists(path, "Texture2D"):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			return texture
	return fallback
