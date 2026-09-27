extends Node2D
var atlases: Dictionary = { }
var clips: Dictionary = { }
var textures: Dictionary = { }
var current_clip = ""
var current_frame = -1
var facing := "E":
	set(value):
		if facing != value:
			facing = value
			queue_redraw()
const Registration := preload("res://characters/achilles/2d/passe_rive_registration.gd")
const Directions := preload("res://characters/achilles/2d/passe_rive_s20_directions.gd")

const Data = preload("res://characters/achilles/2d/passe_rive_s19_data.gd")
const Effect = preload("res://vfx/class_cards/passe_rive_s19_effect.gd")
var card: Dictionary = { }
var action_time := 0.0
const Appearance := preload("res://characters/achilles/2d/passe_rive_appearance.gd")
var _palette_source := ""


func _ready():
	atlases = Data.REGIONS
	clips = Data.CLIPS
	textures = Data.BODY_TEXTURES
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = Appearance.material_for("PR_SHOT")


func show_frame(id: String, index: int):
	if current_clip != id or current_frame != index:
		current_clip = id
		current_frame = index
		queue_redraw()


func _rect(v: Array) -> Rect2:
	return Rect2(v[0], v[1], v[2], v[3])


func _subtract(rect: Rect2, cut: Rect2) -> Array:
	var hit = rect.intersection(cut)
	if not hit.has_area():
		return [rect]
	var parts = [
		Rect2(rect.position.x, rect.position.y, rect.size.x, hit.position.y - rect.position.y),
		Rect2(rect.position.x, hit.end.y, rect.size.x, rect.end.y - hit.end.y),
		Rect2(rect.position.x, hit.position.y, hit.position.x - rect.position.x, hit.size.y),
		Rect2(hit.end.x, hit.position.y, rect.end.x - hit.end.x, hit.size.y),
	]
	return parts.filter(
		func(p):
			return p.has_area(),
	)


func _draw():
	if not clips.has(current_clip) or current_frame < 0:
		return
	var spec: Dictionary = clips[current_clip]
	var pair: Array = (
		spec.sequence[current_frame]
		if spec.has("sequence")
		else [current_clip, current_frame]
	)
	var atlas: Dictionary = atlases[pair[0]]
	var texture: Texture2D = textures[pair[0]]
	var directional_source := Directions.source(pair[0], facing)
	if not directional_source.is_empty():
		atlas = Directions.Art.REGIONS[directional_source]
		texture = Directions.Art.TEXTURES[directional_source]
	var palette_source: String = str(pair[0]) if directional_source.is_empty() else directional_source
	if palette_source != _palette_source:
		_palette_source = palette_source
		Appearance.apply_palette(material as ShaderMaterial, palette_source)
	var frame: Dictionary = atlas.frames[Directions.pose_index(pair[0], facing, pair[1])]
	var registered_scale: float = atlas.scale * Registration.stance_scale(pair[0], facing)
	var layers: Array = [frame]
	layers.append_array(frame.get("effects", []))
	for layer in layers:
		var original = _rect(layer.rect)
		var parts = [original]
		for cut in layer.get("exclude", []):
			var next_parts = []
			for part in parts:
				next_parts.append_array(_subtract(part, _rect(cut)))
			parts = next_parts
		var pivot = Vector2(layer.pivot[0], layer.pivot[1])
		for part in parts:
			var target = Rect2(
				(part.position - original.position - pivot) * registered_scale,
				part.size * registered_scale,
			)
			draw_texture_rect_region(texture, target, part)

	# Only local weapon accents belong to the caster clock. Target accents are
	# spawned separately by the router after confirmed combat resolution.
	for track in card.get("tracks", []):
		if track.gate != "cast":
			continue
		var dt: float = action_time - track.start_ms
		if dt < 0.0 or dt >= track.duration:
			continue
		var factor := 330.0 / 270.0 * Registration.stance_scale(pair[0], facing)
		var axis := Directions.local_axis(facing)
		var offset := Vector2(track.offset[0] * axis.x, track.offset[1] + track.offset[0] * axis.y)
		Effect.draw_pose(
			self,
			track.asset,
			mini(7, int(dt / track.duration * 8)),
			offset * factor,
			track.size * factor,
			track.angle + axis.angle(),
		)
