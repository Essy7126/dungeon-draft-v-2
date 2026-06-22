extends Node2D

@onready var fond: Node2D = $Fond
@onready var couche_effets: Node2D = $Fond/CoucheEffets
@onready var couche_personnages: Node2D = $Fond/CouchePersonnages
@onready var logo: TextureRect = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_continuer: Button = $UI/Boutons/BoutonContinuer
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fumee_shader: Node2D = $Fond/FumeeShader

var _run_default: RunData = preload("res://data/runs/run_default.tres")


func _ready() -> void:
	fumee_shader.modulate.a = 0.0
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_continuer.pressed.connect(_on_continuer)
	bouton_quitter.pressed.connect(_on_quitter)
	animation_player.animation_finished.connect(_on_intro_terminee)
	animation_player.play("intro")


func _on_intro_terminee(anim_name: StringName) -> void:
	if anim_name == "intro":
		animation_player.play("idle")


func _on_nouvelle_partie() -> void:
	GameManager.start_run(_run_default)


func _on_continuer() -> void:
	pass


func _on_quitter() -> void:
	get_tree().quit()
