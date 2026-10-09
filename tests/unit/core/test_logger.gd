extends Node
## Godot's own output is copied into GNLogger, and GNLogger lines are not copied twice.


func test_godot_print_lands_in_logger_once() -> void:
	var prev_enabled := GNLogger.enabled
	var prev_level := GNLogger.level
	var prev_sink := GNLogger.log_sink
	var lines: Array[Dictionary] = []
	GNLogger.install_godot_bridge()
	GNLogger.enabled = true
	GNLogger.level = GNLogger.Level.DEBUG
	GNLogger.log_sink = func(lvl: GNLogger.Level, category: String, message: String) -> void:
		lines.append({ "level": lvl, "category": category, "message": message })

	var token := "bridge-unique-%d" % Time.get_ticks_usec()
	print(token)
	var godot_hits := 0
	for row in lines:
		if row["category"] == "Godot" and str(row["message"]).contains(token):
			godot_hits += 1
	GNTestAssert.assert_eq(godot_hits, 1, "one Godot copy of print()")

	lines.clear()
	var own := "only-once-%d" % Time.get_ticks_usec()
	GNLogger.info("Test", own)
	var own_hits := 0
	var echo_hits := 0
	for row in lines:
		if not str(row["message"]).contains(own):
			continue
		if row["category"] == "Test":
			own_hits += 1
		elif row["category"] == "Godot":
			echo_hits += 1
	GNTestAssert.assert_eq(own_hits, 1, "GNLogger line kept")
	GNTestAssert.assert_eq(echo_hits, 0, "GNLogger line not copied back from Godot")

	lines.clear()
	var warn_token := "bridge-warn-%d" % Time.get_ticks_usec()
	# Call the bridge directly. push_warning() itself fails this runner.
	GNLogger._godot_bridge._log_error(
		"push_warning", "res://tests/unit/core/test_logger.gd", 40,
		"", warn_token, false, 1, [])
	var warn_hits := 0
	var warn_level := -1
	for row in lines:
		if row["category"] == "Godot" and str(row["message"]).contains(warn_token):
			warn_hits += 1
			warn_level = row["level"]
	GNTestAssert.assert_eq(warn_hits, 1, "one Godot copy of a warning")
	GNTestAssert.assert_eq(warn_level, GNLogger.Level.WARN, "warning stays a warning")

	GNLogger.enabled = prev_enabled
	GNLogger.level = prev_level
	GNLogger.log_sink = prev_sink


func test_logger_panel_draws_only_while_open() -> void:
	var prev_enabled := GNLogger.enabled
	var prev_level := GNLogger.level
	var prev_limit := GNLogger.panel_line_limit
	var panel := GNLogPanel.new()
	var dbg: CheckButton = panel._filter_buttons[GNLogger.Level.DEBUG]
	GNTestAssert.assert_false(dbg.button_pressed, "DBG filter starts off")

	GNLogger.enabled = true
	GNLogger.set_baseline_level(GNLogger.Level.INFO)
	GNLogger.install_godot_bridge()
	panel.visible = false
	var token := "held-%d" % Time.get_ticks_usec()
	print(token)
	GNTestAssert.assert_true(GNLogger.enabled, "closed panel still captures")
	GNTestAssert.assert_false(
		GNLogger.will_log(GNLogger.Level.DEBUG, "CookEngine"),
		"DBG off skips per-cook debug")

	var found_token := false
	var found_engine := false
	for row in GNLogger.get_recent_lines():
		var text := str(row["message"])
		if text.contains(token):
			found_token = true
		if text.begins_with("Godot Engine v"):
			found_engine = true
	GNTestAssert.assert_true(found_token, "print while closed is captured")
	GNTestAssert.assert_true(found_engine, "engine banner is captured")

	panel.visible = true
	panel.refresh_from_buffer()
	found_token = false
	found_engine = false
	for row in panel._entries:
		var shown := str(row["message"])
		if shown.contains(token):
			found_token = true
		if shown.begins_with("Godot Engine v"):
			found_engine = true
	GNTestAssert.assert_true(found_token, "opening the panel shows the captured print")
	GNTestAssert.assert_true(found_engine, "opening the panel shows the engine banner")
	GNTestAssert.assert_eq(GNLogger.level, GNLogger.Level.INFO, "panel stays at info")

	dbg.button_pressed = true
	GNTestAssert.assert_eq(GNLogger.level, GNLogger.Level.DEBUG, "DBG on includes debug")
	GNTestAssert.assert_true(
		GNLogger.will_log(GNLogger.Level.DEBUG, "CookEngine"),
		"DBG on allows per-cook debug")

	panel.visible = false
	GNTestAssert.assert_true(GNLogger.enabled, "closing the panel keeps capture")
	GNTestAssert.assert_eq(GNLogger.level, GNLogger.Level.DEBUG, "closing the panel keeps DBG")

	dbg.button_pressed = false
	GNTestAssert.assert_eq(GNLogger.level, GNLogger.Level.INFO, "DBG off restores the preference level")

	GNLogger.enabled = prev_enabled
	GNLogger.level = prev_level
	GNLogger.set_panel_line_limit(prev_limit)
	panel.free()


