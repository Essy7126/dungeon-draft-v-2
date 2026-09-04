class_name SkillEvolutionCard
extends Control

signal choice_requested(upgrade_id: StringName)
signal hover_changed(card_index: int, hovered: bool)

const CARD_SHADER := preload(
	"res://ui/progression/evolution/skill_evolution_art.gdshader"
)
const FALLBACK_ASPECT := 0.62

# Régions normalisées produites une fois à partir du cadrage historique des
# cartes. Elles évitent de relire puis parcourir jusqu'à 1,57 million de pixels
# en GDScript à chaque première ouverture, tout en conservant le même cadrage.
const ARTWORK_CROP_REGIONS := {
	# Cartes historiques de l'archère.
	"res://asset/sorts/abre_competences/elfe/pointe_barbelée.png": Rect2(
		0.177734, 0.074219, 0.596680, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/oeil_aigle.png": Rect2(
		0.177734, 0.074219, 0.596680, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/trait_impact.png": Rect2(
		0.177734, 0.074219, 0.596680, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/longue_portée.jpg": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/tir_perforant.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/trait_de_siege.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/tracas.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/fleche_siege.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/trait_de_.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/recul_tactique.png": Rect2(
		0.179688, 0.074219, 0.594727, 0.407227
	),
	"res://asset/sorts/abre_competences/elfe/felche_clouante.jpg": Rect2(
		0.165039, 0.033203, 0.677734, 0.419922
	),
	"res://asset/sorts/abre_competences/elfe/stabilisation.jpg": Rect2(
		0.222656, 0.064453, 0.553711, 0.396484
	),
	"res://asset/sorts/abre_competences/elfe/fleche_arret.jpg": Rect2(
		0.178711, 0.046875, 0.595703, 0.418945
	),
	# Illustrations d'évolution de la run Odyssée.
	"res://asset/ui/progression/achilles_evolutions_v1/allonge_du_styx.png": Rect2(
		0.007177, 0.004785, 0.980064, 0.990431
	),
	"res://asset/ui/progression/achilles_evolutions_v1/cercle_de_bronze.png": Rect2(
		0.043062, 0.019139, 0.912281, 0.940191
	),
	"res://asset/ui/progression/achilles_evolutions_v1/elan_des_myrmidons.png": Rect2(
		0.012759, 0.058214, 0.952153, 0.897129
	),
	"res://asset/ui/progression/achilles_evolutions_v1/horizon_brise.png": Rect2(
		0.026316, 0.094099, 0.958533, 0.809410
	),
	"res://asset/ui/progression/achilles_evolutions_v1/impact_d_airain.png": Rect2(
		0.088517, 0.035088, 0.890750, 0.924242
	),
	"res://asset/ui/progression/achilles_evolutions_v1/pas_du_revenant.png": Rect2(
		0.050239, 0.006380, 0.913078, 0.985646
	),
	"res://asset/ui/progression/achilles_evolutions_v1/pointe_inexorable.png": Rect2(
		0.035088, 0.016746, 0.920255, 0.972089
	),
	"res://asset/ui/progression/achilles_evolutions_v1/rempart_du_pelion.png": Rect2(
		0.015152, 0.006380, 0.970494, 0.987241
	),
}

@onready var floating_root: Control = %FloatingRoot
@onready var visual_root: Control = %VisualRoot
@onready var back_glow: PanelContainer = %BackGlow
@onready var card_shadow: PanelContainer = %CardShadow
@onready var card_texture: TextureRect = %CardTexture
@onready var fallback: PanelContainer = %Fallback
@onready var card_margin: MarginContainer = $FloatingRoot/VisualRoot/CardFrame/CardMargin
@onready var card_content: VBoxContainer = $FloatingRoot/VisualRoot/CardFrame/CardMargin/CardContent
@onready var eyebrow: Label = $FloatingRoot/VisualRoot/CardFrame/CardMargin/CardContent/Eyebrow
@onready var art_stage: PanelContainer = $FloatingRoot/VisualRoot/CardFrame/CardMargin/CardContent/ArtStage
@onready var fallback_glyph: Label = $FloatingRoot/VisualRoot/CardFrame/CardMargin/CardContent/ArtStage/Fallback/FallbackContent/Glyph
@onready var fallback_title: Label = %FallbackTitle
@onready var fallback_description: Label = %FallbackDescription
@onready var display_title: Label = %DisplayTitle
@onready var display_description: Label = %DisplayDescription
@onready var rank_label: Label = %RankLabel
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
var _confirmation_tween: Tween = null
var _visible_texture: Texture2D = null
var _compact_mode := false
var _presentation_scale := 1.0

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
	_apply_content_layout()
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
	_rest_rotation = -0.7 if index == 0 else 0.7
	_float_phase = float(index) * PI
	reset_visual_state()
	var source := upgrade.get_card_texture() if upgrade != null else null
	_visible_texture = _extract_artwork(source)
	card_texture.texture = _visible_texture
	fallback.visible = _visible_texture == null
	card_texture.visible = _visible_texture != null
	fallback_title.text = upgrade.display_name.to_upper() if upgrade != null else "ÉVOLUTION"
	fallback_description.text = "ILLUSTRATION NON RENSEIGNÉE"
	display_title.text = upgrade.display_name.to_upper() if upgrade != null else "ÉVOLUTION"
	display_description.text = (
		upgrade.description
		if upgrade != null
		else "Les données de cette évolution sont indisponibles."
	)
	rank_label.text = "RANG %d · CHOIX PERMANENT" % (
		upgrade.rank if upgrade != null else 0
	)
	interaction.tooltip_text = (
		"%s\n%s" % [upgrade.display_name, upgrade.description]
		if upgrade != null
		else ""
	)
	_material = ShaderMaterial.new()
	_material.shader = CARD_SHADER
	_material.set_shader_parameter("outline_color", Color(0.96, 0.66, 0.18, 1.0))
	_material.set_shader_parameter("tint", Color(1.04, 0.99, 0.9, 1.0))
	card_texture.material = _material
	_refresh_state(false)


func reset_visual_state() -> void:
	for tween in [_state_tween, _entrance_tween, _confirmation_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_state_tween = null
	_entrance_tween = null
	_confirmation_tween = null
	modulate.a = 1.0
	visual_root.position = Vector2.ZERO
	visual_root.scale = Vector2.ONE
	visual_root.rotation_degrees = _rest_rotation
	floating_root.position = Vector2.ZERO


func get_card_aspect() -> float:
	return FALLBACK_ASPECT


func set_card_height(card_height: float, maximum_width: float) -> void:
	var wanted_width := card_height * get_card_aspect()
	if wanted_width > maximum_width:
		wanted_width = maximum_width
		card_height = wanted_width / get_card_aspect()
	custom_minimum_size = Vector2(wanted_width, card_height)
	size = custom_minimum_size
	_update_geometry()


func set_compact_mode(value: bool) -> void:
	_compact_mode = value
	if is_node_ready():
		_apply_content_layout()


func set_presentation_scale(value: float) -> void:
	_presentation_scale = clampf(value, 1.0, 1.18)
	if is_node_ready():
		_apply_content_layout()


func is_compact_mode() -> bool:
	return _compact_mode


func get_layout_snapshot() -> Dictionary:
	return {
		"compact_mode": _compact_mode,
		"presentation_scale": _presentation_scale,
		"card_global": get_global_rect(),
		"art_global": art_stage.get_global_rect(),
		"title_global": display_title.get_global_rect(),
		"description_global": display_description.get_global_rect(),
		"rank_global": rank_label.get_global_rect(),
		"art_minimum_height": art_stage.custom_minimum_size.y,
		"description_minimum_height": display_description.custom_minimum_size.y,
		"description_font_size": display_description.get_theme_font_size("font_size"),
		"eyebrow_global": eyebrow.get_global_rect(),
		"selection_badge_global": selection_badge.get_global_rect(),
	}


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
	visual_root.position.y = 28.0
	visual_root.scale = Vector2.ONE * 0.96
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(self, "modulate:a", 1.0, 0.32).set_delay(delay)
	_entrance_tween.tween_property(visual_root, "position:y", _state_y, 0.38) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(visual_root, "scale", Vector2.ONE, 0.38) \
		.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func play_confirmation(chosen: bool) -> void:
	set_locked(true)
	particles.emitting = chosen and not reduced_motion
	var duration := 0.12 if reduced_motion else 0.42
	var target_scale := Vector2.ONE * (1.055 if chosen else 0.96)
	var target_x := 0.0 if chosen else (-54.0 if card_index == 0 else 54.0)
	if _confirmation_tween != null and _confirmation_tween.is_valid():
		_confirmation_tween.kill()
	_confirmation_tween = create_tween().set_parallel(true)
	_confirmation_tween.tween_property(visual_root, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_confirmation_tween.tween_property(visual_root, "position:x", target_x, duration)
	_confirmation_tween.tween_property(self, "modulate:a", 0.0 if not chosen else 0.96, duration)
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
		floating_root.position.y = sin(_elapsed * 1.55 + _float_phase) * 1.5


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
		scale_value = 1.045
		y_value = -10.0
		rotation_value = 0.0
		brightness = 1.06
		saturation = 1.04
		outline = 0.72
	elif _peer_dimmed:
		scale_value = 0.975
		y_value = 3.0
		rotation_value = _rest_rotation
		brightness = 0.7
		saturation = 0.58
	elif _hovered or _focused:
		scale_value = 1.025
		y_value = -6.0
		rotation_value = 0.0
		brightness = 1.03
		outline = 0.3
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
	back_glow.modulate.a = 0.38 if _selected else (0.14 if _hovered or _focused else 0.0)
	card_shadow.modulate.a = 0.68 if _selected else (0.58 if _hovered or _focused else 0.5)
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


func _apply_content_layout() -> void:
	if not is_node_ready():
		return
	var scale_factor := 1.0 if _compact_mode else _presentation_scale
	var horizontal_margin := 14.0 if _compact_mode else 19.0 * scale_factor
	var top_margin := 12.0 if _compact_mode else 19.0 * scale_factor
	var bottom_margin := 11.0 if _compact_mode else 18.0 * scale_factor
	card_margin.add_theme_constant_override("margin_left", roundi(horizontal_margin))
	card_margin.add_theme_constant_override("margin_right", roundi(horizontal_margin))
	card_margin.add_theme_constant_override("margin_top", roundi(top_margin))
	card_margin.add_theme_constant_override("margin_bottom", roundi(bottom_margin))
	card_content.add_theme_constant_override(
		"separation",
		4 if _compact_mode else roundi(8.0 * scale_factor)
	)
	art_stage.custom_minimum_size.y = (
		164.0 if _compact_mode else 250.0 * scale_factor
	)
	display_title.custom_minimum_size.y = (
		42.0 if _compact_mode else 54.0 * scale_factor
	)
	display_description.custom_minimum_size.y = (
		70.0 if _compact_mode else 92.0 * scale_factor
	)
	eyebrow.add_theme_font_size_override(
		"font_size",
		9 if _compact_mode else roundi(11.0 * scale_factor)
	)
	display_title.add_theme_font_size_override(
		"font_size",
		17 if _compact_mode else roundi(21.0 * scale_factor)
	)
	display_description.add_theme_font_size_override(
		"font_size",
		12 if _compact_mode else roundi(14.0 * scale_factor)
	)
	display_description.max_lines_visible = 5 if _compact_mode else -1
	display_description.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
		if _compact_mode
		else TextServer.OVERRUN_NO_TRIMMING
	)
	rank_label.add_theme_font_size_override(
		"font_size",
		9 if _compact_mode else roundi(11.0 * scale_factor)
	)
	selection_badge.add_theme_font_size_override(
		"font_size",
		9 if _compact_mode else roundi(11.0 * scale_factor)
	)
	fallback_glyph.add_theme_font_size_override(
		"font_size",
		38 if _compact_mode else roundi(54.0 * scale_factor)
	)
	fallback_title.add_theme_font_size_override(
		"font_size",
		12 if _compact_mode else roundi(15.0 * scale_factor)
	)
	fallback_description.add_theme_font_size_override(
		"font_size",
		9 if _compact_mode else roundi(11.0 * scale_factor)
	)
	selection_badge.offset_left = (
		-128.0 if _compact_mode else -150.0 * scale_factor
	)
	selection_badge.offset_top = 7.0 * scale_factor
	selection_badge.offset_right = -7.0 * scale_factor
	selection_badge.offset_bottom = (
		35.0 if _compact_mode else 41.0 * scale_factor
	)


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


func _extract_artwork(source: Texture2D) -> Texture2D:
	if source == null:
		push_warning("Carte d’évolution absente pour %s." % upgrade_id)
		return null
	var cache_key := source.resource_path
	if not cache_key.is_empty() and _crop_cache.has(cache_key):
		return _crop_cache[cache_key]
	var result: Texture2D = source
	var normalized: Rect2 = ARTWORK_CROP_REGIONS.get(cache_key, Rect2())
	if normalized.size.x > 0.0 and normalized.size.y > 0.0:
		var texture_size := Vector2(source.get_width(), source.get_height())
		var used := Rect2(
			(texture_size * normalized.position).round(),
			(texture_size * normalized.size).round(),
		)
		used.position.x = clampf(used.position.x, 0.0, texture_size.x - 1.0)
		used.position.y = clampf(used.position.y, 0.0, texture_size.y - 1.0)
		used.size.x = clampf(used.size.x, 1.0, texture_size.x - used.position.x)
		used.size.y = clampf(used.size.y, 1.0, texture_size.y - used.position.y)
		if used.position != Vector2.ZERO or used.size != texture_size:
			var cropped := AtlasTexture.new()
			cropped.atlas = source
			cropped.region = used
			cropped.filter_clip = true
			result = cropped
	if not cache_key.is_empty():
		_crop_cache[cache_key] = result
	return result
