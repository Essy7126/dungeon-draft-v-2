extends "res://vfx/class_cards/class_card_vfx_player.gd"
## Original straight-alpha drawings. Contact clocks start on the resolved hit.
const Art := preload("res://characters/achilles/2d/passe_rive_s19_data.gd")
var card: Dictionary = {}
var art_scale := 0.5


func configure(entry: Dictionary, world_point: Vector2, display_width: float, unit_anchor: Node2D = null, hold := false) -> void:
	recipe = entry.duplicate(true)
	card = Art.CARDS[entry.s19_card]
	point = world_point
	width = display_width
	anchor = unit_anchor
	persistent = hold
	status_slot = int(entry.get("status_slot", 0))
	status_count = int(entry.get("status_count", 1))
	badge_mode = hold or entry.get("feedback_phase", "") == "expire"
	# Width is the grid's cell width (not the standalone preview's canvas).
	art_scale = clampf(width / 180.0, 0.25, 1.25)
	duration = 0.38
	for track in card.tracks:
		if track.gate == "confirmed":
			duration = maxf(duration, (track.start_ms - card.confirm_ms + track.duration) / 1000.0)
	if badge_mode:
		duration = 0.3
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 40
	sample(0.0)


func sample(seconds: float) -> void:
	elapsed = maxf(seconds, 0.0)
	global_position = anchor.global_position if badge_mode and is_instance_valid(anchor) else point
	queue_redraw()


func _draw() -> void:
	if closed:
		return
	if badge_mode:
		# Use the same compact state rail as the other class effects.
		if status_slot >= 6:
			return
		var offset := Vector2((status_slot - (mini(status_count, 6) - 1) * 0.5) * 24.0, -badge_height)
		var fade := 1.0 if persistent else 1.0 - clampf(elapsed / duration, 0.0, 1.0)
		draw_pose(self, "mark", 7, offset, 38.0, 0.0, fade)
		return
	for track in card.tracks:
		if track.gate != "confirmed":
			continue
		var dt: float = elapsed * 1000.0 - (track.start_ms - card.confirm_ms)
		if dt < 0.0 or dt >= track.duration:
			continue
		var offset := Vector2(float(track.offset[0]) * art_scale, -55.0)
		var angle := float(track.angle)
		# Radial fire/volley/seal stay upright. Pierce/slash follow the shot axis.
		if track.asset in ["pierce", "slash"] and origin.is_finite():
			angle += (point + offset - origin).angle()
		draw_pose(self, track.asset, mini(7, int(dt / track.duration * 8)), offset, float(track.size) * art_scale, angle)


static func draw_pose(owner: Node2D, asset: String, frame: int, at: Vector2, size: float, angle: float, alpha := 1.0) -> void:
	var atlas: Dictionary = Art.VFX[asset]
	var pose: Dictionary = atlas.frames[frame]
	var factor: float = size / atlas.cell_width
	owner.draw_set_transform(at, angle)
	owner.draw_texture_rect_region(Art.VFX_TEXTURES[asset], Rect2(-Vector2(pose.pivot[0], pose.pivot[1]) * factor, Vector2(pose.rect[2], pose.rect[3]) * factor), Rect2(pose.rect[0], pose.rect[1], pose.rect[2], pose.rect[3]), Color(1, 1, 1, alpha))
	owner.draw_set_transform(Vector2.ZERO)
