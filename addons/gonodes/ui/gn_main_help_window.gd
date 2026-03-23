class_name GNMainHelpWindow
extends Window
## Main in-editor Help Reference Hub.
##
## Displays an organized sidebar Tree on the left with documentation sections,
## and a RichTextLabel content pane on the right.  Markdown files from
## `res://addons/gonodes/help/` are lazily loaded and rendered to BBCode via
## GNMarkdownRenderer.
##
## Sections:
##   1. Getting Started — overview, families, first-patch walkthrough
##   2. Editor Guide — keyboard shortcuts, toolbar, inspector, mouse
##   3. Expressions & Scripting — expressions, cross-node refs, script operators
##   4. Operators Reference — per-family expandable list with descriptions
##   5. Takes — parameter layer overrides for live performance
##   6. Timeline & Cues — local timelines, cue sequencer, show automation
##   7. Sub-Networks — containers, tunnels, grouping, dive navigation
##   8. Annotations — sticky notes and network boxes
##   9. Protocols — MIDI, OSC, and DMX setup and usage
##  10. Parameter Presets — copy/paste, save/load, factory presets
##  11. Cook Engine — how cooking works, dirty propagation, active chains
##  12. Player — standalone runtime, config.json, hotkeys, window management
##  13. Building — build scripts, Quick Build, export presets, GDExtensions
##  14. Extensions — how to write GNExtension addons
##  15. Troubleshooting — common issues, debugging, performance tips
##
## Opened via:  Toolbar "Help" button  or  F1

const HELP_DIR := "res://addons/gonodes/help"

## Category icons for sidebar tree items.
const _SECTION_ICONS := {
	"getting_started": "📖",
	"editor": "🔧",
	"expressions": "📐",
	"operators": "📋",
	"takes": "🎚️",
	"timeline": "⏱️",
	"sub_networks": "📦",
	"annotations": "📝",
	"protocols": "📡",
	"presets": "💾",
	"cook_engine": "⚙️",
	"player": "🎮",
	"building": "🏗️",
	"extensions": "🔌",
	"troubleshooting": "🩹",
}

## Map of sidebar keys → markdown file paths (relative to HELP_DIR).
const _SECTION_FILES := {
	"getting_started": "getting_started.md",
	"editor": "editor.md",
	"expressions": "expressions.md",
	"takes": "takes.md",
	"timeline": "timeline.md",
	"sub_networks": "sub_networks.md",
	"annotations": "annotations.md",
	"protocols": "protocols.md",
	"presets": "presets.md",
	"cook_engine": "cook_engine.md",
	"player": "player.md",
	"building": "building.md",
	"extensions": "extensions.md",
	"troubleshooting": "troubleshooting.md",
}

## Dark background to match per-node help windows.
const _BG_COLOR := Color(0.10, 0.10, 0.12)

## Minimum window dimensions.
const _MIN_SIZE := Vector2i(680, 480)
const _DEFAULT_SIZE := Vector2i(960, 680)

## Sidebar width (pixels).
const _SIDEBAR_WIDTH := 240

# ─── Internal Controls ────────────────────────────────────────────────────────

var _bg: ColorRect
var _hsplit: HSplitContainer
var _sidebar_vbox: VBoxContainer
var _search_edit: LineEdit
var _tree: Tree
var _scroll: ScrollContainer
var _rtl: RichTextLabel

## Content cache: section_key → rendered BBCode (lazy-loaded).
var _content_cache: Dictionary = {}

## Currently displayed section key.
var _active_section: String = ""

## Tree item metadata stores the section key string.
## For operator items, metadata is "op::<ClassName>".

## Tree root item (hidden).
var _tree_root: TreeItem


func _init() -> void:
	title = "GONODES — Help Reference"
	size = _DEFAULT_SIZE
	min_size = _MIN_SIZE
	unresizable = false
	always_on_top = false
	wrap_controls = true
	close_requested.connect(hide)


