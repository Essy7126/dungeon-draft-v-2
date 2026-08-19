@tool
class_name ArenaCaptureContentReport
extends RefCounted

## Resultat type de l'inspection d'une capture. Le rapport conserve a la fois
## la provenance du document et des mesures de contenu independantes du rendu.

var ok := false
var output_path := ""
var report_path := ""
var report_written := false
var render_ready := false
var document_loaded := false
var document_id := ""
var expected_document_id := ""
var document_matches := false
var document_fingerprint := ""
var expected_document_fingerprint := ""
var fingerprint_matches := false
var expected_dimensions := Vector2i.ZERO
var actual_dimensions := Vector2i.ZERO
var canvas_rect := Rect2i()
var background_color := Color.BLACK
var minimum_file_size_bytes := 0
var minimum_variance := 0.0
var minimum_non_background_ratio := 0.0
var maximum_black_ratio := 1.0
var file_exists := false
var file_size_bytes := 0
var file_sha256 := ""
var sampled_pixels := 0
var pixel_variance := 0.0
var black_ratio := 1.0
var non_background_ratio := 0.0
var unique_color_buckets := 0
var uniform_frame := true
var visual_signature := ""
var expected_visual_signature := ""
var signature_matches := false
var errors: Array[String] = []
var warnings: Array[String] = []


func add_error(code: String) -> void:
	if not errors.has(code):
		errors.append(code)
	ok = false


func add_warning(code: String) -> void:
	if not warnings.has(code):
		warnings.append(code)


func has_error(code: String) -> bool:
	return errors.has(code)


func recompute() -> ArenaCaptureContentReport:
	ok = errors.is_empty()
	return self


func to_dict() -> Dictionary:
	return {
		"ok": ok,
		"output_path": output_path,
		"report_path": report_path,
		"report_written": report_written,
		"render_ready": render_ready,
		"document_loaded": document_loaded,
		"document_id": document_id,
		"expected_document_id": expected_document_id,
		"document_matches": document_matches,
		"document_fingerprint": document_fingerprint,
		"expected_document_fingerprint": expected_document_fingerprint,
		"fingerprint_matches": fingerprint_matches,
		"expected_dimensions": [expected_dimensions.x, expected_dimensions.y],
		"actual_dimensions": [actual_dimensions.x, actual_dimensions.y],
		"canvas_rect": {
			"x": canvas_rect.position.x,
			"y": canvas_rect.position.y,
			"width": canvas_rect.size.x,
			"height": canvas_rect.size.y,
		},
		"background_color": [
			background_color.r, background_color.g,
			background_color.b, background_color.a,
		],
		"minimum_file_size_bytes": minimum_file_size_bytes,
		"minimum_variance": minimum_variance,
		"minimum_non_background_ratio": minimum_non_background_ratio,
		"maximum_black_ratio": maximum_black_ratio,
		"file_exists": file_exists,
		"file_size_bytes": file_size_bytes,
		"file_sha256": file_sha256,
		"sampled_pixels": sampled_pixels,
		"pixel_variance": pixel_variance,
		"black_ratio": black_ratio,
		"non_background_ratio": non_background_ratio,
		"unique_color_buckets": unique_color_buckets,
		"uniform_frame": uniform_frame,
		"visual_signature": visual_signature,
		"expected_visual_signature": expected_visual_signature,
		"signature_matches": signature_matches,
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
	}
