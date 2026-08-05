class_name IntroCinematic
extends Control

signal exit_started(skipped: bool)
signal run_start_requested(run_data: RunData, hero_sources: Array)
signal cinematic_failed(reason: String)

const CINEMATIC_DURATION := 94.46
const CROSSFADE_DURATION := 0.9
const MUSIC_SILENCE_DB := -40.0
const MAX_KEN_BURNS_ZOOM := 1.04
const MAX_KEN_BURNS_TRAVEL_AT_1080P := 7.0

const TRANSLATION_PATH := \
	"res://cinematics/intro/localization/intro_subtitles.fr.tres"

const PLAN_START_TIMES := [
	0.0,
	13.0,
	25.0,
	34.0,
	42.0,
	51.0,
	59.0,
	67.0,
	84.0,
]

const SUBTITLE_KEYS := [
	"INTRO_SUBTITLE_01",
	"INTRO_SUBTITLE_02",
	"INTRO_SUBTITLE_03",
	"INTRO_SUBTITLE_04",
	"INTRO_SUBTITLE_05",
	"INTRO_SUBTITLE_06",
	"INTRO_SUBTITLE_07",
	"INTRO_SUBTITLE_08",
	"INTRO_SUBTITLE_09",
]

const SUBTITLE_FALLBACKS := [
	"Au-delà des royaumes connus s’élève une montagne qui défie les cieux.",
	"À son sommet repose un donjon ancien, gardien d’un pouvoir oublié.",
	"Ceux qui l’ont affronté n’en rapportent que des souvenirs brisés.",
	"Et dans son ombre, quelque chose s’éveille.",
	"Pourtant, trois voyageurs ont répondu à l’appel.",
	"L’Elfe, le Mage et le Guerrier ont juré d’atteindre le sommet.",
	"Au cœur de la montagne, l’aube attend encore d’être libérée.",
	"Mais l’ascension transforme tous ceux qui osent la tenter.",
	"L’Archiviste ouvre la voie. Leur histoire commence ici.",
]

const KEN_BURNS_DIRECTIONS := [
	Vector2(0.8, -0.25),
	Vector2(-0.65, 0.2),
	Vector2(0.45, 0.35),
	Vector2(-0.75, -0.15),
	Vector2(0.15, -0.35),
	Vector2(0.7, 0.2),
	Vector2(-0.35, 0.25),
	Vector2(0.6, -0.2),
	Vector2(-0.5, -0.15),
]

@export var illustration_paths: Array[String] = [
	"res://cinematics/intro/atlas/intro_01_legende.tres",
	"res://cinematics/intro/atlas/intro_02_montagne.tres",
	"res://cinematics/intro/atlas/intro_03_souvenirs.tres",
	"res://cinematics/intro/atlas/intro_04_ombre.tres",
	"res://cinematics/intro/atlas/intro_05_voyageurs.tres",
	"res://cinematics/intro/atlas/intro_06_promesse.tres",
	"res://cinematics/intro/atlas/intro_07_coeur_aube.tres",
	"res://cinematics/intro/atlas/intro_08_transformation.tres",
	"res://cinematics/intro/atlas/intro_09_marchand.tres",
]
@export_file("*.mp3") var narration_path := \
	"res://cinematics/intro/audio/intro_narration.mp3"
@export_file("*.mp3") var music_path := \
	"res://cinematics/intro/audio/The Heart of Dawn.mp3"
@export_file("*.tres") var skip_sfx_path := ""
@export_file("*.tres") var run_data_path := "res://data/runs/first_run.tres"
@export var hero_source_paths: Array[String] = [
	"res://data/units/alliés/elfe.tres",
	"res://data/units/alliés/mage.tres",
	"res://data/units/alliés/Guerrier.tres",
]
@export_file("*.tscn") var fallback_scene_path := "res://ui/TitreEcran.tscn"
@export var subtitles_enabled := true
@export var autoplay := true
@export_range(0.0, 3.0, 0.05) var opening_fade_duration := 0.8
@export_range(0.0, 3.0, 0.05) var exit_fade_duration := 0.8
@export_range(-40.0, 0.0, 0.5) var music_volume_db := -18.0
@export_range(0.0, 5.0, 0.1) var music_fade_in_duration := 1.5
@export_range(0.0, 5.0, 0.1) var music_fade_out_duration := 1.0

