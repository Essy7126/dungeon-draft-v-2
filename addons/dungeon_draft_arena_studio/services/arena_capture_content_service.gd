@tool
class_name ArenaCaptureContentService
extends RefCounted

## Ecrit et inspecte les captures de validation sans jamais toucher a res://.
## Le flag render_ready et l'identite du document sont obligatoires : une image
## plausible mais issue du mauvais document reste donc bloquante.

const OUTPUT_ROOT := "user://arena_reliability"
const DEFAULT_MINIMUM_FILE_SIZE_BYTES := 256
const DEFAULT_MINIMUM_VARIANCE := 0.00005
const DEFAULT_MINIMUM_NON_BACKGROUND_RATIO := 0.005
const DEFAULT_MAXIMUM_BLACK_RATIO := 0.985
const DEFAULT_BACKGROUND_TOLERANCE := 0.035
const SAMPLE_BUDGET := 65536
const CANVAS_SAMPLE_BUDGET := 32768
const SIGNATURE_GRID_SIZE := 16


static func write_and_validate(
		image: Image,
		output_path: String,
		context: Dictionary
	) -> ArenaCaptureContentReport:
	var report := _new_report(output_path, context)
	_validate_context(report)
	if not _is_allowed_output(output_path):
		report.add_error("OUTPUT_OUTSIDE_USER_ROOT")
		return report.recompute()
	if not output_path.to_lower().ends_with(".png"):
		report.add_error("CAPTURE_FORMAT_NOT_PNG")
	if image == null or image.is_empty():
		report.add_error("CAPTURE_IMAGE_EMPTY")
		_write_report(report)
		return report.recompute()
	var absolute_directory := ProjectSettings.globalize_path(
		output_path.get_base_dir()
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		report.add_error("CAPTURE_DIRECTORY_CREATE_FAILED")
		return report.recompute()
	var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
	if save_error != OK:
		report.add_error("CAPTURE_SAVE_FAILED")
		_write_report(report)
		return report.recompute()
	_inspect_written_file(report, context)
	_write_report(report)
	return report.recompute()


static func inspect_file(
		input_path: String,
		context: Dictionary
	) -> ArenaCaptureContentReport:
	var report := _new_report(input_path, context)
	_validate_context(report)
	_inspect_written_file(report, context)
	var requested_report_path := str(context.get("report_path", ""))
	if not requested_report_path.is_empty():
		report.report_path = requested_report_path
	_write_report(report)
	return report.recompute()


static func visual_signature(image: Image) -> String:
	if image == null or image.is_empty():
		return ""
	var payload := "%dx%d|" % [image.get_width(), image.get_height()]
	for sample_y in range(SIGNATURE_GRID_SIZE):
		var y := clampi(
			floori((float(sample_y) + 0.5) * float(image.get_height()) \
				/ float(SIGNATURE_GRID_SIZE)),
			0,
			image.get_height() - 1
		)
		for sample_x in range(SIGNATURE_GRID_SIZE):
			var x := clampi(
				floori((float(sample_x) + 0.5) * float(image.get_width()) \
					/ float(SIGNATURE_GRID_SIZE)),
				0,
				image.get_width() - 1
			)
			var color := image.get_pixel(x, y)
			payload += "%d,%d,%d,%d;" % [
				clampi(roundi(color.r * 255.0), 0, 255),
				clampi(roundi(color.g * 255.0), 0, 255),
				clampi(roundi(color.b * 255.0), 0, 255),
				clampi(roundi(color.a * 255.0), 0, 255),
			]
	return payload.sha256_text()


static func _new_report(
		path: String,
		context: Dictionary
	) -> ArenaCaptureContentReport:
	var report := ArenaCaptureContentReport.new()
	report.output_path = path
	report.report_path = path.get_basename() + ".capture.json" \
		if _is_allowed_output(path) else ""
	report.render_ready = bool(context.get("render_ready", false))
	report.document_loaded = bool(context.get("document_loaded", false))
	report.document_id = str(context.get("document_id", ""))
	report.expected_document_id = str(context.get("expected_document_id", ""))
	report.document_fingerprint = str(context.get("document_fingerprint", ""))
	report.expected_document_fingerprint = str(
		context.get("expected_document_fingerprint", "")
	)
	report.expected_dimensions = _vector2i(
		context.get("expected_dimensions", Vector2i.ZERO)
	)
	report.canvas_rect = _rect2i(context.get("canvas_rect", Rect2i()))
	report.background_color = _color(
		context.get("background_color", Color.BLACK)
	)
	report.minimum_file_size_bytes = maxi(
		0,
		int(context.get(
			"minimum_file_size_bytes", DEFAULT_MINIMUM_FILE_SIZE_BYTES
		))
	)
	report.minimum_variance = maxf(
		0.0,
		float(context.get("minimum_variance", DEFAULT_MINIMUM_VARIANCE))
	)
	report.minimum_non_background_ratio = clampf(
		float(context.get(
			"minimum_non_background_ratio",
			DEFAULT_MINIMUM_NON_BACKGROUND_RATIO
		)),
		0.0,
		1.0
	)
	report.maximum_black_ratio = clampf(
		float(context.get("maximum_black_ratio", DEFAULT_MAXIMUM_BLACK_RATIO)),
		0.0,
		1.0
	)
	report.expected_visual_signature = str(
		context.get("expected_visual_signature", "")
	)
	return report


static func _validate_context(report: ArenaCaptureContentReport) -> void:
	if not report.render_ready:
		report.add_error("RENDER_NOT_READY")
	if not report.document_loaded:
		report.add_error("DOCUMENT_NOT_LOADED")
	if report.document_id.is_empty() or report.expected_document_id.is_empty():
		report.add_error("DOCUMENT_ID_MISSING")
	report.document_matches = not report.document_id.is_empty() \
		and report.document_id == report.expected_document_id
	if not report.document_matches:
		report.add_error("DOCUMENT_MISMATCH")
	if report.document_fingerprint.is_empty() \
			or report.expected_document_fingerprint.is_empty():
		report.add_error("DOCUMENT_FINGERPRINT_MISSING")
	report.fingerprint_matches = not report.document_fingerprint.is_empty() \
		and report.document_fingerprint == report.expected_document_fingerprint
	if not report.fingerprint_matches:
		report.add_error("DOCUMENT_FINGERPRINT_MISMATCH")
	if report.expected_dimensions.x <= 0 or report.expected_dimensions.y <= 0:
		report.add_error("EXPECTED_DIMENSIONS_MISSING")
	if report.expected_visual_signature.is_empty():
		report.add_error("EXPECTED_VISUAL_SIGNATURE_MISSING")


static func _inspect_written_file(
		report: ArenaCaptureContentReport,
		context: Dictionary
	) -> void:
	report.file_exists = FileAccess.file_exists(report.output_path)
	if not report.file_exists:
		report.add_error("CAPTURE_FILE_MISSING")
		return
	var file := FileAccess.open(report.output_path, FileAccess.READ)
	if file == null:
		report.add_error("CAPTURE_FILE_UNREADABLE")
		return
	report.file_size_bytes = file.get_length()
	file.close()
	report.file_sha256 = FileAccess.get_sha256(report.output_path)
	if report.file_size_bytes < report.minimum_file_size_bytes:
		report.add_error("CAPTURE_FILE_TOO_SMALL")
	if report.file_sha256.is_empty():
		report.add_error("CAPTURE_FILE_FINGERPRINT_MISSING")
	var image := Image.load_from_file(ProjectSettings.globalize_path(report.output_path))
	if image == null or image.is_empty():
		report.add_error("CAPTURE_LOAD_FAILED")
		return
	report.actual_dimensions = image.get_size()
	if report.actual_dimensions != report.expected_dimensions:
		report.add_error("CAPTURE_DIMENSIONS_MISMATCH")
	_analyze_content(report, image, context)


static func _analyze_content(
		report: ArenaCaptureContentReport,
		image: Image,
		context: Dictionary
	) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var stride := maxi(1, ceili(sqrt(
		float(width * height) / float(SAMPLE_BUDGET)
	)))
	var luminance_sum := 0.0
	var luminance_squared_sum := 0.0
	var black_count := 0
	var buckets: Dictionary = {}
	for y in range(0, height, stride):
		for x in range(0, width, stride):
			var color := image.get_pixel(x, y)
			var luminance := _visible_luminance(color)
			luminance_sum += luminance
			luminance_squared_sum += luminance * luminance
			if luminance <= 0.0125:
				black_count += 1
			buckets[_color_bucket(color)] = true
			report.sampled_pixels += 1
	if report.sampled_pixels <= 0:
		report.add_error("CAPTURE_HAS_NO_PIXELS")
		return
	var count := float(report.sampled_pixels)
	var average := luminance_sum / count
	report.pixel_variance = maxf(
		0.0, luminance_squared_sum / count - average * average
	)
	report.black_ratio = float(black_count) / count
	report.unique_color_buckets = buckets.size()
	report.uniform_frame = report.unique_color_buckets <= 1
	if report.pixel_variance < report.minimum_variance:
		report.add_error("CAPTURE_VARIANCE_TOO_LOW")
	if report.uniform_frame:
		report.add_error("CAPTURE_UNIFORM")
	if report.black_ratio > report.maximum_black_ratio:
		report.add_error("CAPTURE_BLACK")
	_analyze_canvas_content(report, image, context)
	report.visual_signature = visual_signature(image)
	if report.visual_signature.is_empty():
		report.add_error("VISUAL_SIGNATURE_MISSING")
	report.signature_matches = not report.expected_visual_signature.is_empty() \
		and report.visual_signature == report.expected_visual_signature
	if not report.expected_visual_signature.is_empty() \
			and not report.signature_matches:
		report.add_error("VISUAL_SIGNATURE_MISMATCH")


static func _analyze_canvas_content(
		report: ArenaCaptureContentReport,
		image: Image,
		context: Dictionary
	) -> void:
	var image_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var requested := report.canvas_rect
	if requested.size.x <= 0 or requested.size.y <= 0:
		requested = image_rect
	var canvas := requested.intersection(image_rect)
	report.canvas_rect = canvas
	if canvas.size.x <= 0 or canvas.size.y <= 0:
		report.add_error("CAPTURE_CANVAS_MISSING")
		return
	var tolerance := clampf(
		float(context.get("background_tolerance", DEFAULT_BACKGROUND_TOLERANCE)),
		0.0,
		2.0
	)
	var canvas_stride := maxi(1, ceili(sqrt(
		float(canvas.size.x * canvas.size.y) / float(CANVAS_SAMPLE_BUDGET)
	)))
	var sample_count := 0
	var content_count := 0
	for y in range(canvas.position.y, canvas.end.y, canvas_stride):
		for x in range(canvas.position.x, canvas.end.x, canvas_stride):
			var color := image.get_pixel(x, y)
			if _color_distance(color, report.background_color) > tolerance:
				content_count += 1
			sample_count += 1
	report.non_background_ratio = float(content_count) / float(maxi(sample_count, 1))
	if report.non_background_ratio < report.minimum_non_background_ratio:
		report.add_error("MAP_CONTENT_MISSING")


static func _write_report(report: ArenaCaptureContentReport) -> void:
	if report.report_path.is_empty() or not _is_allowed_output(report.report_path):
		return
	var absolute_directory := ProjectSettings.globalize_path(
		report.report_path.get_base_dir()
	)
	if DirAccess.make_dir_recursive_absolute(absolute_directory) != OK:
		report.add_error("REPORT_DIRECTORY_CREATE_FAILED")
		return
	report.report_written = true
	report.recompute()
	var file := FileAccess.open(report.report_path, FileAccess.WRITE)
	if file == null:
		report.report_written = false
		report.add_error("REPORT_WRITE_FAILED")
		return
	file.store_string(JSON.stringify(report.to_dict(), "  "))
	file.close()


static func _is_allowed_output(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	return normalized.begins_with(OUTPUT_ROOT + "/") \
		and not normalized.contains("/../") \
		and not normalized.ends_with("/..")


static func _visible_luminance(color: Color) -> float:
	return color.a * (0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b)


static func _color_bucket(color: Color) -> int:
	var red := clampi(floori(color.r * 31.999), 0, 31)
	var green := clampi(floori(color.g * 31.999), 0, 31)
	var blue := clampi(floori(color.b * 31.999), 0, 31)
	var alpha := clampi(floori(color.a * 15.999), 0, 15)
	return red | (green << 5) | (blue << 10) | (alpha << 15)


static func _color_distance(left: Color, right: Color) -> float:
	return maxf(
		maxf(absf(left.r - right.r), absf(left.g - right.g)),
		maxf(absf(left.b - right.b), absf(left.a - right.a))
	)


static func _vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value as Vector2i
	if value is Vector2:
		return Vector2i(value as Vector2)
	if value is Array and (value as Array).size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func _rect2i(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value as Rect2i
	if value is Rect2:
		return Rect2i(value as Rect2)
	return Rect2i()


static func _color(value: Variant) -> Color:
	if value is Color:
		return value as Color
	return Color.BLACK
