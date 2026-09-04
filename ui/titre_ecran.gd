extends Node2D

@onready var fond: Node2D = $Fond
@onready var couche_effets: Node2D = $Fond/CoucheEffets
@onready var couche_personnages: Node2D = $Fond/CouchePersonnages
@onready var logo: TextureRect = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const START_HUB_SCENE_PATH := "res://hub/StartHub.tscn"
const REFERENCE_VIEWPORT := Vector2(1200.0, 896.0)

var _intro_en_cours: bool = true


func _ready() -> void:
	PremiumUI.apply(boutons)
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_quitter.pressed.connect(_on_quitter)
	animation_player.animation_finished.connect(_on_intro_terminee)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_configure_focus_navigation()
	_apply_responsive_layout()
	animation_player.play("intro")


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_en_cours:
		return
	var touche_pressee: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if touche_pressee:
		get_viewport().set_input_as_handled()
		var animation_intro: Animation = animation_player.get_animation(&"intro")
		animation_player.seek(animation_intro.length, true)
		_on_intro_terminee(&"intro")


func _on_intro_terminee(anim_name: StringName) -> void:
	if anim_name == "intro":
		_intro_en_cours = false
		animation_player.play("idle")
		bouton_nouvelle_partie.grab_focus.call_deferred()


func _on_nouvelle_partie() -> void:
	GameManager.cleanup_run_state()
	get_tree().change_scene_to_file(START_HUB_SCENE_PATH)


func _on_quitter() -> void:
	get_tree().quit()


func _configure_focus_navigation() -> void:
	bouton_nouvelle_partie.focus_neighbor_top = (
		bouton_nouvelle_partie.get_path_to(bouton_quitter)
	)
	bouton_nouvelle_partie.focus_neighbor_bottom = (
		bouton_nouvelle_partie.get_path_to(bouton_quitter)
	)
	bouton_quitter.focus_neighbor_top = (
		bouton_quitter.get_path_to(bouton_nouvelle_partie)
	)
	bouton_quitter.focus_neighbor_bottom = (
		bouton_quitter.get_path_to(bouton_nouvelle_partie)
	)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	fond.scale = viewport_size / REFERENCE_VIEWPORT
	var left := clampf(viewport_size.x * 0.045, 42.0, 88.0)
	var width := clampf(viewport_size.x * 0.3, 360.0, 460.0)
	var top := clampf(viewport_size.y * 0.135, 104.0, 176.0)
	boutons.offset_left = left
	boutons.offset_right = left + width
	boutons.offset_top = top
	boutons.offset_bottom = top + 190.0
