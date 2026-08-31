class_name IntroCinematic
extends Control

signal exit_started(skipped: bool)
signal sequence_completed(sequence_id: StringName, skipped: bool)
signal run_start_requested(run_data: RunData, hero_sources: Array)
signal cinematic_failed(reason: String)

const SILENCE_DB := -40.0
const BASE_RESOLUTION := Vector2(1920.0, 1080.0)
const MAX_KEN_BURNS_TRAVEL_AT_1080P := 7.0
const TRANSLATION_PATHS := [
	"res://cinematics/intro/localization/intro_subtitles.fr.tres",
	"res://cinematics/catabase/localization/catabase_intro.fr.tres",
]
const SERIF_FONT := preload(
	"res://asset/ui/dungeon_draft/fonts/LobsterTwo-Regular.ttf"
)
const SERIF_BOLD_FONT := preload(
	"res://asset/ui/dungeon_draft/fonts/LobsterTwo-Bold.ttf"
)

@export var default_sequence: CinematicSequenceData = null
@export var autoplay := true
@export_file("*.tres") var skip_sfx_path := ""
@export_file("*.tscn") var fallback_scene_path := "res://ui/TitreEcran.tscn"

@onready var illustration_frame: PanelContainer = $IllustrationFrame
@onready var image_a: TextureRect = $IllustrationFrame/ImageA
@onready var image_b: TextureRect = $IllustrationFrame/ImageB
@onready var text_layer: Control = $TextLayer
@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var subtitle: RichTextLabel = $SubtitlePanel/Subtitle
@onready var black_fade: ColorRect = $BlackFade
@onready var skip_button: Button = $SkipButton
@onready var voice_player: AudioStreamPlayer = $VoicePlayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var run_manager_override: Node = null
var sequence_override: CinematicSequenceData = null
var sequence: CinematicSequenceData = null
var completion_committed := false
var run_start_committed := false
var _exit_requested := false
var _last_exit_was_skip := false
var _clock_started_msec := 0
var _last_clock_time := 0.0
var _current_frame_index := -1
var _cue_labels: Array[RichTextLabel] = []
var _opening_tween: Tween = null
var _exit_tween: Tween = null
var _warned_missing_music := false


func _ready() -> void:
	_install_translations()
	sequence = _resolve_sequence()
	if not _validate_sequence_for_playback():
		set_process(false)
		return
	_build_text_labels()
	_configure_for_sequence()
	_update_responsive_layout()
	if not get_viewport().size_changed.is_connected(_update_responsive_layout):
		get_viewport().size_changed.connect(_update_responsive_layout)
	if not skip_button.pressed.is_connected(request_skip):
		skip_button.pressed.connect(request_skip)
	if autoplay:
		_begin_playback()
	else:
		black_fade.color.a = 0.0
		set_process(false)
		synchronize_to_time(0.0)


func _process(_delta: float) -> void:
	if _exit_requested or sequence == null:
		return
	var sampled_time := float(Time.get_ticks_msec() - _clock_started_msec) / 1000.0
	_last_clock_time = maxf(_last_clock_time, maxf(0.0, sampled_time))
	synchronize_to_time(_last_clock_time)
	_update_music_volume(_last_clock_time)
	if _last_clock_time >= sequence.duration_seconds:
		finish_cinematic()


func _exit_tree() -> void:
	_kill_tweens()
	_stop_audio()


func _unhandled_input(event: InputEvent) -> void:
	if _exit_requested or sequence == null or not sequence.allow_skip:
		return
	if not _is_skip_input(event):
		return
	get_viewport().set_input_as_handled()
	request_skip()


func set_sequence_override(value: CinematicSequenceData) -> void:
	sequence_override = value


func _resolve_sequence() -> CinematicSequenceData:
	if sequence_override != null:
		return sequence_override
	var manager := _get_run_manager()
	if manager != null and manager.has_method("peek_next_run_data"):
		var configured_run = manager.call("peek_next_run_data")
		if configured_run is RunData:
			var run_data := configured_run as RunData
			if run_data.intro_sequence != null:
				return run_data.intro_sequence
	return default_sequence


