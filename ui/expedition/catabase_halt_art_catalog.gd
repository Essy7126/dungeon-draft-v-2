class_name CatabaseHaltArtCatalog
extends RefCounted
## Presentation only. Route IDs, transactions and save fingerprints stay authoritative.

const SOURCE_SIZE := Vector2(1920, 1200)
const TEXTURE_ROOT := "res://assets/catabase/painted/halts/"
const DESTINATIONS := {
	"camp_compagnons": {"title": "Le camp des compagnons", "kind": "hub"},
	"etal_passeur": {"title": "L'étal du passeur", "kind": "merchant"},
	"stele_noms": {"title": "La stèle des noms", "kind": "lore"},
	"autel_serments": {"title": "L'autel des serments", "kind": "sanctuary"},
	"forge_cuirasses": {"title": "La forge des cuirasses", "kind": "merchant"},
	"memoire_chiron": {"title": "La mémoire de Chiron", "kind": "lore"},
	"bibliotheque_engloutie": {"title": "La bibliothèque engloutie", "kind": "lore"},
	"bivouac_memoires": {"title": "Le bivouac des six mémoires", "kind": "hub"},
	"pacte_sixieme_geste": {"title": "Le pacte du sixième geste", "kind": "sanctuary"},
	"marche_dernier_feu": {"title": "Le marché du dernier feu", "kind": "merchant"},
	"foyer_revenants": {"title": "Le foyer des revenants", "kind": "hub"},
	"feu_avant_paris": {"title": "Le feu avant Pâris", "kind": "hub"},
	"ultime_offrande": {"title": "L'ultime offrande", "kind": "sanctuary"},
	"obole_dernier_passage": {"title": "L'obole du dernier passage", "kind": "merchant"},
	"atelier_sous_racine": {"title": "L'atelier sous la racine", "kind": "sanctuary"},
	"tombeau_serment_intact": {"title": "Le tombeau du serment intact", "kind": "lore"},
	"defi_serment_muet": {"title": "Le défi du serment muet", "kind": "sanctuary"},
}
const HALT_ANCHORS := {
	"buy": Vector2(0.22, 0.48),
	"rest": Vector2(0.50, 0.72),
	"lore": Vector2(0.79, 0.43),
	"branch": Vector2(0.78, 0.79),
	"wager": Vector2(0.78, 0.79),
}
const MERCHANT_BUY_ANCHORS := [Vector2(0.18, 0.46), Vector2(0.43, 0.40), Vector2(0.70, 0.46)]
const MERCHANT_ANCHORS := {"rest": Vector2(0.29, 0.78), "lore": Vector2(0.76, 0.80)}
## Measured on the approved paintings. Camp Y includes the source's central crop.
const DESTINATION_TARGETS := {
	"camp_compagnons": {
		"buy": Vector2(0.31, (0.44 * 1288.1 - 44.0) / 1200.0),
		"rest": Vector2(0.28, (0.72 * 1288.1 - 44.0) / 1200.0),
		"lore": Vector2(0.79, (0.46 * 1288.1 - 44.0) / 1200.0),
		"branch": Vector2(0.78, (0.74 * 1288.1 - 44.0) / 1200.0),
		"wager": Vector2(0.78, (0.74 * 1288.1 - 44.0) / 1200.0),
	},
	"bibliotheque_engloutie": {
		"buy": Vector2(0.15, 0.58), "lore": Vector2(0.33, 0.40),
		"rest": Vector2(0.43, 0.77), "branch": Vector2(0.70, 0.42),
		"wager": Vector2(0.70, 0.42),
	},
}
const DESTINATION_LABELS := {
	"camp_compagnons": {
		"buy": Vector2(0.31, 0.60), "rest": Vector2(0.28, 0.87),
		"lore": Vector2(0.79, 0.62), "branch": Vector2(0.78, 0.89),
		"wager": Vector2(0.78, 0.89),
	},
	"bibliotheque_engloutie": {
		"buy": Vector2(0.15, 0.72), "lore": Vector2(0.34, 0.55),
		"rest": Vector2(0.42, 0.90), "branch": Vector2(0.72, 0.64),
		"wager": Vector2(0.72, 0.64),
	},
}


static func all_keys() -> PackedStringArray:
	return PackedStringArray(DESTINATIONS.keys())


static func resolve_key(destination: Dictionary) -> String:
	# Safe previews must not disclose the resolved content behind an unknown node.
	var kind := str(destination.get("kind", ""))
	if str(destination.get("knowledge", "")) == "unknown" \
			or str(destination.get("presentation_kind", "")) == "unknown" \
			or (not kind.is_empty() and kind not in ["hub", "merchant", "sanctuary", "lore"]):
		return ""
	var explicit_key := str(destination.get("halt_art_key", ""))
	if DESTINATIONS.has(explicit_key):
		return explicit_key if kind.is_empty() or kind == DESTINATIONS[explicit_key].kind else ""
	var title := str(destination.get("title", ""))
	for key in DESTINATIONS:
		if title == str(DESTINATIONS[key].title) \
				and (kind.is_empty() or kind == str(DESTINATIONS[key].kind)):
			return str(key)
	return ""


static func texture_path(key: String) -> String:
	return TEXTURE_ROOT + key + ".png" if DESTINATIONS.has(key) else ""


static func load_texture(key: String) -> Texture2D:
	var path := texture_path(key)
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	return ResourceLoader.load(path, "Texture2D") as Texture2D


static func service_role(service_id: String) -> String:
	if service_id.begins_with("buy:"):
		return "buy"
	if service_id.begins_with("branch:"):
		return "branch"
	return service_id if service_id in ["rest", "lore", "wager"] else ""


static func service_anchor(service_id: String, merchant: bool, buy_index := 0, destination_key := "") -> Vector2:
	var role := service_role(service_id)
	if DESTINATION_TARGETS.has(destination_key) and DESTINATION_TARGETS[destination_key].has(role):
		return DESTINATION_TARGETS[destination_key][role]
	if merchant and role == "buy":
		return MERCHANT_BUY_ANCHORS[clampi(buy_index, 0, MERCHANT_BUY_ANCHORS.size() - 1)]
	if merchant and MERCHANT_ANCHORS.has(role):
		return MERCHANT_ANCHORS[role]
	return HALT_ANCHORS.get(role, Vector2(0.5, 0.5))


static func label_anchor(service_id: String, merchant: bool, buy_index := 0, destination_key := "") -> Vector2:
	var role := service_role(service_id)
	if DESTINATION_LABELS.has(destination_key) and DESTINATION_LABELS[destination_key].has(role):
		return DESTINATION_LABELS[destination_key][role]
	var target := service_anchor(service_id, merchant, buy_index, destination_key)
	return Vector2(target.x, minf(target.y + 0.12, 0.94))


static func fitted_rect(available_size: Vector2) -> Rect2:
	var fit_scale := maxf(0.0, minf(available_size.x / SOURCE_SIZE.x, available_size.y / SOURCE_SIZE.y))
	var fitted_size := SOURCE_SIZE * fit_scale
	return Rect2((available_size - fitted_size) * 0.5, fitted_size)
