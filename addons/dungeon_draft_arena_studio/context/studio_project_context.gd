@tool
class_name StudioProjectContext
extends RefCounted

## Autorite de selection partagee par Arena, Encounter et Skill Tree.
## Les transitions restent sans effet tant qu'un document sale n'a pas recu
## une decision explicite.

signal context_changed(snapshot: Dictionary)
signal run_changed(run_data: RunData)
signal room_changed(room_index: int, room: RoomData)
signal hero_changed(hero: RunHeroProfile)
signal character_changed(character: UnitData)
signal scope_changed(scope: StringName)
signal dirty_state_changed(dirty_domains: Dictionary)
signal transition_requested(transition: Dictionary)
signal transition_resolved(result: Dictionary)
signal generation_changed(domain: StringName, generation: int)

const SCOPE_RUN_SPECIFIC := &"RUN_SPECIFIC"
const SCOPE_SHARED := &"SHARED"
const SCOPE_DRAFT := &"DRAFT"
const VALID_SCOPES: Array[StringName] = [
	SCOPE_RUN_SPECIFIC, SCOPE_SHARED, SCOPE_DRAFT,
]

const ACTION_SAVE := &"SAVE"
const ACTION_DRAFT := &"DRAFT"
const ACTION_KEEP_AS_DRAFT := ACTION_DRAFT
const ACTION_DISCARD := &"DISCARD"
const ACTION_CANCEL := &"CANCEL"

var active_run: RunData = null
var active_room_index := -1
var active_hero: RunHeroProfile = null
## Personnage effectivement ouvert par les outils. Il correspond au heros du
## run lorsqu'il en fait partie, mais peut aussi designer un ennemi ou un
## personnage global ; active_hero vaut alors null sans ambiguite.
var active_character: UnitData = null
var edit_scope: StringName = SCOPE_RUN_SPECIFIC
var generations := {
	&"context": 0,
	&"references": 0,
	&"arena": 0,
	&"encounter": 0,
	&"items": 0,
	&"skills": 0,
}
var persisted_ui := {}

var _dirty_domains := {}
var _transition_handlers := {}
var _pending_transition := {}
var _transition_serial := 0


func initialize(preferred_run_path := "", preferred_character_id := &"") -> Dictionary:
	var runs := RunContentCatalogService.discover_runs()
	if runs.is_empty():
		return {"ok": false, "error": "Aucune configuration de partie trouvée."}
	var selected := runs[0]
	for run_data in runs:
		if run_data != null and run_data.resource_path == preferred_run_path:
			selected = run_data
			break
	active_run = selected
	active_room_index = 0 if not selected.rooms.is_empty() else -1
	active_hero = _find_hero(selected, preferred_character_id)
	if active_hero == null:
		var heroes := RunContentCatalogService.heroes_for_run(selected)
		active_hero = heroes[0] if not heroes.is_empty() else null
	active_character = active_hero.base_unit_data if active_hero != null else null
	_bump(&"context")
	_emit_all()
	return {"ok": true, "snapshot": snapshot()}


func register_transition_handler(
		domain: StringName,
		save_handler: Callable = Callable(),
		draft_handler: Callable = Callable(),
		discard_handler: Callable = Callable(),
		prepare_handler: Callable = Callable(),
		stage_handler: Callable = Callable(),
		rollback_handler: Callable = Callable(),
		is_dirty_handler: Callable = Callable(),
		snapshot_handler: Callable = Callable(),
		restore_handler: Callable = Callable()
	) -> Dictionary:
	_transition_handlers[domain] = {
		"save": save_handler,
		"draft": draft_handler,
		"discard": discard_handler,
		"prepare": prepare_handler,
		"stage": stage_handler,
		"rollback": rollback_handler,
		"is_dirty": is_dirty_handler if is_dirty_handler.is_valid() \
			else Callable(self, "is_dirty").bind(domain),
		"snapshot": snapshot_handler if snapshot_handler.is_valid() \
			else Callable(self, "_domain_metadata_snapshot").bind(domain),
		"restore": restore_handler if restore_handler.is_valid() \
			else Callable(self, "_restore_domain_metadata_snapshot").bind(domain),
	}
	return transition_handler_contract(domain)


