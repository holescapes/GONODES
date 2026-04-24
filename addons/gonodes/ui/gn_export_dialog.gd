class_name GNExportDialog
extends Window
## Export dialog for building standalone GONODES applications.
##
## The user picks a concrete target platform (OS + architecture) and a renderer
## independently.  Eight platform targets cover all Godot export configurations:
##
##   windows_x86_64, windows_arm64, linux_x86_64, linux_arm64, macos,
##   android, ios, web
##
## Three renderers are available:  Forward+, Mobile, Compatibility.
## The user chooses the renderer — we don't force it per platform.
##
## Before building, the dialog scans the current network against the target
## platform + renderer and shows a compatibility summary.  Warnings (CPU
## fallback) don't block the build; errors (unsupported nodes) show but
## the user can still proceed — the nodes will simply be skipped at runtime.
##
## A template-availability hint is shown when no pre-built Player template
## exists for the selected platform.


## Emitted when user confirms the export.  The editor wires this to start the build.
signal export_requested(settings: Dictionary)


# ─── Platform definitions ─────────────────────────────────────────────────────

## Internal platform IDs — each maps 1:1 to a templates/<id>/ directory.
const _PLATFORM_IDS := [
	"windows_x86_64", "windows_arm64",
	"linux_x86_64", "linux_arm64",
	"macos",
	"android", "ios", "web",
]

## Display names for the platform dropdown (same order as _PLATFORM_IDS).
const _PLATFORM_LABELS := [
	"Windows x86_64", "Windows ARM64",
	"Linux x86_64", "Linux ARM64",
	"macOS (Universal)",
	"Android", "iOS", "Web",
]

## Maps each platform ID to the OS-level string used by supported_platforms().
## Desktop variants collapse to their base OS name; mobile/web are identity.
const _PLATFORM_TO_OS := {
	"windows_x86_64": "windows",
	"windows_arm64":  "windows",
	"linux_x86_64":   "linux",
	"linux_arm64":    "linux",
	"macos":          "macos",
	"android":        "android",
	"ios":            "ios",
	"web":            "web",
}

# ─── Renderer definitions ─────────────────────────────────────────────────────

## Internal renderer IDs (Godot's canonical strings).
const _RENDERER_IDS := ["forward_plus", "mobile", "gl_compatibility"]

## Display names for the renderer dropdown.
const _RENDERER_LABELS := ["Forward+", "Mobile", "Compatibility"]

## Allowed renderer indices per platform.  Indices into _RENDERER_IDS / _RENDERER_LABELS.
## Desktop: all three.  Android/iOS: Mobile + Compatibility.  Web: Compatibility only.
const _PLATFORM_ALLOWED_RENDERERS := {
	"windows_x86_64": [0, 1, 2],
	"windows_arm64":  [0, 1, 2],
	"linux_x86_64":   [0, 1, 2],
	"linux_arm64":    [0, 1, 2],
	"macos":          [0, 1, 2],
	"android":        [1, 2],     # Mobile, Compatibility
	"ios":            [1, 2],     # Mobile, Compatibility
	"web":            [2],        # Compatibility only
}


# ─── Controls ──────────────────────────────────────────────────────────────────

var _platform_btn: OptionButton
var _renderer_btn: OptionButton
var _template_hint: Label
var _output_dir_edit: LineEdit
var _browse_btn: Button
var _build_btn: Button
var _cancel_btn: Button
var _progress_label: Label
var _compat_label: RichTextLabel
var _dir_dialog: FileDialog

## Currently active exporter (null when idle).
var _exporter: RefCounted = null

## Patch path set by the editor before showing.
var patch_path: String = ""

## Network reference set by the editor — used for compat scan.
var network: GNNetwork = null


