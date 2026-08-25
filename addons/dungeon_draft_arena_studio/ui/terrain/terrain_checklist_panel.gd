@tool
class_name TerrainChecklistPanel
extends PanelContainer

## Checklist pédagogique facultative. Elle informe sans changer l'outil, le
## filtre de bibliothèque, l'Inspecteur ou la disposition du canvas.

signal collapsed_changed(collapsed: bool)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

var toggle_button: Button = null
var entries_box: VBoxContainer = null
var summary_label: Label = null
var _collapsed := true
var _entries: Array[Dictionary] = []
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainChecklistPanel"
	custom_minimum_size.x = 164
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	toggle_button = Button.new()
	toggle_button.name = "TerrainChecklistToggle"
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.focus_mode = Control.FOCUS_ALL
	toggle_button.pressed.connect(func(): set_collapsed(not _collapsed))
	root.add_child(toggle_button)
	summary_label = Label.new()
	summary_label.name = "TerrainChecklistSummary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_color_override("font_color", MUTED)
	root.add_child(summary_label)
	entries_box = VBoxContainer.new()
	entries_box.name = "TerrainChecklistEntries"
	entries_box.add_theme_constant_override("separation", 3)
	root.add_child(entries_box)
	_refresh()


func set_entries(entries: Array[Dictionary]) -> void:
	_build()
	_entries = entries.duplicate(true)
	_refresh()


func set_collapsed(value: bool) -> void:
	_build()
	if _collapsed == value:
		return
	_collapsed = value
	_refresh()
	collapsed_changed.emit(value)


func is_collapsed() -> bool:
	return _collapsed


func _refresh() -> void:
	if entries_box == null:
		return
	for child in entries_box.get_children():
		entries_box.remove_child(child)
		child.queue_free()
	var completed := 0
	var blocking := 0
	for entry in _entries:
		var state := StringName(entry.get("state", &"todo"))
		completed += 1 if state == TerrainWorkflowService.STATE_DONE else 0
		blocking += 1 if state == TerrainWorkflowService.STATE_ERROR else 0
		if _collapsed:
			continue
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s %s" % [
			TerrainWorkflowService.state_glyph(state), entry.get("label", ""),
		]
		label.tooltip_text = str(entry.get("detail", entry.get("next_action", "")))
		label.add_theme_color_override("font_color", TerrainWorkflowService.state_color(state))
		entries_box.add_child(label)
	toggle_button.text = "%s CHECKLIST" % ("▸" if _collapsed else "▾")
	summary_label.text = (
		"%d problème(s) bloquant(s)" % blocking
		if blocking > 0 else "%d/%d points prêts" % [completed, _entries.size()]
	)
	entries_box.visible = not _collapsed
