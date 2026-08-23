class_name PersistentRunUI
extends Node

signal evolution_choice_resolved(request_id, upgrade_id)

const MODAL_INVENTORY: StringName = &"inventory"
const MODAL_PAUSE: StringName = &"pause"
const MODAL_SKILL_TREE: StringName = &"skill_tree"
const MODAL_EVOLUTION: StringName = &"evolution"

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
@onready var inventory_screen: InventoryScreen = %InventoryScreen
@onready var pause_menu: DarkPauseMenu = %DarkPauseMenu
@onready var evolution_feedback: PanelContainer = %EvolutionFeedback
@onready var evolution_emblem: TextureRect = %EvolutionEmblem
@onready var evolution_title: Label = %EvolutionTitle
@onready var evolution_discipline: Label = %EvolutionDiscipline
@onready var skill_evolution_overlay: SkillEvolutionOverlay = %SkillEvolutionOverlay

@export var evolution_feedback_duration := 0.38

var _ui_mode: RunUIMode = RunUIMode.TRANSITION
var _combat_controls_before_skill_tree := false
var _combat_controls_before_pause := false
var _combat_controls_before_inventory := false
var _tree_was_paused_before_menu := false
var _owns_tree_pause := false
var _evolution_screen_active := false
var _tree_was_paused_before_evolution := false
var _owns_evolution_tree_pause := false
var _evolution_hud_was_visible := false
var _active_evolution_request: EvolutionRequest = null
var _active_evolution_request_id: StringName = &""
var _active_evolution_upgrade_id: StringName = &""
var _modal_coordinator := CombatModalCoordinator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_modal_coordinator.active_modal_changed.connect(
		_on_active_modal_changed
	)
	skill_tree_status_button.tree_requested.connect(
		_on_skill_tree_requested
	)
	combat_hud.utility_skill_tree_requested.connect(
		_on_skill_tree_requested
	)
	combat_hud.utility_inventory_requested.connect(
		_on_inventory_requested
	)
	skill_tree_screen.screen_closed.connect(
		_on_skill_tree_screen_closed
	)
	skill_tree_screen.evolution_choice_resolved.connect(
		_on_skill_tree_evolution_resolved
	)
	skill_evolution_overlay.confirmation_requested.connect(
		_on_skill_evolution_confirmation_requested
	)
	skill_evolution_overlay.confirmation_finished.connect(
		_on_skill_evolution_confirmation_finished
	)
	pause_menu.resume_requested.connect(close_pause_menu)
	pause_menu.equipment_requested.connect(_on_pause_equipment_requested)
	pause_menu.set_action_available(&"equipment", true)
	inventory_screen.screen_closed.connect(_on_inventory_screen_closed)
	pause_menu.return_to_title_requested.connect(
		_on_pause_return_to_title_requested
	)
	set_ui_mode(_ui_mode)


func _exit_tree() -> void:
	_close_evolution_overlay_for_cleanup()
	close_inventory_screen()
	close_pause_menu()
	_modal_coordinator.clear()


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
		close_inventory_screen()
		close_pause_menu()
	if mode != RunUIMode.COMBAT and _evolution_screen_active:
		_close_evolution_overlay_for_cleanup()
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
	if mode == RunUIMode.TRANSITION:
		_modal_coordinator.clear()


func get_ui_mode() -> RunUIMode:
	return _ui_mode


func get_combat_hud() -> CanvasLayer:
	return combat_hud


func get_skill_tree_status_button() -> SkillTreeStatusButton:
	return skill_tree_status_button


func get_skill_tree_screen() -> SkillTreeScreen:
	return skill_tree_screen


func get_skill_evolution_overlay() -> SkillEvolutionOverlay:
	return skill_evolution_overlay


func get_pause_menu() -> DarkPauseMenu:
	return pause_menu


func get_inventory_screen() -> InventoryScreen:
	return inventory_screen


func get_active_modal() -> StringName:
	return _modal_coordinator.get_active_modal()


