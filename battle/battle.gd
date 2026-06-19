# battle/battle.gd
# ============================================================
# BATTLE — Chef d'orchestre. Combat complet : joueur + IA + fin de combat.
# ============================================================

extends Node2D

@export var grid_cols: int = 20
@export var grid_rows: int = 14

# Logique
var grid: GridData
var pathfinder: Pathfinder
var spell_caster: SpellCaster
var enemy_ai: EnemyAI
var turn_queue: TurnQueue
var units: Array = []

# Visuel
var grid_view: Node2D
var camera: Camera2D
var _unit_views: Dictionary = {}

# Contrôle
var turn_state: TurnState
var action_bar: CanvasLayer

# État de fin de combat.
var _battle_over: bool = false

const MOVE_COLOR   = Color(0.3, 0.9, 0.4, 0.35)
const ATTACK_COLOR = Color(0.95, 0.3, 0.3, 0.45)
const SPELL_COLOR  = Color(0.3, 0.55, 1.0, 0.40)

func _ready() -> void:
	_setup_logic()
	_setup_view()
	_setup_camera()
	_setup_ui()
	_setup_state()
	_spawn_units()
	_start_battle()

# ============================================================
# MISE EN PLACE
# ============================================================

func _setup_logic() -> void:
	grid = GridData.new(grid_cols, grid_rows)
	pathfinder = Pathfinder.new(grid)
	spell_caster = SpellCaster.new(grid, pathfinder)
	enemy_ai = EnemyAI.new(grid, pathfinder)

func _setup_view() -> void:
	grid_view = Node2D.new()
	grid_view.set_script(load("res://battle/grid_view.gd"))
	grid_view.name = "GridView"
	add_child(grid_view)
	grid_view.setup(grid)
	grid_view.cell_clicked.connect(_on_cell_clicked)
	grid_view.cell_hovered.connect(_on_cell_hovered)

func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var pixel_size = grid_view.get_pixel_size()
	camera.position = pixel_size / 2.0
	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / pixel_size.x
	var zoom_y = viewport_size.y / pixel_size.y
	var zoom_factor = min(zoom_x, zoom_y) * 0.9
	camera.zoom = Vector2(zoom_factor, zoom_factor)

func _setup_ui() -> void:
	action_bar = CanvasLayer.new()
	action_bar.set_script(load("res://ui/action_bar.gd"))
	add_child(action_bar)
	action_bar.move_pressed.connect(_on_move_pressed)
	action_bar.attack_pressed.connect(_on_attack_pressed)
	action_bar.spell_pressed.connect(_on_spell_pressed)
	action_bar.end_turn_pressed.connect(_on_end_turn_pressed)

func _setup_state() -> void:
	turn_state = TurnState.new()
	turn_state.request_show_move_range.connect(_on_request_show_move_range)
	turn_state.request_show_attack_range.connect(_on_request_show_attack_range)
	turn_state.request_show_spell_range.connect(_on_request_show_spell_range)
	turn_state.request_clear_highlights.connect(_on_request_clear_highlights)
	turn_state.request_move_to.connect(_on_request_move_to)
	turn_state.request_attack.connect(_on_request_attack)
	turn_state.request_cast_spell.connect(_on_request_cast_spell)

# Remplace UNIQUEMENT la fonction _spawn_units() dans ton battle.gd par ceci.
# (le reste du fichier ne change pas)

func _spawn_units() -> void:
	# On charge les unités depuis leurs Resources (.tres).
	var chevalier_data = load("res://data/units/chevalier.tres")
	var mage_data      = load("res://data/units/mage.tres")
	var gobelin_data   = load("res://data/units/gobelin.tres")

	# On crée les Unit à partir des données.
	var chevalier = Unit.from_data(chevalier_data)
	var mage      = Unit.from_data(mage_data)
	var gob1      = Unit.from_data(gobelin_data)
	var gob2      = Unit.from_data(gobelin_data)   # deuxième gobelin (même data)

	# On renomme les gobelins pour les distinguer.
	gob1.unit_name = "Gobelin A"
	gob2.unit_name = "Gobelin B"

	# Placement sur la grille.
	_place(chevalier, Vector2i(2, 6))
	_place(mage,      Vector2i(2, 8))
	_place(gob1, Vector2i(grid_cols - 3, 6))
	_place(gob2, Vector2i(grid_cols - 3, 8))

	units = [chevalier, mage, gob1, gob2]

func _place(unit: Unit, pos: Vector2i) -> void:
	grid.set_unit(pos, unit)
	unit.grid_pos = pos
	unit.died.connect(_on_unit_died)
	_create_unit_view(unit)

