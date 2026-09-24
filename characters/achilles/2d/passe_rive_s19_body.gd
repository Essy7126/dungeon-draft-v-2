extends Node2D
var atlases: Dictionary = {}
var clips: Dictionary = {}
var textures: Dictionary = {}
var current_clip = ""
var current_frame = -1

const Data = preload("res://characters/achilles/2d/passe_rive_s19_data.gd")
const Effect = preload("res://vfx/class_cards/passe_rive_s19_effect.gd")
var card: Dictionary = {}
var action_time := 0.0

func _ready():
	atlases = Data.REGIONS
	clips = Data.CLIPS
	textures = Data.BODY_TEXTURES
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func show_frame(id: String, index: int):
	if current_clip != id or current_frame != index:
		current_clip = id
		current_frame = index
		queue_redraw()

func _rect(v: Array) -> Rect2:
	return Rect2(v[0], v[1], v[2], v[3])

func _subtract(rect: Rect2, cut: Rect2) -> Array:
	var hit = rect.intersection(cut)
	if not hit.has_area(): return [rect]
	var parts = [Rect2(rect.position.x, rect.position.y, rect.size.x, hit.position.y-rect.position.y), Rect2(rect.position.x, hit.end.y, rect.size.x, rect.end.y-hit.end.y), Rect2(rect.position.x, hit.position.y, hit.position.x-rect.position.x, hit.size.y), Rect2(hit.end.x, hit.position.y, rect.end.x-hit.end.x, hit.size.y)]
	return parts.filter(func(p): return p.has_area())

func _draw():
	if not clips.has(current_clip) or current_frame < 0: return
	var spec: Dictionary = clips[current_clip]
	var pair: Array = spec.sequence[current_frame] if spec.has("sequence") else [current_clip, current_frame]
	var atlas: Dictionary = atlases[pair[0]]
	var frame: Dictionary = atlas.frames[pair[1]]
	var layers: Array = [frame]
	layers.append_array(frame.get("effects", []))
	for layer in layers:
		var original = _rect(layer.rect)
		var parts = [original]
		for cut in layer.get("exclude", []):
			var next_parts = []
			for part in parts: next_parts.append_array(_subtract(part, _rect(cut)))
			parts = next_parts
		var pivot = Vector2(layer.pivot[0], layer.pivot[1])
		for part in parts:
			var target = Rect2((part.position-original.position-pivot)*atlas.scale, part.size*atlas.scale)
			draw_texture_rect_region(textures[pair[0]], target, part)

	# Only local weapon accents belong to the caster clock. Target accents are
	# spawned separately by the router after confirmed combat resolution.
	for track in card.get("tracks", []):
		if track.gate != "cast": continue
		var dt: float = action_time - track.start_ms
		if dt < 0.0 or dt >= track.duration: continue
		var factor := 330.0 / 270.0
		Effect.draw_pose(self, track.asset, mini(7, int(dt / track.duration * 8)), Vector2(track.offset[0], track.offset[1]) * factor, track.size * factor, track.angle)
