@tool
class_name ArenaCameraFramingService
extends RefCounted


static func painted_framing(
		visual_data: PaintedMapVisualData,
		viewport_size: Vector2,
		presentation_profile: BattlePresentationProfile = null
	) -> Dictionary:
	if visual_data == null:
		return {"ok": false, "error": "visual_data_missing"}
	var frame_rect := visual_data.image_rect()
	if frame_rect.size.x <= 0.0 or frame_rect.size.y <= 0.0 \
			or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return {"ok": false, "error": "invalid_frame"}
	var profile_offset := Vector2.ZERO
	var profile_zoom := 1.0
	if presentation_profile != null:
		profile_offset = presentation_profile.camera_offset_adjustment
		profile_zoom = presentation_profile.camera_zoom_multiplier
	var zoom_factor := maxf(
		viewport_size.x / frame_rect.size.x,
		viewport_size.y / frame_rect.size.y
	) * visual_data.camera_zoom * profile_zoom
	var frame_center := frame_rect.get_center()
	var camera_position := frame_center + visual_data.camera_offset + profile_offset
	if presentation_profile != null and presentation_profile.camera_keep_painting_in_view:
		var visible_size := viewport_size / zoom_factor
		var movement_room := (frame_rect.size - visible_size) * 0.5
		movement_room = Vector2(maxf(0.0, movement_room.x), maxf(0.0, movement_room.y))
		camera_position = Vector2(
			clampf(camera_position.x, frame_center.x - movement_room.x, frame_center.x + movement_room.x),
			clampf(camera_position.y, frame_center.y - movement_room.y, frame_center.y + movement_room.y)
		)
	return {
		"ok": true,
		"strategy": &"cover",
		"frame_rect": frame_rect,
		"position": camera_position,
		"zoom": Vector2(zoom_factor, zoom_factor),
		"profile_offset": profile_offset,
		"profile_zoom": profile_zoom,
	}
