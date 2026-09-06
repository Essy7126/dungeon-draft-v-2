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
const REFERENCE := Vector2(1440, 900)
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


func _ready() -> void:
	theme = Theme.new()
	theme.default_font = BODY
	theme.default_font_size = 16
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
	_label(_canvas, "C A T A B A S E", Rect2(42, 27, 350, 30), 23, GOLD, HEADING)
	_label(_canvas, "LE SEUIL DES LÉGENDES", Rect2(43, 64, 360, 22), 12, MUTED, BOLD)
	_label(_canvas, "01   PERSONNAGE", Rect2(625, 41, 220, 28), 14, GOLD, BOLD)
	_label(_canvas, "02   L’AVENTURE", Rect2(845, 41, 190, 28), 14, MUTED)
	var refuge := _button(_canvas, "Le refuge", Rect2(1040, 32, 138, 42))
	refuge.tooltip_text = "Explorer le refuge et rencontrer l’Archiviste"
	refuge.pressed.connect(open_refuge)
	var back := _button(_canvas, "Retour à l’accueil", Rect2(1190, 32, 208, 42))
	back.pressed.connect(func(): request_back())
	_line(_canvas, Rect2(42, 106, 1356, 1), LINE)
	_build_roster()
	_build_stage()
	_build_details()
	_build_footer()


func _build_roster() -> void:
	_label(_canvas, "Choisissez votre héros", Rect2(42, 130, 305, 38), 23, TEXT, HEADING)
	_label(_canvas, "Votre héros, votre aventure", Rect2(43, 171, 300, 25), 15, MUTED)
	for index in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		var unit: UnitData = entry["unit"]
		var button := _button(_canvas, "", Rect2(42, 218 + index * 92, 280, 82))
		button.name = "Hero_%d_%s" % [index, entry["id"]]
		button.toggle_mode = true
		button.tooltip_text = "%s\n%s\n%s" % [entry["chapter"], unit.role, entry["party_note"]]
		button.pressed.connect(select_character.bind(index))
		_roster_buttons.append(button)
		var emblem := _panel(button, Rect2(13, 13, 56, 56), Color("243637"), LINE, 5)
		var thumb := _portrait_for(unit)
		if thumb != null:
			_texture(emblem, thumb, Rect2(2, 2, 52, 52))
		else:
			_label(emblem, unit.unit_name.left(1), Rect2(0, 3, 56, 50), 30, entry["accent"], HEADING, HORIZONTAL_ALIGNMENT_CENTER)
		_label(button, unit.unit_name, Rect2(82, 8, 180, 28), 22, TEXT, HEADING)
		var chapter := str(entry["chapter"]).to_upper()
		var journey := _label(button, chapter, Rect2(82, 35, 183, 19), 10 if chapter.length() > 24 else 11, entry["accent"], BOLD)
		journey.name = "Journey"
		_label(button, _short_role(unit), Rect2(82, 55, 183, 19), 12, MUTED)
	var note_panel := _panel(_canvas, Rect2(42, 691, 280, 66), Color("172427"), LINE, 6)
	note_panel.name = "RosterNote"
	_label(note_panel, "UNE AVENTURE, UN GROUPE", Rect2(14, 9, 254, 20), 11, GOLD, BOLD)
	_label(note_panel, "Chaque héros appartient à son récit.", Rect2(14, 32, 254, 24), 14, MUTED)


