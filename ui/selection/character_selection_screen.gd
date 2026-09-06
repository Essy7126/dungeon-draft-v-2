class_name CharacterSelectionScreen
extends Control
## A run owns its party. Browsing a hero never rewrites that party or its assets.

signal back_requested
signal adventure_requested(run_data: RunData)

const CATALOG := preload("res://ui/selection/character_selection_catalog.gd")
const BACKDROP := preload("res://ui/selection/selection_backdrop.gd")
const PREVIEW := preload("res://ui/characters/CharacterPreview3D.tscn")
const SPELL_TREE := preload("res://ui/progression/screens/skill_tree_screen.tscn")
const HEADING := preload("res://asset/ui/recraft_hud_v1/fonts/cinzel/Cinzel-Variable.ttf")
const BODY := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf")
const BOLD := preload("res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Bold.otf")
const REFERENCE := Vector2(1600, 900)
const ORNAMENT := preload("res://ui/selection/selection_ornament.gd")
const INK := Color("121d20")
const PANEL := Color("18272a")
const LINE := Color("42514e")
const GOLD := Color("d6b77c")
const TEXT := Color("f0ebdc")
const MUTED := Color("a6b4ad")
const DIRECTIONS := ["N", "E", "S", "W"]

var selected_index := 0
var selected_spell_index := 0
var orientation_index := 1
var stats_labels: Dictionary = {}
var start_button: Button
var _entries: Array[Dictionary] = []
var _canvas: Control
var _preview: CharacterPreview3D
var _roster_buttons: Array[Button] = []
var _spell_buttons: Array[Button] = []
var _pose_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _name: Label
var _role: Label
var _chapter: Label
var _party_note: Label
var _appearance: Label
var _orientation: Label
var _spell_title: Label
var _spell_cost: Label
var _spell_description: Label
var _spell_limit: Label
var _details: Control
var _lore: Control
var _lore_body: Label
var _discipline_list: VBoxContainer
var _status: Label
var _pose: StringName = &"idle"
var _transitioning := false
var _entry_tween: Tween
var _spell_tree: SkillTreeScreen
var _spell_tree_state: CharacterRunState
var _hero_tween: Tween
var _spell_scroll: ScrollContainer
var _hero_counter: Label
var _zoom_label: Label
var _zoom := 1.0


func _ready() -> void:
	theme = Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 18
	_entries = CATALOG.get_entries()
	_build_screen()
	resized.connect(_layout)
	_layout()
	if not _entries.is_empty():
		select_character(0)
		_roster_buttons[0].grab_focus.call_deferred()
	else:
		start_button.disabled = true
		_status.text = "Aucun personnage disponible. Revenez à l’accueil."
	_canvas.modulate.a = 0.0
	_entry_tween = create_tween()
	_entry_tween.tween_property(_canvas, "modulate:a", 1.0, 0.35)


