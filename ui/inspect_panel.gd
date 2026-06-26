extends CanvasLayer

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _content: VBoxContainer
var _release_button: Button
var _locked: bool = false

func _ready() -> void:
	_build_ui()
	_show_empty()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -340
	_panel.offset_right = -14
	_panel.offset_top = 18
	_panel.offset_bottom = -116
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", Color(0.72, 0.72, 0.66))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_subtitle)

	_release_button = Button.new()
	_release_button.text = "Libre"
	_release_button.custom_minimum_size = Vector2(66, 28)
	_release_button.tooltip_text = "Reprendre l'inspection au survol."
	_release_button.pressed.connect(release_lock)
	header.add_child(_release_button)

	var sep := HSeparator.new()
	root.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 7)
	scroll.add_child(_content)

func release_lock() -> void:
	_locked = false
	_release_button.disabled = true
	_show_empty()

func is_locked() -> bool:
	return _locked

func show_unit(unit, locked: bool = false) -> void:
	if _locked and not locked:
		return
	_locked = locked
	_release_button.disabled = not _locked
	_clear_content()
	if unit == null:
		_show_empty()
		return
	_title.text = unit.unit_name
	_subtitle.text = "Allie" if unit.team == 0 else "Ennemi"
	_add_section("Ressources")
	_add_line("PV", "%d / %d" % [unit.current_hp, unit.max_hp.get_int()])
	_add_line("Bouclier", str(unit.current_shield))
	if unit.has_energy():
		_add_line("Elan", "%d / %d" % [int(unit.current_elan), int(unit.max_elan)])
		_add_line(unit.energy_type.energy_name, "%d / %d" % [int(unit.current_energy), int(unit.energy_type.max_energy)])
		if unit.charge_threshold_active:
			_add_line("Eveil", "%s, %d tour(s)" % [unit.energy_type.threshold_name, unit.awakening_turns_remaining])
		else:
			_add_line("Reaction", "%d Ferveur pour reduire un gros coup" % int(unit.energy_type.reaction_cost))
	_add_section("Stats")
	_add_line("Attaque", str(unit.get_attack()))
	_add_line("Initiative", str(unit.get_initiative()))
	_add_line("PM", "%d / %d" % [unit.current_mp, unit.max_mp.get_int()])
	_add_line("Armure", _fmt_float(unit.armure.get_value()))
	_add_line("Resist. magique", _fmt_float(unit.resist_magique.get_value()))
	_add_line("Esquive", "%d%%" % int(round(unit.esquive.get_value() * 100.0)))
	_add_line("Critique", "%d%% x%s" % [int(round(unit.crit_chance.get_value() * 100.0)), _fmt_float(unit.crit_multi.get_value())])
	_add_statuses(unit)
	_add_spells(unit)
	_add_traits(unit)

func show_cell(cell: Vector2i, grid: GridData, terrain_effects, locked: bool = false) -> void:
	if _locked and not locked:
		return
	_locked = locked
	_release_button.disabled = not _locked
	_clear_content()
	if grid == null or not grid.is_valid(cell):
		_show_empty()
		return
	var unit = grid.get_unit(cell)
	if unit != null:
		show_unit(unit, locked)
		return
	_title.text = "Case %d, %d" % [cell.x, cell.y]
	_subtitle.text = _cell_type_name(grid.get_type(cell))
	_add_section("Case")
	_add_line("Marchable", "Oui" if grid.is_walkable(cell) else "Non")
	_add_line("Ligne de vue", "Oui" if grid.is_transparent(cell) else "Non")
	var effect = terrain_effects.get_effect_data(cell) if terrain_effects != null else null
	if effect == null:
		_add_paragraph("Aucun effet actif sur cette case.")
		return
	_add_section("Effet actif")
	_add_line("Nom", effect.effect_name)
	if effect.description.strip_edges() != "":
		_add_paragraph(effect.description)
	_add_line("Declenchement", _trigger_name(effect.trigger))
	if effect.damage > 0:
		_add_line("Degats", str(effect.damage))
	if effect.applied_status != null:
		_add_line("Statut", effect.applied_status.status_name)
	var stored = grid.get_effect(cell)
	if stored != null and stored.has("data") and stored["data"].has("duration"):
		_add_line("Duree", _duration_label(stored["data"]["duration"]))
	if effect.native_energy_id.strip_edges() != "" or effect.counts_as_rune:
		_add_section("Energie")
		if effect.native_energy_id.strip_edges() != "":
			_add_line("Affinite", effect.native_energy_id)
		if effect.elan_discount > 0.0:
			_add_line("Elan", "-%d sur la prochaine action" % int(effect.elan_discount))
		if effect.fervor_generation_multiplier != 1.0:
			_add_line("Ferveur", "x%s generation" % _fmt_float(effect.fervor_generation_multiplier))