func _ready() -> void:
	# ── Background ──
	_bg = ColorRect.new()
	_bg.color = _BG_COLOR
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# ── HSplitContainer ──
	_hsplit = HSplitContainer.new()
	_hsplit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hsplit.set_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	_hsplit.split_offset = _SIDEBAR_WIDTH
	add_child(_hsplit)

	# ── Left: Sidebar ──
	_sidebar_vbox = VBoxContainer.new()
	_sidebar_vbox.custom_minimum_size.x = _SIDEBAR_WIDTH
	_sidebar_vbox.size_flags_horizontal = Control.SIZE_FILL
	_hsplit.add_child(_sidebar_vbox)

	# Search bar
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search help…"
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_on_search_changed)
	_sidebar_vbox.add_child(_search_edit)

	# Tree
	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.allow_search = false
	_tree.item_selected.connect(_on_tree_item_selected)
	_sidebar_vbox.add_child(_tree)

	# ── Right: Content Pane ──
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hsplit.add_child(right_panel)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_scroll)

	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content = true
	_rtl.scroll_active = false  # ScrollContainer handles scrolling
	_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rtl.selection_enabled = true
	_rtl.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	_rtl.add_theme_constant_override("line_separation", 4)
	_scroll.add_child(_rtl)

	# Build the sidebar contents
	_build_sidebar()

	# Show the welcome/getting-started section by default
	_show_section("getting_started")


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F and event.ctrl_pressed:
			# Ctrl+F focuses the search bar
			_search_edit.grab_focus()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# Sidebar Construction
# ═══════════════════════════════════════════════════════════════════════════════

func _build_sidebar() -> void:
	_tree.clear()
	_tree_root = _tree.create_item()

	# Sections with inline TOC from markdown headings
	_add_section_with_toc("getting_started", "%s  Getting Started" % _SECTION_ICONS["getting_started"])
	_add_section_with_toc("editor", "%s  Editor Guide" % _SECTION_ICONS["editor"])
	_add_section_with_toc("expressions", "%s  Expressions & Scripting" % _SECTION_ICONS["expressions"])

	# Operators section (expandable by family)
	var ops_item := _tree.create_item(_tree_root)
	ops_item.set_text(0, "%s  Operators Reference" % _SECTION_ICONS["operators"])
	ops_item.set_metadata(0, "operators")
	ops_item.collapsed = true

	_build_operator_tree(ops_item)

	# Workflow & features sections
	_add_section_with_toc("takes", "%s  Takes" % _SECTION_ICONS["takes"])
	_add_section_with_toc("timeline", "%s  Timeline & Cues" % _SECTION_ICONS["timeline"])
	_add_section_with_toc("sub_networks", "%s  Sub-Networks" % _SECTION_ICONS["sub_networks"])
	_add_section_with_toc("annotations", "%s  Annotations" % _SECTION_ICONS["annotations"])
	_add_section_with_toc("protocols", "%s  Protocols (MIDI / OSC / DMX)" % _SECTION_ICONS["protocols"])
	_add_section_with_toc("presets", "%s  Parameter Presets" % _SECTION_ICONS["presets"])

	# Engine & infrastructure sections
	_add_section_with_toc("cook_engine", "%s  Cook Engine" % _SECTION_ICONS["cook_engine"])
	_add_section_with_toc("player", "%s  Player" % _SECTION_ICONS["player"])
	_add_section_with_toc("building", "%s  Building" % _SECTION_ICONS["building"])
	_add_section_with_toc("extensions", "%s  Extensions" % _SECTION_ICONS["extensions"])
	_add_section_with_toc("troubleshooting", "%s  Troubleshooting" % _SECTION_ICONS["troubleshooting"])


func _add_section_item(key: String, display_text: String) -> TreeItem:
	var item := _tree.create_item(_tree_root)
	item.set_text(0, display_text)
	item.set_metadata(0, key)
	return item


## Creates a section tree item and populates it with child items for each
## H2 heading found in the section's markdown file, giving an inline TOC.
func _add_section_with_toc(key: String, display_text: String) -> TreeItem:
	var item := _tree.create_item(_tree_root)
	item.set_text(0, display_text)
	item.set_metadata(0, key)

	# Extract headings from the section's .md file and add as children
	var md_file: String = _SECTION_FILES.get(key, "")
	if md_file != "":
		var md_path := "%s/%s" % [HELP_DIR, md_file]
		var headings := _extract_headings(md_path)
		if headings.size() > 0:
			item.collapsed = true
			for h in headings:
				var child := _tree.create_item(item)
				child.set_text(0, "  %s" % h)
				child.set_metadata(0, "heading::%s::%s" % [key, h])

	return item


