@tool
# ui/characters/character_preview_3d.gd
# ============================================================
# APERÇU D'UN PERSONNAGE (sprites ou 3D) — utilisé par l'ordre de tour, le portrait,
# l'écran de fin de combat, la fiche de présentation, et par l'écran
# « Animations » du Studio des personnages.
#
# Le script est @tool pour fonctionner aussi dans l'éditeur. Attention :
# dans l'éditeur, les scripts des personnages (MageVisual3D...) ne
# tournent PAS — Godot leur substitue une coquille sans méthodes. Le
# widget reprend donc la main sur le lecteur d'animations dans ce seul
# cas, et laisse strictement le comportement d'origine en jeu.
# ============================================================

class_name CharacterPreview3D
extends Control

# Pose de reference ajoutee par l'import Godot : elle n'a aucun sens pour
# un joueur et ne doit jamais apparaitre dans une liste de choix.
const RESET_CLIP := &"RESET"
const SHOWCASE_FOOT_ANCHOR := 0.96
const SHOWCASE_HEIGHT := 0.94
const SHOWCASE_MIN_ZOOM := 0.85
const SHOWCASE_MAX_ZOOM := 1.1

@export var unit_data: UnitData = null

@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var preview_viewport: SubViewport = $ViewportContainer/PreviewViewport
@onready var visual_root: Node3D = $ViewportContainer/PreviewViewport/PreviewWorld/VisualRoot
@onready var camera: Camera3D = $ViewportContainer/PreviewViewport/PreviewWorld/Camera3D
@onready var fallback_panel: PanelContainer = $FallbackPanel
@onready var fallback_label: Label = $FallbackPanel/FallbackLabel

var _visual_instance: Node3D = null
var _editor_player: AnimationPlayer = null
var _sprite_instance: AnimatedSprite2D = null
var _sprite_reference_rect := Rect2()
var _preview_active := true
var _sprite_play_requested := false
# Selection-only framing. HUD, Studio and portraits keep their authored layout.
var _showcase_mode := false
var _showcase_zoom := 1.0
var _authored_camera_transform := Transform3D.IDENTITY
var _authored_camera_size := 2.75
# Several HUD cards reuse the same texture; read its alpha bounds only once.
static var _sprite_bounds_cache: Dictionary = {}


func _ready() -> void:
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	_authored_camera_transform = camera.transform
	_authored_camera_size = camera.size
	set_process(false)
	clip_contents = true
	resized.connect(_layout_preview)
	configure(unit_data)


func _process(delta: float) -> void:
	# Uniquement le chemin editeur : en jeu, _editor_player reste null et le
	# traitement est desactive.
	if not is_instance_valid(_editor_player):
		set_process(false)
		return
	if _editor_player.is_playing():
		_editor_player.advance(delta)


func _exit_tree() -> void:
	clear_preview()
	if is_instance_valid(preview_viewport):
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func configure(source) -> void:
	clear_preview()
	var visual_scene: PackedScene = null
	var display_name := "Personnage"
	if source is UnitData:
		unit_data = source as UnitData
		visual_scene = unit_data.preview_visual_scene
		display_name = unit_data.unit_name
		if unit_data.preview_sprite_frames != null:
			if not _configure_sprite_preview(unit_data):
				_show_fallback(display_name)
			return
	elif source is PackedScene:
		unit_data = null
		visual_scene = source as PackedScene
	else:
		unit_data = null

	if visual_scene == null:
		_show_fallback(display_name)
		return
	var candidate := visual_scene.instantiate()
	if not candidate is Node3D:
		candidate.free()
		_show_fallback(display_name)
		return
	_visual_instance = candidate as Node3D
	visual_root.add_child(_visual_instance)
	var authored_scale := _visual_instance.scale
	_visual_instance.transform = Transform3D.IDENTITY
	_visual_instance.scale = authored_scale
	if _character_script_is_running():
		# En jeu : le personnage se pilote lui-meme, comportement d'origine.
		if unit_data != null and _visual_instance.has_method("apply_animation_set"):
			_visual_instance.apply_animation_set(unit_data.animation_set)
		if _visual_instance.has_method("reset_to_idle"):
			_visual_instance.reset_to_idle()
		elif _visual_instance.has_method("play_idle"):
			_visual_instance.play_idle()
	else:
		# Script en sommeil (editeur) ou visuel sans pilotage : on cherche
		# nous-memes le lecteur d'animations du modele.
		_prepare_dormant_playback()
		if not is_instance_valid(_editor_player):
			if _visual_instance.has_method("reset_to_idle"):
				_visual_instance.reset_to_idle()
			elif _visual_instance.has_method("play_idle"):
				_visual_instance.play_idle()
	viewport_container.visible = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _preview_active else SubViewport.UPDATE_DISABLED
	fallback_panel.visible = false
	_layout_showcase_camera()