func _create_unit_view(unit: Unit) -> void:
	var view = preload("res://battle/unit_view.tscn").instantiate()
	grid_view.add_child(view)
	view.setup(unit)
	view.position = grid_view.grid_to_world(unit.grid_pos)
	_unit_views[unit] = view

func _start_battle() -> void:
	turn_queue = TurnQueue.new()
	turn_queue.setup(units)
	turn_queue.turn_started.connect(_on_turn_started)
	turn_queue.round_started.connect(_on_round_started)
	turn_queue.start()

# ============================================================
# DÉBUT DE TOUR
# ============================================================

func _on_turn_started(unit: Unit) -> void:
	if _battle_over:
		return

	_update_active_highlight(unit)
	action_bar.update_info(unit)
	action_bar.build_spell_buttons(unit)

	if unit.team == 1:
		# Tour ennemi : l'IA joue.
		turn_state.begin_enemy_turn()
		action_bar.set_player_controls_enabled(false)
		await _run_enemy_turn(unit)
		# Après le tour ennemi, on passe au suivant (si le combat continue).
		if not _battle_over:
			turn_queue.advance()
	else:
		# Tour joueur.
		turn_state.begin_player_turn()
		action_bar.set_player_controls_enabled(true)
		action_bar.set_active_mode("")

func _update_active_highlight(active_unit: Unit) -> void:
	for unit in _unit_views:
		var view = _unit_views[unit]
		if is_instance_valid(view):
			view.set_active(unit == active_unit)

# ============================================================
# TOUR DE L'IA
# ============================================================

func _run_enemy_turn(enemy: Unit) -> void:
	# Petite pause avant que l'ennemi agisse (lisibilité).
	await get_tree().create_timer(0.3).timeout

	# L'IA décide son plan.
	var plan = enemy_ai.decide(enemy, units)

	# On exécute chaque action du plan dans l'ordre.
	for action in plan:
		if _battle_over:
			return
		match action["type"]:
			"move":
				await _execute_ai_move(enemy, action["path"])
			"attack":
				await _execute_ai_attack(enemy, action["target"])
		await get_tree().create_timer(0.2).timeout

# Déplace l'ennemi le long du chemin décidé par l'IA.
func _execute_ai_move(enemy: Unit, path: Array) -> void:
	if path.size() < 2:
		return
	var destination = path[path.size() - 1]
	var cost = path.size() - 1
	enemy.spend_mp(cost)
	grid.move_unit(enemy.grid_pos, destination)
	enemy.grid_pos = destination
	await _animate_move(enemy, path)

# L'ennemi attaque une cible.
func _execute_ai_attack(enemy: Unit, target: Unit) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return
	if not grid.are_adjacent(enemy.grid_pos, target.grid_pos):
		return
	enemy.spend_ap(1)
	target.take_damage(enemy.get_attack())
	await _animate_attack(enemy, target)

# ============================================================
# BOUTONS JOUEUR
# ============================================================

func _on_move_pressed() -> void:
	turn_state.on_move_button()
	_refresh_mode_button()

func _on_attack_pressed() -> void:
	turn_state.on_attack_button()
	_refresh_mode_button()

func _on_spell_pressed(spell: Spell) -> void:
	turn_state.on_spell_selected(spell)
	_refresh_mode_button()

func _on_end_turn_pressed() -> void:
	grid_view.clear_highlights()
	turn_queue.advance()

func _refresh_mode_button() -> void:
	match turn_state.current:
		TurnState.State.MOVE:
			action_bar.set_active_mode("move")
		TurnState.State.TARGET_MELEE:
			action_bar.set_active_mode("attack")
		TurnState.State.TARGET_SPELL:
			action_bar.set_active_mode("spell", turn_state.selected_spell)
		_:
			action_bar.set_active_mode("")

# ============================================================
# CLICS + ANNULATION
# ============================================================

func _on_cell_clicked(cell: Vector2i) -> void:
	turn_state.on_cell_clicked(cell)

func _on_cell_hovered(_cell: Vector2i) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		turn_state.on_cancel()
		action_bar.set_active_mode("")

# ============================================================
# INTENTIONS — DÉPLACEMENT
# ============================================================

func _on_request_show_move_range() -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	grid_view.clear_highlights()
	grid_view.highlight(pathfinder.get_reachable(unit.grid_pos, unit.current_mp, unit), MOVE_COLOR)

func _on_request_clear_highlights() -> void:
	grid_view.clear_highlights()

