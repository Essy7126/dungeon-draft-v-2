@tool
class_name EncounterMapPreview
extends Control

## Carte de rencontre (G4). Consultation par défaut : un clic ordinaire
## sélectionne une case sans jamais muter de donnée métier. Seul l'outil
## explicite « Modifier les cases interdites » autorise la mutation. La
## grille, les zones et les placements restent des projections de
## `RoomData` / `GridData` / `EncounterPreviewService` : aucune autorité
## seconde n'est introduite ici.

signal forbidden_cell_toggled(cell: Vector2i)
signal cell_selected(cell: Vector2i)
signal edit_mode_changed(active: bool)
signal zoom_changed(value: float)

## Grossissement du terrain. 1.0 = vue d'ensemble : tout le terrain tient dans
## le panneau. Dézoomer en dessous n'a donc aucun sens et la borne basse le dit.
const ZOOM_MIN := 1.0
const ZOOM_MAX := 6.0
const ZOOM_STEP := 1.25

var room: RoomData = null
var preview := {}
var grid: GridData = null
var selected_cell := Vector2i(-1, -1)
var hover_cell := Vector2i(-1, -1)
var edit_forbidden_mode := false
var show_distances := true
var show_grid := true
var show_zones := true
var show_placements := true
var show_legend := true
var _background_texture: Texture2D = null
var zoom := ZOOM_MIN
var _scale := 1.0
## Échelle qui fait tenir tout le terrain dans le panneau, avant grossissement.
var _fit_scale := 1.0
## Décalage de consultation, en pixels écran. Purement une préférence de vue :
## aucune donnée métier, jamais sérialisé dans le document.
var _pan := Vector2.ZERO
var _panning := false
var _offset := Vector2.ZERO
var _logical_rect := Rect2()


func _ready() -> void:
	# Zoomé, le terrain déborde du panneau : sans découpe il peindrait par-dessus
	# la navigation et les propriétés voisines.
	clip_contents = true
	_update_cursor()
	_update_tooltip()
	resized.connect(queue_redraw)


func set_context(value: RoomData, result: Dictionary) -> void:
	# Régénérer un placement ne doit pas défaire le cadrage choisi ; changer de
	# salle, si : le terrain précédent n'a plus rien à voir avec celui-ci.
	var room_changed := value != room
	room = value
	preview = result
	grid = result.get("grid") as GridData
	# Le terrain existe avant son premier affrontement. Le résultat de placement
	# est alors volontairement vide, mais la grille reste reconstructible depuis
	# le brouillon Terrain et doit continuer à être affichée.
	if grid == null and room != null:
		grid = EncounterGridFactory.build_from_room(room)
	_background_texture = null
	if room != null and room.painted_map_visual_data != null:
		_background_texture = room.painted_map_visual_data.load_background_texture()
	elif room != null:
		_background_texture = room.background_image
	if room_changed:
		reset_view()
	queue_redraw()


## Outil explicite : par défaut la carte est en consultation. `Échap`, un
## changement de salle/affrontement ou de navigation doivent aussi appeler
## cette fonction avec `false` pour ne jamais laisser l'édition active par
## accident. Ceci n'est qu'un état d'interface : aucun document n'est modifié.
func set_edit_mode(active: bool) -> void:
	if edit_forbidden_mode == active:
		return
	edit_forbidden_mode = active
	_update_cursor()
	_update_tooltip()
	edit_mode_changed.emit(edit_forbidden_mode)
	queue_redraw()


