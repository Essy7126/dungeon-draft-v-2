extends Node
## Challenges never replace spells, resources, progression, or baseline enemy stats.
var battle: Node
var hero: Unit
var state
var budget := 5
var seal := Vector2i(-1, -1)
var layer: CanvasLayer
var panel: PanelContainer
var summary: Label
var seal_button: Button
signal prompt_done


func prepare(owner_battle: Node) -> void:
	battle = owner_battle
	hero = GameManager.expedition.character.unit
	state = GameManager.expedition.challenges
	state.begin_encounter()
	budget = 6 if int(GameManager.expedition.route.get_current_node().depth) >= 3 else 5
	_apply_consequences()
	_find_seal()
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	if not GameManager.get_meta("challenge_auto_setup", false):
		await _choose_contract()
	_build_hud()
	var marks := preload("res://battle/catabase_challenge_marks.gd").new()
	marks.controller = self
	marks.z_index = 4095
	add_child(marks)
	EventBus.unit_pushed.connect(_pushed)


func _apply_consequences() -> void:
	if state.incoming_boon:
		hero.add_shield(
			maxi(1, roundi(hero.max_hp.get_int() * 0.10)),
			hero,
			{ "duration_activations": 2 },
		)
	if state.incoming_alert > 0:
		for enemy: Unit in battle.units:
			if enemy.team == 1 and enemy.is_alive:
				enemy.add_shield(
					maxi(1, roundi(enemy.max_hp.get_int() * 0.10 * state.incoming_alert)),
					enemy,
					{ "duration_activations": 2 },
				)
				break


func _find_seal() -> void:
	for y in battle.grid.rows:
		for x in battle.grid.cols:
			var cell := Vector2i(x, y)
			if battle.grid.is_walkable(cell) and _distance(cell, hero.grid_pos) in [2, 3]:
				var path: Array = battle.pathfinder.find_path(hero.grid_pos, cell, hero)
				if path.size() in [2, 3, 4]:
					seal = cell
					return


func _choose_contract() -> void:
	var shade := ColorRect.new()
	shade.name = "ChallengeDialog"
	shade.color = Color(0.02, 0.04, 0.05, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 35)
	shade.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	column.theme = preload("res://ui/expedition/catabase_ui_theme.gd").get_theme()
	scroll.add_child(column)
	_label(column, "Un défi pour ce combat ?", 27)
	_label(
		column,
		"Réussite : Achille commencera le prochain combat avec un bouclier de 10 % de ses PV maximum.\nÉchec : le premier ennemi du prochain combat recevra un bouclier de 10 % de ses PV maximum.\nCes boucliers durent deux activations de leur porteur. Aucun effet ne s'accumule de salle en salle.\nRefuser n'ajoute aucune pénalité de durée.",
		18,
	)
	_label(
		column,
		"Pour cette salle : %s%s"
		% [
			"bouclier de faveur pour Achille. " if state.incoming_boon else "",
			"Premier ennemi protégé (%d %% PV)." % (state.incoming_alert * 10) if state.incoming_alert
			> 0 else "Aucune alerte reçue.",
		],
		17,
	)
	var choices := [
		["tempo", "Gagner en %d tours maximum" % budget],
		["control", "Déplacer un ennemi deux fois (poussée ou attraction)"],
	]
	if seal.x >= 0:
		choices.append(["seal", "Éteindre le sceau avant la fin du tour 4 · 2 PA à proximité"])
	choices.append(["", "Combattre sans défi"])
	for option: Array in choices:
		var button := Button.new()
		button.name = "Challenge_" + (option[0] if not option[0].is_empty() else "none")
		button.text = option[1]
		button.custom_minimum_size.y = 54
		column.add_child(button)
		button.pressed.connect(
			func():
				state.contract = option[0]
				layer.remove_child(shade)
				shade.queue_free()
				prompt_done.emit(),
		)
	await prompt_done


func _build_hud() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(16, 90)
	panel.custom_minimum_size.x = 310
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.09, 0.90)
	for side in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + side, 10.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	summary = _label(column, "", 15)
	seal_button = Button.new()
	seal_button.text = "Éteindre le sceau · 2 PA"
	column.add_child(seal_button)
	seal_button.pressed.connect(_sabotage)


func start_turn(unit: Unit) -> void:
	if unit == hero:
		state.turns += 1


func _process(_delta: float) -> void:
	if panel == null or not is_instance_valid(battle):
		return
	panel.visible = not battle._battle_over and not state.contract.is_empty()
	var progress := ""
	match state.contract:
		"tempo":
			progress = "Victoire rapide · tour %d/%d" % [state.turns, budget]
		"control":
			progress = "Déplacements ennemis · %d/2" % mini(state.displaced, 2)
		"seal":
			progress = "Sceau éteint ✓" if state.sabotaged else "Sceau · tour %d/4" % state.turns
	summary.text = "Défi : " + progress
	seal_button.visible = state.contract == "seal" and not state.sabotaged
	seal_button.disabled = (
		not battle._can_accept_player_intent() or battle.get_active_unit() != hero
		or state.turns > 4 or hero.current_ap < 2 or _distance(hero.grid_pos, seal) > 1
	)


func _sabotage() -> void:
	if state.contract != "seal" or state.sabotaged or state.turns > 4:
		return
	if battle.get_active_unit() != hero or not battle._can_accept_player_intent():
		return
	if seal.x < 0 or _distance(hero.grid_pos, seal) > 1:
		return
	if hero.spend_ap(2):
		state.sabotaged = true


func _pushed(unit, from: Vector2i, to: Vector2i, _collision: bool) -> void:
	if unit.team != hero.team and from != to and battle.get_active_unit() == hero:
		state.displaced += 1


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
