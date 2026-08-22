@tool
# ui/characters/character_preview_3d.gd
# ============================================================
# APERÇU 3D D'UN PERSONNAGE — utilisé par l'ordre de tour, le portrait,
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

@export var unit_data: UnitData = null

@onready var viewport_container: SubViewportContainer = $ViewportContainer
@onready var preview_viewport: SubViewport = $ViewportContainer/PreviewViewport
@onready var visual_root: Node3D = $ViewportContainer/PreviewViewport/PreviewWorld/VisualRoot
@onready var camera: Camera3D = $ViewportContainer/PreviewViewport/PreviewWorld/Camera3D
@onready var fallback_panel: PanelContainer = $FallbackPanel
@onready var fallback_label: Label = $FallbackPanel/FallbackLabel

var _visual_instance: Node3D = null
var _editor_player: AnimationPlayer = null


func _ready() -> void:
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	set_process(false)
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
	fallback_panel.visible = false


func clear_preview() -> void:
	_editor_player = null
	set_process(false)
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
	var player := _animation_player()
	return player != null and clip_name != &"" and player.has_animation(clip_name)


## Joue un clip nomme sur l'instance actuellement affichee.
## En jeu, passe par CharacterVisual3D.play_animation(). Dans l'editeur, ou le
## script du personnage est en sommeil, pilote directement le lecteur trouve
## dans le modele.
func play_clip(clip_name: StringName, blend_time := 0.12) -> bool:
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
	fallback_label.text = "%s\nAperçu 3D indisponible" % display_name
