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
	shortcut_label.visible = not shortcut.is_empty()
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


func _refresh_visuals() -> void:
	super._refresh_visuals()
	if not is_node_ready() or not is_empty_slot():
		return
	# An unoccupied slot is inert, not an action refused by the game rules.
	# Keep the public DISABLED state while removing its error-like cues.
	disabled = true
	for overlay in [
		selection_overlay, focus_overlay, hover_overlay, hover_rail,
		disabled_overlay, disabled_bar, unavailable_cross_a, unavailable_cross_b,
		cooldown_overlay, cooldown_disc, cooldown_glyph, cooldown_label,
		state_glyph, selected_marker, lock_icon, lock_rail_left, lock_rail_right,
	]:
		overlay.visible = false
	shortcut_label.visible = false
	cost_badge.visible = false
	fallback_label.visible = false
	tooltip_text = "Emplacement d’objet vide"
	background.color = (
		_visual_skin.surface_recessed if _visual_skin != null
		else Color(0.035, 0.035, 0.045, 0.6)
	)
	frame.modulate = Color(0.7, 0.7, 0.7, 0.7)
	refined_frame.modulate = Color.WHITE
	if _visual_skin != null:
		var quiet_style := refined_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if quiet_style != null:
			quiet_style.draw_center = false
			quiet_style.border_color = _visual_skin.border_subtle_color
			refined_frame.add_theme_stylebox_override("panel", quiet_style)


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
	if not message.is_empty():
		accessibility_name += ". " + message


func _accessible_description(_ap_cost: int) -> String:
	return _item_name()


func _update_accessibility_name() -> void:
	if not is_node_ready():
		return
	if is_empty_slot():
		accessibility_name = "Emplacement d’objet vide"
		return
	super._update_accessibility_name()
	if visual_state == VisualState.UNAFFORDABLE:
		# Shared visual state, not a PA rule: the service supplies the reason.
		accessibility_name = _item_name() + ", indisponible"


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
