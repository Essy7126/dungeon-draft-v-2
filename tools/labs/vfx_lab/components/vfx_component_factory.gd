extends RefCounted

const ParticleBurst = preload("res://tools/labs/vfx_lab/components/procedural_particle_burst.gd")
const PulseRing = preload("res://tools/labs/vfx_lab/components/procedural_pulse_ring.gd")
const TrailRibbon = preload("res://tools/labs/vfx_lab/components/procedural_trail_ribbon.gd")
const LightningBolt = preload("res://tools/labs/vfx_lab/components/procedural_lightning_bolt.gd")


static func add_particles(parent: Node, position: Vector2, config: Dictionary) -> Node2D:
	var particles := ParticleBurst.new() as Node2D
	particles.position = position
	parent.add_child(particles)
	particles.call("configure", config)
	return particles


static func add_ring(parent: Node, position: Vector2, config: Dictionary) -> Node2D:
	var ring := PulseRing.new() as Node2D
	ring.position = position
	parent.add_child(ring)
	ring.call("configure", config)
	return ring


static func add_trail(parent: Node, config: Dictionary) -> Node2D:
	var trail := TrailRibbon.new() as Node2D
	parent.add_child(trail)
	trail.call("configure", config)
	return trail


static func add_lightning(
		parent: Node,
		from: Vector2,
		to: Vector2,
		config: Dictionary
) -> Node2D:
	var bolt := LightningBolt.new() as Node2D
	parent.add_child(bolt)
	bolt.call("configure", from, to, config)
	return bolt


static func add_shader_rect(
		parent: Node,
		position: Vector2,
		size: Vector2,
		shader: Shader,
		parameters: Dictionary = {}
) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = position - size * 0.5
	rect.size = size
	var material := ShaderMaterial.new()
	material.shader = shader
	for key in parameters:
		material.set_shader_parameter(key, parameters[key])
	rect.material = material
	parent.add_child(rect)
	return rect