func _validate_sequence_for_playback() -> bool:
	if sequence == null:
		_fail_and_return("Aucune sequence configuree.")
		return false
	var errors := sequence.validation_errors()
	if not errors.is_empty():
		_fail_and_return(
			"Sequence %s invalide : %s" % [sequence.sequence_id, "; ".join(errors)]
		)
		return false
	return true


func _configure_for_sequence() -> void:
	completion_committed = false
	run_start_committed = false
	_exit_requested = false
	_last_exit_was_skip = false
	_last_clock_time = 0.0
	_current_frame_index = -1
	skip_button.visible = sequence.allow_skip
	skip_button.disabled = not sequence.allow_skip
	subtitle_panel.visible = false
	music_player.volume_db = SILENCE_DB
	voice_player.volume_db = sequence.narration_volume_db
	synchronize_to_time(0.0)


func _begin_playback() -> void:
	if sequence == null or _exit_requested:
		return
	_clock_started_msec = Time.get_ticks_msec()
	_last_clock_time = 0.0
	_play_optional_music()
	_play_optional_narration()
	black_fade.color.a = 1.0
	if sequence.opening_fade_seconds <= 0.0:
		black_fade.color.a = 0.0
	else:
		_opening_tween = create_tween()
		_opening_tween.tween_property(
			black_fade, "color:a", 0.0, sequence.opening_fade_seconds
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	set_process(true)


func _play_optional_music() -> void:
	if sequence.music_stream == null:
		if not _warned_missing_music:
			push_warning(
				"Cinématique %s : musique optionnelle absente, lecture silencieuse."
				% sequence.sequence_id
			)
			_warned_missing_music = true
		return
	music_player.stream = sequence.music_stream
	music_player.bus = &"Music"
	music_player.volume_db = SILENCE_DB
	music_player.play()
	if not music_player.playing:
		push_warning(
			"Cinématique %s : la musique n'a pas pu démarrer."
			% sequence.sequence_id
		)


func _play_optional_narration() -> void:
	if sequence.narration_stream == null:
		return
	voice_player.stream = sequence.narration_stream
	voice_player.bus = &"Voice"
	voice_player.volume_db = sequence.narration_volume_db
	voice_player.play()


func _update_music_volume(time_seconds: float) -> void:
	if not music_player.playing:
		return
	var volume := sequence.music_volume_db
	if sequence.music_fade_in_seconds > 0.0 \
			and time_seconds < sequence.music_fade_in_seconds:
		volume = lerpf(
			SILENCE_DB,
			sequence.music_volume_db,
			clampf(time_seconds / sequence.music_fade_in_seconds, 0.0, 1.0),
		)
	if time_seconds >= sequence.music_fade_out_start_seconds:
		var fade_out_progress := 1.0
		if sequence.music_fade_out_seconds > 0.0:
			fade_out_progress = clampf(
				(time_seconds - sequence.music_fade_out_start_seconds)
				/ sequence.music_fade_out_seconds,
				0.0,
				1.0,
			)
		volume = lerpf(sequence.music_volume_db, SILENCE_DB, fade_out_progress)
	music_player.volume_db = volume


## Met le rendu en coherence avec une heure absolue. L'horloge de lecture ne
## recule jamais ; cet entry point sert aussi aux captures QA determinees.
func synchronize_to_time(time_seconds: float) -> void:
	if sequence == null:
		return
	var monotonic_time := maxf(_last_clock_time, maxf(0.0, time_seconds))
	_last_clock_time = minf(monotonic_time, sequence.duration_seconds)
	_update_frames(_last_clock_time)
	_update_text_cues(_last_clock_time)
	if not is_processing():
		_update_music_volume(_last_clock_time)


func _update_frames(time_seconds: float) -> void:
	var frame_index := _find_frame_index(time_seconds)
	if frame_index < 0:
		return
	_current_frame_index = frame_index
	var frame := sequence.frames[frame_index]
	var previous_frame: CinematicFrameData = null
	if frame_index > 0:
		previous_frame = sequence.frames[frame_index - 1]
	image_a.texture = frame.texture
	image_b.texture = previous_frame.texture if previous_frame != null else null
	var blend := 1.0
	if previous_frame != null \
			and frame.transition_mode == CinematicFrameData.TransitionMode.CROSSFADE:
		blend = clampf(
			(time_seconds - frame.start_time_seconds)
			/ maxf(0.001, frame.transition_duration_seconds),
			0.0,
			1.0,
		)
	image_a.modulate.a = blend
	image_b.modulate.a = 1.0 - blend if previous_frame != null else 0.0
	_update_ken_burns(image_a, frame, time_seconds)
	if previous_frame != null:
		_update_ken_burns(image_b, previous_frame, time_seconds)


func _find_frame_index(time_seconds: float) -> int:
	for index in range(sequence.frames.size() - 1, -1, -1):
		if time_seconds >= sequence.frames[index].start_time_seconds:
			return index
	return 0 if not sequence.frames.is_empty() else -1


func _update_ken_burns(
		image: TextureRect,
		frame: CinematicFrameData,
		time_seconds: float,
	) -> void:
	image.pivot_offset = image.size * 0.5
	if not frame.ken_burns_enabled:
		image.scale = Vector2.ONE
		image.position = Vector2.ZERO
		return
	var duration := maxf(0.001, frame.end_time_seconds - frame.start_time_seconds)
	var progress := clampf(
		(time_seconds - frame.start_time_seconds) / duration, 0.0, 1.0
	)
	var eased := smoothstep(0.0, 1.0, progress)
	var zoom := lerpf(frame.start_zoom, frame.end_zoom, eased)
	var viewport_scale := maxf(0.5, get_viewport_rect().size.y / BASE_RESOLUTION.y)
	var travel := MAX_KEN_BURNS_TRAVEL_AT_1080P * viewport_scale
	image.scale = Vector2.ONE * zoom
	image.position = frame.ken_burns_direction * lerpf(-travel * 0.5, travel * 0.5, eased)


func _build_text_labels() -> void:
	for child in text_layer.get_children():
		child.queue_free()
	_cue_labels.clear()
	for cue in sequence.text_cues:
		var label := RichTextLabel.new()
		label.name = "Cue_%03d" % (_cue_labels.size() + 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.bbcode_enabled = true
		label.fit_content = false
		label.scroll_active = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.z_index = cue.layer
		label.visible = false
		text_layer.add_child(label)
		_cue_labels.append(label)
		_apply_cue_style(label, cue.style_id)
		label.text = "[center]%s[/center]" % _translated_cue_text(cue)


func _translated_cue_text(cue: CinematicTextCueData) -> String:
	if cue.localization_key == &"":
		return cue.fallback_text
	var translated := tr(cue.localization_key)
	if translated == String(cue.localization_key):
		return cue.fallback_text
	return translated


func _update_text_cues(time_seconds: float) -> void:
	for index in range(sequence.text_cues.size()):
		var cue := sequence.text_cues[index]
		var label := _cue_labels[index]
		var active := time_seconds >= cue.start_time_seconds \
			and time_seconds <= cue.end_time_seconds
		label.visible = active
		if not active:
			continue
		var alpha := 1.0
		if cue.fade_in_seconds > 0.0:
			alpha = minf(
				alpha,
				clampf(
					(time_seconds - cue.start_time_seconds) / cue.fade_in_seconds,
					0.0,
					1.0,
				),
			)
		if cue.fade_out_seconds > 0.0:
			alpha = minf(
				alpha,
				clampf(
					(cue.end_time_seconds - time_seconds) / cue.fade_out_seconds,
					0.0,
					1.0,
				),
			)
		label.modulate.a = alpha


func _apply_cue_style(label: RichTextLabel, style_id: StringName) -> void:
	var style := _style_definition(style_id)
	label.add_theme_font_override(
		"normal_font", SERIF_BOLD_FONT if style.bold else SERIF_FONT
	)
	label.add_theme_font_override("bold_font", SERIF_BOLD_FONT)
	label.add_theme_color_override("default_color", style.color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.84))
	label.add_theme_constant_override("outline_size", int(style.outline))
	label.add_theme_constant_override("line_separation", 4)
	if style.background:
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.0, 0.0, 0.0, 0.48)
		background.corner_radius_top_left = 6
		background.corner_radius_top_right = 6
		background.corner_radius_bottom_left = 6
		background.corner_radius_bottom_right = 6
		background.content_margin_left = 18.0
		background.content_margin_right = 18.0
		background.content_margin_top = 8.0
		background.content_margin_bottom = 8.0
		label.add_theme_stylebox_override("normal", background)