## Extracts H2 headings from a markdown file for sidebar table-of-contents.
## Returns a PackedStringArray of heading titles (without the "## " prefix).
static func _extract_headings(md_path: String) -> PackedStringArray:
	var headings := PackedStringArray()
	if not FileAccess.file_exists(md_path):
		return headings
	var text := FileAccess.get_file_as_string(md_path)
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("## ") and not stripped.begins_with("### "):
			headings.append(stripped.substr(3))
	return headings


## Builds the per-family → per-operator sub-tree under the Operators node.
func _build_operator_tree(parent: TreeItem) -> void:
	var registry := GNExtensionRegistry.instance()
	var by_family := registry.get_operator_registry_sectioned()

	# Sort families alphabetically
	var families: Array = by_family.keys()
	families.sort()

	for family_name in families:
		var family_item := _tree.create_item(parent)
		var family_sections: Dictionary = by_family[family_name]

		# Count total operators in this family
		var total := 0
		for sec_key in family_sections:
			total += family_sections[sec_key].size()

		family_item.set_text(0, "%s  (%d)" % [family_name, total])
		family_item.set_metadata(0, "family::%s" % family_name)
		family_item.collapsed = true

		# If there are sections, group them; otherwise flat list
		var section_keys: Array = family_sections.keys()
		section_keys.sort()

		for sec_key in section_keys:
			var ops: Array = family_sections[sec_key]
			ops.sort()

			var section_parent: TreeItem = family_item
			if sec_key != "" and section_keys.size() > 1:
				# Create a sub-section item
				section_parent = _tree.create_item(family_item)
				section_parent.set_text(0, "  %s" % sec_key)
				section_parent.set_metadata(0, "section::%s::%s" % [family_name, sec_key])
				section_parent.collapsed = true

			for op_name in ops:
				var op_item := _tree.create_item(section_parent)
				op_item.set_text(0, "  %s" % op_name)
				op_item.set_metadata(0, "op::%s" % op_name)


# ═══════════════════════════════════════════════════════════════════════════════
# Sidebar Event Handlers
# ═══════════════════════════════════════════════════════════════════════════════

func _on_tree_item_selected() -> void:
	var selected := _tree.get_selected()
	if selected == null:
		return
	var meta: String = selected.get_metadata(0)
	if meta.is_empty():
		return

	if meta.begins_with("op::"):
		_show_operator_help(meta.substr(4))
	elif meta.begins_with("family::"):
		_show_family_overview(meta.substr(8))
	elif meta.begins_with("section::"):
		# Expand the section, don't change content
		selected.collapsed = not selected.collapsed
	elif meta.begins_with("heading::"):
		_show_heading(meta)
	else:
		_show_section(meta)
		# Auto-expand TOC sub-items when selecting a section header
		if selected.get_child_count() > 0:
			selected.collapsed = false


func _on_search_changed(search_text: String) -> void:
	if search_text.strip_edges().is_empty():
		# Show all items
		_set_tree_visibility(_tree_root, true)
		return
	var query := search_text.strip_edges().to_lower()
	_filter_tree(_tree_root, query)


## Recursively filters the tree, showing only items matching the query.
## Returns true if this item or any child is visible.
func _filter_tree(item: TreeItem, query: String) -> bool:
	if item == null:
		return false

	var any_child_visible := false
	var child := item.get_first_child()
	while child != null:
		if _filter_tree(child, query):
			any_child_visible = true
		child = child.get_next()

	var text_matches := item.get_text(0).to_lower().contains(query)
	var meta: String = item.get_metadata(0) if item.get_metadata(0) is String else ""
	var meta_matches := meta.to_lower().contains(query)

	var visible := text_matches or meta_matches or any_child_visible
	item.visible = visible

	# Auto-expand parent items that have matching children
	if any_child_visible and item != _tree_root:
		item.collapsed = false

	return visible


## Sets visibility on all tree items recursively.
func _set_tree_visibility(item: TreeItem, vis: bool) -> void:
	if item == null:
		return
	item.visible = vis
	var child := item.get_first_child()
	while child != null:
		_set_tree_visibility(child, vis)
		child = child.get_next()


