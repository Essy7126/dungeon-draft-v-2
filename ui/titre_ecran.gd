extends Node2D

@onready var fond: Node2D = $Fond
@onready var couche_effets: Node2D = $Fond/CoucheEffets
@onready var couche_personnages: Node2D = $Fond/CouchePersonnages
@onready var logo: TextureRect = $UI/Logo
@onready var boutons: VBoxContainer = $UI/Boutons
@onready var bouton_trio_fixe: Button = $UI/Boutons/BoutonTrioFixe
@onready var bouton_prototype_elfe: Button = $UI/Boutons/BoutonPrototypeElfe
@onready var bouton_validation_equipe: Button = $UI/Boutons/BoutonValidationEquipe
@onready var bouton_nouvelle_partie: Button = $UI/Boutons/BoutonNouvellePartie
@onready var bouton_continuer: Button = $UI/Boutons/BoutonContinuer
@onready var bouton_quitter: Button = $UI/Boutons/BoutonQuitter
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _run_default: RunData = preload("res://data/runs/run_default.tres")
var _elf_prototype_run: RunData = preload("res://data/runs/elf_prototype_run.tres")
var _three_character_validation_run: RunData = preload(
	"res://data/runs/three_character_validation_run.tres"
)
const PARTY_PRESENTATION_SCREEN_PATH := "res://ui/party/PartyPresentationScreen.tscn"

var _intro_en_cours: bool = true


func _ready() -> void:
	bouton_trio_fixe.pressed.connect(_on_trio_fixe)
	bouton_prototype_elfe.pressed.connect(_on_prototype_elfe)
	bouton_validation_equipe.visible = OS.is_debug_build()
	bouton_validation_equipe.pressed.connect(_on_validation_equipe)
	bouton_nouvelle_partie.pressed.connect(_on_nouvelle_partie)
	bouton_continuer.pressed.connect(_on_continuer)
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
	GameManager.start_run(_run_default)


func _on_trio_fixe() -> void:
	get_tree().change_scene_to_file(PARTY_PRESENTATION_SCREEN_PATH)

func _on_prototype_elfe() -> void:
	GameManager.start_preconfigured_run(
		_elf_prototype_run,
		[GameManager.ELF_DATA_PATH]
	)


func _on_validation_equipe() -> void:
	GameManager.start_preconfigured_run(
		_three_character_validation_run,
		[
			GameManager.ELF_DATA_PATH,
			GameManager.GUARDIAN_DATA_PATH,
			GameManager.WARRIOR_DATA_PATH,
		]
	)


func _on_continuer() -> void:
	pass


func _on_quitter() -> void:
	get_tree().quit()