func test_logger_panel_keeps_latest_lines_only() -> void:
	var prev_limit := GNLogger.panel_line_limit
	var prev_level := GNLogger.level
	GNLogger.enabled = true
	GNLogger.level = GNLogger.Level.INFO
	GNLogger.clear_recent_lines()
	GNLogger.set_panel_line_limit(2)
	GNLogger.info("Test", "line-a")
	GNLogger.info("Test", "line-b")
	GNLogger.info("Test", "line-c")
	var recent := GNLogger.get_recent_lines()
	GNTestAssert.assert_eq(recent.size(), 2, "panel window drops the oldest line")
	GNTestAssert.assert_eq(str(recent[0]["message"]), "line-b", "oldest kept line")
	GNTestAssert.assert_eq(str(recent[1]["message"]), "line-c", "newest line")
	GNLogger.set_panel_line_limit(prev_limit)
	GNLogger.level = prev_level


func test_logger_file_beside_patch_and_backlog() -> void:
	GNTestAssert.assert_eq(GNLogger.sanitize_log_file_name("  session.log "), "session.log", "file name is trimmed")
	GNTestAssert.assert_eq(GNLogger.sanitize_log_file_name("a/b.log"), "", "a path is rejected")
	var patch := "C:/show/patch.gnpatch"
	var beside := GNLogger.log_path_beside_patch(patch, "session.log")
	GNTestAssert.assert_eq(beside.get_file(), "session.log", "log uses the given file name")
	GNTestAssert.assert_eq(beside.get_base_dir(), patch.get_base_dir(), "log sits beside the patch")
	GNTestAssert.assert_eq(GNLogger.log_path_beside_patch("", "session.log"), "", "no patch means no file yet")

	var prev_enabled := GNLogger.enabled
	var prev_level := GNLogger.level
	GNLogger.enabled = true
	GNLogger.level = GNLogger.Level.INFO
	GNLogger.close_log_file()
	GNLogger.arm_log_file()
	var token := "file-%d" % Time.get_ticks_usec()
	GNLogger.info("Test", token)
	var path := "user://gn_logger_test_%d.log" % Time.get_ticks_usec()
	GNLogger.set_log_file(path)
	GNLogger.info("Test", token + "-live")
	GNLogger.set_log_file(path)
	GNLogger.close_log_file()

	var text := FileAccess.get_file_as_string(path)
	GNTestAssert.assert_true(text.contains(token), "lines before the file opened are written")
	GNTestAssert.assert_true(text.contains(token + "-live"), "later lines are appended")
	var header_count := text.count("# GONODES log")
	GNTestAssert.assert_eq(header_count, 1, "reopening the same file does not restart it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	GNLogger.enabled = prev_enabled
	GNLogger.level = prev_level


func test_logger_error_dat_probe_does_not_warn() -> void:
	var prev_sink := GNLogger.log_sink
	var prev_enabled := GNLogger.enabled
	var prev_level := GNLogger.level
	GNLogger.enabled = true
	GNLogger.level = GNLogger.Level.INFO
	var probe := ErrorDAT.new()
	var took_log := GNLogger.log_sink.is_valid() and GNLogger.log_sink.get_object() == probe
	GNTestAssert.assert_false(took_log, "a bare ErrorDAT does not take the log")
	GNLogger.info("Test", "probe-ok-%d" % Time.get_ticks_usec())
	probe.free()
	GNLogger.enabled = prev_enabled
	GNLogger.level = prev_level
	GNLogger.log_sink = prev_sink
