class_name PartyPresentationScreen
extends Control

const CARD_SCENE := preload("res://ui/party/CharacterPresentationCard.tscn")

signal run_requested(run_data: RunData, party_members: Array[UnitData])
signal back_requested

@export var run_data: RunData = null
@export var party_members: Array[UnitData] = []
@export_file("*.tscn") var return_scene_path := "res://ui/TitreEcran.tscn"

@onready var cards_container: HBoxContainer = $Background/Margin/Layout/Cards
@onready var start_button: Button = $Background/Margin/Layout/Buttons/Start
@onready var back_button: Button = $Background/Margin/Layout/Buttons/Back

var _cards: Array[CharacterPresentationCard] = []


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_rebuild_cards()
	start_button.disabled = run_data == null or party_members.is_empty()


func _exit_tree() -> void:
	_clear_cards()


func _rebuild_cards() -> void:
	_clear_cards()
	for member in party_members:
		if member == null:
			continue
		var card := CARD_SCENE.instantiate() as CharacterPresentationCard
		cards_container.add_child(card)
		card.configure(member)
		_cards.append(card)


func _clear_cards() -> void:
	for card in _cards:
		if not is_instance_valid(card):
			continue
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		card.free()
	_cards.clear()


func get_cards() -> Array[CharacterPresentationCard]:
	return _cards.duplicate()


func _on_start_pressed() -> void:
	start_with_manager(GameManager)


func start_with_manager(manager: Node) -> bool:
	if run_data == null or party_members.is_empty():
		return false
	if manager == null or not manager.has_method("start_preconfigured_run"):
		return false
	start_button.disabled = true
	var ordered_party: Array[UnitData] = []
	ordered_party.assign(party_members)
	run_requested.emit(run_data, ordered_party)
	manager.start_preconfigured_run(run_data, ordered_party)
	return true


func _on_back_pressed() -> void:
	request_back()


func request_back(navigate: bool = true) -> bool:
	back_requested.emit()
	_clear_cards()
	if navigate:
		get_tree().change_scene_to_file(return_scene_path)
	return true
