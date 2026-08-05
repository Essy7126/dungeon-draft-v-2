class_name GridTransformService
extends RefCounted

## Transformation affine partagee par le runtime, Arena Studio et les tests.
## Les axes representent les vecteurs centre-a-centre des deux directions de
## grille. Le losange d'une cellule est le parallelogramme des coefficients
## locaux compris entre -0.5 et +0.5.

const INVALID_CELL := Vector2i(-2147483648, -2147483648)
const RELATIVE_DETERMINANT_EPSILON := 0.00001
const MIN_AXIS_LENGTH := 0.01
const MIN_SCALE_FACTOR := 0.01
const MAX_SCALE_FACTOR := 100.0
const HIT_EPSILON := 0.0001
const ANCHOR_CONDITION_RATIO_EPSILON := 0.000001
const QUALITY_EXCELLENT_RMS := 1.0
const QUALITY_ACCEPTABLE_RMS := 3.0


static func determinant(axis_x: Vector2, axis_y: Vector2) -> float:
	return axis_x.x * axis_y.y - axis_y.x * axis_x.y


static func is_invertible(axis_x: Vector2, axis_y: Vector2) -> bool:
	if not is_vector_finite(axis_x) or not is_vector_finite(axis_y):
		return false
	if axis_x.length() < MIN_AXIS_LENGTH or axis_y.length() < MIN_AXIS_LENGTH:
		return false
	return relative_determinant(axis_x, axis_y) > RELATIVE_DETERMINANT_EPSILON


static func relative_determinant(axis_x: Vector2, axis_y: Vector2) -> float:
	var length_product := axis_x.length() * axis_y.length()
	if not is_finite(length_product) or length_product <= 0.0:
		return 0.0
	return absf(determinant(axis_x, axis_y)) / length_product


