extends AudioStreamPlayer
## The title scene owns playback; settings never touch the expedition save.
signal selection_changed(index: int)
const Catalog := preload("res://core/audio/title_music_catalog.gd")
@export var settings_path := "user://title_music.cfg"
@export_range(0.0, 2.0) var fade_seconds := 0.8
var selected_index := 0
var level := 0.5
var envelope := 0.0:
	set(value):
		envelope = value
		_update_gain()
var _fade: Tween


func _ready() -> void:
	bus = &"Music"
	autoplay = false
	_load_preferences()
	select_track(selected_index, false)


func _load_preferences() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var id: Variant = config.get_value("music", "track", "passage")
	for index in Catalog.TRACKS.size():
		if id == Catalog.TRACKS[index].id:
			selected_index = index
			break
	var saved_level: Variant = config.get_value("music", "volume", 0.5)
	if (saved_level is float or saved_level is int) and is_finite(float(saved_level)):
		level = clampf(float(saved_level), 0.0, 1.0)


func save_preferences() -> Error:
	var config := ConfigFile.new()
	config.set_value("music", "track", Catalog.TRACKS[selected_index].id)
	config.set_value("music", "volume", level)
	return config.save(settings_path)


func select_track(index: int, persist: bool = true) -> void:
	selected_index = posmod(index, Catalog.TRACKS.size())
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if fade_seconds <= 0.0:
		_replace_stream(selected_index)
		envelope = 1.0
	else:
		_fade = create_tween()
		if playing:
			_fade.tween_property(self, "envelope", 0.0, fade_seconds * 0.25)
		_fade.tween_callback(_replace_stream.bind(selected_index))
		_fade.tween_property(self, "envelope", 1.0, fade_seconds * 0.75)
	selection_changed.emit(selected_index)
	if persist and save_preferences() != OK:
		push_warning("Le choix musical n’a pas pu être enregistré.")


func _replace_stream(index: int) -> void:
	stop()
	var original := load(Catalog.resource_path(index)) as AudioStreamOggVorbis
	if original == null:
		stream = null
		return
	var loop := original.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	stream = loop
	play()


func set_level(value: float, persist: bool = true) -> void:
	if not is_finite(value):
		return
	level = clampf(value, 0.0, 1.0)
	_update_gain()
	if persist and save_preferences() != OK:
		push_warning("Le volume musical n’a pas pu être enregistré.")


func _update_gain() -> void:
	volume_db = linear_to_db(maxf(0.0001, level * envelope))


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	stop()
	stream = null
