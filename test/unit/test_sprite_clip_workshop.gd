extends GutTest

const Clips := preload("res://addons/dungeon_draft_arena_studio/services/sprite_clip_service.gd")
const Workshop := preload("res://tools/sprite_workshop/SpriteWorkshop.tscn")
const ROOT := Clips.TEST_ROOT + "contract/"
var source_path := ROOT + "source.png"
var document: Dictionary


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(2, 3, 3, 5), Color(0.2, 0.5, 0.8, 0.7))
	assert_eq(image.save_png(source_path), OK)


func before_each() -> void:
	var frame := {
		"id": "a",
		"source": source_path,
		"sha256": FileAccess.get_sha256(source_path),
		"region": [0, 0, 8, 12],
		"placement": [1, 1],
		"offset": [0, 0],
		"duration_ms": 80.0,
	}
	var second := frame.duplicate(true)
	second.id = "b"
	second.offset = [2, 0]
	second.duration_ms = 160.0
	document = {
		"schema_version": 1,
		"id": "contract",
		"animation": "attack_E",
		"title": "Contract",
		"intent": "Test",
		"direction": "E",
		"canvas": [16, 16],
		"anchor": [8, 13],
		"display_scale": 0.35,
		"frames": [frame, second],
		"events": [{ "name": "release", "frame": "b" }],
		"playback": { "mode": "once" },
		"provenance": { },
		"review": { },
	}
	document.baseline = {
		"frames": document.frames.duplicate(true),
		"events": document.events.duplicate(true),
		"playback": { "mode": "once" },
		"anchor": [8, 13],
		"display_scale": 0.35,
	}


func test_new_clip_from_pngs_needs_no_preexisting_game_resource() -> void:
	var created := Clips.new_clip([source_path, source_path], source_path, "attack_E")
	assert_true(created.ok, str(created))
	if not created.ok:
		return
	assert_eq(created.document.frames.size(), 2)
	assert_eq(created.document.canvas, [16, 16])
	assert_eq(created.document.reference.source, source_path)
	assert_false(Clips.review_current(created.document))
	assert_false(Clips.new_clip([], source_path, "attack_E").ok)
	assert_false(Clips.new_clip([source_path], "", "attack_E").ok)


func test_atlas_margin_restores_logical_pixels_without_rescaling() -> void:
	var source := Image.load_from_file(source_path)
	var texture := ImageTexture.create_from_image(source)
	# Source metadata mirrors a trimmed AtlasTexture (margin is not in get_image()).
	var frame: Dictionary = document.frames[0]
	frame.region = [2, 3, 3, 5]
	frame.placement = [4, 6]
	var restored := Clips.frame_image(frame, document.canvas, { })
	assert_eq(restored.get_size(), Vector2i(16, 16))
	assert_eq(restored.get_used_rect(), Rect2i(4, 6, 3, 5))
	assert_eq(restored.get_pixel(4, 6), texture.get_image().get_pixel(2, 3))
	assert_eq(restored.get_pixel(3, 6).a, 0.0)