## Coupe ou relance le rendu du petit monde 3D. Un aperçu qu'on ne regarde pas
## continuerait sinon à se dessiner à chaque image : coûteux partout, et
## particulièrement dans une fenêtre d'éditeur, qui n'est pas un jeu.
func set_preview_active(active: bool) -> void:
	_preview_active = active
	if is_using_sprite_preview():
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport_container.visible = false
		if active and _sprite_play_requested:
			_sprite_instance.play()
		else:
			_sprite_instance.pause()
		return
	if not is_instance_valid(preview_viewport):
		return
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active \
		else SubViewport.UPDATE_DISABLED
	if not active:
		stop_clip()


## Opt-in large framing for the selection stage; safe to set before _ready().
func set_showcase_mode(enabled: bool) -> void:
	var was_showcase := _showcase_mode
	_showcase_mode = enabled
	if not enabled:
		_showcase_zoom = 1.0
		if was_showcase and is_instance_valid(camera):
			camera.transform = _authored_camera_transform
			camera.size = _authored_camera_size
	_layout_preview()


func is_showcase_mode() -> bool:
	return _showcase_mode


## Zoom pivots around the same foot anchor instead of moving the silhouette.
func set_showcase_zoom(value: float) -> bool:
	if not _showcase_mode or not is_finite(value):
		return false
	_showcase_zoom = clampf(value, SHOWCASE_MIN_ZOOM, SHOWCASE_MAX_ZOOM)
	_layout_preview()
	return true


func get_showcase_zoom() -> float:
	return _showcase_zoom


func _layout_preview() -> void:
	_layout_sprite_preview()
	_layout_showcase_camera()


func _layout_showcase_camera() -> void:
	if not _showcase_mode or not is_instance_valid(camera):
		return
	camera.transform = _authored_camera_transform
	camera.size = _authored_camera_size
	if not is_instance_valid(_visual_instance):
		return
	# Preserve the model's authored orientation and lighting. This mild crop
	# enlarges the trio while a projection-based offset keeps their origin on
	# the same stage as the 2D champion, independently of the panel's aspect.
	camera.size = _authored_camera_size * 0.85 / _showcase_zoom
	var viewport_size := Vector2(preview_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var ground := visual_root.global_position
	var depth := maxf(0.1, -camera.to_local(ground).z)
	var anchor := Vector2(viewport_size.x * 0.5, viewport_size.y * SHOWCASE_FOOT_ANCHOR)
	camera.global_position += ground - camera.project_position(anchor, depth)


func clear_preview() -> void:
	_editor_player = null
	set_process(false)
	_sprite_play_requested = false
	_sprite_reference_rect = Rect2()
	if is_instance_valid(_sprite_instance):
		_sprite_instance.stop()
		remove_child(_sprite_instance)
		_sprite_instance.free()
	_sprite_instance = null
	if is_instance_valid(preview_viewport):
		preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(viewport_container):
		viewport_container.visible = false
	if is_instance_valid(fallback_panel):
		fallback_panel.visible = true
	if not is_instance_valid(_visual_instance):
		_visual_instance = null
		return
	if _visual_instance.get_parent() != null:
		_visual_instance.get_parent().remove_child(_visual_instance)
	_visual_instance.free()
	_visual_instance = null


func get_visual_instance() -> Node3D:
	return _visual_instance if is_instance_valid(_visual_instance) else null


func is_using_fallback() -> bool:
	return fallback_panel.visible


## Noms des clips reellement presents dans le modele affiche, dans l'ordre
## alphabetique. Sert a ne proposer que des valeurs valides.
func get_available_clips() -> Array[StringName]:
	var result: Array[StringName] = []
	if is_using_sprite_preview():
		for name_value in _sprite_instance.sprite_frames.get_animation_names():
			result.append(StringName(name_value))
	else:
		var player := _animation_player()
		if player == null:
			return result
		for name_value in player.get_animation_list():
			var clip := StringName(name_value)
			if clip != RESET_CLIP:
				result.append(clip)
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return str(a).naturalnocasecmp_to(str(b)) < 0
	)
	return result