func _style_definition(style_id: StringName) -> Dictionary:
	var gold := Color("d8b56a")
	var ivory := Color("f5eee2")
	match style_id:
		&"context_title":
			return {"size": 78, "color": gold, "bold": true, "outline": 2, "background": false}
		&"context_line":
			return {"size": 45, "color": Color("f1e8d8"), "bold": false, "outline": 2, "background": false}
		&"context_strong":
			return {"size": 53, "color": gold, "bold": true, "outline": 2, "background": false}
		&"narrative":
			return {"size": 50, "color": ivory, "bold": false, "outline": 2, "background": true}
		&"narrative_small":
			return {"size": 45, "color": ivory, "bold": false, "outline": 2, "background": true}
		&"key":
			return {"size": 60, "color": gold, "bold": true, "outline": 3, "background": true}
		&"passions":
			return {"size": 48, "color": gold, "bold": true, "outline": 3, "background": true}
		&"paris":
			return {"size": 90, "color": gold, "bold": true, "outline": 4, "background": false}
		&"main_title":
			return {"size": 118, "color": gold, "bold": true, "outline": 4, "background": false}
		&"subtitle":
			return {"size": 48, "color": Color("f1e8d8"), "bold": false, "outline": 3, "background": false}
		&"legacy_subtitle":
			return {"size": 50, "color": ivory, "bold": false, "outline": 2, "background": true}
		_:
			return {"size": 50, "color": ivory, "bold": false, "outline": 2, "background": true}


