class_name GNDebugOverlay
extends Control
## Debug overlay drawn on top of the GraphEdit canvas.
## Five toggleable layers:
##   1. Cook order badges — small "#N" on each node's top-left
##   2. Active chain dimming — inactive nodes drawn at 40% opacity
##   3. Dirty propagation — orange border flash on nodes dirtied this frame
##   4. Sink labels — colored halo rings on sinks, matching dots on upstream
##   5. Data flow annotations — data dimensions on wires (resolution, channels, etc.)
##
## Each layer is independently togglable. The overlay reads from
## GNCookEngine (last_topo_order, _active_set) and GNNetwork.

## Reference to graph editor for coordinate conversion and node views.
## Untyped to avoid circular class_name dependency (GNGraphEditor ↔ GNDebugOverlay).
var graph_editor = null

## Reference to cook engine for active set and topo order.
var cook_engine: GNCookEngine = null

## Reference to network for connections and expression scanning.
var network: GNNetwork = null

## Layer visibility toggles.
var show_cook_order: bool = true
var show_active_dimming: bool = true
var show_dirty_propagation: bool = true
var show_sink_labels: bool = true
var show_data_flow: bool = true

## Master toggle — when false, nothing is drawn and node modulation is reset.
var debug_enabled: bool = false

## Dirty flash state: node_id → remaining alpha (fades from 1.0 → 0.0).
var _dirty_flash: Dictionary = {}

## Fade speed for dirty flash (alpha per second).
const _DIRTY_FADE_SPEED := 3.3  # ~0.3 seconds to fully fade

## Sink colors for visual differentiation.
const _SINK_COLORS: Array[Color] = [
	Color(0.2, 0.85, 0.95, 0.8),   # Cyan
	Color(0.95, 0.5, 0.2, 0.8),    # Orange
	Color(0.4, 0.95, 0.4, 0.8),    # Green
	Color(0.95, 0.3, 0.95, 0.8),   # Magenta
	Color(0.95, 0.95, 0.3, 0.8),   # Yellow
]


func _init() -> void:
	name = "DebugOverlay"
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Call after each cook frame to refresh debug visuals.
func update_overlay() -> void:
	if not debug_enabled:
		return
	_apply_active_dimming()
	_update_dirty_flash()
	queue_redraw()


## Toggle the master debug mode on or off.
func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	if not enabled:
		_reset_node_modulation()
		_dirty_flash.clear()
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# Draw
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if not debug_enabled or graph_editor == null or cook_engine == null:
		return

	if show_cook_order:
		_draw_cook_order_badges()

	if show_dirty_propagation:
		_draw_dirty_flash()

	if show_sink_labels:
		_draw_sink_labels()

	if show_data_flow:
		_draw_data_flow()


# ── Layer 1: Cook Order Badges ────────────────────────────────────────────────

func _draw_cook_order_badges() -> void:
	var topo: Array[GNNode] = cook_engine.last_topo_order
	var font := ThemeDB.fallback_font
	var font_size := 10

	for i in range(topo.size()):
		var node: GNNode = topo[i]
		var view: GNNodeView = graph_editor._node_views.get(node.id, null)
		if view == null or not view.visible:
			continue

		var badge_text := "#%d" % (i + 1)

		# Position: top-left corner of node, in overlay space
		var node_pos := view.position_offset
		var screen_pos := _graph_to_overlay(node_pos) + Vector2(-4, -2)

		# Background pill
		var text_size := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pill_rect := Rect2(screen_pos - Vector2(3, text_size.y + 1),
				Vector2(text_size.x + 6, text_size.y + 4))
		draw_rect(pill_rect, Color(0.0, 0.0, 0.0, 0.7), true, -1.0)
		draw_rect(pill_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)

		# Text
		draw_string(font, screen_pos, badge_text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, Color(0.9, 0.9, 0.9))


# ── Layer 2: Active Chain Dimming ─────────────────────────────────────────────