func has_clip(clip_name: StringName) -> bool:
	if is_using_sprite_preview():
		return clip_name != &"" and _sprite_instance.sprite_frames.has_animation(clip_name)
	var player := _animation_player()
	return player != null and clip_name != &"" and player.has_animation(clip_name)


## Joue un clip nomme sur l'instance actuellement affichee.
## En jeu, passe par CharacterVisual3D.play_animation(). Dans l'editeur, ou le
## script du personnage est en sommeil, pilote directement le lecteur trouve
## dans le modele.
func play_clip(clip_name: StringName, blend_time := 0.12) -> bool:
	if is_using_sprite_preview():
		if not has_clip(clip_name):
			return false
		_sprite_instance.stop()
		_sprite_instance.animation = clip_name
		_sprite_instance.set_frame_and_progress(0, 0.0)
		_sprite_instance.speed_scale = 1.0
		_sprite_play_requested = not _sprite_clip_is_idle(clip_name)
		if _sprite_play_requested and _preview_active:
			_sprite_instance.play()
		else:
			_sprite_instance.pause()
		return true
	if not is_instance_valid(_visual_instance) or clip_name == &"":
		return false
	if _character_script_is_running():
		return _visual_instance.play_animation(clip_name, 1.0, blend_time)
	if not is_instance_valid(_editor_player) \
			or not _editor_player.has_animation(clip_name):
		return false
	_editor_player.stop()
	_editor_player.play(clip_name, maxf(blend_time, 0.0))
	_editor_player.advance(0.0)
	set_process(true)
	return true


func stop_clip() -> void:
	if is_using_sprite_preview():
		_sprite_play_requested = false
		_sprite_instance.pause()
		return
	if _character_script_is_running():
		_visual_instance.stop_animation()
		return
	if is_instance_valid(_editor_player):
		_editor_player.stop()
	set_process(false)


func _character_script_is_running() -> bool:
	# has_method() renvoie false sur la coquille que l'editeur substitue aux
	# scripts non-@tool : c'est le test fiable pour savoir si le personnage
	# sait se piloter lui-meme.
	return is_instance_valid(_visual_instance) \
		and _visual_instance.has_method("play_animation") \
		and _visual_instance.has_method("get_animation_player") \
		and _visual_instance.get_animation_player() != null


func _animation_player() -> AnimationPlayer:
	if _character_script_is_running():
		return _visual_instance.get_animation_player()
	return _editor_player if is_instance_valid(_editor_player) else null


func _prepare_dormant_playback() -> void:
	var players := _visual_instance.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_editor_player = players[0] as AnimationPlayer
	# Le lecteur n'avance pas tout seul tant que le script du personnage dort :
	# on le passe en avance manuelle et on le fait progresser depuis _process.
	_editor_player.callback_mode_process = \
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var idle_clip := _dormant_idle_clip()
	if idle_clip != &"":
		play_clip(idle_clip, 0.0)


