class_name GNPreviewHost
extends PanelContainer
## Lightweight on-node preview host — mirrors the viewer panel API.
##
## Nodes push content via set_texture(), set_text(), or set_control().
## Text/control modes size dynamically between MIN_HEIGHT and
## max_preview_height—only growing when content actually needs the space.
## Texture previews are always fixed at TEXTURE_HEIGHT (80 px).
##
## The host is created by GNNodeView._setup_preview() and holds a single
## display at a time (texture OR text OR custom control).


## Height constants — texture is fixed, text/control flex between the two.
const TEXTURE_HEIGHT := 80.0
const MIN_HEIGHT := 80.0
const MIN_WIDTH := 120

## Upper bound for text/control modes (set from preferences).
var max_preview_height: float = 80.0

# ─── Internal ────────────────────────────────────────────────────────────────
var _tex_rect: TextureRect = null
var _text_label: Label = null
var _scroll: ScrollContainer = null
var _custom_control: Control = null
var _current_mode: int = -1  # 0=texture, 1=text, 2=control

enum Mode { TEXTURE, TEXT, CONTROL }


func _init() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(MIN_WIDTH, 0)
	size_flags_horizontal = SIZE_EXPAND_FILL
	clip_contents = true

	# Transparent background — the GraphNode panel provides the backdrop
	var sb := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	_build_ui()
	# Listen for live preference changes so the user sees immediate effect.
	GNSettings.add_listener(_on_setting_changed)


func _build_ui() -> void:
	# Texture display (fixed height, no scroll)
	_tex_rect = TextureRect.new()
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.mouse_filter = MOUSE_FILTER_IGNORE
	_tex_rect.visible = false
	add_child(_tex_rect)

	# Scroll container for text and control modes
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.mouse_filter = MOUSE_FILTER_PASS
	_scroll.visible = false
	add_child(_scroll)

	# Text label inside scroll
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 10)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_text_label.mouse_filter = MOUSE_FILTER_IGNORE
	_scroll.add_child(_text_label)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API — mirrors GNViewerPanel's display modes
# ═══════════════════════════════════════════════════════════════════════════════


## Displays a Texture2D thumbnail (aspect-fitted, fixed height, no scroll).
func set_texture(tex: Texture2D) -> void:
	if tex == null:
		set_text("")
		return
	_switch_mode(Mode.TEXTURE)
	_tex_rect.texture = tex
	# Always enforce fixed texture height — prevent any layout drift.
	_force_height(TEXTURE_HEIGHT)


## Displays short text with automatic scroll if it exceeds max height.
func set_text(text: String) -> void:
	_switch_mode(Mode.TEXT)
	_text_label.text = text
	# Recalc after layout so the label's minimum size accounts for autowrap.
	call_deferred("_recalc_dynamic_height")


## Embeds a custom Control with automatic scroll if it exceeds max height.
func set_control(ctrl: Control) -> void:
	if ctrl == null:
		set_text("")
		return
	_switch_mode(Mode.CONTROL)
	if _custom_control != ctrl:
		if _custom_control != null and _custom_control.get_parent() == _scroll:
			_scroll.remove_child(_custom_control)
		_custom_control = ctrl
		if ctrl.get_parent() != _scroll:
			if ctrl.get_parent() != null:
				ctrl.get_parent().remove_child(ctrl)
			_scroll.add_child(ctrl)
		ctrl.size_flags_horizontal = SIZE_EXPAND_FILL
	call_deferred("_recalc_dynamic_height")


# ═══════════════════════════════════════════════════════════════════════════════
# Internal
# ═══════════════════════════════════════════════════════════════════════════════


func _switch_mode(mode: int) -> void:
	if _current_mode == mode:
		return
	_current_mode = mode
	_tex_rect.visible = (mode == Mode.TEXTURE)
	_scroll.visible = (mode == Mode.TEXT or mode == Mode.CONTROL)
	_text_label.visible = (mode == Mode.TEXT)
	if mode == Mode.TEXT and _custom_control != null and _custom_control.get_parent() == _scroll:
		_custom_control.visible = false
	elif mode == Mode.CONTROL:
		_text_label.visible = false
	_apply_size_for_mode()


func _apply_size_for_mode() -> void:
	size_flags_vertical = SIZE_SHRINK_BEGIN
	match _current_mode:
		Mode.TEXTURE:
			_tex_rect.custom_minimum_size = Vector2(MIN_WIDTH, TEXTURE_HEIGHT)
			_scroll.custom_minimum_size = Vector2(MIN_WIDTH, 0)
			_force_height(TEXTURE_HEIGHT)
		Mode.TEXT, Mode.CONTROL:
			_scroll.custom_minimum_size = Vector2(MIN_WIDTH, 0)
			# Start at MIN_HEIGHT — _recalc_dynamic_height will grow if needed.
			_force_height(MIN_HEIGHT)


## Compute the ideal height for text/control modes and apply it.
func _recalc_dynamic_height() -> void:
	if _current_mode == Mode.TEXTURE:
		return

	var content_h := 0.0
	if _current_mode == Mode.TEXT and _text_label != null:
		content_h = _text_label.get_combined_minimum_size().y
	elif _current_mode == Mode.CONTROL and _custom_control != null:
		content_h = _custom_control.get_combined_minimum_size().y

	var target_h := clampf(content_h, MIN_HEIGHT, max_preview_height)
	_force_height(target_h)


## Set custom_minimum_size, size, and ask parent GraphNode to re-layout.
func _force_height(h: float) -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, h)
	size = Vector2(size.x, h)
	if get_parent() is GraphNode:
		get_parent().reset_size()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "preview_max_height":
		max_preview_height = maxf(float(value), MIN_HEIGHT)
		# Texture mode is not affected — it stays at TEXTURE_HEIGHT.
		if _current_mode != Mode.TEXTURE:
			_recalc_dynamic_height()


func _exit_tree() -> void:
	GNSettings.remove_listener(_on_setting_changed)

