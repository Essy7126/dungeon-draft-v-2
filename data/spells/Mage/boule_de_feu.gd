# battle/vfx/boule_de_feu.gd
extends Node2D

@export var vitesse_pixels_sec : float = 400.0

var _cible_monde : Vector2 = Vector2.ZERO
var _en_vol : bool = false

@onready var _lueur     : PointLight2D   = $Lueur
@onready var _smoke     : GPUParticles2D = $SmokeTrail
@onready var _fire      : GPUParticles2D = $FireTrail
@onready var _core      : GPUParticles2D = $FireballCore
@onready var _explosion : GPUParticles2D = $Explosion

func initialiser(depuis: Vector2, vers: Vector2) -> void:
	global_position = depuis
	_cible_monde    = vers
	_en_vol         = true
	var dir_vol := (vers - depuis).normalized()
	# Oriente la traînée et la fumée à l'opposé du sens de vol
	for trail in [_smoke, _fire]:
		trail.process_material = trail.process_material.duplicate()
		trail.process_material.direction = Vector3(-dir_vol.x, -dir_vol.y, 0.0)

func _physics_process(delta: float) -> void:
	if not _en_vol:
		return
	var dir := (_cible_monde - global_position)
	if dir.length() < 8.0:
		_arriver()
		return
	global_position += dir.normalized() * vitesse_pixels_sec * delta

func _arriver() -> void:
	_en_vol = false
	set_physics_process(false)
	_smoke.emitting = false
	_fire.emitting  = false
	_core.emitting  = false
	_lueur.energy   = 3.0
	_explosion.emitting = true

func _on_explosion_finished() -> void:
	queue_free()
