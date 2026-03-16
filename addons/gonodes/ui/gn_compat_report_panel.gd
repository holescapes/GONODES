class_name GNCompatReportPanel
extends PanelContainer
## Export Compatibility Report — editor panel that scans the current network
## against a target platform + renderer and lists incompatible nodes.
##
## Usage: Added to the editor toolbar (row 2), toggled via "Compat" CheckButton.
## Provides a "Copy Report" button that copies a plain-text summary to clipboard.

signal node_selected(node_id: String)

# ─── State ────────────────────────────────────────────────────────────────────

var network: GNNetwork = null

var _platform_btn: OptionButton = null
var _renderer_btn: OptionButton = null
var _report_tree: Tree = null
var _summary_label: Label = null
var _copy_btn: Button = null

const _PLATFORMS := ["windows", "macos", "linux", "android", "ios", "web"]
const _RENDERERS := ["forward_plus", "mobile", "gl_compatibility"]
const _RENDERER_LABELS := ["Forward+", "Mobile", "Compatibility"]

# ─── Setup ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	custom_minimum_size.y = 200
	_build_ui()
	_scan()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Top bar: dropdowns + buttons ──
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	var plat_label := Label.new()
	plat_label.text = "Platform:"
	top.add_child(plat_label)

	_platform_btn = OptionButton.new()
	for p in _PLATFORMS:
		_platform_btn.add_item(p)
	# Default to current platform
	var cur_plat: String = GNGpuContext.get_current_platform()
	var plat_idx: int = _PLATFORMS.find(cur_plat)
	if plat_idx >= 0:
		_platform_btn.selected = plat_idx
	_platform_btn.item_selected.connect(func(_i: int): _scan())
	top.add_child(_platform_btn)

	top.add_child(VSeparator.new())

	var rend_label := Label.new()
	rend_label.text = "Renderer:"
	top.add_child(rend_label)

	_renderer_btn = OptionButton.new()
	for i in range(_RENDERERS.size()):
		_renderer_btn.add_item(_RENDERER_LABELS[i])
	# Default to current renderer
	var cur_rend: String = GNGpuContext.get_current_renderer()
	var rend_idx: int = _RENDERERS.find(cur_rend)
	if rend_idx >= 0:
		_renderer_btn.selected = rend_idx
	_renderer_btn.item_selected.connect(func(_i: int): _scan())
	top.add_child(_renderer_btn)

	top.add_child(VSeparator.new())

	_copy_btn = Button.new()
	_copy_btn.text = "Copy Report"
	_copy_btn.tooltip_text = "Copy the compatibility report to clipboard"
	_copy_btn.pressed.connect(_copy_report)
	top.add_child(_copy_btn)

	# ── Summary line ──
	_summary_label = Label.new()
	_summary_label.text = ""
	_summary_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_summary_label)

	# ── Tree (node list) ──
	_report_tree = Tree.new()
	_report_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report_tree.columns = 4
	_report_tree.set_column_title(0, "Node")
	_report_tree.set_column_title(1, "Family")
	_report_tree.set_column_title(2, "Issue")
	_report_tree.set_column_title(3, "Detail")
	_report_tree.column_titles_visible = true
	_report_tree.set_column_expand_ratio(0, 2)
	_report_tree.set_column_expand_ratio(1, 1)
	_report_tree.set_column_expand_ratio(2, 2)
	_report_tree.set_column_expand_ratio(3, 3)
	_report_tree.item_selected.connect(_on_item_selected)
	vbox.add_child(_report_tree)


# ─── Scanning ─────────────────────────────────────────────────────────────────

