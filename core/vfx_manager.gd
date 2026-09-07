# core/vfx_manager.gd
extends Node

const ACHILLES_EFFECTS_PATH := "res://assets/vfx/achilles_kit_v2/effects.tres"
const AchillesFX := preload("res://vfx/achilles_kit/achilles_spell_sprite_vfx.gd")
const ParisRouter := preload("res://vfx/paris/paris_spell_vfx_router.gd")
const PHILOSOPHER_EFFECTS_PATH := "res://assets/vfx/philosopher_mage/sprites_v1/effects.tres"
const PhilosopherFX := preload("res://vfx/philosopher_mage/philosopher_spell_sprite_vfx.gd")
const PHILOSOPHER_SPELLS := [&"philosopher_axiom", &"philosopher_refutation",
	&"philosopher_mending", &"philosopher_aporia", &"philosopher_aegis"]

var _battle_view : Node = null
var _paris_router: ParisSpellVFXRouter
var _achilles_frames: SpriteFrames
var _achilles_flights: Dictionary = {}
var _achilles_arrivals: Dictionary = {}
var _achilles_effects: Array[Node] = []
var _barrier_bindings: Dictionary = {}
var _philosopher_frames: SpriteFrames
var _philosopher_effects: Array[Node] = []
var _philosopher_flights: Dictionary = {}
var _philosopher_holds: Dictionary = {}
var _philosopher_resolved_actions: Array[String] = []

func register_battle_view(view: Node) -> void:
	if _battle_view != view:
		_clear_achilles_effects()
		_clear_philosopher_effects()
		_clear_paris_effects()
	_battle_view = view
	_get_paris_router().load_frames()
	# Load outside the release frame so a first disk read cannot consume most
	# of the short projectile delay before the player sees frame zero.
	if _achilles_frames == null and ResourceLoader.exists(ACHILLES_EFFECTS_PATH):
		_achilles_frames = load(ACHILLES_EFFECTS_PATH) as SpriteFrames
	if _philosopher_frames == null and ResourceLoader.exists(PHILOSOPHER_EFFECTS_PATH):
		_philosopher_frames = load(PHILOSOPHER_EFFECTS_PATH) as SpriteFrames

func unregister_battle_view(view: Node = null) -> void:
	if view == null or _battle_view == view:
		_clear_achilles_effects()
		_clear_philosopher_effects()
		_clear_paris_effects()
		_battle_view = null

func _ready() -> void:
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.spell_visual_resolved.connect(_on_spell_visual_resolved)
	EventBus.unit_visual_movement_finished.connect(_on_unit_visual_movement_finished)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.status_applied.connect(_on_status_applied)
	EventBus.battle_view_ready.connect(register_battle_view)