func _update_responsive_layout() -> void:
	if sequence == null:
		return
	var viewport_size := get_viewport_rect().size
	var scale_factor := minf(
		viewport_size.x / BASE_RESOLUTION.x, viewport_size.y / BASE_RESOLUTION.y
	)
	for index in range(sequence.text_cues.size()):
		var cue := sequence.text_cues[index]
		var label := _cue_labels[index]
		var style := _style_definition(cue.style_id)
		var font_size := maxi(18, roundi(float(style.size) * scale_factor))
		label.add_theme_font_size_override("normal_font_size", font_size)
		label.add_theme_font_size_override("bold_font_size", font_size)
		var width := viewport_size.x * 0.84
		var height := maxf(viewport_size.y * 0.12, float(font_size) * 2.8)
		if cue.style_id in [&"main_title", &"paris", &"context_title"]:
			height = maxf(height, float(font_size) * 1.8)
		var center := cue.normalized_position * viewport_size
		var safe_margin := Vector2(viewport_size.x * 0.05, viewport_size.y * 0.04)
		var top_left := center - Vector2(width, height) * 0.5
		top_left.x = clampf(
			top_left.x, safe_margin.x, viewport_size.x - safe_margin.x - width
		)
		top_left.y = clampf(
			top_left.y, safe_margin.y, viewport_size.y - safe_margin.y - height
		)
		label.position = top_left
		label.size = Vector2(width, height)
	for image in [image_a, image_b]:
		image.pivot_offset = image.size * 0.5