func get_cell_info_text(cell: Vector2i) -> String:
	if room == null or grid == null or not grid.is_valid(cell):
		return "Aucune case sélectionnée."
	var lines := PackedStringArray(["Case (%d, %d)" % [cell.x, cell.y]])
	lines.append("Type : %s" % EncounterPresentation.terrain_type_name(grid.get_type(cell)))
	var zone := "Aucune zone particulière"
	if room.hero_spawn_zone.has(cell):
		zone = "Zone de départ des héros"
	elif room.enemy_spawn_zone.has(cell):
		zone = "Zone préférée des ennemis"
	lines.append("Zone : %s" % zone)
	var encounter := _encounter()
	var forbidden := encounter != null and encounter.forbidden_initial_spawn_cells.has(cell)
	lines.append("Case interdite au déploiement ennemi : %s" % ("oui" if forbidden else "non"))
	for placement_value in preview.get("placements", []):
		var placement := placement_value as Dictionary
		if (placement.get("cell", Vector2i(-1, -1)) as Vector2i) == cell:
			lines.append("Ennemi placé : %s (n° %d)" % [
				str(placement.get("unit_name", "Unité")),
				int(placement.get("order", 0)) + 1,
			])
			break
	return "\n".join(lines)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.05), true)
	if room == null or grid == null:
		_draw_centered_message("Sélectionnez une salle et générez un placement.")
		return
	_configure_projection()
	if _background_texture != null:
		draw_texture_rect(
			_background_texture,
				Rect2(_offset + _logical_rect.position * _scale, _logical_rect.size * _scale),
				false,
				Color(0.82, 0.82, 0.82, 0.92),
			)
	if show_grid or show_zones:
		for y in grid.rows:
			for x in grid.cols:
				var cell := Vector2i(x, y)
				var polygon := _cell_polygon(cell)
				var type := grid.get_type(cell)
				var fill := _terrain_color(type) if show_grid else Color(0, 0, 0, 0)
				var zone_glyph := ""
				if show_zones and room.hero_spawn_zone.has(cell):
					fill = Color(0.12, 0.48, 1.0, 0.42)
					zone_glyph = "A"
				elif show_zones and room.enemy_spawn_zone.has(cell):
					fill = Color(1.0, 0.48, 0.08, 0.34)
					zone_glyph = "E"
				draw_colored_polygon(polygon, fill)
				if show_grid:
					_draw_outline(polygon, Color(0.68, 0.75, 0.82, 0.28), 1.0)
				if not zone_glyph.is_empty():
					_draw_zone_glyph(_cell_center(cell), zone_glyph)
	var encounter := _encounter()
	if show_zones and encounter != null:
		for cell in encounter.forbidden_initial_spawn_cells:
			if not grid.is_valid(cell):
				continue
			var polygon := _cell_polygon(cell)
			draw_colored_polygon(polygon, Color(0.9, 0.08, 0.08, 0.42))
			draw_line(polygon[0], polygon[2], Color(1.0, 0.35, 0.35), 2.0)
			draw_line(polygon[1], polygon[3], Color(1.0, 0.35, 0.35), 2.0)
	if show_placements:
		for placement_value in preview.get("placements", []):
			var placement := placement_value as Dictionary
			var cell := placement.get("cell", Vector2i(-1, -1)) as Vector2i
			if not grid.is_valid(cell):
				continue
			var center := _cell_center(cell)
			# Aucune validité par case n'existe dans les données : le marqueur
			# reste un vert normal, y compris quand le placement global échoue.
			# L'échec global est annoncé séparément (bandeau dédié).
			var color := Color(0.24, 0.95, 0.54)
			draw_circle(center, clampf(12.0 * _scale, 7.0, 17.0), color, true)
			draw_circle(center, clampf(12.0 * _scale, 7.0, 17.0), Color.WHITE, false, 1.5)
			var marker := "%d" % (int(placement.get("order", 0)) + 1)
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-4, 5),
				marker,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color(0.02, 0.04, 0.03),
			)
	if show_distances:
		_draw_distance_legend()
	if hover_cell != Vector2i(-1, -1) and hover_cell != selected_cell and grid.is_valid(hover_cell):
		_draw_outline(_cell_polygon(hover_cell), Color(0.95, 0.97, 1.0, 0.85), 2.0)
	if selected_cell != Vector2i(-1, -1) and grid.is_valid(selected_cell):
		_draw_outline(_cell_polygon(selected_cell), Color(1.0, 0.86, 0.15), 3.0)
	if show_legend:
		_draw_legend()
	if not preview.is_empty() and encounter != null and not bool(preview.get("valid", false)):
		_draw_failure_banner()
	if encounter == null:
		_draw_empty_encounter_message()
	if edit_forbidden_mode:
		_draw_edit_mode_banner()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if _panning:
			_pan += event.relative
			queue_redraw()
			accept_event()
			return
		var cell := _position_to_cell(event.position)
		if cell != hover_cell:
			hover_cell = cell
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# La molette zoome sur le curseur. Le panneau n'est pas défilable : aucun
		# défilement n'est volé à un parent.
		zoom_at(event.position, ZOOM_STEP \
			if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		accept_event()
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_MIDDLE:
		# Déplacement au clic milieu : le clic gauche reste la sélection de case,
		# et l'outil des cases interdites garde son geste intact.
		_panning = event.pressed
		mouse_default_cursor_shape = Control.CURSOR_DRAG if _panning else (
			Control.CURSOR_CROSS if edit_forbidden_mode else Control.CURSOR_ARROW
		)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var cell := _position_to_cell(event.position)
		if grid == null or not grid.is_valid(cell):
			return
		selected_cell = cell
		cell_selected.emit(cell)
		if edit_forbidden_mode and grid.is_walkable(cell):
			forbidden_cell_toggled.emit(cell)
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if edit_forbidden_mode and event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		set_edit_mode(false)
		get_viewport().set_input_as_handled()


func visual_snapshot() -> Dictionary:
	return {
		"size": size,
		"grid_size": Vector2i(grid.cols, grid.rows) if grid != null else Vector2i.ZERO,
		"placement_count": (preview.get("placements", []) as Array).size(),
		"valid": preview.get("valid", false),
		"has_room": room != null,
	}


func _configure_projection() -> void:
	var padding := 20.0
	var visual := room.painted_map_visual_data
	if visual != null:
		_logical_rect = visual.image_rect()
	else:
		_logical_rect = Rect2(Vector2.ZERO, Vector2(grid.cols, grid.rows) * 48.0)
	if _logical_rect.size.x <= 0.0 or _logical_rect.size.y <= 0.0:
		_logical_rect = Rect2(Vector2.ZERO, Vector2.ONE)
	_fit_scale = minf(
		maxf(0.01, (size.x - padding * 2.0) / _logical_rect.size.x),
		maxf(0.01, (size.y - padding * 2.0) / _logical_rect.size.y),
	)
	_scale = _fit_scale * zoom
	var content := _logical_rect.size * _scale
	_pan = _clamped_pan(_pan, content)
	_offset = (size - content) * 0.5 - _logical_rect.position * _scale + _pan


## Le terrain ne doit jamais pouvoir être traîné hors du panneau : sur un axe où
## il est plus petit que le panneau il reste centré, sinon il ne peut pas
## décoller du bord correspondant.
func _clamped_pan(value: Vector2, content: Vector2) -> Vector2:
	var limit := ((content - size) * 0.5).max(Vector2.ZERO)
	return value.clamp(-limit, limit)


## Grossit ou réduit en gardant fixe le point du terrain sous `screen_position`.
## C'est la seule façon d'explorer une grande carte sans perdre le repère qu'on
## visait ; un zoom centré sur le panneau ferait fuir la zone regardée.
func zoom_at(screen_position: Vector2, factor: float) -> void:
	if room == null or grid == null:
		return
	var target := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(target, zoom):
		return
	_configure_projection()
	var logical := (screen_position - _offset) / _scale
	zoom = target
	_configure_projection()
	_pan += screen_position - (_offset + logical * _scale)
	_configure_projection()
	zoom_changed.emit(zoom)
	queue_redraw()


## Zoom depuis un bouton : le centre du panneau est le seul point de référence
## disponible quand le geste ne vient pas de la souris.
func zoom_by(factor: float) -> void:
	zoom_at(size * 0.5, factor)


## Revient à la vue d'ensemble : tout le terrain visible, recentré.
func reset_view() -> void:
	var changed := not is_equal_approx(zoom, ZOOM_MIN) or _pan != Vector2.ZERO
	zoom = ZOOM_MIN
	_pan = Vector2.ZERO
	_panning = false
	if changed:
		zoom_changed.emit(zoom)
	queue_redraw()


func _cell_center(cell: Vector2i) -> Vector2:
	var visual := room.painted_map_visual_data
	if visual != null:
		return _offset + visual.cell_to_image(cell) * _scale
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	return _offset + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size * _scale


func _cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var visual := room.painted_map_visual_data
	var result := PackedVector2Array()
	if visual != null:
		for point in visual.cell_polygon(cell):
			result.append(_offset + point * _scale)
		return result
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	var position := _offset + Vector2(cell) * cell_size * _scale
	var scaled_size := cell_size * _scale
	return PackedVector2Array([
		position,
		position + Vector2(scaled_size.x, 0),
		position + scaled_size,
		position + Vector2(0, scaled_size.y),
	])


func _position_to_cell(position: Vector2) -> Vector2i:
	if room == null or grid == null:
		return Vector2i(-1, -1)
	var logical := (position - _offset) / _scale
	if room.painted_map_visual_data != null:
		return room.painted_map_visual_data.image_to_cell(logical)
	var cell_size := _logical_rect.size / Vector2(grid.cols, grid.rows)
	return Vector2i(floori(logical.x / cell_size.x), floori(logical.y / cell_size.y))


func _encounter() -> EncounterDefinition:
	if room == null:
		return null
	var wave_index := int(preview.get("wave_index", 0))
	return room.get_encounter_for_wave(wave_index)


func _terrain_color(type: GridData.CellType) -> Color:
	match type:
		GridData.CellType.WALL: return Color(0.2, 0.22, 0.25, 0.72)
		GridData.CellType.HOLE: return Color(0.02, 0.02, 0.025, 0.8)
		GridData.CellType.LAVA: return Color(0.94, 0.2, 0.04, 0.48)
		GridData.CellType.ICE: return Color(0.42, 0.82, 1.0, 0.4)
		GridData.CellType.SHADOW: return Color(0.3, 0.16, 0.48, 0.55)
		GridData.CellType.RUNE: return Color(0.64, 0.2, 0.92, 0.5)
	return Color(0.12, 0.18, 0.2, 0.28)


func _draw_outline(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.is_empty():
		return
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _draw_zone_glyph(center: Vector2, glyph: String) -> void:
	draw_string(
		ThemeDB.fallback_font, center + Vector2(-4, 4), glyph,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1.0, 1.0, 1.0, 0.8)
	)


func _draw_centered_message(message: String) -> void:
	draw_string(
		ThemeDB.fallback_font, size * 0.5 - Vector2(180, 0), message,
		HORIZONTAL_ALIGNMENT_CENTER, 360, 16, Color(0.72, 0.78, 0.86)
	)


func _draw_empty_encounter_message() -> void:
	var panel_size := Vector2(minf(520.0, size.x - 40.0), 58.0)
	var panel_position := Vector2((size.x - panel_size.x) * 0.5, 16.0)
	draw_rect(
		Rect2(panel_position, panel_size), Color(0.015, 0.025, 0.04, 0.9), true
	)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(12.0, 23.0),
		"Terrain de la salle affiché en lecture seule",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x - 24.0,
		15,
		Color(0.55, 0.86, 1.0),
	)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(12.0, 45.0),
		"Créez le premier affrontement pour ajouter des ennemis.",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_size.x - 24.0,
		13,
		Color(0.9, 0.93, 0.96),
	)


