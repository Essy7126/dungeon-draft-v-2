extends GutTest

const OUTPUT_DIR := "user://arena_reliability/unit/capture_content"
const DOCUMENT_ID := "synthetic:arena_capture_content"
const DOCUMENT_FINGERPRINT := (
	"4d9a36c1e5f0782b8c14d630a7f19e42c5b8d31f0a6e9274d3c1b5f8092e7a64"
)
const DIMENSIONS := Vector2i(64, 48)


func test_valid_capture_writes_png_report_metrics_and_signature() -> void:
	var image := _valid_image()
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("valid.png"), _context(image)
	)
	assert_true(report.ok, JSON.stringify(report.to_dict()))
	assert_true(report.file_exists)
	assert_true(report.report_written)
	assert_true(FileAccess.file_exists(report.output_path))
	assert_true(FileAccess.file_exists(report.report_path))
	var serialized = JSON.parse_string(FileAccess.get_file_as_string(report.report_path))
	assert_true(serialized is Dictionary)
	assert_eq(serialized.visual_signature, report.visual_signature)
	assert_eq(serialized.document_fingerprint, DOCUMENT_FINGERPRINT)
	assert_eq(report.actual_dimensions, DIMENSIONS)
	assert_gt(report.file_size_bytes, 0)
	assert_eq(report.file_sha256.length(), 64)
	assert_gt(report.pixel_variance, 0.0)
	assert_gt(report.non_background_ratio, 0.05)
	assert_gt(report.unique_color_buckets, 1)
	assert_false(report.uniform_frame)
	assert_eq(report.visual_signature.length(), 64)
	assert_true(report.document_matches)
	assert_true(report.fingerprint_matches)


func test_expected_visual_signature_is_exact_and_detects_a_changed_frame() -> void:
	var image := _valid_image()
	var expected := ArenaCaptureContentService.visual_signature(image)
	var matching_context := _context(image)
	matching_context.expected_visual_signature = expected
	var matching := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("signature_match.png"), matching_context
	)
	assert_true(matching.ok, JSON.stringify(matching.to_dict()))
	assert_true(matching.signature_matches)
	var altered := image.duplicate()
	altered.fill_rect(Rect2i(0, 0, 24, 24), Color("f4458d"))
	var mismatch := ArenaCaptureContentService.write_and_validate(
		altered, OUTPUT_DIR.path_join("signature_mismatch.png"), matching_context
	)
	assert_false(mismatch.ok)
	assert_true(mismatch.has_error("VISUAL_SIGNATURE_MISMATCH"))


func test_black_capture_is_rejected_even_when_file_and_dimensions_are_valid() -> void:
	var image := Image.create(DIMENSIONS.x, DIMENSIONS.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("black.png"), _context(image)
	)
	assert_false(report.ok)
	assert_true(report.has_error("CAPTURE_BLACK"))
	assert_true(report.has_error("CAPTURE_UNIFORM"))
	assert_true(report.has_error("CAPTURE_VARIANCE_TOO_LOW"))


func test_uniform_non_black_capture_is_rejected() -> void:
	var image := Image.create(DIMENSIONS.x, DIMENSIONS.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("5b7692"))
	var context := _context(image)
	context.background_color = Color("5b7692")
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("uniform.png"), context
	)
	assert_false(report.ok)
	assert_true(report.has_error("CAPTURE_UNIFORM"))
	assert_true(report.has_error("CAPTURE_VARIANCE_TOO_LOW"))


func test_activity_outside_canvas_does_not_hide_an_absent_map() -> void:
	var background := Color("28323c")
	var image := Image.create(DIMENSIONS.x, DIMENSIONS.y, false, Image.FORMAT_RGBA8)
	image.fill(background)
	image.fill_rect(Rect2i(0, 0, DIMENSIONS.x, 6), Color("f2b84b"))
	image.fill_rect(Rect2i(0, DIMENSIONS.y - 6, DIMENSIONS.x, 6), Color("4aa7e8"))
	var context := _context(image)
	context.background_color = background
	context.canvas_rect = Rect2i(12, 10, 40, 28)
	context.minimum_non_background_ratio = 0.05
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("map_absent.png"), context
	)
	assert_false(report.ok, JSON.stringify(report.to_dict()))
	assert_true(report.has_error("MAP_CONTENT_MISSING"))
	assert_gt(report.pixel_variance, 0.0)
	assert_gt(report.unique_color_buckets, 1)


