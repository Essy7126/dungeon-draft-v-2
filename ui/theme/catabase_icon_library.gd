extends RefCounted
## Painted icons for equipment, spells and UI; the map keeps its original symbols.
const ROOT := "res://assets/catabase/emerald_icons_v2/"
const MAP_ROOT := "res://assets/catabase/icons/"
const GROUPS := [
	"spells",
	"equipment",
	"stats",
	"nav",
	"resources",
	"emblems",
	"route",
	"states",
	"effects",
	"masteries",
	"attributes",
]
static var _cache: Dictionary = { }


static func icon(group: String, id: String, fallback: Texture2D = null) -> Texture2D:
	if group not in GROUPS or id.is_empty() or not id.is_valid_identifier():
		return fallback
	var path := (MAP_ROOT if group == "route" else ROOT) + group + "/" + id + (
		".svg" if group == "route" else ".png"
	)
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path, "Texture2D"):
		return fallback
	var texture := load(path) as Texture2D
	if texture != null:
		_cache[path] = texture
	return texture if texture != null else fallback
