# battle/battle.gd
# ============================================================
# BATTLE — Chef d'orchestre d'UN combat.
# Assemble : logique (grille, pathfinding, sorts, terrain, IA) + visuel
# (grille, sprites, caméra) + contrôle (états de tour, barre d'action).
#
# RÔLE : gérer un seul combat, du spawn à la victoire/défaite.
# Ce qu'il NE fait PAS : gérer le run (ça, c'est le GameManager).
# Les héros sont EMPRUNTÉS au GameManager (ils persistent entre salles).
# ============================================================

extends Node2D

@export var grid_cols: int = 20
@export var grid_rows: int = 14

# La salle est fournie par le GameManager au démarrage.
@export var room_data: RoomData = null

# --- Logique ---
var grid: GridData
var pathfinder: Pathfinder
var spell_caster: SpellCaster
var terrain_effects: TerrainEffects
var enemy_ai: EnemyAI
var turn_queue: TurnQueue
var units: Array = []

# Exécuteur du tour ennemi (déroulé de l'IA). Logique extraite par composition.
var _enemy_turn: EnemyTurnRunner = null

# --- Visuel ---
var grid_view: Node2D
var camera: Camera2D
var _unit_views: Dictionary = {}

# --- Contrôle ---
var turn_state: TurnState
var action_bar: CanvasLayer
var inspect_panel: CanvasLayer
var player_combat_log: CanvasLayer
var keyword_tooltip_layer: CanvasLayer

# --- Fin de combat ---
var _battle_over: bool = false

# --- Phase de déploiement (placement manuel des héros, façon Dofus) ---
# La logique vit dans son propre contrôleur (composition). battle.gd l'instancie,
# route les clics vers lui et lance le combat à la fin (deployment_completed).
var _deployment: DeploymentController = null

# --- Salle-situation (optionnel) — instancié seulement si la salle est configurée.
var _situation: SituationRoomController = null

const MOVE_COLOR   = Color(0.3, 0.9, 0.4, 0.35)
const ATTACK_COLOR = Color(0.95, 0.3, 0.3, 0.45)
const SPELL_COLOR  = Color(0.3, 0.55, 1.0, 0.40)
const AOE_COLOR    = Color(1.0, 0.5, 0.1, 0.5)

# Durée d'affichage de l'écran de fin avant de rendre la main au run.
const END_SCREEN_DELAY := 1.5

func _ready() -> void:
	# La salle vient du run en cours. On la lit AVANT de construire la logique,
	# pour pouvoir, plus tard, adapter la grille à la salle si besoin.
	room_data = GameManager.get_current_room()
	if room_data == null:
		push_error("Aucune salle fournie par le GameManager.")
		return

	_setup_logic()
	_import_terrain_from_tilemap()
	_setup_view() 
	EventBus.battle_view_ready.emit(grid_view)
	_setup_camera()
	_setup_ui()
	_setup_state()
	# _spawn_units() pose les ennemis puis lance la phase de déploiement.
	# C'est la fin du déploiement (ou le secours auto) qui appellera
	# _start_battle() : on ne le lance donc PAS directement ici.
	_spawn_units()

# ============================================================
# MISE EN PLACE — LOGIQUE
# ============================================================

func _setup_logic() -> void:
	grid = GridData.new(grid_cols, grid_rows)
	pathfinder = Pathfinder.new(grid)
	terrain_effects = TerrainEffects.new(grid)
	spell_caster = SpellCaster.new(grid, pathfinder, terrain_effects)
	enemy_ai = EnemyAI.new(grid, pathfinder, spell_caster)
	# Exécuteur du tour ennemi (Node : a besoin de get_tree() pour cadencer).
	# Lit les systèmes/vue/animations de battle au moment du run, pas avant.
	_enemy_turn = EnemyTurnRunner.new()
	add_child(_enemy_turn)
	_enemy_turn.setup(self)
	# Contrôleur de la phase de déploiement (placement manuel des héros).
	_deployment = DeploymentController.new()
	add_child(_deployment)
	_deployment.setup(self)
	_deployment.deployment_completed.connect(_start_battle)
	# Salle-situation : uniquement si la RoomData la configure (totem defini).
	# battle ne fait que l'instancier ; toute la logique vit dans le controleur.
	if room_data != null and room_data.situation_totem != null:
		_situation = SituationRoomController.new()
		add_child(_situation)
		_situation.setup(self, {
			"totem_data": room_data.situation_totem,
			"spawn_data": room_data.situation_spawn,
			"totem_cell": room_data.situation_totem_cell,
			"spawn_period": room_data.situation_spawn_period,
			"lava_effect": room_data.situation_lava_effect,
			"lava_origin": room_data.situation_lava_origin,
			"lava_cap": room_data.situation_lava_cap,
		})