## Rescans the network against the selected platform+renderer.
## Called automatically when dropdowns change and can be called externally.
func _scan() -> void:
	if _report_tree == null:
		return

	_report_tree.clear()
	var root := _report_tree.create_item()

	if network == null:
		_summary_label.text = "No network loaded."
		return

	var target_platform: String = _PLATFORMS[_platform_btn.selected]
	var target_renderer: String = _RENDERERS[_renderer_btn.selected]
	var renderer_label: String = _RENDERER_LABELS[_renderer_btn.selected]
	var has_compute: bool = target_renderer != "gl_compatibility"

	var issues: Array[Dictionary] = []

	for node_id: String in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node == null:
			continue

		var node_type: String = node.node_type if "node_type" in node else node_id

		# Check renderer compatibility
		var supported_rend: PackedStringArray = node.supported_renderers()
		if not supported_rend.has(target_renderer):
			var has_fallback: bool = node.has_cpu_fallback()
			var detail: String
			if has_fallback:
				detail = "Will run on CPU instead of GPU — reduced performance"
			else:
				if not has_compute and node.requires_compute():
					detail = "%s has no compute shaders — node disabled, output = null, downstream receives empty input" % renderer_label
				else:
					detail = "Not supported on %s — node disabled, output = null, downstream receives empty input" % renderer_label
			issues.append({
				"node_id": node_id,
				"node_name": node.display_name if "display_name" in node else node_id,
				"node_type": node_type,
				"family": node.get_family_name() if node.has_method("get_family_name") else "?",
				"issue": "Renderer: needs %s" % "/".join(supported_rend),
				"detail": detail,
				"severity": "warn" if has_fallback else "error",
			})

		# Check platform compatibility
		var supported_plat: PackedStringArray = node.supported_platforms()
		if not supported_plat.has(target_platform):
			issues.append({
				"node_id": node_id,
				"node_name": node.display_name if "display_name" in node else node_id,
				"node_type": node_type,
				"family": node.get_family_name() if node.has_method("get_family_name") else "?",
				"issue": "Platform: only available on %s" % "/".join(supported_plat),
				"detail": "Node disabled on %s — output = null, downstream receives empty input" % target_platform,
				"severity": "error",
			})

	# ── Multi-WindowOUT check for single-window platforms ────────────
	var is_single_window: bool = target_platform in ["web", "android", "ios"]
	if is_single_window:
		var window_out_ids: PackedStringArray = []
		for node_id: String in network.nodes:
			var node: GNNode = network.nodes[node_id]
			if node != null and node.node_type == "window":
				window_out_ids.append(node_id)
		if window_out_ids.size() > 1:
			for wid in window_out_ids:
				issues.append({
					"node_id": wid,
					"node_name": wid,
					"node_type": "window",
					"family": "OUT",
					"issue": "Multi-window: %d WindowOUTs, platform supports 1" % window_out_ids.size(),
					"detail": "%s only supports a single window — extra WindowOUTs cook but won't open" % target_platform,
					"severity": "warn",
				})

	# Populate tree
	for entry: Dictionary in issues:
		var item := _report_tree.create_item(root)
		item.set_text(0, entry["node_name"])
		item.set_text(1, entry["family"])
		item.set_text(2, entry["issue"])
		item.set_text(3, entry["detail"])
		item.set_metadata(0, entry["node_id"])
		if entry["severity"] == "error":
			item.set_custom_color(0, Color(1.0, 0.35, 0.35))
			item.set_custom_color(2, Color(1.0, 0.35, 0.35))
		else:
			item.set_custom_color(0, Color(1.0, 0.85, 0.2))
			item.set_custom_color(2, Color(1.0, 0.85, 0.2))

	# Summary
	var node_count: int = network.nodes.size()
	var issue_count: int = issues.size()
	var error_count: int = issues.filter(func(e: Dictionary): return e["severity"] == "error").size()
	var warn_count: int = issue_count - error_count

	if issue_count == 0:
		_summary_label.text = "✓ All %d nodes fully compatible with %s / %s" % [
			node_count, target_platform, renderer_label]
		_summary_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		var parts: PackedStringArray = []
		if error_count > 0:
			parts.append("%d skipped" % error_count)
		if warn_count > 0:
			parts.append("%d CPU fallback" % warn_count)
		_summary_label.text = "%d of %d nodes affected (%s) — %s / %s" % [
			issue_count, node_count, ", ".join(parts),
			target_platform, renderer_label]
		if error_count > 0:
			_summary_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		else:
			_summary_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


func _on_item_selected() -> void:
	var item := _report_tree.get_selected()
	if item == null:
		return
	var nid = item.get_metadata(0)
	if nid is String and not nid.is_empty():
		node_selected.emit(nid)


# ─── Report Generation ────────────────────────────────────────────────────────

func _copy_report() -> void:
	var target_platform: String = _PLATFORMS[_platform_btn.selected]
	var target_renderer: String = _RENDERER_LABELS[_renderer_btn.selected]

	var lines: PackedStringArray = PackedStringArray()
	lines.append("GONODES Export Compatibility Report")
	lines.append("Target: %s / %s" % [target_platform, target_renderer])
	lines.append("Date: %s" % Time.get_datetime_string_from_system())
	lines.append("")

	if network == null:
		lines.append("No network loaded.")
		DisplayServer.clipboard_set("\n".join(lines))
		return

	lines.append("Nodes: %d" % network.nodes.size())
	lines.append("")

	var root := _report_tree.get_root()
	if root == null:
		DisplayServer.clipboard_set("\n".join(lines))
		return

	var child := root.get_first_child()
	if child == null:
		lines.append("All nodes compatible.")
	else:
		lines.append("%-24s %-10s %-30s %s" % ["NODE", "FAMILY", "ISSUE", "DETAIL"])
		lines.append("-".repeat(90))
		while child != null:
			lines.append("%-24s %-10s %-30s %s" % [
				child.get_text(0), child.get_text(1),
				child.get_text(2), child.get_text(3)])
			child = child.get_next()

	lines.append("")
	lines.append("End of report.")
	DisplayServer.clipboard_set("\n".join(lines))

	# Flash button text as feedback
	_copy_btn.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_copy_btn):
			_copy_btn.text = "Copy Report")
