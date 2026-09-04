class_name PremiumUI
extends RefCounted
## Point d'entree unique du langage visuel premium hors HUD de combat.

const SKIN: HudVisualSkinData = preload(
	"res://data/ui/hud_visual_skin_achilles_v1.tres"
)
const THEME_FACTORY := preload(
	"res://ui/recraft_hud_v1/theme/hud_visual_theme_factory.gd"
)

static var _shared_theme: Theme = null


static func get_theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = THEME_FACTORY.build(SKIN)
	return _shared_theme


static func apply(root: Control) -> void:
	if root != null:
		root.theme = get_theme()


static func set_button_state(button: Button, selected: bool) -> void:
	if button == null:
		return
	button.button_pressed = selected
	button.set_meta(&"premium_selected", selected)


static func rarity_color(rarity: StringName) -> Color:
	match rarity:
		&"legendary", &"mythic":
			return Color(1.0, 0.66, 0.18, 1.0)
		&"rare":
			return Color(0.55, 0.7, 0.96, 1.0)
		&"uncommon":
			return Color(0.48, 0.8, 0.56, 1.0)
		_:
			return SKIN.text_secondary


static func rarity_label(rarity: StringName) -> String:
	match rarity:
		&"legendary":
			return "LÉGENDAIRE"
		&"mythic":
			return "MYTHIQUE"
		&"rare":
			return "RARE"
		&"uncommon":
			return "INHABITUEL"
		_:
			return "COMMUN"
