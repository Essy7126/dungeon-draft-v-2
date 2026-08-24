@tool
class_name TerrainGuidancePanel
extends PanelContainer

## Guidage contextuel du Studio Terrain. Il remplace la visite de 22 pages dans
## le parcours nominal : une seule consigne, attachee a l'etape ouverte, mise a
## jour automatiquement des que l'action est realisee.
##
## Le guidage n'attrape jamais la souris et ne desactive aucun outil : c'est une
## banniere au-dessus du canvas, masquable a tout moment.

signal continue_requested
signal previous_requested
signal hidden_requested
signal glossary_requested

const ACCENT := Color(0.48, 0.86, 1.0)
const MUTED := Color(0.72, 0.77, 0.84)
const PANEL_BACKGROUND := Color(0.137, 0.153, 0.184)

var step_label: Label = null
var instruction_label: Label = null
var state_label: Label = null
var continue_button: Button = null
var previous_button: Button = null
var hide_button: Button = null
var glossary_button: Button = null

var _built := false
var _step := 0


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	name = "TerrainGuidancePanel"
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND
	style.set_corner_radius_all(6)
	style.border_width_left = 3
	style.border_color = ACCENT
	style.set_content_margin_all(6)
	style.content_margin_left = 12
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	step_label = Label.new()
	step_label.name = "TerrainGuidanceStep"
	step_label.add_theme_font_size_override("font_size", 14)
	step_label.add_theme_color_override("font_color", ACCENT)
	texts.add_child(step_label)
	instruction_label = Label.new()
	instruction_label.name = "TerrainGuidanceInstruction"
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_color_override("font_color", MUTED)
	texts.add_child(instruction_label)
	state_label = Label.new()
	state_label.name = "TerrainGuidanceState"
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(state_label)
	# Une seule rangée d'actions, libellés courts et infobulles explicites :
	# chaque ligne prise ici est prise au canvas.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	previous_button = Button.new()
	previous_button.name = "TerrainGuidancePrevious"
	previous_button.text = "Précédent"
	previous_button.tooltip_text = "Revenir à l'étape précédente du parcours."
	previous_button.focus_mode = Control.FOCUS_ALL
	previous_button.pressed.connect(func(): previous_requested.emit())
	actions.add_child(previous_button)
	continue_button = Button.new()
	continue_button.name = "TerrainGuidanceContinue"
	continue_button.text = "Continuer"
	continue_button.tooltip_text = "Passer à l'étape suivante du parcours."
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(func(): continue_requested.emit())
	actions.add_child(continue_button)
	glossary_button = Button.new()
	glossary_button.name = "TerrainGuidanceGlossary"
	glossary_button.text = "Glossaire"
	glossary_button.tooltip_text = "Consulter la définition des mots du Studio Terrain."
	glossary_button.focus_mode = Control.FOCUS_ALL
	glossary_button.pressed.connect(func(): glossary_requested.emit())
	actions.add_child(glossary_button)
	hide_button = Button.new()
	hide_button.name = "TerrainGuidanceHide"
	hide_button.text = "Masquer"
	hide_button.tooltip_text = (
		"Masquer le guidage. Le rail des étapes continue d'indiquer la suite."
	)
	hide_button.focus_mode = Control.FOCUS_ALL
	hide_button.pressed.connect(func(): hidden_requested.emit())
	actions.add_child(hide_button)


func show_step(step: int, entry: Dictionary) -> void:
	_build()
	_step = step
	step_label.text = "Étape %d — %s" % [step + 1, entry.get("label", "")]
	# L'objectif de l'étape est déjà affiché par le rail : le guidage ne répète
	# que la consigne d'action, pour rendre la place au canvas.
	instruction_label.text = str(entry.get("hint", "")).replace("\n", "  ·  ")
	instruction_label.tooltip_text = str(entry.get("goal", ""))
	previous_button.disabled = step <= 0
	var state := StringName(entry.get("state", TerrainWorkflowService.STATE_TODO))
	state_label.add_theme_color_override(
		"font_color", TerrainWorkflowService.state_color(state)
	)
	if state == TerrainWorkflowService.STATE_DONE:
		state_label.text = "✓ Étape terminée — vous pouvez continuer."
		continue_button.disabled = step >= TerrainWorkflowService.STEP_COUNT - 1
		continue_button.text = "Continuer" if step < TerrainWorkflowService.STEP_COUNT - 1 \
			else "Parcours terminé"
	elif state == TerrainWorkflowService.STATE_ERROR:
		state_label.text = "! %s" % entry.get("next_action", "")
		continue_button.disabled = false
		continue_button.text = "Continuer"
		continue_button.tooltip_text = (
			"Des problèmes subsistent : vous pouvez quand même passer à l'étape suivante."
		)
	else:
		state_label.text = "%s %s" % [
			TerrainWorkflowService.state_glyph(state), entry.get("next_action", ""),
		]
		continue_button.disabled = false
		continue_button.text = "Continuer"
		continue_button.tooltip_text = "Passer à l'étape suivante du parcours."