func unregister_transition_handler(domain: StringName) -> void:
	_transition_handlers.erase(domain)


func set_dirty(domain: StringName, dirty: bool, metadata := {}) -> void:
	if dirty:
		var contract := transition_handler_contract(domain)
		if not bool(contract.get("valid", false)):
			push_error("Domaine modifiable sans handlers complets : %s" % human_domain_name(domain))
			return
		_dirty_domains[domain] = metadata.duplicate(true) if metadata is Dictionary else {}
	else:
		_dirty_domains.erase(domain)
	dirty_state_changed.emit(dirty_domains())
	context_changed.emit(snapshot())


func is_dirty(domain: StringName = &"") -> bool:
	return not _dirty_domains.is_empty() if domain == &"" else _dirty_domains.has(domain)


func dirty_domains() -> Dictionary:
	return _dirty_domains.duplicate(true)


func transition_handler_contract(domain: StringName) -> Dictionary:
	var handlers := _transition_handlers.get(domain, {}) as Dictionary
	var missing: Array[String] = []
	for key in ["save", "draft", "discard", "is_dirty", "snapshot", "restore"]:
		if not (handlers.get(key, Callable()) as Callable).is_valid():
			missing.append(key.to_upper())
	return {
		"domain": domain,
		"human_name": human_domain_name(domain),
		"required": ["SAVE", "KEEP_AS_DRAFT", "DISCARD", "IS_DIRTY", "SNAPSHOT", "RESTORE"],
		"missing": missing,
		"valid": missing.is_empty(),
	}


func validate_transition_handlers() -> Dictionary:
	var domains := {}
	var invalid: Array[StringName] = []
	for domain_value in _transition_handlers:
		var domain := StringName(domain_value)
		var contract := transition_handler_contract(domain)
		domains[domain] = contract
		if not bool(contract.valid):
			invalid.append(domain)
	return {"valid": invalid.is_empty(), "invalid_domains": invalid, "domains": domains}


func human_domain_name(domain: StringName) -> String:
	return {
		&"arena": "Arène",
		&"arena_run": "Séquence de salles",
		&"encounter": "Rencontre",
		&"items": "Objets",
		&"skills": "Compétences",
	}.get(domain, str(domain).capitalize())


func _domain_metadata_snapshot(domain: StringName) -> Dictionary:
	return {
		"dirty": _dirty_domains.has(domain),
		"metadata": (_dirty_domains.get(domain, {}) as Dictionary).duplicate(true),
	}


func _restore_domain_metadata_snapshot(snapshot: Dictionary, domain: StringName) -> Dictionary:
	if bool(snapshot.get("dirty", false)):
		_dirty_domains[domain] = (
			snapshot.get("metadata", {}) as Dictionary
		).duplicate(true)
	else:
		_dirty_domains.erase(domain)
	return {"ok": true}


func has_pending_transition() -> bool:
	return not _pending_transition.is_empty()


func pending_transition() -> Dictionary:
	return _pending_transition.duplicate(true)


func request_selection(selection: Dictionary, requester_domain := &"") -> Dictionary:
	var normalized := _normalized_selection(selection)
	var validation := _validate_selection(normalized)
	if not validation.get("ok", false):
		return validation
	if _selection_matches(normalized):
		return {"ok": true, "status": &"UNCHANGED", "snapshot": snapshot()}
	if has_pending_transition():
		return {
			"ok": false,
			"status": &"TRANSITION_PENDING",
			"transition": pending_transition(),
		}
	if not _dirty_domains.is_empty():
		_transition_serial += 1
		_pending_transition = {
			"token": "studio-transition-%d" % _transition_serial,
			"selection": normalized,
			"requester_domain": requester_domain,
			"dirty_domains": dirty_domains(),
			"from": snapshot(),
		}
		transition_requested.emit(pending_transition())
		return {
			"ok": false,
			"status": &"REQUIRES_DECISION",
			"transition": pending_transition(),
		}
	_apply_selection(normalized)
	return {"ok": true, "status": &"APPLIED", "snapshot": snapshot()}


