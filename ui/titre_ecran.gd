extends Node2D
## Catabase's living painting. The UI stays still while the atmosphere breathes.

const CHARACTER_SELECTION_SCENE_PATH := "res://ui/selection/CharacterSelectionScreen.tscn"
const HEADING := preload("res://asset/ui/character_selection/selection_title_font.tres")
const BODY := preload(
	"res://asset/ui/recraft_hud_v1/fonts/atkinson_hyperlegible/AtkinsonHyperlegible-Regular.otf"
)
const GOLD := Color("c6a16a")

@onready var fond: TextureRect = $Fond
@onready var logo: Label = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter

var _intro_en_cours := false
var _resume_button: Button
var _sanctuary_button: Button
var _notice: Label
var _motion_toggle: CheckButton
var _edition: Label
var _entry_tween: Tween
var _elapsed := 0.0
var _pointer := Vector2.ZERO
var _music_controls: PanelContainer


func _ready() -> void:
	# Keep the existing project/user-data identity so saved games stay discoverable.
	DisplayServer.window_set_title("Catabase")
	if FileAccess.file_exists(GameManager.expedition_save_path):
		_resume_button = Button.new()
		_resume_button.name = "BoutonReprendreCatabase"
		_resume_button.text = "Continuer"
		boutons.add_child(_resume_button)
		boutons.move_child(_resume_button, 1)
		_resume_button.pressed.connect(
			func():
				if not GameManager.resume_expedition():
					_notice.text = "Cette partie ne peut pas être reprise. Sa sauvegarde a été conservée."
					_notice.show()
					_apply_responsive_layout.call_deferred(),
		)
	bouton_nouvelle_partie.tooltip_text = "Préparer la descente d’Achille. Votre sauvegarde reste disponible."
	_sanctuary_button = Button.new()
	_sanctuary_button.name = "BoutonSanctuaire"
	_sanctuary_button.text = "Le Sanctuaire"
	_sanctuary_button.tooltip_text = "Retrouver le refuge, puis partir ou reprendre Catabase."
	boutons.add_child(_sanctuary_button)
	boutons.move_child(_sanctuary_button, boutons.get_child_count() - 2)
	_sanctuary_button.pressed.connect(_open_sanctuary)
	_notice = Label.new()
	_notice.name = "MenuNotice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Color("f1c99b"))
	_notice.hide()
	boutons.add_child(_notice)
	_motion_toggle = CheckButton.new()
	_motion_toggle.name = "AnimateBackdrop"
	_motion_toggle.text = "Animer le décor"
	_motion_toggle.tooltip_text = "Caméra, brume et lumières. Désactiver réduit aussi les animations du jeu."
	_motion_toggle.add_theme_font_override("font", BODY)
	_motion_toggle.add_theme_color_override("font_color", Color("b9b8ac"))
	_motion_toggle.toggled.connect(
		func(enabled: bool):
			GameManager.set_reduced_motion_enabled(not enabled),
	)
	$UI.add_child(_motion_toggle)
	_edition = Label.new()
	_edition.text = "VERSION EN DÉVELOPPEMENT"
	_edition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_edition.add_theme_font_override("font", BODY)
	_edition.add_theme_color_override("font_color", Color("999b91"))
	$UI.add_child(_edition)
	_music_controls = preload("res://ui/menus/title_music_controls.gd").new()
	_music_controls.name = "TitleMusicControls"
	_music_controls.soundtrack = $AudioStreamPlayer
	$UI.add_child(_music_controls)
	for label: Label in [logo, $UI/Subtitle, $UI/Boutons/MenuEyebrow]:
		label.add_theme_font_override("font", HEADING)
		label.add_theme_color_override("font_color", GOLD)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_y", 3)
	logo.add_theme_color_override("font_color", Color("e3c58e"))
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_quitter.pressed.connect(_on_quitter)
	GameManager.reduced_motion_changed.connect(_sync_motion)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_sync_motion(GameManager.is_reduced_motion_enabled())
	_apply_responsive_layout()
	_configure_focus_navigation()
	_focus_first_action.call_deferred()
	if not GameManager.is_reduced_motion_enabled():
		# Immediate interaction; the short fade never gates the player's buttons.
		boutons.modulate.a = 0.0
		_entry_tween = create_tween()
		_entry_tween.tween_property(boutons, "modulate:a", 1.0, 0.65)
	_apply_responsive_layout.call_deferred()