func _ready() -> void:
	title = "Export Patch"
	size = Vector2i(620, 540)
	exclusive = true
	unresizable = false

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# ── Platform ─────────────────────────────────────────────────────────
	vbox.add_child(_make_label("Target Platform"))
	_platform_btn = OptionButton.new()
	for label in _PLATFORM_LABELS:
		_platform_btn.add_item(label)
	_platform_btn.selected = _detect_host_platform_index()
	_platform_btn.item_selected.connect(_on_selection_changed)
	vbox.add_child(_platform_btn)

	# ── Renderer ─────────────────────────────────────────────────────────
	vbox.add_child(_make_label("Renderer"))
	_renderer_btn = OptionButton.new()
	_renderer_btn.item_selected.connect(_on_selection_changed)
	vbox.add_child(_renderer_btn)
	_populate_renderer_dropdown(_platform_btn.selected)

	# ── Template availability hint ───────────────────────────────────────
	_template_hint = Label.new()
	_template_hint.add_theme_font_size_override("font_size", 12)
	_template_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_template_hint)

	# ── Output Directory ─────────────────────────────────────────────────
	vbox.add_child(_make_label("Output Directory"))
	var dir_hbox := HBoxContainer.new()
	dir_hbox.add_theme_constant_override("separation", 4)
	_output_dir_edit = LineEdit.new()
	_output_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_dir_edit.placeholder_text = "Choose output folder..."
	dir_hbox.add_child(_output_dir_edit)
	_browse_btn = Button.new()
	_browse_btn.text = "Browse..."
	_browse_btn.pressed.connect(_on_browse_pressed)
	dir_hbox.add_child(_browse_btn)
	vbox.add_child(dir_hbox)

	# ── Compatibility Summary ────────────────────────────────────────────
	vbox.add_child(_make_label("Compatibility"))
	_compat_label = RichTextLabel.new()
	_compat_label.bbcode_enabled = true
	_compat_label.fit_content = false
	_compat_label.custom_minimum_size.y = 120
	_compat_label.scroll_active = true
	_compat_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_compat_label)

	# ── Progress ─────────────────────────────────────────────────────────
	_progress_label = Label.new()
	_progress_label.text = ""
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_progress_label)

	# ── Buttons ──────────────────────────────────────────────────────────
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	_cancel_btn = Button.new()
	_cancel_btn.text = "Cancel"
	_cancel_btn.pressed.connect(func(): hide())
	btn_hbox.add_child(_cancel_btn)
	_build_btn = Button.new()
	_build_btn.text = "Build"
	_build_btn.pressed.connect(_on_build_pressed)
	btn_hbox.add_child(_build_btn)
	vbox.add_child(btn_hbox)

	# ── Directory picker dialog ──────────────────────────────────────────
	_dir_dialog = FileDialog.new()
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.title = "Choose Output Directory"
	_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dir_dialog.dir_selected.connect(_on_dir_selected)
	add_child(_dir_dialog)

	close_requested.connect(func(): hide())

	# Initial UI update
	_update_template_hint()


# ═══════════════════════════════════════════════════════════════════════════════
# Public
# ═══════════════════════════════════════════════════════════════════════════════

## Shows the dialog, pre-filling output directory from the patch path.
func show_for_patch(p_patch_path: String, p_network: GNNetwork = null) -> void:
	patch_path = p_patch_path
	network = p_network

	if not patch_path.is_empty():
		var stem := patch_path.get_file().get_basename()
		var default_dir := patch_path.get_base_dir().path_join(stem + "_build")
		_output_dir_edit.text = default_dir

	_progress_label.text = ""
	_build_btn.disabled = false
	_update_template_hint()
	_run_compat_scan()
	popup_centered()