func _draw_failure_banner() -> void:
	var panel_size := Vector2(minf(420.0, size.x - 40.0), 30.0)
	var panel_position := Vector2((size.x - panel_size.x) * 0.5, size.y - 80.0)
	draw_rect(Rect2(panel_position, panel_size), Color(0.32, 0.06, 0.06, 0.92), true)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(10.0, 20.0),
		"Placement impossible pour cette valeur de départ — voir Analyse ou Placement.",
		HORIZONTAL_ALIGNMENT_LEFT,
		panel_size.x - 20.0,
		12,
		Color(1.0, 0.75, 0.7),
	)


func _draw_edit_mode_banner() -> void:
	var text := "Modification des cases interdites active — cliquez une case praticable, Échap pour arrêter"
	var panel_width := minf(size.x - 16.0, 620.0)
	draw_rect(Rect2(8, 8, panel_width, 24), Color(0.36, 0.18, 0.02, 0.92), true)
	draw_string(ThemeDB.fallback_font, Vector2(16, 25), text, HORIZONTAL_ALIGNMENT_LEFT, panel_width - 16, 12, Color(1.0, 0.86, 0.6))


func _draw_legend() -> void:
	if size.x < 400.0:
		var compact_lines := legend_lines_for_width(size.x)
		var compact_width := size.x - 16.0
		draw_rect(Rect2(8, size.y - 50, compact_width, 44),
			Color(0.02, 0.03, 0.05, 0.94), true)
		for index in compact_lines.size():
			draw_string(ThemeDB.fallback_font,
				Vector2(14, size.y - 37 + index * 14), compact_lines[index],
				HORIZONTAL_ALIGNMENT_LEFT, compact_width - 12.0, 10,
				Color(0.9, 0.93, 0.96))
		return
	var first_line := "Bleu « A » : zone alliée  •  Orange « E » : zone ennemie  •  Rouge (croix) : case interdite"
	var second_line := "Vert numéroté : ennemi placé  •  Contour blanc : survol  •  Contour jaune : sélection"
	var panel_width := minf(size.x - 16.0, 720.0)
	draw_rect(Rect2(8, size.y - 44, panel_width, 38), Color(0.02, 0.03, 0.05, 0.92), true)
	draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 28), first_line,
		HORIZONTAL_ALIGNMENT_LEFT, panel_width - 16.0, 12, Color(0.9, 0.93, 0.96))
	draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 12), second_line,
		HORIZONTAL_ALIGNMENT_LEFT, panel_width - 16.0, 12, Color(0.9, 0.93, 0.96))


