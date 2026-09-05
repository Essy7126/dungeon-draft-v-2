class_name DisciplineData
extends Resource

enum ProgressionMode {
	LEGACY_RANK_XP,
	MASTERY_POINTS,
}

@export var discipline_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var presentation_color: Color = Color.WHITE
## Le mode legacy reste la valeur par defaut pour toutes les donnees existantes.
## Odyssey utilise MASTERY_POINTS sans detourner les seuils XP des autres heros.
@export var progression_mode: ProgressionMode = ProgressionMode.LEGACY_RANK_XP
@export var ranks: Array[DisciplineRankData] = []
