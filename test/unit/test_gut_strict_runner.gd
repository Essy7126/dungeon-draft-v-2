extends GutTest

const RUNNER_PATH := "res://tools/ci/run_gut_strict.ps1"
const SELF_TEST_PATH := "res://tools/ci/test_run_gut_strict.ps1"
const SCHEMA_PATH := "res://tools/ci/gut_strict_report.schema.json"
const FIXTURE_ROOT := "res://test/fixtures/gut_strict"

const FAILURE_CLASSIFICATIONS: Array[String] = [
	"CONFIG_ERROR",
	"PROCESS_START_ERROR",
	"IMPORT_TIMEOUT",
	"GUT_TIMEOUT",
	"PARSE_ERROR",
	"GUT_STARTUP_ERROR",
	"JUNIT_MISSING",
	"JUNIT_INVALID",
	"ZERO_TESTS",
	"SUMMARY_MISSING",
	"SUITE_MISSING",
	"UNEXPECTED_ENGINE_ERROR",
	"EXPECTED_FAILURE_SET_MISMATCH",
	"TEST_FAILURE",
]


func test_report_schema_is_parseable_and_declares_every_strict_outcome() -> void:
	var schema := _load_json_dictionary(SCHEMA_PATH)
	assert_false(schema.is_empty(), "Le schema du strict runner doit etre lisible.")
	assert_eq(int(schema.get("schema_version", 0)), 0, "Le schema JSON ne porte pas de faux champ de version racine.")
	assert_eq(schema.get("type", ""), "object")
	var required := schema.get("required", []) as Array
	for key in [
		"schema_version",
		"verdict",
		"primary_classification",
		"selection",
		"counts",
		"process",
		"summary",
		"junit",
		"errors",
		"artifacts",
	]:
		assert_true(required.has(key), "Champ obligatoire absent du schema: %s" % key)

	var definitions := schema.get("$defs", {}) as Dictionary
	var classifications := (
		(definitions.get("classification", {}) as Dictionary).get("enum", []) as Array
	)
	for classification in ["PASS", "PASS_WITH_EXPECTED_FAILURES"] + FAILURE_CLASSIFICATIONS:
		assert_true(
			classifications.has(classification),
			"Classification absente du schema: %s" % classification
		)


func test_fixture_templates_are_safe_text_and_cover_the_five_real_cases() -> void:
	var expected_templates: Array[String] = [
		"project.godot.txt",
		"test_pass.gd.txt",
		"test_failure.gd.txt",
		"test_parse_error.gd.txt",
		"test_zero_tests.gd.txt",
		"test_timeout.gd.txt",
	]
	for filename in expected_templates:
		var path := FIXTURE_ROOT.path_join(filename)
		assert_true(FileAccess.file_exists(path), "Fixture absente: %s" % path)
		assert_gt(_read_text(path).length(), 0, "Fixture vide: %s" % path)

	var directory := DirAccess.open(FIXTURE_ROOT)
	assert_not_null(directory)
	if directory == null:
		return
	for filename in directory.get_files():
		assert_false(
			filename.ends_with(".gd"),
			"Une fixture volontairement invalide ne doit jamais etre importable: %s" % filename
		)

	assert_true(_read_text(FIXTURE_ROOT.path_join("test_pass.gd.txt")).contains("assert_true(true"))
	assert_true(_read_text(FIXTURE_ROOT.path_join("test_failure.gd.txt")).contains("assert_true(false"))
	var parse_fixture := _read_text(FIXTURE_ROOT.path_join("test_parse_error.gd.txt"))
	assert_true(parse_fixture.contains("func test_fixture_has_a_parse_error() -> void\n"))
	assert_false(parse_fixture.contains("func test_fixture_has_a_parse_error() -> void:"))
	assert_false(_read_text(FIXTURE_ROOT.path_join("test_zero_tests.gd.txt")).contains("func test_"))
	assert_true(_read_text(FIXTURE_ROOT.path_join("test_timeout.gd.txt")).contains("3600.0"))


func test_report_contract_parser_accepts_complete_report_and_rejects_false_green_shapes() -> void:
	var schema := _load_json_dictionary(SCHEMA_PATH)
	var valid_report := _minimal_report()
	assert_eq(_report_contract_errors(valid_report, schema), PackedStringArray())

	var missing_junit := valid_report.duplicate(true)
	missing_junit.erase("junit")
	assert_true(_report_contract_errors(missing_junit, schema).has("missing:junit"))

	var false_green := valid_report.duplicate(true)
	false_green["failure_codes"] = ["ZERO_TESTS"]
	assert_true(_report_contract_errors(false_green, schema).has("pass_with_failures"))

	var unknown_classification := valid_report.duplicate(true)
	unknown_classification["primary_classification"] = "GREEN_BUT_EMPTY"
	assert_true(
		_report_contract_errors(unknown_classification, schema).has("unknown:GREEN_BUT_EMPTY")
	)


