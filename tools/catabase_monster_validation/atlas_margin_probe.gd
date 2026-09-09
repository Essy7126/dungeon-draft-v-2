extends SceneTree
## Independent GPU proof of cropped AtlasTexture placement; no production art.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 384)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var source := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.fill_rect(Rect2i(3, 4, 10, 12), Color.RED)
	var texture := AtlasTexture.new()
	texture.atlas = ImageTexture.create_from_image(source)
	texture.region = Rect2(3, 4, 10, 12)
	texture.margin = Rect2(219, 286, 502, 372)
	texture.filter_clip = true
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame(&"default", texture)
	sprite.centered = false
	sprite.offset = Vector2(-256, -320)
	sprite.position = Vector2(256, 320)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var expected := Image.create(512, 384, false, Image.FORMAT_RGBA8)
	# Color.TRANSPARENT is transparent white; the framebuffer clears to zero.
	expected.fill(Color(0, 0, 0, 0))
	expected.fill_rect(Rect2i(219, 286, 10, 12), Color.RED)
	var passed := rendered != null and rendered.get_size() == expected.get_size()
	var original_mipmaps := rendered.has_mipmaps() if rendered != null else false
	if passed:
		rendered.convert(Image.FORMAT_RGBA8)
		rendered.clear_mipmaps()
		passed = rendered.get_data() == expected.get_data()
	var report := {"passed": passed, "logical_size": str(texture.get_size()),
		"expected_pixel_rect": str(expected.get_used_rect()),
		"rendered_pixel_rect": str(rendered.get_used_rect()) if rendered != null else "missing",
		"renderer": RenderingServer.get_current_rendering_method(), "original_mipmaps": original_mipmaps,
		"rendered_bytes": rendered.get_data().size(), "expected_bytes": expected.get_data().size()}
	var output := "res://artifacts/catabase_monsters/atlas_margin_gpu"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if rendered != null:
		rendered.save_png(output.path_join("rendered.png"))
	expected.save_png(output.path_join("expected.png"))
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CATABASE_ATLAS_MARGIN_GPU=", JSON.stringify(report))
	viewport.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