## Returns the current settings as a Dictionary.
func get_export_settings() -> Dictionary:
	return {
		"platform": _PLATFORM_IDS[_platform_btn.selected],
		"renderer": _RENDERER_IDS[_get_selected_renderer_index()],
		"output_dir": _output_dir_edit.text,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# Host Detection
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the _PLATFORM_IDS index matching the host machine.
func _detect_host_platform_index() -> int:
	var os_name := OS.get_name()
	var arch := Engine.get_architecture_name()  # e.g. "x86_64", "arm64"
	var is_arm: bool = arch.contains("arm") or arch.contains("aarch")

	var host_id: String
	match os_name:
		"Windows":
			host_id = "windows_arm64" if is_arm else "windows_x86_64"
		"Linux", "FreeBSD":
			host_id = "linux_arm64" if is_arm else "linux_x86_64"
		"macOS":
			host_id = "macos"
		"Android":
			host_id = "android"
		"iOS":
			host_id = "ios"
		"Web":
			host_id = "web"
		_:
			host_id = "windows_x86_64"

	var idx: int = _PLATFORM_IDS.find(host_id)
	return idx if idx >= 0 else 0


## Repopulates the renderer dropdown with only the renderers allowed for the
## given platform, and selects the best default.
func _populate_renderer_dropdown(plat_idx: int) -> void:
	var plat_id: String = _PLATFORM_IDS[plat_idx]
	var allowed: Array = _PLATFORM_ALLOWED_RENDERERS.get(plat_id, [0, 1, 2])

	_renderer_btn.clear()
	for ri: int in allowed:
		_renderer_btn.add_item(_RENDERER_LABELS[ri])
		# Store the real _RENDERER_IDS index as item metadata
		_renderer_btn.set_item_metadata(_renderer_btn.item_count - 1, ri)

	# Pick the best default: first allowed entry is already the recommended one
	_renderer_btn.selected = 0


## Returns the real _RENDERER_IDS index for the currently selected renderer item.
func _get_selected_renderer_index() -> int:
	var sel: int = _renderer_btn.selected
	if sel < 0:
		return 2  # Compatibility fallback
	return _renderer_btn.get_item_metadata(sel)


# ═══════════════════════════════════════════════════════════════════════════════
# Template Availability
# ═══════════════════════════════════════════════════════════════════════════════

## Checks whether a template directory exists for the selected platform
## and updates the hint label accordingly.
func _update_template_hint() -> void:
	if _template_hint == null:
		return

	var plat_id: String = _PLATFORM_IDS[_platform_btn.selected]
	var plat_label: String = _PLATFORM_LABELS[_platform_btn.selected]

	# Use the same search logic as GNPatchExporter._find_template_dir()
	var found := false
	var search_roots: PackedStringArray = []
	search_roots.append(ProjectSettings.globalize_path("res://"))
	search_roots.append(OS.get_executable_path().get_base_dir())

	for root in search_roots:
		var candidate := root.path_join("templates").path_join(plat_id)
		if DirAccess.dir_exists_absolute(candidate):
			var d := DirAccess.open(candidate)
			if d != null:
				d.list_dir_begin()
				var first := d.get_next()
				d.list_dir_end()
				if not first.is_empty():
					found = true
					break

	if found:
		_template_hint.text = ""
		_template_hint.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		_template_hint.text = ("No template found for %s. "
			+ "Build it first: scripts/build_templates -Platforms %s") % [plat_label, plat_id]
		_template_hint.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))


# ═══════════════════════════════════════════════════════════════════════════════
# Compatibility Scan
# ═══════════════════════════════════════════════════════════════════════════════

