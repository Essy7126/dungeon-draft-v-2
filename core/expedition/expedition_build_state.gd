class_name ExpeditionBuildState
extends RefCounted

signal changed

const VERSION := 2
const STARTING_POINTS := 0
const MAX_DEPTH := 20
const CAPACITY_DEPTH := 12
# 24 points: two early decisions, then a full doctrine or several hybrid branches.
# The final victory grants no unusable mastery point.
const DEPTH_POINTS := {1: 2, 2: 1, 3: 1, 4: 1, 5: 1, 6: 2, 7: 1, 8: 1,
	9: 1, 10: 2, 11: 1, 12: 1, 13: 1, 14: 2, 15: 1, 16: 1, 17: 1, 18: 2, 19: 1}
const STAT_SOURCE := "expedition_build"
const STAT_NAMES := ["max_hp", "attack_power", "initiative", "max_mp", "armure", "resist_magique", "esquive", "force"]

var catalog := ExpeditionBuildCatalog.new()
var character_state: CharacterRunState = null
var points: int = STARTING_POINTS
var unlocked_node_ids: Array[String] = []
var is_editable: bool = true
var depth_eight_choice: String = ""
var completed_depth: int = 0
var current_level: int = 1
var correction_used: bool = false
var _granted_depths: Array[int] = []
var _card_spell_ids: Array[String] = []
var _last_encounter_id: String = ""
var discovered_branches: Array[String] = []


func initialize(state: CharacterRunState) -> bool:
	if state == null or state.unit == null or state.loadout == null:
		return false
	if character_state != null:
		_clear_stats()
	character_state = state
	points = STARTING_POINTS
	unlocked_node_ids.clear()
	_granted_depths.clear()
	_card_spell_ids.clear()
	_last_encounter_id = ""
	discovered_branches.clear()
	depth_eight_choice = ""
	completed_depth = 0
	current_level = 1
	correction_used = false
	is_editable = true
	# Catabase always enters its first fight with exactly its canonical four spells.
	state.loadout.initialize(catalog.base_spells(), 4)
	if state.champion_progression != null:
		sync_level(state.champion_progression.current_level)
	changed.emit()
	return true


func sync_level(level: int) -> void:
	current_level = clampi(level, 1, 14)
	if character_state != null and current_level >= 5 \
			and character_state.loadout.get_active_slot_count() < 5:
		character_state.loadout.resize_slots(5)
	changed.emit()


func grant_depth_reward(depth: int) -> Dictionary:
	if depth < 1 or depth > MAX_DEPTH:
		return _failure("Profondeur invalide.")
	if _granted_depths.has(depth):
		return _failure("Récompense déjà reçue.")
	if depth != completed_depth + 1:
		return _failure("Les jalons doivent être résolus dans l'ordre.")
	_granted_depths.append(depth)
	completed_depth = depth
	var amount := int(DEPTH_POINTS.get(depth, 0))
	points += amount
	changed.emit()
	return {"success": true, "reason": "", "points": amount}


func get_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in catalog.nodes:
		var offer := node.duplicate(true)
		offer["discovered"] = is_axis_discovered(String(node.axis))
		offer["owned"] = _node_owned(node)
		offer["reason"] = _purchase_failure(node)
		offer["available"] = String(offer.reason).is_empty()
		result.append(offer)
	return result


func purchase(id: String) -> Dictionary:
	var node := catalog.get_node(id)
	var reason := _purchase_failure(node)
	if not reason.is_empty():
		return _failure(reason)
	points -= int(node.cost)
	unlocked_node_ids.append(id)
	var spell_id := String(node.spell_id)
	if not spell_id.is_empty():
		_learn(spell_id, String(node.kind) != "apprentissage")
	_apply_stats()
	changed.emit()
	return {"success": true, "reason": "", "spell_id": spell_id}


