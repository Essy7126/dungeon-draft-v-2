extends CanvasLayer

const KeywordText = preload("res://ui/keyword_rich_text_label.gd")
const Glossary = preload("res://ui/combat_glossary.gd")
const VisualThemeFactory = preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)
const VISUAL_SKIN = preload("res://data/ui/hud_visual_skin_neutral_v1.tres")

var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _content: VBoxContainer
var _release_button: Button
var _locked: bool = false
var _details_expanded: bool = false
var _displayed_unit = null
var _pathfinder: Pathfinder = null
var _grid: GridData = null
var _last_subject_key := ""
var _last_subject_fingerprint := ""

func _ready() -> void:
	layer = 30
	_build_ui()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_show_empty()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_apply_responsive_layout):
		get_viewport().size_changed.disconnect(_apply_responsive_layout)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.theme = VisualThemeFactory.build(VISUAL_SKIN)
	_panel.theme_type_variation = &"HudInspect"
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
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", VISUAL_SKIN.space_md)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", VISUAL_SKIN.space_md)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title = Label.new()
	_title.theme_type_variation = &"HudTitle"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.theme_type_variation = &"HudMuted"
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_box.add_child(_subtitle)

	_release_button = Button.new()
	_release_button.theme_type_variation = &"HudUtilityButton"
	_release_button.text = "Libre"
	_release_button.custom_minimum_size = Vector2(66, 28)
	_release_button.tooltip_text = "Reprendre l'inspection au survol."
	_release_button.pressed.connect(release_lock)
	header.add_child(_release_button)

	var sep := HSeparator.new()
	sep.theme_type_variation = &"HudSeparator"
	root.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", VISUAL_SKIN.space_sm)
	scroll.add_child(_content)


func _apply_responsive_layout() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.y <= 800.0 or viewport_size.x <= 1366.0
	var panel_width := clampf(
		viewport_size.x * (0.22 if compact else 0.19),
		270.0,
		326.0,
	)
	_panel.offset_left = -panel_width - 10.0
	_panel.offset_right = -10.0
	_panel.offset_top = 12.0 if compact else 18.0
	_panel.offset_bottom = -124.0 if compact else -150.0


func get_layout_snapshot() -> Dictionary:
	return {
		"panel": Rect2(_panel.position, _panel.size),
		"locked": _locked,
		"compact": (
			get_viewport().get_visible_rect().size.y <= 800.0
			or get_viewport().get_visible_rect().size.x <= 1366.0
		),
	}


func release_transient_preview() -> void:
	if not _locked:
		_show_empty()

func release_lock() -> void:
	_locked = false
	_release_button.disabled = true
	_show_empty()

func is_locked() -> bool:
	return _locked


func setup(pathfinder: Pathfinder, grid: GridData = null) -> void:
	if _grid != null and _grid.occupancy_changed.is_connected(
		_on_grid_occupancy_changed
	):
		_grid.occupancy_changed.disconnect(_on_grid_occupancy_changed)
	_invalidate_subject_cache()
	_pathfinder = pathfinder
	_grid = grid
	if _grid != null and not _grid.occupancy_changed.is_connected(
		_on_grid_occupancy_changed
	):
		_grid.occupancy_changed.connect(_on_grid_occupancy_changed)


func _on_grid_occupancy_changed(
		_reason: StringName,
		_unit,
		_from_pos: Vector2i,
		_to_pos: Vector2i
	) -> void:
	if _displayed_unit != null and is_instance_valid(_displayed_unit):
		_invalidate_subject_cache()
		show_unit(_displayed_unit, _locked)


func show_unit(unit, locked: bool = false) -> void:
	if _locked and not locked:
		return
	if unit != _displayed_unit:
		_details_expanded = false
	if unit == null:
		_displayed_unit = null
		_locked = locked
		_release_button.disabled = not _locked
		_show_empty()
		return
	var subject_key := "unit:%d" % _object_identity(unit)
	var subject_fingerprint := _unit_subject_fingerprint(unit)
	_displayed_unit = unit
	_locked = locked
	_release_button.disabled = not _locked
	if _subject_is_unchanged(subject_key, subject_fingerprint):
		_panel.visible = true
		return
	_clear_content()
	_panel.visible = true
	_title.text = Glossary.unit_display_name(unit)
	_subtitle.text = "Allie" if unit.team == 0 else "Ennemi"
	_add_resources(unit)
	_add_engagement(unit)
	_add_statuses(unit)
	_add_details_toggle(unit)
	if _details_expanded:
		_add_detailed_stats(unit)
	_add_spells(unit)
	_remember_subject(subject_key, subject_fingerprint)

