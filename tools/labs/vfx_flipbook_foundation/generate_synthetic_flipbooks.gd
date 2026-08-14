extends SceneTree

const OUTPUT_ROOT := "res://vfx/assets/flipbooks/test"
const MANIFEST_PATH := "res://vfx/manifests/test/synthetic_flipbook_foundation.json"
const COLUMNS := 8
const ROWS := 4
const FRAME_COUNT := 32
const FPS := 30.0
const FRAME_SIZES := {"low": 16, "medium": 32, "high": 64}
const VARIANTS := {
	"variant_a": [Color(0.15, 0.65, 1.0, 1.0), Color(0.75, 0.95, 1.0, 1.0)],
	"variant_b": [Color(1.0, 0.28, 0.72, 1.0), Color(1.0, 0.86, 0.25, 1.0)],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MANIFEST_PATH.get_base_dir()))
	var manifest_variants: Array = []
	var checksums := {}
	for variant_id in VARIANTS:
		var descriptor := {"variant_id": variant_id}
		for quality in FRAME_SIZES:
			var frame_size: int = FRAME_SIZES[quality]
			var path := OUTPUT_ROOT.path_join("%s_%s.png" % [variant_id, quality])
			var image := _make_atlas(variant_id, frame_size)
			var error := image.save_png(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error("SYNTHETIC_FLIPBOOK_SAVE_FAILED %s %s" % [path, error_string(error)])
				quit(1)
				return
			descriptor["texture_%s" % quality] = path
			descriptor["frame_size_%s" % quality] = frame_size
			checksums[path] = FileAccess.get_sha256(path)
		manifest_variants.append(descriptor)
	var manifest := {
		"schema_version": 1,
		"asset_id": "synthetic.flipbook.foundation",
		"source_tool": "SYNTHETIC_TEST_GENERATOR",
		"columns": COLUMNS,
		"rows": ROWS,
		"frame_count": FRAME_COUNT,
		"frames_per_second": FPS,
		"loop": false,
		"playback_mode": "FIT_MODULE_DURATION",
		"blend_mode": "ADD",
		"alpha_mode": "STRAIGHT",
		"pivot_normalized": [0.5, 0.75],
		"nominal_size_in_cells": [1.0, 1.0],
		"art_status": "TECHNICAL_PLACEHOLDER",
		"license_status": "INTERNAL_TEST",
		"variants": manifest_variants,
		"generator_checksum": FileAccess.get_sha256(get_script().resource_path),
		"texture_checksums": checksums,
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SYNTHETIC_FLIPBOOK_MANIFEST_WRITE_FAILED")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print("SYNTHETIC_FLIPBOOK_GENERATED atlas_count=6 manifest=%s" % MANIFEST_PATH)
	quit(0)


func _make_atlas(variant_id: String, frame_size: int) -> Image:
	var image := Image.create(COLUMNS * frame_size, ROWS * frame_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors: Array = VARIANTS[variant_id]
	for frame in FRAME_COUNT:
		var cell_x := (frame % COLUMNS) * frame_size
		var cell_y := (frame / COLUMNS) * frame_size
		var ratio := float(frame) / float(FRAME_COUNT - 1)
		var center := Vector2(
			cell_x + frame_size * (0.28 + 0.44 * ratio),
			cell_y + frame_size * (0.58 - 0.18 * sin(ratio * TAU)),
		)
		var radius := frame_size * (0.10 + 0.28 * sin(ratio * PI))
		for y in range(cell_y, cell_y + frame_size):
			for x in range(cell_x, cell_x + frame_size):
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
				if distance <= radius:
					var edge := clampf(1.0 - distance / maxf(radius, 0.5), 0.0, 1.0)
					var color: Color = colors[0].lerp(colors[1], ratio)
					color.a = clampf(edge * 1.4, 0.0, 1.0)
					image.set_pixel(x, y, color)
				elif absf(distance - radius * 1.35) <= maxf(0.7, frame_size / 48.0):
					var rim: Color = colors[1]
					rim.a = 0.52 * (1.0 - ratio * 0.35)
					image.set_pixel(x, y, rim)
		var marker_count := 1 if variant_id == "variant_a" else 2
		var marker_size := maxi(1, frame_size / 16)
		for marker in marker_count:
			for my in marker_size:
				for mx in marker_size:
					image.set_pixel(cell_x + 1 + marker * (marker_size + 1) + mx, cell_y + 1 + my, colors[1])
	return image
