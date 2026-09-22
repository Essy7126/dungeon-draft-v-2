extends Node
## Observes confirmed facts. Never changes resources, timing, RNG or combat state.
const Catalog := preload("res://vfx/class_cards/class_card_vfx_catalog.gd")
const Player := preload("res://vfx/class_cards/class_card_vfx_player.gd")
const Flight := preload("class_card_vfx_flight.gd")
const Ground := preload("class_card_vfx_ground.gd")
const Profiles := preload("class_card_vfx_profiles.gd")
const STATUS_PRIORITY := [
	"ecosystem_stasis",
	"class_root",
	"class_burn",
	"class_bleed",
	"class_marked",
	"shield",
]
var manager: Node
var effects: Array[Node] = []
var holds := { }
var arrivals := { }
var resolved: Array[String] = []
var terrain: TerrainEffects
var surfaces := { }
var _scan_elapsed := 0.0
var flights := { }
var echoes: Array[Node] = []
var pending := { }
var surface_holds := { }
var ground_effects: Array[Node] = []
var observing := true


func _ready() -> void:
	EventBus.status_added.connect(_status_apply)
	EventBus.combat_status_refreshed.connect(_status_apply)
	EventBus.combat_status_expired.connect(_status_expire)
	EventBus.status_removed.connect(_status_removed)
	EventBus.status_tick.connect(_tick)
	EventBus.hp_damage_taken.connect(_terrain_damage)
	EventBus.heal_received.connect(_heal)
	EventBus.shield_granted.connect(_shield)
	EventBus.shield_absorption_resolved.connect(_absorb)
	EventBus.attack_dodge_resolved.connect(_dodge)
	EventBus.attack_immune.connect(_immune)
	EventBus.hit_resolved.connect(_critical)
	EventBus.unit_visual_movement_finished.connect(_arrived)
	EventBus.unit_died.connect(_died)
	EventBus.ability_telegraphed.connect(_telegraph)
	EventBus.pending_ability_resolved.connect(_pending_resolved)
	EventBus.pending_ability_blocked.connect(_pending_blocked)
	EventBus.pending_ability_cancelled.connect(_pending_cancelled)
	EventBus.hp_damage_taken.connect(_pending_damage)


static func handles(spell: Spell) -> bool:
	return spell != null and not Catalog.for_spell(spell).is_empty()


func _units() -> Array:
	if not is_instance_valid(manager) or not manager._has_battle_view():
		return []
	var host: Node = manager._battle_view.get_parent()
	if host == null:
		return []
	var members: Variant = host.get("units")
	return members if members is Array else []


func is_card_battle() -> bool:
	for unit in _units():
		if _card_unit(unit):
			return true
	return false


func accepts(caster: Unit, spell: Spell) -> bool:
	return _available() and caster in _units() and handles(spell)