static func is_vector_finite(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func validate_snapshot(
		snapshot: GridTransformSnapshot,
		expected_orientation := 0.0
	) -> Dictionary:
	if snapshot == null:
		return {"ok": false, "error": "La transformation est absente."}
	if not is_vector_finite(snapshot.origin):
		return {"ok": false, "error": "L'origine contient une valeur non finie."}
	if not is_vector_finite(snapshot.axis_x) or not is_vector_finite(snapshot.axis_y):
		return {"ok": false, "error": "Un axe contient une valeur non finie."}
	if snapshot.axis_x.length() < MIN_AXIS_LENGTH:
		return {"ok": false, "error": "L'axe droit est presque nul."}
	if snapshot.axis_y.length() < MIN_AXIS_LENGTH:
		return {"ok": false, "error": "L'axe gauche est presque nul."}
	var relative := relative_determinant(snapshot.axis_x, snapshot.axis_y)
	if relative <= RELATIVE_DETERMINANT_EPSILON:
		return {
			"ok": false,
			"error": "Les axes sont presque colineaires.",
			"relative_determinant": relative,
		}
	var orientation := signf(determinant(snapshot.axis_x, snapshot.axis_y))
	if expected_orientation != 0.0 and orientation != signf(expected_orientation):
		return {"ok": false, "error": "La transformation inverserait la grille."}
	return {
		"ok": true,
		"determinant": determinant(snapshot.axis_x, snapshot.axis_y),
		"relative_determinant": relative,
	}


static func translate(snapshot: GridTransformSnapshot, delta: Vector2) -> GridTransformSnapshot:
	var result := snapshot.copy()
	result.origin += delta
	return result


static func rotate_around(
		snapshot: GridTransformSnapshot,
		pivot: Vector2,
		angle: float
	) -> GridTransformSnapshot:
	var result := snapshot.copy()
	result.origin = pivot + (snapshot.origin - pivot).rotated(angle)
	result.axis_x = snapshot.axis_x.rotated(angle)
	result.axis_y = snapshot.axis_y.rotated(angle)
	return result


static func scale_around(
		snapshot: GridTransformSnapshot,
		pivot: Vector2,
		factor: float
	) -> GridTransformSnapshot:
	var safe_factor := clampf(factor, MIN_SCALE_FACTOR, MAX_SCALE_FACTOR)
	var result := snapshot.copy()
	result.origin = pivot + (snapshot.origin - pivot) * safe_factor
	result.axis_x = snapshot.axis_x * safe_factor
	result.axis_y = snapshot.axis_y * safe_factor
	return result


static func set_axis_x(
		snapshot: GridTransformSnapshot,
		value: Vector2
	) -> GridTransformSnapshot:
	var result := snapshot.copy()
	result.axis_x = value
	return result


static func set_axis_y(
		snapshot: GridTransformSnapshot,
		value: Vector2
	) -> GridTransformSnapshot:
	var result := snapshot.copy()
	result.axis_y = value
	return result


static func transform_axis_x_from_handle(
		snapshot: GridTransformSnapshot,
		handle_image_position: Vector2,
		preserve_length := false
	) -> GridTransformSnapshot:
	var value := handle_image_position - snapshot.origin
	if preserve_length and value.length() > 0.0:
		value = value.normalized() * snapshot.axis_x.length()
	return set_axis_x(snapshot, value)


static func transform_axis_y_from_handle(
		snapshot: GridTransformSnapshot,
		handle_image_position: Vector2,
		preserve_length := false
	) -> GridTransformSnapshot:
	var value := handle_image_position - snapshot.origin
	if preserve_length and value.length() > 0.0:
		value = value.normalized() * snapshot.axis_y.length()
	return set_axis_y(snapshot, value)


static func mirror_axis_across_bisector(axis: Vector2, bisector: Vector2) -> Vector2:
	if bisector.length() < MIN_AXIS_LENGTH:
		return axis
	var direction := bisector.normalized()
	return 2.0 * direction * axis.dot(direction) - axis


static func logical_grid_center(
		snapshot: GridTransformSnapshot,
		logical_size: Vector2i
	) -> Vector2:
	return snapshot.origin \
		+ (float(logical_size.x) - 1.0) * 0.5 * snapshot.axis_x \
		+ (float(logical_size.y) - 1.0) * 0.5 * snapshot.axis_y


static func grid_bounds(
		snapshot: GridTransformSnapshot,
		logical_size: Vector2i
	) -> Rect2:
	if snapshot == null or logical_size.x <= 0 or logical_size.y <= 0:
		return Rect2(snapshot.origin if snapshot != null else Vector2.ZERO, Vector2.ZERO)
	var corners := PackedVector2Array([
		snapshot.origin - 0.5 * snapshot.axis_x - 0.5 * snapshot.axis_y,
		snapshot.origin + (float(logical_size.x) - 0.5) * snapshot.axis_x - 0.5 * snapshot.axis_y,
		snapshot.origin - 0.5 * snapshot.axis_x + (float(logical_size.y) - 0.5) * snapshot.axis_y,
		snapshot.origin + (float(logical_size.x) - 0.5) * snapshot.axis_x \
			+ (float(logical_size.y) - 0.5) * snapshot.axis_y,
	])
	var minimum := corners[0]
	var maximum := corners[0]
	for point in corners:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func snap_position(value: Vector2, step := 1.0) -> Vector2:
	if step <= 0.0:
		return value
	return Vector2(snappedf(value.x, step), snappedf(value.y, step))


static func snap_angle(value: float, step_radians := deg_to_rad(1.0)) -> float:
	return snappedf(value, step_radians) if step_radians > 0.0 else value


static func snap_scale(value: float, step := 0.01) -> float:
	return snappedf(value, step) if step > 0.0 else value


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


## Conversion explicite du repere pixel natif de la ressource vers l'ecran.
## image_offset/image_scale appartiennent au placement de l'image ; pan/zoom
## appartiennent au viewport. Les deltas n'appliquent jamais les translations.
static func image_native_to_screen(
		position: Vector2,
		image_offset: Vector2,
		image_scale: Vector2,
		pan: Vector2,
		zoom: float
	) -> Vector2:
	return pan + (image_offset + position * image_scale) * zoom


static func screen_to_image_native(
		position: Vector2,
		image_offset: Vector2,
		image_scale: Vector2,
		pan: Vector2,
		zoom: float
	) -> Vector2:
	if absf(zoom) <= 0.000001 \
			or absf(image_scale.x) <= 0.000001 \
			or absf(image_scale.y) <= 0.000001:
		return Vector2(INF, INF)
	return ((position - pan) / zoom - image_offset) / image_scale


static func image_native_delta_from_screen_delta(
		delta: Vector2,
		image_scale: Vector2,
		zoom: float
	) -> Vector2:
	if absf(zoom) <= 0.000001 \
			or absf(image_scale.x) <= 0.000001 \
			or absf(image_scale.y) <= 0.000001:
		return Vector2(INF, INF)
	return delta / (image_scale * zoom)


static func screen_handle_radius_to_image_radius(
		radius: float,
		image_scale: Vector2,
		zoom: float
	) -> float:
	var minimum_scale := minf(absf(image_scale.x), absf(image_scale.y))
	if minimum_scale <= 0.000001 or absf(zoom) <= 0.000001:
		return INF
	return radius / (minimum_scale * absf(zoom))


static func calibration_quality(rms_error: float, anchor_count: int) -> StringName:
	if anchor_count < 3 or not is_finite(rms_error):
		return &"insufficient"
	if rms_error <= QUALITY_EXCELLENT_RMS:
		return &"excellent"
	if rms_error <= QUALITY_ACCEPTABLE_RMS:
		return &"acceptable"
	return &"check"


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
static func fit_affine(
		cells: Array,
		positions: Array,
		logical_size := Vector2i.ZERO
	) -> Dictionary:
	if cells.size() != positions.size() or cells.size() < 3:
		return {"ok": false, "error": "Au moins trois correspondances sont requises."}
	var unique_cells := {}
	var minimum_cell := Vector2(INF, INF)
	var maximum_cell := Vector2(-INF, -INF)
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
		if logical_size.x > 0 and logical_size.y > 0 \
				and not is_cell_in_bounds(cell, logical_size):
			return {"ok": false, "error": "Une ancre se trouve hors de la grille."}
		if not is_vector_finite(position):
			return {"ok": false, "error": "Une position d'ancre n'est pas finie."}
		if unique_cells.has(cell):
			return {"ok": false, "error": "Deux ancres ciblent la meme cellule."}
		unique_cells[cell] = true
		minimum_cell = minimum_cell.min(Vector2(cell))
		maximum_cell = maximum_cell.max(Vector2(cell))
		var row := Vector3(1.0, float(cell.x), float(cell.y))
		for column in range(3):
			for other in range(3):
				normal[column][other] += row[column] * row[other]
		rhs_x += row * position.x
		rhs_y += row * position.y
	var condition_ratio := _anchor_condition_ratio(cells)
	if condition_ratio <= ANCHOR_CONDITION_RATIO_EPSILON:
		return {
			"ok": false,
			"error": "Les ancres sont colineaires ou trop mal reparties.",
			"condition_ratio": condition_ratio,
		}
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
		"anchor_spread": maximum_cell - minimum_cell,
		"anchor_count": cells.size(),
		"condition_ratio": condition_ratio,
	}


static func _anchor_condition_ratio(cells: Array) -> float:
	if cells.size() < 3:
		return 0.0
	var mean := Vector2.ZERO
	for cell in cells:
		mean += Vector2(cell)
	mean /= float(cells.size())
	var xx := 0.0
	var xy := 0.0
	var yy := 0.0
	for cell in cells:
		var delta := Vector2(cell) - mean
		xx += delta.x * delta.x
		xy += delta.x * delta.y
		yy += delta.y * delta.y
	var trace := xx + yy
	if trace <= 0.0 or not is_finite(trace):
		return 0.0
	var discriminant := sqrt(maxf(
		(xx - yy) * (xx - yy) + 4.0 * xy * xy,
		0.0
	))
	var largest := 0.5 * (trace + discriminant)
	var smallest := 0.5 * (trace - discriminant)
	return maxf(smallest, 0.0) / maxf(largest, 0.000000000001)


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