func show_cell(cell: Vector2i, grid: GridData, terrain_effects, locked: bool = false) -> void:
	if _locked and not locked:
		return
	_displayed_unit = null
	_locked = locked
	_release_button.disabled = not _locked
	if grid == null or not grid.is_valid(cell):
		_show_empty()
		return
	var unit = grid.get_unit(cell)
	if unit != null:
		show_unit(unit, locked)
		return
	var subject_key := "cell:%d:%d:%d" % [
		_object_identity(grid), cell.x, cell.y,
	]
	var subject_fingerprint := _cell_subject_fingerprint(
		cell, grid, terrain_effects
	)
	if _subject_is_unchanged(subject_key, subject_fingerprint):
		_panel.visible = true
		return
	_clear_content()
	_panel.visible = true
	_title.text = "Case %d, %d" % [cell.x, cell.y]
	var base: Dictionary = terrain_effects.get_base_state(cell) \
		if terrain_effects != null and terrain_effects.has_method("get_base_state") \
		else {}
	var base_type := int(base.get("cell_type", grid.get_type(cell)))
	var base_terrain_id := StringName(base.get("terrain_id", &""))
	var base_definition := ArenaCatalogService.terrain(base_terrain_id)
	var base_display_name := base_definition.display_name \
		if base_definition != null else str(base_terrain_id)
	_subtitle.text = base_display_name if not base_display_name.is_empty() \
		else _cell_type_name(base_type)
	_add_section("Terrain permanent")
	_add_line("Type", _cell_type_name(base_type))
	if base_terrain_id != &"":
		_add_line("Terrain", base_display_name)
	_add_line("Marchable", "Oui" if bool(base.get(
		"walkable", grid.is_walkable(cell)
	)) else "Non")
	_add_line("Ligne de vue", "Oui" if bool(base.get(
		"transparent", grid.is_transparent(cell)
	)) else "Non")
	_add_line("Projectiles", "Oui" if bool(base.get(
		"projectile_passable", grid.is_projectile_passable(cell)
	)) else "Non")
	var base_effect: TerrainEffectData = base.get("effect") as TerrainEffectData
	if base_effect != null:
		_add_section("Effet sur unité")
		_add_terrain_effect_details(base_effect)
	var state: CellSurfaceState = terrain_effects.get_surface_state(cell) as CellSurfaceState \
		if terrain_effects != null and terrain_effects.has_method("get_surface_state") else null
	var effect: TerrainEffectData = state.active_effect if state != null and state.is_dynamic() else null
	if effect == null:
		_add_paragraph("Aucune surface temporaire active. La map reste inchangée.")
		_remember_subject(subject_key, subject_fingerprint)
		return
	_add_section("Surface active — temporaire")
	_add_terrain_effect_details(effect)
	if terrain_effects.has_method("get_surface_id"):
		_add_line("ID stable", str(terrain_effects.get_surface_id(cell)))
		_add_line("Texture", str(terrain_effects.get_visual_terrain_id(cell)))
	if terrain_effects.has_method("get_remaining_duration"):
		_add_line(
			"Durée restante",
			_duration_round_label(terrain_effects.get_remaining_duration(cell))
		)
	if effect.dangerous_for_ai:
		_add_line("Danger IA", _fmt_float(effect.ai_danger_weight))
	if state != null and state.source_spell != null:
		_add_line("Source", state.source_spell.spell_name)
	if state != null and state.source_unit != null:
		_add_line("Lanceur", str(state.source_unit.unit_name))
	_add_paragraph("Surface de combat temporaire : ArenaDefinition n'est pas modifiée.")
	_remember_subject(subject_key, subject_fingerprint)


