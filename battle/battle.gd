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

signal runtime_ready(snapshot: Dictionary)

const MovementTiming = preload("res://characters/character_movement_timing.gd")
const MovementPathPreviewScript = preload("res://battle/movement_path_preview.gd")
const ArenaGeneratorScript = preload("res://core/arena_generator.gd")
const ArenaFeatureRendererScript = preload(
	"res://battle/arena_feature_renderer.gd"
)
const ArenaDirectTestConfigurationScript = preload(
	"res://addons/dungeon_draft_arena_studio/services/arena_direct_test_configuration.gd"
)
const TURN_ORDER_TIMELINE_SCENE := preload(
	"res://ui/combat/turn_order_timeline.tscn"
)
const COMBAT_PRESENTATION_STATE := preload(
	"res://battle/combat_presentation_state.gd"
)
const COMBAT_OUTCOME_OVERLAY := preload(
	"res://ui/combat/combat_outcome_overlay.gd"
)
const END_TURN_CONFIRMATION := preload(
	"res://ui/combat/end_turn_confirmation.gd"
)
const COMBAT_TARGET_FEEDBACK := preload(
	"res://battle/combat_target_feedback.gd"
)
const COMBAT_HUD_PORT := preload("res://ui/combat/combat_hud_port.gd")
const COMBAT_HIGHLIGHT_MARKER := preload(
	"res://battle/combat_highlight_marker.gd"
)

@export var grid_cols: int = 20
@export var grid_rows: int = 14

# La salle est fournie par le GameManager au démarrage.
@export var room_data: RoomData = null

## Permet de lancer une scene de carte seule pour verifier son cadrage. Cette
## option ne demarre ni logique de tour ni deploiement et reste desactivee sur
## toutes les scenes historiques.
@export var standalone_preview_without_room := false

## Remplacement strictement local des visuels historiques. Seule la scene iso
## de la premiere salle active cette option ; les UnitView et UnitData restent
## inchanges et continuent de porter toute la logique de combat.
@export var temporary_iso_placeholders := false

## Echelle appliquee aux visuels d'unites (persos) dans les salles iso.
## 1.0 = inchange (salles carrees historiques). Reduire pour des persos plus
## petits face a un decor peint. N'affecte PAS l'ombre au sol : celle-ci reste
## calee sur la case (calcul en coordonnees globales).
@export var iso_unit_view_scale := 1.0

## Materiau lumiere (golden hour) applique aux elements de gameplay (persos,
## grille) pour qu'ils se fondent dans le decor peint. Laisser vide = aucun
## eclairage ajoute (salles carrees classiques). Reglable dans l'Inspecteur.
@export var iso_gameplay_light: ShaderMaterial = null

## Cache le TerrainLayer une fois ses donnees lues (au demarrage reel du jeu),
## tout en le laissant visible/peignable dans l'editeur. A utiliser uniquement
## quand TerrainLayer ne sert qu'a stocker le cell_type (pas a afficher un sol,
## contrairement aux salles carrees classiques ou TerrainLayer EST le sol).
@export var hide_terrain_layer_after_import := false

## GridData part toutes les cases en NORMAL par defaut ; ce reglage inverse ce
## defaut pour cette salle : toute case non peinte explicitement dans
## TerrainLayer devient WALL (decor, non-interactive), seules les cases
## peintes NORMAL restent interactives. Ne touche pas les salles carrees
## classiques (WALL n'y est marque qu'a la main, le reste doit rester NORMAL).
@export var terrain_unpainted_defaults_to_wall := false

## Scene de HUD optionnelle, strictement visuelle. Quand elle est vide, le
## HUD historique ui/action_bar.gd est construit exactement comme avant.
## Une salle peut ainsi choisir une presentation sans dupliquer le combat.
@export var action_bar_scene: PackedScene = null

## Les panneaux d'inspection et d'historique restent disponibles pour les
## salles legacy, mais la premiere run de production peut les masquer afin de
## conserver une vue de combat lisible.
@export var show_auxiliary_panels := true

# --- Logique ---
var grid: GridData
var pathfinder: Pathfinder
var spell_caster: SpellCaster
var terrain_effects: TerrainEffects
var enemy_ai: EnemyAI
var encounter_runtime_state: EncounterRuntimeState = null
var encounter_formation_snapshot: Dictionary = {}
var turn_queue: TurnQueue
var units: Array = []

# Exécuteur du tour ennemi (déroulé de l'IA). Logique extraite par composition.
var _enemy_turn: EnemyTurnRunner = null
var _spell_impact_scheduler: SpellImpactScheduler = null
var _spell_resolution_pending := false
var _evolution_queue := EvolutionRequestQueue.new()
var _evolution_processing := false
var _evolution_request_counter := 0
var _trigger_sequence := 0
var _active_trigger_sequence := 0
var _action_sequence := 0
var _turn_end_committed := false
var _battle_outcome_waiting := false
var _waiting_outcome_victory := false
var _turn_start_deferred_for_evolution := false

# --- Visuel ---
var grid_view: Node2D
var camera: Camera2D
var _unit_views: Dictionary = {}
var _unit_view_parent: Node2D = null
var _movement_path_preview = null
var _arena_tile_parent: Node2D = null
var arena_dynamic_surface_layer: Node2D = null
var terrain_surface_visual_adapter: DynamicSurfaceVisualAdapter = null
var generated_arena_seed: int = 0
var _generated_arena_features: Dictionary = {}
var _arena_feature_renderer: Node = null
var _direct_test_options := {}
var runtime_ready_state := false
var runtime_ready_snapshot: Dictionary = {}

# --- Contrôle ---
var turn_state: TurnState
var action_bar: CanvasLayer
var inspect_panel: CanvasLayer
var player_combat_log: CanvasLayer
var keyword_tooltip_layer: CanvasLayer
var turn_order_timeline: TurnOrderTimeline = null
var presentation_state: CombatPresentationState = null
var _uses_persistent_action_bar := false
var _hud_port = null
var _presentation_feedback_generation := 0
var _outcome_overlay: CombatOutcomeOverlay = null
var _end_turn_confirmation: EndTurnConfirmation = null
var _skip_end_turn_confirmation := false
var _target_feedback = null

# --- Fin de combat ---
var _battle_over: bool = false
var _closing := false
var _lifecycle_generation := 0

# --- Phase de déploiement (placement manuel des héros, façon Dofus) ---
# La logique vit dans son propre contrôleur (composition). battle.gd l'instancie,
# route les clics vers lui et lance le combat à la fin (deployment_completed).
var _deployment: DeploymentController = null

# --- Salle-situation (optionnel) — instancié seulement si la salle est configurée.

const MOVE_COLOR   = Color(0.3, 0.9, 0.4, 0.35)
const CONTROL_LIMITED_MOVE_COLOR = Color(1.0, 0.42, 0.42, 0.34)
const ATTACK_COLOR = Color(0.95, 0.3, 0.3, 0.45)
const SPELL_COLOR  = Color(0.3, 0.55, 1.0, 0.40)
const AOE_COLOR    = Color(1.0, 0.5, 0.1, 0.5)

# Durée d'affichage de l'écran de fin avant de rendre la main au run.
const END_SCREEN_DELAY := 1.5


func _is_operation_current(generation: int) -> bool:
	return generation == _lifecycle_generation \
		and not _closing \
		and is_inside_tree()


func _wait_battle_seconds_safe(seconds: float, generation: int) -> bool:
	if not _is_operation_current(generation):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	await tree.create_timer(maxf(seconds, 0.001)).timeout
	return _is_operation_current(generation)

func _ready() -> void:
	_direct_test_options = ArenaDirectTestConfigurationScript.from_tree(get_tree())
	# La salle vient du run en cours. On la lit AVANT de construire la logique,
	# pour pouvoir, plus tard, adapter la grille à la salle si besoin.
	room_data = GameManager.get_current_room()
	if room_data == null:
		if standalone_preview_without_room:
			grid = EncounterGridFactory.build_for_battle(
				null, self, grid_cols, grid_rows
			)
			_import_terrain_from_tilemap()
			_setup_view()
			EventBus.battle_view_ready.emit(grid_view)
			_setup_camera()
			_schedule_runtime_ready()
			return
		push_error("Aucune salle fournie par le GameManager.")
		return

	_setup_logic()
	_import_terrain_from_tilemap()
	_generate_arena_layout()
	terrain_effects.capture_base_state(room_data, grid)
	_setup_view() 
	_apply_direct_test_view_options()
	_setup_arena_visuals()
	_setup_dynamic_surface_visuals()
	EventBus.battle_view_ready.emit(grid_view)
	_setup_camera()
	if _direct_test_flag("hud_enabled", true):
		_setup_ui()
	_apply_accessibility_preferences()
	if _direct_test_flag("combat_enabled", true):
		_setup_state()
	# _spawn_units() pose les ennemis puis lance la phase de déploiement.
	# C'est la fin du déploiement (ou le secours auto) qui appellera
	# _start_battle() : on ne le lance donc PAS directement ici.
	if _direct_test_options.is_empty():
		_spawn_units()
	else:
		_spawn_direct_test_units()
	_schedule_runtime_ready()


func _schedule_runtime_ready() -> void:
	# The concrete painted/modular adapter finishes its assembly after super().
	# Publishing deferred therefore exposes the complete, inspectable SceneTree.
	call_deferred("_publish_runtime_ready")


func _publish_runtime_ready() -> void:
	if runtime_ready_state or _closing or not is_inside_tree():
		return
	runtime_ready_snapshot = {
		"grid_ready": grid != null,
		"pathfinder_ready": pathfinder != null,
		"camera_ready": camera != null,
		"unit_count": units.size(),
	}
	runtime_ready_state = true
	runtime_ready.emit(runtime_ready_snapshot.duplicate(true))