func test_export_preserves_pixels_durations_and_source_files() -> void:
	var before := FileAccess.get_sha256(source_path)
	var result := Clips.export_clip(document, ROOT)
	assert_true(result.ok, str(result))
	if not result.ok:
		return
	assert_true(result.pixel_roundtrip)
	assert_false(result.runtime_integration_verified)
	var editable_png := Image.load_from_file(
		ProjectSettings.globalize_path(result.directory.path_join("frames/000.png"))
	)
	assert_eq(
		editable_png.get_data(),
		Clips.frame_image(document.frames[0], document.canvas, { }).get_data(),
	)
	var sprites := ResourceLoader.load(
		result.sprite_frames,
		"SpriteFrames",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as SpriteFrames
	assert_not_null(sprites)
	assert_eq(sprites.get_animation_names(), PackedStringArray(["attack_E"]))
	assert_eq(sprites.get_frame_count("attack_E"), 2)
	assert_almost_eq(
		sprites.get_frame_duration("attack_E", 1) / sprites.get_animation_speed("attack_E"),
		0.16,
		0.000001,
	)
	assert_eq(FileAccess.get_sha256(source_path), before)
	var atlas_hash := FileAccess.get_sha256(result.directory.path_join("atlas.png"))
	var resource_hash := FileAccess.get_sha256(result.sprite_frames)
	var repeated := Clips.export_clip(document, ROOT)
	assert_true(repeated.ok)
	assert_eq(repeated.directory, result.directory)
	assert_eq(FileAccess.get_sha256(repeated.directory.path_join("atlas.png")), atlas_hash)
	assert_eq(
		FileAccess.get_sha256(repeated.sprite_frames),
		resource_hash,
		"Rebuild of unchanged inputs is deterministic",
	)


func test_clipped_drawing_is_rejected_before_export() -> void:
	document.frames[0].offset = [20, 0]
	assert_false(Clips.validate(document).ok)
	assert_false(Clips.export_clip(document, ROOT).ok)


func test_source_hash_and_source_resource_drift_are_blocking() -> void:
	document.frames[0].sha256 = "old"
	assert_false(Clips.validate(document).ok)
	document.frames[0].sha256 = FileAccess.get_sha256(source_path)
	document.provenance[source_path] = "old"
	assert_false(Clips.validate(document).ok)


func test_rejects_invalid_manifest_values_without_crashing() -> void:
	for change in [
		{ "schema_version": 2 },
		{ "frames": "wrong" },
		{ "canvas": [0, 100] },
		{ "anchor": [-1, 0] },
		{ "display_scale": "0.35" },
		{ "baseline": { } },
		{ "events": [{ "name": "release", "frame": "missing" }] },
	]:
		var candidate := document.duplicate(true)
		candidate.merge(change, true)
		assert_false(Clips.validate(candidate).ok, str(change))
	document.frames[0].duration_ms = 0
	assert_false(Clips.validate(document).ok)


func test_review_expires_after_pixel_timing_or_order_edit() -> void:
	assert_false(Clips.review_current(document))
	assert_false(Clips.approve_visual(document, "", "").ok)
	assert_true(Clips.approve_visual(document, "test", "observations de test").ok)
	assert_true(Clips.review_current(document))
	assert_true(Clips.write_json(ROOT + "approved.json", document).ok)
	assert_true(
		Clips.review_current(Clips.read_document(ROOT + "approved.json").document),
		"Saving and reopening preserves the review",
	)
	var approved := document.duplicate(true)
	document.frames[0].duration_ms += 1
	assert_false(Clips.review_current(document))
	document = approved.duplicate(true)
	document.frames.reverse()
	assert_false(Clips.review_current(document))
	document = approved.duplicate(true)
	document.frames[0].offset[0] += 1
	assert_false(Clips.review_current(document))


func test_event_stays_on_its_drawing_when_order_changes() -> void:
	assert_eq(Clips.event_times(document)[0].preview_ms, 80.0)
	document.frames.reverse()
	assert_true(Clips.validate(document).ok)
	assert_eq(Clips.event_times(document)[0].preview_ms, 0.0)
	document.events.append({ "name": "release", "frame": "a" })
	assert_false(Clips.validate(document).ok)


func test_sampling_respects_unequal_durations_and_loop_boundary() -> void:
	assert_eq(Clips.sample(document, 79.9), 0)
	assert_eq(Clips.sample(document, 80), 1)
	assert_eq(Clips.sample(document, 1000), 1)
	document.playback.mode = "loop"
	assert_eq(Clips.sample(document, 240), 0)
	assert_eq(Clips.sample(document, 321), 1)


func test_arrival_does_not_turn_into_fixed_frame_playback() -> void:
	var imported := Clips.read_document(Clips.SOURCE_ROOT + "achille_dash_e.json")
	assert_true(imported.ok)
	if not imported.ok:
		return
	var dash: Dictionary = imported.document
	assert_eq(Clips.sample(dash, 49), 0)
	assert_eq(Clips.sample(dash, 50), 1)
	assert_eq(Clips.sample(dash, 100), 2)
	assert_eq(Clips.sample(dash, 799, 800), 2)
	assert_eq(Clips.sample(dash, 800, 800), 3)
	assert_eq(Clips.duration(dash, 800), 880.0)
	dash.playback.arrival_preview_ms = 50
	assert_false(Clips.validate(dash).ok)


func test_save_and_export_never_target_production_assets() -> void:
	assert_false(Clips.write_json("res://data/visuals/forbidden.json", document).ok)
	assert_false(Clips.write_json(Clips.SOURCE_ROOT + "../forbidden.json", document).ok)
	assert_false(Clips.export_clip(document, "res://assets/").ok)
	assert_true(Clips.write_json(ROOT + "saved.json", document).ok)
	assert_true(
		Clips.write_json(ROOT + "saved.json", document).ok,
		"Repeated saves replace atomically",
	)
	assert_eq(
		Clips.fingerprint(Clips.read_document(ROOT + "saved.json").document),
		Clips.fingerprint(document),
	)


func test_real_trimmed_monster_import_preserves_canvas_and_runtime_timing() -> void:
	var imported := Clips.import_clip(
		"res://assets/characters/catabase_monsters/sentinelle_airain/sprite_frames.tres",
		"attack_E",
	)
	assert_true(imported.ok, str(imported))
	if not imported.ok:
		return
	assert_true(Clips.validate(imported.document).ok)
	assert_eq(imported.document.frames.size(), 8)
	assert_eq(imported.document.canvas, [512, 384])
	assert_almost_eq(Clips.duration(imported.document), 800.0, 0.001)
	assert_true(
		imported.document.frames[0].placement != [0, 0],
		"Trimmed margins must survive import",
	)
	var result := Clips.export_clip(imported.document, ROOT)
	assert_true(result.ok, str(result))


func test_editor_changes_are_undoable_and_original_is_preserved() -> void:
	var previous_title := get_window().title
	var previous_min_size := get_window().min_size
	var previous_auto_quit := get_tree().auto_accept_quit
	assert_true(Clips.write_json(ROOT + "ui.json", document).ok)
	var workshop := Workshop.instantiate()
	add_child_autofree(workshop)
	workshop.load_clip(ROOT + "ui.json")
	var original: Dictionary = workshop.document.baseline.duplicate(true)
	workshop.select_frame(0)
	workshop.duration_input.value = 120
	assert_eq(workshop.document.frames[0].duration_ms, 120.0)
	assert_true(workshop.dirty())
	workshop.undo_edit()
	assert_eq(workshop.document.frames[0].duration_ms, 80.0)
	workshop.redo_edit()
	assert_eq(workshop.document.frames[0].duration_ms, 120.0)
	workshop.move_frame(1)
	assert_eq(workshop.document.frames[1].id, "a")
	assert_eq(workshop.document.baseline, original)
	workshop.save_clip()
	assert_false(workshop.dirty())
	assert_eq(Clips.read_document(ROOT + "ui.json").document.frames[1].id, "a")
	workshop.file_action = "replace"
	workshop.file_selected(source_path)
	assert_eq(workshop.document.frames[1].region, [0, 0, 16, 16])
	assert_eq(workshop.document.baseline, original)
	workshop.undo_edit()
	assert_eq(workshop.document.frames[1].region, [0.0, 0.0, 8.0, 12.0])
	get_window().title = previous_title
	get_window().min_size = previous_min_size
	get_tree().auto_accept_quit = previous_auto_quit
