class_name GridTransformService
extends RefCounted

## Transformation affine partagee par le runtime, Arena Studio et les tests.
## Les axes representent les vecteurs centre-a-centre des deux directions de
## grille. Le losange d'une cellule est le parallelogramme des coefficients
## locaux compris entre -0.5 et +0.5.

const INVALID_CELL := Vector2i(-2147483648, -2147483648)
const RELATIVE_DETERMINANT_EPSILON := 0.00001
const HIT_EPSILON := 0.0001


static func determinant(axis_x: Vector2, axis_y: Vector2) -> float:
	return axis_x.x * axis_y.y - axis_y.x * axis_x.y


static func is_invertible(axis_x: Vector2, axis_y: Vector2) -> bool:
	var scale := maxf(axis_x.length() * axis_y.length(), 1.0)
	return absf(determinant(axis_x, axis_y)) > scale * RELATIVE_DETERMINANT_EPSILON


static func cell_to_position(
		cell: Vector2i,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2
	) -> Vector2:
	return origin + float(cell.x) * axis_x + float(cell.y) * axis_y


static func position_to_fractional(
		position: Vector2,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2
	) -> Vector2:
	var det := determinant(axis_x, axis_y)
	if not is_invertible(axis_x, axis_y):
		return Vector2(INF, INF)
	var local := position - origin
	return Vector2(
		(local.x * axis_y.y - axis_y.x * local.y) / det,
		(axis_x.x * local.y - local.x * axis_x.y) / det
	)


static func position_to_cell(
		position: Vector2,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2,
		logical_size: Vector2i = Vector2i.ZERO
	) -> Vector2i:
	var fractional := position_to_fractional(position, origin, axis_x, axis_y)
	if not is_finite(fractional.x) or not is_finite(fractional.y):
		return INVALID_CELL
	var candidate := Vector2i(roundi(fractional.x), roundi(fractional.y))
	if logical_size.x > 0 and logical_size.y > 0 and not is_cell_in_bounds(
		candidate, logical_size
	):
		return INVALID_CELL
	if not is_point_in_cell(position, candidate, origin, axis_x, axis_y):
		return INVALID_CELL
	return candidate


static func is_point_in_cell(
		position: Vector2,
		cell: Vector2i,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2
	) -> bool:
	var fractional := position_to_fractional(position, origin, axis_x, axis_y)
	if not is_finite(fractional.x) or not is_finite(fractional.y):
		return false
	return absf(fractional.x - float(cell.x)) <= 0.5 + HIT_EPSILON \
		and absf(fractional.y - float(cell.y)) <= 0.5 + HIT_EPSILON


static func cell_polygon(
		cell: Vector2i,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2
	) -> PackedVector2Array:
	var center := cell_to_position(cell, origin, axis_x, axis_y)
	return PackedVector2Array([
		center - 0.5 * axis_x - 0.5 * axis_y,
		center + 0.5 * axis_x - 0.5 * axis_y,
		center + 0.5 * axis_x + 0.5 * axis_y,
		center - 0.5 * axis_x + 0.5 * axis_y,
	])


static func is_cell_in_bounds(cell: Vector2i, logical_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 \
		and cell.x < logical_size.x and cell.y < logical_size.y


static func image_to_view(position: Vector2, pan: Vector2, zoom: float) -> Vector2:
	return pan + position * zoom


static func view_to_image(position: Vector2, pan: Vector2, zoom: float) -> Vector2:
	if absf(zoom) <= 0.000001:
		return Vector2(INF, INF)
	return (position - pan) / zoom


static func view_to_cell(
		view_position: Vector2,
		pan: Vector2,
		zoom: float,
		origin: Vector2,
		axis_x: Vector2,
		axis_y: Vector2,
		logical_size: Vector2i = Vector2i.ZERO
	) -> Vector2i:
	return position_to_cell(
		view_to_image(view_position, pan, zoom),
		origin,
		axis_x,
		axis_y,
		logical_size
	)


## Ajustement affine aux moindres carres de position = origine + x*axe_x +
## y*axe_y. Trois points non colineaires suffisent ; les points supplementaires
## reduisent l'erreur de mesure sans changer le modele runtime.
static func fit_affine(cells: Array, positions: Array) -> Dictionary:
	if cells.size() != positions.size() or cells.size() < 3:
		return {"ok": false, "error": "Au moins trois correspondances sont requises."}
	var normal := [
		[0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0],
		[0.0, 0.0, 0.0],
	]
	var rhs_x := Vector3.ZERO
	var rhs_y := Vector3.ZERO
	for index in range(cells.size()):
		if not cells[index] is Vector2i or not positions[index] is Vector2:
			return {"ok": false, "error": "Une correspondance est invalide."}
		var cell := cells[index] as Vector2i
		var position := positions[index] as Vector2
		var row := Vector3(1.0, float(cell.x), float(cell.y))
		for column in range(3):
			for other in range(3):
				normal[column][other] += row[column] * row[other]
		rhs_x += row * position.x
		rhs_y += row * position.y
	var solved_x := _solve_3x3(normal, rhs_x)
	var solved_y := _solve_3x3(normal, rhs_y)
	if not bool(solved_x.get("ok", false)) or not bool(solved_y.get("ok", false)):
		return {"ok": false, "error": "Les points de calibration sont colineaires."}
	var values_x: Vector3 = solved_x["value"]
	var values_y: Vector3 = solved_y["value"]
	var fitted_origin := Vector2(values_x.x, values_y.x)
	var fitted_axis_x := Vector2(values_x.y, values_y.y)
	var fitted_axis_y := Vector2(values_x.z, values_y.z)
	if not is_invertible(fitted_axis_x, fitted_axis_y):
		return {"ok": false, "error": "La transformation calculee n'est pas inversible."}
	var squared_error := 0.0
	var maximum_error := 0.0
	for index in range(cells.size()):
		var predicted := cell_to_position(
			cells[index], fitted_origin, fitted_axis_x, fitted_axis_y
		)
		var error := predicted.distance_to(positions[index])
		squared_error += error * error
		maximum_error = maxf(maximum_error, error)
	return {
		"ok": true,
		"origin": fitted_origin,
		"axis_x": fitted_axis_x,
		"axis_y": fitted_axis_y,
		"rms_error": sqrt(squared_error / float(cells.size())),
		"max_error": maximum_error,
	}


static func _solve_3x3(matrix: Array, rhs: Vector3) -> Dictionary:
	var augmented := []
	for row_index in range(3):
		augmented.append([
			float(matrix[row_index][0]),
			float(matrix[row_index][1]),
			float(matrix[row_index][2]),
			float(rhs[row_index]),
		])
	for pivot_index in range(3):
		var best := pivot_index
		for row_index in range(pivot_index + 1, 3):
			if absf(augmented[row_index][pivot_index]) \
					> absf(augmented[best][pivot_index]):
				best = row_index
		if absf(augmented[best][pivot_index]) <= 0.000001:
			return {"ok": false}
		if best != pivot_index:
			var temporary = augmented[pivot_index]
			augmented[pivot_index] = augmented[best]
			augmented[best] = temporary
		var pivot: float = augmented[pivot_index][pivot_index]
		for column in range(pivot_index, 4):
			augmented[pivot_index][column] /= pivot
		for row_index in range(3):
			if row_index == pivot_index:
				continue
			var factor: float = augmented[row_index][pivot_index]
			for column in range(pivot_index, 4):
				augmented[row_index][column] -= factor * augmented[pivot_index][column]
	return {
		"ok": true,
		"value": Vector3(augmented[0][3], augmented[1][3], augmented[2][3]),
	}