func _add_terrain_effect_details(effect: TerrainEffectData) -> void:
	_add_line("Nom", effect.effect_name)
	if effect.description.strip_edges() != "":
		_add_paragraph(effect.description)
	_add_line("Déclenchement", _trigger_name(effect.trigger))
	if effect.damage > 0:
		_add_line("Dégâts", str(effect.damage))
	if effect.applied_status != null:
		_add_line("Statut", effect.applied_status.status_name)
		var status := effect.applied_status
		if status.damage_per_turn > 0:
			_add_line("Dégâts périodiques", "%d au début du tour" % status.damage_per_turn)
		_add_line("Durée du statut", _duration_round_label(status.duration))
func show_spell_preview(caster, spell: Spell, cell: Vector2i, grid: GridData, spell_caster: SpellCaster) -> void:
	if _locked:
		return
	_invalidate_subject_cache()
	_displayed_unit = caster
	_clear_content()
	if caster == null or spell == null or grid == null or spell_caster == null:
		_show_empty()
		return
	_panel.visible = true
	_title.text = "Apercu : %s" % spell.spell_name
	_subtitle.text = "Cible %d, %d" % [cell.x, cell.y]
	_add_section("Cout")
	_add_paragraph(_spell_summary(spell, caster))
	_add_section("Zone touchee")
	var affected_cells := spell_caster.get_aoe_cells(spell, cell)
	var affected_units: Array = []
	for target_cell in affected_cells:
		var target = grid.get_unit(target_cell)
		if target != null:
			affected_units.append(target)
	if affected_units.is_empty():
		_add_paragraph("Aucune unite touchee. Terrain ou case libre seulement.")
	else:
		for target in affected_units:
			_add_line(target.unit_name, _preview_effect_on_unit(caster, spell, target))
	if spell.terrain_effect != null:
		_add_line("Terrain", "Pose %s" % Glossary.token_for_name(spell.terrain_effect.effect_name))

func _add_resources(unit) -> void:
	_add_section("Ressources")
	_add_line("PV", "%d / %d" % [unit.current_hp, unit.max_hp.get_int()])
	_add_line("Bouclier", str(unit.current_shield))
	_add_line("PM", "%d / %d" % [unit.current_mp, unit.max_mp.get_int()])
	_add_line("PA", "%d / %d" % [unit.current_ap, unit.max_ap.get_int()])


func _add_engagement(unit) -> void:
	if _pathfinder == null:
		return
	var controllers := _pathfinder.get_engaging_controllers(unit)
	if controllers.is_empty():
		return
	var names: Array[String] = []
	var disengagement_cost := 0
	for controller in controllers:
		names.append(controller.unit_name)
		disengagement_cost = maxi(
			disengagement_cost,
			controller.get_control_cost(),
		)
	_add_section("Engagement")
	_add_line("Engagé par", ", ".join(names))
	_add_line(
		"Sortie du contrôle",
		"-%d PM supplémentaire%s" % [
			disengagement_cost,
			"s" if disengagement_cost > 1 else "",
		],
	)


func _add_details_toggle(unit) -> void:
	var btn := Button.new()
	btn.theme_type_variation = &"HudUtilityButton"
	btn.text = "Details v" if _details_expanded else "Details >"
	btn.custom_minimum_size = Vector2(286, 28)
	btn.pressed.connect(func():
		_details_expanded = not _details_expanded
		show_unit(unit, _locked)
	)
	_content.add_child(btn)

func _add_detailed_stats(unit) -> void:
	_add_section("Stats")
	_add_line("Prouesse" if Glossary.uses_champion_progression(unit) else "Attaque", str(unit.attack_power.get_int() if Glossary.uses_champion_progression(unit) else unit.get_attack()))
	_add_line("Initiative", str(unit.get_initiative()))
	_add_line("Armure", _fmt_float(unit.armure.get_value()))
	_add_line("Resist. magique", _fmt_float(unit.resist_magique.get_value()))
	_add_line("Esquive", "%d%%" % int(round(unit.esquive.get_value() * 100.0)))
	_add_line("Critique", "%d%% x%s" % [int(round(unit.crit_chance.get_value() * 100.0)), _fmt_float(unit.crit_multi.get_value())])