# ============================================================
# IMPORT DU TERRAIN DESSINÉ (TileMapLayer → GridData)
# Lit le TileMapLayer "TerrainLayer" une fois au démarrage et traduit
# chaque case en CellType logique via le custom data "cell_type".
# Ensuite, GridData fait foi : plus personne ne lit le TileMap.
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

# ============================================================
# MISE EN PLACE — VISUEL & CONTRÔLE
# ============================================================

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
	action_bar.awakening_pressed.connect(_on_awakening_pressed)
	action_bar.end_turn_pressed.connect(_on_end_turn_pressed)

	inspect_panel = CanvasLayer.new()
	inspect_panel.set_script(load("res://ui/inspect_panel.gd"))
	add_child(inspect_panel)

	player_combat_log = CanvasLayer.new()
	player_combat_log.set_script(load("res://ui/player_combat_log.gd"))
	add_child(player_combat_log)

	keyword_tooltip_layer = CanvasLayer.new()
	keyword_tooltip_layer.set_script(load("res://ui/keyword_tooltip_layer.gd"))
	add_child(keyword_tooltip_layer)

func _setup_state() -> void:
	turn_state = TurnState.new()
	turn_state.request_show_move_range.connect(_on_request_show_move_range)
	turn_state.request_show_attack_range.connect(_on_request_show_attack_range)
	turn_state.request_show_spell_range.connect(_on_request_show_spell_range)
	turn_state.request_clear_highlights.connect(_on_request_clear_highlights)
	turn_state.request_move_to.connect(_on_request_move_to)
	turn_state.request_attack.connect(_on_request_attack)
	turn_state.request_cast_spell.connect(_on_request_cast_spell)

# ============================================================
# SPAWN DES UNITÉS
# ============================================================

func _spawn_units() -> void:
	units = []
	# Les ennemis sont posés automatiquement (placement aléatoire dans leur zone).
	_spawn_enemies()
	# Les héros, eux, sont placés PAR LE JOUEUR (phase de déploiement).
	_deployment.start()

# --- Ennemis : viennent du RoomData, placés aléatoirement dans leur zone. ---
func _spawn_enemies() -> void:
	if room_data == null:
		push_warning("Aucune RoomData assignée : pas d'ennemis.")
		return

	var available = room_data.enemy_spawn_zone.duplicate()
	available.shuffle()

	for enemy_data in room_data.enemies:
		if enemy_data == null:
			push_warning("Un ennemi de la salle est null : ignoré.")
			continue
		var spawn_cell = _resolve_spawn_cell(available, enemy_data.unit_name)
		if spawn_cell == Vector2i(-1, -1):
			push_warning("Plus de case libre pour %s." % enemy_data.unit_name)
			break
		var enemy = Unit.from_data(enemy_data)
		_place(enemy, spawn_cell)
		units.append(enemy)

# Pioche la première case LIBRE d'une liste (et la retire de la liste).
# "Libre" = valide, marchable, et sans unité dessus.
# Évite toute superposition d'unités. Modifie la liste passée (pop).
func _resolve_spawn_cell(pool: Array, who: String) -> Vector2i:
	while not pool.is_empty():
		var candidate = pool.pop_front()
		if grid.is_valid(candidate) and not grid.has_unit(candidate) \
				and grid.is_walkable(candidate):
			return candidate
	return Vector2i(-1, -1)

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
	var heroes_count := 0
	var enemies_count := 0
	for u in units:
		if u.team == 0:
			heroes_count += 1
		else:
			enemies_count += 1
	if heroes_count == 0:
		push_error("Aucun héros dans le combat : défaite immédiate.")
		_end_battle(false)
		return
	if enemies_count == 0:
		push_warning("Aucun ennemi dans la salle : victoire immédiate.")
		_end_battle(true)
		return

	# Connexion du handler de poussée (visuel — logique dans SpellCaster)
	EventBus.unit_pushed.connect(_on_unit_pushed)

	# Les energies et chassis sont prepares par le run (draft d'avant-combat).
	_reset_combat_resources()
	_launch_combat()


