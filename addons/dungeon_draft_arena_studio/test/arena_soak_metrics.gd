@tool
class_name ArenaSoakMetrics
extends RefCounted

## Mesures et criteres purs du soak Arena. Les diagnostics emis apres le marqueur
## de fin in-process sont volontairement hors de ce contrat et sont ajoutes par
## le wrapper PowerShell dans `shutdown_historical_errors`.

const CONTINUOUS_WINDOW := 5
const MEMORY_STEP_TOLERANCE_BYTES := 64 * 1024
const LEAK_METRICS := [
	"object_count",
	"resource_count",
	"node_count",
	"orphan_node_count",
	"tree_node_count",
	"signal_connection_count",
	"subviewport_count",
	"window_count",
	"memory_static_bytes",
	"render_video_memory_bytes",
	"arena_render_plan_cache_size",
	"arena_tactical_cache_size",
	"arena_visual_inspection_cache_size",
]
const EXACT_CLEANUP_METRICS := [
	"orphan_node_count",
	"tree_node_count",
	"signal_connection_count",
	"subviewport_count",
	"window_count",
]
const EXPECTED_PHASE_RETENTION := {
	# StudioHistoryController conserve volontairement jusqu'a 100 paires de
	# snapshots before/after. La memoire statique peut donc monter pendant les
	# 100 transformations, mais le nombre d'entrees est borne et controle par le
	# runner. Les autres compteurs restent des gates de croissance pendant cette
	# phase, et la memoire reste exposee dans les echantillons/deltas finaux.
	"transforms": ["memory_static_bytes"],
}


static func sample(
		tree: SceneTree,
		tracked_root: Node = null,
		label := "",
		elapsed_ms := 0.0
	) -> Dictionary:
	var root := tree.root if tree != null else null
	return {
		"label": label,
		"elapsed_ms": snappedf(float(elapsed_ms), 0.001),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resource_count": int(Performance.get_monitor(
			Performance.OBJECT_RESOURCE_COUNT
		)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(Performance.get_monitor(
			Performance.OBJECT_ORPHAN_NODE_COUNT
		)),
		"memory_static_bytes": int(Performance.get_monitor(
			Performance.MEMORY_STATIC
		)),
		"memory_static_peak_bytes": int(Performance.get_monitor(
			Performance.MEMORY_STATIC_MAX
		)),
		# Ces moniteurs sont les proxies publics disponibles pour les objets/RID
		# de rendu. Ils ne sont jamais presentes comme un compte global de RID.
		"render_proxy_objects_in_frame": int(Performance.get_monitor(
			Performance.RENDER_TOTAL_OBJECTS_IN_FRAME
		)),
		"render_primitives_in_frame": int(Performance.get_monitor(
			Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
		)),
		"render_draw_calls_in_frame": int(Performance.get_monitor(
			Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME
		)),
		"render_video_memory_bytes": int(Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED
		)),
		# Ces caches statiques sont inclus explicitement : une suite de contenus
		# uniques ne doit pas pouvoir masquer une retention globale derriere des
		# compteurs ObjectDB qui seraient autrement stables.
		"arena_render_plan_cache_size": (
			ArenaTerrainRenderPlanService.cache_size()
		),
		"arena_tactical_cache_size": ArenaTacticalMetricsService.cache_size(),
		"arena_visual_inspection_cache_size": (
			ArenaVisualAssembler.inspection_cache_size()
		),
		"tree_node_count": _node_count(root),
		"tracked_node_count": _node_count(tracked_root),
		"signal_connection_count": _signal_connection_count(root),
		"tracked_signal_connection_count": _signal_connection_count(
			tracked_root
		),
		"subviewport_count": _type_count(root, &"SubViewport"),
		"tracked_subviewport_count": _type_count(
			tracked_root, &"SubViewport"
		),
		"window_count": _type_count(root, &"Window"),
		"tracked_window_count": _type_count(tracked_root, &"Window"),
	}


static func delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key in after:
		var after_value: Variant = after[key]
		var before_value: Variant = before.get(key)
		if after_value is int or after_value is float:
			if before_value is int or before_value is float:
				result[key] = after_value - before_value
	return result


static func latency_summary(samples: Array) -> Dictionary:
	var values: Array[float] = []
	for value in samples:
		if value is int or value is float:
			values.append(float(value))
	values.sort()
	if values.is_empty():
		return {
			"count": 0,
			"valid": false,
			"continuous_degradation": false,
		}
	var total := 0.0
	for value in values:
		total += value
	var chronological: Array[float] = []
	for value in samples:
		if value is int or value is float:
			chronological.append(float(value))
	var half := maxi(1, chronological.size() / 2)
	var first_mean := _mean(chronological.slice(0, half))
	var last_mean := _mean(chronological.slice(chronological.size() - half))
	return {
		"count": values.size(),
		"valid": true,
		"min_ms": snappedf(values[0], 0.001),
		"mean_ms": snappedf(total / float(values.size()), 0.001),
		"p50_ms": snappedf(_percentile(values, 0.50), 0.001),
		"p95_ms": snappedf(_percentile(values, 0.95), 0.001),
		"max_ms": snappedf(values[-1], 0.001),
		"first_half_mean_ms": snappedf(first_mean, 0.001),
		"last_half_mean_ms": snappedf(last_mean, 0.001),
		# Pas de budget wall-clock materiel-dependant. Le gate detecte seulement
		# une deterioration relative ET une hausse continue de la queue.
		"continuous_degradation": (
			last_mean > first_mean * 2.5 + 5.0
			and _strict_tail_growth(chronological, 0.05)
		),
	}


