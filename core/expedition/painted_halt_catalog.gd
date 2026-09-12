extends RefCounted
## Presentation bindings never modify route identities or the saved catalog.
const BINDINGS := "res://data/halts/route_bindings.json"


static func manifest_for(node: Dictionary) -> String:
	if (
		bool(node.get("hidden", false)) or int(node.get("lane", -1)) < 0
		or int(node.get("lane", -1)) > 2
	):
		return ""
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