# ═══════════════════════════════════════════════════════════════════════════════
# Content Display
# ═══════════════════════════════════════════════════════════════════════════════

## Shows a section and scrolls to a specific heading within it.
## Meta format: "heading::<section_key>::<heading_text>"
func _show_heading(meta: String) -> void:
	var parts := meta.split("::", false, 2)
	if parts.size() < 3:
		return
	var section_key: String = parts[1]
	var heading_text: String = parts[2]
	_show_section(section_key)
	call_deferred("_scroll_to_heading", heading_text)


## Scrolls the content pane to the paragraph containing the given heading text.
func _scroll_to_heading(heading_text: String) -> void:
	var plain := _rtl.get_parsed_text()
	var idx := plain.find(heading_text)
	if idx < 0:
		return
	var para := _rtl.get_character_paragraph(idx)
	var offset := _rtl.get_paragraph_offset(para)
	_scroll.scroll_vertical = int(offset)


func _show_section(key: String) -> void:
	if _active_section == key and _rtl.text != "":
		return  # Already showing this section

	_active_section = key

	if _content_cache.has(key):
		_rtl.text = _content_cache[key]
		_scroll.scroll_vertical = 0
		return

	# Try to load the markdown file
	var md_file: String = _SECTION_FILES.get(key, "")
	if md_file != "":
		var full_path := "%s/%s" % [HELP_DIR, md_file]
		if FileAccess.file_exists(full_path):
			var md_text := FileAccess.get_file_as_string(full_path)
			var bbcode := GNMarkdownRenderer.render(md_text)
			_content_cache[key] = bbcode
			_rtl.text = bbcode
			_scroll.scroll_vertical = 0
			return

	# Fallback: generate placeholder content
	var bb := _generate_placeholder(key)
	_content_cache[key] = bb
	_rtl.text = bb
	_scroll.scroll_vertical = 0


func _show_operator_help(op_name: String) -> void:
	var cache_key := "op::%s" % op_name
	_active_section = cache_key

	if _content_cache.has(cache_key):
		_rtl.text = _content_cache[cache_key]
		_scroll.scroll_vertical = 0
		return

	var bb := _generate_operator_bbcode(op_name)
	_content_cache[cache_key] = bb
	_rtl.text = bb
	_scroll.scroll_vertical = 0


func _show_family_overview(family_name: String) -> void:
	var cache_key := "family::%s" % family_name
	_active_section = cache_key

	if _content_cache.has(cache_key):
		_rtl.text = _content_cache[cache_key]
		_scroll.scroll_vertical = 0
		return

	var bb := _generate_family_bbcode(family_name)
	_content_cache[cache_key] = bb
	_rtl.text = bb
	_scroll.scroll_vertical = 0


# ═══════════════════════════════════════════════════════════════════════════════
# Content Generators
# ═══════════════════════════════════════════════════════════════════════════════