static func continuous_growth(
		samples: Array,
		metrics: Array = LEAK_METRICS
	) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	if samples.size() < CONTINUOUS_WINDOW:
		return findings
	var tail := samples.slice(samples.size() - CONTINUOUS_WINDOW)
	for metric_value in metrics:
		var metric := str(metric_value)
		var tolerance := MEMORY_STEP_TOLERANCE_BYTES \
			if metric in ["memory_static_bytes", "render_video_memory_bytes"] \
			else 0
		var deltas: Array[float] = []
		var rising := true
		for index in range(1, tail.size()):
			var previous := float((tail[index - 1] as Dictionary).get(metric, 0))
			var current := float((tail[index] as Dictionary).get(metric, 0))
			var step := current - previous
			deltas.append(step)
			if step <= float(tolerance):
				rising = false
		if rising:
			findings.append({
				"metric": metric,
				"window": tail.size(),
				"step_tolerance": tolerance,
				"deltas": deltas,
				"classification": "CONTINUOUS_GROWTH",
			})
	return findings


static func evaluate(
		before: Dictionary,
		after_cleanup: Dictionary,
		phase_samples: Dictionary,
		latencies: Dictionary,
		expected_operations: Dictionary,
		completed_operations: Dictionary,
		cleanup_ok: bool
	) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var growth_findings: Array[Dictionary] = []
	var latency_report := {}
	var expected_retention_report := {}
	if not cleanup_ok:
		errors.append({
			"classification": "FIXTURE_CLEANUP_FAILED",
			"message": "Un namespace fixture du soak existe encore.",
		})
	for operation in expected_operations:
		var expected := int(expected_operations[operation])
		var completed := int(completed_operations.get(operation, 0))
		if completed != expected:
			errors.append({
				"classification": "OPERATION_COUNT_MISMATCH",
				"operation": str(operation),
				"expected": expected,
				"completed": completed,
			})
	var in_process_delta := delta(before, after_cleanup)
	for metric_value in EXACT_CLEANUP_METRICS:
		var metric := str(metric_value)
		var metric_delta := int(in_process_delta.get(metric, 0))
		if metric_delta > 0:
			errors.append({
				"classification": "RESIDUAL_ARENA_OBJECT",
				"metric": metric,
				"delta": metric_delta,
			})
	for phase in phase_samples:
		var phase_name := str(phase)
		var gated_metrics := LEAK_METRICS.duplicate()
		var retention_exclusions := (
			EXPECTED_PHASE_RETENTION.get(phase_name, []) as Array
		).duplicate()
		for metric_value in retention_exclusions:
			gated_metrics.erase(str(metric_value))
		if not retention_exclusions.is_empty():
			expected_retention_report[phase_name] = {
				"excluded_from_continuous_growth": retention_exclusions,
				"gate": "bounded_retention_reported_by_runner",
			}
		var findings := continuous_growth(
			phase_samples[phase] as Array, gated_metrics
		)
		for finding_value in findings:
			var finding := (finding_value as Dictionary).duplicate(true)
			finding["phase"] = str(phase)
			growth_findings.append(finding)
			errors.append(finding)
	for phase in latencies:
		var summary := latency_summary(latencies[phase] as Array)
		latency_report[phase] = summary
		if not bool(summary.get("valid", false)):
			errors.append({
				"classification": "LATENCY_SAMPLE_MISSING",
				"phase": str(phase),
			})
		elif bool(summary.get("continuous_degradation", false)):
			errors.append({
				"classification": "CONTINUOUS_LATENCY_DEGRADATION",
				"phase": str(phase),
				"summary": summary,
			})
	for metric in [
		"object_count", "resource_count", "memory_static_bytes",
		"render_video_memory_bytes",
	]:
		var residual := int(in_process_delta.get(metric, 0))
		if residual > 0:
			warnings.append({
				"classification": "POSITIVE_RESIDUAL_REPORTED",
				"metric": metric,
				"delta": residual,
				"gate": "continuous_growth_only",
			})
	return {
		"ok": errors.is_empty(),
		"verdict": "PASS" if errors.is_empty() else "FAIL",
		"arena_in_process_delta": in_process_delta,
		"errors": errors,
		"warnings": warnings,
		"continuous_growth_findings": growth_findings,
		"expected_phase_retention": expected_retention_report,
		"latencies": latency_report,
		"expected_operations": expected_operations.duplicate(true),
		"completed_operations": completed_operations.duplicate(true),
		"cleanup_ok": cleanup_ok,
		"shutdown_diagnostics_included": false,
	}


static func _node_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total := 1
	for child in root.get_children():
		total += _node_count(child)
	return total


static func _type_count(root: Node, type_name: StringName) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var matches := 0
	match type_name:
		&"SubViewport":
			matches = 1 if root is SubViewport else 0
		&"Window":
			matches = 1 if root is Window else 0
	for child in root.get_children():
		matches += _type_count(child, type_name)
	return matches


static func _signal_connection_count(root: Node) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var total := 0
	for signal_value in root.get_signal_list():
		var signal_data := signal_value as Dictionary
		var signal_name := StringName(signal_data.get("name", &""))
		if signal_name != &"":
			total += root.get_signal_connection_list(signal_name).size()
	for child in root.get_children():
		total += _signal_connection_count(child)
	return total


static func _percentile(sorted_values: Array[float], ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := clampi(
		int(ceil(float(sorted_values.size()) * ratio)) - 1,
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


static func _strict_tail_growth(values: Array[float], tolerance: float) -> bool:
	if values.size() < CONTINUOUS_WINDOW:
		return false
	var tail := values.slice(values.size() - CONTINUOUS_WINDOW)
	for index in range(1, tail.size()):
		if float(tail[index]) - float(tail[index - 1]) <= tolerance:
			return false
	return true
