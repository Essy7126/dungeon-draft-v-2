class_name ArchivistPanel
extends Control

signal trade_requested
signal run_requested(run_data: RunData, start_room_index: int)
signal closed
signal dialogue_opened

const ARCHIVIST_TITLE_FR := "ARCHIVISTE DES LANTERNES"
const ODYSSEY_RUN_PATH := "res://data/runs/odyssey.tres"
const ODYSSEY_PROFILE_ID: StringName = &"odyssey"
const ODYSSEY_ILLUSTRATION := preload(
	"res://asset/map/painted/greece/map2-_achilles.png"
)
const ACHILLES_PORTRAIT := preload(
	"res://assets/characters/Achilles/processed/idle_00.png"
)

@onready var title_label: Label = %Title
@onready var panel: PanelContainer = %Panel
@onready var panel_margin: MarginContainer = %Margin
@onready var panel_content: VBoxContainer = %Content
@onready var main_menu: VBoxContainer = %MainMenu
@onready var dialogue_view: VBoxContainer = %DialogueView
@onready var dialogue_label: Label = %DialogueText
@onready var room_selection_view: VBoxContainer = %RoomSelectionView
@onready var run_selector: OptionButton = %RunSelector
@onready var room_selection_label: Label = %RoomSelectionLabel
@onready var room_selector: OptionButton = %RoomSelector
@onready var run_dossier: PanelContainer = %RunDossier
@onready var dossier_body: HBoxContainer = %DossierBody
@onready var run_illustration: TextureRect = %RunIllustration
@onready var illustration_fallback: Control = %IllustrationFallback
@onready var illustration_title: Label = %IllustrationTitle
@onready var illustration_subtitle: Label = %IllustrationSubtitle
@onready var dossier_eyebrow: Label = %DossierEyebrow
@onready var run_display_name: Label = %RunDisplayName
@onready var run_summary: Label = %RunSummary
@onready var run_meta: Label = %RunMeta
@onready var hero_portrait: TextureRect = %HeroPortrait
@onready var hero_glyph: Label = %HeroGlyph
@onready var hero_badge: Label = %HeroBadge
@onready var hero_name: Label = %HeroName
@onready var hero_role: Label = %HeroRole
@onready var hero_stats: Label = %HeroStats
@onready var flow_combat: Label = %FlowCombat
@onready var flow_reward: Label = %FlowReward
@onready var flow_next_room: Label = %FlowNextRoom
@onready var start_room_row: HBoxContainer = %StartRoomRow
@onready var confirm_run_button: Button = %ConfirmRunButton

var data: LanternboundArchivistData = null
var _available_runs: Array[RunData] = []
var _odyssey_dossier_active := false
var _compact_dossier := false


func _ready() -> void:
	PremiumUI.apply(self)
	%TalkButton.pressed.connect(_show_dialogue)
	%TradeButton.pressed.connect(func(): trade_requested.emit())
	%RunButton.pressed.connect(_show_room_selection)
	%LeaveButton.pressed.connect(close_panel)
	%DialogueBackButton.pressed.connect(show_menu)
	%RoomBackButton.pressed.connect(show_menu)
	%ConfirmRunButton.pressed.connect(_confirm_run)
	run_selector.item_selected.connect(_on_run_selected)
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func open_panel(p_data: LanternboundArchivistData) -> void:
	data = p_data
	var configured_title := data.display_name.strip_edges() if data != null else ""
	title_label.text = (
		configured_title if not configured_title.is_empty() else ARCHIVIST_TITLE_FR
	)
	dialogue_label.text = data.dialogue_text if data != null else ""
	show_menu()
	visible = true
	%TalkButton.grab_focus.call_deferred()


func close_panel() -> void:
	visible = false
	show_menu()
	closed.emit()


func close_silently() -> void:
	visible = false
	show_menu()