func equip(spell_id: String, slot: int) -> bool:
	if not is_editable or character_state == null or completed_depth == 0:
		return false
	if spell_id.is_empty():
		if slot < 0 or slot >= character_state.loadout.get_active_slot_count():
			return false
		character_state.loadout.unequip_slot(slot)
		changed.emit()
		return true
	if not character_state.loadout.knows_spell_id(StringName(spell_id)):
		return false
	var family := catalog.get_spell_family(spell_id)
	var equipped := character_state.loadout.get_spell_slot_ids()
	for index in equipped.size():
		if index != slot and equipped[index] != &"" \
				and catalog.get_spell_family(String(equipped[index])) == family:
			return false
	var success := character_state.loadout.equip_spell(StringName(spell_id), slot)
	if success:
		changed.emit()
	return success


## One correction per expedition. Only the latest point purchase is refunded;
## cards, attributes and the exclusive VIII reward retain their own histories.
func undo_last_purchase() -> Dictionary:
	if not is_editable or character_state == null:
		return _failure("La correction est disponible entre les étapes.")
	if correction_used:
		return _failure("Votre correction unique a déjà été utilisée.")
	if unlocked_node_ids.is_empty():
		return _failure("Aucun achat de maîtrise à corriger.")
	var candidate := to_snapshot()
	var removed_id := String(candidate.unlocked_node_ids.pop_back())
	var removed := catalog.get_node(removed_id)
	candidate.points = points + int(removed.cost)
	candidate.correction_used = true
	var allowed: Array[String] = []
	for spell in catalog.base_spells():
		allowed.append(String(spell.spell_id))
	for id in _card_spell_ids:
		if not allowed.has(id):
			allowed.append(id)
	for id in candidate.unlocked_node_ids:
		var learned_id := String(catalog.get_node(String(id)).get("spell_id", ""))
		if not learned_id.is_empty() and not allowed.has(learned_id):
			allowed.append(learned_id)
	if depth_eight_choice == "mutation":
		allowed.append("exp_tempest")
	var kept: Array[String] = []
	for id in candidate.loadout.known_spell_ids:
		if allowed.has(String(id)):
			kept.append(String(id))
	candidate.loadout.known_spell_ids = kept
	for slot in candidate.loadout.equipped_spell_ids.size():
		var id := String(candidate.loadout.equipped_spell_ids[slot])
		if id.is_empty() or allowed.has(id):
			continue
		var replacement := ""
		var family := catalog.get_spell_family(id)
		# Last acquired remaining form wins; otherwise the original technique.
		for index in range(allowed.size() - 1, -1, -1):
			if catalog.get_spell_family(allowed[index]) == family:
				replacement = allowed[index]
				break
		candidate.loadout.equipped_spell_ids[slot] = replacement
	if not restore_snapshot(candidate):
		return _failure("Cette correction rendrait le kit incohérent.")
	return {"success": true, "reason": "", "refunded": int(removed.cost), "title": String(removed.title)}


func learn_spell_card(spell_id: String) -> Dictionary:
	if not is_editable or character_state == null or completed_depth == 0:
		return _failure("Le kit est verrouillé pendant une étape engagée.")
	if not catalog.card_spell_ids().has(spell_id):
		return _failure("Cette carte ne peut pas enseigner une mutation ou une technique inconnue.")
	if not is_axis_discovered(catalog.get_spell_axis(spell_id)):
		return _failure("Cette branche doit d'abord être découverte pendant la run.")
	if character_state.loadout.knows_spell_id(StringName(spell_id)):
		return _failure("Technique déjà connue.")
	_card_spell_ids.append(spell_id)
	_learn(spell_id, false)
	changed.emit()
	return {"success": true, "reason": "", "spell_id": spell_id}


func learn_axis_card(axis: String, seed_value: int = 0) -> Dictionary:
	if character_state == null:
		return _failure("Le personnage n'est pas initialisé.")
	var candidates: Array[String] = []
	for id in catalog.card_spell_ids(axis):
		if not character_state.loadout.knows_spell_id(StringName(id)):
			candidates.append(id)
	if candidates.is_empty():
		return _failure("Toutes les techniques de cette famille sont déjà connues.")
	return learn_spell_card(candidates[posmod(seed_value, candidates.size())])