## Generates BBCode for a single operator reference page.
func _generate_operator_bbcode(op_name: String) -> String:
	var registry := GNExtensionRegistry.instance()
	var desc := registry.get_description(op_name)
	var entry: GNExtensionRegistry.OperatorEntry = registry._operators.get(op_name, null)

	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]%s[/color][/b][/font_size]\n" % op_name

	if entry:
		bb += "[color=#888888]Family: %s" % entry.family
		if not entry.section.is_empty():
			bb += "  |  Section: %s" % entry.section
		bb += "  |  Source: %s[/color]\n\n" % entry.source
	else:
		bb += "\n"

	if not desc.is_empty():
		bb += desc + "\n\n"
	else:
		bb += "[color=#666666]No description available.[/color]\n\n"

	# Try to instantiate the operator to read its ports and parameters
	var node := registry.create_instance(op_name)
	if node != null:
		node._init_ports()
		node._init_parameters()

		# ── Inputs ──
		if node.input_ports.size() > 0:
			bb += "[font_size=17][b][color=#7eb8da]Inputs[/color][/b][/font_size]\n"
			bb += "[table=3]"
			bb += "[cell][b][color=#aaaaaa]Port[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Family[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Description[/color][/b][/cell]"
			for port in node.input_ports:
				bb += "[cell]%s[/cell]" % port.display_name()
				bb += "[cell]%s[/cell]" % GNFamily.get_family_name(port.family)
				bb += "[cell]%s[/cell]" % port.description
			bb += "[/table]\n\n"

		# ── Outputs ──
		if node.output_ports.size() > 0:
			bb += "[font_size=17][b][color=#7eb8da]Outputs[/color][/b][/font_size]\n"
			bb += "[table=3]"
			bb += "[cell][b][color=#aaaaaa]Port[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Family[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Description[/color][/b][/cell]"
			for port in node.output_ports:
				bb += "[cell]%s[/cell]" % port.display_name()
				bb += "[cell]%s[/cell]" % GNFamily.get_family_name(port.family)
				bb += "[cell]%s[/cell]" % port.description
			bb += "[/table]\n\n"

		# ── Parameters ──
		if node.parameters.size() > 0:
			bb += "[font_size=17][b][color=#7eb8da]Parameters[/color][/b][/font_size]\n"
			bb += "[table=4]"
			bb += "[cell][b][color=#aaaaaa]Name[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Type[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Default[/color][/b][/cell]"
			bb += "[cell][b][color=#aaaaaa]Description[/color][/b][/cell]"
			for p_name in node.parameters:
				var p: GNParameter = node.parameters[p_name]
				bb += "[cell]%s[/cell]" % p.param_name
				bb += "[cell]%s[/cell]" % _param_type_label(p.value_type)
				bb += "[cell]%s[/cell]" % str(p.default_value)
				bb += "[cell]%s[/cell]" % p.description
			bb += "[/table]\n\n"

		node.free()

	# ── Check for .md help file ──
	if entry:
		var family_lower := entry.family.to_lower()
		var md_path := "%s/%s/%s.md" % [HELP_DIR, family_lower, op_name.to_lower()]
		if FileAccess.file_exists(md_path):
			bb += "[color=#444444]────────────────────────────────────────[/color]\n"
			var md := FileAccess.get_file_as_string(md_path)
			bb += GNMarkdownRenderer.render(md)

	return bb


## Generates a family overview page listing all operators in that family.
func _generate_family_bbcode(family_name: String) -> String:
	var registry := GNExtensionRegistry.instance()
	var by_family := registry.get_operator_registry_sectioned()
	var sections: Dictionary = by_family.get(family_name, {})

	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]%s Family[/color][/b][/font_size]\n\n" % family_name

	var total := 0
	for sec_key in sections:
		total += sections[sec_key].size()
	bb += "[color=#888888]%d operators[/color]\n\n" % total

	# Sort sections
	var sec_keys: Array = sections.keys()
	sec_keys.sort()

	for sec_key in sec_keys:
		if not sec_key.is_empty():
			bb += "[font_size=17][b]%s[/b][/font_size]\n" % sec_key

		var ops: Array = sections[sec_key]
		ops.sort()

		for op_name in ops:
			var desc := registry.get_description(op_name)
			bb += "  •  [b]%s[/b]" % op_name
			if not desc.is_empty():
				bb += " — %s" % desc
			bb += "\n"

		bb += "\n"

	return bb


## Generates placeholder content for sections without a .md file yet.
func _generate_placeholder(key: String) -> String:
	match key:
		"getting_started":
			return _generate_getting_started()
		"cook_engine":
			return _generate_cook_engine_guide()
		"extensions":
			return _generate_extensions_guide()
		"operators":
			return _generate_operators_overview()
		_:
			return "[font_size=17][b]%s[/b][/font_size]\n\n[color=#666666]Content coming soon.[/color]" % key