func has_active_modal() -> bool:
	return _modal_coordinator.has_active_modal()


func _claim_modal(modal_id: StringName) -> bool:
	return _modal_coordinator.try_open(modal_id)


func _release_modal(modal_id: StringName) -> void:
	_modal_coordinator.close(modal_id)


func _on_active_modal_changed(
		_previous: StringName,
		current: StringName
	) -> void:
	var blocked := current != &""
	var context = (
		combat_hud.get_combat_context()
		if is_instance_valid(combat_hud)
		else null
	)
	if is_instance_valid(context) and context.has_method(
		"set_external_interaction_lock"
	):
		context.set_external_interaction_lock(&"run_modal", blocked)
	_set_tooltips_modal_blocked(blocked)


func _set_tooltips_modal_blocked(blocked: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for tooltip in tree.get_nodes_in_group("keyword_tooltip_layer"):
		if tooltip.has_method("set_modal_blocked"):
			tooltip.set_modal_blocked(blocked)
		elif blocked and tooltip.has_method("hide_all"):
			tooltip.hide_all()


func _combat_context_allows_run_modal() -> bool:
	if not is_instance_valid(combat_hud):
		return true
	var context = combat_hud.get_combat_context()
	if not is_instance_valid(context) \
			or not context.has_method("get_combat_presentation_snapshot"):
		return true
	var snapshot: Dictionary = context.get_combat_presentation_snapshot()
	return StringName(snapshot.get("phase_name", &"PLAYER_IDLE")) not in [
		&"RESOLVING_ACTION",
		&"MODAL",
		&"BATTLE_ENDING",
	]


func is_inventory_open() -> bool:
	return is_instance_valid(inventory_screen) and inventory_screen.is_open()


func open_inventory_screen(character_id: StringName = &"") -> bool:
	if not GameManager.run_active \
			or _ui_mode == RunUIMode.TRANSITION \
			or is_inventory_open() \
			or is_pause_menu_open() \
		or _evolution_screen_active \
		or (is_instance_valid(skill_tree_screen) and skill_tree_screen.visible) \
		or not _combat_context_allows_run_modal():
		return false
	_combat_controls_before_inventory = bool(
		combat_hud.get("_player_controls_enabled")
	) if is_instance_valid(combat_hud) else false
	if not _claim_modal(MODAL_INVENTORY):
		_combat_controls_before_inventory = false
		return false
	var wanted_id := character_id
	if wanted_id == &"":
		var states: Array[CharacterRunState] = (
			GameManager.get_ordered_character_states()
		)
		if states.is_empty():
			_release_modal(MODAL_INVENTORY)
			return false
		wanted_id = states[0].character_id
	if is_instance_valid(combat_hud):
		combat_hud.set_player_controls_enabled(false)
	if not inventory_screen.open_for_character(wanted_id, GameManager):
		if is_instance_valid(combat_hud):
			combat_hud.set_player_controls_enabled(
				_combat_controls_before_inventory
			)
		_combat_controls_before_inventory = false
		_release_modal(MODAL_INVENTORY)
		return false
	return true


func close_inventory_screen() -> bool:
	var was_open := is_inventory_open()
	if is_instance_valid(inventory_screen):
		inventory_screen.close_screen()
	return was_open


func is_pause_menu_open() -> bool:
	return is_instance_valid(pause_menu) and pause_menu.is_open()


func open_pause_menu() -> bool:
	if (
		not GameManager.run_active
		or _ui_mode == RunUIMode.TRANSITION
		or is_pause_menu_open()
		or is_inventory_open()
		or _evolution_screen_active
		or (
			is_instance_valid(skill_tree_screen)
			and skill_tree_screen.visible
		)
		or not _combat_context_allows_run_modal()
	):
		return false
	_combat_controls_before_pause = bool(
		combat_hud.get("_player_controls_enabled")
	) if is_instance_valid(combat_hud) else false
	if not _claim_modal(MODAL_PAUSE):
		_combat_controls_before_pause = false
		return false
	_tree_was_paused_before_menu = get_tree().paused
	_owns_tree_pause = true
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
	_release_modal(MODAL_PAUSE)
	return was_open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_inventory_open():
		get_viewport().set_input_as_handled()
		close_inventory_screen()
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
	var context = (
		combat_hud.get_combat_context()
		if is_instance_valid(combat_hud)
		else null
	)
	if is_instance_valid(context) \
			and context.has_method("dismiss_top_combat_modal") \
			and bool(context.dismiss_top_combat_modal()):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(context) \
			and context.has_method("cancel_active_selection") \
			and bool(context.cancel_active_selection()):
		get_viewport().set_input_as_handled()
		return
	if open_pause_menu():
		get_viewport().set_input_as_handled()


func _on_skill_tree_requested(
		character_id: StringName,
		discipline_id: StringName
	) -> void:
	if _ui_mode != RunUIMode.COMBAT \
			or skill_tree_screen.visible \
		or is_inventory_open() \
		or _evolution_screen_active \
		or not _combat_context_allows_run_modal():
		return
	_combat_controls_before_skill_tree = bool(
		combat_hud.get("_player_controls_enabled")
	)
	if not _claim_modal(MODAL_SKILL_TREE):
		_combat_controls_before_skill_tree = false
		return
	combat_hud.set_player_controls_enabled(false)
	if not skill_tree_screen.open_for_character(
			character_id,
			GameManager,
			discipline_id
		):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_skill_tree
		)
		_release_modal(MODAL_SKILL_TREE)


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
	_release_modal(MODAL_SKILL_TREE)