func _build_screen() -> void:
	var backdrop := BACKDROP.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.name = "SelectionLayout"
	_canvas.size = REFERENCE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_ornament(_canvas, Rect2(31, 21, 51, 51), &"seal")
	_label(_canvas, "CATABASE", Rect2(96, 24, 306, 35), 28, TEXT, HEADING)
	_label(_canvas, "LE SEUIL DES LÉGENDES", Rect2(98, 61, 300, 19), 13, GOLD, BOLD)
	_label(_canvas, "CHOISISSEZ VOTRE LÉGENDE", Rect2(511, 37, 480, 29), 17, GOLD, BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var refuge := _button(_canvas, "Le refuge", Rect2(1190, 31, 139, 44))
	refuge.tooltip_text = "Explorer le refuge et rencontrer l’Archiviste"
	refuge.pressed.connect(open_refuge)
	var back := _button(_canvas, "Retour à l’accueil", Rect2(1341, 31, 227, 44))
	back.pressed.connect(func(): request_back())
	_line(_canvas, Rect2(32, 95, 1536, 1), Color(LINE, 0.55))
	_build_roster()
	_build_stage()
	_build_details()
	_build_footer()
	_wire_navigation()


func _build_roster() -> void:
	_label(_canvas, "Les héros", Rect2(32, 117, 260, 37), 27, TEXT, HEADING)
	_hero_counter = _label(_canvas, "", Rect2(241, 125, 91, 25), 15, GOLD, BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_canvas, "Un destin à incarner", Rect2(33, 154, 297, 24), 17, MUTED)
	for index in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		var unit: UnitData = entry["unit"]
		var button := _button(_canvas, "", Rect2(32, 192 + index * 105, 300, 95))
		button.name = "Hero_%d_%s" % [index, entry["id"]]
		button.set_meta("style_role", &"roster")
		button.set_meta("accent", entry["accent"])
		button.toggle_mode = true
		button.tooltip_text = "%s\n%s\n%s" % [entry["chapter"], unit.role, entry["party_note"]]
		button.pressed.connect(select_character.bind(index))
		_roster_buttons.append(button)
		var portrait_frame := _panel(button, Rect2(9, 9, 76, 77), Color("314240"), Color("6b7058"), 4)
		var thumb := _portrait_for(unit)
		if thumb != null:
			_texture(portrait_frame, thumb, Rect2(2, 2, 72, 73))
		else:
			_label(portrait_frame, unit.unit_name.left(1), Rect2(0, 0, 76, 77), 38, entry["accent"], HEADING, HORIZONTAL_ALIGNMENT_CENTER)
		var marker := _line(button, Rect2(0, 14, 3, 67), Color(entry["accent"], 0.28))
		marker.name = "SelectionMarker"
		_label(button, unit.unit_name, Rect2(101, 9, 178, 31), 25, TEXT, HEADING)
		var journey := _label(button, str(entry["chapter"]).to_upper(), Rect2(101, 44, 180, 19), 13, entry["accent"], BOLD)
		journey.name = "Journey"
		journey.clip_text = true
		journey.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label(button, _short_role(unit), Rect2(101, 67, 182, 19), 14, MUTED)
	var note := _panel(_canvas, Rect2(32, 734, 300, 52), Color(0.06, 0.11, 0.12, 0.94), Color(LINE, 0.7), 4)
	note.name = "RosterNote"
	_label(note, "UN HÉROS, SON AVENTURE", Rect2(14, 6, 272, 18), 13, GOLD, BOLD)
	_label(note, "Le groupe est lié au récit choisi.", Rect2(14, 27, 272, 18), 15, MUTED)


func _build_stage() -> void:
	_label(_canvas, "VOTRE HÉROS", Rect2(445, 113, 596, 20), 14, GOLD, BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_name = _label(_canvas, "", Rect2(350, 138, 780, 69), 57, TEXT, HEADING, HORIZONTAL_ALIGNMENT_CENTER)
	_role = _label(_canvas, "", Rect2(378, 204, 727, 28), 20, TEXT, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_ornament(_canvas, Rect2(628, 677, 228, 33), &"shadow")
	_preview = PREVIEW.instantiate() as CharacterPreview3D
	_preview.name = "HeroPreview"
	_canvas.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_preview.custom_minimum_size = Vector2.ZERO
	_preview.position = Vector2(444, 246)
	_preview.size = Vector2(596, 462)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_showcase_mode(true)
	var left := _button(_canvas, "‹", Rect2(429, 605, 48, 50))
	left.name = "RotateLeft"
	left.tooltip_text = "Tourner vers la gauche"
	left.pressed.connect(rotate_preview.bind(-1))
	var right := _button(_canvas, "›", Rect2(1007, 605, 48, 50))
	right.name = "RotateRight"
	right.tooltip_text = "Tourner vers la droite"
	right.pressed.connect(rotate_preview.bind(1))
	var zoom_out := _button(_canvas, "−", Rect2(941, 676, 34, 33))
	zoom_out.tooltip_text = "Réduire l’aperçu"
	zoom_out.pressed.connect(_change_zoom.bind(-0.05))
	_zoom_label = _label(_canvas, "100 %", Rect2(977, 677, 59, 31), 14, TEXT, BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var zoom_in := _button(_canvas, "+", Rect2(1038, 676, 34, 33))
	zoom_in.tooltip_text = "Agrandir l’aperçu"
	zoom_in.pressed.connect(_change_zoom.bind(0.05))
	_orientation = _label(_canvas, "", Rect2(554, 700, 376, 21), 14, TEXT, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(3):
		var pose_button := _button(_canvas, ["Repos", "Marche", "Attaque"][i], Rect2(541 + i * 136, 730, 128, 43))
		pose_button.toggle_mode = true
		pose_button.pressed.connect(set_preview_pose.bind([&"idle", &"walk", &"attack"][i]))
		_pose_buttons.append(pose_button)
	_appearance = _label(_canvas, "", Rect2(475, 779, 534, 23), 15, MUTED, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_appearance.tooltip_text = "L’apparence montrée est celle disponible en jeu."


func _build_details() -> void:
	var card := _panel(_canvas, Rect2(1126, 119, 442, 668), Color("182c2d"), Color("82765b"), 8)
	card.name = "CharacterFolio"
	_ornament(card, Rect2(6, 6, 430, 656), &"corners")
	for i in range(2):
		var tab := _button(card, ["Caractéristiques", "Histoire & voies"][i], Rect2(16 + i * 205, 16, 198, 44))
		tab.toggle_mode = true
		tab.pressed.connect(show_details.bind(i))
		_tab_buttons.append(tab)
	_details = Control.new()
	card.add_child(_details)
	_details.position = Vector2(21, 80)
	_details.size = Vector2(400, 566)
	_label(_details, "À L’ENTRÉE DE L’AVENTURE", Rect2(0, 0, 399, 23), 14, GOLD, BOLD)
	for i in range(3):
		var stat := _panel(_details, Rect2(i * 137, 35, 126, 88), Color("dfd5b7"), Color("a89468"), 4)
		stats_labels[["hp", "ap", "mp"][i]] = _label(stat, "", Rect2(4, 7, 118, 43), 37, Color("263b37"), BOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label(stat, ["Vitalité", "Points d’action", "Mouvement"][i], Rect2(3, 54, 120, 23), 14, Color("4b5e53"), BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_details, "Initiative", Rect2(0, 136, 120, 25), 17, MUTED)
	stats_labels["initiative"] = _label(_details, "", Rect2(126, 136, 42, 25), 19, TEXT, BOLD)
	_label(_details, "Armure", Rect2(239, 136, 100, 25), 17, MUTED)
	stats_labels["armor"] = _label(_details, "", Rect2(343, 136, 56, 25), 19, TEXT, BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	stats_labels["prowess"] = _label(_details, "", Rect2(0, 164, 255, 23), 15, GOLD, BOLD)
	stats_labels["level"] = _label(_details, "", Rect2(269, 164, 131, 23), 15, MUTED, BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	_ornament(_details, Rect2(0, 193, 400, 10), &"divider")
	_label(_details, "LES QUATRE TECHNIQUES", Rect2(0, 211, 399, 25), 14, GOLD, BOLD)
	for i in range(4):
		var spell_button := _button(_details, "", Rect2(i * 103, 247, 91, 73))
		spell_button.name = "Spell_%d" % i
		spell_button.toggle_mode = true
		spell_button.pressed.connect(select_spell.bind(i))
		_texture(spell_button, null, Rect2(15, 6, 61, 61)).name = "Icon"
		_spell_buttons.append(spell_button)
	_spell_title = _label(_details, "", Rect2(0, 336, 400, 32), 23, TEXT, HEADING)
	_spell_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_spell_title.clip_text = true
	_spell_cost = _label(_details, "", Rect2(0, 376, 400, 27), 17, GOLD, BOLD)
	_spell_scroll = ScrollContainer.new()
	_spell_scroll.name = "SpellDescriptionScroll"
	_details.add_child(_spell_scroll)
	_spell_scroll.position = Vector2(0, 411)
	_spell_scroll.size = Vector2(400, 84)
	_spell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_spell_description = _label(_spell_scroll, "", Rect2(0, 0, 383, 84), 18, TEXT)
	_spell_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spell_description.clip_text = false
	_spell_limit = _label(_details, "", Rect2(0, 503, 400, 25), 14, MUTED)
	_spell_limit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spell_tree_button := _button(_details, "Explorer les maîtrises   ›", Rect2(0, 536, 400, 34))
	spell_tree_button.name = "ExploreMasteries"
	spell_tree_button.pressed.connect(open_spell_tree)
	_lore = Control.new()
	card.add_child(_lore)
	_lore.position = Vector2(21, 80)
	_lore.size = Vector2(400, 566)
	_label(_lore, "UN HÉROS, UNE HISTOIRE", Rect2(0, 0, 400, 25), 14, GOLD, BOLD)
	_lore_body = _label(_lore, "", Rect2(0, 44, 400, 149), 21, TEXT)
	_lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_ornament(_lore, Rect2(0, 213, 400, 10), &"divider")
	_label(_lore, "VOIES DE PROGRESSION", Rect2(0, 244, 400, 25), 14, GOLD, BOLD)
	_discipline_list = VBoxContainer.new()
	_lore.add_child(_discipline_list)
	_discipline_list.position = Vector2(0, 290)
	_discipline_list.size = Vector2(400, 205)
	_discipline_list.add_theme_constant_override("separation", 20)
	var lore_tree_button := _button(_lore, "Explorer les maîtrises   ›", Rect2(0, 524, 400, 46))
	lore_tree_button.name = "ExploreMasteriesFromLore"
	lore_tree_button.pressed.connect(open_spell_tree)
	show_details(0)


func _build_footer() -> void:
	_line(_canvas, Rect2(32, 814, 1536, 1), Color(GOLD, 0.35))
	_ornament(_canvas, Rect2(37, 839, 39, 39), &"seal")
	_chapter = _label(_canvas, "", Rect2(93, 830, 690, 31), 25, TEXT, HEADING)
	_party_note = _label(_canvas, "", Rect2(94, 866, 800, 24), 18, MUTED)
	_status = _label(_canvas, "", Rect2(790, 831, 318, 59), 16, Color("ebc399"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button(_canvas, "INCARNER ACHILLE   ›", Rect2(1127, 832, 440, 57), true)
	start_button.name = "StartAdventure"
	_ornament(start_button, Rect2(0, 0, 440, 57), &"primary")
	start_button.pressed.connect(_start_adventure)


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate()


func get_selected_entry() -> Dictionary:
	return _entries[selected_index] if selected_index >= 0 and selected_index < _entries.size() else {}


func get_preview() -> CharacterPreview3D:
	return _preview


func get_spell_tree() -> SkillTreeScreen:
	return _spell_tree if is_instance_valid(_spell_tree) else null


func open_spell_tree() -> bool:
	if _transitioning or _is_spell_tree_open() or get_selected_entry().is_empty():
		return false
	var resolved_data := get_selected_entry().get("unit") as UnitData
	if resolved_data == null:
		return false
	var preview_state := CharacterRunState.new()
	if not preview_state.initialize(Unit.from_data(resolved_data), resolved_data):
		preview_state.dispose()
		return false
	var initial_discipline: StringName = &""
	if selected_spell_index >= 0 and selected_spell_index < resolved_data.spells.size():
		var selected_spell := resolved_data.spells[selected_spell_index]
		if selected_spell != null and selected_spell.skill_tree != null:
			initial_discipline = selected_spell.skill_tree.discipline_id
	_spell_tree_state = preview_state
	_spell_tree = SPELL_TREE.instantiate() as SkillTreeScreen
	_spell_tree.name = "SelectionSpellTree"
	add_child(_spell_tree)
	_spell_tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spell_tree.screen_closed.connect(_on_spell_tree_closed)
	_preview.set_preview_active(false)
	if not _spell_tree.open_for_state(preview_state, initial_discipline):
		_on_spell_tree_closed()
		return false
	return true


func _is_spell_tree_open() -> bool:
	return is_instance_valid(_spell_tree) and _spell_tree.visible


func _on_spell_tree_closed() -> void:
	if is_instance_valid(_spell_tree):
		_spell_tree.screen_closed.disconnect(_on_spell_tree_closed)
		_spell_tree.queue_free()
	_spell_tree = null
	_dispose_spell_tree_state()
	if is_inside_tree() and is_instance_valid(_preview):
		_preview.set_preview_active(true)
		_play_preview()
		if _lore.visible:
			(_lore.get_node("ExploreMasteriesFromLore") as Button).grab_focus.call_deferred()
		else:
			_spell_buttons[selected_spell_index].grab_focus.call_deferred()


func _dispose_spell_tree_state() -> void:
	if _spell_tree_state != null:
		_spell_tree_state.dispose()
		_spell_tree_state = null


func _exit_tree() -> void:
	if is_instance_valid(_spell_tree) and _spell_tree.screen_closed.is_connected(_on_spell_tree_closed):
		_spell_tree.screen_closed.disconnect(_on_spell_tree_closed)
	_spell_tree = null
	_dispose_spell_tree_state()


func select_character(index: int) -> bool:
	if _transitioning or _is_spell_tree_open() or index < 0 or index >= _entries.size():
		return false
	selected_index = index
	selected_spell_index = 0
	orientation_index = 1
	_pose = &"idle"
	var entry := get_selected_entry()
	var unit: UnitData = entry["unit"]
	_name.text = unit.unit_name
	_hero_counter.text = "%02d / %02d" % [index + 1, _entries.size()]
	_zoom = 1.0
	_zoom_label.text = "100 %"
	_role.text = "Champion de Catabase" if entry["id"] == &"achilles" else unit.role
	_chapter.text = entry["chapter"]
	_party_note.text = entry["party_note"]
	_lore_body.text = entry["description"]
	_appearance.text = "APPARENCE ORIGINALE  ·  Tenue disponible en jeu"
	var champion_mode := unit.progression_profile != null and unit.progression_profile.progression_model == CharacterProgressionProfile.ProgressionModel.CHAMPION_LEVEL_AND_MASTERY
	stats_labels["prowess"].visible = champion_mode
	stats_labels["level"].visible = champion_mode
	stats_labels["prowess"].text = "Prouesse   %d" % unit.attack_power
	stats_labels["level"].text = "Niveau 1"
	stats_labels["hp"].text = str(unit.max_hp)
	stats_labels["ap"].text = str(unit.max_ap)
	stats_labels["mp"].text = str(unit.max_mp)
	stats_labels["initiative"].text = str(unit.initiative)
	stats_labels["armor"].text = str(unit.armure).trim_suffix(".0")
	start_button.text = "INCARNER ACHILLE   ›" if entry["id"] == &"achilles" else "JOUER AVEC LE TRIO   ›"
	start_button.tooltip_text = "Commencer %s\n%s" % [entry["chapter"], entry["party_note"]]
	_preview.configure(unit)
	_preview.set_showcase_zoom(_zoom)
	for i in range(_roster_buttons.size()):
		_mark_selected(_roster_buttons[i], i == index)
	var hud_theme := CharacterHUDThemeCatalog.resolve_refined(unit)
	for i in range(_spell_buttons.size()):
		var button := _spell_buttons[i]
		button.visible = i < unit.spells.size()
		if not button.visible:
			continue
		var spell := unit.spells[i]
		var icon := hud_theme.get_spell_icon_for(spell) if hud_theme != null else spell.icon
		(button.get_node("Icon") as TextureRect).texture = icon
		button.tooltip_text = "%s · %d PA" % [spell.spell_name, spell.ap_cost]
	for child in _discipline_list.get_children():
		_discipline_list.remove_child(child)
		child.free()
	var shown_trees := unit.get_skill_trees()
	if champion_mode and unit.progression_profile.mastery_catalog != null:
		shown_trees = unit.progression_profile.mastery_catalog.doctrines
	for tree in shown_trees:
		var row := Label.new()
		row.text = "◇   %s" % tree.display_name
		row.add_theme_color_override("font_color", TEXT)
		row.add_theme_font_size_override("font_size", 19)
		_discipline_list.add_child(row)
	_status.text = ""
	select_spell(0)
	_update_pose_buttons()
	_play_preview()
	_animate_hero_entry()
	return true


func select_spell(index: int) -> bool:
	if _is_spell_tree_open() or get_selected_entry().is_empty():
		return false
	var unit: UnitData = get_selected_entry()["unit"]
	if index < 0 or index >= unit.spells.size():
		return false
	selected_spell_index = index
	var spell := unit.spells[index]
	_spell_title.text = spell.spell_name
	_spell_title.tooltip_text = spell.spell_name
	_spell_scroll.scroll_vertical = 0
	var range_text := "Sur soi" if spell.is_self_only() else ("Portée %d" % spell.spell_range if spell.minimum_range == spell.spell_range else "Portée %d–%d" % [spell.minimum_range, spell.spell_range])
	_spell_cost.text = "%d PA   ·   %s" % [spell.ap_cost, range_text]
	_spell_description.text = _plain_effect_text(CombatGlossary.spell_base_effect_text(unit, spell))
	_spell_description.tooltip_text = spell.description
	var limits: Array[String] = []
	if spell.once_per_activation:
		limits.append("1 utilisation par activation")
	if spell.cooldown_activations > 0:
		limits.append("Relance : %d tours" % spell.cooldown_activations)
	if spell.max_uses_per_combat > 0:
		limits.append("%d utilisations par combat" % spell.max_uses_per_combat)
	if limits.is_empty():
		limits.append("Disponible tant que vous avez assez de PA")
	_spell_limit.text = " · ".join(limits)
	for i in range(_spell_buttons.size()):
		_mark_selected(_spell_buttons[i], i == index)
	return true


func show_details(tab: int) -> void:
	if tab < 0 or tab > 1:
		return
	_details.visible = tab == 0
	_lore.visible = tab == 1
	if is_instance_valid(start_button):
		var mastery_button := _details.get_node("ExploreMasteries") if tab == 0 else _lore.get_node("ExploreMasteriesFromLore")
		start_button.focus_neighbor_top = start_button.get_path_to(mastery_button)
	for i in range(_tab_buttons.size()):
		_mark_selected(_tab_buttons[i], tab == i)


func rotate_preview(step: int) -> void:
	if _transitioning or _is_spell_tree_open():
		return
	orientation_index = posmod(orientation_index + step, 4)
	_update_pose_buttons()
	_play_preview()


func set_preview_pose(pose: StringName) -> bool:
	if _transitioning or _is_spell_tree_open() or pose not in [&"idle", &"walk", &"attack"] or _clip_for_pose(pose) == &"":
		return false
	_pose = pose
	_update_pose_buttons()
	return _play_preview()


func _clip_for_pose(pose: StringName) -> StringName:
	if _preview.is_using_sprite_preview():
		var clip := StringName("%s_%s" % [pose, DIRECTIONS[orientation_index]])
		return clip if _preview.has_clip(clip) else &""
	var unit: UnitData = get_selected_entry().get("unit")
	if unit != null and unit.animation_set != null:
		var action := CharacterVisual3D.ACTION_IDLE
		if pose == &"walk":
			action = CharacterVisual3D.ACTION_WALK
		elif pose == &"attack":
			action = CharacterVisual3D.ACTION_CAST
		var configured := unit.animation_set.get_animation_name(action)
		if _preview.has_clip(configured):
			return configured
	for clip in _preview.get_available_clips():
		if String(clip).to_lower().contains(String(pose)):
			return clip
	return &""


func _play_preview() -> bool:
	var clip := _clip_for_pose(_pose)
	_orientation.text = "VUE %s" % ["NORD", "EST", "SUD", "OUEST"][orientation_index]
	if not _preview.is_using_sprite_preview():
		var visual := _preview.get_visual_instance()
		if visual != null:
			visual.rotation_degrees.y = (orientation_index - 1) * 90.0
	return _preview.play_clip(clip) if clip != &"" else false


func _update_pose_buttons() -> void:
	var poses := [&"idle", &"walk", &"attack"]
	for i in range(_pose_buttons.size()):
		_pose_buttons[i].disabled = _clip_for_pose(poses[i]) == &""
		_pose_buttons[i].tooltip_text = "Animation indisponible pour ce personnage" if _pose_buttons[i].disabled else "Observer l’animation"
		_mark_selected(_pose_buttons[i], _pose == poses[i])


func prepare_adventure(manager: Node) -> bool:
	if _transitioning or _is_spell_tree_open() or get_selected_entry().is_empty() or manager == null or not manager.has_method("configure_next_run"):
		return false
	var run: RunData = get_selected_entry()["run"]
	if not manager.configure_next_run(run, 0):
		_status.text = "L’aventure n’a pas pu être préparée."
		return false
	_transitioning = true
	start_button.disabled = true
	return true


func _start_adventure() -> void:
	if not prepare_adventure(GameManager):
		return
	_transitioning = true
	start_button.disabled = true
	var run: RunData = get_selected_entry()["run"]
	adventure_requested.emit(run)
	var succeeded := false
	if run.intro_sequence != null:
		succeeded = get_tree().change_scene_to_file("res://cinematics/intro/intro_cinematic.tscn") == OK
	else:
		succeeded = GameManager.start_configured_run()
	if not succeeded:
		GameManager.clear_next_run_configuration()
		_transitioning = false
		start_button.disabled = false
		_status.text = "Impossible d’ouvrir l’aventure. Réessayez."


func request_back(navigate: bool = true) -> void:
	if _transitioning or _is_spell_tree_open():
		return
	back_requested.emit()
	if navigate:
		get_tree().change_scene_to_file("res://ui/TitreEcran.tscn")


func open_refuge() -> void:
	if not _transitioning and not _is_spell_tree_open():
		get_tree().change_scene_to_file("res://hub/StartHub.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _is_spell_tree_open():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_back()


func _layout() -> void:
	if not is_instance_valid(_canvas):
		return
	var fit := minf(size.x / REFERENCE.x, size.y / REFERENCE.y)
	_canvas.scale = Vector2.ONE * fit
	_canvas.position = (size - REFERENCE * fit) * 0.5


func _portrait_for(unit: UnitData) -> Texture2D:
	var illustrated := "res://asset/ui/character_selection/portraits/%s_illustrated_v2.%s" % [unit.get_effective_unit_id(), "png" if unit.get_effective_unit_id() == &"achilles" else "tres"]
	if ResourceLoader.exists(illustrated):
		return load(illustrated) as Texture2D
	var portrait_path := "res://asset/ui/character_selection/portraits/%s.png" % unit.get_effective_unit_id()
	if ResourceLoader.exists(portrait_path):
		return load(portrait_path) as Texture2D
	var hud := CharacterHUDThemeCatalog.resolve_refined(unit)
	if hud != null and hud.portrait_texture != null:
		return hud.portrait_texture
	if unit.preview_sprite_frames != null:
		var frames := unit.preview_sprite_frames
		if frames.has_animation(unit.preview_sprite_animation):
			return frames.get_frame_texture(unit.preview_sprite_animation, 0)
	return null


func _short_role(unit: UnitData) -> String:
	match unit.get_effective_unit_id():
		&"achilles": return "Mobilité · Polyvalence"
		&"elf": return "Précision · Soutien"
		&"mage": return "Éléments · Contrôle"
		&"warrior": return "Mêlée · Protection"
	return unit.role


func _mark_selected(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	var accent: Color = button.get_meta("accent", GOLD)
	var roster := StringName(button.get_meta("style_role", &"")) == &"roster"
	var fill := Color("34483f") if selected else Color("122123")
	button.add_theme_stylebox_override("normal", _style(fill, accent if selected else Color("55615a"), 5, 2 if selected else 1))
	button.add_theme_stylebox_override("pressed", _style(fill if selected else Color("34483f"), accent, 5, 2))
	button.add_theme_color_override("font_color", GOLD if selected else TEXT)
	if roster:
		var marker := button.get_node_or_null("SelectionMarker") as ColorRect
		if marker != null:
			marker.color = accent if selected else Color(accent, 0.15)


func _style(fill: Color, border: Color, radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	if fill.a > 0.5:
		style.shadow_color = Color(0.015, 0.03, 0.03, 0.38)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 3)
	return style


func _panel(parent: Node, rect: Rect2, fill: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, radius))
	return panel


func _button(parent: Node, caption: String, rect: Rect2, primary: bool = false) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 20 if primary else 17)
	button.add_theme_color_override("font_color", INK if primary else TEXT)
	button.add_theme_color_override("font_hover_color", INK if primary else TEXT)
	button.add_theme_color_override("font_pressed_color", INK if primary else GOLD)
	button.add_theme_color_override("font_focus_color", INK if primary else TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(GOLD if primary else INK, Color("efcf91") if primary else LINE, 6))
	button.add_theme_stylebox_override("hover", _style(Color("ebce91") if primary else Color("30423e"), GOLD, 6))
	button.add_theme_stylebox_override("pressed", _style(Color("c1a16a") if primary else Color("314237"), GOLD, 6, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("26312f"), LINE, 6))
	var focus := _style(Color.TRANSPARENT, Color("f0dfae"), 6, 2)
	focus.expand_margin_left = 3
	focus.expand_margin_top = 3
	focus.expand_margin_right = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
	return button


func _label(parent: Node, caption: String, rect: Rect2, font_size: int, color: Color, font: Font = BODY, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = caption
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.04, 0.65) if color.get_luminance() > 0.4 else Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _texture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	parent.add_child(image)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image


func _line(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	parent.add_child(line)
	line.color = color
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _ornament(parent: Node, rect: Rect2, kind: StringName) -> Control:
	var ornament := ORNAMENT.new()
	ornament.kind = kind
	ornament.position = rect.position
	ornament.size = rect.size
	parent.add_child(ornament)
	return ornament


func _change_zoom(delta: float) -> void:
	if _transitioning or _is_spell_tree_open():
		return
	_zoom = clampf(_zoom + delta, 0.85, 1.1)
	_preview.set_showcase_zoom(_zoom)
	_zoom_label.text = "%d %%" % roundi(_zoom * 100.0)


func _animate_hero_entry() -> void:
	if is_instance_valid(_hero_tween):
		_hero_tween.kill()
	_preview.modulate = Color.WHITE
	if GameManager.is_reduced_motion_enabled():
		return
	_preview.modulate.a = 0.0
	_hero_tween = create_tween()
	_hero_tween.tween_property(_preview, "modulate:a", 1.0, 0.18)


func _wire_navigation() -> void:
	for i in range(_roster_buttons.size()):
		var button := _roster_buttons[i]
		button.focus_neighbor_top = button.get_path_to(_roster_buttons[posmod(i - 1, _roster_buttons.size())])
		button.focus_neighbor_bottom = button.get_path_to(_roster_buttons[(i + 1) % _roster_buttons.size()])
		button.focus_neighbor_right = button.get_path_to(_tab_buttons[0])
	for i in range(_spell_buttons.size()):
		var button := _spell_buttons[i]
		button.focus_neighbor_left = button.get_path_to(_spell_buttons[posmod(i - 1, _spell_buttons.size())])
		button.focus_neighbor_right = button.get_path_to(_spell_buttons[(i + 1) % _spell_buttons.size()])
		button.focus_neighbor_bottom = button.get_path_to(_details.get_node("ExploreMasteries"))
	start_button.focus_neighbor_top = start_button.get_path_to(_details.get_node("ExploreMasteries"))


func _plain_effect_text(value: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\[kw:([^\\]]+)\\]")
	var result := value
	for keyword in pattern.search_all(value):
		result = result.replace(keyword.get_string(), str(CombatGlossary.get_entry(keyword.get_string(1)).name))
	return result