## Scans the network against the selected platform+renderer and updates
## the compatibility summary label with descriptive per-node impact text.
func _run_compat_scan() -> void:
	if _compat_label == null:
		return

	var plat_idx: int = _platform_btn.selected
	var plat_id: String = _PLATFORM_IDS[plat_idx]
	var plat_label: String = _PLATFORM_LABELS[plat_idx]
	var rend_idx: int = _get_selected_renderer_index()
	var target_renderer: String = _RENDERER_IDS[rend_idx]
	var renderer_label: String = _RENDERER_LABELS[rend_idx]
	var has_compute: bool = target_renderer != "gl_compatibility"

	if network == null or network.nodes.is_empty():
		_compat_label.text = "[color=#aaaaaa]No nodes to check.[/color]"
		return

	# Map concrete platform ID to OS-level name for supported_platforms() checks
	var check_platform: String = _PLATFORM_TO_OS.get(plat_id, plat_id)

	# Categorize every affected node with its type and reason
	# skipped: {node_id: {type, reason}}  — node output will be null
	# cpu_fallback: {node_id: {type, reason}}  — runs on CPU instead of GPU
	# platform_blocked: {node_id: {type, reason}}  — OS-level incompatibility
	var skipped: Array[Dictionary] = []
	var cpu_fallback: Array[Dictionary] = []
	var platform_blocked: Array[Dictionary] = []

	for node_id: String in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node == null:
			continue

		var node_type: String = node.node_type if "node_type" in node else node_id
		var family: String = node.get_family_name() if node.has_method("get_family_name") else "?"

		# Renderer check
		var sr: PackedStringArray = node.supported_renderers()
		if not sr.has(target_renderer):
			if node.has_cpu_fallback():
				cpu_fallback.append({
					"id": node_id, "type": node_type, "family": family,
					"needs": "/".join(sr),
				})
			else:
				skipped.append({
					"id": node_id, "type": node_type, "family": family,
					"needs": "/".join(sr),
				})

		# Platform check
		var sp: PackedStringArray = node.supported_platforms()
		if not sp.has(check_platform):
			# Avoid adding to platform_blocked if already in skipped
			var already_flagged := false
			for s in skipped:
				if s["id"] == node_id:
					already_flagged = true
					break
			if not already_flagged:
				platform_blocked.append({
					"id": node_id, "type": node_type, "family": family,
					"platforms": "/".join(sp),
				})

	var total: int = network.nodes.size()
	var lines: PackedStringArray = []

	# ── Multi-WindowOUT check (single-window platforms) ───────────────
	var is_single_window: bool = check_platform in ["web", "android", "ios"]
	var window_out_ids: PackedStringArray = []
	if is_single_window:
		for node_id: String in network.nodes:
			var node: GNNode = network.nodes[node_id]
			if node != null and node.node_type == "window":
				window_out_ids.append(node_id)

	var has_multi_window_warn: bool = is_single_window and window_out_ids.size() > 1

	if skipped.is_empty() and cpu_fallback.is_empty() and platform_blocked.is_empty() and not has_multi_window_warn:
		lines.append("[color=#66ff66]✓ All %d nodes fully compatible with %s / %s.[/color]" % [
			total, plat_label, renderer_label])
		_compat_label.text = "\n".join(lines)
		return

	if not skipped.is_empty() or not cpu_fallback.is_empty() or not platform_blocked.is_empty():
		# ── Header ────────────────────────────────────────────────────
		var issue_total: int = skipped.size() + cpu_fallback.size() + platform_blocked.size()
		lines.append("[color=#aaaaaa]%d of %d node(s) affected by %s / %s:[/color]" % [
			issue_total, total, plat_label, renderer_label])

	# ── Skipped nodes (no fallback — output will be null) ─────────────
	if not skipped.is_empty():
		lines.append("")
		lines.append("[color=#ff5555][b]Skipped (%d)[/b] — these nodes will be disabled (output = null).[/color]" % skipped.size())
		if not has_compute:
			lines.append("[color=#ff8888]  The %s renderer has no compute shader support.[/color]" % renderer_label)
		for entry in skipped:
			lines.append("[color=#ff8888]  • %s [/color][color=#aaaaaa](%s) — requires %s[/color]" % [
				entry["id"], entry["type"], entry["needs"]])
		lines.append("[color=#ff8888]  Downstream nodes wired to these will receive empty input.[/color]")

	# ── CPU fallback nodes (slower but functional) ────────────────────
	if not cpu_fallback.is_empty():
		lines.append("")
		lines.append("[color=#ffdd33][b]CPU Fallback (%d)[/b] — these nodes will run on CPU instead of GPU.[/color]" % cpu_fallback.size())
		lines.append("[color=#ffdd88]  Performance will be reduced compared to the GPU compute path.[/color]")
		for entry in cpu_fallback:
			lines.append("[color=#ffdd88]  • %s [/color][color=#aaaaaa](%s) — GPU needs %s, falling back to CPU[/color]" % [
				entry["id"], entry["type"], entry["needs"]])

	# ── Platform-blocked nodes ────────────────────────────────────────
	if not platform_blocked.is_empty():
		lines.append("")
		lines.append("[color=#ff5555][b]Platform Unavailable (%d)[/b] — these nodes don't support %s.[/color]" % [
			platform_blocked.size(), plat_label])
		for entry in platform_blocked:
			lines.append("[color=#ff8888]  • %s [/color][color=#aaaaaa](%s) — only available on %s[/color]" % [
				entry["id"], entry["type"], entry["platforms"]])

	# ── Multi-WindowOUT warning for single-window platforms ──────────
	if has_multi_window_warn:
		lines.append("")
		lines.append("[color=#ffdd33][b]Multi-Window (%d WindowOUTs)[/b] — %s only supports a single window.[/color]" % [
			window_out_ids.size(), plat_label])
		lines.append("[color=#ffdd88]  Only one WindowOUT will display. The others will cook but their windows won't open.[/color]")
		for wid in window_out_ids:
			lines.append("[color=#ffdd88]  • %s[/color]" % wid)
		lines.append("[color=#ffdd88]  Consider merging outputs into a single WindowOUT using CompositeTOP or LayoutTOP.[/color]")

	_compat_label.text = "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════════════
