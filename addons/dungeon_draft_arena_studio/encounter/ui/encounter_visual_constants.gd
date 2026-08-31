@tool
class_name EncounterVisualConstants
extends RefCounted

## G6 — système visuel local du Studio de rencontres : un seul endroit pour
## les couleurs sémantiques, espacements et tailles réutilisés par les cartes
## et boutons de ce Studio. N'affecte aucun autre Studio (Terrain, Objets,
## Compétences, VFX) : chacun garde ses propres constantes.
##
## Les couleurs de gravité sont les mêmes que celles déjà utilisées par la
## carte G4 (case interdite, sélection) pour rester cohérentes avec le
## glossaire visuel existant — voir EncounterPresentation.TERRAIN_TYPE_LABELS
## pour le pendant textuel de ces couleurs fonctionnelles.

## --- Couleurs sémantiques ----------------------------------------------------

const SEVERITY_COLORS := {
	0: Color(1.0, 0.36, 0.32),  # StudioValidationMessage.Severity.ERROR
	1: Color(1.0, 0.76, 0.3),   # StudioValidationMessage.Severity.WARNING
	2: Color(0.58, 0.82, 1.0),  # StudioValidationMessage.Severity.INFO
}
const COLOR_SUCCESS := Color(0.6, 0.9, 0.6)
const COLOR_MUTED := Color(0.72, 0.77, 0.84)
const COLOR_DESTRUCTIVE := Color(1.0, 0.45, 0.42)
const COLOR_DESTRUCTIVE_BORDER := Color(0.75, 0.28, 0.26)

## --- Espacements (px) ---------------------------------------------------------

const SPACING_TIGHT := 4
const SPACING_NORMAL := 8
const SPACING_LOOSE := 12

## --- Contrôles ------------------------------------------------------------

## Hauteur minimale commune à tous les boutons du Studio de rencontres : évite
## les boutons de hauteurs incohérentes sur une même barre ou une même carte,
## et garde une zone cliquable confortable pour une interface de bureau.
const BUTTON_MIN_HEIGHT := 32
const CARD_CORNER_RADIUS := 4

## --- Typographie ------------------------------------------------------------

const FONT_SIZE_CARD_TITLE := 16
const FONT_SIZE_SECTION := 14


static func severity_color(severity: int) -> Color:
	return SEVERITY_COLORS.get(severity, Color.WHITE)


## Style discret pour une action destructrice (Supprimer, Retirer...) :
## identifiable par sa couleur de texte, sans dominer l'écran — aucun fond
## plein, aucune taille agrandie, la hiérarchie reste celle du texte.
static func apply_destructive_style(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_DESTRUCTIVE)
	button.add_theme_color_override("font_hover_color", COLOR_DESTRUCTIVE)
	button.add_theme_color_override("font_focus_color", COLOR_DESTRUCTIVE)