func _on_inventory_requested(character_id: StringName) -> void:
	open_inventory_screen(character_id)


func _on_pause_equipment_requested() -> void:
	var states: Array[CharacterRunState] = (
		GameManager.get_ordered_character_states()
	)
	if states.is_empty():
		return
	var character_id: StringName = states[0].character_id
	close_pause_menu()
	open_inventory_screen(character_id)


func _on_inventory_screen_closed() -> void:
	if (
		_ui_mode == RunUIMode.COMBAT
		and is_instance_valid(combat_hud)
		and is_instance_valid(combat_hud.get_combat_context())
	):
		combat_hud.set_player_controls_enabled(
			_combat_controls_before_inventory
		)
	_combat_controls_before_inventory = false
	_release_modal(MODAL_INVENTORY)


func open_evolution_request(request: EvolutionRequest) -> bool:
	if request == null \
			or not request.is_valid() \
			or _ui_mode != RunUIMode.COMBAT \
			or _evolution_screen_active \
			or is_inventory_open() \
		or skill_tree_screen.visible \
		or is_pause_menu_open():
		return false
	if not _claim_modal(MODAL_EVOLUTION):
		return false
	_evolution_screen_active = true
	_combat_controls_before_skill_tree = false
	_active_evolution_request = request
	_active_evolution_request_id = request.request_id
	_active_evolution_upgrade_id = &""
	if is_instance_valid(combat_hud):
		combat_hud.set_player_controls_enabled(false)
	_begin_evolution_pause()
	_show_evolution_feedback(request)
	var tree := get_tree()
	if tree == null:
		_close_evolution_overlay_for_cleanup()
		return false
	await tree.create_timer(maxf(evolution_feedback_duration, 0.001)).timeout
	if not is_inside_tree() or _ui_mode != RunUIMode.COMBAT:
		_close_evolution_overlay_for_cleanup()
		return false
	evolution_feedback.hide()
	var choice: Dictionary = GameManager.get_progression_choice_for_request(request)
	if choice.is_empty() or (choice.get("choices", []) as Array).size() != 2:
		_close_evolution_overlay_for_cleanup()
		return false
	if not skill_evolution_overlay.present(
		request,
		choice,
		skill_evolution_overlay.reduced_motion,
		):
		_close_evolution_overlay_for_cleanup()
		return false
	return true


func is_evolution_screen_active() -> bool:
	return _evolution_screen_active