# ============================================================
# MISE EN PLACE — LOGIQUE
# ============================================================

func _setup_logic() -> void:
	grid = EncounterGridFactory.build_for_battle(
		room_data, self, grid_cols, grid_rows
	)
	pathfinder = Pathfinder.new(grid)
	var relic_service := GameManager.get_relic_runtime_service()
	if relic_service != null:
		pathfinder.set_voluntary_cost_modifier(
			Callable(relic_service, "modify_voluntary_transition_cost")
		)
	terrain_effects = TerrainEffects.new(grid)
	spell_caster = SpellCaster.new(grid, pathfinder, terrain_effects)
	_target_feedback = COMBAT_TARGET_FEEDBACK.new(
		grid, pathfinder, spell_caster
	)
	var encounter_definition: EncounterDefinition = (
		GameManager.get_current_encounter_definition()
	)
	if room_data != null and encounter_definition != null:
		encounter_runtime_state = EncounterRuntimeState.new()
		if not encounter_runtime_state.initialize(encounter_definition):
			push_error("EncounterDefinition invalide pour %s." % room_data.room_name)
			encounter_runtime_state = null
	spell_caster.set_encounter_runtime_state(encounter_runtime_state)
	_spell_impact_scheduler = SpellImpactScheduler.new()
	add_child(_spell_impact_scheduler)
	_spell_impact_scheduler.impact_due.connect(_on_delayed_spell_impact)
	enemy_ai = EnemyAI.new(grid, pathfinder, spell_caster)
	# Exécuteur du tour ennemi (Node : a besoin de get_tree() pour cadencer).
	# Lit les systèmes/vue/animations de battle au moment du run, pas avant.
	_enemy_turn = EnemyTurnRunner.new()
	add_child(_enemy_turn)
	_enemy_turn.setup(self)
	# Contrôleur de la phase de déploiement (placement manuel des héros).
	if _direct_test_flag("deployment_enabled", true):
		_deployment = DeploymentController.new()
		add_child(_deployment)
		_deployment.setup(self)
		_deployment.deployment_completed.connect(_start_battle)
	if not GameManager.discipline_xp_gained.is_connected(
		_on_discipline_xp_gained
	):
		GameManager.discipline_xp_gained.connect(_on_discipline_xp_gained)
	# Salle-situation : uniquement si la RoomData la configure (totem defini).
	# battle ne fait que l'instancier ; toute la logique vit dans le controleur.

# ============================================================
# IMPORT DU TERRAIN DESSINÉ (TileMapLayer → GridData)
# Lit le TileMapLayer "TerrainLayer" une fois au démarrage et traduit
# chaque case en CellType logique via le custom data "cell_type".
# Ensuite, GridData fait foi : plus personne ne lit le TileMap.
# ============================================================

func _import_terrain_from_tilemap() -> void:
	var layer := get_node_or_null("TerrainLayer")
	EncounterGridFactory.populate_base_grid(
		grid,
		room_data,
		layer,
		terrain_unpainted_defaults_to_wall,
	)

	if hide_terrain_layer_after_import and layer is CanvasItem:
		layer.visible = false

func _cell_type_from_string(type_name: String) -> GridData.CellType:
	return EncounterGridFactory.cell_type_from_string(type_name)


func _generate_arena_layout() -> void:
	_generated_arena_features.clear()
	generated_arena_seed = 0
	var generation := EncounterGridFactory.generate_arena_layout(grid, room_data)
	generated_arena_seed = int(generation.get("seed", 0))
	if not bool(generation.get("success", false)):
		return
	_generated_arena_features = generation.get("features", {})
	for cell in _generated_arena_features:
		grid.set_type(cell, _generated_arena_features[cell])

# ============================================================
# MISE EN PLACE — VISUEL & CONTRÔLE
# ============================================================

func _setup_view() -> void:
	grid_view = _find_configured_grid_view()
	if grid_view == null:
		grid_view = Node2D.new()
		grid_view.set_script(load("res://battle/grid_view.gd"))
		grid_view.name = "GridView"
		add_child(grid_view)
	grid_view.setup(grid)
	# La grille NE reçoit PAS la lumiere : elle doit rester constante (pas de
	# variation de nuages ni de teinte). Seuls les persos sont eclaires.
	grid_view.cell_clicked.connect(_on_cell_clicked)
	grid_view.cell_hovered.connect(_on_cell_hovered)
	_unit_view_parent = _find_unit_view_parent()
	_setup_movement_path_preview()


func _setup_movement_path_preview() -> void:
	_movement_path_preview = MovementPathPreviewScript.new()
	_movement_path_preview.name = "MovementPathPreview"
	var layer_parent := grid_view.get_parent() as Node2D
	if layer_parent != null \
			and _unit_view_parent != grid_view \
			and _unit_view_parent != null \
			and _unit_view_parent.get_parent() == layer_parent:
		layer_parent.add_child(_movement_path_preview)
		# Les effets de terrain precedents restent sous la fleche ; la couche des
		# unites et les personnages suivants restent au-dessus.
		layer_parent.move_child(
			_movement_path_preview,
			_unit_view_parent.get_index(),
		)
	else:
		grid_view.add_child(_movement_path_preview)
	_movement_path_preview.setup(grid_view)


func _clear_movement_path_preview() -> void:
	if is_instance_valid(_movement_path_preview):
		_movement_path_preview.clear_path()


func _setup_arena_visuals() -> void:
	# ArenaDefinition possede son renderer Studio 2.0 dans l'adaptateur de scene.
	# Le renderer historique reste reserve aux RoomData procedurales legacy.
	if room_data is ArenaDefinition:
		return
	if room_data == null or room_data.arena_visual_profile == null:
		return
	var visual_cells := {}
	for x in range(grid.cols):
		for y in range(grid.rows):
			var cell := Vector2i(x, y)
			if _generated_arena_features.has(cell) \
					or grid.get_type(cell) == GridData.CellType.NORMAL:
				visual_cells[cell] = grid.get_type(cell)
	if visual_cells.is_empty():
		return
	var feature_parent := _find_or_create_arena_tile_parent()
	_arena_feature_renderer = ArenaFeatureRendererScript.new()
	_arena_feature_renderer.name = "ArenaFeatureRenderer"
	add_child(_arena_feature_renderer)
	_arena_feature_renderer.configure(
		grid_view,
		feature_parent,
		room_data.arena_visual_profile
	)
	_arena_feature_renderer.render(visual_cells)


func _setup_dynamic_surface_visuals() -> void:
	if terrain_effects == null or terrain_effects.runtime_service == null \
			or grid_view == null:
		return
	var floor_parent := _find_or_create_arena_tile_parent(false)
	arena_dynamic_surface_layer = get_node_or_null(
		"ArenaDynamicSurfaceLayer"
	) as Node2D
	if arena_dynamic_surface_layer == null:
		arena_dynamic_surface_layer = Node2D.new()
		arena_dynamic_surface_layer.name = "ArenaDynamicSurfaceLayer"
		add_child(arena_dynamic_surface_layer)
	arena_dynamic_surface_layer.y_sort_enabled = false
	arena_dynamic_surface_layer.set_meta(
		"visual_layer", &"arena_dynamic_surface"
	)
	if floor_parent.get_parent() == self and grid_view.get_parent() == self:
		move_child(arena_dynamic_surface_layer, grid_view.get_index())
	terrain_surface_visual_adapter = DynamicSurfaceVisualAdapter.new()
	terrain_surface_visual_adapter.name = "TerrainSurfaceVisualAdapter"
	add_child(terrain_surface_visual_adapter)
	terrain_surface_visual_adapter.configure(
		terrain_effects.runtime_service,
		grid_view,
		arena_dynamic_surface_layer,
		room_data.theme_id if room_data is ArenaDefinition else &"forest"
	)


func terrain_surface_visual_report() -> Dictionary:
	var active := terrain_effects.active_surface_cells() \
		if terrain_effects != null else [] as Array[Vector2i]
	var rendered := terrain_surface_visual_adapter.rendered_cells() \
		if terrain_surface_visual_adapter != null else [] as Array[Vector2i]
	var missing: Array[Vector2i] = []
	var unexpected: Array[Vector2i] = []
	for cell in active:
		if terrain_effects.get_visual_terrain_id(cell) != &"" \
				and not rendered.has(cell):
			missing.append(cell)
	for cell in rendered:
		if not active.has(cell):
			unexpected.append(cell)
	return {
		"active_cells": active,
		"rendered_cells": rendered,
		"missing_cells": missing,
		"unexpected_cells": unexpected,
		"duplications": (
			terrain_surface_visual_adapter.renderer.actual_render_report()
				.get("rendered_terrain_node_count", 0) - rendered.size()
			if terrain_surface_visual_adapter != null else 0
		),
	}

func _find_or_create_arena_tile_parent(y_sorted := true) -> Node2D:
	if is_instance_valid(_arena_tile_parent):
		_arena_tile_parent.y_sort_enabled = y_sorted
		return _arena_tile_parent
	_arena_tile_parent = get_node_or_null("ArenaTilesLayer") as Node2D
	if _arena_tile_parent == null:
		_arena_tile_parent = Node2D.new()
		_arena_tile_parent.name = "ArenaTilesLayer"
		add_child(_arena_tile_parent)
	_arena_tile_parent.y_sort_enabled = y_sorted
	## Ordre local : fond, dalles, grille tactique, puis YSortedWorld/unites.
	## La grille et les zones de deploiement restent donc visibles et cliquables.
	if grid_view.get_parent() == self:
		move_child(_arena_tile_parent, grid_view.get_index())
	return _arena_tile_parent

func _find_configured_grid_view() -> Node2D:
	var named_view := get_node_or_null("IsoGridView") as Node2D
	if named_view != null and named_view.has_method("setup"):
		return named_view
	for candidate in get_tree().get_nodes_in_group("battle_grid_view"):
		if candidate is Node2D and is_ancestor_of(candidate) and candidate.has_method("setup"):
			return candidate
	return null

