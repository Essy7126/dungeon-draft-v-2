extends VBoxContainer
const SHEET := preload("res://core/expedition/expedition_character_sheet.gd")
const ART := preload("res://ui/expedition/catabase_ui_theme.gd")


func refresh(session: ExpeditionSession) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 10)
	var champion := session.character.champion_progression
	var hero := session.character.unit
	var next_xp := champion.profile.xp_for_level(champion.current_level + 1)
	_label(
		self,
		"Achille · niveau %d · %s"
		% [
			champion.current_level,
			(
				"%d / %d XP" % [champion.current_xp, next_xp]
				if champion.current_level < champion.profile.level_cap
				else "Niveau maximum"
			),
		],
		true,
	)
	_label(
		self,
		"PV : %d / %d · PA actuels : %d / %d · PM actuels : %d / %d · Garde : %d"
		% [
			hero.current_hp,
			hero.max_hp.get_int(),
			hero.current_ap,
			hero.max_ap.get_int(),
			hero.current_mp,
			hero.max_mp.get_int(),
			hero.current_shield,
		],
	)
	_label(
		self,
		"Base au niveau actuel + bonus fixes, puis bonus en pourcentage. Le total inclut l'équipement et les effets actifs ; survolez une ligne pour connaître ses modificateurs.",
	)
	var current_group := ""
	var grid: GridContainer
	for row in SHEET.rows(hero):
		if row.group != current_group:
			current_group = row.group
			_label(self, current_group.to_upper(), true)
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 18)
			grid.add_theme_constant_override("v_separation", 7)
			add_child(grid)
			for heading in ["Caractéristique", "Base", "Bonus", "Total"]:
				_label(grid, heading, true)
		for key in ["title", "base", "bonus", "total"]:
			var cell := _label(grid, str(row[key]), key == "total")
			cell.name = "Detailed_%s_%s" % [row.id, key]
			cell.tooltip_text = row.detail
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if key == "title":
				cell.size_flags_stretch_ratio = 2.2
	_label(self, "PROGRESSION ET CONSTRUCTION", true)
	_label(
		self,
		"%d points de caractéristiques disponibles · %d points de destin · %d oboles"
		% [champion.unspent_attribute_points, session.build.points, session.gold],
	)
	_label(
		self,
		"Boucliers créés : ×%.2f · Sagesse : %d / %d"
		% [hero.shield_creation_multiplier, champion.wisdom_points, champion.profile.wisdom_cap],
	)
	_label(self, "SORTS ÉQUIPÉS", true)
	for spell in session.character.loadout.get_equipped_spells():
		_label(
			self,
			"%s · %d PA · portée %d–%d"
			% [spell.spell_name, spell.ap_cost, spell.minimum_range, spell.spell_range],
		).tooltip_text = spell.description
	_label(self, "ÉQUIPEMENT PORTÉ", true)
	for item in session.character.equipment_loadout.get_equipped_items():
		var definition := GameManager.item_catalog.get_definition(item.definition_id)
		if definition != null:
			_item(definition)
	_label(self, "RELIQUES DANS LE SAC", true)
	var count := 0
	if GameManager.run_inventory != null:
		for item in GameManager.run_inventory.get_slots():
			if item == null:
				continue
			var definition := GameManager.item_catalog.get_definition(item.definition_id)
			if definition != null and definition.category == ItemDefinition.Category.RELIC:
				_item(definition)
				count += 1
	if count == 0:
		_label(self, "Aucune relique.")
	_label(self, "EFFETS ACTIFS", true)
	var statuses := hero.get_active_statuses()
	if statuses.is_empty():
		_label(self, "Aucun effet temporaire actif.")
	for entry in statuses:
		var data: StatusData = entry.get("data")
		if data != null:
			_label(self, data.status_name).tooltip_text = data.description


func _item(definition: ItemDefinition) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = definition.get_inventory_icon()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := _label(row, definition.display_name + " · " + definition.description)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _label(parent: Node, text: String, highlighted := false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", ART.GOLD if highlighted else ART.TEXT)
	parent.add_child(label)
	return label
