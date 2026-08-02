extends "res://battle/battle.gd"

## Adaptateur strictement local de la salle blockout.
## Battle construit toujours GridData, Pathfinder, TerrainEffects et les
## overlays ; seule l'importation initiale du layout est specialisee ici.

@export var blockout_data: MountainPassBlockoutData = preload(
	"res://data/maps/mountain_pass_blockout.tres"
)


func _ready() -> void:
	if blockout_data != null:
		grid_cols = blockout_data.logical_size.x
		grid_rows = blockout_data.logical_size.y
	super._ready()


func _import_terrain_from_tilemap() -> void:
	if blockout_data == null or grid == null:
		push_error("MountainPassBattle requiert sa ressource de blockout.")
		return
	blockout_data.apply_to_grid(grid)
