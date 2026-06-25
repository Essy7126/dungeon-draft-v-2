extends Node

# AudioManager — Autoload
# Responsabilité unique : toute la musique et les SFX du jeu.
# Survit aux changements de scène.

var _musique: AudioStreamPlayer
var _sfx: AudioStreamPlayer

func _ready() -> void:
	_musique = AudioStreamPlayer.new()
	_musique.name = "Musique"
	_musique.bus = "Master"
	add_child(_musique)

	_sfx = AudioStreamPlayer.new()
	_sfx.name = "SFX"
	_sfx.bus = "Master"
	add_child(_sfx)


func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _musique.stream == stream and _musique.playing:
		return
	_musique.stream = stream
	_musique.volume_db = volume_db
	_musique.play()


func stop_music() -> void:
	_musique.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	_sfx.stream = stream
	_sfx.volume_db = volume_db
	_sfx.play()


func set_music_volume(volume_db: float) -> void:
	_musique.volume_db = volume_db

func play_sfx_at(stream: AudioStream, pos: Vector2, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player = AudioStreamPlayer2D.new()
	get_tree().root.add_child(player)
	player.stream = stream
	player.volume_db = volume_db
	player.global_position = pos
	player.play()
	player.finished.connect(player.queue_free)