func _generate_getting_started() -> String:
	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]📖 Getting Started with GONODES[/color][/b][/font_size]\n\n"
	bb += "GONODES is a node-based visual programming environment for Godot, "
	bb += "inspired by TouchDesigner. Build real-time graphics, audio processing, "
	bb += "and data-driven applications by connecting operators in a graph.\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Operator Families[/color][/b][/font_size]\n\n"
	bb += "  •  [b]TOP[/b] — Texture operators: shader-based image generation and compositing\n"
	bb += "  •  [b]IMG[/b] — Image operators: CPU-side image processing\n"
	bb += "  •  [b]CHOP[/b] — Channel operators: time-based data and animation\n"
	bb += "  •  [b]DAT[/b] — Data operators: tables, text, and structured data\n"
	bb += "  •  [b]SOP[/b] — Surface operators: 3D geometry generation and manipulation\n"
	bb += "  •  [b]MAT[/b] — Material operators: shader materials for 3D\n"
	bb += "  •  [b]COMP[/b] — Component operators: 3D scene objects and sub-networks\n"
	bb += "  •  [b]Output[/b] — Final output sinks for rendering and display\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Your First Patch[/color][/b][/font_size]\n\n"
	bb += "1. Press [b]Alt+A[/b] to open the Add Node palette\n"
	bb += "2. Type [b]Noise[/b] and select [b]NoiseTOP[/b]\n"
	bb += "3. Press [b]Alt+A[/b] again and add an [b]OutputTOP[/b]\n"
	bb += "4. Drag from [b]NoiseTOP[/b]'s output port to [b]OutputTOP[/b]'s input\n"
	bb += "5. The viewer shows animated Perlin noise!\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Key Concepts[/color][/b][/font_size]\n\n"
	bb += "  •  [b]Cooking[/b] — Every frame, the cook engine evaluates dirty nodes\n"
	bb += "  •  [b]Active Chain[/b] — Only nodes feeding an output sink are cooked\n"
	bb += "  •  [b]Expressions[/b] — Drive parameters with code (click the C/E button)\n"
	bb += "  •  [b]Sub-Networks[/b] — Double-click a BaseCOMP to dive inside\n"
	bb += "  •  [b]Presets[/b] — Script nodes include example presets in the code editor\n\n"

	bb += "[color=#888888]Tip: Press F1 anytime to open this help window. "
	bb += "Right-click any node and choose \"Help\" for node-specific docs.[/color]\n"

	return bb


func _generate_cook_engine_guide() -> String:
	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]⚙️ Cook Engine[/color][/b][/font_size]\n\n"
	bb += "The GONODES cook engine is responsible for evaluating the node graph each frame.\n\n"

	bb += "[font_size=17][b][color=#7eb8da]How Cooking Works[/color][/b][/font_size]\n\n"
	bb += "1. [b]Dirty Propagation[/b] — When a parameter changes or an input updates, "
	bb += "the node is marked 'dirty'. Dirtiness propagates downstream to all connected nodes.\n\n"
	bb += "2. [b]Active Chain Resolution[/b] — Not all nodes cook every frame. The engine "
	bb += "traces backward from output sinks (OutputTOP, RenderTOP, WindowOUT, etc.) to find "
	bb += "all nodes that feed them. Only these 'active' nodes are evaluated.\n\n"
	bb += "3. [b]Topological Sort[/b] — Active dirty nodes are sorted so upstream nodes "
	bb += "cook first. This guarantees inputs are ready before a node reads them.\n\n"
	bb += "4. [b]Cook Execution[/b] — Each node's [code]cook()[/code] is called with "
	bb += "cook_context containing time, frame, delta. The node reads inputs, processes, "
	bb += "and writes outputs.\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Time & Frames[/color][/b][/font_size]\n\n"
	bb += "  •  [b]time[/b] — Seconds since the cook engine started\n"
	bb += "  •  [b]frame[/b] — Monotonically increasing frame counter\n"
	bb += "  •  [b]dt[/b] — Delta time for this frame\n"
	bb += "  •  [b]NRT mode[/b] — Fixed timestep for deterministic output (toggle on toolbar)\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Performance[/color][/b][/font_size]\n\n"
	bb += "  •  Enable [b]Perf[/b] overlay to see per-node cook times\n"
	bb += "  •  Enable [b]VRAM[/b] toggle to monitor GPU memory usage\n"
	bb += "  •  Bypass expensive nodes with [b]B[/b] key to isolate bottlenecks\n"
	bb += "  •  Lock nodes with [b]L[/b] to prevent parameter changes during profiling\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Bypass & Lock[/color][/b][/font_size]\n\n"
	bb += "  •  [b]Bypass (B)[/b] — Node passes its first input through unchanged. "
	bb += "Useful for A/B testing effects.\n"
	bb += "  •  [b]Lock (L)[/b] — Node becomes read-only. Inspector dims all parameters.\n"

	return bb


