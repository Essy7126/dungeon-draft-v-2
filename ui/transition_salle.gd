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