func resolve_pending_transition(action: StringName) -> Dictionary:
	if _pending_transition.is_empty():
		return {"ok": false, "error": "Aucune transition en attente."}
	if action == ACTION_CANCEL:
		var cancelled := _pending_transition.duplicate(true)
		_pending_transition.clear()
		var cancel_result := {
			"ok": true, "status": &"CANCELLED", "transition": cancelled,
		}
		transition_resolved.emit(cancel_result)
		return cancel_result
	if action not in [ACTION_SAVE, ACTION_DRAFT, ACTION_DISCARD]:
		return {"ok": false, "error": "Decision de transition inconnue : %s" % action}
	var dirty_for_transition := _pending_transition.get("dirty_domains", {}) as Dictionary
	var transaction := StudioContextTransitionTransactionService.execute(
		action, dirty_for_transition, _transition_handlers
	)
	if not transaction.get("ok", false):
		return transaction
	for domain_value in dirty_for_transition.keys():
		_dirty_domains.erase(StringName(domain_value))
	var resolved := _pending_transition.duplicate(true)
	var selection := resolved.get("selection", {}) as Dictionary
	_pending_transition.clear()
	dirty_state_changed.emit(dirty_domains())
	_apply_selection(selection)
	var result := {
		"ok": true,
		"status": &"APPLIED_AFTER_DECISION",
		"action": action,
		"transition": resolved,
		"snapshot": snapshot(),
		"transaction": transaction,
	}
	transition_resolved.emit(result)
	return result


func request_run(run_data: RunData, requester_domain := &"") -> Dictionary:
	return request_selection({"run": run_data, "room_index": 0}, requester_domain)


func request_room(room_index: int, requester_domain := &"") -> Dictionary:
	return request_selection({"room_index": room_index}, requester_domain)


func request_hero(character_id: StringName, requester_domain := &"") -> Dictionary:
	return request_selection({"character_id": character_id}, requester_domain)


func request_character(character_path: String, requester_domain := &"") -> Dictionary:
	var character := _load_character(character_path)
	if character == null:
		return {"ok": false, "error": "Personnage introuvable : %s" % character_path}
	return request_selection({"character": character}, requester_domain)


func request_scope(scope: StringName, requester_domain := &"") -> Dictionary:
	return request_selection({"scope": scope}, requester_domain)


func active_room() -> RoomData:
	if active_run == null or active_room_index < 0 or active_room_index >= active_run.rooms.size():
		return null
	return active_run.rooms[active_room_index]


func bump_generation(domain: StringName) -> int:
	return _bump(domain)


func snapshot() -> Dictionary:
	var room := active_room()
	return {
		"run_path": active_run.resource_path if active_run != null else "",
		"run_name": active_run.run_name if active_run != null else "Aucune partie",
		"room_index": active_room_index,
		"room_path": room.resource_path if room != null else "",
		"room_name": room.room_name if room != null else "Aucune salle",
		"character_id": str(active_character.get_effective_unit_id()) \
			if active_character != null else "",
		"character_path": active_character.resource_path \
			if active_character != null else "",
		"hero_path": active_hero.resource_path if active_hero != null else "",
		"progression_path": active_hero.progression_profile.resource_path \
			if active_hero != null and active_hero.progression_profile != null else "",
		"scope": edit_scope,
		"dirty_domains": dirty_domains(),
		"generations": generations.duplicate(true),
		"pending_transition": pending_transition(),
		"ui": persisted_ui.duplicate(true),
	}


func restore_snapshot(state: Dictionary) -> Dictionary:
	persisted_ui = (state.get("ui", {}) as Dictionary).duplicate(true)
	var run_path := str(state.get("run_path", ""))
	var character_id := StringName(state.get("character_id", &""))
	var initialized := initialize(run_path, character_id)
	if not initialized.get("ok", false):
		return initialized
	var selection := {
		"room_index": int(state.get("room_index", active_room_index)),
		"scope": StringName(state.get("scope", SCOPE_RUN_SPECIFIC)),
	}
	var character_path := str(state.get("character_path", ""))
	if not character_path.is_empty():
		var character := _load_character(character_path)
		if character != null:
			selection["character"] = character
	return request_selection(selection)