@onready var illustration_frame: PanelContainer = $IllustrationFrame
@onready var image_a: TextureRect = $IllustrationFrame/ImageA
@onready var image_b: TextureRect = $IllustrationFrame/ImageB
@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var subtitle: RichTextLabel = $SubtitlePanel/Subtitle
@onready var black_fade: ColorRect = $BlackFade
@onready var skip_button: Button = $SkipButton
@onready var voice_player: AudioStreamPlayer = $VoicePlayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SfxPlayer

var run_manager_override: Node = null

var _illustrations: Array[Texture2D] = []
var _slot_plan_indices: Array[int] = [-1, -1]
var _active_slot := 0
var _current_plan_index := -1
var _last_clock_time := 0.0
var _fallback_clock_started_msec := 0
var _voice_is_clock := false
var _exit_requested := false
var run_start_committed := false
var _opening_tween: Tween = null
var _music_fade_tween: Tween = null
var _music_start_requested := false


func _ready() -> void:
	_install_translation()
	_load_illustrations()
	_configure_initial_plan()
	_update_responsive_layout()
	if not get_viewport().size_changed.is_connected(_update_responsive_layout):
		get_viewport().size_changed.connect(_update_responsive_layout)
	if not skip_button.pressed.is_connected(request_skip):
		skip_button.pressed.connect(request_skip)
	if not voice_player.finished.is_connected(finish_cinematic):
		voice_player.finished.connect(finish_cinematic)
	set_subtitles_enabled(subtitles_enabled)

	if autoplay:
		_begin_playback()
	else:
		black_fade.color.a = 0.0
		set_process(false)


func _process(_delta: float) -> void:
	if _exit_requested:
		return
	var cinematic_time := _sample_narration_clock()
	synchronize_to_time(cinematic_time)
	if not _voice_is_clock and cinematic_time >= CINEMATIC_DURATION:
		finish_cinematic()


func _exit_tree() -> void:
	_kill_music_fade()
	if is_instance_valid(voice_player):
		voice_player.stop()
	if is_instance_valid(music_player):
		music_player.stop()


func _unhandled_input(event: InputEvent) -> void:
	if _exit_requested or not _is_skip_input(event):
		return
	get_viewport().set_input_as_handled()
	request_skip()