func _reset_combat_resources() -> void:
	for unit in units:
		if unit != null and unit.team == 0 and unit.has_method("reset_combat_resources"):
			unit.reset_combat_resources()

func _launch_combat() -> void:
	turn_queue = TurnQueue.new()
	turn_queue.setup(units)
	turn_queue.turn_started.connect(_on_turn_started)
	turn_queue.round_started.connect(_on_round_started)
	turn_queue.start()

# ============================================================
# HANDLER POUSSÉE VISUELLE
# ============================================================

func _on_unit_pushed(unit: Unit, _from: Vector2i, to_pos: Vector2i, _collision: bool) -> void:
	_sync_unit_terrain(unit)
	var view = _unit_views.get(unit)
	if is_instance_valid(view):
		view.position = grid_view.grid_to_world(to_pos)

func _on_turn_started(unit: Unit) -> void:
	if _battle_over:
		return

	# 1. Effet de terrain en début de tour (lave, feu...).
	terrain_effects.on_turn_start(unit)
	_sync_unit_terrain(unit)

	# 2. Statuts : applique leurs effets (poison, regen, slow, stun).
	var is_stunned = unit.process_statuses()

	# 3. Mort des dégâts (terrain ou poison) en début de tour ?
	if not unit.is_alive:
		unit.tick_statuses()
		if not _battle_over:
			turn_queue.advance()
		return

	# 4. Stun : l'unité saute son tour.
	if is_stunned:
		DebugLogger.debug(DebugLogger.LogCategory.TURN, "%s est stun, passe son tour" % unit.unit_name)
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
		await _enemy_turn.run(unit)
		unit.tick_statuses()
		if not _battle_over:
			turn_queue.advance()
	else:
		turn_state.begin_player_turn()
		action_bar.set_player_controls_enabled(true)
		action_bar.set_active_mode("")

func _sync_unit_terrain(unit: Unit) -> void:
	if unit == null or terrain_effects == null:
		return
	if unit.has_method("set_current_terrain_effect"):
		unit.set_current_terrain_effect(terrain_effects.get_effect_data(unit.grid_pos))

func _update_active_highlight(active_unit: Unit) -> void:
	for unit in _unit_views:
		var view = _unit_views[unit]
		if is_instance_valid(view):
			view.set_active(unit == active_unit)

# ============================================================
# BOUTONS JOUEUR
# ============================================================

func _on_move_pressed() -> void:
	turn_state.on_move_button()
	_refresh_mode_button()

func _on_attack_pressed() -> void:
	turn_state.on_attack_button()
	_refresh_mode_button()

func _on_spell_pressed(spell: Spell, imprinted: bool = false) -> void:
	turn_state.on_spell_selected(spell, imprinted)
	_refresh_mode_button()

func _on_awakening_pressed() -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null or unit.team != 0:
		return
	if unit.activate_awakening():
		action_bar.update_info(unit)
		action_bar.build_spell_buttons(unit)
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
			action_bar.set_active_mode("spell", turn_state.selected_spell, turn_state.selected_spell_imprinted)
		_:
			action_bar.set_active_mode("")

# ============================================================
# CLICS + ANNULATION
# ============================================================

func _on_cell_clicked(cell: Vector2i) -> void:
	if _deployment.is_active():
		_deployment.on_cell_clicked(cell)
		return
	if turn_state.current == TurnState.State.IDLE:
		if inspect_panel != null:
			inspect_panel.show_cell(cell, grid, terrain_effects, true)
		return
	turn_state.on_cell_clicked(cell)
func _on_cell_hovered(cell: Vector2i) -> void:
	if inspect_panel != null:
		inspect_panel.show_cell(cell, grid, terrain_effects, false)
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
		if inspect_panel != null:
			inspect_panel.show_spell_preview(unit, spell, cell, grid, spell_caster, turn_state.selected_spell_imprinted)

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

