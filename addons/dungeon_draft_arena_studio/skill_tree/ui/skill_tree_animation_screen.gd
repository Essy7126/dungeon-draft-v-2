@tool
# addons/dungeon_draft_arena_studio/skill_tree/ui/skill_tree_animation_screen.gd
# ============================================================
# ÉCRAN « ANIMATIONS » DU STUDIO DES PERSONNAGES
#
# Une seule intention : choisir quelle animation joue chaque moment de la
# vie d'un personnage, et la voir tout de suite.
#
# Trois zones, jamais plus :
#   1 · gauche  — le personnage et le moment à régler
#   2 · centre  — la liste des moments, avec un choix par moment
#   3 · droite  — l'aperçu du personnage et le bouton « Lire »
# ============================================================

class_name SkillTreeAnimationScreen
extends HSplitContainer

signal character_change_requested
signal clip_change_requested(
	action_id: StringName, clip_name: StringName, event_label: String
)

const PREVIEW_SCENE := preload("res://ui/characters/CharacterPreview3D.tscn")
const NO_CLIP_TEXT := "Aucune animation"
const ACCENT_COLOR := Color(0.48, 0.86, 1.0)
const MUTED_COLOR := Color(0.72, 0.77, 0.84)
const WARNING_COLOR := Color(1.0, 0.72, 0.3)

# Libellés des événements. CharacterVisual3D.ACTION_ORDER reste l'autorité sur
# la liste et l'ordre : un événement ajouté là-bas apparaît ici même sans
# libellé, plutôt que de disparaître silencieusement.
const EVENT_LABELS := {
	&"idle": "Repos",
	&"walk": "Marche",
	&"run": "Course",
	&"cast": "Attaque ou sort",
	&"cast_start": "Préparation",
	&"cast_hold": "Attente",
	&"cast_end": "Libération",
	&"hit": "Dégât reçu",
	&"death": "Mort",
}

const EVENT_HELP := {
	&"idle": "Le personnage attend, immobile, entre deux actions.",
	&"walk": "Déplacement normal, d’une case à la suivante.",
	&"run": "Déplacement rapide, sur une longue distance.",
	&"cast": "Le personnage lance un sort ou porte son attaque.",
	&"cast_start": "Facultatif. Le personnage prépare un sort qui se charge avant de partir.",
	&"cast_hold": "Facultatif. Le personnage garde son sort chargé en attendant.",
	&"cast_end": "Facultatif. Le sort chargé part enfin.",
	&"hit": "Le personnage encaisse un coup.",
	&"death": "Le personnage s’effondre et quitte le combat.",
}

var character_label: Label
var navigation_help: Label
var event_list: ItemList
var center_title: Label
var center_help: Label
var rows_box: VBoxContainer
var preview: CharacterPreview3D
var preview_caption: Label
var play_button: Button

var _unit: UnitData = null
var _heroes: Array[Dictionary] = []
var _current_path := ""
var _guided := true
var _selected_event := 0
var _rows := {}
var _available_clips: Array[StringName] = []
var _applying := false


func _ready() -> void:
	split_offset = 280
	add_child(_build_navigation())
	var content := HSplitContainer.new()
	content.split_offset = 860
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)
	content.add_child(_build_events())
	content.add_child(_build_preview())
	_rebuild_event_list()
	_rebuild_character_list()
	_select_event(_selected_event, false)
	# Rien ne doit se dessiner tant que cet écran n'est pas affiché : le Studio
	# vit dans une fenêtre d'éditeur, pas dans une boucle de jeu.
	preview.set_preview_active(false)


# ============================================================
# API appelée par le Studio
# ============================================================

func set_catalog(heroes: Array[Dictionary], current_path: String) -> void:
	_heroes = heroes
	_current_path = current_path
	_rebuild_character_list()


func set_document(unit: UnitData, current_path: String) -> void:
	if rows_box == null:
		return
	_current_path = current_path
	if unit == _unit:
		# Même personnage : on rafraîchit seulement les valeurs affichées pour
		# ne pas relancer l'aperçu à chaque modification ou annulation. L'appel
		# est différé parce qu'il peut venir du signal d'une liste déroulante
		# qu'il reconstruit.
		_rebuild_character_list()
		_sync_values.call_deferred()
		return
	_unit = unit
	_rebuild_character_list()
	_rebuild_rows()


## Appelée quand l'écran cesse d'être affiché : ni animation ni rendu 3D ne
## doivent continuer pendant qu'on travaille ailleurs.
func suspend() -> void:
	if preview != null:
		preview.set_preview_active(false)


## Appelée quand l'écran redevient visible.
func resume() -> void:
	if preview != null:
		preview.set_preview_active(true)


func set_guided(value: bool) -> void:
	if _guided == value:
		return
	_guided = value
	for action_value in _rows:
		var row := _rows[action_value] as Dictionary
		(row.get("help") as Label).visible = _guided
	center_help.visible = _guided
	navigation_help.visible = _guided


func selected_event_label() -> String:
	return _label_for(_action_at(_selected_event))


# ============================================================
# Construction des trois zones
# ============================================================

func _build_navigation() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 250
	box.add_theme_constant_override("separation", 6)
	box.add_child(_title_label("1 · PERSONNAGE"))
	character_label = Label.new()
	character_label.text = "Aucun personnage"
	character_label.clip_text = true
	character_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_label.add_theme_font_size_override("font_size", 16)
	box.add_child(character_label)
	var change_button := Button.new()
	change_button.text = "Changer de personnage"
	change_button.tooltip_text = "Revenir à l’écran d’accueil pour en choisir un autre."
	change_button.pressed.connect(func(): character_change_requested.emit())
	box.add_child(change_button)
	navigation_help = Label.new()
	navigation_help.text = "Choisissez ci-dessous le moment à régler."
	navigation_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	navigation_help.add_theme_color_override("font_color", MUTED_COLOR)
	box.add_child(navigation_help)
	box.add_child(HSeparator.new())
	var event_title := Label.new()
	event_title.text = "MOMENT À RÉGLER"
	event_title.add_theme_font_size_override("font_size", 13)
	event_title.add_theme_color_override("font_color", ACCENT_COLOR)
	box.add_child(event_title)
	event_list = ItemList.new()
	event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_list.item_selected.connect(_on_event_selected)
	box.add_child(event_list)
	return box


func _build_events() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 420
	box.add_theme_constant_override("separation", 6)
	center_title = _title_label("2 · ANIMATIONS")
	center_title.clip_text = true
	center_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(center_title)
	center_help = Label.new()
	center_help.text = "Pour chaque moment, choisissez l’animation que le personnage doit jouer. L’aperçu la joue aussitôt."
	center_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_help.add_theme_color_override("font_color", MUTED_COLOR)
	box.add_child(center_help)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 10)
	scroll.add_child(rows_box)
	return box


func _build_preview() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 330
	box.add_theme_constant_override("separation", 6)
	box.add_child(_title_label("3 · APERÇU"))
	preview_caption = Label.new()
	preview_caption.text = "Aucun personnage"
	preview_caption.clip_text = true
	preview_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_caption.add_theme_font_size_override("font_size", 15)
	box.add_child(preview_caption)
	preview = PREVIEW_SCENE.instantiate() as CharacterPreview3D
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(preview)
	play_button = Button.new()
	play_button.text = "▶  Lire l’animation"
	play_button.tooltip_text = "Rejoue l’animation du moment sélectionné."
	play_button.custom_minimum_size.y = 46
	play_button.add_theme_font_size_override("font_size", 16)
	play_button.pressed.connect(_play_selected)
	box.add_child(play_button)
	return box


func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", ACCENT_COLOR)
	return label


# ============================================================
# Contenu
# ============================================================

## Le personnage n'est plus choisi ici : cet écran ne fait que rappeler lequel
## est ouvert, pour qu'on sache toujours ce qu'on est en train de modifier.
func _rebuild_character_list() -> void:
	if character_label == null:
		return
	character_label.text = _unit.unit_name if _unit != null else "Aucun personnage"


func _rebuild_event_list() -> void:
	event_list.clear()
	for action in CharacterVisual3D.ACTION_ORDER:
		event_list.add_item(_label_for(action))
	if event_list.item_count > 0:
		event_list.select(clampi(_selected_event, 0, event_list.item_count - 1))


func _rebuild_rows() -> void:
	_rows.clear()
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	if _unit == null:
		center_title.text = "2 · ANIMATIONS"
		preview.configure(null)
		preview_caption.text = "Aucun personnage"
		play_button.disabled = true
		_available_clips = []
		return
	center_title.text = "2 · ANIMATIONS · %s" % _unit.unit_name.to_upper()
	preview.configure(_unit)
	_available_clips = preview.get_available_clips()
	var stored_count := _unit.animation_set.configured_action_ids().size() \
		if _unit.animation_set != null else 0
	if _available_clips.is_empty():
		# L'explication passe avant tout : neuf réglages inutilisables noieraient
		# la seule information utile du moment.
		_add_unavailable_notice()
		if stored_count == 0:
			_update_caption()
			_update_play_button()
			return
	for action in CharacterVisual3D.ACTION_ORDER:
		_rows[action] = _build_row(action)
	_select_event(_selected_event, false)
	_sync_values()
	_play_selected()


## Message affiché quand le personnage n'expose aucune animation : il dit ce
## qui manque, pas seulement que c'est vide.
func _add_unavailable_notice() -> void:
	var panel := PanelContainer.new()
	rows_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "⚠  Ce personnage n’a pas encore d’animations utilisables"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", WARNING_COLOR)
	box.add_child(title)
	var help := Label.new()
	help.text = (
		"Pour régler ses animations, %s a besoin d’une scène de présentation "
		+ "3D contenant ses animations. Elle se renseigne dans l’onglet "
		+ "Apparence de l’écran Compétences, sous « Scène de présentation »."
	) % _unit.unit_name
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", MUTED_COLOR)
	box.add_child(help)


func _build_row(action: StringName) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_child(box)
	var title := Label.new()
	title.text = _label_for(action)
	title.add_theme_font_size_override("font_size", 15)
	box.add_child(title)
	var help := Label.new()
	help.text = str(EVENT_HELP.get(action, ""))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", MUTED_COLOR)
	help.visible = _guided
	box.add_child(help)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.tooltip_text = "Animations présentes dans le modèle 3D de ce personnage."
	option.item_selected.connect(_on_clip_selected.bind(action, option))
	option.disabled = _available_clips.is_empty()
	box.add_child(option)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", MUTED_COLOR)
	note.visible = false
	box.add_child(note)
	return {"box": box, "title": title, "help": help, "option": option, "note": note}


## Remplit les listes déroulantes à partir de la fiche du personnage, sans
## reconstruire l'aperçu ni interrompre l'animation en cours.
func _sync_values() -> void:
	_applying = true
	for action_value in _rows:
		var action := StringName(action_value)
		var row := _rows[action_value] as Dictionary
		var option := row.get("option") as OptionButton
		var note := row.get("note") as Label
		var stored := _stored_clip(action)
		option.clear()
		option.add_item(NO_CLIP_TEXT, 0)
		option.set_item_metadata(0, &"")
		var selected_index := 0
		for clip in _available_clips:
			option.add_item(str(clip))
			option.set_item_metadata(option.item_count - 1, clip)
			if clip == stored:
				selected_index = option.item_count - 1
		if stored != &"" and selected_index == 0:
			# Clip enregistré mais absent du modèle : on le montre au lieu de
			# le faire disparaître sans prévenir.
			option.add_item("%s (introuvable)" % stored)
			option.set_item_metadata(option.item_count - 1, stored)
			selected_index = option.item_count - 1
			note.text = "Cette animation n’existe pas dans le modèle 3D de ce personnage."
			note.add_theme_color_override("font_color", WARNING_COLOR)
			note.visible = true
		elif stored == &"":
			note.text = "Aucun choix : le personnage garde l’animation prévue par défaut."
			note.add_theme_color_override("font_color", MUTED_COLOR)
			note.visible = true
		else:
			note.visible = false
		option.select(selected_index)
	_applying = false
	_update_play_button()


func _stored_clip(action: StringName) -> StringName:
	if _unit == null or _unit.animation_set == null:
		return &""
	return _unit.animation_set.get_animation_name(action)


# ============================================================
# Interactions
# ============================================================

func _on_event_selected(index: int) -> void:
	_select_event(index, true)


func _on_clip_selected(item_index: int, action: StringName, option: OptionButton) -> void:
	if _applying:
		return
	var clip := StringName(option.get_item_metadata(item_index))
	if clip == _stored_clip(action):
		return
	var event_index := _index_of(action)
	if event_index >= 0:
		_select_event(event_index, false)
	clip_change_requested.emit(action, clip, _label_for(action))
	if clip != &"":
		preview.play_clip(clip)
	else:
		preview.stop_clip()
	_update_play_button()


func _select_event(index: int, play: bool) -> void:
	_selected_event = clampi(index, 0, maxi(0, CharacterVisual3D.ACTION_ORDER.size() - 1))
	if event_list.item_count > _selected_event:
		event_list.select(_selected_event)
	var action := _action_at(_selected_event)
	for action_value in _rows:
		var row := _rows[action_value] as Dictionary
		var title := row.get("title") as Label
		if StringName(action_value) == action:
			title.add_theme_color_override("font_color", ACCENT_COLOR)
		else:
			title.remove_theme_color_override("font_color")
	_update_caption()
	_update_play_button()
	if play:
		_play_selected()


func _play_selected() -> void:
	var clip := _stored_clip(_action_at(_selected_event))
	if clip == &"" or _unit == null:
		preview.stop_clip()
		return
	preview.play_clip(clip)


func _update_caption() -> void:
	if _unit == null:
		preview_caption.text = "Aucun personnage"
		return
	preview_caption.text = "%s · %s" % [
		_unit.unit_name, _label_for(_action_at(_selected_event))
	]


func _update_play_button() -> void:
	var clip := _stored_clip(_action_at(_selected_event))
	play_button.disabled = _unit == null or clip == &"" \
		or not preview.has_clip(clip)


func _action_at(index: int) -> StringName:
	var actions := CharacterVisual3D.ACTION_ORDER
	if actions.is_empty():
		return &""
	return actions[clampi(index, 0, actions.size() - 1)]


func _index_of(action: StringName) -> int:
	return CharacterVisual3D.ACTION_ORDER.find(action)


func _label_for(action: StringName) -> String:
	return str(EVENT_LABELS.get(action, str(action)))
