class_name RewardCardChoice
extends Control
signal choice_requested(item_id: StringName)
signal hover_changed(card_index: int, hovered: bool)

const CONTENT_PADDING := 8

@onready var floating_root: Control = %FloatingRoot
@onready var visual_root: Control = %VisualRoot
@onready var back_glow: PanelContainer = %BackGlow
@onready var card_shadow: PanelContainer = %CardShadow
@onready var card_texture: TextureRect = %CardTexture
@onready var fallback: PanelContainer = %Fallback
@onready var fallback_margin: MarginContainer = $FloatingRoot/VisualRoot/Fallback/FallbackMargin
@onready var fallback_content: VBoxContainer = $FloatingRoot/VisualRoot/Fallback/FallbackMargin/FallbackContent
@onready var fallback_meta: Label = $FloatingRoot/VisualRoot/Fallback/FallbackMargin/FallbackContent/FallbackMeta
@onready var illustration_frame: PanelContainer = $FloatingRoot/VisualRoot/Fallback/FallbackMargin/FallbackContent/IllustrationFrame
@onready var fallback_icon: TextureRect = %FallbackIcon
@onready var fallback_title: Label = %FallbackTitle
@onready var fallback_description: Label = %FallbackDescription
@onready var fallback_footer: Label = %FallbackFooter
@onready var selection_badge: Label = %SelectionBadge
@onready var particles: GPUParticles2D = %Particles
@onready var interaction: Button = %Interaction

var item_id: StringName = &""
var card_index := 0
var reduced_motion := false
var _selected := false
var _peer_dimmed := false
var _hovered := false
var _focused := false
var _locked := false
var _rest_rotation := 0.0
var _state_y := 0.0
var _float_phase := 0.0
var _sweep_time := 0.0
var _material: ShaderMaterial = null
var _state_tween: Tween = null
var _entrance_tween: Tween = null
var _compact := false

static var _crop_cache: Dictionary = {}


func _ready() -> void:
	PremiumUI.apply(self)
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


func configure(option: Dictionary, index: int, use_reduced_motion: bool) -> void:
	card_index = index
	reduced_motion = use_reduced_motion
	var definition := option.get("definition") as ItemDefinition
	item_id = StringName(option.get("item_id", &""))
	_rest_rotation = -1.5 if index == 0 else 1.5
	_float_phase = float(index) * PI
	var visible_icon := InventoryItemTile.presentation_icon(definition)
	var reward_source := definition.get_reward_card_texture() if definition != null else null
	var visible_card := (
		_visible_card_texture(reward_source)
		if definition != null and definition.card_texture != null
		else null
	)
	card_texture.texture = visible_card
	card_texture.visible = visible_card != null
	fallback.visible = visible_card == null
	card_shadow.show()
	back_glow.show()
	fallback_icon.texture = visible_icon
	fallback_meta.text = _meta_text(definition)
	fallback_title.text = (
		definition.display_name.to_upper() if definition != null else "OBJET INCONNU"
	)
	fallback_description.text = (
		definition.description if definition != null else "Visuel indisponible"
	)
	fallback_footer.text = (
		(
			"ACTIF · SAC PARTAGÉ"
			if definition.has_manual_activation()
			else "PASSIF · SAC PARTAGÉ"
		)
		if definition != null and definition.is_relic()
		else "ÉQUIPEMENT · ATTRIBUTION IMMÉDIATE"
	)
	interaction.tooltip_text = ""
	_material = null
	_refresh_state(false)


func _meta_text(definition: ItemDefinition) -> String:
	if definition == null:
		return "RÉCOMPENSE"
	if definition.is_relic():
		return "RELIQUE DE L’ODYSSÉE"
	match definition.category:
		ItemDefinition.Category.WEAPON:
			return "ARME · ÉQUIPEMENT"
		ItemDefinition.Category.ARMOR:
			return "ARMURE · ÉQUIPEMENT"
		ItemDefinition.Category.ACCESSORY:
			return "ACCESSOIRE · ÉQUIPEMENT"
		_:
			return "ÉQUIPEMENT"


func set_card_size(card_size: Vector2) -> void:
	set_compact_mode(card_size.y <= 500.0)
	custom_minimum_size = card_size
	size = card_size
	_update_geometry()


func set_compact_mode(value: bool) -> void:
	_compact = value
	clip_contents = false
	var side_margin := 18 if value else 28
	fallback_margin.add_theme_constant_override("margin_left", side_margin)
	fallback_margin.add_theme_constant_override("margin_right", side_margin)
	fallback_margin.add_theme_constant_override("margin_top", 17 if value else 32)
	fallback_margin.add_theme_constant_override("margin_bottom", 15 if value else 28)
	fallback_content.add_theme_constant_override("separation", 6 if value else 12)
	illustration_frame.custom_minimum_size.y = 154.0 if value else 260.0
	if value:
		fallback_meta.add_theme_font_size_override("font_size", 10)
		fallback_title.add_theme_font_size_override("font_size", 20)
		fallback_description.add_theme_font_size_override("font_size", 13)
		fallback_footer.add_theme_font_size_override("font_size", 10)
		selection_badge.add_theme_font_size_override("font_size", 11)
	else:
		fallback_meta.remove_theme_font_size_override("font_size")
		fallback_title.remove_theme_font_size_override("font_size")
		fallback_description.remove_theme_font_size_override("font_size")
		fallback_footer.remove_theme_font_size_override("font_size")
		selection_badge.remove_theme_font_size_override("font_size")
	_refresh_state(false)


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


