extends Node2D

## Vitesse du projectile en pixels/seconde
@export var speed: float = 600.0

## Direction normalisée (Vector2.RIGHT par défaut = vers la droite)
@export var direction: Vector2 = Vector2.RIGHT

## Dégâts infligés à l'impact (pour plus tard)
@export var damage: int = 30

## Durée de vie max en secondes (sécurité si rien n'est touché)
@export var lifetime: float = 4.0

var _timer: float = 0.0


func _ready() -> void:
	# Oriente visuellement le projectile selon la direction
	rotation = direction.angle()


func _process(delta: float) -> void:
	# Déplacement
	position += direction * speed * delta

	# Destruction automatique après lifetime secondes
	_timer += delta
	if _timer >= lifetime:
		_destroy()


func _on_body_entered(body: Node2D) -> void:
	# Appelé par un Area2D enfant quand on touche quelque chose
	# Tu peux appeler body.take_damage(damage) ici si l'ennemi a cette méthode
	_destroy()


func _destroy() -> void:
	# Stoppe l'émission de particules avant de supprimer le nœud
	for child in get_children():
		if child is GPUParticles2D:
			child.emitting = false

	# Attend que les dernières particules disparaissent (1.8s = lifetime smoke)
	await get_tree().create_timer(1.8).timeout
	queue_free()
