extends RefCounted
## Presentation bindings never modify route identities or the saved catalog.
const BINDINGS := "res://data/halts/route_bindings.json"
const R6_BINDINGS := {
	"camp_compagnons": ["hub", "companions_quarry_v1"],
	"stele_noms": ["lore", "stele_names_v1"],
	"autel_serments": ["sanctuary", "emerald_sanctuary_v1"],
	"forge_cuirasses": ["merchant", "bronze_forge_v1"],
}


static func manifest_for(node: Dictionary) -> String:
	if (
		bool(node.get("hidden", false)) or int(node.get("lane", -1)) < 0
		or int(node.get("lane", -1)) > 2
	):
		return ""
	# r6 moves the authored places. Bind by their stable identity, not the
	# depth of the historical route; other halts keep their normal presentation.
	if int(node.get("balance_revision", 0)) >= 1:
		var key := str(node.get("halt_art_key", ""))
		if not R6_BINDINGS.has(key) or bool(node.get("preparation_only", false)):
			return ""
		var binding: Array = R6_BINDINGS[key]
		if str(node.get("kind", "")) != str(binding[0]):
			return ""
		var r6_path := "res://data/halts/%s.json" % str(binding[1])
		return r6_path if FileAccess.file_exists(r6_path) else ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BINDINGS))
	if not parsed is Dictionary:
		return ""
	for entry: Dictionary in parsed.get("bindings", []):
		if (
			int(node.get("depth", -1)) == int(entry.get("depth", -2))
			and str(node.get("kind", "")) == str(entry.get("kind", ""))
			and (not entry.has("title") or str(node.get("title", "")) == str(entry.title))
		):
			var path := str(entry.get("manifest", ""))
			return path if path.begins_with("res://data/halts/") and FileAccess.file_exists(path) else ""
	return ""
