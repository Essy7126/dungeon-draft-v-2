extends Node2D
## The return path is previewed by SpellCaster; this marks its persistent origin.
var battle: Node
var reserves: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -278
	panel.offset_right = -18
	panel.offset_top = 92
	panel.offset_bottom = 160
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.09, 0.09, 0.88)
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	reserves = Label.new()
	reserves.add_theme_font_size_override("font_size", 15)
	reserves.add_theme_color_override("font_color", Color("ffe2ac"))
	panel.add_child(reserves)


func _process(_delta: float) -> void:
	queue_redraw()
	if reserves == null or not is_instance_valid(battle):
		return
	reserves.get_parent().visible = not battle._battle_over
	var lines: Array[String] = []
	for hero in battle.units:
		if hero.team != 0 or not hero.is_alive:
			continue
		var session = CatabaseCombatModifier.session_for(hero)
		if session != null:
			lines.append("Oboles · %d" % session.gold)
		if hero.get_meta("ct_relic_2", false):
			lines.append("Bronze · %d / %d" % [
				int(hero.get_meta("ct_bronze", 0)),
				CatabaseCombatModifier.bronze_cap(hero),
			])
		if hero.get_meta("ct_relic_4", false):
			lines.append("Soin disponible · %d / %d PV" % [
				int(hero.get_meta("ct_healing", 0)),
				CatabaseCombatModifier.healing_cap(hero),
			])
		if int(hero.get_meta("ct_toll_turn", -1)) == hero.activation_index:
			lines.append(
				"Prochain impact · +%d %%" % roundi(float(hero.get_meta("ct_toll", 0)) * 100)
			)
	reserves.text = "\n".join(lines)


func _draw() -> void:
	if not is_instance_valid(battle) or battle._battle_over:
		return
	for hero in battle.units:
		if hero.team != 0 or not hero.is_alive or not hero.has_meta("ct_disc"):
			continue
		var cell: Vector2i = hero.get_meta("ct_disc")
		var center: Vector2 = to_local(battle.grid_cell_to_global(cell))
		draw_circle(center, 13, Color("382e26"))
		draw_arc(center, 12, 0, TAU, 28, Color("edc77d"), 3, true)
		draw_arc(center, 6, 0, TAU, 20, Color("edc77d"), 1, true)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-25, -20),
			"DISQUE",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color("ffe2ac"),
		)