func _is_skip_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [
			KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER,
		]
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index in [
			JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START,
		]
	return false


func request_skip() -> void:
	if sequence == null or not sequence.allow_skip:
		return
	_play_optional_skip_sfx()
	_begin_exit(true)


func finish_cinematic() -> void:
	_begin_exit(false)


func _begin_exit(skipped: bool) -> void:
	if completion_committed or _exit_requested or sequence == null:
		return
	completion_committed = true
	_exit_requested = true
	_last_exit_was_skip = skipped
	set_process(false)
	skip_button.disabled = true
	skip_button.visible = false
	exit_started.emit(skipped)
	_kill_tweens()
	var fade_duration := 0.25 if skipped else sequence.exit_fade_seconds
	if fade_duration <= 0.0:
		black_fade.color.a = 1.0
		music_player.volume_db = SILENCE_DB
		voice_player.volume_db = SILENCE_DB
	else:
		_exit_tween = create_tween().set_parallel(true)
		_exit_tween.tween_property(
			black_fade, "color:a", 1.0, fade_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if music_player.playing:
			_exit_tween.tween_property(
				music_player, "volume_db", SILENCE_DB, fade_duration
			)
		if voice_player.playing:
			_exit_tween.tween_property(
				voice_player, "volume_db", SILENCE_DB, fade_duration
			)
		await _exit_tween.finished
	_stop_audio()
	_execute_continuation()


func _execute_continuation() -> void:
	sequence_completed.emit(sequence.sequence_id, _last_exit_was_skip)
	if sequence.continuation == CinematicSequenceData.Continuation.RETURN_TO_CALLER:
		return
	var manager := _get_run_manager()
	if manager == null or not manager.has_method("start_configured_run"):
		_fail_and_return("GameManager.start_configured_run() indisponible.")
		return
	var configured_run: RunData = null
	if manager.has_method("peek_next_run_data"):
		configured_run = manager.call("peek_next_run_data") as RunData
	if not bool(manager.call("start_configured_run")):
		_fail_and_return("La configuration de run a deja ete consommee ou est invalide.")
		return
	run_start_committed = true
	run_start_requested.emit(configured_run, [])


func _kill_tweens() -> void:
	for tween in [_opening_tween, _exit_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_opening_tween = null
	_exit_tween = null


func _stop_audio() -> void:
	if is_instance_valid(voice_player):
		voice_player.stop()
	if is_instance_valid(music_player):
		music_player.stop()


func _play_optional_skip_sfx() -> void:
	if skip_sfx_path.is_empty() or not ResourceLoader.exists(skip_sfx_path):
		return
	var stream := load(skip_sfx_path) as AudioStream
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


func _install_translations() -> void:
	for path in TRANSLATION_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var translation := load(path) as Translation
		if translation != null:
			TranslationServer.add_translation(translation)


func _get_run_manager() -> Node:
	if is_instance_valid(run_manager_override):
		return run_manager_override
	return get_node_or_null("/root/GameManager")


func _fail_and_return(reason: String) -> void:
	push_error("Cinématique d’introduction : %s" % reason)
	cinematic_failed.emit(reason)
	if fallback_scene_path.is_empty() or not ResourceLoader.exists(fallback_scene_path):
		return
	if is_inside_tree() and autoplay:
		get_tree().change_scene_to_file.call_deferred(fallback_scene_path)


func get_current_plan_index() -> int:
	return _current_frame_index


func get_loaded_illustration_count() -> int:
	if sequence == null:
		return 0
	return sequence.frames.filter(
		func(frame: CinematicFrameData): return frame != null and frame.texture != null
	).size()


func get_active_texts() -> PackedStringArray:
	var result := PackedStringArray()
	for label in _cue_labels:
		if label.visible:
			result.append(label.get_parsed_text())
	return result


func is_exit_requested() -> bool:
	return _exit_requested


func has_started_run() -> bool:
	return run_start_committed
