extends Node2D

@onready var fond: Node2D = $Fond
@onready var couche_effets: Node2D = $Fond/CoucheEffets
@onready var couche_personnages: Node2D = $Fond/CouchePersonnages
@onready var logo: TextureRect = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const PARTY_PRESENTATION_SCREEN_PATH := "res://ui/party/PartyPresentationScreen.tscn"

var _intro_en_cours: bool = true


func _ready() -> void:
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_quitter.pressed.connect(_on_quitter)
	animation_player.animation_finished.connect(_on_intro_terminee)
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


func _on_nouvelle_partie() -> void:
	get_tree().change_scene_to_file(PARTY_PRESENTATION_SCREEN_PATH)


func _on_quitter() -> void:
	get_tree().quit()