static func legend_lines_for_width(width: float) -> PackedStringArray:
	if width < 400.0:
		return PackedStringArray([
			"Bleu « A » : zone alliée • Orange « E » : zone ennemie",
			"Rouge × : case interdite • Vert n° : ennemi placé",
			"Contour blanc : survol • Contour jaune : sélection",
		])
	return PackedStringArray([
		"Bleu « A » : zone alliée • Orange « E » : zone ennemie • Rouge (croix) : case interdite",
		"Vert numéroté : ennemi placé • Contour blanc : survol • Contour jaune : sélection",
	])


func _draw_distance_legend() -> void:
	var placements := preview.get("placements", []) as Array
	if placements.is_empty():
		return
	var row_height := 15.0
	var panel_width := minf(250.0, size.x * 0.42)
	var panel_height := 8.0 + row_height * placements.size()
	draw_rect(
		Rect2(8, 8, panel_width, panel_height),
		Color(0.015, 0.025, 0.04, 0.88), true
	)
	for placement_value in placements:
		var placement := placement_value as Dictionary
		var order := int(placement.get("order", 0))
		var unit := placement.get("unit_data") as UnitData
		var text := "%d. %s  •  distance %d" % [
			order + 1,
			unit.unit_name if unit != null else "Unité absente",
			int(placement.get("distance_to_ally_deployment", -1)),
		]
		draw_string(
			ThemeDB.fallback_font,
			Vector2(14, 22 + order * row_height),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			panel_width - 12,
			11,
			Color(1.0, 1.0, 0.84),
		)


func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS if edit_forbidden_mode \
		else Control.CURSOR_ARROW


func _update_tooltip() -> void:
	var navigation := (
		"\nMolette : zoomer sur le curseur • Clic milieu maintenu : déplacer la vue."
	)
	tooltip_text = ((
		"Outil actif : cliquez une case praticable pour l'ajouter ou la retirer "
		+ "des cases interdites au déploiement ennemi. Échap pour arrêter."
	) if edit_forbidden_mode else (
		"Cliquez une case pour voir son résumé. Activez « Modifier les cases "
		+ "interdites » pour éditer le déploiement ennemi."
	)) + navigation