func choose_depth_eight(option: String) -> Dictionary:
	if not is_editable or character_state == null:
		return _failure("Le kit est verrouillé pendant une étape engagée.")
	if completed_depth < CAPACITY_DEPTH:
		return _failure("Ce choix s'ouvre après le jalon XII.")
	if not depth_eight_choice.is_empty():
		return _failure("Le choix du jalon XII est déjà engagé.")
	if current_level < 5:
		return _failure("Le cinquième emplacement doit déjà être ouvert.")
	if option == "slot":
		if not character_state.loadout.resize_slots(6):
			return _failure("Capacité invalide.")
	elif option == "mutation":
		_learn("exp_tempest", true)
	else:
		return _failure("Choisissez slot ou mutation.")
	depth_eight_choice = option
	changed.emit()
	return {"success": true, "reason": "", "choice": option}


func is_axis_discovered(axis: String) -> bool:
	return catalog.AXES.has(axis) and (not catalog.DISCOVERY_DEPTHS.has(axis) or discovered_branches.has(axis))


func unlock_branch(branch_id: String) -> Dictionary:
	if not is_editable or character_state == null:
		return _failure("Une découverte se résout entre les combats.")
	if not catalog.DISCOVERY_DEPTHS.has(branch_id):
		return _failure("Branche de découverte inconnue.")
	if completed_depth < int(catalog.DISCOVERY_DEPTHS[branch_id]):
		return _failure("Cette découverte n'est pas encore accessible.")
	if discovered_branches.has(branch_id):
		return _failure("Branche déjà découverte.")
	discovered_branches.append(branch_id)
	changed.emit()
	return {"success": true, "reason": "", "branch_id": branch_id}


func begin_encounter(encounter_id: String = "") -> bool:
	if character_state == null:
		return false
	if not encounter_id.is_empty() and encounter_id == _last_encounter_id:
		return false
	_last_encounter_id = encounter_id
	var unit := character_state.unit
	var entry_hp := unit.max_hp.get_int()
	var fraction := 0.30 if unlocked_node_ids.has("endurance.liaison_b") else 0.20
	unit.set_meta(ExpeditionSpellModifier.ENTRY_HP_META, entry_hp)
	unit.set_meta(ExpeditionSpellModifier.HEAL_BUDGET_META, int(floor(entry_hp * fraction)))
	return true


func get_healing_reserve() -> int:
	return int(character_state.unit.get_meta(ExpeditionSpellModifier.HEAL_BUDGET_META, 0)) \
		if character_state != null else 0