func _begin_playback() -> void:
	_fallback_clock_started_msec = Time.get_ticks_msec()
	_last_clock_time = 0.0
	_load_and_play_optional_music()
	_load_and_play_narration()
	black_fade.color.a = 1.0
	_opening_tween = create_tween()
	_opening_tween.tween_property(
		black_fade,
		"color:a",
		0.0,
		opening_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	set_process(true)


func _load_and_play_narration() -> void:
	_voice_is_clock = false
	if not ResourceLoader.exists(narration_path):
		push_warning(
			"Cinématique d’introduction : narration absente, horloge de secours active."
		)
		return
	var stream := load(narration_path) as AudioStream
	if stream == null:
		push_warning(
			"Cinématique d’introduction : narration illisible, horloge de secours active."
		)
		return
	voice_player.stream = stream
	voice_player.play()
	_voice_is_clock = voice_player.playing


func _load_and_play_optional_music() -> void:
	if _music_start_requested:
		return
	_music_start_requested = true
	if music_path.is_empty():
		push_warning("Cinématique d’introduction : chemin de musique vide.")
		return
	if not ResourceLoader.exists(music_path):
		push_warning(
			"Cinématique d’introduction : musique absente : %s" % music_path
		)
		return
	var stream := load(music_path) as AudioStream
	if stream == null:
		push_warning(
			"Cinématique d’introduction : musique illisible : %s" % music_path
		)
		return
	music_player.stream = stream
	music_player.bus = &"Music"
	music_player.volume_db = MUSIC_SILENCE_DB
	music_player.play()
	if not music_player.playing:
		push_warning(
			"Cinématique d’introduction : la musique n’a pas pu démarrer : %s"
			% music_path
		)
		return
	if music_fade_in_duration <= 0.0:
		music_player.volume_db = music_volume_db
		return
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(
		music_player,
		"volume_db",
		music_volume_db,
		music_fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _sample_narration_clock() -> float:
	var sampled_time := (
		float(Time.get_ticks_msec() - _fallback_clock_started_msec) / 1000.0
	)
	if _voice_is_clock and voice_player.playing:
		sampled_time = (
			voice_player.get_playback_position()
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
		)
	_last_clock_time = maxf(_last_clock_time, maxf(0.0, sampled_time))
	return _last_clock_time


## Met à jour l’image et le sous-titre depuis une heure absolue et monotone.
## La narration appelle cette méthode chaque frame ; elle est aussi utile aux captures QA.
func synchronize_to_time(time_seconds: float) -> void:
	var monotonic_time := maxf(_last_clock_time, maxf(0.0, time_seconds))
	_last_clock_time = monotonic_time
	var requested_plan := _find_plan_index(monotonic_time)
	if requested_plan != _current_plan_index:
		_activate_plan(requested_plan)
	_update_crossfade(monotonic_time)
	_update_ken_burns(monotonic_time)


func _find_plan_index(time_seconds: float) -> int:
	for index in range(PLAN_START_TIMES.size() - 1, -1, -1):
		if time_seconds >= PLAN_START_TIMES[index]:
			return index
	return 0


func _configure_initial_plan() -> void:
	_current_plan_index = 0
	_active_slot = 0
	_slot_plan_indices = [0, -1]
	image_a.texture = _get_illustration(0)
	image_a.modulate.a = 1.0
	image_b.texture = null
	image_b.modulate.a = 0.0
	_update_subtitle(0)


func _activate_plan(plan_index: int) -> void:
	_active_slot = 1 - _active_slot
	_slot_plan_indices[_active_slot] = plan_index
	var incoming := _get_image(_active_slot)
	incoming.texture = _get_illustration(plan_index)
	incoming.modulate.a = 0.0
	_current_plan_index = plan_index
	_update_subtitle(plan_index)


func _update_crossfade(time_seconds: float) -> void:
	var fade_progress := 1.0
	if _current_plan_index > 0:
		fade_progress = clampf(
			(time_seconds - PLAN_START_TIMES[_current_plan_index]) / CROSSFADE_DURATION,
			0.0,
			1.0
		)
	var incoming := _get_image(_active_slot)
	var outgoing := _get_image(1 - _active_slot)
	incoming.modulate.a = fade_progress
	outgoing.modulate.a = 1.0 - fade_progress \
		if _slot_plan_indices[1 - _active_slot] >= 0 else 0.0


func _update_ken_burns(time_seconds: float) -> void:
	var viewport_scale := maxf(0.5, get_viewport_rect().size.y / 1080.0)
	for slot in range(2):
		var plan_index := _slot_plan_indices[slot]
		if plan_index < 0:
			continue
		var image := _get_image(slot)
		var start_time: float = PLAN_START_TIMES[plan_index]
		var end_time := CINEMATIC_DURATION
		if plan_index + 1 < PLAN_START_TIMES.size():
			end_time = PLAN_START_TIMES[plan_index + 1]
		var duration := maxf(0.001, end_time - start_time)
		var progress := clampf((time_seconds - start_time) / duration, 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, progress)
		var zoom := lerpf(1.0, MAX_KEN_BURNS_ZOOM, eased)
		var direction: Vector2 = KEN_BURNS_DIRECTIONS[plan_index]
		var travel := MAX_KEN_BURNS_TRAVEL_AT_1080P * viewport_scale
		image.pivot_offset = image.size * 0.5
		image.scale = Vector2.ONE * zoom
		image.position = direction * lerpf(-travel * 0.5, travel * 0.5, eased)


func _update_subtitle(plan_index: int) -> void:
	if plan_index < 0 or plan_index >= SUBTITLE_KEYS.size():
		subtitle.text = ""
		return
	var key: String = SUBTITLE_KEYS[plan_index]
	var translated := tr(StringName(key))
	if translated == key:
		translated = SUBTITLE_FALLBACKS[plan_index]
	subtitle.text = "[center]%s[/center]" % translated


func _load_illustrations() -> void:
	_illustrations.clear()
	for path in illustration_paths:
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D
		if texture == null:
			push_warning("Cinématique d’introduction : illustration absente : %s" % path)
		_illustrations.append(texture)


func _get_illustration(index: int) -> Texture2D:
	if index < 0 or index >= _illustrations.size():
		return null
	return _illustrations[index]


func _get_image(slot: int) -> TextureRect:
	return image_a if slot == 0 else image_b


func _install_translation() -> void:
	if not ResourceLoader.exists(TRANSLATION_PATH):
		return
	var translation := load(TRANSLATION_PATH) as Translation
	if translation != null:
		TranslationServer.add_translation(translation)


func _update_responsive_layout() -> void:
	var height := get_viewport_rect().size.y
	var subtitle_font_size := 22
	var skip_font_size := 17
	if height > 720.0:
		subtitle_font_size = 28
		skip_font_size = 19
	if height > 1080.0:
		subtitle_font_size = 36
		skip_font_size = 24
	subtitle.add_theme_font_size_override("normal_font_size", subtitle_font_size)
	subtitle.add_theme_font_size_override("bold_font_size", subtitle_font_size)
	skip_button.add_theme_font_size_override("font_size", skip_font_size)
	for image in [image_a, image_b]:
		image.pivot_offset = image.size * 0.5


func _is_skip_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [
			KEY_ESCAPE,
			KEY_SPACE,
			KEY_ENTER,
			KEY_KP_ENTER,
		]
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index in [
			JOY_BUTTON_A,
			JOY_BUTTON_B,
			JOY_BUTTON_START,
		]
	return false


func set_subtitles_enabled(enabled: bool) -> void:
	subtitles_enabled = enabled
	subtitle_panel.visible = enabled


func request_skip() -> void:
	_play_optional_skip_sfx()
	_begin_exit(true)


func finish_cinematic() -> void:
	_begin_exit(false)


func _begin_exit(skipped: bool) -> void:
	if _exit_requested:
		return
	_exit_requested = true
	set_process(false)
	skip_button.disabled = true
	skip_button.visible = false
	exit_started.emit(skipped)
	if _opening_tween != null:
		_opening_tween.kill()
	_kill_music_fade()

	var fade := create_tween().set_parallel(true)
	fade.tween_property(
		black_fade,
		"color:a",
		1.0,
		exit_fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if voice_player.playing:
		fade.tween_property(
			voice_player,
			"volume_db",
			MUSIC_SILENCE_DB,
			exit_fade_duration
		)
	if music_player.playing:
		fade.tween_property(
			music_player,
			"volume_db",
			MUSIC_SILENCE_DB,
			music_fade_out_duration
		)
	await fade.finished
	voice_player.stop()
	music_player.stop()
	_complete_intro_and_start_run()


func _kill_music_fade() -> void:
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = null


func _play_optional_skip_sfx() -> void:
	if skip_sfx_path.is_empty() or not ResourceLoader.exists(skip_sfx_path):
		return
	var stream := load(skip_sfx_path) as AudioStream
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()


func _complete_intro_and_start_run() -> void:
	if run_start_committed:
		return
	var configuration := _resolve_run_configuration()
	if configuration.is_empty():
		_fail_and_return("Configuration de la première run indisponible.")
		return
	var manager := _get_run_manager()
	if manager == null or not manager.has_method("start_preconfigured_run"):
		_fail_and_return("GameManager.start_preconfigured_run() indisponible.")
		return
	run_start_committed = true
	var run_data: RunData = configuration["run_data"]
	var hero_sources: Array = configuration["hero_sources"]
	run_start_requested.emit(run_data, hero_sources.duplicate())
	manager.start_preconfigured_run(run_data, hero_sources)


func _resolve_run_configuration() -> Dictionary:
	if not ResourceLoader.exists(run_data_path):
		return {}
	var run_data := load(run_data_path) as RunData
	if run_data == null:
		return {}
	var hero_sources: Array[UnitData] = []
	for path in hero_source_paths:
		if not ResourceLoader.exists(path):
			return {}
		var hero_data := load(path) as UnitData
		if hero_data == null:
			return {}
		hero_sources.append(hero_data)
	var manager := _get_run_manager()
	if manager != null and manager.has_method("take_next_run_data"):
		var selected_run = manager.call("take_next_run_data", run_data)
		if selected_run is RunData:
			run_data = selected_run as RunData
	return {
		"run_data": run_data,
		"hero_sources": hero_sources,
	}


func _get_run_manager() -> Node:
	if is_instance_valid(run_manager_override):
		return run_manager_override
	return get_node_or_null("/root/GameManager")


func _fail_and_return(reason: String) -> void:
	push_error("Cinématique d’introduction : %s" % reason)
	cinematic_failed.emit(reason)
	if fallback_scene_path.is_empty() or not ResourceLoader.exists(fallback_scene_path):
		return
	if is_inside_tree():
		get_tree().change_scene_to_file.call_deferred(fallback_scene_path)


func get_current_plan_index() -> int:
	return _current_plan_index


func get_loaded_illustration_count() -> int:
	return _illustrations.filter(func(texture): return texture != null).size()


func is_exit_requested() -> bool:
	return _exit_requested


func has_started_run() -> bool:
	return run_start_committed