func _show_evolution_feedback(request: EvolutionRequest) -> void:
	var character_state: CharacterRunState = GameManager.get_character_state(
		request.character_id
	)
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
	_active_evolution_request = null
	_active_evolution_request_id = &""
	_active_evolution_upgrade_id = &""
	if is_instance_valid(evolution_feedback):
		evolution_feedback.hide()
	_restore_evolution_pause()
	_release_modal(MODAL_EVOLUTION)
	evolution_choice_resolved.emit(request_id, upgrade_id)


func _on_skill_evolution_confirmation_requested(
		request_id: StringName,
		upgrade_id: StringName
	) -> void:
	if not _evolution_screen_active \
			or request_id != _active_evolution_request_id:
		skill_evolution_overlay.resolve_confirmation(
			false,
			"Cette évolution n’est plus active.",
		)
		return
	var choice: Dictionary = GameManager.get_progression_choice_for_request(
		_active_evolution_request
	)
	var upgrade_is_available := false
	for value in choice.get("choices", []) as Array:
		var upgrade := value as SkillUpgradeData
		if upgrade != null and upgrade.upgrade_id == upgrade_id:
			upgrade_is_available = true
			break
	if choice.is_empty() \
			or StringName(choice.get("character_id", &"")) == &"" \
			or not upgrade_is_available:
		skill_evolution_overlay.resolve_confirmation(
			false,
			"Ce choix ne correspond plus à la branche active.",
		)
		return
	var accepted: bool = GameManager.choose_progression_upgrade(
		StringName(choice.get("character_id", &"")),
		StringName(choice.get("spell_id", choice.get("discipline_id", &""))),
		int(choice.get("rank", 0)),
		upgrade_id,
	)
	if not accepted:
		skill_evolution_overlay.resolve_confirmation(
			false,
			"Les prérequis de cette évolution ne sont plus valides.",
		)
		return
	_active_evolution_upgrade_id = upgrade_id
	skill_evolution_overlay.resolve_confirmation(true)


func _on_skill_evolution_confirmation_finished(
		request_id: StringName,
		upgrade_id: StringName
	) -> void:
	if not _evolution_screen_active \
			or request_id != _active_evolution_request_id \
			or upgrade_id != _active_evolution_upgrade_id:
		return
	skill_evolution_overlay.close_overlay()
	_evolution_screen_active = false
	_active_evolution_request = null
	_active_evolution_request_id = &""
	_active_evolution_upgrade_id = &""
	_restore_evolution_pause()
	_release_modal(MODAL_EVOLUTION)
	evolution_choice_resolved.emit(request_id, upgrade_id)


func _begin_evolution_pause() -> void:
	var tree := get_tree()
	_tree_was_paused_before_evolution = tree.paused if tree != null else false
	_owns_evolution_tree_pause = tree != null
	_evolution_hud_was_visible = combat_hud.visible if is_instance_valid(combat_hud) else false
	if is_instance_valid(combat_hud):
		combat_hud.hide()
	if tree != null:
		tree.paused = true


func _restore_evolution_pause() -> void:
	var tree := get_tree()
	if _owns_evolution_tree_pause and tree != null:
		tree.paused = _tree_was_paused_before_evolution
	_owns_evolution_tree_pause = false
	_tree_was_paused_before_evolution = false
	if is_instance_valid(combat_hud):
		combat_hud.visible = _evolution_hud_was_visible
	_evolution_hud_was_visible = false


func _close_evolution_overlay_for_cleanup() -> void:
	if is_instance_valid(skill_evolution_overlay):
		skill_evolution_overlay.close_overlay()
	if is_instance_valid(evolution_feedback):
		evolution_feedback.hide()
	_evolution_screen_active = false
	_active_evolution_request = null
	_active_evolution_request_id = &""
	_active_evolution_upgrade_id = &""
	_restore_evolution_pause()
	_release_modal(MODAL_EVOLUTION)


func _on_pause_return_to_title_requested(_reason: StringName) -> void:
	close_pause_menu()
	GameManager.return_to_title()
