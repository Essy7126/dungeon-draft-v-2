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
	return {
		"ok": true,
		"strategy": &"cover",
		"frame_rect": frame_rect,
		"position": frame_rect.get_center() + visual_data.camera_offset + profile_offset,
		"zoom": Vector2(zoom_factor, zoom_factor),
		"profile_offset": profile_offset,
		"profile_zoom": profile_zoom,
	}
