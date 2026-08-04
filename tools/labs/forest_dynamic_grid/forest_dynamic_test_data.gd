class_name ForestDynamicTestData
extends Resource

## Relief statique propre au laboratoire. Les cellules proviennent de la meme
## grille 14 x 14 ; aucune coordonnee pixel n'est stockee ici.

@export var segment_two: Array[Vector2i] = []
@export var segment_three: Array[Vector2i] = []
@export var isolated_walls: Array[Vector2i] = []


func all_static_wall_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append_array(segment_two)
	result.append_array(segment_three)
	result.append_array(isolated_walls)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if segment_two.size() != 2:
		errors.append("Le segment court doit couvrir exactement 2 cellules.")
	if segment_three.size() != 3:
		errors.append("Le segment long doit couvrir exactement 3 cellules.")
	if isolated_walls.is_empty():
		errors.append("Au moins un mur isole est requis.")
	var cells := all_static_wall_cells()
	if cells.size() < 4 or cells.size() > 8:
		errors.append("Le relief statique doit contenir entre 4 et 8 murs.")
	var unique := {}
	for cell in cells:
		if unique.has(cell):
			errors.append("Mur duplique : %s." % cell)
		unique[cell] = true
	return errors

