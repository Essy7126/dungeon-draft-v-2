class_name RecraftItemSlotView
extends RecraftSpellSlotView

# Bouton d'objet activable à la main, dans la barre de combat.
#
# Il hérite volontairement du bouton de sort : la scène est une scène héritée de
# spell_slot_view.tscn, donc le cadre, les survols, la sélection et surtout
# l'assombrissement/désaturation de l'état UNAFFORDABLE sont exactement les
# mêmes que pour un sort. Un objet indisponible se lit donc comme un sort
# injouable, sans nouvelle grammaire visuelle à apprendre.
#
# Deux différences seulement : aucun coût en PA n'est affiché (activer un objet
# ne coûte pas de PA, seul l'effet configuré s'applique), et l'objet est
# identifié par l'identifiant de son exemplaire dans le sac de la partie.

var instance_id: StringName = &""
var definition: ItemDefinition = null


func _ready() -> void:
	super._ready()
	cost_badge.visible = false


func configure_item(
		p_instance_id: StringName,
		p_definition: ItemDefinition,
		shortcut: String = ""
	) -> void:
	instance_id = p_instance_id
	definition = p_definition
	shortcut_label.text = shortcut
	shortcut_label.visible = true
	cost_badge.visible = false
	set_icon_override(p_definition.get_inventory_icon() if p_definition != null else null)
	if is_node_ready():
		fallback_label.text = _fallback_text()
	accessibility_name = _item_name()
	tooltip_text = ""


func clear_item() -> void:
	instance_id = &""
	definition = null
	shortcut_label.text = ""
	# La pastille de raccourci a son propre fond : vide, elle laisserait un
	# rectangle clair sur un emplacement pourtant inoccupé.
	shortcut_label.visible = false
	cost_badge.visible = false
	set_icon_override(null)
	if is_node_ready():
		fallback_label.text = _fallback_text()
	accessibility_name = "Emplacement d’objet vide"
	tooltip_text = ""
	set_visual_state(VisualState.DISABLED)


func is_empty_slot() -> bool:
	return definition == null


# Traduit la réponse de RelicRuntimeService.manual_activation_state() en état
# visuel. L'interface ne rejoue jamais les règles de conditions ou de fréquence :
# elle se contente d'afficher le verdict du service.
func apply_availability(state: Dictionary, controls_enabled: bool) -> void:
	if is_empty_slot():
		clear_item()
		return
	var message := str(state.get("message", ""))
	if not controls_enabled:
		set_visual_state(VisualState.DISABLED)
	elif bool(state.get("available", false)):
		set_visual_state(VisualState.NORMAL)
	else:
		set_visual_state(VisualState.UNAFFORDABLE)
	tooltip_text = _tooltip_for(message)


func _tooltip_for(message: String) -> String:
	var lines: Array[String] = [_item_name()]
	if definition != null and not definition.description.strip_edges().is_empty():
		lines.append(definition.description)
	if not message.is_empty():
		lines.append(message)
	return "\n".join(lines)


func _item_name() -> String:
	return definition.display_name if definition != null else "Objet"


func _fallback_text() -> String:
	# Un emplacement vide reste un cadre vide : pas d'initiale de remplacement,
	# contrairement à un objet sans icône qui affiche sa première lettre.
	if definition == null:
		return ""
	var display_name := definition.display_name
	return display_name.left(1).to_upper() if not display_name.is_empty() else "?"
