extends Node
## Scene-owned soundtrack and the four opening techniques, also on normal launches.
signal cue_played(spell_id: StringName)

const MUSIC := preload("res://assets/audio/catabase/mysterious_harp.wav")
const SOUNDS := {
	&"achilles_peleid_strike": preload("res://assets/audio/catabase/strike.wav"),
	&"achilles_fulminant_dash": preload("res://assets/audio/catabase/dash.wav"),
	&"achilles_pelion_shot": preload("res://assets/audio/catabase/shot.wav"),
	&"achilles_bronze_guard": preload("res://assets/audio/catabase/guard.wav"),
}
@export_range(0.0, 1.0) var effects_volume := 0.9
@export_range(0.0, 1.0) var music_volume := 0.5

var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var _battle: Node
var _disposed := false
var feedback: Node
var _grid: GridData
var _walking: Dictionary = { }
var _facts: Dictionary = { }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_battle = get_parent()
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.bus = &"Music"
	var loop := MUSIC.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
	music.stream = loop
	music.volume_db = linear_to_db(maxf(music_volume, 0.0001))
	add_child(music)
	if music_volume > 0.0:
		music.play()
	for index in 3:
		var voice := AudioStreamPlayer.new()
		voice.name = "Effect%d" % index
		voice.bus = &"SFX"
		add_child(voice)
		voices.append(voice)
	EventBus.spell_cast.connect(_on_spell_cast)
	feedback = preload("res://core/audio/feedback_player.gd").new()
	feedback.name = "CombatFeedback"
	add_child(feedback)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.voluntary_movement_prepared.connect(_on_walk_prepared)
	EventBus.voluntary_movement_resolved.connect(_on_walk_finished)
	EventBus.hit_resolved.connect(_on_hit)
	EventBus.heal_received.connect(_on_heal)
	EventBus.shield_granted.connect(_on_shield)
	EventBus.shield_absorption_resolved.connect(_on_block)
	EventBus.attack_dodge_resolved.connect(_on_dodge)
	EventBus.unit_died.connect(_on_fall)
	EventBus.turn_started.connect(_on_turn)


func _owns(unit: Unit) -> bool:
	if _disposed or not can_process() or not is_instance_valid(_battle) or unit == null:
		return false
	var units: Variant = _battle.get("units")
	return units is Array and units.has(unit)


func _play_feedback(cue: StringName, gain_db: float = 0.0) -> void:
	if not _disposed and effects_volume > 0.0:
		feedback.play(cue, gain_db + linear_to_db(effects_volume))


func _on_combat_started(_units: Array, grid: GridData) -> void:
	if _battle.get("grid") != grid or _grid == grid:
		return
	_grid = grid
	_grid.occupancy_changed.connect(_on_cell_reached)


func _on_walk_prepared(unit: Unit, _path: Array, _base: int, _cost: int, _id: StringName) -> void:
	if _owns(unit):
		_walking[unit] = true


func _on_walk_finished(unit: Unit, _path: Array, _cost: int, _id: StringName) -> void:
	_walking.erase(unit)


func _on_cell_reached(reason: StringName, unit: Unit, from: Vector2i, to: Vector2i) -> void:
	# Relocation is committed after each visual walking segment. No deployment,
	# forced push, dash or teleport steps; no queued footsteps after leaving.
	if reason == &"relocated" and _walking.has(unit) and _owns(unit) and unit.is_alive:
		if absi(to.x - from.x) + absi(to.y - from.y) == 1:
			_play_feedback(&"step", -4.0 if unit.team == 0 else -7.0)


func _accept_fact(fact: CombatEventFact) -> bool:
	if fact == null or not _owns(fact.target) or _facts.has(fact.event_id):
		return false
	_facts[fact.event_id] = true
	if _facts.size() > 128:
		_facts.erase(_facts.keys()[0])
	return true


func _on_hit(fact: CombatEventFact) -> void:
	if not _accept_fact(fact) or fact.is_periodic or fact.amount_resolved <= 0:
		return
	if fact.source != null and fact.source.team == 0 and SOUNDS.has(fact.ability_id):
		return
	if fact.amount_applied <= 0:
		return
	_play_feedback(&"hit" if fact.damage_type == 0 else &"magic_hit", -2.0)


func _on_heal(fact: CombatEventFact) -> void:
	if _accept_fact(fact) and fact.amount_applied > 0:
		_play_feedback(&"heal")


func _on_shield(fact: CombatEventFact) -> void:
	if (
		_accept_fact(fact) and fact.amount_applied > 0
		and fact.ability_id != &"achilles_bronze_guard"
	):
		_play_feedback(&"block", -6.0)


func _on_block(fact: CombatEventFact) -> void:
	if _accept_fact(fact) and fact.amount_absorbed > 0:
		_play_feedback(&"block", -3.0)


func _on_dodge(fact: CombatEventFact) -> void:
	if _accept_fact(fact):
		_play_feedback(&"dodge")


func _on_fall(unit: Unit) -> void:
	if _owns(unit):
		_walking.erase(unit)
		_play_feedback(&"fall", -3.0)


func _on_turn(unit: Unit) -> void:
	if _owns(unit) and unit.team == 0:
		_play_feedback(&"turn", -3.0)


func _on_spell_cast(caster: Unit, spell: Spell, report: Dictionary) -> void:
	if _disposed or not can_process() or not is_instance_valid(_battle):
		return
	if caster == null or spell == null or caster.team != 0 or report.get("failed", false):
		return
	# Other previews/tests can emit on the shared bus; only this encounter owns us.
	var units: Variant = _battle.get("units")
	if not units is Array or not units.has(caster):
		return
	var id := spell.get_effective_spell_id()
	if not SOUNDS.has(id) or effects_volume <= 0.0:
		return
	if id == &"achilles_bronze_guard" and int(report.get("shield_increase_total", 0)) <= 0:
		return
	if id == &"achilles_fulminant_dash" and int(report.get("movement_count", 0)) <= 0:
		return
	if (
		id in [&"achilles_peleid_strike", &"achilles_pelion_shot"]
		and report.get("damaged_enemies", []).is_empty()
	):
		return
	for voice in voices:
		if not voice.playing:
			voice.stream = SOUNDS[id]
			voice.volume_db = linear_to_db(effects_volume)
			voice.play()
			cue_played.emit(id)
			return


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for binding in [
		[EventBus.combat_started, _on_combat_started],
		[EventBus.voluntary_movement_prepared, _on_walk_prepared],
		[EventBus.voluntary_movement_resolved, _on_walk_finished],
		[EventBus.hit_resolved, _on_hit],
		[EventBus.heal_received, _on_heal],
		[EventBus.shield_granted, _on_shield],
		[EventBus.shield_absorption_resolved, _on_block],
		[EventBus.attack_dodge_resolved, _on_dodge],
		[EventBus.unit_died, _on_fall],
		[EventBus.turn_started, _on_turn],
	]:
		if binding[0].is_connected(binding[1]):
			binding[0].disconnect(binding[1])
	if _grid != null and _grid.occupancy_changed.is_connected(_on_cell_reached):
		_grid.occupancy_changed.disconnect(_on_cell_reached)
	_grid = null
	_walking.clear()
	_facts.clear()
	if is_instance_valid(feedback):
		feedback.stop()
	if EventBus.spell_cast.is_connected(_on_spell_cast):
		EventBus.spell_cast.disconnect(_on_spell_cast)
	for voice in voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	_battle = null


func _exit_tree() -> void:
	dispose()