func _process(delta: float) -> void:
	_elapsed += minf(delta, 0.1)
	var viewport_size := get_viewport_rect().size
	var target := (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)) * 2.0
	target = target.clamp(Vector2(-1, -1), Vector2.ONE)
	_pointer = _pointer.lerp(target, 1.0 - exp(-delta * 1.5))
	var painting := fond.material as ShaderMaterial
	painting.set_shader_parameter("elapsed", _elapsed)
	painting.set_shader_parameter("pointer_offset", _pointer)


func _sync_motion(reduced: bool) -> void:
	set_process(not reduced)
	_motion_toggle.set_pressed_no_signal(not reduced)
	if reduced:
		_finish_intro()


func _finish_intro() -> void:
	if _entry_tween != null and _entry_tween.is_valid():
		_entry_tween.kill()
	boutons.modulate.a = 1.0
	_intro_en_cours = false


func _focus_first_action() -> void:
	if not is_inside_tree():
		return
	var first: Button = _resume_button if is_instance_valid(_resume_button) else bouton_nouvelle_partie
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
	var actions: Array[Control] = []
	for child in boutons.get_children():
		if child is Button:
			actions.append(child)
	actions.append(_motion_toggle)
	actions.append_array(_music_controls.focus_controls())
	for index in actions.size():
		var button := actions[index]
		button.focus_neighbor_top = button.get_path_to(actions[posmod(index - 1, actions.size())])
		button.focus_neighbor_bottom = button.get_path_to(actions[(index + 1) % actions.size()])


func _button_style(fill: Color, border: Color, scale_factor: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(1.5 * scale_factor)))
	style.set_corner_radius_all(roundi(4 * scale_factor))
	style.corner_detail = 1
	style.content_margin_left = 20 * scale_factor
	style.content_margin_right = 20 * scale_factor
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = roundi(5 * scale_factor)
	return style


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	fond.size = viewport_size
	(fond.material as ShaderMaterial).set_shader_parameter("viewport_size", viewport_size)
	var s := minf(viewport_size.x / 1600.0, viewport_size.y / 900.0)
	var origin := Vector2(
		maxf(0.0, (viewport_size.x - 1600 * s) * 0.12),
		(viewport_size.y - 900 * s) * 0.5,
	)
	logo.position = origin + Vector2(46, 170) * s
	logo.size = Vector2(600, 110) * s
	logo.add_theme_font_size_override("font_size", roundi(80 * s))
	$UI/Subtitle.position = origin + Vector2(46, 280) * s
	$UI/Subtitle.size = Vector2(600, 34) * s
	$UI/Subtitle.add_theme_font_size_override("font_size", roundi(14 * s))
	boutons.add_theme_constant_override("separation", roundi(16 * s))
	boutons.position = origin + Vector2(174, 435) * s
	boutons.size = Vector2(344, 0) * s
	$UI/Boutons/MenuEyebrow.add_theme_font_size_override("font_size", roundi(12 * s))
	$UI/Boutons/MenuEyebrow.custom_minimum_size.y = 35 * s
	for child in boutons.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0, 49) * s
			child.add_theme_font_override("font", HEADING)
			child.add_theme_font_size_override("font_size", roundi(20 * s))
			child.add_theme_color_override("font_color", Color("e3d8bd"))
			child.add_theme_color_override("font_hover_color", Color("fff0cc"))
			child.add_theme_color_override("font_focus_color", Color("fff0cc"))
			child.add_theme_color_override("font_pressed_color", Color("fff0cc"))
			child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			child.add_theme_stylebox_override(
				"normal",
				_button_style(Color(0.035, 0.055, 0.058, 0.88), Color("6e5940"), s),
			)
			child.add_theme_stylebox_override("hover", _button_style(Color("163c40"), GOLD, s))
			child.add_theme_stylebox_override(
				"pressed",
				_button_style(Color("09262b"), Color("f0d59b"), s),
			)
			var focus := _button_style(Color(0.06, 0.22, 0.25, 0.7), GOLD, s)
			child.add_theme_stylebox_override("focus", focus)
	_notice.add_theme_font_size_override("font_size", roundi(16 * s))
	_motion_toggle.position = Vector2(38 * s, viewport_size.y - 60 * s)
	_motion_toggle.add_theme_font_size_override("font_size", roundi(16 * s))
	_motion_toggle.size = Vector2(220, 42) * s
	_edition.position = Vector2(viewport_size.x - 365 * s, viewport_size.y - 47 * s)
	_edition.size = Vector2(325, 28) * s
	_edition.add_theme_font_size_override("font_size", roundi(12 * s))
	_music_controls.apply_layout(viewport_size, s)