func to_snapshot() -> Dictionary:
	return {"version": VERSION, "points": points, "unlocked_node_ids": unlocked_node_ids.duplicate(),
		"granted_depths": _granted_depths.duplicate(), "card_spell_ids": _card_spell_ids.duplicate(),
		"completed_depth": completed_depth, "current_level": current_level,
		"correction_used": correction_used,
		"discovered_branches": discovered_branches.duplicate(),
		"depth_eight_choice": depth_eight_choice,
		"loadout": character_state.loadout.to_snapshot() if character_state != null else {}}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if character_state == null or int(snapshot.get("version", 0)) != VERSION:
		return false
	if not snapshot.get("correction_used", false) is bool:
		return false
	for key in ["points", "completed_depth", "current_level"]:
		if not _integer_value(snapshot.get(key)):
			return false
	var restored_depth := int(snapshot.completed_depth)
	var restored_level := int(snapshot.current_level)
	if restored_depth < 0 or restored_depth > MAX_DEPTH or restored_level < 1 or restored_level > 14:
		return false
	var discovered_value: Variant = snapshot.get("discovered_branches", [])
	if not discovered_value is Array:
		return false
	var discovered: Array[String] = []
	for branch in discovered_value:
		if not branch is String or not catalog.DISCOVERY_DEPTHS.has(branch) or discovered.has(branch) \
				or restored_depth < int(catalog.DISCOVERY_DEPTHS[branch]):
			return false
		discovered.append(branch)
	var grants_value: Variant = snapshot.get("granted_depths")
	var nodes_value: Variant = snapshot.get("unlocked_node_ids")
	var cards_value: Variant = snapshot.get("card_spell_ids")
	var loadout_value: Variant = snapshot.get("loadout")
	if not grants_value is Array or not nodes_value is Array or not cards_value is Array \
			or not loadout_value is Dictionary or grants_value.size() != restored_depth:
		return false
	var grants: Array[int] = []
	var earned := STARTING_POINTS
	for index in grants_value.size():
		if not _integer_value(grants_value[index]) or int(grants_value[index]) != index + 1:
			return false
		grants.append(index + 1)
		earned += int(DEPTH_POINTS.get(index + 1, 0))
	var restored_nodes: Array[String] = []
	var expected_known: Array[String] = []
	for spell in catalog.base_spells():
		expected_known.append(String(spell.spell_id))
	var spent := 0
	var exclusive_groups: Array[String] = []
	for value in nodes_value:
		if not (value is String or value is StringName):
			return false
		var id := String(value)
		var node := catalog.get_node(id)
		if node.is_empty() or restored_nodes.has(id) or int(node.minimum_depth) > restored_depth:
			return false
		if catalog.DISCOVERY_DEPTHS.has(String(node.axis)) and not discovered.has(String(node.axis)):
			return false
		var group := String(node.get("exclusive_group", ""))
		if not group.is_empty():
			if exclusive_groups.has(group):
				return false
			exclusive_groups.append(group)
		# Prerequisites must have been purchased before their descendant.
		for prerequisite in node.prerequisites:
			var prerequisite_node := catalog.get_node(String(prerequisite))
			var taught_by_card: bool = String(prerequisite_node.get("kind", "")) == "apprentissage" \
				and cards_value.has(String(prerequisite_node.get("spell_id", "")))
			if not restored_nodes.has(String(prerequisite)) and not taught_by_card:
				return false
		restored_nodes.append(id)
		spent += int(node.cost)
		var spell_id := String(node.spell_id)
		if not spell_id.is_empty() and not expected_known.has(spell_id):
			expected_known.append(spell_id)
	if int(snapshot.points) != earned - spent or int(snapshot.points) < 0:
		return false
	var cards: Array[String] = []
	if restored_depth == 0 and not cards_value.is_empty():
		return false
	for value in cards_value:
		if not (value is String or value is StringName) or cards.has(String(value)) \
				or not catalog.card_spell_ids().has(String(value)):
			return false
		cards.append(String(value))
		var axis := catalog.get_spell_axis(String(value))
		if catalog.DISCOVERY_DEPTHS.has(axis) and not discovered.has(axis):
			return false
		if not expected_known.has(String(value)):
			expected_known.append(String(value))
	var choice := String(snapshot.get("depth_eight_choice", ""))
	if not ["", "slot", "mutation"].has(choice) or (not choice.is_empty() and (restored_depth < CAPACITY_DEPTH or restored_level < 5)):
		return false
	if choice == "mutation":
		expected_known.append("exp_tempest")
	var expected_slots := 6 if choice == "slot" else (5 if restored_level >= 5 else 4)
	var candidate := SpellLoadoutState.new()
	if not candidate.restore_snapshot(loadout_value as Dictionary, catalog.all_spells()) \
			or candidate.get_active_slot_count() != expected_slots:
		return false
	var known := candidate.get_known_spells()
	if known.size() != expected_known.size():
		return false
	for spell in known:
		if not expected_known.has(String(spell.spell_id)):
			return false
	var equipped_families: Array[String] = []
	for spell in candidate.get_equipped_spells():
		var family := catalog.get_spell_family(String(spell.spell_id))
		if equipped_families.has(family):
			return false
		equipped_families.append(family)
	if restored_depth == 0:
		var starter_ids: Array[StringName] = []
		for spell in catalog.base_spells():
			starter_ids.append(spell.spell_id)
		if candidate.get_spell_slot_ids() != starter_ids:
			return false
	# Commit only after every invariant, including loadout rights, has passed.
	points = int(snapshot.points)
	completed_depth = restored_depth
	current_level = restored_level
	_granted_depths = grants
	unlocked_node_ids = restored_nodes
	_card_spell_ids = cards
	discovered_branches = discovered
	depth_eight_choice = choice
	correction_used = bool(snapshot.get("correction_used", false))
	character_state.loadout.restore_snapshot(loadout_value as Dictionary, catalog.all_spells())
	_apply_stats()
	changed.emit()
	return true