func _apply_active_dimming() -> void:
	if graph_editor == null or cook_engine == null:
		return

	var active_set: Dictionary = cook_engine._active_set

	for node_id in graph_editor._node_views:
		var view: GNNodeView = graph_editor._node_views[node_id]
		if not is_instance_valid(view):
			continue

		if debug_enabled and show_active_dimming:
			if active_set.has(node_id):
				view.modulate = Color.WHITE
			else:
				view.modulate = Color(1, 1, 1, 0.4)
		else:
			view.modulate = Color.WHITE


func _reset_node_modulation() -> void:
	if graph_editor == null:
		return
	for node_id in graph_editor._node_views:
		var view: GNNodeView = graph_editor._node_views[node_id]
		if is_instance_valid(view):
			view.modulate = Color.WHITE


# ── Layer 3: Dirty Propagation Flash ──────────────────────────────────────────

## Called each frame from update_overlay(). Captures newly dirty nodes and
## fades existing flashes toward zero.
func _update_dirty_flash() -> void:
	if not show_dirty_propagation or cook_engine == null:
		return

	var delta: float = get_process_delta_time()

	# Capture dirty nodes this frame from cook engine snapshot
	for node_id in cook_engine.last_dirty_ids:
		_dirty_flash[node_id] = 1.0

	# Fade all flashes
	var to_remove: Array[String] = []
	for node_id in _dirty_flash:
		_dirty_flash[node_id] -= delta * _DIRTY_FADE_SPEED
		if float(_dirty_flash[node_id]) <= 0.0:
			to_remove.append(node_id)
	for node_id in to_remove:
		_dirty_flash.erase(node_id)


## Draws orange border rectangles on flashing nodes.
func _draw_dirty_flash() -> void:
	for node_id in _dirty_flash:
		var alpha: float = clampf(float(_dirty_flash[node_id]), 0.0, 1.0)
		if alpha < 0.01:
			continue
		var view: GNNodeView = graph_editor._node_views.get(node_id, null)
		if view == null or not is_instance_valid(view) or not view.visible:
			continue

		var top_left := _graph_to_overlay(view.position_offset)
		var node_size: Vector2 = view.size * float(graph_editor.zoom)
		var rect := Rect2(top_left, node_size)

		# Outer glow rect (2px border, fading orange)
		var border_color := Color(1.0, 0.6, 0.1, alpha * 0.9)
		draw_rect(rect.grow(2.0), border_color, false, 2.5)


# ── Layer 4: Sink Labels ─────────────────────────────────────────────────────

func _draw_sink_labels() -> void:
	if cook_engine == null or network == null:
		return

	# Collect sinks
	var sinks: Array[String] = []
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		if node.is_sink:
			sinks.append(node_id)

	# Build upstream sets per sink
	var upstream_map: Dictionary = {}
	for conn in network.connections:
		var from_id: String = conn.from_node
		var to_id: String = conn.to_node
		if not to_id.is_empty() and not from_id.is_empty():
			if not upstream_map.has(to_id):
				upstream_map[to_id] = []
			if from_id not in upstream_map[to_id]:
				upstream_map[to_id].append(from_id)

	for sink_idx in range(sinks.size()):
		var sink_id: String = sinks[sink_idx]
		var color: Color = _SINK_COLORS[sink_idx % _SINK_COLORS.size()]

		# Halo on sink node
		var sink_view: GNNodeView = graph_editor._node_views.get(sink_id, null)
		if sink_view != null:
			var center := _graph_to_overlay(
					sink_view.position_offset + sink_view.size / 2.0)
			var radius: float = maxf(sink_view.size.x, sink_view.size.y) * float(graph_editor.zoom) * 0.5 + 8.0
			draw_arc(center, radius, 0, TAU, 32, color, 2.5, true)

			# Label
			var font := ThemeDB.fallback_font
			var label_pos := center + Vector2(radius + 4, 4)
			draw_string(font, label_pos, sink_id, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 10, color)

		# Colored dots on upstream nodes
		var visited: Dictionary = {}
		var upstream_nodes := _collect_upstream(sink_id, upstream_map, visited)
		for up_id in upstream_nodes:
			var up_view: GNNodeView = graph_editor._node_views.get(up_id, null)
			if up_view == null:
				continue
			var dot_pos := _graph_to_overlay(
					up_view.position_offset + Vector2(up_view.size.x - 6, 6))
			draw_circle(dot_pos, 4.0, color)


