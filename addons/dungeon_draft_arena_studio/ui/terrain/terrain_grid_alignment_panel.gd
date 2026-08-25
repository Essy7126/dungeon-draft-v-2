@tool
class_name TerrainGridAlignmentPanel
extends VBoxContainer

signal settings_changed(settings: Dictionary)
signal editing_finished

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const GridAlignmentService = preload(
	"res://addons/dungeon_draft_arena_studio/services/terrain_grid_alignment_service.gd"
)

var width_spin: SpinBox = null
var height_spin: SpinBox = null
var position_x_spin: SpinBox = null
var position_y_spin: SpinBox = null
var rotation_spin: SpinBox = null
var scale_x_spin: SpinBox = null
var scale_y_spin: SpinBox = null
var skew_spin: SpinBox = null
var commit_timer: Timer = null

var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainGridAlignmentPanel"
	add_theme_constant_override("separation", 5)
	commit_timer = Timer.new()
	commit_timer.one_shot = true
	commit_timer.wait_time = 0.35
	commit_timer.timeout.connect(func(): editing_finished.emit())
	add_child(commit_timer)
	var fields := GridContainer.new()
	fields.columns = 2
	add_child(fields)
	width_spin = _field(fields, "Taille — largeur", 1.0, 64.0, 1.0)
	height_spin = _field(fields, "Taille — hauteur", 1.0, 64.0, 1.0)
	position_x_spin = _field(fields, "Position X", -10000.0, 10000.0, 1.0, " px")
	position_y_spin = _field(fields, "Position Y", -10000.0, 10000.0, 1.0, " px")
	rotation_spin = _field(fields, "Rotation", -360.0, 360.0, 0.1, "°")
	scale_x_spin = _field(fields, "Échelle X", 0.01, 10.0, 0.01)
	scale_y_spin = _field(fields, "Échelle Y", 0.01, 10.0, 0.01)
	skew_spin = _field(fields, "Inclinaison", -80.0, 80.0, 0.1, "°")
	var note := Label.new()
	note.text = "Modification immédiate — les poignées restent utilisables sur l'image."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", ACCENT)
	add_child(note)


func sync_from_arena(arena: ArenaDefinition) -> void:
	_build()
	if arena == null:
		return
	var values := GridAlignmentService.settings_from_arena(arena)
	var position := values.get("position", Vector2.ZERO) as Vector2
	var scale := values.get("scale", Vector2.ONE) as Vector2
	width_spin.set_value_no_signal(arena.grid_size.x)
	height_spin.set_value_no_signal(arena.grid_size.y)
	position_x_spin.set_value_no_signal(position.x)
	position_y_spin.set_value_no_signal(position.y)
	rotation_spin.set_value_no_signal(float(values.get("rotation_degrees", 0.0)))
	scale_x_spin.set_value_no_signal(scale.x)
	scale_y_spin.set_value_no_signal(scale.y)
	skew_spin.set_value_no_signal(float(values.get("skew_degrees", 0.0)))


func settings() -> Dictionary:
	_build()
	return {
		"grid_size": Vector2i(int(width_spin.value), int(height_spin.value)),
		"position": Vector2(position_x_spin.value, position_y_spin.value),
		"rotation_degrees": rotation_spin.value,
		"scale": Vector2(scale_x_spin.value, scale_y_spin.value),
		"skew_degrees": skew_spin.value,
	}


func _field(
		parent: GridContainer,
		label_text: String,
		minimum: float,
		maximum: float,
		step: float,
		suffix := ""
	) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.focus_mode = Control.FOCUS_ALL
	spin.value_changed.connect(_on_value_changed)
	parent.add_child(spin)
	return spin


func _on_value_changed(_value: float) -> void:
	settings_changed.emit(settings())
	commit_timer.start()