func _purchase_failure(node: Dictionary) -> String:
	if character_state == null:
		return "Le personnage n'est pas initialisé."
	if not is_editable:
		return "Le kit est verrouillé pendant une étape engagée."
	if node.is_empty():
		return "Maîtrise inconnue."
	if completed_depth == 0:
		return "Le premier combat commence avec les quatre techniques d'Achille."
	if not is_axis_discovered(String(node.axis)):
		return "Branche scellée : une découverte de sanctuaire est nécessaire."
	var group := String(node.get("exclusive_group", ""))
	if not group.is_empty():
		for id in unlocked_node_ids:
			if String(catalog.get_node(id).get("exclusive_group", "")) == group:
				return "Un autre serment exclusif a déjà été choisi."
	if _node_owned(node):
		return "Déjà acquis."
	if int(node.minimum_depth) > completed_depth:
		return "Disponible après le jalon %d." % int(node.minimum_depth)
	for prerequisite in node.prerequisites:
		if not _node_owned(catalog.get_node(String(prerequisite))):
			return "Prérequis : %s." % String(catalog.get_node(String(prerequisite)).get("title", prerequisite))
	if points < int(node.cost):
		return "Il manque %d point(s) de maîtrise." % (int(node.cost) - points)
	return ""


func _node_owned(node: Dictionary) -> bool:
	if node.is_empty():
		return false
	if unlocked_node_ids.has(String(node.id)):
		return true
	return character_state != null and String(node.get("kind", "")) == "apprentissage" \
		and character_state.loadout.knows_spell_id(StringName(node.get("spell_id", "")))


func _learn(spell_id: String, replace_family: bool) -> void:
	var spell := catalog.get_spell(spell_id)
	if spell == null:
		return
	character_state.loadout.learn_spell(spell)
	if replace_family:
		var family := catalog.get_spell_family(spell_id)
		var slots := character_state.loadout.get_spell_slot_ids()
		for slot in slots.size():
			if slots[slot] != &"" and catalog.get_spell_family(String(slots[slot])) == family:
				character_state.loadout.equip_spell(StringName(spell_id), slot)
				return


func _apply_stats() -> void:
	if character_state == null:
		return
	_clear_stats()
	for id in unlocked_node_ids:
		var data: Array = catalog.get_node(id).get("stat", [])
		if data.size() != 3 or String(data[0]) == "heal_budget":
			continue
		var stat := character_state.unit.get(String(data[0])) as Stat
		if stat != null:
			stat.add_modifier(float(data[1]), Stat.ModType.PERCENT if bool(data[2]) else Stat.ModType.FLAT, STAT_SOURCE)
	character_state.unit.current_hp = mini(character_state.unit.current_hp, character_state.unit.max_hp.get_int())
	character_state.unit.stats_changed.emit(character_state.unit)
	character_state.unit.hp_changed.emit(character_state.unit)


func _clear_stats() -> void:
	if character_state == null or character_state.unit == null:
		return
	for name in STAT_NAMES:
		var stat := character_state.unit.get(name) as Stat
		if stat != null:
			stat.remove_modifiers_from(STAT_SOURCE)


func _integer_value(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
