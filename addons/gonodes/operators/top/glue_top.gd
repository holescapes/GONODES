class_name GlueTOP
extends GNTopBase
## Packs multiple input textures into a single atlas/grid layout.
##
## Arranges up to 4 input textures in a configurable grid (2x2, 1x4, 4x1, etc.)
## drawn into a single output viewport.

func _init() -> void:
	node_type = "glue"
	node_description = "Pack multiple textures into a grid atlas."


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.TOP, false, "Texture 1 (top-left)", "Input 1")
	add_input("in2", GNFamily.Type.TOP, false, "Texture 2", "Input 2")
	add_input("in3", GNFamily.Type.TOP, false, "Texture 3", "Input 3")
	add_input("in4", GNFamily.Type.TOP, false, "Texture 4", "Input 4")
	add_output("out", GNFamily.Type.TOP, "Atlas texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1024, 1024),
		"Resolution", "Output atlas resolution"))
	add_parameter(GNParameter.create_enum("layout",
		PackedStringArray(["Auto", "1x2", "2x1", "2x2", "1x4", "4x1"]), 0,
		"Layout", "Grid arrangement"))
	add_parameter(GNParameter.create_int("padding", 0, 0, 32, "Padding", "Pixels between tiles"))
	add_parameter(GNParameter.create_color("background", Color(0, 0, 0, 0),
		"Background", "Atlas background color"))

# Internal: TextureRects for each slot
var _slots: Array[TextureRect] = []


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var layout_idx: int = get_param_value("layout")
	var pad: int = get_param_value("padding")
	var bg_color: Color = get_param_value("background")

	# Collect valid input textures
	var textures: Array[GNTextureData] = []
	for i in range(4):
		var tex: GNTextureData = _get_input_top(inputs, i)
		if tex != null:
			textures.append(tex)

	if textures.is_empty():
		return null

	# Ensure viewport
	_ensure_viewport(res, true)
	if _viewport.size != res:
		_viewport.size = res

	# Determine grid dimensions
	var n: int = textures.size()
	var cols: int
	var rows: int
	match layout_idx:
		1: cols = 1; rows = 2  # 1x2
		2: cols = 2; rows = 1  # 2x1
		3: cols = 2; rows = 2  # 2x2
		4: cols = 1; rows = 4  # 1x4
		5: cols = 4; rows = 1  # 4x1
		_:  # Auto
			if n <= 1:
				cols = 1; rows = 1
			elif n <= 2:
				cols = 2; rows = 1
			else:
				cols = 2; rows = 2

	# Clear old slots
	_clear_slots()

	# Background ColorRect
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = bg_color
	_viewport.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Tile dimensions
	var tile_w: float = (float(res.x) - pad * (cols + 1)) / float(cols)
	var tile_h: float = (float(res.y) - pad * (rows + 1)) / float(rows)

	for i in range(mini(n, cols * rows)):
		var row: int = i / cols
		var col: int = i % cols
		var tr := TextureRect.new()
		tr.name = "Tile_%d" % i
		tr.texture = textures[i].texture
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.position = Vector2(
			pad + col * (tile_w + pad),
			pad + row * (tile_h + pad))
		tr.size = Vector2(tile_w, tile_h)
		_viewport.add_child(tr)
		_slots.append(tr)

	_cached_tex_data.resolution = res

	return _cached_tex_data


func _clear_slots() -> void:
	for child in _viewport.get_children():
		child.queue_free()
	_slots.clear()
