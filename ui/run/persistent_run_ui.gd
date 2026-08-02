class_name PersistentRunUI
extends Node

signal evolution_choice_resolved(request_id, upgrade_id)

enum RunUIMode {
	COMBAT,
	NON_COMBAT,
	TRANSITION,
}

@onready var combat_hud: CanvasLayer = %CombatHUDRecraftV1
@onready var contextual_ui_layer: CanvasLayer = %ContextualUILayer
@onready var overlay_layer: CanvasLayer = %OverlayLayer
@onready var skill_tree_status_button: SkillTreeStatusButton = (
	%SkillTreeStatusButton
)
@onready var skill_tree_screen: SkillTreeScreen = %SkillTreeScreen
@onready var pause_menu: DarkPauseMenu = %DarkPauseMenu
@onready var evolution_feedback: PanelContainer = %EvolutionFeedback
@onready var evolution_emblem: TextureRect = %EvolutionEmblem
@onready var evolution_title: Label = %EvolutionTitle
@onready var evolution_discipline: Label = %EvolutionDiscipline

@export var evolution_feedback_duration := 0.38

var _ui_mode: RunUIMode = RunUIMode.TRANSITION
var _combat_controls_before_skill_tree := false
var _combat_controls_before_pause := false
var _tree_was_paused_before_menu := false
var _owns_tree_pause := false
var _evolution_screen_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skill_tree_status_button.tree_requested.connect(
		_on_skill_tree_requested
	)
	combat_hud.utility_skill_tree_requested.connect(
		_on_skill_tree_requested
	)
	skill_tree_screen.screen_closed.connect(
		_on_skill_tree_screen_closed
	)
	skill_tree_screen.evolution_choice_resolved.connect(
		_on_skill_tree_evolution_resolved
	)
	pause_menu.resume_requested.connect(close_pause_menu)
	pause_menu.return_to_title_requested.connect(
		_on_pause_return_to_title_requested
	)
	set_ui_mode(_ui_mode)


func _exit_tree() -> void:
	close_pause_menu()


func bind_combat_context(context: Node) -> CanvasLayer:
	if context == null:
		unbind_combat_context()
		return null
	combat_hud.bind_combat_context(context)
	set_ui_mode(RunUIMode.COMBAT)
	skill_tree_status_button.refresh_from_state()
	return combat_hud


func unbind_combat_context(expected_context: Node = null) -> void:
	if not is_instance_valid(combat_hud):
		return
	if (
		expected_context != null
		and combat_hud.get_combat_context() != expected_context
	):
		return
	combat_hud.unbind_combat_context()
	set_ui_mode(RunUIMode.TRANSITION)


func refresh_from_context() -> void:
	if is_instance_valid(combat_hud):
		combat_hud.refresh_from_context()
	if is_instance_valid(skill_tree_status_button):
		skill_tree_status_button.refresh_from_state()


func set_ui_mode(mode: RunUIMode) -> void:
	if mode == RunUIMode.TRANSITION or not GameManager.run_active:
		close_pause_menu()
	_ui_mode = mode
	if (
		mode != RunUIMode.COMBAT
		and is_instance_valid(skill_tree_screen)
		and skill_tree_screen.visible
	):
		skill_tree_screen.close_for_run_cleanup()
		_evolution_screen_active = false
	if is_instance_valid(evolution_feedback) and mode != RunUIMode.COMBAT:
		evolution_feedback.hide()
	if is_instance_valid(combat_hud):
		combat_hud.set_ui_mode(mode)
	if is_instance_valid(contextual_ui_layer):
		contextual_ui_layer.visible = mode == RunUIMode.NON_COMBAT
	if is_instance_valid(overlay_layer):
		overlay_layer.visible = mode != RunUIMode.TRANSITION
	if is_instance_valid(skill_tree_status_button):
		# Le UtilityDock REFINED est l’unique point d’accès visuel en combat.
		# Le composant historique reste disponible pour ses autres consommateurs.
		skill_tree_status_button.set_context_visible(false)


func get_ui_mode() -> RunUIMode:
	return _ui_mode


func get_combat_hud() -> CanvasLayer:
	return combat_hud


func get_skill_tree_status_button() -> SkillTreeStatusButton:
	return skill_tree_status_button


func get_skill_tree_screen() -> SkillTreeScreen:
	return skill_tree_screen


func get_pause_menu() -> DarkPauseMenu:
	return pause_menu


func is_pause_menu_open() -> bool:
	return is_instance_valid(pause_menu) and pause_menu.is_open()