func _build_stage() -> void:
	_label(_canvas, "VOTRE PERSONNAGE", Rect2(375, 128, 540, 26), 12, GOLD, BOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_name = _label(_canvas, "", Rect2(349, 159, 594, 65), 50, TEXT, HEADING, HORIZONTAL_ALIGNMENT_CENTER)
	_role = _label(_canvas, "", Rect2(365, 227, 560, 28), 17, MUTED, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_preview = PREVIEW.instantiate() as CharacterPreview3D
	_preview.name = "HeroPreview"
	_canvas.add_child(_preview)
	_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_preview.custom_minimum_size = Vector2.ZERO
	_preview.position = Vector2(400, 278)
	_preview.size = Vector2(490, 380)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _button(_canvas, "‹", Rect2(368, 572, 43, 44))
	left.tooltip_text = "Tourner le personnage vers la gauche"
	left.pressed.connect(rotate_preview.bind(-1))
	var right := _button(_canvas, "›", Rect2(880, 572, 43, 44))
	right.tooltip_text = "Tourner le personnage vers la droite"
	right.pressed.connect(rotate_preview.bind(1))
	_orientation = _label(_canvas, "", Rect2(476, 639, 340, 18), 12, MUTED, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	var poses := ["Repos", "Marche", "Attaque"]
	var pose_ids := [&"idle", &"walk", &"attack"]
	for i in range(3):
		var pose_button := _button(_canvas, poses[i], Rect2(459 + i * 126, 657, 118, 37))
		pose_button.toggle_mode = true
		pose_button.pressed.connect(set_preview_pose.bind(pose_ids[i]))
		_pose_buttons.append(pose_button)
	var appearance_panel := _panel(_canvas, Rect2(393, 711, 510, 47), Color("172427"), LINE, 5)
	_label(appearance_panel, "APPARENCE", Rect2(15, 12, 112, 23), 11, GOLD, BOLD)
	_appearance = _label(appearance_panel, "", Rect2(128, 10, 368, 28), 15, TEXT)
	appearance_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	appearance_panel.tooltip_text = "Tenue actuellement disponible en jeu. Les commandes au-dessus permettent d’observer ses orientations et animations."


func _build_details() -> void:
	var card := _panel(_canvas, Rect2(976, 132, 422, 626), PANEL, LINE, 10)
	for i in range(2):
		var tab := _button(card, ["Caractéristiques", "Histoire & voies"][i], Rect2(16 + i * 197, 16, 192, 40))
		tab.toggle_mode = true
		tab.pressed.connect(show_details.bind(i))
		_tab_buttons.append(tab)
	_details = Control.new()
	card.add_child(_details)
	_details.position = Vector2(22, 76)
	_details.size = Vector2(378, 528)
	_label(_details, "ATTRIBUTS DE DÉPART", Rect2(0, 0, 340, 23), 11, GOLD, BOLD)
	var fields := ["hp", "ap", "mp"]
	var captions := ["Vitalité", "Points d’action", "Mouvement"]
	var colors := [Color("dca48c"), Color("d6c47d"), Color("9bbfa6")]
	for i in range(3):
		var stat := _panel(_details, Rect2(i * 129, 34, 120, 87), INK, Color("354442"), 5)
		stats_labels[fields[i]] = _label(stat, "", Rect2(4, 9, 112, 40), 32, colors[i], BOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label(stat, captions[i], Rect2(3, 53, 114, 23), 12, MUTED, BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_label(_details, "Initiative", Rect2(1, 133, 115, 25), 15, MUTED)
	stats_labels["initiative"] = _label(_details, "", Rect2(123, 133, 45, 25), 17, TEXT, BOLD)
	_label(_details, "Armure", Rect2(220, 133, 91, 25), 15, MUTED)
	stats_labels["armor"] = _label(_details, "", Rect2(317, 133, 58, 25), 17, TEXT, BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	stats_labels["prowess"] = _label(_details, "", Rect2(1, 156, 210, 18), 12, GOLD, BOLD)
	stats_labels["level"] = _label(_details, "", Rect2(220, 156, 155, 18), 12, MUTED, BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	_line(_details, Rect2(0, 173, 378, 1), LINE)
	_label(_details, "CAPACITÉS", Rect2(0, 189, 200, 25), 11, GOLD, BOLD)
	_label(_details, "Sélectionnez pour explorer", Rect2(170, 189, 209, 25), 12, MUTED, BODY, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(4):
		var spell_button := _button(_details, "", Rect2(i * 97, 226, 86, 74))
		spell_button.name = "Spell_%d" % i
		spell_button.toggle_mode = true
		spell_button.pressed.connect(select_spell.bind(i))
		_texture(spell_button, null, Rect2(13, 7, 60, 60)).name = "Icon"
		_spell_buttons.append(spell_button)
	_spell_title = _label(_details, "", Rect2(0, 318, 376, 32), 22, TEXT, HEADING)
	_spell_cost = _label(_details, "", Rect2(0, 357, 375, 25), 14, GOLD, BOLD)
	_spell_description = _label(_details, "", Rect2(0, 395, 378, 62), 16, TEXT)
	_spell_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spell_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_spell_description.clip_text = true
	_spell_limit = _label(_details, "", Rect2(0, 463, 378, 28), 12, MUTED)
	_spell_limit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spell_tree_button := _button(_details, "Explorer les maîtrises   ›", Rect2(0, 499, 378, 29))
	spell_tree_button.name = "ExploreMasteries"
	spell_tree_button.pressed.connect(open_spell_tree)
	_lore = Control.new()
	card.add_child(_lore)
	_lore.position = Vector2(22, 76)
	_lore.size = Vector2(378, 528)
	_label(_lore, "UN HÉROS, UNE HISTOIRE", Rect2(0, 0, 370, 25), 11, GOLD, BOLD)
	_lore_body = _label(_lore, "", Rect2(0, 42, 378, 140), 18, TEXT)
	_lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_line(_lore, Rect2(0, 198, 378, 1), LINE)
	_label(_lore, "VOIES DE PROGRESSION", Rect2(0, 220, 370, 25), 11, GOLD, BOLD)
	_discipline_list = VBoxContainer.new()
	_lore.add_child(_discipline_list)
	_discipline_list.position = Vector2(0, 265)
	_discipline_list.size = Vector2(378, 196)
	_discipline_list.add_theme_constant_override("separation", 14)
	var lore_tree_button := _button(_lore, "Explorer les maîtrises   ›", Rect2(0, 484, 378, 34))
	lore_tree_button.name = "ExploreMasteriesFromLore"
	lore_tree_button.pressed.connect(open_spell_tree)
	show_details(0)


func _build_footer() -> void:
	_line(_canvas, Rect2(42, 789, 1356, 1), LINE)
	_chapter = _label(_canvas, "", Rect2(43, 804, 640, 31), 21, TEXT, HEADING)
	_party_note = _label(_canvas, "", Rect2(43, 843, 640, 25), 15, MUTED)
	_status = _label(_canvas, "", Rect2(700, 841, 310, 35), 12, Color("dfb693"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = _button(_canvas, "INCARNER ACHILLE   ›", Rect2(1010, 811, 388, 62), true)
	start_button.name = "StartAdventure"
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
	_role.text = unit.role
	_chapter.text = entry["chapter"]
	_party_note.text = entry["party_note"]
	_lore_body.text = entry["description"]
	_appearance.text = "Armure d’airain · Originale" if entry["id"] == &"achilles" else "Tenue d’origine"
	var champion_mode := unit.progression_profile != null and unit.progression_profile.progression_model == CharacterProgressionProfile.ProgressionModel.CHAMPION_LEVEL_AND_MASTERY
	stats_labels["prowess"].visible = champion_mode
	stats_labels["level"].visible = champion_mode
	stats_labels["prowess"].text = "Prouesse technique   %d" % unit.attack_power
	stats_labels["level"].text = "Niveau 1"
	stats_labels["hp"].text = str(unit.max_hp)
	stats_labels["ap"].text = str(unit.max_ap)
	stats_labels["mp"].text = str(unit.max_mp)
	stats_labels["initiative"].text = str(unit.initiative)
	stats_labels["armor"].text = str(unit.armure).trim_suffix(".0")
	start_button.text = "INCARNER ACHILLE   ›" if entry["id"] == &"achilles" else "JOUER AVEC LE TRIO   ›"
	start_button.tooltip_text = "Commencer %s\n%s" % [entry["chapter"], entry["party_note"]]
	_preview.configure(unit)
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
	var range_text := "Sur soi" if spell.is_self_only() else "Portée %d–%d" % [spell.minimum_range, spell.spell_range]
	_spell_cost.text = "%d PA   ·   %s" % [spell.ap_cost, range_text]
	_spell_description.text = CombatGlossary.spell_base_effect_text(unit, spell)
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
	for i in range(_tab_buttons.size()):
		_mark_selected(_tab_buttons[i], tab == i)


func rotate_preview(step: int) -> void:
	orientation_index = posmod(orientation_index + step, 4)
	_play_preview()


func set_preview_pose(pose: StringName) -> bool:
	if pose not in [&"idle", &"walk", &"attack"] or _clip_for_pose(pose) == &"":
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
	_orientation.text = "VUE %s   ·   TENUE EN JEU" % ["NORD", "EST", "SUD", "OUEST"][orientation_index]
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
		&"achilles": return "Lance · Mobilité · Garde"
		&"elf": return "Précision · Soutien"
		&"mage": return "Éléments · Contrôle"
		&"warrior": return "Mêlée · Protection"
	return unit.role


func _mark_selected(button: Button, selected: bool) -> void:
	button.set_pressed_no_signal(selected)
	button.add_theme_stylebox_override("normal", _style(Color("2c3b36") if selected else INK, GOLD if selected else LINE, 6, 2 if selected else 1))
	button.add_theme_color_override("font_color", GOLD if selected else TEXT)


func _style(fill: Color, border: Color, radius: int = 6, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
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
	button.add_theme_font_size_override("font_size", 18 if primary else 15)
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
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.04, 0.8))
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


func _line(parent: Node, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	parent.add_child(line)
	line.color = color
	line.position = rect.position
	line.size = rect.size
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
