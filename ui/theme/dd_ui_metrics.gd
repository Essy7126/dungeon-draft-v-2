class_name DDUiMetrics
extends RefCounted
## Toutes les dimensions de l'UI (épaisseurs, rayons, marges, tailles) vivent ici
## afin que le thème et les composants restent cohérents à toute résolution.

# --- Épaisseurs de bordure ----------------------------------------------------
const BORDER_THIN := 1
const BORDER := 2
const BORDER_THICK := 3

# --- Rayons de coins (formes souples) ------------------------------------------
const CORNER_SMALL := 8
const CORNER := 12
const CORNER_LARGE := 16
const CORNER_ROUND := 24

# --- Espacements entre éléments --------------------------------------------------
const SPACING_TINY := 4
const SPACING_SMALL := 6
const SPACING := 10
const SPACING_LARGE := 16
const SPACING_XL := 24

# --- Marges internes des panneaux -------------------------------------------------
const MARGIN_SMALL := 8
const MARGIN := 14
const MARGIN_PANEL := 18
const MARGIN_MODAL := 26

# --- Tailles d'icônes --------------------------------------------------------------
const ICON_TINY := 20
const ICON_SMALL := 28
const ICON := 40
const ICON_LARGE := 56
const ICON_PORTRAIT := 72

# --- Tailles de texte ----------------------------------------------------------------
const FONT_TINY := 12
const FONT_SMALL := 14
const FONT_BODY := 16
const FONT_SUBTITLE := 20
const FONT_TITLE := 28
const FONT_BIG := 36

# --- Boutons ---------------------------------------------------------------------------
const BUTTON_HEIGHT := 44
const BUTTON_HEIGHT_SMALL := 34
const BUTTON_MIN_WIDTH := 120
const ICON_BUTTON_SIZE := 52

# --- Emplacements de sorts ----------------------------------------------------------------
const SLOT_SIZE := 64
const SLOT_ICON := 44

# --- Cartes ----------------------------------------------------------------------------------
const CARD_SPELL := Vector2(236, 328)
const CARD_CHARACTER := Vector2(304, 428)
const CARD_DISCIPLINE := Vector2(210, 84)

# --- Barres ------------------------------------------------------------------------------------
const BAR_HEALTH_HEIGHT := 18
const BAR_PROGRESS_HEIGHT := 14
const BAR_MIN_WIDTH := 160

# --- Bulles de dialogue ---------------------------------------------------------------------------
const BUBBLE_MIN := Vector2(220, 64)
const BUBBLE_TAIL := Vector2(26, 16)

# --- Ombres douces -----------------------------------------------------------------------------------
const SHADOW_SIZE := 7
const SHADOW_OFFSET := Vector2(0, 3)

# --- Fenêtres -------------------------------------------------------------------------------------------
const MODAL_MIN := Vector2(420, 220)
const TOOLTIP_MIN := Vector2(260, 120)

# --- Animations (secondes) ----------------------------------------------------------------------------------
const ANIM_HOVER := 0.12
const ANIM_PRESS := 0.07
const ANIM_APPEAR := 0.2
const CARD_HOVER_SCALE := 1.025
const BUTTON_PRESS_OFFSET := 2.0
