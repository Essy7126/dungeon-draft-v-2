@tool
class_name TerrainWorkflowRail
extends PanelContainer

## Rail des sept etapes du parcours Terrain. Chaque etape affiche son numero,
## son nom, son etat sous forme de glyphe + mot (jamais la couleur seule) et,
## pour l'etape ouverte, son objectif en une phrase, ce qui manque et la
## prochaine action recommandee.
##
## Le parcours reste libre : cliquer une etape l'ouvre immediatement, meme si
## les precedentes ne sont pas terminees.

signal step_selected(step: int)
signal primary_action_requested(step: int)

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)

var buttons: Array[Button] = []
var goal_label: Label = null
var missing_label: Label = null
var next_action_label: Label = null
var readiness_label: Label = null
var primary_button: Button = null

var _steps: Array[Dictionary] = []
var _current := 0
var _built := false


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainWorkflowRail"
	custom_minimum_size = Vector2(196, 150)
	# Les explications d'étape s'enroulent : sans défilement, leur hauteur
	# minimale imposerait la taille de toute la zone d'édition et repousserait
	# le canvas et le tiroir hors de la fenêtre en 1280 × 720.
	var scroll := ScrollContainer.new()
	scroll.name = "TerrainWorkflowRailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "PARCOURS"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	for index in range(TerrainWorkflowService.STEP_COUNT):
		var button := Button.new()
		button.name = "TerrainStep%d" % (index + 1)
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 30)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_step_pressed.bind(index))
		box.add_child(button)
		buttons.append(button)
	var separator := HSeparator.new()
	box.add_child(separator)
	readiness_label = Label.new()
	readiness_label.name = "TerrainReadiness"
	readiness_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	readiness_label.add_theme_font_size_override("font_size", 13)
	box.add_child(readiness_label)
	goal_label = Label.new()
	goal_label.name = "TerrainStepGoal"
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_label.add_theme_color_override("font_color", MUTED)
	box.add_child(goal_label)
	missing_label = Label.new()
	missing_label.name = "TerrainStepMissing"
	missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(missing_label)
	next_action_label = Label.new()
	next_action_label.name = "TerrainStepNextAction"
	next_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_action_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(next_action_label)
	primary_button = Button.new()
	primary_button.name = "TerrainStepPrimaryAction"
	primary_button.focus_mode = Control.FOCUS_ALL
	primary_button.pressed.connect(func(): primary_action_requested.emit(_current))
	box.add_child(primary_button)


func set_steps(steps: Array[Dictionary], readiness := "") -> void:
	_build()
	_steps = steps
	for index in range(buttons.size()):
		var button := buttons[index]
		if index >= steps.size():
			continue
		var entry := steps[index]
		button.text = "%d. %s  %s" % [
			index + 1, entry.get("label", ""), entry.get("state_glyph", "○"),
		]
		button.tooltip_text = "%s — %s\nÉtat : %s" % [
			entry.get("label", ""), entry.get("goal", ""),
			entry.get("state_word", ""),
		]
		button.add_theme_color_override(
			"font_color",
			TerrainWorkflowService.state_color(entry.get("state", &"todo"))
		)
		button.set_pressed_no_signal(index == _current)
	if not readiness.is_empty() and readiness_label != null:
		readiness_label.text = readiness
		readiness_label.add_theme_color_override("font_color", _readiness_color(readiness))
	_refresh_detail()


func set_current_step(step: int) -> void:
	_build()
	_current = clampi(step, 0, TerrainWorkflowService.STEP_COUNT - 1)
	for index in range(buttons.size()):
		buttons[index].set_pressed_no_signal(index == _current)
	_refresh_detail()


func current_step() -> int:
	return _current


func _on_step_pressed(index: int) -> void:
	set_current_step(index)
	step_selected.emit(index)


func _refresh_detail() -> void:
	if goal_label == null:
		return
	if _current >= _steps.size():
		goal_label.text = ""
		missing_label.text = ""
		next_action_label.text = ""
		primary_button.text = ""
		return
	var entry := _steps[_current]
	goal_label.text = str(entry.get("goal", ""))
	var missing := entry.get("missing", PackedStringArray()) as PackedStringArray
	if missing.is_empty():
		missing_label.text = "Rien ne manque à cette étape."
		missing_label.add_theme_color_override(
			"font_color", TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DONE)
		)
	else:
		missing_label.text = "Il manque :\n• %s" % "\n• ".join(missing)
		missing_label.add_theme_color_override(
			"font_color", TerrainWorkflowService.state_color(entry.get("state", &"todo"))
		)
	next_action_label.text = str(entry.get("next_action", "")) \
		if entry.get("state", &"todo") == TerrainWorkflowService.STATE_DONE \
		else "À faire ensuite : %s" % entry.get("next_action", "")
	primary_button.text = str(entry.get("action_label", "Continuer"))
	primary_button.tooltip_text = str(entry.get("next_action", ""))


func _readiness_color(readiness: String) -> Color:
	match readiness:
		TerrainWorkflowService.READINESS_INTEGRABLE:
			return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DONE)
		TerrainWorkflowService.READINESS_TESTABLE:
			return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_DOING)
	return TerrainWorkflowService.state_color(TerrainWorkflowService.STATE_TODO)
