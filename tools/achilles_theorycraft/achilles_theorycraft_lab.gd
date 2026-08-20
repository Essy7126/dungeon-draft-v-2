class_name AchillesTheorycraftLab
extends Control

@onready var snapshot_view: TextEdit = %SnapshotView
@onready var build_a: OptionButton = %BuildA
@onready var build_b: OptionButton = %BuildB
@onready var build_c: OptionButton = %BuildC
@onready var context_selector: OptionButton = %ContextSelector
@onready var economy_view: TextEdit = %EconomyView
@onready var deltas_view: TextEdit = %DeltasView
@onready var alerts_view: TextEdit = %AlertsView
@onready var draft_editor: TextEdit = %DraftEditor
@onready var status_label: Label = %StatusLabel

var _snapshot := {}
var _builds: Array[AchillesTheorycraftBuild] = []
var _contexts: Array[TheorycraftContext] = []
var _report: TheorycraftComparisonReport = null
var _catalog := AchillesTheorycraftCatalog.new()
var _snapshot_exporter := AchillesTheorycraftSnapshotExporter.new()
var _comparison := AchillesTheorycraftComparisonService.new()
var _store := AchillesTheorycraftStore.new()


func _ready() -> void:
	_snapshot = _snapshot_exporter.build_snapshot()
	if _snapshot.has("error"):
		status_label.text = "Snapshot failed: %s" % _snapshot.error
		return
	_builds = _catalog.initial_builds(str(_snapshot.get("snapshot_sha", "")))
	_contexts = _catalog.odyssey_contexts()
	_populate_build_selectors()
	_populate_contexts()
	snapshot_view.text = AchillesTheorycraftJson.stringify(_snapshot)
	for selector in [build_a, build_b, build_c, context_selector]:
		selector.item_selected.connect(func(_index): _refresh())
	%RefreshButton.pressed.connect(_refresh)
	%ApplyDraftButton.pressed.connect(_apply_draft)
	%ExportButton.pressed.connect(_export_review)
	_refresh()


func _populate_build_selectors() -> void:
	var selectors := [build_a, build_b, build_c]
	for selector_index in range(selectors.size()):
		var selector: OptionButton = selectors[selector_index]
		selector.clear()
		if selector_index > 0:
			selector.add_item("EMPTY")
			selector.set_item_metadata(selector.item_count - 1, -1)
		for build_index in range(_builds.size()):
			var build := _builds[build_index]
			selector.add_item(build.display_name)
			selector.set_item_metadata(selector.item_count - 1, build_index)
		var desired_build_index := mini(selector_index, _builds.size() - 1)
		selector.select(desired_build_index + (1 if selector_index > 0 else 0))


func _populate_contexts() -> void:
	context_selector.clear()
	for context in _contexts:
		context_selector.add_item(context.context_id)
	if not _contexts.is_empty():
		context_selector.select(_contexts.size() - 1)


func _selected_builds() -> Array[AchillesTheorycraftBuild]:
	var selected: Array[AchillesTheorycraftBuild] = []
	for selector in [build_a, build_b, build_c]:
		if selector.selected < 0:
			continue
		var build_index := int(selector.get_item_metadata(selector.selected))
		if build_index >= 0 and build_index < _builds.size():
			selected.append(_builds[build_index])
	return selected


func _selected_contexts() -> Array[TheorycraftContext]:
	var selected: Array[TheorycraftContext] = []
	if context_selector.selected >= 0 and context_selector.selected < _contexts.size():
		selected.append(_contexts[context_selector.selected])
	return selected


func _refresh() -> void:
	var builds := _selected_builds()
	if builds.is_empty():
		return
	_report = _comparison.compare(builds, _selected_contexts())
	var report_data := _report.to_dict()
	economy_view.text = AchillesTheorycraftJson.stringify({
		"ap_sequences": report_data.ap_sequences,
		"unused_ap": report_data.unused_ap,
		"damage": report_data.damage,
		"range": report_data.range,
		"area": report_data.area,
		"mobility": report_data.mobility,
		"defense": report_data.defense,
		"control": report_data.control,
		"recovery": report_data.recovery,
	})
	deltas_view.text = AchillesTheorycraftJson.stringify(report_data.deltas)
	alerts_view.text = AchillesTheorycraftJson.stringify({
		"warnings": report_data.warnings,
		"not_measured": report_data.not_measured,
	})
	var editable := builds[1] if builds.size() > 1 else builds[0]
	draft_editor.text = AchillesTheorycraftJson.stringify(editable.to_dict())
	status_label.text = "Snapshot %s | %d build(s) | no runtime write" % [
		str(_snapshot.snapshot_sha).substr(0, 12), builds.size()
	]


func _apply_draft() -> void:
	var parsed: Variant = JSON.parse_string(draft_editor.text)
	if not parsed is Dictionary:
		status_label.text = "Draft rejected: invalid JSON"
		return
	var draft := AchillesTheorycraftBuild.from_dict(parsed)
	if draft.status != AchillesTheorycraftBuild.STATUS_DRAFT:
		status_label.text = "Draft rejected: status must remain DRAFT"
		return
	if not draft.design_tags.has("NOT_RUNTIME_LOADABLE") \
			or not draft.design_tags.has("DESIGN_CONCEPT_ONLY"):
		status_label.text = "Draft rejected: isolation tags are required"
		return
	draft.mark_owner_editable_fields_as_draft()
	var result := _store.save_draft(draft)
	if not result.ok:
		status_label.text = "Draft save failed: %s" % result.error
		return
	var replaced := false
	for index in range(_builds.size()):
		if _builds[index].build_id == draft.build_id:
			_builds[index] = draft
			replaced = true
			break
	if not replaced:
		_builds.append(draft)
	_populate_build_selectors()
	_refresh()
	status_label.text = "Draft saved outside res://: %s" % result.path


func _export_review() -> void:
	if _report == null:
		_refresh()
	var review := _store.export_review(_report, _selected_builds())
	if not review.ok:
		status_label.text = "Export failed: %s" % review.error
		return
	var snapshot_result := _snapshot_exporter.export_snapshot(
		AchillesTheorycraftStore.EXPORT_ROOT.path_join("snapshot")
	)
	status_label.text = (
		"Deterministic review exported: %s" % AchillesTheorycraftStore.EXPORT_ROOT
		if snapshot_result.get("ok", false)
		else "Comparison exported; snapshot export failed"
	)