## Sans script actif, le clip de repos par defaut est inconnu : on le deduit de
## la fiche d'animations du personnage, sinon d'un nom de clip evocateur.
func _dormant_idle_clip() -> StringName:
	if unit_data != null and unit_data.animation_set != null:
		var configured := unit_data.animation_set.get_animation_name(
			CharacterVisual3D.ACTION_IDLE
		)
		if configured != &"" and is_instance_valid(_editor_player) \
				and _editor_player.has_animation(configured):
			return configured
	for clip in get_available_clips():
		if str(clip).to_lower().contains("idle"):
			return clip
	return &""


func _show_fallback(display_name: String) -> void:
	viewport_container.visible = false
	fallback_panel.visible = true
	fallback_label.text = "%s\nAperçu indisponible" % display_name


## Keep the Node3D API above intact for existing camera/skeleton consumers.
## Sprite-aware callers can opt in without changing get_visual_instance().
func get_sprite_instance() -> AnimatedSprite2D:
	return _sprite_instance if is_instance_valid(_sprite_instance) else null


func is_using_sprite_preview() -> bool:
	return is_instance_valid(_sprite_instance)


func get_sprite_reference_rect() -> Rect2:
	return _sprite_reference_rect


func _configure_sprite_preview(data: UnitData) -> bool:
	var frames := data.preview_sprite_frames
	var clip := data.preview_sprite_animation
	if frames == null or not frames.has_animation(clip) or frames.get_frame_count(clip) < 1:
		return false
	var texture := frames.get_frame_texture(clip, 0)
	if texture == null:
		return false
	var cache_key := texture.get_instance_id()
	if _sprite_bounds_cache.has(cache_key):
		_sprite_reference_rect = _sprite_bounds_cache[cache_key]
	else:
		var texture_image := texture.get_image()
		if texture_image == null or texture_image.is_empty():
			return false
		_sprite_reference_rect = Rect2(texture_image.get_used_rect())
		if _sprite_reference_rect.size.x <= 0.0 or _sprite_reference_rect.size.y <= 0.0:
			return false
		_sprite_bounds_cache[cache_key] = _sprite_reference_rect
	_sprite_instance = AnimatedSprite2D.new()
	_sprite_instance.name = "SpritePreview"
	_sprite_instance.centered = false
	_sprite_instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite_instance.sprite_frames = frames
	_sprite_instance.flip_h = false
	_sprite_instance.flip_v = false
	add_child(_sprite_instance)
	# The existing empty 3D world is retained for other units, but never renders
	# or instantiates a character model while this branch is selected.
	viewport_container.visible = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fallback_panel.visible = false
	play_clip(clip, 0.0)
	_layout_sprite_preview()
	return true


func _layout_sprite_preview() -> void:
	if not is_using_sprite_preview() or _sprite_reference_rect.size.x <= 0.0 \
			or _sprite_reference_rect.size.y <= 0.0:
		return
	# Only resize changes the framing. A walk/attack pose cannot make the
	# portrait breathe by fitting each frame's different silhouette bounds.
	var available := Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)) * 0.9
	if _showcase_mode:
		available = Vector2(maxf(size.x, 1.0) * SHOWCASE_HEIGHT,
			maxf(size.y, 1.0) * SHOWCASE_HEIGHT)
	var fit := minf(available.x / _sprite_reference_rect.size.x,
		available.y / _sprite_reference_rect.size.y)
	if _showcase_mode:
		fit *= _showcase_zoom
	_sprite_instance.scale = Vector2.ONE * fit
	if _showcase_mode:
		var reference_feet := Vector2(_sprite_reference_rect.get_center().x,
			_sprite_reference_rect.end.y)
		_sprite_instance.position = Vector2(size.x * 0.5, size.y * SHOWCASE_FOOT_ANCHOR) \
			- reference_feet * fit
	else:
		_sprite_instance.position = size * 0.5 - _sprite_reference_rect.get_center() * fit


func _sprite_clip_is_idle(clip: StringName) -> bool:
	return (unit_data != null and clip == unit_data.preview_sprite_animation) \
		or String(clip).to_lower().begins_with("idle")