func resolve(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if not accepts(caster, spell):
		return
	var had_flight := _finish_flight(caster, spell)
	if bool(report.get("failed", false)) \
			or spell.is_delayed():
		return
	var id := str(report.get("action_id", ""))
	var key := "%s:%s:%s" % [caster.get_instance_id(), spell.get_effective_spell_id(), id]
	if id != "" and key in resolved:
		return
	if id != "":
		resolved.append(key)
		if resolved.size() > 256:
			resolved.pop_front()
	var entry := Catalog.for_spell(spell)
	if entry.is_empty():
		return
	if entry.movement:
		if report.has("caster_movement_from") and report.has("caster_movement_to") \
				and report.caster_movement_from != report.caster_movement_to:
			var start: Vector2 = manager._grid_cell_global(report.caster_movement_from)
			var finish: Vector2 = manager._grid_cell_global(report.caster_movement_to)
			entry["direction"] = (finish - start).normalized()
			entry["travel_phase"] = "departure"
			_spawn(entry, start)
			var arrival := entry.duplicate(true)
			arrival["travel_phase"] = "arrival"
			arrivals[caster] = { "entry": arrival, "cell": report.caster_movement_to }
			if not is_instance_valid(manager._find_unit_view(caster)):
				_arrived(caster)
		return
	if entry.effect == "guard":
		if (
			str(spell.spell_id).begins_with("class_")
			and int(report.get("shield_increase_total", 0)) > 0
		):
			_at_unit(entry, caster)
		return
	if entry.family == "heal":
		return # Positive healing facts already play the local pulse.
	var cells: Array = []
	# The adapter captures these before forced displacement. Empty means no hit.
	if report.has("visual_impact_cells"):
		cells.assign(report.visual_impact_cells)
	else:
		for target in report.get("damaged_enemies", []):
			if is_instance_valid(target):
				var cell: Vector2i = report.get("cell", target.grid_pos) if not entry.area else target.grid_pos
				if cell not in cells:
					cells.append(cell)
	# Stasis applies no damage. Its changed-status report, not a hit or a
	# pre-existing hold, confirms the distinct epic application silhouette.
	if entry.effect == "stasis":
		for target in report.get("status_changed_units", []):
			if (
				is_instance_valid(target) and target in _units()
				and target.get_status_remaining(&"ecosystem_stasis", caster) > 0
				and target.grid_pos not in cells
			):
				cells.append(target.grid_pos)
	for cell in report.get("terrain_changed", []):
		_sync_surface(cell)
		if not entry.has("ground_motif") and cell not in cells:
			cells.append(cell)
	if cells.is_empty() and bool(report.get("pushed", false)) and report.has("cell"):
		cells.append(report.cell)
	for cell in cells:
		var impact_entry := entry.duplicate(true)
		# Zero-damage stasis is confirmed by an applied status, including the Paris exception.
		if entry.effect == "stasis":
			for unit: Unit in _units():
				if unit.grid_pos == cell:
					var actual := _status_recipe(unit, "ecosystem_stasis")
					if not actual.is_empty():
						impact_entry["motif"] = actual.motif
		var fx := _spawn(impact_entry, manager._grid_cell_global(cell))
		if fx != null:
			fx.origin = manager._caster_effect_origin(caster)
	if not had_flight and not cells.is_empty() and entry.ranged:
		_launch(caster, spell, cells[0], true)
	if bool(report.get("class_passive", false)):
		var passive := Catalog.feedback("mark", "passive")
		passive.width = .85
		passive.duration = .42
		passive.accent = entry.accent
		_at_unit(passive, caster)


func _available() -> bool:
	return (
		observing and is_instance_valid(manager) and manager._has_battle_view() and is_card_battle()
	)


func _card_unit(unit) -> bool:
	if not is_instance_valid(unit) or not unit is Unit:
		return false
	var session = CatabaseCombatModifier.session_for(unit)
	return session != null and session.cards != null


func _in_scope(fact: CombatEventFact) -> bool:
	return _available() and is_instance_valid(fact.target) and fact.target in _units()


func owns_status_feedback(fact: CombatEventFact) -> bool:
	return (
		fact != null and fact.event_type in [&"status_added", &"status_expired"] and _in_scope(fact)
	)


static func _status_priority(id: String) -> int:
	var rank := STATUS_PRIORITY.find(id)
	return 99 if rank < 0 else rank


func _spawn(entry: Dictionary, point: Vector2, anchor: Node2D = null, hold := false) -> Node:
	if not _available():
		return null
	var parent: Node = manager._vfx_parent()
	if not is_instance_valid(parent):
		return null
	effects = effects.filter(
		func(fx):
			return is_instance_valid(fx) and not fx.closed,
	)
	if effects.size() >= 96:
		var oldest: Node = null
		for old in effects:
			if not old.persistent:
				oldest = old
				break
		if oldest == null:
			return null
		oldest.cancel()
		effects.erase(oldest)
	var fx := Player.new()
	parent.add_child(fx)
	if anchor == null:
		# Split impact sheets around the visible actor, including before a pushed
		# actor reaches its new logical cell. The impact itself stays at world_point.
		for unit in _units():
			var candidate: Node2D = manager._find_unit_view(unit)
			if is_instance_valid(candidate) and candidate.global_position.distance_to(point) < 2.0:
				anchor = candidate
				break
	fx.configure(
		entry,
		point,
		manager._cell_visual_width() * float(entry.get("width", 1.5)),
		anchor,
		hold,
	)
	effects.append(fx)
	return fx


func _at_unit(entry: Dictionary, unit: Unit, hold := false) -> Node:
	if not is_instance_valid(unit) or not _available():
		return null
	var view: Node2D = manager._find_unit_view(unit)
	var point: Vector2 = (
		view.global_position
		if is_instance_valid(view)
		else manager._grid_cell_global(unit.grid_pos)
	)
	var following := entry.duplicate(true)
	following["follow_unit"] = true
	return _spawn(following, point, view, hold)


func _status_apply(fact: CombatEventFact) -> void:
	var id := str(fact.status_id)
	if not _in_scope(fact) or not fact.target.is_alive:
		return
	var entry := _status_recipe(fact.target, id)
	if entry.is_empty():
		return
	# Authored holds animate their own birth. The confirmed hit owns ignition;
	# layering another generic fire explosion here would count the same action twice.
	if not Profiles.STATES.has(id):
		_at_unit(entry, fact.target)
	_ensure_hold(fact.target, id, entry)


func _status_expire(fact: CombatEventFact) -> void:
	if not _in_scope(fact):
		return
	# Multiple casters may own the same state; keep the hold until the last source ends.
	var key := "%s:%s" % [fact.target.get_instance_id(), fact.status_id]
	if not fact.target.has_status(fact.status_id):
		_remove_hold(key, true)


func _status_removed(unit: Unit, id: StringName, _source: Unit) -> void:
	if _available() and unit in _units() and not unit.has_status(id):
		_remove_hold("%s:%s" % [unit.get_instance_id(), id], true)


func _status_recipe(unit: Unit, id: String) -> Dictionary:
	for state in unit.get_active_statuses():
		var data: StatusData = state.data
		if str(data.get_effective_status_id()) == id:
			var entry := Catalog.feedback(Catalog.status_family(data))
			entry.seed = absi(id.hash())
			return Profiles.state(entry, id, data)
	return { }


func _ensure_hold(unit: Unit, id: String, entry: Dictionary) -> void:
	var key := "%s:%s" % [unit.get_instance_id(), id]
	var anchor: Node2D = manager._find_unit_view(unit)
	if holds.has(key):
		var previous: Variant = holds[key].fx
		if is_instance_valid(previous) and not previous.closed and previous.anchor == anchor:
			return
		_remove_hold(key, false)
	var fx := _at_unit(entry, unit, true)
	if fx != null:
		holds[key] = { "unit": unit, "status": id, "fx": fx }
		_layout_holds()


func _layout_holds() -> void:
	# Stable compact badge rail. Overflow is explicit; the HUD retains all names and turns.
	var groups := { }
	for key in holds:
		var hold: Dictionary = holds[key]
		if not groups.has(hold.unit):
			groups[hold.unit] = []
		groups[hold.unit].append(key)
	for unit in groups:
		var keys: Array = groups[unit]
		keys.sort_custom(
			func(a, b):
				var left := _status_priority(holds[a].status)
				var right := _status_priority(holds[b].status)
				return str(holds[a].status) < str(holds[b].status) if left == right else left < right,
		)
		for i in keys.size():
			var fx = holds[keys[i]].fx
			if is_instance_valid(fx) and not fx.closed:
				fx.set_status_slot(i, keys.size())


func _restore_unit_holds() -> void:
	for unit: Unit in _units():
		if not unit.is_alive:
			continue
		var seen := { }
		for state in unit.get_active_statuses():
			var id := str(state.data.get_effective_status_id())
			if seen.has(id):
				continue
			seen[id] = true
			_ensure_hold(unit, id, _status_recipe(unit, id))
		if unit.current_shield > 0:
			_ensure_hold(unit, "shield", Profiles.state(Catalog.feedback("guard"), "shield"))


func _tick(fact: CombatEventFact) -> void:
	if not _in_scope(fact) or fact.amount_applied <= 0:
		return
	var family: String = Catalog.STATUSES.get(
		str(fact.status_id),
		"fire" if fact.element == Spell.Element.FIRE else "bleed",
	)
	var entry := Catalog.feedback(family, "tick")
	entry.duration = .45
	entry.width = 1.15
	Profiles.state(entry, str(fact.status_id))
	_at_unit(entry, fact.target)


func _heal(fact: CombatEventFact) -> void:
	if _in_scope(fact) and fact.amount_applied > 0:
		_at_unit(Catalog.feedback("heal"), fact.target)


func _shield(fact: CombatEventFact) -> void:
	if not _in_scope(fact) or fact.amount_applied <= 0:
		return
	var entry := Profiles.state(Catalog.feedback("guard"), "shield")
	if not str(fact.ability_id).begins_with("class_"):
		_at_unit(entry, fact.target)
	_ensure_hold(fact.target, "shield", entry)


func _absorb(fact: CombatEventFact) -> void:
	if _in_scope(fact) and fact.amount_absorbed > 0:
		_confirm_pending_hit(fact)
		var entry := Catalog.feedback(
			"guard",
			"break" if not fact.broken_source_ids.is_empty() else "absorb",
		)
		Profiles.state(entry, "shield")
		entry.duration = .4
		entry.width = 1.1
		_at_unit(entry, fact.target)


func _dodge(fact: CombatEventFact) -> void:
	if _in_scope(fact):
		_at_unit(Catalog.feedback("move", "dodge"), fact.target)


func _immune(fact: CombatEventFact) -> void:
	if _in_scope(fact):
		_at_unit(Catalog.feedback("guard", "immune"), fact.target)


func _critical(fact: CombatEventFact) -> void:
	if _in_scope(fact) and fact.is_critical and fact.amount_resolved > 0:
		var entry := Catalog.feedback("pierce", "critical")
		entry.width = .95
		entry.duration = .3
		_at_unit(entry, fact.target)


func _arrived(unit: Unit) -> void:
	if not arrivals.has(unit):
		return
	var arrival: Dictionary = arrivals[unit]
	arrivals.erase(unit)
	if is_instance_valid(unit) and unit.is_alive and unit.grid_pos == arrival.cell:
		_at_unit(arrival.entry, unit)


func _died(unit: Unit) -> void:
	arrivals.erase(unit)
	_drop_pending(unit)
	for key in holds.keys():
		if holds[key].unit == unit:
			_remove_hold(key, false)


func _process(delta: float) -> void:
	if not _available():
		return
	_scan_elapsed += delta
	if _scan_elapsed < .15:
		return
	_scan_elapsed = 0.0
	for key in holds.keys():
		var hold: Dictionary = holds[key]
		var unit = hold.unit
		if not is_instance_valid(unit) or not unit.is_alive or not is_instance_valid(hold.fx):
			_remove_hold(key, false)
		elif (
			unit.current_shield <= 0
			if hold.status == "shield"
			else not unit.has_status(StringName(hold.status))
		):
			_remove_hold(key, true)
	_restore_unit_holds()
	if terrain != null and terrain.runtime_service != null:
		for cell in terrain.active_surface_cells():
			_sync_surface(cell)


func activate() -> void:
	observing = true
	_scan_elapsed = .15


func _remove_hold(key: String, expire: bool) -> void:
	if not holds.has(key):
		return
	var hold: Dictionary = holds[key]
	holds.erase(key)
	if is_instance_valid(hold.fx):
		var visible_sign: bool = hold.fx.status_slot < (5 if hold.fx.status_count > 6 else 6)
		if expire and visible_sign and is_instance_valid(hold.unit):
			# A simultaneous purge has one compact release, never a pile of outro icons.
			var emit_release := true
			for old in effects:
				if (
					is_instance_valid(old) and not old.closed and old.badge_mode
					and not old.persistent and old.recipe.get("status_owner", 0) == hold
					.unit
					.get_instance_id()
				):
					if _status_priority(old.recipe.get("status_id", "")) < _status_priority(
						hold.status
					):
						emit_release = false
					else:
						old.cancel()
			# Preserve the actual held silhouette (notably Paris' PA-only stasis).
			var outro: Dictionary = hold.fx.recipe.duplicate(true)
			outro["feedback_phase"] = "expire"
			outro["duration"] = .48
			outro["status_id"] = hold.status
			outro["status_slot"] = hold.fx.status_slot
			outro["status_count"] = hold.fx.status_count
			outro["status_owner"] = hold.unit.get_instance_id()
			if emit_release:
				_at_unit(outro, hold.unit)
		hold.fx.cancel()
	_layout_holds()


func clear(stop_observing := false) -> void:
	if stop_observing:
		observing = false
	for fx in ground_effects:
		if is_instance_valid(fx):
			fx.cancel()
	ground_effects.clear()
	surface_holds.clear()
	for fx in flights.values() + echoes:
		if is_instance_valid(fx):
			fx.cancel()
	flights.clear()
	echoes.clear()
	pending.clear()
	for fx in effects:
		if is_instance_valid(fx):
			fx.cancel()
	effects.clear()
	holds.clear()
	arrivals.clear()
	resolved.clear()
	surfaces.clear()
	bind_terrain(null)


func bind_terrain(value: TerrainEffects) -> void:
	if terrain == value:
		return
	for fx in ground_effects:
		if is_instance_valid(fx):
			fx.cancel()
	ground_effects.clear()
	surface_holds.clear()
	surfaces.clear()
	if terrain != null:
		terrain.surface_applied.disconnect(_surface_updated)
		terrain.surface_refreshed.disconnect(_surface_updated)
		terrain.duration_changed.disconnect(_surface_updated)
		terrain.surface_cleared.disconnect(_surface_cleared)
		terrain.surface_replaced.disconnect(_surface_replaced)
		terrain.surface_reaction.disconnect(_surface_reaction)
	terrain = value
	if terrain != null:
		terrain.surface_applied.connect(_surface_updated)
		terrain.surface_refreshed.connect(_surface_updated)
		terrain.duration_changed.connect(_surface_updated)
		terrain.surface_cleared.connect(_surface_cleared)
		terrain.surface_replaced.connect(_surface_replaced)
		terrain.surface_reaction.connect(_surface_reaction)


func _surface_cleared(fact: Dictionary) -> void:
	var cell: Vector2i = fact.get("cell", Vector2i(-1, -1))
	var has_authored_outro := false
	if is_instance_valid(surface_holds.get(cell)):
		has_authored_outro = surface_holds[cell].motif != ""
		surface_holds[cell].release()
	surface_holds.erase(cell)
	if surfaces.has(cell) and _available() and not has_authored_outro:
		_spawn(Catalog.feedback(surfaces[cell], "expire"), manager._grid_cell_global(cell))
	surfaces.erase(cell)


func _surface_replaced(fact: Dictionary) -> void:
	_surface_cleared(fact)
	_surface_updated(fact)


func _surface_updated(fact: Dictionary) -> void:
	_sync_surface(fact.get("cell", Vector2i(-1, -1)))


func _sync_surface(cell: Vector2i) -> void:
	if not _available() or terrain == null or terrain.runtime_service == null:
		return
	var state := terrain.get_surface_state(cell)
	if state == null or not state.is_dynamic():
		return
	var family: String = {
		"fire": "fire",
		"lava": "fire",
		"ice": "ice",
		"water": "water",
		"poison": "poison",
		"steam": "move",
		"electrified_water": "lightning",
		"void": "shadow",
	}.get(str(state.surface_id), "")
	if family.is_empty():
		return
	var motif := Profiles.ground(state.source_spell, family)
	var previous: Variant = surface_holds.get(cell)
	if (
		is_instance_valid(previous) and not previous.closed
		and previous.family == family and previous.motif == motif
	):
		previous.remaining = state.remaining_duration
		return
	if is_instance_valid(previous):
		previous.release()
	var view: Node2D = manager._battle_view
	var host := view.get_parent()
	var parent: Node = host.get_node_or_null("ArenaDynamicSurfaceLayer")
	if parent == null:
		parent = view
	var polygon := PackedVector2Array()
	if view.has_method("get_cell_polygon"):
		for point in view.get_cell_polygon(cell):
			polygon.append(view.to_global(point))
	if polygon.size() != 4:
		var center: Vector2 = manager._grid_cell_global(cell)
		var x: Vector2 = (manager._grid_cell_global(cell + Vector2i.RIGHT) - center) * .5
		var y: Vector2 = (manager._grid_cell_global(cell + Vector2i.DOWN) - center) * .5
		polygon = PackedVector2Array(
			[center - x - y, center + x - y, center + x + y, center - x + y]
		)
	var fx := Ground.new()
	parent.add_child(fx)
	fx.configure(
		family,
		polygon,
		state.remaining_duration,
		float(absi(cell.x * 71 + cell.y * 137) % 997) * .01,
		motif,
	)
	ground_effects = ground_effects.filter(
		func(value):
			return is_instance_valid(value),
	)
	ground_effects.append(fx)
	surface_holds[cell] = fx
	surfaces[cell] = family


func _surface_reaction(fact: Dictionary) -> void:
	var cell: Vector2i = fact.get("cell", Vector2i(-1, -1))
	if _available():
		var family := "lightning" if "lightning" in str(fact.get("reaction", "")) else "move"
		_spawn(Catalog.feedback(family, "reaction"), manager._grid_cell_global(cell))


func _terrain_damage(fact: CombatEventFact) -> void:
	# Terrain damage currently has no ability id in CombatEventFact. Only acknowledge
	# a source-less, positive elemental hit on a still-live surface placed by a card.
	if (
		(
			not _in_scope(fact) or terrain == null \
					or fact.source != null
			or fact.is_periodic or fact.amount_applied <= 0
		) \
				or fact.ability_id != &""
		or not surfaces.has(fact.target.grid_pos)
	):
		return
	var data := terrain.get_effect_data(fact.target.grid_pos)
	if data != null and data.damage > 0 and data.element == fact.element:
		var entry := Catalog.feedback(surfaces[fact.target.grid_pos], "tick")
		var state := terrain.get_surface_state(fact.target.grid_pos)
		if (
			state != null
			and Profiles.ground(state.source_spell, surfaces[fact.target.grid_pos]) != ""
		):
			entry = Catalog.for_spell(state.source_spell)
			entry["feedback_phase"] = "tick"
			entry.duration = .45
		_at_unit(entry, fact.target)


func launch(caster: Unit, spell: Spell, cell: Vector2i) -> Node:
	if not accepts(caster, spell) or spell.impact_delay_seconds <= 0.0:
		return null
	return _launch(caster, spell, cell, false)


func _launch(caster: Unit, spell: Spell, cell: Vector2i, echo: bool) -> Node:
	var key: String = manager._flight_key(caster, spell)
	if not echo and is_instance_valid(flights.get(key)):
		return flights[key]
	var entry := Catalog.for_spell(spell)
	var fx := Flight.new()
	manager._vfx_parent().add_child(fx)
	var origin: Vector2 = manager._caster_effect_origin(caster)
	# Paris captures the exact bow/hand release point in his existing animation.
	if caster.unit_id == &"catabase_shadow_paris":
		origin = manager._get_paris_router()._release_origin(caster, spell)
	fx.configure(
		entry,
		origin,
		manager._impact_cell_position(cell),
		.18 if echo else spell.impact_delay_seconds,
		echo,
	)
	if echo:
		echoes = echoes.filter(
			func(value):
				return is_instance_valid(value),
		)
		echoes.append(fx)
	else:
		flights[key] = fx
	return fx


func _finish_flight(caster: Unit, spell: Spell) -> bool:
	var key: String = manager._flight_key(caster, spell)
	var fx: Variant = flights.get(key)
	flights.erase(key)
	if is_instance_valid(fx):
		fx.cancel()
		return true
	return false


func _telegraph(caster: Unit, spell: Spell, payload: Dictionary) -> void:
	if not accepts(caster, spell):
		return
	_drop_pending(caster)
	var entry := Catalog.for_spell(spell)
	var warning := Catalog.feedback("summon" if spell.is_summon() else "mark", "warning")
	warning.width = .9
	var cell: Vector2i = payload.get("cell", caster.grid_pos)
	var fx := _spawn(warning, manager._grid_cell_global(cell), null, true)
	pending[caster] = {
		"spell": spell,
		"entry": entry,
		"cell": cell,
		"target": payload.get("target"),
		"confirmed": false,
		"fx": fx,
	}


func _pending_damage(fact: CombatEventFact) -> void:
	if fact.amount_applied > 0:
		_confirm_pending_hit(fact)


func _confirm_pending_hit(fact: CombatEventFact) -> void:
	if not _in_scope(fact) or not pending.has(fact.source) or fact.is_periodic:
		return
	# SpellCaster clears the pending action immediately before its actual resolution.
	# Damage from the preparation turn must not confirm a later, possibly dodged hit.
	if not fact.source.pending_ability.is_empty():
		return
	var state: Dictionary = pending[fact.source]
	if state.target == fact.target:
		state.cell = fact.target.grid_pos # Before the delayed forced displacement.
		state.confirmed = true


func _pending_resolved(caster: Unit, spell: Spell, payload: Dictionary) -> void:
	if not accepts(caster, spell):
		return
	_finish_flight(caster, spell)
	var state: Dictionary = pending.get(caster, { })
	if bool(payload.get("resolved", false)):
		var summoned: Unit = payload.get("summoned_unit")
		if is_instance_valid(summoned):
			_at_unit(Catalog.for_spell(spell), summoned)
		elif not state.is_empty() and state.confirmed:
			_spawn(state.entry, manager._grid_cell_global(state.cell))
	_drop_pending(caster)


func _pending_blocked(caster: Unit, spell: Spell, _reason: StringName) -> void:
	if is_instance_valid(caster) and spell != null:
		_finish_flight(caster, spell)
	_drop_pending(caster)


func _pending_cancelled(caster: Unit, payload: Dictionary, _reason: StringName) -> void:
	var spell: Spell = payload.get("spell")
	if is_instance_valid(caster) and spell != null:
		_finish_flight(caster, spell)
	_drop_pending(caster)


func _drop_pending(caster: Unit) -> void:
	var state: Dictionary = pending.get(caster, { })
	if is_instance_valid(state.get("fx")):
		state.fx.cancel()
	pending.erase(caster)


func _exit_tree() -> void:
	clear()