func test_powershell_contract_contains_junit_watchdog_and_no_recursive_gut_self_test() -> void:
	var runner := _read_text(RUNNER_PATH)
	var self_test := _read_text(SELF_TEST_PATH)
	assert_gt(runner.length(), 0)
	assert_gt(self_test.length(), 0)
	for token in [
		"-gconfig=",
		"-gjunit_xml_file",
		"WaitForExit",
		"taskkill.exe",
		"Nothing was run",
		"PASS_WITH_EXPECTED_FAILURES",
	]:
		assert_true(runner.contains(token), "Contrat PowerShell absent: %s" % token)
	for fixture in [
		"test_pass.gd.txt",
		"test_failure.gd.txt",
		"test_parse_error.gd.txt",
		"test_zero_tests.gd.txt",
		"test_timeout.gd.txt",
	]:
		assert_true(self_test.contains(fixture), "Fixture live non couverte: %s" % fixture)
	assert_false(self_test.contains("res://test/unit/test_gut_strict_runner.gd"))


func _load_json_dictionary(path: String) -> Dictionary:
	var text := _read_text(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _report_contract_errors(report: Dictionary, schema: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for required_key in schema.get("required", []) as Array:
		if not report.has(required_key):
			errors.append("missing:%s" % required_key)

	var definitions := schema.get("$defs", {}) as Dictionary
	var allowed := (
		(definitions.get("classification", {}) as Dictionary).get("enum", []) as Array
	)
	var primary := str(report.get("primary_classification", ""))
	if not allowed.has(primary):
		errors.append("unknown:%s" % primary)

	var failures := report.get("failure_codes", []) as Array
	var verdict := str(report.get("verdict", ""))
	if verdict.begins_with("PASS") and not failures.is_empty():
		errors.append("pass_with_failures")
	if verdict == "FAIL" and failures.is_empty():
		errors.append("fail_without_failure")
	for classification in failures:
		if not FAILURE_CLASSIFICATIONS.has(str(classification)):
			errors.append("unknown_failure:%s" % classification)
	return errors


func _minimal_report() -> Dictionary:
	return {
		"schema_version": 1,
		"suite_id": "schema-fixture",
		"verdict": "PASS",
		"primary_classification": "PASS",
		"failure_codes": [],
		"started_at_utc": "2026-08-19T00:00:00.0000000Z",
		"duration_ms": 1,
		"godot": {"path": null, "version": null},
		"gut_version": "9.7.1",
		"selection": {
			"directory": "res://test/unit",
			"prefix": "test_schema_fixture",
			"suffix": ".gd",
			"include_subdirectories": false,
			"scripts_discovered": ["res://test/unit/test_schema_fixture.gd"],
			"scripts_expected": ["res://test/unit/test_schema_fixture.gd"],
			"scripts_executed": ["res://test/unit/test_schema_fixture.gd"],
			"scripts_missing": [],
		},
		"counts": {
			"production_scripts_compile_checked": 1,
			"test_scripts_compile_checked": 1,
			"tests_expected": {"mode": "exact", "value": 1},
			"tests_executed": 1,
			"passing_tests": 1,
			"failing_tests": 0,
			"pending_tests": 0,
			"risky_tests": 0,
			"skipped_tests": 0,
			"assertions_passed": 1,
			"assertions_total": 1,
			"parse_errors": 0,
		},
		"process": {
			"version_exit_code": 0,
			"import_started": true,
			"import_exit_code": 0,
			"import_timed_out": false,
			"gut_started": true,
			"gut_exit_code": 0,
			"gut_timed_out": false,
			"killed": false,
			"termination_exit_code": 0,
		},
		"summary": {
			"present": true,
			"scripts": 1,
			"tests": 1,
			"passing_tests": 1,
			"failing_tests": 0,
			"risky_pending": 0,
			"errors": 0,
			"warnings": 0,
			"assertions_passed": 1,
			"assertions_total": 1,
		},
		"junit": {
			"path": "user://gut.junit.xml",
			"present": true,
			"bytes": 1,
			"valid": true,
			"tests": 1,
			"failures": 0,
			"testcases": 1,
			"suite_count": 1,
			"assertion_sum": 1,
		},
		"expected_failures": [],
		"observed_failures": [],
		"errors": [],
		"artifacts": {
			"import_stdout": null,
			"import_stderr": null,
			"import_engine": null,
			"gut_stdout": null,
			"gut_stderr": null,
			"gut_engine": null,
			"junit": "user://gut.junit.xml",
			"report": "user://gut-strict-report.json",
		},
	}