func show_menu() -> void:
	main_menu.visible = true
	dialogue_view.visible = false
	room_selection_view.visible = false
	_apply_responsive_layout()
	if visible:
		%TalkButton.grab_focus.call_deferred()


func is_dialogue_open() -> bool:
	return visible and dialogue_view.visible


func _show_dialogue() -> void:
	main_menu.visible = false
	dialogue_view.visible = true
	room_selection_view.visible = false
	_apply_responsive_layout()
	dialogue_opened.emit()
	%DialogueBackButton.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if dialogue_view.visible or room_selection_view.visible:
		show_menu()
	else:
		close_panel()


func _show_room_selection() -> void:
	_available_runs = data.get_available_runs() if data != null else []
	run_selector.clear()
	for run_index in range(_available_runs.size()):
		run_selector.add_item(_available_runs[run_index].run_name, run_index)
	if run_selector.item_count > 0:
		run_selector.select(0)
	_populate_room_selector(0)
	main_menu.visible = false
	dialogue_view.visible = false
	room_selection_view.visible = true
	_apply_responsive_layout()
	_update_run_confirmation_state()
	if run_selector.item_count > 0:
		run_selector.grab_focus.call_deferred()


func _on_run_selected(item_index: int) -> void:
	_populate_room_selector(run_selector.get_item_id(item_index))
	_update_run_confirmation_state()


func _populate_room_selector(run_index: int) -> void:
	room_selector.clear()
	if run_index >= 0 and run_index < _available_runs.size():
		var run_data := _available_runs[run_index]
		room_selection_label.visible = run_data.hub_room_selection_enabled
		room_selector.visible = run_data.hub_room_selection_enabled
		if run_data.hub_room_selection_enabled:
			for index in range(run_data.rooms.size()):
				var room := run_data.rooms[index]
				var room_name := (
					room.room_name if room != null else "Salle %d" % (index + 1)
				)
				room_selector.add_item(room_name, index)
		else:
			var forced_index := run_data.hub_forced_start_room_index
			if forced_index >= 0 and forced_index < run_data.rooms.size():
				var forced_room := run_data.rooms[forced_index]
				var forced_name := (
					forced_room.room_name
					if forced_room != null else "Salle %d" % (forced_index + 1)
				)
				room_selector.add_item(forced_name, forced_index)
	else:
		room_selection_label.visible = true
		room_selector.visible = true
	start_room_row.visible = room_selector.visible
	if room_selector.item_count > 0:
		room_selector.select(0)
	_update_run_dossier(run_index)
	_configure_run_focus()


