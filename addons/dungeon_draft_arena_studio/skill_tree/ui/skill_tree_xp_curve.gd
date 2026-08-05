@tool
class_name SkillTreeXpCurve
extends Control

var discipline: DisciplineData = null


func _ready() -> void:
	custom_minimum_size = Vector2(420, 115)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_discipline(value: DisciplineData) -> void:
	discipline = value
	queue_redraw()


func _draw() -> void:
	var ranks := _sorted_ranks()
	if ranks.is_empty():
		return
	var margin := Vector2(34.0, 18.0)
	var area := Rect2(margin, size - margin - Vector2(16.0, 24.0))
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	draw_line(area.position, Vector2(area.position.x, area.end.y), Color(0.42, 0.47, 0.54), 1.0)
	draw_line(Vector2(area.position.x, area.end.y), area.end, Color(0.42, 0.47, 0.54), 1.0)
	var maximum_xp := 1
	for rank_data in ranks:
		maximum_xp = maxi(maximum_xp, rank_data.required_total_xp)
	var points := PackedVector2Array()
	for index in range(ranks.size()):
		var rank_data := ranks[index]
		var ratio_x := float(index) / float(maxi(1, ranks.size() - 1))
		var ratio_y := float(rank_data.required_total_xp) / float(maximum_xp)
		var point := Vector2(
			lerpf(area.position.x, area.end.x, ratio_x),
			lerpf(area.end.y, area.position.y, ratio_y)
		)
		points.append(point)
	if points.size() >= 2:
		draw_polyline(points, Color(0.34, 0.78, 1.0), 3.0, true)
	for index in range(points.size()):
		var point := points[index]
		var rank_data := ranks[index]
		draw_circle(point, 4.5, Color(0.95, 0.76, 0.27))
		draw_string(
			get_theme_default_font(),
			point + Vector2(-12.0, 18.0),
			"R%d" % rank_data.rank,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			11,
			Color(0.78, 0.82, 0.88)
		)
		draw_string(
			get_theme_default_font(),
			point + Vector2(7.0, -5.0),
			"%d" % rank_data.required_total_xp,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			11,
			Color(0.95, 0.76, 0.27)
		)


func _sorted_ranks() -> Array[DisciplineRankData]:
	var result: Array[DisciplineRankData] = []
	if discipline != null:
		for rank_data in discipline.ranks:
			if rank_data != null:
				result.append(rank_data)
	result.sort_custom(func(a: DisciplineRankData, b: DisciplineRankData) -> bool:
		return a.rank < b.rank
	)
	return result