func _normalized_selection(selection: Dictionary) -> Dictionary:
	var run_data := selection.get("run", active_run) as RunData
	var room_index := int(selection.get("room_index", active_room_index))
	if selection.has("run") and not selection.has("room_index"):
		room_index = 0 if run_data != null and not run_data.rooms.is_empty() else -1
	var hero := active_hero
	var character := active_character
	if selection.has("character"):
		character = selection.get("character") as UnitData
		hero = _find_hero_for_character(run_data, character)
	elif selection.has("character_id") or selection.has("run"):
		var fallback_id := active_character.get_effective_unit_id() \
			if active_character != null else &""
		var character_id := StringName(selection.get("character_id", fallback_id))
		hero = _find_hero(run_data, character_id)
		if hero == null:
			var heroes := RunContentCatalogService.heroes_for_run(run_data)
			hero = heroes[0] if not heroes.is_empty() else null
		character = hero.base_unit_data if hero != null else null
	elif character == null and hero != null:
		character = hero.base_unit_data
	return {
		"run": run_data,
		"room_index": room_index,
		"hero": hero,
		"character": character,
		"scope": StringName(selection.get("scope", edit_scope)),
	}


func _validate_selection(selection: Dictionary) -> Dictionary:
	var run_data := selection.get("run") as RunData
	if run_data == null:
		return {"ok": false, "error": "La sélection ne contient aucune configuration de partie."}
	var room_index := int(selection.get("room_index", -1))
	if room_index < -1 or room_index >= run_data.rooms.size():
		return {"ok": false, "error": "Index de salle hors limites : %d." % room_index}
	var scope := StringName(selection.get("scope", SCOPE_RUN_SPECIFIC))
	if scope not in VALID_SCOPES:
		return {"ok": false, "error": "Portée d'édition inconnue : %s." % scope}
	return {"ok": true}


func _selection_matches(selection: Dictionary) -> bool:
	return selection.get("run") == active_run \
		and int(selection.get("room_index", -1)) == active_room_index \
		and selection.get("hero") == active_hero \
		and selection.get("character") == active_character \
		and StringName(selection.get("scope", &"")) == edit_scope


func _apply_selection(selection: Dictionary) -> void:
	var previous_run := active_run
	var previous_room := active_room_index
	var previous_hero := active_hero
	var previous_character := active_character
	var previous_scope := edit_scope
	active_run = selection.get("run") as RunData
	active_room_index = int(selection.get("room_index", -1))
	active_hero = selection.get("hero") as RunHeroProfile
	active_character = selection.get("character") as UnitData
	edit_scope = StringName(selection.get("scope", SCOPE_RUN_SPECIFIC))
	_bump(&"context")
	if previous_run != active_run:
		run_changed.emit(active_run)
	if previous_room != active_room_index or previous_run != active_run:
		room_changed.emit(active_room_index, active_room())
	if previous_hero != active_hero:
		hero_changed.emit(active_hero)
	if previous_character != active_character:
		character_changed.emit(active_character)
	if previous_scope != edit_scope:
		scope_changed.emit(edit_scope)
	context_changed.emit(snapshot())


func _emit_all() -> void:
	run_changed.emit(active_run)
	room_changed.emit(active_room_index, active_room())
	hero_changed.emit(active_hero)
	character_changed.emit(active_character)
	scope_changed.emit(edit_scope)
	dirty_state_changed.emit(dirty_domains())
	context_changed.emit(snapshot())


func _find_hero(run_data: RunData, character_id: StringName) -> RunHeroProfile:
	var heroes := RunContentCatalogService.heroes_for_run(run_data)
	for hero in heroes:
		if hero != null and (character_id == &"" or hero.character_id == character_id):
			return hero
	return null


func _find_hero_for_character(
		run_data: RunData,
		character: UnitData
	) -> RunHeroProfile:
	if character == null:
		return null
	for hero in RunContentCatalogService.heroes_for_run(run_data):
		if hero == null or hero.base_unit_data == null:
			continue
		if hero.base_unit_data == character or (
				not character.resource_path.is_empty()
				and hero.base_unit_data.resource_path == character.resource_path
			):
			return hero
	return null


func _load_character(path: String) -> UnitData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as UnitData


func _bump(domain: StringName) -> int:
	var value := int(generations.get(domain, 0)) + 1
	generations[domain] = value
	generation_changed.emit(domain, value)
	return value