func _update_run_dossier(run_index: int) -> void:
	var run_data: RunData = (
		_available_runs[run_index]
		if run_index >= 0 and run_index < _available_runs.size()
		else null
	)
	_odyssey_dossier_active = _is_odyssey_run(run_data)
	if _odyssey_dossier_active:
		var featured_hero := _resolve_featured_hero(run_data)
		run_illustration.texture = ODYSSEY_ILLUSTRATION
		run_illustration.show()
		illustration_fallback.hide()
		illustration_title.text = "LES PORTES DE CATABASE"
		illustration_subtitle.text = "Une Odyssée en trois affrontements"
		dossier_eyebrow.text = "DOSSIER D’EXPÉDITION · ODYSSÉE"
		run_display_name.text = "CATABASE — L’ODYSSÉE D’ACHILLE"
		run_summary.text = (
			"Achille avance seul à travers trois salles liées. Chaque victoire "
			+ "ouvre un choix de relique avant l’affrontement suivant."
		)
		run_meta.text = "3 SALLES · DÉPART IMPOSÉ EN SALLE I"
		hero_portrait.texture = ACHILLES_PORTRAIT
		hero_portrait.show()
		hero_glyph.hide()
		hero_badge.text = "HÉROS UNIQUE"
		hero_name.text = (
			featured_hero.unit_name.to_upper()
			if featured_hero != null else "HÉROS DE CATABASE"
		)
		hero_role.text = (
			featured_hero.role
			if featured_hero != null and not featured_hero.role.is_empty()
			else "Hoplite de Catabase · mêlée mobile"
		)
		hero_stats.text = (
			"%d PV   ◆   %d PA   ◆   %d PM" % [
				featured_hero.max_hp,
				featured_hero.max_ap,
				featured_hero.max_mp,
			]
			if featured_hero != null else "DONNÉES DU HÉROS INDISPONIBLES"
		)
		flow_combat.text = "1  COMBAT"
		flow_reward.text = "2  RELIQUE"
		flow_next_room.text = "3  SALLE SUIVANTE"
		confirm_run_button.text = "ENTRER DANS CATABASE"
	else:
		run_illustration.texture = null
		run_illustration.hide()
		illustration_fallback.show()
		illustration_title.text = "REGISTRE D’EXPÉDITION"
		illustration_subtitle.text = "Parcours consigné par l’Archiviste"
		dossier_eyebrow.text = "DOSSIER D’EXPÉDITION"
		run_display_name.text = (
			run_data.run_name.to_upper() if run_data != null else "PARCOURS INDISPONIBLE"
		)
		var room_count := run_data.rooms.size() if run_data != null else 0
		run_summary.text = (
			"Prépare ton groupe, choisis ton point de départ et progresse "
			+ "de salle en salle."
		)
		run_meta.text = "%d SALLE%s · PARCOURS STANDARD" % [
			room_count,
			"S" if room_count != 1 else "",
		]
		hero_portrait.texture = null
		hero_portrait.hide()
		hero_glyph.show()
		hero_badge.text = "GROUPE"
		hero_name.text = "ÉQUIPE D’EXPÉDITION"
		hero_role.text = "Composition définie par le parcours"
		hero_stats.text = "HÉROS · ÉQUIPEMENT · PROGRESSION"
		flow_combat.text = "1  COMBAT"
		flow_reward.text = "2  PROGRESSION"
		flow_next_room.text = "3  SALLE SUIVANTE"
		confirm_run_button.text = "LANCER LA RUN"
	_apply_responsive_layout()


func _is_odyssey_run(run_data: RunData) -> bool:
	return run_data != null and (
		run_data.resource_path == ODYSSEY_RUN_PATH
		or _run_profile_id(run_data) == ODYSSEY_PROFILE_ID
	)


## Retourne l'index d'un parcours a partir de son identite persistante. Le
## chemin canonique reste prioritaire ; le profil permet aux copies runtime ou
## de validation, dont resource_path est vide, de retrouver le meme dossier.
func find_run_index(run_identity: RunData) -> int:
	if run_identity == null:
		return -1
	var expected_path := run_identity.resource_path
	var expected_profile_id := _run_profile_id(run_identity)
	for run_index in range(_available_runs.size()):
		var candidate := _available_runs[run_index]
		if candidate == null:
			continue
		if not expected_path.is_empty() \
				and candidate.resource_path == expected_path:
			return run_index
		if expected_profile_id != &"" \
				and _run_profile_id(candidate) == expected_profile_id:
			return run_index
	return -1


func _run_profile_id(run_data: RunData) -> StringName:
	if run_data == null or run_data.content_profile == null:
		return &""
	return run_data.content_profile.profile_id


func _resolve_featured_hero(run_data: RunData) -> UnitData:
	if run_data == null:
		return null
	var resolution := RunHeroResolver.resolve_runtime_hero_data(run_data, true)
	if not resolution.is_valid() or resolution.heroes.size() != 1:
		return null
	return resolution.heroes[0]


func _configure_run_focus() -> void:
	if not is_node_ready():
		return
	var next_control: Control = room_selector if room_selector.visible else confirm_run_button
	run_selector.focus_neighbor_bottom = next_control.get_path()
	confirm_run_button.focus_neighbor_top = next_control.get_path() if room_selector.visible else run_selector.get_path()
	if room_selector.visible:
		room_selector.focus_neighbor_top = run_selector.get_path()
		room_selector.focus_neighbor_bottom = confirm_run_button.get_path()