func _preview_effect_on_unit(caster, spell: Spell, _target) -> String:
	var parts: Array = []
	var damage := spell.get_scaled_damage(caster)
	if damage > 0:
		parts.append("~%d dégâts avant défenses" % damage)
	if spell.heal > 0:
		parts.append("~%d PV rendus" % spell.heal)
	var shield: int = spell.get_scaled_shield(caster)
	if shield > 0:
		parts.append("%d bouclier" % shield)
	if spell.applied_status != null:
		parts.append("applique %s" % Glossary.token_for_name(spell.applied_status.status_name))
	if spell.push_distance > 0:
		parts.append("pousse %d" % spell.push_distance)
	if parts.is_empty():
		parts.append("effet tactique")
	return " | ".join(parts)

func _show_empty() -> void:
	_displayed_unit = null
	_invalidate_subject_cache()
	_clear_content()
	_panel.visible = false
	_title.text = "Inspection"
	_subtitle.text = "Survole une case, ou clique une unite pour figer le panneau."
	_add_paragraph("Les ressources, statuts, terrains et sorts apparaissent ici pendant le combat.")

func _add_statuses(unit) -> void:
	var statuses = unit.get_active_statuses()
	var has_terrain_status: bool = false
	for entry in statuses:
		var metadata: Dictionary = entry.get("metadata", {})
		if StringName(metadata.get("terrain_id", &"")) != &"":
			has_terrain_status = true
			break
	_add_section("Statuts de terrain" if has_terrain_status else "Statuts")
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
			details.append("%d PV/tour" % data.heal_per_turn)
		if data.skips_turn:
			details.append("saute le tour")
		if data.mp_reduction > 0:
			details.append("-%d PM" % data.mp_reduction)
		if data.damage_multiplier_received != 1.0:
			details.append("degats recus x%s" % _fmt_float(data.damage_multiplier_received))
		_add_line(data.status_name, ", ".join(details))
		var metadata := entry.get("metadata", {}) as Dictionary
		var terrain_id := StringName(metadata.get("terrain_id", &""))
		if terrain_id != &"":
			var terrain := ArenaCatalogService.terrain(terrain_id)
			_add_line(
				"Source terrain",
				terrain.display_name if terrain != null else str(terrain_id)
			)
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
		_add_spell_row(unit, spell)

