class_name ChampionProgressionSummary
extends PanelContainer

signal preparation_requested
signal camp_requested

const STYLE := preload("res://ui/progression/theme/spell_codex_style.gd")

var state: CharacterRunState
var award: Dictionary = {}
var _bar: ProgressBar
var _level: Label
var _xp: Label
var _points: Label
var _prepare: Button
var _tween: Tween


func configure(character: CharacterRunState, result: Dictionary) -> void:
	state = character
	award = result.duplicate(true)
	add_theme_stylebox_override("panel", STYLE.box(STYLE.INK, STYLE.GOLD, 10, 24))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label(state.unit.unit_name.to_upper(), 26, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_level = _label("", 24, true)
	_level.add_theme_color_override("font_color", STYLE.GOLD)
	header.add_child(_level)
	var ledger := HBoxContainer.new()
	ledger.add_theme_constant_override("separation", 18)
	column.add_child(ledger)
	for entry in [
		["VICTOIRE", str(award.get("base_xp", 0)) + " XP"],
		["SAGESSE AU DÉPART", "+%d XP · %d point(s)" % [award.get("wisdom_bonus_xp", 0), award.get("wisdom_at_start", 0)]],
		["GLOIRE", "+%d XP" % award.get("glory_bonus_xp", 0)],
		["TOTAL ACQUIS", "+%d XP" % award.get("gained_xp", 0)],
	]:
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ledger.add_child(tile)
		tile.add_child(_label(entry[0], 12))
		tile.add_child(_label(entry[1], 19))
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 14
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", STYLE.box(STYLE.SURFACE))
	_bar.add_theme_stylebox_override("fill", STYLE.box(STYLE.GOLD, STYLE.GOLD))
	column.add_child(_bar)
	_xp = _label("", 15)
	column.add_child(_xp)
	var reached: Array[String] = []
	for value in award.get("reached_levels", []):
		reached.append(str(value))
	var gain := _label(
		"Niveau%s %s atteint%s · PV +%d · Prouesse %d → %d" % [
			"x" if reached.size() > 1 else "", ", ".join(reached), "s" if reached.size() > 1 else "",
			award.get("hp_delta", 0), award.get("prowess_before", 0), award.get("prowess_after", 0)], 18)
	gain.visible = not reached.is_empty()
	gain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(gain)
	_points = _label("", 17)
	column.add_child(_points)
	_prepare = Button.new()
	_prepare.text = "RÉPARTIR MES POINTS · CARACTÉRISTIQUES & DOCTRINES"
	_prepare.custom_minimum_size.y = 48
	STYLE.button(_prepare)
	_prepare.pressed.connect(func() -> void: preparation_requested.emit())
	column.add_child(_prepare)
	if not GameManager.is_final_room() and not GameManager.get_champion_camp_snapshot().is_empty():
		var camp := Button.new()
		camp.text = "L’ÉTAPE DE CHIRON · ÉQUIPEMENTS, SOINS & MAÎTRISE"
		STYLE.button(camp)
		camp.pressed.connect(func() -> void: camp_requested.emit())
		column.add_child(camp)
	var note := _label("Vous pouvez conserver vos points pour la suite. Les techniques progressent avec votre champion et vos choix de maîtrise.", 14)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	refresh_points()
	set_xp(int(award.get("xp_before", 0)))


func refresh_points() -> void:
	if state == null or state.champion_progression == null or _points == null:
		return
	var champion := state.champion_progression
	_points.text = "%d point(s) de caractéristiques · %d point(s) de maîtrise disponibles" % [
		champion.unspent_attribute_points, champion.unspent_mastery_points]
	_prepare.disabled = not GameManager.can_edit_champion_build()


func set_xp(value: int) -> void:
	var profile := state.champion_progression.profile
	var level := profile.level_for_xp(value)
	var thresholds := profile.cumulative_xp_thresholds
	var floor_xp := int(thresholds[level - 1])
	var cap := int(thresholds[level]) if level < thresholds.size() else maxi(value, floor_xp + 1)
	_bar.min_value = floor_xp
	_bar.max_value = cap
	_bar.value = value
	_level.text = "NIVEAU %d" % level
	_xp.text = "%d / %d XP · prochain niveau %d" % [value, cap, level + 1] if level < thresholds.size() else "%d XP · niveau maximum" % value


func reveal(animated: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var before := int(award.get("xp_before", 0))
	var after := int(award.get("xp_after", 0))
	if not animated:
		set_xp(after)
		return
	_tween = create_tween()
	_tween.tween_method(set_xp, before, after, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func get_summary_snapshot() -> Dictionary:
	return {"award": award.duplicate(true), "level": _level.text, "xp": _xp.text, "points": _points.text}


func _label(text: String, font_size: int, heading := false) -> Label:
	var label := Label.new()
	label.text = text
	STYLE.label(label, heading)
	label.add_theme_font_size_override("font_size", font_size)
	return label