func _generate_extensions_guide() -> String:
	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]🔌 Extensions[/color][/b][/font_size]\n\n"
	bb += "GONODES supports third-party operator extensions via the GNExtensionRegistry "
	bb += "architecture.\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Extension Structure[/color][/b][/font_size]\n\n"
	bb += "Extensions live under [code]res://addons/gn_ext_<name>/[/code] and contain:\n\n"
	bb += "  •  [b]gn_extension.cfg[/b] — Manifest file declaring operators\n"
	bb += "  •  [b]operators/[/b] — GDScript files extending GNNode\n"
	bb += "  •  [b]README.md[/b] — Optional documentation\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Manifest Format[/color][/b][/font_size]\n\n"
	bb += "[code][bgcolor=#1a1a2e]"
	bb += "[lb]extension[rb]\n"
	bb += "name = \"My Extension\"\n"
	bb += "version = \"1.0.0\"\n"
	bb += "author = \"Your Name\"\n"
	bb += "description = \"What the extension does.\"\n"
	bb += "section = \"MySection\"\n\n"
	bb += "[lb]operator.MyCustomTOP[rb]\n"
	bb += "family = \"TOP\"\n"
	bb += "script = \"res://addons/gn_ext_myext/operators/my_custom_top.gd\"\n"
	bb += "description = \"One-line description.\"\n"
	bb += "[/bgcolor][/code]\n\n"

	bb += "[font_size=17][b][color=#7eb8da]Writing an Operator[/color][/b][/font_size]\n\n"
	bb += "1. Create a GDScript extending the appropriate family base class\n"
	bb += "2. Implement [code]_init_ports()[/code], [code]_init_params()[/code], and [code]cook()[/code]\n"
	bb += "3. Register it in your [code]gn_extension.cfg[/code] manifest\n"
	bb += "4. Place the extension folder under [code]res://addons/[/code]\n"
	bb += "5. GONODES discovers it automatically on startup\n\n"

	# List loaded extensions
	var registry := GNExtensionRegistry.instance()
	var loaded := registry.get_loaded_extensions()
	if loaded.size() > 0:
		bb += "[font_size=17][b][color=#7eb8da]Loaded Extensions[/color][/b][/font_size]\n\n"
		for ext_name in loaded:
			bb += "  •  %s\n" % ext_name
	else:
		bb += "[color=#888888]No third-party extensions currently loaded.[/color]\n"

	return bb


func _generate_operators_overview() -> String:
	var registry := GNExtensionRegistry.instance()
	var by_family := registry.get_operator_registry()

	var bb := ""
	bb += "[font_size=22][b][color=#7eb8da]📋 Operators Reference[/color][/b][/font_size]\n\n"
	bb += "[color=#888888]%d operators across %d families[/color]\n\n" % [
		registry.get_operator_count(), by_family.size()]

	bb += "Click a family or operator in the sidebar to see detailed documentation.\n\n"

	var families: Array = by_family.keys()
	families.sort()

	for family_name in families:
		var ops: Array = by_family[family_name]
		bb += "  •  [b]%s[/b] — %d operators\n" % [family_name, ops.size()]

	return bb


## Returns a human-readable label for a GNParameter.ValueType enum value.
func _param_type_label(vtype: GNParameter.ValueType) -> String:
	match vtype:
		GNParameter.ValueType.FLOAT: return "Float"
		GNParameter.ValueType.INT: return "Int"
		GNParameter.ValueType.BOOL: return "Bool"
		GNParameter.ValueType.STRING: return "String"
		GNParameter.ValueType.COLOR: return "Color"
		GNParameter.ValueType.VECTOR2: return "Vector2"
		GNParameter.ValueType.VECTOR2I: return "Vector2i"
		GNParameter.ValueType.VECTOR3: return "Vector3"
		GNParameter.ValueType.VECTOR4: return "Vector4"
		GNParameter.ValueType.ENUM: return "Enum"
		GNParameter.ValueType.FILE: return "File"
		GNParameter.ValueType.RAMP: return "Ramp"
		_: return "—"
