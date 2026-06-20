# battle/battle.gd
# ============================================================
# BATTLE — Chef d'orchestre. Combat complet : joueur + IA + terrain + statuts.
# ============================================================

extends Node2D

@export var grid_cols: int = 20
@export var grid_rows: int = 14

# La salle à charger. Pour l'instant on en assigne une en dur dans _ready.
# Plus tard, le GameManager la fournira.
@export var room_data: RoomData = null

# Logique
var grid: GridData
var pathfinder: Pathfinder
var spell_caster: SpellCaster
var terrain_effects: TerrainEffects
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

# Fin de combat
var _battle_over: bool = false

const MOVE_COLOR   = Color(0.3, 0.9, 0.4, 0.35)
const ATTACK_COLOR = Color(0.95, 0.3, 0.3, 0.45)
const SPELL_COLOR  = Color(0.3, 0.55, 1.0, 0.40)
const AOE_COLOR    = Color(1.0, 0.5, 0.1, 0.5)

func _ready() -> void:
	_setup_logic()
	_import_terrain_from_tilemap()
	_setup_view()
	_setup_camera()
	_setup_ui()
	_setup_state()
	# La salle vient du run en cours.
	room_data = GameManager.get_current_room()
	if room_data == null:
		push_error("Aucune salle fournie par le GameManager.")
		return
	_spawn_units()
	_start_battle()

# ============================================================
# MISE EN PLACE
# ============================================================

func _setup_logic() -> void:
	grid = GridData.new(grid_cols, grid_rows)
	pathfinder = Pathfinder.new(grid)
	terrain_effects = TerrainEffects.new(grid)
	spell_caster = SpellCaster.new(grid, pathfinder, terrain_effects)
	enemy_ai = EnemyAI.new(grid, pathfinder)
	# ============================================================
# IMPORT DU TERRAIN DESSINÉ (TileMapLayer → GridData)
# Lit le TileMapLayer "TerrainLayer" une fois au démarrage et
# traduit chaque case en CellType logique via le custom data
# "cell_type". Ensuite, GridData fait foi.
# ============================================================

func _import_terrain_from_tilemap() -> void:
	var layer = get_node_or_null("TerrainLayer")
	if layer == null:
		return

	for cell in layer.get_used_cells():
		var grid_pos = Vector2i(cell.x, cell.y)
		if not grid.is_valid(grid_pos):
			continue
		var tile_data = layer.get_cell_tile_data(cell)
		if tile_data == null:
			continue
		var type_name = tile_data.get_custom_data("cell_type")
		var cell_type = _cell_type_from_string(type_name)
		grid.set_type(grid_pos, cell_type)

func _cell_type_from_string(type_name: String) -> GridData.CellType:
	match type_name:
		"NORMAL": return GridData.CellType.NORMAL
		"WALL":   return GridData.CellType.WALL
		"HOLE":   return GridData.CellType.HOLE
		"LAVA":   return GridData.CellType.LAVA
		"ICE":    return GridData.CellType.ICE
		"SHADOW": return GridData.CellType.SHADOW
		"RUNE":   return GridData.CellType.RUNE
		_:        return GridData.CellType.NORMAL

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

func _spawn_units() -> void:
	units = []
	_spawn_heroes()
	_spawn_enemies()

# --- Héros : placement auto pour l'instant (déploiement manuel plus tard) ---
# --- Héros : EMPRUNTÉS au GameManager (persistent entre les salles) ---
# --- Héros : EMPRUNTÉS au GameManager (persistent entre les salles) ---
func _spawn_heroes() -> void:
	# Zone de déploiement : vient de la salle, sinon défaut à gauche.
	var zone = []
	if room_data != null and room_data.hero_spawn_zone.size() > 0:
		zone = room_data.hero_spawn_zone.duplicate()
	else:
		zone = [Vector2i(2, 6), Vector2i(2, 8)]

	# On récupère les héros vivants du run.
	var run_heroes = GameManager.get_living_heroes()

	# Placement auto sur les cases de la zone.
	for i in run_heroes.size():
		if i < zone.size():
			var hero = run_heroes[i]
			# On recharge PA/PM pour le nouveau combat,
			# mais PAS les HP (pas de regen entre les salles).
			hero.current_ap = hero.max_ap.get_int()
			hero.current_mp = hero.max_mp.get_int()
			_place(hero, zone[i])
			units.append(hero)