# Animation de déplacement BLINDÉE contre les objets détruits.
# Une unité peut mourir en cours de route (lave via on_enter_cell) : on
# vérifie is_instance_valid(view) ET unit.is_alive avant/après chaque await.
# Sans ça : erreur "Freed Object" + tour figé (cause des freezes passés).
func _animate_move(unit: Unit, path: Array) -> void:
	var view = _unit_views.get(unit)
	if not is_instance_valid(view):
		return
	for i in range(1, path.size()):
		# L'unité a pu mourir à l'étape précédente : on s'arrête proprement.
		if not unit.is_alive or not is_instance_valid(view):
			return
		var from_pos = grid_view.grid_to_world(path[i - 1])
		var target_pos = grid_view.grid_to_world(path[i])
		view.face_direction(from_pos, target_pos)
		var tween = create_tween()
		tween.tween_property(view, "position", target_pos, 0.15)
		await tween.finished
		# La vue a pu être libérée pendant l'await.
		if not is_instance_valid(view):
			return
		terrain_effects.on_enter_cell(unit, path[i])
		_sync_unit_terrain(unit)
		# on_enter_cell a pu tuer l'unité (lave) : on stoppe le déplacement.
		if not unit.is_alive:
			return

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
	var elan_cost := 0.0
	if unit.team == 0:
		elan_cost = unit.get_basic_attack_elan_cost()
		if not unit.can_afford_elan(elan_cost):
			return
	elif unit.current_ap < 1:
		return
	var target = grid.get_unit(cell)
	if target == null:
		return
	if unit.team == 0:
		if not unit.spend_elan(elan_cost, "Attaque"):
			return
	else:
		unit.spend_ap(1)
	var result = target.take_damage(
		unit.get_attack(),
		unit,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE)
	turn_state.begin_animating()
	if result != null and not result.dodged:
		EventBus.basic_attack_performed.emit(unit, target)
	await _animate_attack(unit, target)
	turn_state.end_animating()
	action_bar.update_info(unit)

# Animation d'attaque BLINDÉE (accès .get() + vérif de validité).
func _animate_attack(unit: Unit, target: Unit) -> void:
	var view = _unit_views.get(unit)
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

func _on_request_show_spell_range(spell: Spell, _imprinted: bool = false) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	grid_view.clear_highlights()
	grid_view.highlight(spell_caster.get_targetable_cells(unit, spell), SPELL_COLOR)

func _on_request_cast_spell(spell: Spell, cell: Vector2i, imprinted: bool = false) -> void:
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	if not spell_caster.is_valid_target(unit, spell, cell):
		return
	var report = spell_caster.cast(unit, spell, cell, imprinted)
	if report.get("failed", false):
		return
	grid_view.queue_redraw()
	action_bar.update_info(unit)
	turn_state.set_state(TurnState.State.IDLE)
	action_bar.set_active_mode("")

func _on_round_started(number: int) -> void:
	DebugLogger.set_turn(number)
	DebugLogger.info(DebugLogger.LogCategory.TURN, "Round %d" % number)
	print("\n========== ROUND %d ==========" % number)
	if terrain_effects != null and number > 1:
		terrain_effects.tick_all_effects()
		grid_view.queue_redraw()

func _on_unit_died(unit: Unit) -> void:
	# Logique de combat uniquement. Le LOG ("est vaincu") est désormais produit
	# par le CombatLogger, abonné au signal unit_died du bus. battle.gd ne logge
	# plus la mort : il réagit à ses conséquences sur le terrain et le combat.
	grid.clear_unit(unit.grid_pos)
	turn_queue.on_unit_died(unit)
	_check_battle_end()

func _check_battle_end() -> void:
	var heroes_alive = turn_queue.count_living_in_team(0)
	var enemies_alive = turn_queue.count_living_in_team(1)
	if heroes_alive == 0:
		_end_battle(false)
	elif enemies_alive == 0:
		_end_battle(true)

# ============================================================
# FIN DE COMBAT
# Prévient le GameManager, qui orchestre la suite (transition + salle).
# ============================================================

func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	grid_view.clear_highlights()
	action_bar.set_player_controls_enabled(false)
	_show_end_screen(victory)

	# On laisse voir l'écran un instant, puis on rend la main au run.
	await get_tree().create_timer(END_SCREEN_DELAY).timeout
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
	
