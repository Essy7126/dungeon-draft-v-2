class_name SkillEvolutionCard
extends Control

signal choice_requested(upgrade_id: StringName)
signal hover_changed(card_index: int, hovered: bool)

const CARD_SHADER := preload("res://ui/post_combat/shaders/reward_card.gdshader")
const CONTENT_PADDING := 10
const FALLBACK_ASPECT := 0.62

@onready var floating_root: Control = %FloatingRoot
@onready var visual_root: Control = %VisualRoot
@onready var back_glow: TextureRect = %BackGlow
@onready var card_shadow: TextureRect = %CardShadow
@onready var card_texture: TextureRect = %CardTexture
@onready var fallback: PanelContainer = %Fallback
@onready var fallback_title: Label = %FallbackTitle
@onready var fallback_description: Label = %FallbackDescription
@onready var selection_badge: Label = %SelectionBadge
@onready var particles: GPUParticles2D = %Particles
@onready var interaction: Button = %Interaction

var upgrade_id: StringName = &""
var card_index := 0
var reduced_motion := false
var upgrade: SkillUpgradeData = null
var _selected := false
var _peer_dimmed := false
var _hovered := false
var _focused := false
var _locked := false
var _rest_rotation := 0.0
var _state_y := 0.0
var _float_phase := 0.0
var _elapsed := 0.0
var _material: ShaderMaterial = null
var _state_tween: Tween = null
var _entrance_tween: Tween = null
var _visible_texture: Texture2D = null