func _find_unit_view_parent() -> Node2D:
	var y_sorted_world := get_node_or_null("YSortedWorld") as Node2D
	if y_sorted_world != null:
		return y_sorted_world
	var units_layer := get_node_or_null("UnitsLayer") as Node2D
	if units_layer != null:
		return units_layer
	return grid_view

func grid_cell_to_grid_local(cell: Vector2i) -> Vector2:
	if grid_view.has_method("grid_to_local"):
		return grid_view.grid_to_local(cell)
	return grid_view.grid_to_world(cell)

func grid_cell_to_global(cell: Vector2i) -> Vector2:
	return grid_view.to_global(grid_cell_to_grid_local(cell))

func grid_cell_to_parent_local(cell: Vector2i, parent: Node2D) -> Vector2:
	return parent.to_local(grid_cell_to_global(cell))

func _setup_camera() -> void:
	camera = get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		add_child(camera)
	camera.make_current()
	_fit_camera_to_battle()
	if not get_viewport().size_changed.is_connected(_fit_camera_to_battle):
		get_viewport().size_changed.connect(_fit_camera_to_battle)

func _fit_camera_to_battle() -> void:
	if camera == null or grid_view == null:
		return
	var camera_parent := camera.get_parent() as Node2D
	if camera_parent == null:
		return
	var background := _find_battle_background()
	var frame_rect: Rect2
	if background != null and background.texture != null:
		# Le fond peint fait foi pour le cadrage ecran quand il existe : la
		# taille logique de la grille (grid_cols/grid_rows) ne sert alors plus
		# qu'au gameplay (forme du terrain, pathfinding), plus au zoom/centrage
		# camera. Ca permet un trace peint aussi grand que necessaire sans
		# jamais avoir a retoucher le cadrage visuel.
		frame_rect = _rect_in_parent(background, background.get_rect(), camera_parent)
	elif grid_view.has_method("get_map_bounds"):
		frame_rect = _rect_in_parent(grid_view, grid_view.get_map_bounds(), camera_parent)
	else:
		frame_rect = _rect_in_parent(
			grid_view,
			Rect2(Vector2.ZERO, grid_view.get_pixel_size()),
			camera_parent
		)
	if frame_rect.size.x <= 0.0 or frame_rect.size.y <= 0.0:
		return
	camera.position = frame_rect.get_center()
	var viewport_size = get_viewport_rect().size
	var zoom_x = viewport_size.x / frame_rect.size.x
	var zoom_y = viewport_size.y / frame_rect.size.y
	var zoom_factor = min(zoom_x, zoom_y) * 0.9
	camera.zoom = Vector2(zoom_factor, zoom_factor)

func _find_battle_background() -> Sprite2D:
	for path in ["ForestBackground/ForestSprite", "ForestSprite", "Background/ForestSprite"]:
		var sprite := get_node_or_null(path) as Sprite2D
		if sprite != null:
			return sprite
	# Recherche generique : un enfant direct dont le nom finit par "Background"
	# (convention "XxxBackground"), contenant un Sprite2D. Permet a toute
	# nouvelle salle iso avec un fond peint de se cadrer automatiquement, sans
	# avoir a ajouter son nom en dur ici.
	for child in get_children():
		if not child.name.ends_with("Background"):
			continue
		var sprite := _find_sprite_recursive(child)
		if sprite != null:
			return sprite
	return null

func _find_sprite_recursive(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node
	for child in node.get_children():
		var found := _find_sprite_recursive(child)
		if found != null:
			return found
	return null

func _rect_in_parent(source: Node2D, rect: Rect2, target_parent: Node2D) -> Rect2:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.end,
		rect.position + Vector2(0.0, rect.size.y),
	]
	var first := target_parent.to_local(source.to_global(corners[0]))
	var minimum := first
	var maximum := first
	for corner in corners.slice(1):
		var converted := target_parent.to_local(source.to_global(corner))
		minimum = minimum.min(converted)
		maximum = maximum.max(converted)
	return Rect2(minimum, maximum - minimum)

func _setup_ui() -> void:
	action_bar = GameManager.bind_combat_context(self)
	_uses_persistent_action_bar = action_bar != null
	if not _uses_persistent_action_bar:
		if action_bar_scene != null:
			action_bar = action_bar_scene.instantiate() as CanvasLayer
		else:
			action_bar = CanvasLayer.new()
			action_bar.set_script(load("res://ui/action_bar.gd"))
	if action_bar == null:
		push_error("La scene de HUD doit avoir un CanvasLayer pour racine.")
		return
	if not _uses_persistent_action_bar:
		add_child(action_bar)
	_hud_port = COMBAT_HUD_PORT.new(action_bar)
	var hud_contract: Dictionary = _hud_port.audit_contract()
	if not bool(hud_contract.get("valid", false)):
		push_error("HUD de combat incompatible : %s" % hud_contract)
	if not _uses_persistent_action_bar:
		_hud_port.connect_intents(self)

	inspect_panel = CanvasLayer.new()
	inspect_panel.set_script(load("res://ui/inspect_panel.gd"))
	add_child(inspect_panel)
	inspect_panel.setup(pathfinder, grid)

	player_combat_log = CanvasLayer.new()
	player_combat_log.set_script(load("res://ui/player_combat_log.gd"))
	add_child(player_combat_log)
	inspect_panel.visible = show_auxiliary_panels
	player_combat_log.visible = show_auxiliary_panels

	keyword_tooltip_layer = CanvasLayer.new()
	keyword_tooltip_layer.set_script(load("res://ui/keyword_tooltip_layer.gd"))
	add_child(keyword_tooltip_layer)

	turn_order_timeline = TURN_ORDER_TIMELINE_SCENE.instantiate()
	add_child(turn_order_timeline)
	turn_order_timeline.unit_selected.connect(_on_turn_order_unit_selected)


func _apply_accessibility_preferences() -> void:
	var reduced_motion := GameManager.is_reduced_motion_enabled()
	if _hud_port != null:
		_hud_port.set_reduced_motion(reduced_motion)
	set_reduced_motion(reduced_motion)


func set_reduced_motion(enabled: bool) -> void:
	var feedback_controller := get_node_or_null("FloatingTextSpawner")
	if feedback_controller != null \
			and feedback_controller.has_method("set_reduced_motion"):
		feedback_controller.set_reduced_motion(enabled)


func _setup_state() -> void:
	turn_state = TurnState.new()
	presentation_state = COMBAT_PRESENTATION_STATE.new()
	presentation_state.set_lock(&"battle_not_started", true)
	presentation_state.snapshot_changed.connect(
		_on_presentation_snapshot_changed
	)
	turn_state.state_changed.connect(_on_turn_state_changed)
	turn_state.request_show_move_range.connect(_on_request_show_move_range)
	turn_state.request_show_attack_range.connect(_on_request_show_attack_range)
	turn_state.request_show_spell_range.connect(_on_request_show_spell_range)
	turn_state.request_clear_highlights.connect(_on_request_clear_highlights)
	turn_state.request_move_to.connect(_on_request_move_to)
	turn_state.request_attack.connect(_on_request_attack)
	turn_state.request_cast_spell.connect(_on_request_cast_spell)
	_on_presentation_snapshot_changed(presentation_state.get_snapshot())


func get_combat_presentation_snapshot() -> Dictionary:
	return (
		presentation_state.get_snapshot()
		if presentation_state != null
		else {}
	)


func is_action_selection_active() -> bool:
	return turn_state != null and turn_state.current in [
		TurnState.State.MOVE,
		TurnState.State.TARGET_MELEE,
		TurnState.State.TARGET_SPELL,
	]


func cancel_active_selection() -> bool:
	if not is_action_selection_active():
		return false
	turn_state.on_cancel()
	if _hud_port != null:
		_hud_port.set_active_mode("")
	if is_instance_valid(inspect_panel) and inspect_panel.has_method(
		"release_transient_preview"
	):
		inspect_panel.release_transient_preview()
	return true


func set_external_interaction_lock(source: StringName, locked: bool) -> void:
	if presentation_state == null or source == &"":
		return
	if locked:
		cancel_active_selection()
	presentation_state.set_lock(StringName("external:%s" % source), locked)


func _can_accept_player_intent() -> bool:
	return presentation_state == null \
		or presentation_state.can_accept_player_intent()


func _on_turn_state_changed(
		_previous: TurnState.State,
		current: TurnState.State
	) -> void:
	if presentation_state == null:
		return
	match current:
		TurnState.State.IDLE:
			presentation_state.begin_player_turn()
		TurnState.State.MOVE:
			presentation_state.begin_targeting(&"move")
		TurnState.State.TARGET_MELEE:
			presentation_state.begin_targeting(&"attack")
		TurnState.State.TARGET_SPELL:
			presentation_state.begin_targeting(&"spell")
		TurnState.State.ENEMY_TURN:
			presentation_state.begin_enemy_turn()
		TurnState.State.ANIMATING:
			if presentation_state.get_phase() \
					!= CombatPresentationState.Phase.RESOLVING_ACTION:
				presentation_state.begin_resolution(&"action")
		TurnState.State.SKILL_EVOLUTION_PENDING, \
		TurnState.State.SKILL_EVOLUTION_UI:
			presentation_state.begin_modal()


func _on_presentation_snapshot_changed(snapshot: Dictionary) -> void:
	if _hud_port != null:
		_hud_port.apply_presentation_snapshot(snapshot)
	var focus_active := bool(snapshot.get("focus_active", false))
	if is_instance_valid(player_combat_log) and player_combat_log.has_method(
		"set_tactical_focus"
	):
		player_combat_log.set_tactical_focus(focus_active)
	if is_instance_valid(turn_order_timeline) and turn_order_timeline.has_method(
		"set_tactical_focus"
	):
		turn_order_timeline.set_tactical_focus(focus_active)


