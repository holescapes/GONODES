class_name StereogramIMG
extends GNImgBase
## Generates a random-dot autostereogram (Magic Eye) from a depth map.
## Each pixel depends on pixels to its left at depth-dependent offsets,
## making this inherently sequential per row — requires CPU.


func _init() -> void:
	node_type = "stereogram"


func _init_ports() -> void:
	add_input("depth", GNFamily.Type.IMG, false, "Depth map (brighter = closer)")
	add_output("out", GNFamily.Type.IMG, "Stereogram image")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 256),
		"Resolution", "Output image size"))
	add_parameter(GNParameter.create_int("strip_width", 80, 20, 200,
		"Strip Width", "Repeating pattern strip width in pixels"))
	add_parameter(GNParameter.create_float("depth_scale", 0.3, 0.0, 1.0, 0.01,
		"Depth Scale", "Maximum depth displacement as fraction of strip width"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999,
		"Seed", "Random seed for the dot pattern"))
	add_parameter(GNParameter.create_bool("color", false,
		"Color", "Use colored random dots instead of grayscale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_image()
	var depth_in: GNImageData = _get_input_img(inputs, 0)

	var res: Vector2i = get_param_value("resolution")
	var strip_w: int = get_param_value("strip_width")
	var depth_scale: float = get_param_value("depth_scale")
	var seed_val: int = get_param_value("seed")
	var use_color: bool = get_param_value("color")

	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Get depth image (resize to match output)
	var depth_img: Image = null
	if depth_in != null and depth_in.image != null and not depth_in.image.is_empty():
		depth_img = depth_in.image.duplicate()
		if Vector2i(depth_img.get_width(), depth_img.get_height()) != res:
			depth_img.resize(res.x, res.y, Image.INTERPOLATE_BILINEAR)

	# Generate stereogram row by row
	for y in range(res.y):
		# Row pixel buffer: stores final color per pixel
		var row: Array[Color] = []
		row.resize(res.x)

		# Link array: each pixel links to the pixel it should match
		var links: PackedInt32Array = PackedInt32Array()
		links.resize(res.x)
		for x in range(res.x):
			links[x] = x  # self-link initially

		# Compute links from depth
		for x in range(res.x):
			var depth_val: float = 0.0
			if depth_img != null:
				var dc: Color = depth_img.get_pixel(x, y)
				depth_val = (dc.r + dc.g + dc.b) / 3.0

			var shift: int = strip_w - int(depth_val * depth_scale * float(strip_w))
			shift = clampi(shift, 1, strip_w)

			var left: int = x - shift
			if left >= 0:
				# Union-find: link these two pixels to share the same color
				var root_x: int = x
				while links[root_x] != root_x:
					root_x = links[root_x]
				var root_left: int = left
				while links[root_left] != root_left:
					root_left = links[root_left]
				if root_x != root_left:
					links[maxi(root_x, root_left)] = mini(root_x, root_left)

		# Assign colors left-to-right: inherit from linked pixel or generate new
		rng.seed = seed_val + y * 7919  # deterministic per row
		for x in range(res.x):
			# Find root
			var root: int = x
			while links[root] != root:
				root = links[root]
			# Path compression
			var cur: int = x
			while cur != root:
				var next_val: int = links[cur]
				links[cur] = root
				cur = next_val

			if root == x:
				# New random color
				if use_color:
					row[x] = Color(rng.randf(), rng.randf(), rng.randf(), 1.0)
				else:
					var v: float = rng.randf()
					row[x] = Color(v, v, v, 1.0)
			else:
				row[x] = row[root]

		# Write row to image
		for x in range(res.x):
			img.set_pixel(x, y, row[x])

	out.set_image(img)
	return out