func _on_spell_cast(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if ParisRouter.is_spell(caster, spell):
		_get_paris_router().resolve(caster, spell, report)
		return
	if _is_philosopher_spell(caster, spell):
		_resolve_philosopher_vfx(caster, spell, report)
		return
	if caster == null or spell == null or bool(report.get("failed", false)):
		return
	var presentation := _achilles_presentation(caster, spell, report)
	if _is_achilles_presentation(presentation) and not spell.is_delayed():
		_resolve_achilles_vfx(caster, spell, report, presentation)
		# Preserve the source-bound bronze guard aura and its existing lifecycle.
		if presentation.action_family == &"guard":
			_play_legacy_spell_vfx(caster, spell, report.get("cell", caster.grid_pos))
		return
	# A delayed cast is only its warning phase. Its impact is played explicitly
	# by Battle after the pending ability has passed its spatial revalidation.
	if spell.is_delayed() or spell.impact_delay_seconds > 0.0:
		return
	play_spell_vfx(caster, spell, report.get("cell", caster.grid_pos))


func play_spell_vfx(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if ParisRouter.is_spell(caster, spell):
		return _get_paris_router().launch(caster, spell, cell)
	if caster == null or spell == null:
		return null
	if _is_philosopher_spell(caster, spell):
		if spell.get_effective_spell_id() == &"philosopher_axiom" and spell.impact_delay_seconds > 0.0:
			return _launch_philosopher_projectile(caster, spell, cell)
		return null
	var presentation := _achilles_presentation(caster, spell)
	if _is_achilles_presentation(presentation) and presentation.action_family == &"shot" \
			and spell.impact_delay_seconds > 0.0:
		return _launch_achilles_projectile(caster, spell, cell, presentation)
	return _play_legacy_spell_vfx(caster, spell, cell)


func _play_legacy_spell_vfx(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if spell.vfx_scene == null:
		return null
	if not is_instance_valid(_battle_view) or not _battle_view.is_inside_tree():
		_battle_view = null
		return null
	var caster_view_pos := _caster_effect_origin(caster)
	var target_position := _grid_cell_global(cell)
	var vfx = spell.vfx_scene.instantiate()
	var parent := _vfx_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		vfx.free()
		return null
	parent.add_child(vfx)
	if spell.vfx_placement == Spell.VfxPlacement.TARGET_CELL:
		if vfx is Node2D:
			(vfx as Node2D).global_position = target_position
		elif vfx.has_method("initialiser_cible"):
			vfx.initialiser_cible(target_position)
	elif vfx.has_method("initialiser"):
		vfx.initialiser(caster_view_pos, target_position)
	elif vfx is Node2D:
		(vfx as Node2D).global_position = target_position
	# Optional contract for status-bound sprite effects. Ordinary scene VFX
	# retain their existing placement and initialization behavior.
	if vfx.has_method("bind_source_unit"):
		vfx.bind_source_unit(caster, _find_unit_view(caster))
	return vfx


# Additive data-driven entry point. The legacy Spell.vfx_scene path above is
# intentionally unchanged; callers must provide gameplay-resolved positions.
func play_profile(
		profile: VFXProfile,
		context: VFXExecutionContext,
		sequence_id: StringName = &"play",
		parent_override: Node = null
	) -> VFXRuntimeInstance:
	if profile == null or context == null:
		return null
	var parent := parent_override
	if parent == null:
		parent = context.get_target_layer()
	if parent == null:
		parent = _vfx_parent()
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var result := VFXProfileRunner.play(profile, context, sequence_id, parent)
	if not bool(result.get("ok", false)):
		push_warning("VFXProfile ignoré sans impact gameplay : %s" % result.get("errors", []))
		return null
	return result.get("instance") as VFXRuntimeInstance

func _find_unit_view(unit: Unit) -> Node2D:
	if not is_instance_valid(_battle_view) or not _battle_view.is_inside_tree():
		return null
	for candidate in _battle_view.get_tree().get_nodes_in_group("unit_views"):
		if candidate is Node2D and candidate.get("unit") == unit:
			return candidate as Node2D
	return null


func _caster_effect_origin(caster: Unit) -> Vector2:
	if is_instance_valid(_battle_view) and _battle_view.is_inside_tree():
		var tree := _battle_view.get_tree()
		if tree == null:
			return _grid_cell_global(caster.grid_pos)
		for candidate in tree.get_nodes_in_group("unit_views"):
			if candidate.get("unit") == caster \
					and candidate.has_method("get_cast_effect_origin_global"):
				return candidate.get_cast_effect_origin_global()
	return _grid_cell_global(caster.grid_pos)

func _on_status_applied(unit: Unit, status_data: StatusData) -> void:
	if status_data.vfx_scene == null:
		return
	if not is_instance_valid(_battle_view) or not _battle_view.is_inside_tree():
		_battle_view = null
		return
	var pos := _grid_cell_global(unit.grid_pos)
	var vfx = status_data.vfx_scene.instantiate()
	_vfx_parent().add_child(vfx)
	vfx.initialiser(pos)

func _grid_cell_global(cell: Vector2i) -> Vector2:
	var local_position: Vector2
	if _battle_view.has_method("grid_to_local"):
		local_position = _battle_view.grid_to_local(cell)
	else:
		local_position = _battle_view.grid_to_world(cell)
	return _battle_view.to_global(local_position)

func _vfx_parent() -> Node:
	if not is_instance_valid(_battle_view):
		return null
	var battle_root := _battle_view.get_parent()
	if battle_root != null:
		var layer := battle_root.get_node_or_null("VFXLayer")
		if layer != null:
			return layer
	return _battle_view


func _is_achilles_presentation(presentation: Dictionary) -> bool:
	return presentation.get("action_family", &"generic") in [&"strike", &"dash", &"shot", &"guard"] \
		and str(presentation.get("inherited_spell_id", &"")).begins_with("achilles_")


func _achilles_presentation(caster: Unit, spell: Spell, report: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = report.get("visual_presentation", {})
	if not resolved.is_empty():
		return resolved.duplicate(true)
	var unit_view := _find_unit_view(caster)
	if unit_view != null:
		# The façade snapshot was also sent to the body sprite renderer.
		var visual: Node = unit_view.get("_optional_visual") as Node
		if visual != null and visual.has_method("get_action_presentation"):
			var current: Dictionary = visual.get_action_presentation()
			if current.get("spell_id", &"") == spell.get_effective_spell_id():
				return current.duplicate(true)
	return AchillesSpellVisualResolver.resolve(spell, caster)


func _launch_achilles_projectile(caster: Unit, spell: Spell, cell: Vector2i,
		presentation: Dictionary) -> Node:
	if not _has_battle_view():
		return null
	var origin_cell := caster.grid_pos
	var cells: Array = [cell]
	var adapter = caster.mastery_combat_adapter
	if adapter != null:
		origin_cell = adapter.projectile_origin(caster, spell)
		var shaped: Array = adapter.preview_target_cells(caster, spell, cell)
		if not shaped.is_empty():
			cells = shaped
	# A piercing arrow traverses the real preview line; a volley separates into
	# one arrow per legal fan cell. No targets are fabricated outside the grid.
	if presentation.get("variant", &"base") in [&"piercing", &"death_line"] and cells.size() > 1:
		cells = [cells.back()]
	var origin := _caster_effect_origin(caster)
	if origin_cell != caster.grid_pos:
		origin += _grid_cell_global(origin_cell) - _grid_cell_global(caster.grid_pos)
	var targets: Array[Vector2] = []
	for target_cell in cells:
		targets.append(_impact_cell_position(target_cell))
	var fx := _new_achilles_effect(presentation, origin, targets, _cell_visual_width() * 0.85)
	if fx == null:
		return null
	var key := _flight_key(caster, spell)
	var previous: Node = _achilles_flights.get(key) as Node
	if is_instance_valid(previous):
		previous.cancel()
	_achilles_flights[key] = fx
	fx.start_flight(spell.impact_delay_seconds)
	return fx


func _resolve_achilles_vfx(caster: Unit, spell: Spell, report: Dictionary,
		presentation: Dictionary) -> void:
	if not _has_battle_view():
		return
	var cell: Vector2i = report.get("cell", caster.grid_pos)
	var targets := _resolved_impact_positions(report)
	var family := StringName(presentation.get("action_family", &"generic"))
	var origin := _caster_effect_origin(caster)
	match family:
		&"shot":
			var key := _flight_key(caster, spell)
			var flight: Node = _achilles_flights.get(key) as Node
			_achilles_flights.erase(key)
			if is_instance_valid(flight):
				flight.confirm_impact(targets)
			elif not targets.is_empty():
				# Headless/direct calls and automatic reactions only acknowledge
				# the actual hit: never start a late flight after the HP loss.
				_burst(presentation, &"impact", origin, targets, 0.55)
		&"strike":
			if presentation.get("variant", &"base") in [&"scourge", &"sweep"]:
				_burst(presentation, &"sweep", origin, [_impact_cell_position(cell)], 1.15)
			if not targets.is_empty():
				_burst(presentation, &"impact", origin, targets, 0.52)
		&"guard":
			if int(report.get("shield_increase_total", 0)) > 0:
				_burst(presentation, &"guard", origin, [origin], 1.12)
			_bind_barrier_visuals(caster.mastery_combat_adapter)
		&"dash":
			if int(report.get("movement_count", 0)) <= 0:
				return
			var from_cell: Vector2i = presentation.get("origin_cell", caster.grid_pos)
			var departure := _grid_cell_global(from_cell)
			_burst(presentation, &"dust", departure, [departure], 0.72)
			_achilles_arrivals[caster] = {"spell": spell, "report": report.duplicate(true),
				"presentation": presentation.duplicate(true), "destination": cell, "arrived": false}


func _on_spell_visual_resolved(caster: Unit, spell: Spell, report: Dictionary,
		presentation: Dictionary) -> void:
	if caster == null or spell == null or not _is_achilles_presentation(presentation) \
			or bool(report.get("failed", false)) or not _has_battle_view():
		return
	if bool(presentation.get("movement_arrival_only", false)):
		var pending: Dictionary = _achilles_arrivals.get(caster, {})
		if pending.is_empty() or pending.destination != report.get("cell"):
			return
		var pending_visual: Dictionary = pending.presentation
		if pending_visual.get("action_id", &"") != presentation.get("action_id", &""):
			return
		var pending_report: Dictionary = pending.report
		var feedback: Array = pending_report.get("visual_feedback", [])
		feedback.append_array(report.get("visual_feedback", []))
		pending_report["visual_feedback"] = feedback
		if bool(pending.get("arrived", false)):
			_play_bastion_feedback(caster, pending)
		return
	var actual := _resolved_impact_positions(report)
	if not actual.is_empty():
		# Synchronous acknowledgement of a resolved automatic action. This does
		# not call UnitView, launch another cast, or enqueue any gameplay work.
		_burst(presentation, &"impact", _caster_effect_origin(caster), actual, 0.52, 0.16)


func _on_unit_visual_movement_finished(unit: Unit) -> void:
	var pending: Dictionary = _achilles_arrivals.get(unit, {})
	if pending.is_empty() or not _has_battle_view() or unit == null or not unit.is_alive \
			or unit.grid_pos != pending.destination:
		return
	var presentation: Dictionary = pending.presentation
	var arrival := _grid_cell_global(unit.grid_pos)
	if not bool(pending.get("arrived", false)):
		_burst(presentation, &"dust", arrival, [arrival], 0.65, 0.18)
	pending["arrived"] = true
	_play_bastion_feedback(unit, pending)


func _play_bastion_feedback(unit: Unit, pending: Dictionary) -> void:
	if unit == null or not unit.is_alive or unit.grid_pos != pending.destination:
		return
	var presentation: Dictionary = pending.presentation
	var feedback: Array = (pending.report as Dictionary).get("visual_feedback", [])
	for fact in feedback:
		if fact.get("kind", &"") != &"bastion_impact" or fact.get("cell") != unit.grid_pos:
			continue
		# This acknowledges the real Bastion reaction. Battle flushes it at
		# arrival; an already recorded arrival is accepted too. Victim cells
		# were captured before their resolved push.
		var bastion_visual := presentation.duplicate(true)
		bastion_visual["variant"] = &"bastion"
		bastion_visual["effect_variant"] = &"dash_bastion"
		var center := _caster_effect_origin(unit)
		_burst(bastion_visual, &"guard", center, [center], 1.25)
		var targets: Array[Vector2] = []
		for target_cell in fact.get("target_cells", []):
			targets.append(_impact_cell_position(target_cell))
		if not targets.is_empty() and int(fact.get("raw_damage", 0)) > 0:
			_burst(bastion_visual, &"impact", center, targets, 0.58)
	feedback.clear()


func _resolved_impact_positions(report: Dictionary) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if report.has("visual_impact_cells"):
		for cell in report.visual_impact_cells:
			targets.append(_impact_cell_position(cell))
		return targets
	for value in report.get("damaged_enemies", []):
		var target := value as Unit
		if target != null:
			targets.append(_impact_cell_position(target.grid_pos))
	return targets


func _burst(presentation: Dictionary, animation: StringName, origin: Vector2,
		targets: Array[Vector2], width_ratio: float, duration: float = 0.24) -> Node:
	var fx := _new_achilles_effect(presentation, origin, targets, _cell_visual_width() * width_ratio)
	if fx != null:
		fx.start_burst(animation, duration)
	return fx


func _new_achilles_effect(presentation: Dictionary, origin: Vector2,
		targets: Array[Vector2], width: float) -> Node:
	if not _has_battle_view() or not ResourceLoader.exists(ACHILLES_EFFECTS_PATH):
		return null
	if _achilles_frames == null:
		_achilles_frames = load(ACHILLES_EFFECTS_PATH) as SpriteFrames
	if _achilles_frames == null:
		return null
	var parent := _vfx_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var fx := AchillesFX.new()
	parent.add_child(fx)
	# A mastery accent changes visual weight only, never its affected cells.
	var tier := clampi(int(presentation.get("intensity_tier", 0)), 0, 2)
	var visual_width := width * (1.0 + 0.08 * float(tier))
	fx.configure(_achilles_frames, presentation, origin, targets, visual_width)
	_prune_achilles_effects()
	_achilles_effects.append(fx)
	return fx


func _prune_achilles_effects() -> void:
	# Freed Object references cannot enter a typed Node callback. Test the
	# array slot before any typed assignment, and preserve the typed array.
	for index in range(_achilles_effects.size() - 1, -1, -1):
		if not is_instance_valid(_achilles_effects[index]):
			_achilles_effects.remove_at(index)


func _bind_barrier_visuals(adapter) -> void:
	if adapter == null or not adapter.has_method("barrier_visual_entries"):
		return
	if not _barrier_bindings.has(adapter):
		var callback := _sync_barrier_visuals.bind(adapter)
		adapter.barrier_changed.connect(callback)
		_barrier_bindings[adapter] = {"callback": callback, "nodes": {}}
	_sync_barrier_visuals([], adapter)


func _sync_barrier_visuals(_cells: Array, adapter) -> void:
	if not _barrier_bindings.has(adapter) or not _has_battle_view():
		return
	var nodes: Dictionary = _barrier_bindings[adapter].nodes
	var wanted := {}
	for entry in adapter.barrier_visual_entries():
		var owner := entry.get("owner") as Unit
		if owner == null:
			continue
		for cell in entry.get("cells", []):
			var key := "%s:%s" % [owner.get_instance_id(), str(cell)]
			wanted[key] = true
			if is_instance_valid(nodes.get(key)):
				continue
			var presentation := {"spell_id": &"achilles_bronze_guard", "action_family": &"guard",
				"variant": &"rampart", "effect_variant": &"guard_rampart", "cell": cell,
				"palette_variant": &"aeacus"}
			var position := _impact_cell_position(cell)
			var fx := _new_achilles_effect(presentation, position, [position], _cell_visual_width() * 0.92)
			if fx != null:
				fx.start_hold()
				nodes[key] = fx
	for key in nodes.keys():
		if not wanted.has(key):
			if is_instance_valid(nodes[key]):
				nodes[key].cancel()
			nodes.erase(key)


func _flight_key(caster: Unit, spell: Spell) -> String:
	return "%s:%s" % [caster.get_instance_id(), spell.get_effective_spell_id()]


func _impact_cell_position(cell: Vector2i) -> Vector2:
	return _grid_cell_global(cell) + Vector2(0.0, -_cell_visual_width() * 0.32)


func _cell_visual_width() -> float:
	if not _has_battle_view():
		return 128.0
	# The sum of the two isometric basis lengths is stable across map zooms.
	var origin := _grid_cell_global(Vector2i.ZERO)
	return maxf(1.0, (_grid_cell_global(Vector2i.RIGHT) - origin).length() * 1.8)


func _has_battle_view() -> bool:
	return is_instance_valid(_battle_view) and _battle_view.is_inside_tree()


func _on_combat_ended(_victory: bool) -> void:
	_clear_achilles_effects()
	_clear_philosopher_effects()
	_clear_paris_effects()


func _clear_achilles_effects() -> void:
	for adapter in _barrier_bindings:
		var callback: Callable = _barrier_bindings[adapter].callback
		if adapter.barrier_changed.is_connected(callback):
			adapter.barrier_changed.disconnect(callback)
	_barrier_bindings.clear()
	for index in range(_achilles_effects.size() - 1, -1, -1):
		if is_instance_valid(_achilles_effects[index]):
			_achilles_effects[index].cancel()
	_achilles_effects.clear()
	_achilles_flights.clear()
	_achilles_arrivals.clear()


func _is_philosopher_spell(caster: Unit, spell: Spell) -> bool:
	return caster != null and caster.unit_id == &"philosopher_mage" and spell != null \
		and spell.get_effective_spell_id() in PHILOSOPHER_SPELLS


func _launch_philosopher_projectile(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if not _has_battle_view():
		return null
	var key := _flight_key(caster, spell)
	var previous: Variant = _philosopher_flights.get(key)
	if is_instance_valid(previous) and not previous.get_debug_state().closed:
		return previous
	var origin := _caster_effect_origin(caster)
	var targets: Array[Vector2] = [_impact_cell_position(cell)]
	var effect := _new_philosopher_effect(spell.spell_id, origin, targets, _cell_visual_width() * 0.58)
	if effect == null:
		return null
	_philosopher_flights[key] = effect
	effect.start_flight(spell.impact_delay_seconds)
	return effect


func _resolve_philosopher_vfx(caster: Unit, spell: Spell, report: Dictionary) -> void:
	var flight_key := _flight_key(caster, spell)
	var flight: Variant = _philosopher_flights.get(flight_key)
	if bool(report.get("failed", false)):
		if is_instance_valid(flight):
			flight.cancel()
		_philosopher_flights.erase(flight_key)
		return
	if not _has_battle_view():
		return
	var action_id := str(report.get("action_id", ""))
	var resolved_key := "%s:%s:%s" % [caster.get_instance_id(), spell.spell_id, action_id]
	if action_id != "" and _philosopher_resolved_actions.has(resolved_key):
		return
	if action_id != "":
		_philosopher_resolved_actions.append(resolved_key)
		if _philosopher_resolved_actions.size() > 128:
			_philosopher_resolved_actions.pop_front()
	var origin := _caster_effect_origin(caster)
	# All five canonical spells are SINGLE. report.cell is captured by
	# SpellCaster before impacts and push, unlike the victim's current cell.
	var cell: Vector2i = report.get("cell", caster.grid_pos)
	var impact_position := _impact_cell_position(cell)
	var impacted: Array[Vector2] = []
	if not (report.get("damaged_enemies", []) as Array).is_empty():
		impacted.append(impact_position)
	match spell.get_effective_spell_id():
		&"philosopher_axiom":
			_philosopher_flights.erase(flight_key)
			if is_instance_valid(flight):
				flight.confirm_impact(impacted)
			elif not impacted.is_empty():
				_philosopher_burst(spell, &"impact", origin, impacted, 0.60, 0.24)
		&"philosopher_refutation":
			if bool(report.get("pushed", false)) or bool(report.get("collision", false)):
				_philosopher_burst(spell, &"repel", origin, [impact_position], 1.12, 0.34)
			if not impacted.is_empty():
				_philosopher_burst(spell, &"impact", origin, impacted, 0.55, 0.24)
		&"philosopher_mending":
			if not (report.get("healed_units", []) as Array).is_empty():
				_philosopher_burst(spell, &"heal", origin, [impact_position], 0.90, 0.48)
		&"philosopher_aegis":
			for value in report.get("shielded_units", []):
				var target := value as Unit
				if is_instance_valid(target) and target.get_shield_value(spell.spell_id) > 0:
					_bind_philosopher_effect(spell, target, &"shield", &"shield", spell.spell_id)
		&"philosopher_aporia":
			if spell.applied_status == null:
				return
			var status_id := spell.applied_status.get_effective_status_id()
			for value in report.get("status_changed_units", []):
				var target := value as Unit
				if is_instance_valid(target) and target.has_status(status_id):
					_bind_philosopher_effect(spell, target, &"control", &"status", status_id)


func _philosopher_burst(spell: Spell, animation: StringName, origin: Vector2,
		targets: Array[Vector2], width_ratio: float, duration: float) -> Node:
	var effect := _new_philosopher_effect(spell.spell_id, origin, targets, _cell_visual_width() * width_ratio)
	if effect != null:
		effect.start_burst(animation, duration)
	return effect


func _bind_philosopher_effect(spell: Spell, target: Unit, animation: StringName,
		kind: StringName, source_id: StringName) -> Node:
	var target_view := _find_unit_view(target)
	if target_view == null:
		return null
	var key := "%s:%s:%s" % [target.get_instance_id(), kind, source_id]
	var previous: Variant = _philosopher_holds.get(key)
	if is_instance_valid(previous):
		previous.cancel()
	var width := _cell_visual_width()
	var offset := Vector2(0.0, -width * 0.28) if kind == &"shield" else Vector2(0.0, -width * 0.04)
	var position := target_view.global_position + offset
	var targets: Array[Vector2] = [position]
	var effect := _new_philosopher_effect(spell.spell_id, position, targets, width * 0.94)
	if effect == null:
		return null
	effect.start_bound(animation, target, target_view, kind, source_id, offset)
	_philosopher_holds[key] = effect
	return effect


func _new_philosopher_effect(spell_id: StringName, origin: Vector2,
		targets: Array[Vector2], width: float) -> Node:
	if not _has_battle_view() or targets.is_empty():
		return null
	if _philosopher_frames == null and ResourceLoader.exists(PHILOSOPHER_EFFECTS_PATH):
		_philosopher_frames = load(PHILOSOPHER_EFFECTS_PATH) as SpriteFrames
	if _philosopher_frames == null:
		return null
	var parent := _vfx_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var effect := PhilosopherFX.new()
	parent.add_child(effect)
	effect.configure(_philosopher_frames, spell_id, origin, targets, width)
	_prune_philosopher_effects()
	_philosopher_effects.append(effect)
	return effect


func _prune_philosopher_effects() -> void:
	for index in range(_philosopher_effects.size() - 1, -1, -1):
		if not is_instance_valid(_philosopher_effects[index]):
			_philosopher_effects.remove_at(index)
	for registry in [_philosopher_holds, _philosopher_flights]:
		for key in registry.keys():
			if not is_instance_valid(registry[key]):
				registry.erase(key)


func _clear_philosopher_effects() -> void:
	for index in range(_philosopher_effects.size() - 1, -1, -1):
		if is_instance_valid(_philosopher_effects[index]):
			_philosopher_effects[index].cancel()
	_philosopher_effects.clear()
	_philosopher_flights.clear()
	_philosopher_holds.clear()
	_philosopher_resolved_actions.clear()


func _exit_tree() -> void:
	_clear_philosopher_effects()
	_clear_paris_effects()


func _get_paris_router() -> ParisSpellVFXRouter:
	if _paris_router == null:
		_paris_router = ParisRouter.new(self)
	return _paris_router


func _clear_paris_effects() -> void:
	if _paris_router != null:
		_paris_router.clear()
