class_name CharacterHUDThemeCatalog
extends RefCounted

const REFINED_THEMES: Array[CharacterHUDThemeData] = [
	preload("res://data/ui/elf_hud_theme_refined.tres"),
	preload("res://data/ui/mage_hud_theme_refined.tres"),
	preload("res://data/ui/warrior_hud_theme_refined.tres"),
	preload("res://data/ui/achilles_hud_theme_refined.tres"),
]


static func get_refined_themes() -> Array[CharacterHUDThemeData]:
	return REFINED_THEMES.duplicate()


static func resolve_refined(unit) -> CharacterHUDThemeData:
	if unit == null:
		return null
	for theme in REFINED_THEMES:
		if theme != null and theme.matches_unit(unit):
			return with_presentation_overrides(theme, unit)
	return null


static func with_presentation_overrides(theme: CharacterHUDThemeData, unit) -> CharacterHUDThemeData:
	if theme == null or unit == null:
		return theme
	var portrait := unit.get("portrait_texture_override") as Texture2D
	if portrait == null:
		return theme
	var presentation := theme.duplicate(false) as CharacterHUDThemeData
	presentation.set_path_cache("")
	presentation.portrait_texture = portrait
	return presentation
