class_name DisciplineData
extends Resource

@export var discipline_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null
@export var presentation_color: Color = Color.WHITE
@export var ranks: Array[DisciplineRankData] = []