func _update_run_confirmation_state() -> void:
	var selected_run_index := run_selector.get_selected_id()
	%ConfirmRunButton.disabled = selected_run_index < 0 \
		or selected_run_index >= _available_runs.size() \
		or room_selector.item_count == 0


func _confirm_run() -> void:
	var selected_run_index := run_selector.get_selected_id()
	if selected_run_index < 0 or selected_run_index >= _available_runs.size():
		return
	var selected_run := _available_runs[selected_run_index]
	var selected_room_index := selected_run.get_hub_start_room_index(
		room_selector.get_selected_id()
	)
	if selected_room_index < 0 or selected_room_index >= selected_run.rooms.size():
		return
	%ConfirmRunButton.disabled = true
	run_requested.emit(selected_run, selected_room_index)


func apply_viewport_size_for_test(viewport_size: Vector2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = viewport_size
	_apply_responsive_layout()


func get_run_dossier_snapshot() -> Dictionary:
	return {
		"panel_rect": panel.get_global_rect(),
		"dossier_rect": run_dossier.get_global_rect(),
		"illustration_rect": %IllustrationPanel.get_global_rect(),
		"details_rect": %DossierDetails.get_global_rect(),
		"odyssey": _odyssey_dossier_active,
		"compact": _compact_dossier,
		"title": title_label.text,
		"run_name": run_display_name.text,
		"run_meta": run_meta.text,
		"hero_name": hero_name.text,
		"hero_stats": hero_stats.text,
		"flow": [flow_combat.text, flow_reward.text, flow_next_room.text],
		"illustration_visible": run_illustration.visible,
		"hero_portrait_visible": hero_portrait.visible,
		"room_selector_visible": room_selector.visible,
	}


func _apply_responsive_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	var run_mode := room_selection_view.visible
	_compact_dossier = size.x <= 1400.0 or size.y <= 800.0
	var panel_width := 500.0
	var panel_height := 590.0
	if run_mode:
		panel_width = clampf(size.x - 72.0, 860.0, 1080.0)
		panel_height = clampf(size.y - 48.0, 600.0, 700.0)
	else:
		panel_width = minf(520.0, size.x - 48.0)
		panel_height = minf(590.0, size.y - 48.0)
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5
	var horizontal_margin := 22 if _compact_dossier and run_mode else 28
	var vertical_margin := 18 if _compact_dossier and run_mode else 24
	panel_margin.add_theme_constant_override("margin_left", horizontal_margin)
	panel_margin.add_theme_constant_override("margin_right", horizontal_margin)
	panel_margin.add_theme_constant_override("margin_top", vertical_margin)
	panel_margin.add_theme_constant_override("margin_bottom", vertical_margin)
	panel_content.add_theme_constant_override("separation", 10 if run_mode else 18)
	room_selection_view.add_theme_constant_override("separation", 9 if _compact_dossier else 11)
	dossier_body.add_theme_constant_override("separation", 14 if _compact_dossier else 18)
	%IllustrationPanel.custom_minimum_size.x = 380.0 if _compact_dossier else 430.0
	%RoomSelectionPrompt.custom_minimum_size.y = 38.0 if _compact_dossier else 44.0
	%RunDisplayName.add_theme_font_size_override("font_size", 22 if _compact_dossier else 26)
	%RunSummary.add_theme_font_size_override("font_size", 13 if _compact_dossier else 14)
	%RunDossierMargin.add_theme_constant_override("margin_left", 12 if _compact_dossier else 16)
	%RunDossierMargin.add_theme_constant_override("margin_right", 12 if _compact_dossier else 16)
	%RunDossierMargin.add_theme_constant_override("margin_top", 12 if _compact_dossier else 16)
	%RunDossierMargin.add_theme_constant_override("margin_bottom", 12 if _compact_dossier else 16)