func open_pause_menu() -> bool:
	if (
		not GameManager.run_active
		or _ui_mode == RunUIMode.TRANSITION
		or is_pause_menu_open()
		or _evolution_screen_active
		or (
			is_instance_valid(skill_tree_screen)
			and skill_tree_screen.visible
		)
	):
		return false
	_tree_was_paused_before_menu = get_tree().paused
	_owns_tree_pause = true
	_combat_controls_before_pause = bool(
		combat_hud.get("_player_controls_enabled")
	) if is_instance_valid(combat_hud) else false
	if is_instance_valid(combat_hud):
		combat_hud.set_player_controls_enabled(false)
	pause_menu.open_menu()
	get_tree().paused = true
	return true


func close_pause_menu() -> bool:
	var was_open := is_pause_menu_open()
	if is_instance_valid(pause_menu):
		pause_menu.close_menu()
	var scene_tree: SceneTree = get_tree() if is_inside_tree() else null
	if _owns_tree_pause and scene_tree != null:
		scene_tree.paused = _tree_was_paused_before_menu
	_owns_tree_pause = false
	_tree_was_paused_before_menu = false
	if (
		was_open
		and _ui_mode == RunUIMode.COMBAT
		and is_instance_valid(combat_hud)
		and is_instance_valid(combat_hud.get_combat_context())
	):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_pause
		)
	_combat_controls_before_pause = false
	return was_open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_pause_menu_open():
		get_viewport().set_input_as_handled()
		if not pause_menu.dismiss_confirmation():
			close_pause_menu()
		return
	if (
		is_instance_valid(skill_tree_screen)
		and skill_tree_screen.visible
	):
		return
	if open_pause_menu():
		get_viewport().set_input_as_handled()


func _on_skill_tree_requested(
		character_id: StringName,
		discipline_id: StringName
	) -> void:
	if _ui_mode != RunUIMode.COMBAT \
			or skill_tree_screen.visible \
			or _evolution_screen_active:
		return
	_combat_controls_before_skill_tree = bool(
		combat_hud.get("_player_controls_enabled")
	)
	combat_hud.set_player_controls_enabled(false)
	if not skill_tree_screen.open_for_character(
			character_id,
			GameManager,
			discipline_id
		):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_skill_tree
		)


func _on_skill_tree_screen_closed() -> void:
	if _evolution_screen_active:
		return
	if (
		_ui_mode == RunUIMode.COMBAT
		and is_instance_valid(combat_hud)
		and is_instance_valid(combat_hud.get_combat_context())
	):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_skill_tree
		)
	_combat_controls_before_skill_tree = false


func open_evolution_request(request: EvolutionRequest) -> bool:
	if request == null \
			or not request.is_valid() \
			or _ui_mode != RunUIMode.COMBAT \
			or _evolution_screen_active \
			or skill_tree_screen.visible:
		return false
	_evolution_screen_active = true
	_combat_controls_before_skill_tree = false
	if is_instance_valid(combat_hud):
		combat_hud.set_player_controls_enabled(false)
	_show_evolution_feedback(request)
	var tree := get_tree()
	if tree == null:
		_evolution_screen_active = false
		return false
	await tree.create_timer(maxf(evolution_feedback_duration, 0.001)).timeout
	if not is_inside_tree() or _ui_mode != RunUIMode.COMBAT:
		_evolution_screen_active = false
		return false
	evolution_feedback.hide()
	if not skill_tree_screen.open_for_evolution(request, GameManager):
		_evolution_screen_active = false
		return false
	return true


func is_evolution_screen_active() -> bool:
	return _evolution_screen_active


func _show_evolution_feedback(request: EvolutionRequest) -> void:
	var character_state := GameManager.get_character_state(request.character_id)
	var character_name := str(request.character_id)
	var discipline_name := str(request.discipline_id)
	var emblem: Texture2D = null
	if character_state != null:
		if character_state.unit != null:
			character_name = character_state.unit.unit_name
			var hud_theme := CharacterHUDThemeCatalog.resolve_refined(
				character_state.unit
			)
			if hud_theme != null:
				emblem = hud_theme.discipline_emblem_texture
		discipline_name = character_state.get_discipline_display_name(
			request.discipline_id
		)
	evolution_emblem.texture = emblem
	evolution_emblem.visible = emblem != null
	evolution_title.text = "ÉVOLUTION DISPONIBLE"
	evolution_discipline.text = "%s · %s · Rang %d" % [
		character_name,
		discipline_name,
		request.pending_rank,
	]
	evolution_feedback.show()
	evolution_feedback.move_to_front()


func _on_skill_tree_evolution_resolved(
		request_id: StringName,
		upgrade_id: StringName
	) -> void:
	_evolution_screen_active = false
	if is_instance_valid(evolution_feedback):
		evolution_feedback.hide()
	evolution_choice_resolved.emit(request_id, upgrade_id)


func _on_pause_return_to_title_requested(_reason: StringName) -> void:
	close_pause_menu()
	GameManager.return_to_title()