static var _crop_cache: Dictionary = {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interaction.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	interaction.pressed.connect(_on_pressed)
	interaction.mouse_entered.connect(_on_mouse_entered)
	interaction.mouse_exited.connect(_on_mouse_exited)
	interaction.focus_entered.connect(_on_focus_entered)
	interaction.focus_exited.connect(_on_focus_exited)
	resized.connect(_update_geometry)
	_update_geometry()
	set_process(true)


func configure(
		wanted_upgrade: SkillUpgradeData,
		index: int,
		use_reduced_motion: bool
	) -> void:
	upgrade = wanted_upgrade
	upgrade_id = upgrade.upgrade_id if upgrade != null else &""
	card_index = index
	reduced_motion = use_reduced_motion
	_rest_rotation = -1.5 if index == 0 else 1.5
	_float_phase = float(index) * PI
	var source := upgrade.get_card_texture() if upgrade != null else null
	_visible_texture = _crop_white_margins(source)
	card_texture.texture = _visible_texture
	card_shadow.texture = _visible_texture
	back_glow.texture = _visible_texture
	fallback.visible = _visible_texture == null
	card_texture.visible = _visible_texture != null
	card_shadow.visible = _visible_texture != null
	back_glow.visible = _visible_texture != null
	fallback_title.text = upgrade.display_name.to_upper() if upgrade != null else "ÉVOLUTION"
	fallback_description.text = upgrade.description if upgrade != null else "Visuel indisponible"
	interaction.tooltip_text = ""
	_material = ShaderMaterial.new()
	_material.shader = CARD_SHADER
	_material.set_shader_parameter("outline_color", Color(0.48, 0.96, 0.55, 1.0))
	_material.set_shader_parameter("tint", Color(0.96, 1.04, 0.96, 1.0))
	card_texture.material = _material
	_refresh_state(false)


func get_card_aspect() -> float:
	if _visible_texture == null or _visible_texture.get_height() <= 0:
		return FALLBACK_ASPECT
	return float(_visible_texture.get_width()) / float(_visible_texture.get_height())


func set_card_height(card_height: float, maximum_width: float) -> void:
	var wanted_width := card_height * get_card_aspect()
	if wanted_width > maximum_width:
		wanted_width = maximum_width
		card_height = wanted_width / get_card_aspect()
	custom_minimum_size = Vector2(wanted_width, card_height)
	size = custom_minimum_size
	_update_geometry()


func set_selected(value: bool) -> void:
	_selected = value
	selection_badge.visible = value
	particles.emitting = value and not reduced_motion and not _locked
	_refresh_state(true)


func set_peer_dimmed(value: bool) -> void:
	_peer_dimmed = value
	_refresh_state(true)


func set_locked(value: bool) -> void:
	_locked = value
	interaction.disabled = value
	particles.emitting = _selected and not reduced_motion and not value


func is_selected() -> bool:
	return _selected


func grab_card_focus() -> void:
	interaction.grab_focus()


func set_focus_neighbors(left_path: NodePath, right_path: NodePath) -> void:
	interaction.focus_neighbor_left = left_path
	interaction.focus_neighbor_right = right_path


func play_entrance(delay: float) -> void:
	if reduced_motion:
		modulate.a = 1.0
		return
	modulate.a = 0.0
	visual_root.position.y = 48.0
	visual_root.scale = Vector2.ONE * 0.88
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(self, "modulate:a", 1.0, 0.46).set_delay(delay)
	_entrance_tween.tween_property(visual_root, "position:y", _state_y, 0.54) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(visual_root, "scale", Vector2.ONE, 0.54) \
		.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_confirmation(chosen: bool) -> void:
	set_locked(true)
	particles.emitting = chosen and not reduced_motion
	var duration := 0.18 if reduced_motion else 0.58
	var target_scale := Vector2.ONE * (1.11 if chosen else 0.91)
	var target_x := 0.0 if chosen else (-90.0 if card_index == 0 else 90.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "position:x", target_x, duration)
	tween.tween_property(self, "modulate:a", 0.0 if not chosen else 0.96, duration)
	if _material != null:
		_material.set_shader_parameter("sweep_intensity", 0.74 if chosen else 0.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _material != null and _selected and not reduced_motion:
		_material.set_shader_parameter("sweep_progress", fmod(_elapsed * 0.42, 1.8) - 0.35)
	if reduced_motion or _selected or _hovered or _focused or _locked:
		floating_root.position.y = 0.0
	else:
		floating_root.position.y = sin(_elapsed * 1.8 + _float_phase) * 3.0


func _refresh_state(animated: bool) -> void:
	if not is_node_ready():
		return
	var scale_value := 1.0
	var y_value := 0.0
	var rotation_value := _rest_rotation
	var brightness := 1.0
	var saturation := 1.0
	var outline := 0.0
	if _selected:
		scale_value = 1.085
		y_value = -24.0
		rotation_value = 0.0
		brightness = 1.08
		saturation = 1.06
		outline = 0.9
	elif _peer_dimmed:
		scale_value = 0.96
		y_value = 4.0
		rotation_value = _rest_rotation * 1.35
		brightness = 0.64
		saturation = 0.44
	elif _hovered or _focused:
		scale_value = 1.048
		y_value = -14.0
		rotation_value = 0.0
		brightness = 1.04
		outline = 0.36
	_state_y = y_value
	if animated and _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
		_entrance_tween = null
		modulate.a = 1.0
	if _material != null:
		_material.set_shader_parameter("brightness", brightness)
		_material.set_shader_parameter("saturation", saturation)
		_material.set_shader_parameter("outline_intensity", outline)
		_material.set_shader_parameter("selected_amount", 1.0 if _selected else 0.0)
		_material.set_shader_parameter("sweep_intensity", 0.3 if _selected and not reduced_motion else 0.0)
	back_glow.modulate.a = 0.46 if _selected else (0.16 if _hovered or _focused else 0.0)
	card_shadow.modulate.a = 0.72 if _selected else (0.58 if _hovered or _focused else 0.45)
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	if not animated or reduced_motion:
		visual_root.scale = Vector2.ONE * scale_value
		visual_root.position.y = y_value
		visual_root.rotation_degrees = rotation_value
		return
	_state_tween = create_tween().set_parallel(true)
	_state_tween.tween_property(visual_root, "scale", Vector2.ONE * scale_value, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(visual_root, "position:y", y_value, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(visual_root, "rotation_degrees", rotation_value, 0.15)


func _update_geometry() -> void:
	if not is_node_ready():
		return
	visual_root.pivot_offset = size * 0.5
	floating_root.pivot_offset = size * 0.5
	particles.position = size * 0.5


func _on_pressed() -> void:
	if not _locked:
		choice_requested.emit(upgrade_id)


func _on_mouse_entered() -> void:
	if _locked:
		return
	_hovered = true
	hover_changed.emit(card_index, true)
	_refresh_state(true)


func _on_mouse_exited() -> void:
	_hovered = false
	hover_changed.emit(card_index, false)
	_refresh_state(true)


func _on_focus_entered() -> void:
	_focused = true
	hover_changed.emit(card_index, true)
	_refresh_state(true)


func _on_focus_exited() -> void:
	_focused = false
	hover_changed.emit(card_index, false)
	_refresh_state(true)


func _crop_white_margins(source: Texture2D) -> Texture2D:
	if source == null:
		push_warning("Carte d’évolution absente pour %s." % upgrade_id)
		return null
	var cache_key := source.resource_path
	if not cache_key.is_empty() and _crop_cache.has(cache_key):
		return _crop_cache[cache_key]
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var used := _non_white_content_rect(image)
	var result: Texture2D = source
	if used.size.x > 0 and used.size.y > 0 \
			and used.size != Vector2i(image.get_width(), image.get_height()):
		var cropped := AtlasTexture.new()
		cropped.atlas = source
		cropped.region = Rect2(used)
		result = cropped
	if not cache_key.is_empty():
		_crop_cache[cache_key] = result
	return result


func _non_white_content_rect(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.01 or (pixel.r >= 0.94 and pixel.g >= 0.94 and pixel.b >= 0.94):
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x or maximum.y < minimum.y:
		return Rect2i()
	minimum -= Vector2i.ONE * CONTENT_PADDING
	maximum += Vector2i.ONE * CONTENT_PADDING
	minimum.x = maxi(0, minimum.x)
	minimum.y = maxi(0, minimum.y)
	maximum.x = mini(image.get_width() - 1, maximum.x)
	maximum.y = mini(image.get_height() - 1, maximum.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