func _add_spell_row(unit, spell: Spell) -> void:
	var label := RichTextLabel.new()
	label.theme_type_variation = &"HudRichText"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(286, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.text = "%s - %s" % [spell.spell_name, _spell_summary(spell, unit)]
	label.mouse_entered.connect(func(): _show_spell_tooltip(unit, spell))
	label.mouse_exited.connect(_hide_keyword_tooltip)
	_content.add_child(label)

func _spell_summary(spell: Spell, unit = null) -> String:
	var parts: Array = []
	var ap_cost: int = unit.get_spell_ap_cost(spell) if unit != null else spell.ap_cost
	parts.append("%d PA" % ap_cost)
	var damage: int = spell.get_scaled_damage(unit) if unit is Unit else spell.damage
	var heal: int = spell.heal
	var shield: int = spell.get_scaled_shield(unit) if unit is Unit else spell.shield_grant
	if damage > 0:
		parts.append("%d degats" % damage)
	if heal > 0:
		parts.append("%d PV" % heal)
	if shield > 0:
		parts.append("%d bouclier" % shield)
	if spell.applied_status != null:
		parts.append("Applique %s" % spell.applied_status.status_name)
	if spell.has_terrain_effect():
		parts.append("Pose %s" % spell.terrain_effect.effect_name)
	if spell.push_distance > 0:
		parts.append("Pousse %d" % spell.push_distance)
	return " | ".join(parts)

func _add_section(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"HudSection"
	label.text = text
	_content.add_child(label)

func _add_line(name: String, value: String) -> void:
	var label := KeywordText.new()
	label.theme_type_variation = &"HudRichText"
	label.custom_minimum_size = Vector2(286, 0)
	label.set_keyword_text(Glossary.annotate_text("%s : %s" % [name, value]))
	_content.add_child(label)

func _add_paragraph(text: String) -> void:
	var label := KeywordText.new()
	label.theme_type_variation = &"HudRichText"
	label.custom_minimum_size = Vector2(286, 0)
	label.add_theme_color_override("default_color", VISUAL_SKIN.text_secondary)
	label.set_keyword_text(Glossary.annotate_text(text))
	_content.add_child(label)

func _show_spell_tooltip(unit, spell: Spell) -> void:
	var layer = _tooltip_layer()
	if layer == null:
		return
	layer.show_spell(unit, spell, _spell_unusable_reason(unit, spell), get_viewport().get_mouse_position())

func _hide_keyword_tooltip() -> void:
	var layer = _tooltip_layer()
	if layer != null:
		layer.request_hide()

func _tooltip_layer():
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("keyword_tooltip_layer")

func _spell_unusable_reason(unit, spell: Spell) -> String:
	if unit == null:
		return "aucun lanceur actif"
	if spell == null:
		return "sort invalide"
	var ap_cost: int = unit.get_spell_ap_cost(spell)
	if unit.current_ap < ap_cost:
		return "PA insuffisants (%d / %d)" % [unit.current_ap, ap_cost]
	return ""


func _unit_subject_fingerprint(unit) -> String:
	var values: Array = [
		unit.unit_name,
		Glossary.champion_level(unit),
		unit.attack_power.get_int(),
		unit.team,
		unit.current_hp,
		unit.max_hp.get_int(),
		unit.current_shield,
		unit.current_mp,
		unit.max_mp.get_int(),
		unit.current_ap,
		unit.max_ap.get_int(),
		_details_expanded,
		str(unit.get_active_statuses()),
	]
	if _details_expanded:
		values.append_array([
			unit.get_attack(),
			unit.get_initiative(),
			unit.armure.get_value(),
			unit.resist_magique.get_value(),
			unit.esquive.get_value(),
			unit.crit_chance.get_value(),
			unit.crit_multi.get_value(),
		])
	for spell in unit.spells:
		if spell != null:
			values.append([
				_object_identity(spell),
				unit.get_spell_ap_cost(spell),
			])
	if _pathfinder != null:
		for controller in _pathfinder.get_engaging_controllers(unit):
			values.append([
				_object_identity(controller),
				controller.unit_name,
				controller.grid_pos,
				controller.get_control_cost(),
			])
	return str(values)


func _cell_subject_fingerprint(
		cell: Vector2i,
		grid: GridData,
		terrain_effects
	) -> String:
	var values: Array = [
		grid.get_type(cell),
		grid.is_walkable(cell),
		grid.is_transparent(cell),
		grid.is_projectile_passable(cell),
	]
	if terrain_effects == null:
		return str(values)
	if terrain_effects.has_method("get_base_state"):
		values.append(str(terrain_effects.get_base_state(cell)))
	if terrain_effects.has_method("get_surface_id"):
		values.append(terrain_effects.get_surface_id(cell))
		values.append(terrain_effects.get_visual_terrain_id(cell))
	if terrain_effects.has_method("get_remaining_duration"):
		values.append(terrain_effects.get_remaining_duration(cell))
	if terrain_effects.has_method("get_surface_state"):
		var state := terrain_effects.get_surface_state(cell) as CellSurfaceState
		if state != null:
			values.append([
				state.is_dynamic(),
				_object_identity(state.active_effect),
				_object_identity(state.source_spell),
				_object_identity(state.source_unit),
			])
	return str(values)


func _subject_is_unchanged(key: String, fingerprint: String) -> bool:
	return (
		_panel.visible
		and _last_subject_key == key
		and _last_subject_fingerprint == fingerprint
	)


func _remember_subject(key: String, fingerprint: String) -> void:
	_last_subject_key = key
	_last_subject_fingerprint = fingerprint


func _invalidate_subject_cache() -> void:
	_last_subject_key = ""
	_last_subject_fingerprint = ""


func _object_identity(value) -> int:
	if value is Object and is_instance_valid(value):
		return value.get_instance_id()
	return 0

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


func _duration_round_label(value: int) -> String:
	return "permanente" if value < 0 else "%d round(s)" % value

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