# --- Ennemis : viennent du RoomData, placés aléatoirement dans leur zone ---
func _spawn_enemies() -> void:
	if room_data == null:
		push_warning("Aucune RoomData assignée : pas d'ennemis.")
		return

	# On copie la zone pour piocher dedans sans répétition.
	var available = room_data.enemy_spawn_zone.duplicate()
	available.shuffle()

	var index = 0
	for enemy_data in room_data.enemies:
		if index >= available.size():
			push_warning("Pas assez de cases dans enemy_spawn_zone pour tous les ennemis.")
			break
		var enemy = Unit.from_data(enemy_data)
		_place(enemy, available[index])
		units.append(enemy)
		index += 1

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

	# 1. Effet de terrain en début de tour (lave, feu...).
	terrain_effects.on_turn_start(unit)

	# 2. Statuts : applique leurs effets (poison, regen, slow, stun).
	var is_stunned = unit.process_statuses()

	# 3. Morte des dégâts (terrain ou poison) ?
	if not unit.is_alive:
		unit.tick_statuses()
		if not _battle_over:
			turn_queue.advance()
		return

	# 4. Stun : l'unité saute son tour.
	if is_stunned:
		print("%s est stun et passe son tour." % unit.unit_name)
		unit.tick_statuses()
		await get_tree().create_timer(0.6).timeout
		if not _battle_over:
			turn_queue.advance()
		return

	# 5. Déroulement normal.
	_update_active_highlight(unit)
	action_bar.update_info(unit)
	action_bar.build_spell_buttons(unit)

	if unit.team == 1:
		turn_state.begin_enemy_turn()
		action_bar.set_player_controls_enabled(false)
		await _run_enemy_turn(unit)
		unit.tick_statuses()
		if not _battle_over:
			turn_queue.advance()
	else:
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
	await get_tree().create_timer(0.3).timeout
	var plan = enemy_ai.decide(enemy, units)
	for action in plan:
		if _battle_over:
			return
		match action["type"]:
			"move":
				await _execute_ai_move(enemy, action["path"])
			"attack":
				await _execute_ai_attack(enemy, action["target"])
		await get_tree().create_timer(0.2).timeout

func _execute_ai_move(enemy: Unit, path: Array) -> void:
	if path.size() < 2:
		return
	var destination = path[path.size() - 1]
	var cost = path.size() - 1
	enemy.spend_mp(cost)
	grid.move_unit(enemy.grid_pos, destination)
	enemy.grid_pos = destination
	await _animate_move(enemy, path)

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
	var unit = turn_queue.get_current_unit()
	if unit != null:
		unit.tick_statuses()
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

func _on_cell_hovered(cell: Vector2i) -> void:
	if turn_state.current != TurnState.State.TARGET_SPELL:
		return
	var spell = turn_state.selected_spell
	var unit = turn_queue.get_current_unit()
	if spell == null or unit == null:
		return
	grid_view.clear_highlights()
	var targetable = spell_caster.get_targetable_cells(unit, spell)
	grid_view.highlight(targetable, SPELL_COLOR)
	if targetable.has(cell):
		grid_view.highlight(spell_caster.get_aoe_cells(spell, cell), AOE_COLOR)

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
		terrain_effects.on_enter_cell(unit, path[i])

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
	if terrain_effects != null and number > 1:
		terrain_effects.tick_all_effects()
		grid_view.queue_redraw()

func _on_unit_died(unit: Unit) -> void:
	grid.clear_unit(unit.grid_pos)
	turn_queue.on_unit_died(unit)
	print("%s est vaincu." % unit.unit_name)
	_check_battle_end()

func _check_battle_end() -> void:
	var heroes_alive = turn_queue.count_living_in_team(0)
	var enemies_alive = turn_queue.count_living_in_team(1)
	if heroes_alive == 0:
		_end_battle(false)
	elif enemies_alive == 0:
		_end_battle(true)

func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	grid_view.clear_highlights()
	action_bar.set_player_controls_enabled(false)
	_show_end_screen(victory)

	# On laisse le joueur voir l'écran un instant, puis on prévient le run.
	await get_tree().create_timer(1.5).timeout
	if victory:
		GameManager.on_battle_won()
	else:
		GameManager.on_battle_lost()
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
