class_name ScreenGrabIMG
extends GNImgBase
## Captures the main viewport (or editor viewport) as a CPU-side Image.
##
## Viewport-only capture — no OS-level desktop grab (that requires GDExtension).
## Each cook grabs the current rendered frame via Viewport.get_texture().get_image()
## and outputs it as GNImageData.  Chain → ImgToTOP if you need a GPU texture.

func _init() -> void:
	node_type = "screen_grab"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.IMG, "Grabbed viewport image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("source",
		PackedStringArray(["Main Viewport", "Editor Viewport"]),
		0, "Source", "Which viewport to capture"))
	add_parameter(GNParameter.create_int("res_x", 512, 1, 4096, "Width",
		"Output resolution width (0 = native viewport size)"))
	add_parameter(GNParameter.create_int("res_y", 512, 1, 4096, "Height",
		"Output resolution height (0 = native viewport size)"))
	add_parameter(GNParameter.create_bool("active", true, "Active",
		"Enable/disable capture"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var active: bool = get_param_value("active")
	if not active:
		return null

	var res_x: int = get_param_value("res_x")
	var res_y: int = get_param_value("res_y")
	var source_idx: int = get_param_value("source")

	var target_vp: Viewport = _resolve_viewport(source_idx)
	if target_vp == null:
		return null

	var img: Image = target_vp.get_texture().get_image()
	if img == null:
		return null

	# Resize if requested resolution differs from native
	if res_x > 0 and res_y > 0:
		if img.get_width() != res_x or img.get_height() != res_y:
			img.resize(res_x, res_y, Image.INTERPOLATE_BILINEAR)

	var out: GNImageData = _prepare_image()
	out.set_image(img)
	return out


func _resolve_viewport(source_idx: int) -> Viewport:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	match source_idx:
		0:  # Main Viewport
			return tree.root
		1:  # Editor Viewport — find first SubViewport under editor root
			var root: Window = tree.root
			if root == null:
				return null
			var svp: SubViewport = _find_child_viewport(root)
			return svp if svp != null else root
		_:
			return tree.root


func _find_child_viewport(node: Node) -> SubViewport:
	for child in node.get_children():
		if child is SubViewport:
			return child
		var found: SubViewport = _find_child_viewport(child)
		if found != null:
			return found
	return null
