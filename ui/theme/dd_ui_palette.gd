class_name DDUiPalette
extends Resource
## Palette centrale de l'identité visuelle "Dungeon Draft".
## Direction : fantasy dessinée et chaleureuse — parchemin ivoire, bois peint
## sombre violacé, contours brun-aubergine épais, cuivre vieilli et or désaturé.
## Toutes les couleurs sont éditables dans l'Inspector ; la valeur par défaut
## partagée s'obtient via DDUiPalette.get_default().

# --- Contours et ombres ---------------------------------------------------
## Brun aubergine très sombre : contour épais caractéristique.
@export var outline_dark: Color = Color("2b1a26")
## Contour adouci pour les petits éléments.
@export var outline_soft: Color = Color("3d2737")
## Ombre douce portée des panneaux.
@export var shadow_soft: Color = Color(0.05, 0.02, 0.07, 0.45)
## Lueur fine de focus.
@export var focus_glow: Color = Color("e8c97a")

# --- Parchemin ivoire chaud ------------------------------------------------
@export var parchment_light: Color = Color("f5e7c6")
@export var parchment: Color = Color("ecd9b2")
@export var parchment_dark: Color = Color("d9bf92")
@export var parchment_shadow: Color = Color("b99c6d")

# --- Bois peint sombre aux nuances violettes -------------------------------
@export var wood_light: Color = Color("543e5c")
@export var wood: Color = Color("3e2d47")
@export var wood_dark: Color = Color("2c1f34")
@export var wood_deep: Color = Color("201728")

# --- Cuivre vieilli et or désaturé ------------------------------------------
@export var copper_light: Color = Color("d9a869")
@export var copper: Color = Color("b3814d")
@export var copper_dark: Color = Color("8a5f36")
@export var gold_muted: Color = Color("c9a558")
@export var patina: Color = Color("6f8f7b")

# --- Texte -------------------------------------------------------------------
## Texte sombre sur parchemin (contraste fort).
@export var text_on_light: Color = Color("37202f")
## Texte secondaire sur parchemin.
@export var text_on_light_dim: Color = Color("6b4b58")
## Texte clair sur bois sombre.
@export var text_on_dark: Color = Color("f0e4cd")
## Texte secondaire sur bois sombre.
@export var text_on_dark_dim: Color = Color("b9a48f")

# --- États -------------------------------------------------------------------
@export var hover_tint: Color = Color(1.12, 1.09, 1.02, 1.0)
@export var pressed_tint: Color = Color(0.9, 0.87, 0.84, 1.0)
@export var disabled_tint: Color = Color(0.62, 0.6, 0.62, 0.85)
@export var selected_tint: Color = Color("ffd98a")
@export var danger: Color = Color("a33527")
@export var danger_dark: Color = Color("6f2019")

# --- Lecture des ressources de tour ------------------------------------------
## PA (points d'action) : or chaud lisible.
@export var ap_color: Color = Color("f0b83e")
## PM (points de mouvement) : vert d'eau / patine.
@export var mp_color: Color = Color("7fc4a8")
## PV : vert sanguin chaud.
@export var hp_color: Color = Color("7fb069")
@export var hp_low_color: Color = Color("c94f38")
@export var shield_color: Color = Color("8fa7c9")

# --- Accents élémentaires ------------------------------------------------------
## Feu : orange profond.
@export var fire: Color = Color("e05a2b")
## Feu : rouge braise (fond).
@export var fire_dark: Color = Color("8e2a1c")
## Glace : cyan.
@export var ice: Color = Color("5fc8dd")
## Glace : bleu pâle (fond).
@export var ice_dark: Color = Color("2e6d80")
## Foudre : violet.
@export var lightning: Color = Color("9a63d8")
## Foudre : jaune chaud (accent).
@export var lightning_accent: Color = Color("f2d150")
## Terre : ocre.
@export var earth: Color = Color("c08b3e")
## Terre : vert mousse (accent).
@export var earth_accent: Color = Color("7d9153")
## Terre : brun minéral (fond).
@export var earth_dark: Color = Color("5d4128")

static var _default: DDUiPalette = null


## Instance partagée par défaut (constuite à la demande).
static func get_default() -> DDUiPalette:
	if _default == null:
		_default = DDUiPalette.new()
	return _default


## Couleur principale d'un élément ("fire", "ice", "lightning", "earth").
func element_color(element: StringName) -> Color:
	match element:
		&"fire":
			return fire
		&"ice":
			return ice
		&"lightning":
			return lightning
		&"earth":
			return earth
		_:
			return gold_muted


## Couleur de fond (sombre) associée à un élément.
func element_dark_color(element: StringName) -> Color:
	match element:
		&"fire":
			return fire_dark
		&"ice":
			return ice_dark
		&"lightning":
			return wood_dark.lightened(0.08).lerp(lightning, 0.22)
		&"earth":
			return earth_dark
		_:
			return wood_dark


## Couleur d'accent secondaire d'un élément.
func element_accent_color(element: StringName) -> Color:
	match element:
		&"fire":
			return gold_muted
		&"ice":
			return Color("d9f2f8")
		&"lightning":
			return lightning_accent
		&"earth":
			return earth_accent
		_:
			return copper_light


## Nom affichable FR d'un élément.
static func element_display_name(element: StringName) -> String:
	match element:
		&"fire":
			return "Feu"
		&"ice":
			return "Glace"
		&"lightning":
			return "Foudre"
		&"earth":
			return "Terre"
		_:
			return "Neutre"
