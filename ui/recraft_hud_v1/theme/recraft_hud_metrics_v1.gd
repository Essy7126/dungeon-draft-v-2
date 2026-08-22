class_name RecraftHudMetricsV1
extends RefCounted

const REFERENCE_WIDTH := 1600.0
const MINIMUM_SCALE := 0.75

const HUD_HEIGHT := 150.0
const HORIZONTAL_MARGIN := 18.0
const VERTICAL_MARGIN := 12.0

const PORTRAIT_SIZE := 96.0
const PORTRAIT_INNER_SIZE := 76.0
const PORTRAIT_PREVIEW_CAMERA_SIZE := 1.75
const CHARACTER_INFO_WIDTH := 210.0
const CHARACTER_SECTION_GAP := 12.0
const CHARACTER_NAME_HEIGHT := 18.0

const RESOURCE_BAR_SIZE := Vector2(190.0, 18.0)
const RESOURCE_BAR_GAP := 7.0
const RESOURCE_BAR_INSETS := Vector4(7.0, 4.0, 7.0, 4.0)

const RESOURCE_BADGE_SIZE := 42.0
const RESOURCE_BADGE_GAP := 8.0

const ACTION_BUTTON_SIZE := Vector2(99.0, 27.0)
const ACTION_BUTTON_GAP := 6.0
const ACTION_BUTTON_ROW_GAP := 4.0

const SPELL_VISUAL_SIZE := 64.0
const SPELL_SLOT_HEIGHT := 78.0
const SPELL_SHORTCUT_HEIGHT := 14.0
const SPELL_ICON_SIZE := 48.0
const SPELL_GAP := 6.0
const SPELL_PANEL_PADDING := 12.0
const SPELL_PANEL_HEIGHT := 92.0
const SPELL_COST_BADGE_SIZE := Vector2(24.0, 18.0)

# Bascule entre la barre de sorts et la barre d'objets : deux flèches empilées.
# Cette largeur est réservée en permanence dans le calcul de la barre, même
# quand la barre d'objets est masquée, pour que « Fin de tour » et le bouton de
# compétences ne bougent jamais d'un tour à l'autre.
const BAR_TOGGLE_WIDTH := 34.0
const BAR_TOGGLE_BUTTON_SIZE := Vector2(30.0, 26.0)
const BAR_TOGGLE_GAP := 4.0

const END_TURN_SIZE := Vector2(136.0, 44.0)
const TURN_LABEL_GAP := 6.0
const GROUP_GAP := 24.0

const CHARACTER_NAME_FONT_SIZE := 16
const RESOURCE_VALUE_FONT_SIZE := 12
const SHORTCUT_FONT_SIZE := 11
const COST_FONT_SIZE := 11
const SECONDARY_FONT_SIZE := 10
const PRIMARY_BUTTON_FONT_SIZE := 14
const ACTION_BUTTON_FONT_SIZE := 10


static func scale_for(viewport_width: float) -> float:
	return clampf(viewport_width / REFERENCE_WIDTH, MINIMUM_SCALE, 1.0)


static func scaled(value: float, scale_factor: float) -> float:
	return roundf(value * scale_factor)


static func scaled_vector(value: Vector2, scale_factor: float) -> Vector2:
	return Vector2(scaled(value.x, scale_factor), scaled(value.y, scale_factor))


static func scaled_font(value: int, scale_factor: float) -> int:
	return maxi(int(round(value * scale_factor)), 8)