func _on_request_move_to(cell: Vector2i) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	if not pathfinder.get_reachable(unit.grid_pos, unit.current_mp, unit).has(cell):
		return
	var path = pathfinder.find_path(unit.grid_pos, cell, unit)
	if path.size() < 2:
		return
	if not unit.spend_mp(path.size() - 1):
		return
	grid.move_unit(unit.grid_pos, cell)
	unit.grid_pos = cell
	turn_state.begin_animating()
	await _animate_move(unit, path)
	turn_state.end_animating()
	action_bar.update_info(unit)

func _animate_move(unit: Unit, path: Array) -> void:
	var view = _unit_views[unit]
	if not is_instance_valid(view):
		return
	for i in range(1, path.size()):
		var target_pos = grid_view.grid_to_world(path[i])
		var tween = create_tween()
		tween.tween_property(view, "position", target_pos, 0.15)
		await tween.finished

# ============================================================
# INTENTIONS — ATTAQUE
# ============================================================

func _on_request_show_attack_range() -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	grid_view.clear_highlights()
	grid_view.highlight(_get_attackable_cells(unit), ATTACK_COLOR)

func _get_attackable_cells(unit: Unit) -> Array:
	var result: Array = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var pos = unit.grid_pos + dir
		if not grid.is_valid(pos):
			continue
		var target = grid.get_unit(pos)
		if target != null and target.team != unit.team:
			result.append(pos)
	return result

func _on_request_attack(cell: Vector2i) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	if not _get_attackable_cells(unit).has(cell):
		return
	if unit.current_ap < 1:
		return
	var target = grid.get_unit(cell)
	if target == null:
		return
	unit.spend_ap(1)
	target.take_damage(unit.get_attack())
	turn_state.begin_animating()
	await _animate_attack(unit, target)
	turn_state.end_animating()
	action_bar.update_info(unit)

func _animate_attack(unit: Unit, target: Unit) -> void:
	var view = _unit_views[unit]
	if not is_instance_valid(view):
		return
	var start = grid_view.grid_to_world(unit.grid_pos)
	var toward = grid_view.grid_to_world(target.grid_pos)
	var bump = start.lerp(toward, 0.4)
	var tween = create_tween()
	tween.tween_property(view, "position", bump, 0.1)
	tween.tween_property(view, "position", start, 0.1)
	await tween.finished

# ============================================================
# INTENTIONS — SORTS
# ============================================================

func _on_request_show_spell_range(spell: Spell) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	grid_view.clear_highlights()
	grid_view.highlight(spell_caster.get_targetable_cells(unit, spell), SPELL_COLOR)

func _on_request_cast_spell(spell: Spell, cell: Vector2i) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	if unit.current_ap < spell.ap_cost:
		return
	if not spell_caster.is_valid_target(unit, spell, cell):
		return
	unit.spend_ap(spell.ap_cost)
	spell_caster.cast(unit, spell, cell)
	grid_view.queue_redraw()
	action_bar.update_info(unit)
	turn_state.set_state(TurnState.State.IDLE)
	action_bar.set_active_mode("")

# ============================================================
# FIN DE COMBAT
# ============================================================

func _on_round_started(number: int) -> void:
	print("\n========== ROUND %d ==========" % number)

func _on_unit_died(unit: Unit) -> void:
	grid.clear_unit(unit.grid_pos)
	turn_queue.on_unit_died(unit)
	print("%s est vaincu." % unit.unit_name)
	_check_battle_end()

# Vérifie si un camp est éliminé.
func _check_battle_end() -> void:
	var heroes_alive = turn_queue.count_living_in_team(0)
	var enemies_alive = turn_queue.count_living_in_team(1)

	if heroes_alive == 0:
		_end_battle(false)
	elif enemies_alive == 0:
		_end_battle(true)

# Termine le combat avec un écran Victoire/Défaite.
func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	grid_view.clear_highlights()
	action_bar.set_player_controls_enabled(false)
	_show_end_screen(victory)

# Affiche un panneau de fin simple.
func _show_end_screen(victory: bool) -> void:
	var layer = CanvasLayer.new()
	add_child(layer)

	var panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.7)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	layer.add_child(panel)

	var label = Label.new()
	label.text = "VICTOIRE !" if victory else "DÉFAITE"
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(0.3, 1, 0.4) if victory else Color(1, 0.3, 0.3))
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -200
	label.offset_top = -40
	label.size = Vector2(400, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(label)

	print("\n===== COMBAT TERMINÉ : %s =====" % ("VICTOIRE" if victory else "DÉFAITE"))
