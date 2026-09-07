# battle/impact_juice.gd
# ============================================================
# IMPACT JUICE — Hit-stop + shake, UNIQUEMENT sur les moments signature :
#   - collision en chaine (EventBus.collision_impact)
#   - mort par terrain-hasard (EventBus.hazard_kill)
# Jamais sur les frappes normales : la juice marque l'exception, pas la
# routine. Composant autonome (instancie par battle.tscn), zero couplage.
#
# Hit-stop : Engine.time_scale = 0 pendant FREEZE_TIME, restauration par un
# Les tweens de l'UI sont figes ~60 ms — imperceptible et voulu.
# Shake : offset de camera pilote en temps REEL (ticks), amorti lineairement,
# donc insensible au time_scale du hit-stop.
#
# Interrupteur global : ImpactJuice.juice_enabled (case a cocher dans le
# DebugOverlay — accessibilite / debug).
# ============================================================

class_name ImpactJuice
extends Node

static var juice_enabled: bool = true

const FREEZE_TIME := 0.06      # duree du gel (s, temps reel)
const SHAKE_TIME := 0.15       # duree du shake (s, temps reel)
const SHAKE_AMPLITUDE := 4.0   # px au depart, amorti jusqu'a 0

var _shake_until_ms: int = 0
var _restoring_scale: bool = false

func _ready() -> void:
	EventBus.collision_impact.connect(_on_collision_impact)
	EventBus.hazard_kill.connect(_on_hazard_kill)
	set_process(false)

func _on_collision_impact(_attacker, _victim, _damage: int) -> void:
	_punch()

func _on_hazard_kill(_unit, _effect_name: String) -> void:
	_punch()

func _punch() -> void:
	if not juice_enabled or not is_inside_tree():
		return
	_freeze()
	_start_shake()

func _freeze() -> void:
	if _restoring_scale:
		return # un gel est deja en cours : on ne reempile pas
	_restoring_scale = true
	Engine.time_scale = 0.0
	# ignore_time_scale = true : le timer tourne en temps reel malgre le gel.
	var timer := get_tree().create_timer(FREEZE_TIME, true, false, true)
	timer.timeout.connect(func () -> void:
		Engine.time_scale = 1.0
		_restoring_scale = false)

func _start_shake() -> void:
	_shake_until_ms = Time.get_ticks_msec() + int(SHAKE_TIME * 1000.0)
	set_process(true)

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var remaining := _shake_until_ms - Time.get_ticks_msec()
	if camera == null or remaining <= 0:
		if camera != null:
			camera.offset = Vector2.ZERO
		set_process(false)
		return
	# Amplitude amortie lineairement sur la duree du shake.
	var strength := SHAKE_AMPLITUDE * (float(remaining) / (SHAKE_TIME * 1000.0))
	camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