func _collect_upstream(node_id: String, upstream_map: Dictionary,
		visited: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if visited.has(node_id):
		return result
	visited[node_id] = true

	var ups: Array = upstream_map.get(node_id, [])
	for up_id in ups:
		result.append(up_id)
		result.append_array(_collect_upstream(up_id, upstream_map, visited))
	return result


# ── Layer 5: Data Flow Annotations ────────────────────────────────────────────

## Draws data dimension labels at the midpoint of each wire.
func _draw_data_flow() -> void:
	if network == null:
		return

	var font := ThemeDB.fallback_font
	var font_size := 9

	for conn in network.connections:
		var from_id: String = conn.from_node
		var to_id: String = conn.to_node
		var from_port: int = conn.from_port

		var from_node: GNNode = network.nodes.get(from_id, null)
		if from_node == null:
			continue

		# Get output data from the source node's cache
		var data: GNData = from_node.get_output_data(from_port)
		if data == null:
			continue

		# Build annotation text based on data type
		var label_text := _format_data_label(data, from_node)
		if label_text.is_empty():
			continue

		# Get wire midpoint
		var from_view: GNNodeView = graph_editor._node_views.get(from_id, null)
		var to_view: GNNodeView = graph_editor._node_views.get(to_id, null)
		if from_view == null or to_view == null:
			continue

		# Approximate output port position (right side of from_node)
		var from_pos := from_view.position_offset + Vector2(
				from_view.size.x, _port_y_offset(from_view, from_port, true))
		# Approximate input port position (left side of to_node)
		var to_pos := to_view.position_offset + Vector2(
				0.0, _port_y_offset(to_view, conn.to_port, false))
		var mid := (from_pos + to_pos) * 0.5
		var screen_mid := _graph_to_overlay(mid)

		# Family color for the label
		var label_color: Color = GNFamily.get_color(from_node.family).lightened(0.3)
		label_color.a = 0.85

		# Background pill
		var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pill_rect := Rect2(
				screen_mid - Vector2(text_size.x * 0.5 + 3, text_size.y + 1),
				Vector2(text_size.x + 6, text_size.y + 4))
		draw_rect(pill_rect, Color(0.05, 0.05, 0.08, 0.85), true, -1.0)
		draw_rect(pill_rect, label_color * Color(1, 1, 1, 0.4), false, 1.0)

		# Text
		var text_pos := screen_mid + Vector2(-text_size.x * 0.5, 0)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, label_color)


## Returns a compact data dimension string for the given output data.
func _format_data_label(data: GNData, node: GNNode) -> String:
	if data is GNTextureData:
		var td: GNTextureData = data as GNTextureData
		return "%d×%d" % [td.resolution.x, td.resolution.y]
	elif data is GNImageData:
		var id: GNImageData = data as GNImageData
		return "%d×%d" % [id.resolution.x, id.resolution.y]
	elif data is GNChannelData:
		var cd: GNChannelData = data as GNChannelData
		var ch_count: int = cd.channels.size()
		var length: int = cd.length
		if length <= 1:
			return "%dch" % ch_count
		return "%dch×%d" % [ch_count, length]
	elif data is GNGeoData:
		var gd_data: GNGeoData = data as GNGeoData
		return "%dv" % gd_data.vertex_count
	elif data is GNTableData:
		var td: GNTableData = data as GNTableData
		return "%d×%d" % [td.num_rows(), td.num_cols()]
	return ""


## Estimates the Y offset of a port on a node view. Approximate — based on
## port index and a fixed per-slot height.
func _port_y_offset(view: GNNodeView, port_idx: int, is_output: bool) -> float:
	# GraphNode title bar is ~26px, each slot is ~26px
	var title_height := 26.0
	var slot_height := 26.0
	return title_height + slot_height * (port_idx + 0.5)


# ═══════════════════════════════════════════════════════════════════════════════
# Coordinate conversion
# ═══════════════════════════════════════════════════════════════════════════════

func _graph_to_overlay(graph_pos: Vector2) -> Vector2:
	return (graph_pos - graph_editor.scroll_offset / graph_editor.zoom) * graph_editor.zoom
