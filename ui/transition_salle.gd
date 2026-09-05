# ui/transition_salle.gd
extends Control

@onready var fond_image: TextureRect = $FondImage
@onready var nom_salle: Label = $Contenu/Nomsalle
@onready var description: Label = $Contenu/Description
@onready var bouton: Button = $Contenu/BoutonContinuer
@onready var heroes_container: HBoxContainer = $Contenu/Heroes

func _ready() -> void:
	var room: RoomData = GameManager.get_current_room()
	if room == null:
		return
	nom_salle.text = room.room_name
	description.text = ""
	if room.background_image != null:
		fond_image.texture = room.background_image
	if room.particles_scene != null:
		var particles = room.particles_scene.instantiate()
		add_child(particles)
	_build_heroes_display()
	_build_champion_preparation()
	bouton.pressed.connect(GameManager.start_next_battle)

func _build_heroes_display() -> void:
	for hero in GameManager.get_living_heroes():
		var vbox := VBoxContainer.new()

		var label := Label.new()
		label.text = hero.unit_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = hero.get_hp_ratio()
		bar.custom_minimum_size = Vector2(120, 20)
		vbox.add_child(bar)

		heroes_container.add_child(vbox)


func _build_champion_preparation() -> void:
	var encounter := GameManager.get_current_encounter_definition()
	var states := GameManager.get_ordered_character_states()
	if states.is_empty() or not states[0].uses_champion_progression():
		return
	var state := states[0]
	description.text = "Niveau %d · %d PV · %d Prouesse\nVictoire : %d XP de champion" % [
		state.champion_progression.current_level, state.unit.max_hp.get_int(),
		state.unit.attack_power.get_int(), encounter.base_xp if encounter != null else 0]
	var prepare := Button.new()
	prepare.text = "CARACTÉRISTIQUES & DOCTRINES"
	prepare.pressed.connect(func() -> void:
		var scene := load("res://ui/progression/screens/skill_tree_screen.tscn") as PackedScene
		if scene == null:
			return
		var codex = scene.instantiate()
		add_child(codex)
		codex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		codex.screen_closed.connect(codex.queue_free)
		codex.open_for_character(state.character_id, GameManager)
	)
	$Contenu.add_child(prepare)
	$Contenu.move_child(prepare, bouton.get_index())
	if encounter == null or encounter.glory_challenge == null:
		return
	var challenge := encounter.glory_challenge
	var choice := CheckButton.new()
	choice.text = "%s · +30 %% XP" % challenge.display_name
	choice.tooltip_text = challenge.description + " En cas d’échec, l’XP de base reste acquise après victoire."
	choice.button_pressed = bool(GameManager.get_current_glory_challenge_state().get("accepted", false))
	choice.toggled.connect(func(accepted: bool) -> void:
		GameManager.set_current_glory_challenge_accepted(accepted)
	)
	$Contenu.add_child(choice)
	$Contenu.move_child(choice, bouton.get_index())