func is_hovered() -> bool:
	return _hovered


func has_card_focus() -> bool:
	return interaction.has_focus()


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
	visual_root.position.y = 54.0
	visual_root.scale = Vector2.ONE * 0.88
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_interval(delay)
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
	var target_x := (
		get_viewport_rect().size.x * 0.5 - get_global_rect().get_center().x
		if chosen
		else (-90.0 if card_index == 0 else 90.0)
	)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual_root, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual_root, "position:x", target_x, duration)
	tween.tween_property(self, "modulate:a", 0.0 if not chosen else 0.94, duration)
	if _material != null:
		_material.set_shader_parameter("sweep_intensity", 0.72 if chosen else 0.0)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_sweep_time += delta
	if _material != null and _selected and not reduced_motion:
		_material.set_shader_parameter("sweep_progress", fmod(_sweep_time * 0.42, 1.8) - 0.35)
	if reduced_motion or _selected or _hovered or _focused or _locked:
		floating_root.position.y = 0.0
	else:
		floating_root.position.y = sin(_sweep_time * 1.9 + _float_phase) * 3.0


func _refresh_state(animated: bool) -> void:
	if not is_node_ready():
		return
	var scale_value := 1.0
	var y_value := 0.0
	var rotation_value := _rest_rotation
	var brightness := 1.0
	var saturation := 1.0
	var outline := 0.0
	var visual_tint := Color.WHITE
	if _selected:
		scale_value = 1.045 if _compact else 1.085
		y_value = 0.0
		rotation_value = 0.0
		brightness = 1.08
		saturation = 1.08
		outline = 0.88
		visual_tint = Color(1.04, 1.02, 0.96, 1.0)
	elif _peer_dimmed:
		scale_value = 0.96
		y_value = 4.0
		rotation_value = _rest_rotation * 1.35
		brightness = 0.64
		saturation = 0.44
		visual_tint = Color(0.58, 0.56, 0.53, 1.0)
	elif _hovered or _focused:
		scale_value = 1.025 if _compact else 1.048
		y_value = -6.0 if _compact else -14.0
		rotation_value = 0.0
		brightness = 1.04
		outline = 0.34
		visual_tint = Color(1.03, 1.01, 0.96, 1.0)
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
		_material.set_shader_parameter("sweep_intensity", 0.28 if _selected and not reduced_motion else 0.0)
	back_glow.modulate.a = 0.44 if _selected else (0.15 if _hovered or _focused else 0.0)
	card_shadow.modulate.a = 0.72 if _selected else (0.58 if _hovered or _focused else 0.42)
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	if not animated or reduced_motion:
		visual_root.scale = Vector2.ONE * scale_value
		visual_root.position = Vector2(0.0, y_value)
		visual_root.rotation_degrees = rotation_value
		visual_root.modulate = visual_tint
		return
	_state_tween = create_tween().set_parallel(true)
	_state_tween.tween_property(visual_root, "scale", Vector2.ONE * scale_value, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(visual_root, "position", Vector2(0.0, y_value), 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_state_tween.tween_property(visual_root, "rotation_degrees", rotation_value, 0.15)
	_state_tween.tween_property(visual_root, "modulate", visual_tint, 0.15)


func _update_geometry() -> void:
	if not is_node_ready():
		return
	visual_root.pivot_offset = size * 0.5
	floating_root.pivot_offset = size * 0.5
	particles.position = size * 0.5


func _on_pressed() -> void:
	if not _locked:
		choice_requested.emit(item_id)


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
	_refresh_state(true)


func _on_focus_exited() -> void:
	_focused = false
	_refresh_state(true)


func _visible_card_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var cache_key := source.resource_path
	if cache_key != "" and _crop_cache.has(cache_key):
		return _crop_cache[cache_key]
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	var used := _non_black_content_rect(image)
	var result: Texture2D = source
	if used.size.x > 0 and used.size.y > 0 \
			and used.size != Vector2i(image.get_width(), image.get_height()):
		var cropped := AtlasTexture.new()
		cropped.atlas = source
		cropped.region = Rect2(used)
		result = cropped
	if cache_key != "":
		_crop_cache[cache_key] = result
	return result


func _non_black_content_rect(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.01 or maxf(pixel.r, maxf(pixel.g, pixel.b)) <= 0.025:
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