# Callbacks
# ═══════════════════════════════════════════════════════════════════════════════

## Called when either the platform or renderer dropdown changes.
func _on_selection_changed(_idx: int) -> void:
	# If the platform changed, repopulate the renderer list for the new platform
	var plat_id: String = _PLATFORM_IDS[_platform_btn.selected]
	var allowed: Array = _PLATFORM_ALLOWED_RENDERERS.get(plat_id, [0, 1, 2])
	var current_renderer_count: int = _renderer_btn.item_count
	if current_renderer_count != allowed.size():
		_populate_renderer_dropdown(_platform_btn.selected)
	else:
		# Verify items still match (handles switching between platforms with same count)
		var mismatch := false
		for i in current_renderer_count:
			if _renderer_btn.get_item_metadata(i) != allowed[i]:
				mismatch = true
				break
		if mismatch:
			_populate_renderer_dropdown(_platform_btn.selected)
	_update_template_hint()
	_run_compat_scan()


func _on_browse_pressed() -> void:
	if not _output_dir_edit.text.is_empty():
		_dir_dialog.current_dir = _output_dir_edit.text
	_dir_dialog.popup_centered(Vector2i(600, 400))


func _on_dir_selected(dir: String) -> void:
	_output_dir_edit.text = dir


func _on_build_pressed() -> void:
	var out_dir: String = _output_dir_edit.text.strip_edges()
	if out_dir.is_empty():
		_progress_label.text = "Please choose an output directory."
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		return
	if patch_path.is_empty():
		_progress_label.text = "No patch file loaded. Save your patch first."
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		return

	_build_btn.disabled = true
	_progress_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_progress_label.text = "Starting build..."

	var platform_id: String = _PLATFORM_IDS[_platform_btn.selected]
	var renderer_id: String = _RENDERER_IDS[_get_selected_renderer_index()]

	# Configure exporter
	_exporter = GNPatchExporter.new()
	_exporter.patch_path = patch_path
	_exporter.output_dir = out_dir
	_exporter.target_platform = platform_id
	_exporter.target_renderer = renderer_id
	_exporter.progress.connect(_on_export_progress)
	_exporter.completed.connect(_on_export_completed)

	# Run the build
	_exporter.quick_build()


func _on_export_progress(message: String) -> void:
	_progress_label.text = message


func _on_export_completed(success: bool, message: String) -> void:
	_build_btn.disabled = false
	if success:
		_progress_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_progress_label.text = message
	else:
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_progress_label.text = message
	_exporter = null


# ═══════════════════════════════════════════════════════════════════════════════
# UI Helpers
# ═══════════════════════════════════════════════════════════════════════════════

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl
