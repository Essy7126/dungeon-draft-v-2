extends Node2D

@onready var fond: Node2D = $Fond
@onready var couche_effets: Node2D = $Fond/CoucheEffets
@onready var couche_personnages: Node2D = $Fond/CouchePersonnages
@onready var logo: TextureRect = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const CHARACTER_SELECTION_SCENE_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"
const REFERENCE_VIEWPORT := Vector2(1200.0, 896.0)
const MENU_ART := preload("res://ui/expedition/catabase_ui_theme.gd")

var _intro_en_cours: bool = true
var _resume_button: Button
var _sanctuary_button: Button
var _skip_hint: Label
var _notice: Label


func _ready() -> void:
	if FileAccess.file_exists(GameManager.expedition_save_path):
		_resume_button = DarkMenuButton.new()
		_resume_button.minimum_button_size = Vector2(0, 58)
		_resume_button.name = "BoutonReprendreCatabase"
		_resume_button.text = "Reprendre Catabase"
		_resume_button.theme_type_variation = &"PremiumPrimaryButton"
		_resume_button.icon = MENU_ART.icon("nav", "continue")
		_resume_button.expand_icon = true
		_resume_button.add_theme_constant_override("icon_max_width", 24)
		boutons.add_child(_resume_button)
		boutons.move_child(_resume_button, 1)
		bouton_nouvelle_partie.text = "Nouvelle aventure"
		bouton_nouvelle_partie.theme_type_variation = &"PremiumButton"
		bouton_nouvelle_partie.tooltip_text = "Choisir un héros. Votre partie actuelle reste disponible."
		_resume_button.pressed.connect(func():
			if not GameManager.resume_expedition():
				_notice.text = "Cette partie ne peut pas être reprise. Sa sauvegarde a été conservée."
				_notice.show()
				_apply_responsive_layout.call_deferred()
		)
	_sanctuary_button = DarkMenuButton.new()
	_sanctuary_button.name = "BoutonSanctuaire"
	_sanctuary_button.minimum_button_size = Vector2(0, 52)
	_sanctuary_button.text = "Le Sanctuaire"
	_sanctuary_button.theme_type_variation = &"PremiumButton"
	_sanctuary_button.tooltip_text = "Retrouver le refuge, puis partir ou reprendre Catabase."
	boutons.add_child(_sanctuary_button)
	boutons.move_child(_sanctuary_button, boutons.get_child_count() - 2)
	_sanctuary_button.pressed.connect(_open_sanctuary)
	_notice = Label.new()
	_notice.name = "MenuNotice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_font_size_override("font_size", 16)
	_notice.add_theme_color_override("font_color", Color("f1c99b"))
	_notice.hide()
	boutons.add_child(_notice)
	_skip_hint = Label.new()
	_skip_hint.name = "IntroSkipHint"
	_skip_hint.text = "Cliquer ou appuyer sur une touche pour continuer"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.add_theme_color_override("font_color", Color("f3ead7"))
	_skip_hint.add_theme_color_override("font_outline_color", Color("181513"))
	_skip_hint.add_theme_constant_override("outline_size", 4)
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_skip_hint)
	PremiumUI.apply(boutons)
	var eyebrow := boutons.get_node("MenuEyebrow") as Label
	eyebrow.add_theme_color_override("font_color", Color("f3ead7"))
	eyebrow.add_theme_font_size_override("font_size", 17)
	eyebrow.add_theme_color_override("font_outline_color", Color("181513"))
	eyebrow.add_theme_constant_override("outline_size", 4)
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_quitter.pressed.connect(_on_quitter)
	animation_player.animation_finished.connect(_on_intro_terminee)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_configure_focus_navigation()
	for child in boutons.get_children():
		if child is Button:
			child.disabled = true
			child.add_theme_font_size_override("font_size", 20)
		if child is DarkMenuButton:
			child.set_reduced_motion(GameManager.is_reduced_motion_enabled())
	_apply_responsive_layout()
	animation_player.play("intro")
	if GameManager.is_reduced_motion_enabled():
		_finish_intro()
	_apply_responsive_layout.call_deferred()


func _input(event: InputEvent) -> void:
	if not _intro_en_cours:
		return
	var touche_pressee: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if touche_pressee:
		get_viewport().set_input_as_handled()
		_finish_intro()


func _finish_intro() -> void:
	if not _intro_en_cours:
		return
	var animation_intro: Animation = animation_player.get_animation(&"intro")
	animation_player.seek(animation_intro.length, true)
	_on_intro_terminee(&"intro")


func _on_intro_terminee(anim_name: StringName) -> void:
	if anim_name == "intro":
		_intro_en_cours = false
		animation_player.play("idle")
		_skip_hint.hide()
		for child in boutons.get_children():
			if child is Button:
				child.disabled = false
		_focus_first_action.call_deferred()


func _focus_first_action() -> void:
	if not is_inside_tree():
		return
	var first: Button = _resume_button if is_instance_valid(_resume_button) else bouton_nouvelle_partie
	if is_instance_valid(first) and first.is_inside_tree() and first.is_visible_in_tree() and not first.disabled:
		first.grab_focus()


func _on_nouvelle_partie() -> void:
	GameManager.cancel_expedition_replacement()
	GameManager.cleanup_run_state()
	get_tree().change_scene_to_file(CHARACTER_SELECTION_SCENE_PATH)


func _open_sanctuary() -> void:
	GameManager.cancel_expedition_replacement()
	var result := GameManager.open_sanctuary()
	if not bool(result.get("success", false)):
		_notice.text = str(result.get("message", "Le Sanctuaire est indisponible."))
		_notice.show()
		_apply_responsive_layout.call_deferred()


func _on_quitter() -> void:
	get_tree().quit()


func _configure_focus_navigation() -> void:
	var actions: Array[Button] = []
	for child in boutons.get_children():
		if child is Button:
			actions.append(child)
	for index in actions.size():
		var button := actions[index]
		button.focus_neighbor_top = button.get_path_to(actions[posmod(index - 1, actions.size())])
		button.focus_neighbor_bottom = button.get_path_to(actions[(index + 1) % actions.size()])


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var backdrop_scale := maxf(viewport_size.x / REFERENCE_VIEWPORT.x, viewport_size.y / REFERENCE_VIEWPORT.y)
	fond.scale = Vector2.ONE * backdrop_scale
	fond.position = (viewport_size - REFERENCE_VIEWPORT * backdrop_scale) * 0.5
	var left := clampf(viewport_size.x * 0.045, 32.0, 88.0)
	var width := minf(clampf(viewport_size.x * 0.32, 360.0, 460.0), viewport_size.x - left * 2.0)
	var menu_height := maxf(boutons.get_combined_minimum_size().y, 190.0)
	var bottom := clampf(viewport_size.y * 0.09, 44.0, 96.0)
	boutons.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	boutons.position = Vector2(left, maxf(260.0, viewport_size.y - bottom - menu_height))
	boutons.size = Vector2(width, menu_height)
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	logo.custom_minimum_size = Vector2.ZERO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var logo_width := minf(820.0, viewport_size.x * 0.62)
	logo.size = Vector2(logo_width, minf(300.0, viewport_size.y * 0.28))
	logo.position = Vector2((viewport_size.x - logo_width) * 0.5, 24.0)
	if _skip_hint != null:
		_skip_hint.position = Vector2(24.0, viewport_size.y - 36.0)
		_skip_hint.size = Vector2(viewport_size.x - 48.0, 24.0)