func _begin_action_resolution(kind: StringName) -> void:
	if presentation_state != null:
		presentation_state.begin_resolution(kind)
	turn_state.begin_animating()


func _show_intent_feedback(
		message: String,
		kind: StringName = &"warning"
	) -> void:
	if message.strip_edges().is_empty():
		return
	_presentation_feedback_generation += 1
	var generation := _presentation_feedback_generation
	if presentation_state != null:
		presentation_state.set_feedback(message, kind)
	if _hud_port != null:
		_hud_port.show_feedback(message, kind)
	_clear_intent_feedback_later(generation)


func _clear_intent_feedback_later(generation: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(1.6).timeout
	if generation != _presentation_feedback_generation \
		or presentation_state == null:
		return
	presentation_state.clear_feedback()

# ============================================================
# SPAWN DES UNITÉS
# ============================================================

func _spawn_units() -> void:
	units = []
	# Les ennemis sont posés automatiquement (placement aléatoire dans leur zone).
	_spawn_enemies()
	# Les héros, eux, sont placés PAR LE JOUEUR (phase de déploiement).
	_deployment.start()


func _spawn_direct_test_units() -> void:
	units = []
	if bool(_direct_test_options.get("spawn_enemies", false)):
		_spawn_enemies()
	if not bool(_direct_test_options.get("spawn_heroes", false)):
		return
	if bool(_direct_test_options.get("deployment_enabled", false)):
		if _deployment != null:
			_deployment.start()
		return
	var available := room_data.hero_spawn_zone.duplicate() \
		if room_data != null else []
	for hero in GameManager.get_living_heroes():
		var spawn_cell := _resolve_spawn_cell(available, hero.unit_name)
		if spawn_cell == Vector2i(-1, -1):
			break
		hero.current_ap = hero.max_ap.get_int()
		hero.current_mp = hero.max_mp.get_int()
		_place(hero, spawn_cell)
		units.append(hero)


func _direct_test_flag(key: String, production_default: bool) -> bool:
	return production_default if _direct_test_options.is_empty() \
		else bool(_direct_test_options.get(key, production_default))


func _apply_direct_test_view_options() -> void:
	if _direct_test_options.is_empty() or grid_view == null:
		return
	if grid_view.has_method("set_render_options"):
		grid_view.set_render_options(
			bool(_direct_test_options.get("draw_base_cells", false)),
			bool(_direct_test_options.get("draw_grid_lines", false)),
			bool(_direct_test_options.get("draw_cell_centers", false)),
			bool(_direct_test_options.get("draw_map_bounds", false)),
		)
	if grid_view.has_method("set_debug_layers"):
		grid_view.set_debug_layers(
			bool(_direct_test_options.get("draw_logic_types", false)),
			bool(_direct_test_options.get("draw_void_cells", false)),
			bool(_direct_test_options.get("draw_coordinates", false)),
			bool(_direct_test_options.get("draw_spawns", false)),
			bool(_direct_test_options.get("draw_calibration", false)),
		)

# --- Ennemis : viennent du RoomData, placés aléatoirement dans leur zone. ---
func _spawn_enemies() -> void:
	if room_data == null:
		push_warning("Aucune RoomData assignée : pas d'ennemis.")
		return

	var roster: Array = room_data.enemies
	var placements: Array = []
	var encounter_definition: EncounterDefinition = (
		GameManager.get_current_encounter_definition()
	)
	if encounter_definition != null:
		var planner := EncounterFormationPlanner.new(grid, pathfinder)
		encounter_formation_snapshot = planner.build_plan(
			encounter_definition,
			room_data.hero_spawn_zone,
			room_data.enemy_spawn_zone,
			EncounterSeedResolver.effective_seed(
				GameManager.get_run_seed(), GameManager.get_current_wave_index()
			),
		)
		if not encounter_formation_snapshot.get("valid", false):
			push_error("Placement de rencontre impossible (%s) : %s" % [
				room_data.room_name,
				str(encounter_formation_snapshot.get("reason", &"unknown")),
			])
			return
		placements = encounter_formation_snapshot.get("placements", [])
		roster = encounter_definition.expanded_roster()
	var available = room_data.enemy_spawn_zone.duplicate()
	available.shuffle()

	for enemy_index in range(roster.size()):
		var enemy_data := (
			(placements[enemy_index] as Dictionary).get("unit_data") as UnitData
			if enemy_index < placements.size()
			else roster[enemy_index] as UnitData
		)
		if enemy_data == null:
			push_warning("Un ennemi de la salle est null : ignoré.")
			continue
		var spawn_cell: Vector2i = (
			(placements[enemy_index] as Dictionary).get("cell", Vector2i(-1, -1))
			if enemy_index < placements.size()
			else _resolve_spawn_cell(available, enemy_data.unit_name)
		)
		if spawn_cell == Vector2i(-1, -1):
			push_warning("Plus de case libre pour %s." % enemy_data.unit_name)
			break
		var enemy = Unit.from_data(enemy_data)
		_apply_current_wave_scaling(enemy)
		_place(enemy, spawn_cell)
		units.append(enemy)


func _apply_current_wave_scaling(enemy: Unit) -> void:
	if enemy == null or room_data == null or not GameManager.is_wave_chain_active():
		return
	var wave := room_data.get_wave(GameManager.get_current_wave_index())
	if wave == null:
		return
	enemy.max_hp.add_modifier(
		wave.enemy_health_multiplier - 1.0,
		Stat.ModType.PERCENT,
		"room_wave_health",
	)
	enemy.attack_power.add_modifier(
		wave.enemy_attack_multiplier - 1.0,
		Stat.ModType.PERCENT,
		"room_wave_attack",
	)
	enemy.current_hp = enemy.max_hp.get_int()

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
	if unit.team == 0:
		_orient_unit_toward_nearest_opponent(unit)

func _create_unit_view(unit: Unit) -> void:
	var view = preload("res://battle/unit_view.tscn").instantiate()
	var parent := _unit_view_parent if _unit_view_parent != null else grid_view
	parent.add_child(view)
	view.setup(unit)
	# Reduit la taille des persos face au decor. Fait AVANT le calcul de l'ombre
	# pour que celle-ci, calculee en repere local, reste a la taille de la case.
	if not is_equal_approx(iso_unit_view_scale, 1.0):
		view.scale = Vector2(iso_unit_view_scale, iso_unit_view_scale)
	view.position = grid_cell_to_parent_local(unit.grid_pos, parent)
	if temporary_iso_placeholders:
		_install_ground_shadow(view, unit.grid_pos)
		_install_temporary_iso_placeholder(view, unit)
	if iso_gameplay_light != null and view.has_method("set_light_material"):
		view.set_light_material(iso_gameplay_light)
	_unit_views[unit] = view


## Oriente ensemble la logique et la vue vers l'adversaire vivant le plus
## proche. La distance de Manhattan suit les memes axes que les deplacements.
func _orient_unit_toward_nearest_opponent(unit: Unit) -> void:
	if unit == null or not unit.is_alive or grid == null \
			or not grid.is_valid(unit.grid_pos):
		return
	var nearest: Unit = null
	var nearest_distance := 0
	for candidate_value in units:
		var candidate := candidate_value as Unit
		if candidate == null or candidate == unit or not candidate.is_alive \
				or candidate.team == unit.team or not grid.is_valid(candidate.grid_pos):
			continue
		var distance := grid.manhattan(unit.grid_pos, candidate.grid_pos)
		if nearest == null or distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest == null:
		return
	var direction := nearest.grid_pos - unit.grid_pos
	unit.facing_dir = unit._snap_to_cardinal(direction)
	var view = _unit_views.get(unit)
	if is_instance_valid(view) and view.has_method("face_grid_direction"):
		view.face_grid_direction(direction)

## Ombre au sol qui suit le skew de la case (perspective). Le perso reste droit.
func _install_ground_shadow(view: Node2D, cell: Vector2i) -> void:
	if grid_view == null or not grid_view.has_method("get_cell_polygon"):
		return
	var footprint_local := PackedVector2Array()
	for point in grid_view.get_cell_polygon(cell):
		footprint_local.append(view.to_local(grid_view.to_global(point)))
	var shadow := Node2D.new()
	shadow.set_script(load("res://battle/iso/iso_ground_shadow.gd"))
	view.add_child(shadow)
	view.move_child(shadow, 0)
	shadow.setup(footprint_local)

func _install_temporary_iso_placeholder(view: Node2D, unit: Unit) -> void:
	var placeholder := Node2D.new()
	placeholder.set_script(load("res://battle/iso/iso_unit_placeholder.gd"))
	view.add_child(placeholder)
	placeholder.setup(unit, view)

func _start_battle() -> void:
	_enqueue_existing_pending_evolutions()
	GameManager.apply_pending_next_combat_rewards()
	GameManager.begin_combat_report()
	var heroes_count := 0
	var enemies_count := 0
	for u in units:
		if u.team == 0:
			heroes_count += 1
		else:
			enemies_count += 1
	if heroes_count == 0:
		push_error("Aucun héros dans le combat : défaite immédiate.")
		_request_battle_outcome(false)
		return
	if enemies_count == 0:
		push_warning("Aucun ennemi dans la salle : victoire immédiate.")
		_request_battle_outcome(true)
		if _evolution_queue.has_pending():
			_process_evolution_queue_at_safe_point.call_deferred()
		return

	# Connexion du handler de poussée (visuel — logique dans SpellCaster)
	EventBus.unit_pushed.connect(_on_unit_pushed)

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
	if is_instance_valid(turn_order_timeline):
		turn_order_timeline.bind_queue(turn_queue)
	EventBus.combat_started.emit(units.duplicate(), grid)
	turn_queue.start()

# ============================================================
# HANDLER POUSSÉE VISUELLE
# ============================================================

func _on_unit_pushed(unit: Unit, _from: Vector2i, to_pos: Vector2i, _collision: bool) -> void:
	_sync_unit_terrain(unit)
	var view = _unit_views.get(unit)
	if is_instance_valid(view):
		view.position = grid_cell_to_parent_local(to_pos, view.get_parent())

func _on_turn_started(unit: Unit) -> void:
	if _battle_over or _closing or not is_instance_valid(unit):
		return
	if _evolution_queue.has_pending() or _evolution_processing:
		_turn_start_deferred_for_evolution = true
		_lock_combat_for_evolution(false)
		_process_evolution_queue_at_safe_point.call_deferred()
		return
	var lifecycle_generation := _lifecycle_generation
	_turn_end_committed = false
	if presentation_state != null:
		presentation_state.set_lock(&"battle_not_started", false)

	# Un ciblage appartient exclusivement au personnage qui l'a ouvert. Il est
	# annule avant de remplacer le HUD, y compris lors d'un passage allie -> allie.
	_cancel_action_selection_for_active_unit()

	# 1. Effet de terrain en début de tour (lave, feu...).
	var is_stunned = ArenaTerrainStatusTimingService.resolve_activation_start(
		unit, terrain_effects
	)
	_sync_unit_terrain(unit)

	# 3. Mort des dégâts (terrain ou poison) en début de tour ?
	if not unit.is_alive:
		_end_active_turn_if_dead(unit)
		return

	# 4. Stun : l'unité saute son tour.
	if is_stunned:
		DebugLogger.debug(DebugLogger.LogCategory.TURN, "%s est stun, passe son tour" % unit.unit_name)
		if not await _wait_battle_seconds_safe(0.6, lifecycle_generation):
			return
		if not _battle_over and is_instance_valid(turn_queue):
			_finish_active_turn(&"stunned")
		return

	# 5. Déroulement normal.
	_update_active_highlight(unit)
	_hud_port.update_info(unit)
	_hud_port.build_actions(unit)

	if unit.team == 1:
		turn_state.begin_enemy_turn()
		_hud_port.set_controls_enabled(false)
		await _enemy_turn.run(unit)
		if not _is_operation_current(lifecycle_generation) \
				or not is_instance_valid(unit):
			return
		if not _battle_over:
			_finish_active_turn(&"enemy_completed")
	else:
		turn_state.begin_player_turn()
		_hud_port.set_controls_enabled(true)
		_hud_port.set_active_mode("")


func get_active_unit():
	if turn_queue == null:
		return null
	return turn_queue.get_current_unit()


func _end_active_turn_if_dead(unit: Unit) -> bool:
	if not is_instance_valid(unit) or unit.is_alive or turn_queue == null:
		return false
	if turn_queue.get_current_unit() != unit:
		return false
	if _battle_over or _closing:
		return true
	_cancel_action_selection_for_active_unit()
	if is_instance_valid(grid_view):
		grid_view.clear_highlights()
	if _hud_port != null:
		_hud_port.set_controls_enabled(false)
		_hud_port.set_active_mode("")
	_finish_active_turn(&"dead")
	return true


func _finish_active_turn(reason: StringName) -> bool:
	if _turn_end_committed or turn_queue == null or _battle_over or _closing:
		return false
	var unit := turn_queue.get_current_unit() as Unit
	if unit == null:
		return false
	_turn_end_committed = true
	ArenaTerrainStatusTimingService.resolve_activation_end(unit)
	EventBus.turn_ended.emit(unit, reason)
	turn_queue.advance()
	return true


func get_pending_evolution_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request in _evolution_queue.get_requests():
		result.append(request.to_dictionary())
	return result


func is_combat_input_locked_for_evolution() -> bool:
	return _is_evolution_locked()


func get_combat_evolution_state() -> StringName:
	if turn_state == null:
		return &""
	match turn_state.current:
		TurnState.State.SKILL_EVOLUTION_PENDING:
			return &"SKILL_EVOLUTION_PENDING"
		TurnState.State.SKILL_EVOLUTION_UI:
			return &"SKILL_EVOLUTION_UI"
	return &""


func _cancel_action_selection_for_active_unit() -> void:
	if turn_state == null or _hud_port == null:
		return
	turn_state.on_cancel()
	_hud_port.set_active_mode("")

func _sync_unit_terrain(_unit: Unit) -> void:
	pass

func _update_active_highlight(active_unit: Unit) -> void:
	for unit in _unit_views:
		var view = _unit_views[unit]
		if is_instance_valid(view):
			view.set_active(unit == active_unit)

# ============================================================
# BOUTONS JOUEUR
# ============================================================

func _on_move_pressed() -> void:
	if _is_evolution_locked() or not _can_accept_player_intent():
		return
	turn_state.on_move_button()
	_refresh_mode_button()

func _on_attack_pressed() -> void:
	if _is_evolution_locked() or not _can_accept_player_intent():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null or not unit.basic_attack_enabled:
		return
	turn_state.on_attack_button()
	_refresh_mode_button()

func _on_spell_pressed(spell: Spell) -> void:
	if _is_evolution_locked() or not _can_accept_player_intent():
		return
	turn_state.on_spell_selected(spell)
	_refresh_mode_button()

# Activation d'un objet depuis la barre d'objets du HUD. Le HUD n'applique
# jamais l'effet lui-même : il demande, et RelicRuntimeService décide. Un refus
# ici est un cas de course (l'état a changé entre l'affichage et le clic), pas
# une erreur du joueur.
func _on_item_activation_requested(instance_id: StringName) -> void:
	if _is_evolution_locked() \
			or _spell_resolution_pending \
			or not _can_accept_player_intent():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null or unit.team != 0:
		return
	var relic_service := GameManager.get_relic_runtime_service()
	if relic_service == null:
		return
	var result := relic_service.activate_relic_manually(unit, instance_id)
	if not bool(result.get("success", false)):
		DebugLogger.debug(
			DebugLogger.LogCategory.COMBAT,
			"Activation manuelle refusée : %s" % result.get("reason", &"inconnu"),
			{"instance_id": str(instance_id)}
		)

func _on_end_turn_pressed() -> void:
	if _is_evolution_locked() \
			or _spell_resolution_pending \
			or not _can_accept_player_intent():
		return
	var unit := get_active_unit() as Unit
	if unit != null \
			and not _skip_end_turn_confirmation \
			and (unit.current_ap > 0 or unit.current_mp > 0):
		_show_end_turn_confirmation(unit)
		return
	_commit_player_end_turn()


func _commit_player_end_turn() -> void:
	_clear_movement_path_preview()
	grid_view.clear_highlights()
	_finish_active_turn(&"player_requested")


func _show_end_turn_confirmation(unit: Unit) -> void:
	cancel_active_selection()
	if not is_instance_valid(_end_turn_confirmation):
		_end_turn_confirmation = END_TURN_CONFIRMATION.new()
		add_child(_end_turn_confirmation)
		_end_turn_confirmation.confirmed.connect(
			_on_end_turn_confirmation_confirmed
		)
		_end_turn_confirmation.cancelled.connect(
			_on_end_turn_confirmation_cancelled
		)
	if presentation_state != null:
		presentation_state.begin_modal()
		presentation_state.set_lock(&"end_turn_confirmation", true)
	_end_turn_confirmation.present(unit)


func _on_end_turn_confirmation_confirmed(skip_future: bool) -> void:
	_skip_end_turn_confirmation = _skip_end_turn_confirmation or skip_future
	if presentation_state != null:
		presentation_state.set_lock(&"end_turn_confirmation", false)
	_commit_player_end_turn()


func _on_end_turn_confirmation_cancelled() -> void:
	if presentation_state != null:
		presentation_state.set_lock(&"end_turn_confirmation", false)
	if turn_state != null:
		turn_state.begin_player_turn()
	if presentation_state != null:
		# TurnState peut deja etre IDLE : dans ce cas aucun signal de transition
		# n'est emis, il faut donc restaurer explicitement la phase joueur.
		presentation_state.begin_player_turn()


func dismiss_top_combat_modal() -> bool:
	return is_instance_valid(_end_turn_confirmation) \
		and _end_turn_confirmation.dismiss()

func _refresh_mode_button() -> void:
	if _hud_port == null:
		return
	match turn_state.current:
		TurnState.State.MOVE:
			_hud_port.set_active_mode("move")
		TurnState.State.TARGET_MELEE:
			_hud_port.set_active_mode("attack")
		TurnState.State.TARGET_SPELL:
			_hud_port.set_active_mode("spell", turn_state.selected_spell)
		_:
			_hud_port.set_active_mode("")

# ============================================================
# CLICS + ANNULATION
# ============================================================

func _on_cell_clicked(cell: Vector2i) -> void:
	if _is_evolution_locked():
		return
	if _deployment != null and _deployment.is_active():
		_deployment.on_cell_clicked(cell)
		return
	if turn_state == null:
		if inspect_panel != null:
			inspect_panel.show_cell(cell, grid, terrain_effects, true)
		return
	if turn_state.current == TurnState.State.IDLE:
		if inspect_panel != null:
			inspect_panel.show_cell(cell, grid, terrain_effects, true)
		return
	if turn_state.current == TurnState.State.MOVE:
		var active_unit = turn_queue.get_current_unit() if turn_queue != null else null
		var reachable_cells: Array = []
		if active_unit != null:
			reachable_cells = pathfinder.get_reachable(
				active_unit.grid_pos,
				active_unit.current_mp,
				active_unit,
			)
		if not reachable_cells.has(cell):
			_show_intent_feedback(_movement_rejection_reason(active_unit, cell))
			if inspect_panel != null:
				inspect_panel.show_cell(cell, grid, terrain_effects, true)
			return
	if not _can_accept_player_intent():
		return
	turn_state.on_cell_clicked(cell)


func _on_turn_order_unit_selected(unit: Unit) -> void:
	if not is_instance_valid(unit) or not unit.is_alive or inspect_panel == null:
		return
	inspect_panel.visible = true
	inspect_panel.show_unit(unit, true)


func _on_cell_hovered(cell: Vector2i) -> void:
	if inspect_panel != null:
		inspect_panel.show_cell(cell, grid, terrain_effects, false)
	if turn_state == null:
		_clear_movement_path_preview()
		return
	if turn_state.current == TurnState.State.MOVE:
		_update_movement_path_preview(cell)
		return
	_clear_movement_path_preview()
	if turn_state.current != TurnState.State.TARGET_SPELL:
		return
	var spell = turn_state.selected_spell
	var unit = turn_queue.get_current_unit()
	if spell == null or unit == null:
		return
	grid_view.clear_highlights()
	var targetable = spell_caster.get_targetable_cells(unit, spell)
	grid_view.highlight(
		targetable,
		SPELL_COLOR,
		COMBAT_HIGHLIGHT_MARKER.SPELL,
	)
	if targetable.has(cell):
		grid_view.highlight(
			spell_caster.get_aoe_cells(spell, cell),
			AOE_COLOR,
			COMBAT_HIGHLIGHT_MARKER.AOE,
		)
		if inspect_panel != null:
			inspect_panel.show_spell_preview(unit, spell, cell, grid, spell_caster)

func _unhandled_input(event: InputEvent) -> void:
	if _is_evolution_locked():
		return
	var cancel_requested := event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton:
		cancel_requested = cancel_requested or (
			event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
		)
	if not cancel_requested:
		return
	if dismiss_top_combat_modal():
		get_viewport().set_input_as_handled()
		return
	if cancel_active_selection():
		get_viewport().set_input_as_handled()

# ============================================================
# INTENTIONS — DÉPLACEMENT
# ============================================================

func _movement_range_layers(unit: Unit) -> Dictionary:
	var reachable: Array = pathfinder.get_reachable(
		unit.grid_pos,
		unit.current_mp,
		unit,
	)
	var control_limited: Array[Vector2i] = []
	if not pathfinder.get_engaging_controllers(unit).is_empty():
		# Le contexte forcé conserve les coûts du terrain et les obstacles, mais
		# ignore le désengagement : la différence isole la portée perdue.
		var without_control: Array = pathfinder.get_reachable(
			unit.grid_pos,
			unit.current_mp,
			unit,
			Pathfinder.MovementType.FORCED,
		)
		for cell_value in without_control:
			var cell := cell_value as Vector2i
			if not reachable.has(cell):
				control_limited.append(cell)
	return {
		"reachable": reachable,
		"control_limited": control_limited,
	}


func _movement_rejection_reason(unit: Unit, cell: Vector2i) -> String:
	return (
		_target_feedback.movement_rejection_reason(unit, cell)
		if _target_feedback != null
		else "Cette case n'est pas accessible."
	)


func _on_request_show_move_range() -> void:
	if _is_evolution_locked():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	_clear_movement_path_preview()
	grid_view.clear_highlights()
	var range_layers := _movement_range_layers(unit)
	grid_view.highlight(
		range_layers.get("control_limited", []),
		CONTROL_LIMITED_MOVE_COLOR,
		COMBAT_HIGHLIGHT_MARKER.CONTROL_LIMITED,
	)
	grid_view.highlight(
		range_layers.get("reachable", []),
		MOVE_COLOR,
		COMBAT_HIGHLIGHT_MARKER.MOVE,
	)

func _on_request_clear_highlights() -> void:
	_clear_movement_path_preview()
	grid_view.clear_highlights()


func _update_movement_path_preview(cell: Vector2i) -> void:
	var unit = turn_queue.get_current_unit() if turn_queue != null else null
	if unit == null \
			or not unit.is_alive \
			or not pathfinder.get_reachable(
				unit.grid_pos, unit.current_mp, unit
			).has(cell):
		_clear_movement_path_preview()
		return
	var path := pathfinder.find_path(unit.grid_pos, cell, unit)
	var cost_breakdown := pathfinder.path_cost_breakdown(path, unit)
	if path.size() < 2 or int(cost_breakdown.get("total", 0)) > unit.current_mp:
		_clear_movement_path_preview()
		return
	_movement_path_preview.set_path(path, cost_breakdown)


func _on_request_move_to(cell: Vector2i) -> void:
	if _closing \
			or _battle_over \
			or _is_evolution_locked() \
			or not _can_accept_player_intent():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null:
		return
	if not pathfinder.get_reachable(unit.grid_pos, unit.current_mp, unit).has(cell):
		_show_intent_feedback(_movement_rejection_reason(unit, cell))
		return
	var path = pathfinder.find_path(unit.grid_pos, cell, unit)
	if path.size() < 2:
		_show_intent_feedback("Choisissez une autre case que la position actuelle.")
		return
	var cost_breakdown := pathfinder.path_cost_breakdown(path, unit)
	var paid_cost := int(cost_breakdown.get("total", 0))
	var base_cost := int(cost_breakdown.get("unmodified_total", paid_cost))
	var action_id := _next_action_id(&"move")
	var relic_service := GameManager.get_relic_runtime_service()
	if relic_service != null and relic_service.try_intercept(
			unit,
			ItemReactiveEffectData.TRIGGER_VOLUNTARY_MOVE_PREPARED,
			{
				"path": path.duplicate(), "distance": maxi(0, path.size() - 1),
				"voluntary": true, "base_cost": base_cost,
				"effective_cost": paid_cost, "action_id": action_id,
			}
		):
		turn_state.on_cancel()
		_clear_movement_path_preview()
		grid_view.clear_highlights()
		return
	EventBus.voluntary_movement_prepared.emit(
		unit, path.duplicate(), base_cost, paid_cost, action_id
	)
	if not unit.spend_mp(paid_cost):
		_show_intent_feedback("PM insuffisants pour ce déplacement.")
		return
	_begin_action_resolution(&"move")
	var lifecycle_generation := _lifecycle_generation
	await _animate_move(unit, path)
	if not _is_operation_current(lifecycle_generation):
		return
	if _end_active_turn_if_dead(unit):
		return
	EventBus.voluntary_movement_resolved.emit(
		unit, path.duplicate(), paid_cost, action_id
	)
	EventBus.action_resolved.emit(unit, action_id, &"voluntary_movement", {
		"distance": maxi(0, path.size() - 1), "paid_mp": paid_cost,
	})
	turn_state.end_animating()
	_hud_port.update_info(unit)

# Animation de déplacement BLINDÉE contre les objets détruits.
# Une unité peut mourir en cours de route (lave via on_enter_cell) : on
# vérifie is_instance_valid(view) ET unit.is_alive avant/après chaque await.
# Sans ça : erreur "Freed Object" + tour figé (cause des freezes passés).
func _animate_move(unit: Unit, path: Array) -> void:
	if _closing or _battle_over:
		return
	var lifecycle_generation := _lifecycle_generation
	var view = _unit_views.get(unit)
	if not is_instance_valid(view) or path.size() < 2:
		return
	if view.has_method("begin_path_movement_feedback"):
		view.begin_path_movement_feedback(path.duplicate())
	else:
		view.begin_movement_feedback(path[0], path[1])
	var segment_duration := _movement_segment_duration_for(view, path)
	terrain_effects.begin_unit_resolution(unit, &"movement")
	for i in range(1, path.size()):
		# L'unité a pu mourir à l'étape précédente : on s'arrête proprement.
		if not unit.is_alive or not is_instance_valid(view):
			break
		if pathfinder.is_vortex_edge(path[i - 1], path[i]):
			continue
		var from_pos = grid_cell_to_parent_local(path[i - 1], view.get_parent())
		var target_pos = grid_cell_to_parent_local(path[i], view.get_parent())
		if view.has_method("face_grid_direction"):
			view.face_grid_direction(path[i] - path[i - 1])
		else:
			view.face_direction(from_pos, target_pos)
		var tween = create_tween()
		tween.tween_property(
			view,
			"position",
			target_pos,
			segment_duration
		)
		await tween.finished
		# La vue a pu être libérée pendant l'await.
		if not _is_operation_current(lifecycle_generation) \
				or not is_instance_valid(view):
			break
		if not grid.relocate_unit(unit, path[i]):
			break
		var entry_result := terrain_effects.consume_last_entry_result(unit)
		if bool(entry_result.get("teleported", false)):
			var destination := entry_result.get("destination", path[i]) as Vector2i
			view.position = grid_cell_to_parent_local(destination, view.get_parent())
		_sync_unit_terrain(unit)
		# on_enter_cell a pu tuer l'unité (lave) : on stoppe le déplacement.
		if not unit.is_alive:
			break
		if bool(entry_result.get("end_movement", false)):
			break
	terrain_effects.end_unit_resolution(unit)
	if is_instance_valid(view):
		view.end_movement_feedback()
		if unit.team != 0:
			_orient_unit_toward_nearest_opponent(unit)


func _movement_segment_duration_for(view, path: Array) -> float:
	if is_instance_valid(view) \
			and view.has_method("get_movement_segment_duration"):
		var custom_duration: Variant = view.call(
			"get_movement_segment_duration", path.duplicate()
		)
		if custom_duration is float or custom_duration is int:
			var duration := float(custom_duration)
			if duration > 0.0:
				return clampf(duration, 0.05, 1.0)
	return MovementTiming.MOVE_SEGMENT_DURATION

# ============================================================
# INTENTIONS — ATTAQUE
# ============================================================

func _on_request_show_attack_range() -> void:
	if _is_evolution_locked():
		return
	_clear_movement_path_preview()
	var unit = turn_queue.get_current_unit()
	if unit == null or not unit.basic_attack_enabled:
		turn_state.set_state(TurnState.State.IDLE)
		return
	grid_view.clear_highlights()
	grid_view.highlight(
		_get_attackable_cells(unit),
		ATTACK_COLOR,
		COMBAT_HIGHLIGHT_MARKER.ATTACK,
	)

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
	if _closing \
			or _battle_over \
			or _is_evolution_locked() \
			or not _can_accept_player_intent():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null or not unit.basic_attack_enabled:
		turn_state.set_state(TurnState.State.IDLE)
		return
	if not _get_attackable_cells(unit).has(cell):
		_show_intent_feedback("Choisissez un ennemi adjacent.")
		return
	# Une seule economie pour tout le monde : l'attaque de base coute 1 PA.
	var ap_cost: int = unit.get_basic_attack_ap_cost()
	if unit.current_ap < ap_cost:
		_show_intent_feedback(
			"PA insuffisants (%d / %d)." % [unit.current_ap, ap_cost]
		)
		return
	var target = grid.get_unit(cell)
	if target == null:
		return
	var view = _unit_views.get(unit)
	var has_action_visual := false
	var lifecycle_generation := _lifecycle_generation
	_begin_action_resolution(&"basic_attack")
	if is_instance_valid(view) and view.has_method("prepare_basic_attack_visual"):
		var visual_ready: bool = await view.prepare_basic_attack_visual(cell)
		if not visual_ready or not _is_operation_current(lifecycle_generation):
			turn_state.end_animating()
			return
		has_action_visual = view.has_method("has_optional_visual") \
			and view.has_optional_visual()
	var action_id := _next_action_id(&"basic_attack")
	var ap_before: int = unit.current_ap
	if not unit.spend_ap(ap_cost):
		turn_state.end_animating()
		return
	if not has_action_visual:
		await _animate_attack_to_impact(unit, target)
		if not _is_operation_current(lifecycle_generation):
			return
	var result = target.take_damage(
		unit.get_attack(),
		unit,
		Spell.DamageType.PHYSICAL,
		Spell.Element.NONE,
		{"action_id": action_id, "impact_id": StringName("%s:000" % action_id)})
	if result != null and not result.dodged:
		EventBus.basic_attack_performed.emit(unit, target)
	if not _is_operation_current(lifecycle_generation):
		return
	if has_action_visual and is_instance_valid(view) \
			and view.has_method("wait_for_action_visual_finished"):
		await view.wait_for_action_visual_finished()
	else:
		await _animate_attack_recovery(unit)
	if not _is_operation_current(lifecycle_generation):
		return
	if _end_active_turn_if_dead(unit):
		return
	EventBus.ap_after_action_changed.emit(unit, ap_before, unit.current_ap, action_id)
	EventBus.action_resolved.emit(unit, action_id, &"basic_attack", {"target": target})
	turn_state.end_animating()
	_hud_port.update_info(unit)

# Animation d'attaque BLINDÉE (accès .get() + vérif de validité).
func _animate_attack(unit: Unit, target: Unit) -> void:
	await _animate_attack_to_impact(unit, target)
	await _animate_attack_recovery(unit)


func _animate_attack_to_impact(unit: Unit, target: Unit) -> void:
	if _closing or _battle_over:
		return
	var lifecycle_generation := _lifecycle_generation
	var view = _unit_views.get(unit)
	if not is_instance_valid(view):
		return
	var start = grid_cell_to_parent_local(unit.grid_pos, view.get_parent())
	var toward = grid_cell_to_parent_local(target.grid_pos, view.get_parent())
	if view.has_method("face_grid_direction"):
		view.face_grid_direction(target.grid_pos - unit.grid_pos)
	var bump = start.lerp(toward, 0.4)
	var tween = create_tween()
	tween.tween_property(view, "position", bump, 0.1)
	await tween.finished
	if not _is_operation_current(lifecycle_generation):
		return


func _animate_attack_recovery(unit: Unit) -> void:
	if _closing or _battle_over:
		return
	var lifecycle_generation := _lifecycle_generation
	var view = _unit_views.get(unit)
	if not is_instance_valid(view):
		return
	var start = grid_cell_to_parent_local(unit.grid_pos, view.get_parent())
	var tween = create_tween()
	tween.tween_property(view, "position", start, 0.1)
	await tween.finished
	if not _is_operation_current(lifecycle_generation):
		return

# ============================================================
# INTENTIONS — SORTS
# ============================================================

func _on_request_show_spell_range(spell: Spell) -> void:
	if _is_evolution_locked():
		return
	_clear_movement_path_preview()
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	grid_view.clear_highlights()
	grid_view.highlight(
		spell_caster.get_targetable_cells(unit, spell),
		SPELL_COLOR,
		COMBAT_HIGHLIGHT_MARKER.SPELL,
	)


func _spell_target_rejection_reason(
		unit: Unit,
		spell: Spell,
		cell: Vector2i
	) -> String:
	return (
		_target_feedback.spell_rejection_reason(unit, spell, cell)
		if _target_feedback != null
		else "Cible incompatible avec cette capacité."
	)

func _on_request_cast_spell(spell: Spell, cell: Vector2i) -> void:
	if _spell_resolution_pending \
			or _closing \
			or _battle_over \
			or _is_evolution_locked() \
			or not _can_accept_player_intent():
		return
	var unit = turn_queue.get_current_unit()
	if unit == null or spell == null:
		return
	if not spell_caster.is_valid_target(unit, spell, cell):
		_show_intent_feedback(_spell_target_rejection_reason(unit, spell, cell))
		return
	_spell_resolution_pending = true
	_trigger_sequence += 1
	_active_trigger_sequence = _trigger_sequence
	_begin_action_resolution(&"spell")
	_hud_port.set_controls_enabled(false)
	var lifecycle_generation := _lifecycle_generation
	var view = _unit_views.get(unit)
	if is_instance_valid(view):
		if view.has_method("prepare_spell_visual"):
			var visual_ready: bool = await view.prepare_spell_visual(cell, spell)
			if not visual_ready or not _is_operation_current(lifecycle_generation):
				_spell_resolution_pending = false
				if turn_state != null:
					turn_state.begin_player_turn()
				if _hud_port != null:
					_hud_port.set_controls_enabled(true)
				return
		elif view.has_method("face_grid_direction"):
			view.face_grid_direction(cell - unit.grid_pos)
	var context := spell_caster.begin_cast(unit, spell, cell)
	if context.failed:
		_spell_resolution_pending = false
		turn_state.begin_player_turn()
		_hud_port.set_controls_enabled(true)
		return
	if spell.impact_delay_seconds > 0.0:
		VFXManager.play_spell_vfx(unit, spell, cell)
		if _spell_impact_scheduler.schedule(context, spell.impact_delay_seconds):
			return
	var report = spell_caster.resolve_cast(context)
	await _finish_spell_resolution(unit, report)


func _on_delayed_spell_impact(context: CastContext) -> void:
	if _closing or _battle_over or context == null or spell_caster == null:
		_spell_resolution_pending = false
		return
	var report := spell_caster.resolve_cast(context)
	_finish_spell_resolution(context.caster, report)


func _finish_spell_resolution(unit: Unit, report: Dictionary) -> void:
	if _closing or _battle_over or report.get("failed", false):
		_spell_resolution_pending = false
		return
	var lifecycle_generation := _lifecycle_generation
	var view = _unit_views.get(unit)
	if is_instance_valid(view) \
			and view.has_method("has_optional_visual") \
			and view.has_optional_visual() \
			and view.has_method("wait_for_action_visual_finished"):
		await view.wait_for_action_visual_finished()
		if not _is_operation_current(lifecycle_generation):
			_spell_resolution_pending = false
			return
	var tree := get_tree()
	if tree != null:
		await tree.process_frame
		if not _is_operation_current(lifecycle_generation):
			_spell_resolution_pending = false
			return
	if is_instance_valid(grid_view):
		grid_view.queue_redraw()
	if _hud_port != null:
		_hud_port.update_info(unit)
		_hud_port.set_active_mode("")
	var action_id := StringName(report.get("action_id", &""))
	if action_id != &"":
		EventBus.ap_after_action_changed.emit(
			unit, int(report.get("ap_before", unit.current_ap)),
			int(report.get("ap_after", unit.current_ap)), action_id
		)
		EventBus.action_resolved.emit(unit, action_id, &"spell", report.duplicate(false))
	_spell_resolution_pending = false
	if _evolution_queue.has_pending():
		await _process_evolution_queue_at_safe_point()
		return
	if _battle_outcome_waiting:
		_commit_waiting_battle_outcome()
		return
	if _end_active_turn_if_dead(unit):
		return
	if turn_state != null:
		turn_state.begin_player_turn()
	if _hud_port != null:
		_hud_port.set_controls_enabled(true)


func _on_discipline_xp_gained(
		character_id: StringName,
		discipline_id: StringName,
		_amount: int,
		snapshot: Dictionary
	) -> void:
	if _closing or _battle_over:
		return
	var caster := snapshot.get("caster") as Unit
	if caster == null or not units.has(caster):
		return
	var source_spell_id := StringName(snapshot.get("spell_id", &""))
	for rank_value in snapshot.get("reached_ranks", []):
		_enqueue_evolution_request(
			character_id,
			discipline_id,
			int(rank_value),
			source_spell_id,
			_active_trigger_sequence,
		)


func _enqueue_existing_pending_evolutions() -> void:
	for choice in GameManager.get_pending_progression_choices():
		_enqueue_evolution_request(
			StringName(choice.get("character_id", &"")),
			StringName(choice.get("discipline_id", &"")),
			int(choice.get("rank", 0)),
			&"",
			0,
		)


func _enqueue_evolution_request(
		character_id: StringName,
		discipline_id: StringName,
		pending_rank: int,
		source_spell_id: StringName,
		trigger_sequence: int
	) -> bool:
	_evolution_request_counter += 1
	var request_id := StringName("evolution_%06d_%04d" % [
		maxi(trigger_sequence, 0),
		_evolution_request_counter,
	])
	return _evolution_queue.enqueue(EvolutionRequest.create(
		character_id,
		discipline_id,
		pending_rank,
		source_spell_id,
		trigger_sequence,
		request_id,
	))


func _process_evolution_queue_at_safe_point() -> void:
	if _evolution_processing or not _evolution_queue.has_pending():
		return
	_evolution_processing = true
	_lock_combat_for_evolution(false)
	while _evolution_queue.has_pending() and not _closing and not _battle_over:
		var request := _evolution_queue.peek()
		if not _is_request_still_pending(request):
			_evolution_queue.discard_current()
			continue
		var run_ui: PersistentRunUI = GameManager.get_persistent_run_ui()
		if run_ui == null:
			push_error("Évolution en combat impossible : PersistentRunUI indisponible.")
			break
		_lock_combat_for_evolution(false)
		var opened: bool = await run_ui.open_evolution_request(request)
		if not opened:
			push_error(
				"Évolution en combat impossible : ouverture de l’arbre refusée."
			)
			break
		_lock_combat_for_evolution(true)
		var resolved_request_id: StringName = &""
		while resolved_request_id != request.request_id:
			var resolution: Array = await run_ui.evolution_choice_resolved
			if resolution.size() >= 1:
				resolved_request_id = StringName(resolution[0])
		if _is_request_still_pending(request):
			push_error(
				"Évolution en combat refusée : le choix n’a pas été enregistré."
			)
			break
		_evolution_queue.complete_current()
		run_ui.refresh_from_context()
	_evolution_processing = false
	if _evolution_queue.has_pending() or _closing or _battle_over:
		return
	_resume_combat_after_evolutions()


func _is_request_still_pending(request: EvolutionRequest) -> bool:
	if request == null:
		return false
	var state: CharacterRunState = GameManager.get_character_state(
		request.character_id
	)
	if state == null:
		return false
	var progress: DisciplineProgressState = state.get_discipline_progress(
		request.discipline_id
	)
	return progress != null \
		and progress.get_pending_rank_choices().has(request.pending_rank)


func _lock_combat_for_evolution(ui_open: bool) -> void:
	if turn_state != null:
		if ui_open:
			turn_state.begin_skill_evolution_ui()
		else:
			turn_state.begin_skill_evolution_pending()
	if _hud_port != null:
		_hud_port.set_controls_enabled(false)
		_hud_port.set_active_mode("")
	if is_instance_valid(grid_view):
		grid_view.clear_highlights()


func _resume_combat_after_evolutions() -> void:
	if _battle_outcome_waiting:
		_commit_waiting_battle_outcome()
		return
	if _turn_start_deferred_for_evolution:
		_turn_start_deferred_for_evolution = false
		var deferred_unit = get_active_unit()
		if deferred_unit != null:
			_on_turn_started(deferred_unit)
		return
	var active_unit = get_active_unit()
	if active_unit == null:
		if turn_state != null:
			turn_state.begin_player_turn()
		return
	if _end_active_turn_if_dead(active_unit):
		return
	if active_unit.team == 0:
		turn_state.begin_player_turn()
		if _hud_port != null:
			_hud_port.set_controls_enabled(true)
			_hud_port.update_info(active_unit)
	else:
		turn_state.begin_enemy_turn()
		if _hud_port != null:
			_hud_port.set_controls_enabled(false)


func _is_evolution_locked() -> bool:
	return _evolution_processing \
		or _evolution_queue.has_pending() \
		or (turn_state != null and turn_state.is_skill_evolution_locked())


func _exit_tree() -> void:
	_begin_battle_shutdown()
	if GameManager.discipline_xp_gained.is_connected(
		_on_discipline_xp_gained
	):
		GameManager.discipline_xp_gained.disconnect(_on_discipline_xp_gained)
	if _uses_persistent_action_bar:
		GameManager.unbind_combat_context(self)
	_uses_persistent_action_bar = false
	if _hud_port != null:
		_hud_port.detach()
		_hud_port = null
	_spell_resolution_pending = false
	_evolution_processing = false
	_evolution_queue.clear()
	if is_instance_valid(_spell_impact_scheduler):
		_spell_impact_scheduler.cancel_all()


func _begin_battle_shutdown() -> void:
	if not _closing:
		_closing = true
		_lifecycle_generation += 1
	if is_instance_valid(_enemy_turn):
		_enemy_turn.cancel_pending_actions()
	if turn_queue != null \
			and turn_queue.turn_started.is_connected(_on_turn_started):
		turn_queue.turn_started.disconnect(_on_turn_started)
	if is_instance_valid(turn_order_timeline):
		turn_order_timeline.clear_queue()
	for view in _unit_views.values():
		if is_instance_valid(view) \
				and view.has_method("cancel_pending_visual_actions"):
			view.cancel_pending_visual_actions()
	if is_instance_valid(_spell_impact_scheduler):
		_spell_impact_scheduler.cancel_all()
	_spell_resolution_pending = false
	var vfx_layer := get_node_or_null("VFXLayer")
	if is_instance_valid(vfx_layer):
		for child in vfx_layer.get_children():
			child.queue_free()
	if is_instance_valid(grid_view):
		VFXManager.unregister_battle_view(grid_view)

func _on_round_started(number: int) -> void:
	DebugLogger.set_turn(number)
	DebugLogger.info(DebugLogger.LogCategory.TURN, "Round %d" % number)
	if terrain_effects != null and terrain_effects.runtime_service != null:
		terrain_effects.runtime_service.configure_resolution_context(0, number)
	if terrain_effects != null and number > 1:
		terrain_effects.tick_all_effects()
		grid_view.queue_redraw()

func _on_unit_died(unit: Unit) -> void:
	# Logique de combat uniquement. Le LOG ("est vaincu") est désormais produit
	# par le CombatLogger, abonné au signal unit_died du bus. battle.gd ne logge
	# plus la mort : il réagit à ses conséquences sur le terrain et le combat.
	if spell_caster != null:
		spell_caster.cancel_pending_for_unit(unit, &"caster_dead")
	grid.clear_unit(unit.grid_pos)
	turn_queue.on_unit_died(unit)
	_check_battle_end()

func _check_battle_end() -> void:
	var heroes_alive = turn_queue.count_living_in_team(0)
	var enemies_alive = turn_queue.count_living_in_team(1)
	if heroes_alive == 0:
		_request_battle_outcome(false)
	elif enemies_alive == 0:
		_request_battle_outcome(true)


func _request_battle_outcome(victory: bool) -> void:
	if _spell_resolution_pending \
			or _evolution_processing \
			or _evolution_queue.has_pending():
		_battle_outcome_waiting = true
		_waiting_outcome_victory = victory
		return
	_end_battle(victory)


func _commit_waiting_battle_outcome() -> void:
	if not _battle_outcome_waiting:
		return
	var victory := _waiting_outcome_victory
	_battle_outcome_waiting = false
	_end_battle(victory)

# ============================================================
# FIN DE COMBAT
# Prévient le GameManager, qui orchestre la suite (transition + salle).
# ============================================================

func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	if _evolution_processing or _evolution_queue.has_pending():
		_battle_outcome_waiting = true
		_waiting_outcome_victory = victory
		return
	_battle_over = true
	if presentation_state != null:
		presentation_state.begin_battle_ending()
	EventBus.combat_ended.emit(victory)
	_begin_battle_shutdown()
	if is_instance_valid(grid_view):
		grid_view.clear_highlights()
	if _hud_port != null:
		_hud_port.set_controls_enabled(false)
	_prepare_final_battle_frame()
	_queue_local_battle_outcome_presentation(victory)

	# Le délai est possédé par le GameManager persistant. La Battle peut donc
	# quitter l'arbre sans qu'une coroutine locale ne tente de reprendre.
	GameManager.schedule_battle_outcome(
		victory,
		0.45 if GameManager.is_reduced_motion_enabled() else END_SCREEN_DELAY,
	)


func _prepare_final_battle_frame() -> void:
	for layer in [
		action_bar,
		inspect_panel,
		player_combat_log,
		keyword_tooltip_layer,
		turn_order_timeline,
	]:
		if is_instance_valid(layer):
			layer.visible = false
	var feedback_controller := get_node_or_null("FloatingTextSpawner")
	if feedback_controller != null \
			and feedback_controller.has_method("clear_feedback"):
		feedback_controller.clear_feedback()


func _queue_local_battle_outcome_presentation(victory: bool) -> void:
	var callback := Callable(self, "_on_final_battle_frame_drawn").bind(victory)
	if not RenderingServer.frame_post_draw.is_connected(callback):
		RenderingServer.frame_post_draw.connect(callback, CONNECT_ONE_SHOT)


func _on_final_battle_frame_drawn(victory: bool) -> void:
	if not is_inside_tree() or not _battle_over:
		return
	if victory:
		GameManager.capture_battle_outcome_background()
	_show_end_screen(victory)


func _next_action_id(kind: StringName) -> StringName:
	_action_sequence += 1
	return StringName("%s_%06d" % [kind, _action_sequence])

func _show_end_screen(victory: bool) -> void:
	if is_instance_valid(keyword_tooltip_layer) \
			and keyword_tooltip_layer.has_method("set_modal_blocked"):
		keyword_tooltip_layer.set_modal_blocked(true)
	if is_instance_valid(_outcome_overlay):
		_outcome_overlay.queue_free()
	_outcome_overlay = COMBAT_OUTCOME_OVERLAY.new()
	add_child(_outcome_overlay)
	_outcome_overlay.present(victory, GameManager.is_reduced_motion_enabled())
