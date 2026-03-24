class_name GNTestRunner
extends SceneTree
## Lightweight unit-test runner for GONODES.
##
## Run from the command line:
##   godot --headless -s tests/test_runner.gd
##
## The runner discovers all test scripts under res://tests/ whose filenames
## start with "test_".  Each script must extend Node and expose zero-arg
## methods whose names start with "test_".  The runner calls them in sequence,
## collects pass/fail results, prints a summary, and exits with code 0 (all
## passed) or 1 (any failures).
##
## Optional lifecycle methods per test script:
##   before_all()   — called once before any test methods
##   after_all()    — called once after all test methods
##   before_each()  — called before every individual test method
##   after_each()   — called after every individual test method
##
## Assertion helpers are provided by GNTestAssert (autoloaded via the runner).


# ─── Counters ──────────────────────────────────────────────────────────────────

var _total_tests: int = 0
var _passed: int = 0
var _failed: int = 0
var _errors: Array[String] = []
var _current_suite: String = ""
var _current_test: String = ""
var _filter: String = ""  # Optional test name filter from CLI
var _tag: String = ""     # Optional tag filter: core, extension, integration, patch


# ═══════════════════════════════════════════════════════════════════════════════
# Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	# Parse --test-filter="pattern" and --test-tag="tag" from command line
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-filter="):
			_filter = arg.substr("--test-filter=".length())
		elif arg.begins_with("--test-tag="):
			_tag = arg.substr("--test-tag=".length()).to_lower()


func _initialize() -> void:
	_print_header()
	var test_scripts := _discover_test_scripts()

	if not _tag.is_empty():
		test_scripts = _filter_by_tag(test_scripts)

	if test_scripts.is_empty():
		print("  No test scripts found (tag=%s)" % [_tag if not _tag.is_empty() else "all"])
		quit(1)
		return

	for script_path in test_scripts:
		_run_suite(script_path)

	_print_summary()
	quit(1 if _failed > 0 else 0)


# ═══════════════════════════════════════════════════════════════════════════════
# Discovery
# ═══════════════════════════════════════════════════════════════════════════════

func _discover_test_scripts() -> Array[String]:
	var results: Array[String] = []
	_scan_dir("res://tests/", results)
	# Also discover tests inside each gn_ext_* extension folder
	var addons_dir := DirAccess.open("res://addons/")
	if addons_dir != null:
		addons_dir.list_dir_begin()
		var folder := addons_dir.get_next()
		while folder != "":
			if addons_dir.current_is_dir() and folder.begins_with("gn_ext_"):
				var ext_test_dir := "res://addons/".path_join(folder).path_join("tests")
				if DirAccess.dir_exists_absolute(ext_test_dir):
					_scan_dir(ext_test_dir, results)
			folder = addons_dir.get_next()
		addons_dir.list_dir_end()
	results.sort()
	return results


## Filters discovered scripts by tag.
## Tags:
##   core        — tests/operators/ and tests/test_*.gd (not integration/functional)
##   functional  — tests/functional/
##   integration — tests/integration/
##   extension   — addons/gn_ext_*/tests/
##   patch       — tests/integration/test_gnpatch_smoke.gd only
func _filter_by_tag(scripts: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	for path in scripts:
		match _tag:
			"core":
				if path.begins_with("res://tests/") \
						and not path.contains("/integration/") \
						and not path.contains("/functional/"):
					filtered.append(path)
			"functional":
				if path.contains("/functional/"):
					filtered.append(path)
			"integration":
				if path.contains("/integration/") and not path.contains("gnpatch_smoke"):
					filtered.append(path)
			"extension":
				if path.begins_with("res://addons/gn_ext_"):
					filtered.append(path)
			"patch":
				if path.contains("gnpatch_smoke"):
					filtered.append(path)
			_:
				filtered.append(path)
	return filtered


func _scan_dir(dir_path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	# Files to exclude from discovery (not real test suites)
	var _exclude := ["test_runner.gd", "test_assert.gd"]
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if dir.current_is_dir() and fname != "." and fname != "..":
			_scan_dir(dir_path.path_join(fname), results)
		elif fname.begins_with("test_") and fname.ends_with(".gd") and not fname in _exclude:
			results.append(dir_path.path_join(fname))
		fname = dir.get_next()
	dir.list_dir_end()


# ═══════════════════════════════════════════════════════════════════════════════
# Execution
# ═══════════════════════════════════════════════════════════════════════════════

func _run_suite(script_path: String) -> void:
	var script: GDScript = load(script_path) as GDScript
	if script == null:
		print("  ✗ Failed to load: %s" % script_path)
		_failed += 1
		return

	_current_suite = script_path.get_file().get_basename()
	print("\n── %s ──" % _current_suite)

	# Instantiate the test class (extends Node)
	var instance: Node = script.new()
	if instance == null:
		print("  ✗ Failed to instantiate: %s" % script_path)
		_failed += 1
		return

	# Add to tree so add_child() works inside tests
	root.add_child(instance)

	# Collect test methods
	var test_methods: Array[String] = []
	for method_info in instance.get_method_list():
		var mname: String = method_info["name"]
		if mname.begins_with("test_"):
			if _filter.is_empty() or mname.containsn(_filter):
				test_methods.append(mname)
	test_methods.sort()

	if test_methods.is_empty():
		print("  (no test methods found)")
		instance.queue_free()
		return

	# Lifecycle: before_all
	if instance.has_method("before_all"):
		instance.call("before_all")

	for method_name in test_methods:
		_current_test = method_name
		_total_tests += 1

		# Lifecycle: before_each
		if instance.has_method("before_each"):
			instance.call("before_each")

		var success := true
		var error_msg := ""
		# Run test — catch assertion failures via GNTestAssert
		GNTestAssert._reset()
		instance.call(method_name)
		if GNTestAssert._failure_count > 0:
			success = false
			error_msg = GNTestAssert._last_failure

		if success:
			_passed += 1
			print("  ✓ %s" % method_name)
		else:
			_failed += 1
			_errors.append("%s::%s — %s" % [_current_suite, method_name, error_msg])
			print("  ✗ %s — %s" % [method_name, error_msg])

		# Lifecycle: after_each
		if instance.has_method("after_each"):
			instance.call("after_each")

	# Lifecycle: after_all
	if instance.has_method("after_all"):
		instance.call("after_all")

	instance.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# Output
# ═══════════════════════════════════════════════════════════════════════════════

func _print_header() -> void:
	print("")
	print("═══════════════════════════════════════════════════")
	print("  GONODES Unit Test Runner")
	print("═══════════════════════════════════════════════════")
	if not _filter.is_empty():
		print("  Filter: %s" % _filter)
	if not _tag.is_empty():
		print("  Tag: %s" % _tag)


func _print_summary() -> void:
	print("")
	print("═══════════════════════════════════════════════════")
	if _failed == 0:
		print("  ALL PASSED — %d tests" % _total_tests)
	else:
		print("  FAILED — %d/%d passed, %d failed" % [_passed, _total_tests, _failed])
		print("")
		for err in _errors:
			print("    ✗ %s" % err)
	print("═══════════════════════════════════════════════════")
	print("")