func test_missing_file_is_never_accepted() -> void:
	var missing := OUTPUT_DIR.path_join(
		"missing_%d.png" % Time.get_ticks_usec()
	)
	var report := ArenaCaptureContentService.inspect_file(
		missing, _context(_valid_image())
	)
	assert_false(report.ok)
	assert_true(report.has_error("CAPTURE_FILE_MISSING"))
	assert_false(report.file_exists)
	assert_true(report.report_written)


func test_wrong_dimensions_and_insufficient_file_size_are_blocking() -> void:
	var image := _valid_image()
	var context := _context(image)
	context.expected_dimensions = Vector2i(DIMENSIONS.x + 1, DIMENSIONS.y)
	context.minimum_file_size_bytes = 10_000_000
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("wrong_dimensions.png"), context
	)
	assert_false(report.ok)
	assert_true(report.has_error("CAPTURE_DIMENSIONS_MISMATCH"))
	assert_true(report.has_error("CAPTURE_FILE_TOO_SMALL"))


func test_render_document_and_fingerprint_contracts_are_explicit() -> void:
	var image := _valid_image()
	var context := _context(image)
	context.render_ready = false
	context.document_id = "wrong:document"
	context.document_fingerprint = "wrong_fingerprint"
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("wrong_context.png"), context
	)
	assert_false(report.ok)
	assert_true(report.has_error("RENDER_NOT_READY"))
	assert_true(report.has_error("DOCUMENT_MISMATCH"))
	assert_true(report.has_error("DOCUMENT_FINGERPRINT_MISMATCH"))


func test_expected_visual_signature_is_mandatory() -> void:
	var image := _valid_image()
	var context := _context(image)
	context.erase("expected_visual_signature")
	var report := ArenaCaptureContentService.write_and_validate(
		image, OUTPUT_DIR.path_join("signature_missing.png"), context
	)
	assert_false(report.ok)
	assert_true(report.has_error("EXPECTED_VISUAL_SIGNATURE_MISSING"))


func test_capture_service_refuses_every_res_output_path() -> void:
	var image := _valid_image()
	var forbidden := "res://arena_capture_content_forbidden.png"
	var report := ArenaCaptureContentService.write_and_validate(
		image, forbidden, _context(image)
	)
	assert_false(report.ok)
	assert_true(report.has_error("OUTPUT_OUTSIDE_USER_ROOT"))
	assert_false(FileAccess.file_exists(forbidden))


func _context(image: Image) -> Dictionary:
	return {
		"render_ready": true,
		"document_loaded": true,
		"document_id": DOCUMENT_ID,
		"expected_document_id": DOCUMENT_ID,
		"document_fingerprint": DOCUMENT_FINGERPRINT,
		"expected_document_fingerprint": DOCUMENT_FINGERPRINT,
		"expected_dimensions": DIMENSIONS,
		"canvas_rect": Rect2i(8, 8, 48, 32),
		"background_color": Color("101820"),
		"minimum_file_size_bytes": 64,
		"minimum_variance": 0.00005,
		"minimum_non_background_ratio": 0.05,
		"expected_visual_signature": (
			ArenaCaptureContentService.visual_signature(image)
		),
	}


func _valid_image() -> Image:
	var image := Image.create(DIMENSIONS.x, DIMENSIONS.y, false, Image.FORMAT_RGBA8)
	image.fill(Color("101820"))
	image.fill_rect(Rect2i(8, 8, 24, 32), Color("2f9f73"))
	image.fill_rect(Rect2i(32, 8, 24, 16), Color("d29a3a"))
	image.fill_rect(Rect2i(32, 24, 24, 16), Color("5c83d5"))
	return image