func _show_empty() -> void:
	_clear_content()
	_title.text = "Inspection"
	_subtitle.text = "Survole une case, ou clique une unite pour figer le panneau."
	_add_paragraph("Les details de sort, terrain, statut et ressources apparaissent ici pendant le combat.")

func _add_statuses(unit) -> void:
	_add_section("Statuts")
	var statuses = unit.get_active_statuses()
	if statuses.is_empty():
		_add_paragraph("Aucun statut actif.")
		return
	for entry in statuses:
		var data: StatusData = entry.get("data")
		if data == null:
			continue
		var details: Array = []
		details.append("%d tour(s)" % int(entry.get("remaining", data.duration)))
		if data.damage_per_turn > 0:
			details.append("%d degats/tour" % data.damage_per_turn)
		if data.heal_per_turn > 0:
			details.append("%d soin/tour" % data.heal_per_turn)
		if data.skips_turn:
			details.append("saute le tour")
		if data.mp_reduction > 0:
			details.append("-%d PM" % data.mp_reduction)
		if data.damage_multiplier_received != 1.0:
			details.append("degats recus x%s" % _fmt_float(data.damage_multiplier_received))
		_add_line(data.status_name, ", ".join(details))
		if data.description.strip_edges() != "":
			_add_paragraph(data.description)

func _add_spells(unit) -> void:
	_add_section("Sorts")
	if unit.spells.is_empty():
		_add_paragraph("Aucun sort connu.")
		return
	for spell in unit.spells:
		if spell == null:
			continue
		_add_line(spell.spell_name, _spell_summary(spell, unit))
		if spell.description.strip_edges() != "":
			_add_paragraph(spell.description)

func _add_traits(unit) -> void:
	_add_section("Traits")
	if unit.traits.is_empty():
		_add_paragraph("Aucun trait actif.")
		return
	for unit_trait in unit.traits:
		if unit_trait == null:
			continue
		var trait_name: String = unit_trait._trait_name() if unit_trait.has_method("_trait_name") else "trait"
		_add_paragraph(trait_name)

func _spell_summary(spell: Spell, unit = null) -> String:
	var parts: Array = []
	if unit != null and unit.has_energy():
		parts.append("%d Elan" % int(unit.get_spell_elan_cost(spell)))
		var normal_fervor: float = unit.get_spell_fervor_cost(spell, false)
		if normal_fervor > 0.0:
			parts.append("%d Ferveur" % int(normal_fervor))
		if spell.can_imprint():
			parts.append("Emp. +%d Ferveur" % int(unit.get_spell_imprint_fervor_cost(spell)))
	else:
		parts.append("%d PA" % spell.ap_cost)
	if spell.damage > 0:
		parts.append("%d degats" % spell.damage)
	if spell.heal > 0:
		parts.append("%d soin" % spell.heal)
	if spell.shield_grant > 0:
		parts.append("%d bouclier" % spell.shield_grant)
	if spell.applied_status != null:
		parts.append("statut: %s" % spell.applied_status.status_name)
	if spell.has_terrain_effect():
		parts.append("terrain: %s" % spell.terrain_effect.effect_name)
	if spell.push_distance > 0:
		parts.append("pousse %d" % spell.push_distance)
	return " | ".join(parts)

func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	_content.add_child(label)

func _add_line(name: String, value: String) -> void:
	var label := Label.new()
	label.text = "%s : %s" % [name, value]
	label.add_theme_font_size_override("font_size", 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func _add_paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.72))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func _clear_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func _fmt_float(value: float) -> String:
	if abs(value - round(value)) < 0.01:
		return str(int(round(value)))
	return "%.2f" % value

func _duration_label(value: int) -> String:
	return "permanent" if value < 0 else "%d tour(s)" % value

func _trigger_name(trigger: int) -> String:
	match trigger:
		TerrainEffectData.Trigger.TURN_START:
			return "debut de tour"
		TerrainEffectData.Trigger.ON_ENTER:
			return "entree sur case"
		TerrainEffectData.Trigger.PASSIVE:
			return "passif"
	return "inconnu"

func _cell_type_name(cell_type: int) -> String:
	match cell_type:
		GridData.CellType.NORMAL:
			return "Sol normal"
		GridData.CellType.WALL:
			return "Mur"
		GridData.CellType.HOLE:
			return "Trou"
		GridData.CellType.LAVA:
			return "Lave"
		GridData.CellType.ICE:
			return "Glace"
		GridData.CellType.SHADOW:
			return "Ombre"
		GridData.CellType.RUNE:
			return "Rune"
	return "Case"
