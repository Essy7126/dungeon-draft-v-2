class_name SkillTreeDisciplineTab
extends Button

@onready var _frame_texture: TextureRect = %FrameTexture
@onready var _icon: SkillTreeEffectGlyph = %DisciplineIcon
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _pending_badge: SkillTreeEffectGlyph = %PendingBadge
@onready var _active_marker: Label = %ActiveMarker

var discipline_id: StringName = &""
var skin: SkillTreeSkinData = null


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(
		discipline: DisciplineData,
		progress: DisciplineProgressState,
		wanted_skin: SkillTreeSkinData,
		is_selected: bool
	) -> void:
	skin = wanted_skin
	discipline_id = (
		discipline.discipline_id if discipline != null else &""
	)
	if not is_node_ready():
		await ready
	_frame_texture.texture = (
		skin.discipline_tab_texture if skin != null else null
	)
	var icon_id := StringName("elf_%s" % discipline_id)
	_icon.configure_discipline(icon_id, skin)
	_name_label.text = (
		discipline.display_name if discipline != null else "Discipline"
	)
	_rank_label.text = "R%d" % (
		progress.rank if progress != null else 1
	)
	var has_pending := (
		progress != null
		and not progress.get_pending_rank_choices().is_empty()
	)
	_pending_badge.visible = has_pending
	if has_pending:
		_pending_badge.configure(
			&"pending",
			skin.get_state_texture(&"pending") if skin != null else null
		)
	set_selected(is_selected)


func set_selected(value: bool) -> void:
	button_pressed = value
	_active_marker.visible = value
	_active_marker.text = "ACTIF" if value else ""


func get_discipline_id() -> StringName:
	return discipline_id


func has_pending_badge() -> bool:
	return _pending_badge.visible
