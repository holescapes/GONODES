class_name GeometryBufferTOP
extends RenderTOP
## Renders a 3D COMP scene with a debug draw mode for G-buffer inspection.
##
## Extends RenderTOP identically (same COMP inputs, all scene management).
## A "Buffer" parameter selects which render buffer to visualise:
##
##   Color         — normal rendered output (same as RenderTOP).
##   Unshaded      — diffuse albedo without any lighting or shadows.
##   Normal Buffer — world-space normals encoded as RGB (0.5 bias).
##   Wireframe     — polygon edges overlay (Forward+ renderer, requires debug draw).
##
## Normal Buffer and Wireframe require the Forward+ renderer.
## Unshaded is available in all renderers.
##
## Useful for: split-screen debug views, occlusion masks, normal-map baking
## references, and driving downstream effects with scene geometry information.


func _init() -> void:
	super._init()
	node_type        = "geometry_buffer"


func _init_parameters() -> void:
	super._init_parameters()  # inherit all RenderTOP params
	# Buffer selector appended at the top of the param list (logically first,
	# but appended so RenderTOP params stay in their registered order).
	add_parameter(GNParameter.create_enum("buffer_mode",
		PackedStringArray(["Color", "Unshaded", "Normal Buffer", "Wireframe"]),
		0, "Buffer",
		"Colour = normal render · Unshaded = no lighting · Normal Buffer = world normals · Wireframe = polygon edges"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Render the scene (creates/updates _viewport).
	var result: GNData = super._cook(inputs)

	# Apply debug draw mode every cook so param changes take effect next frame.
	if _viewport != null:
		var mode: int = get_param_value("buffer_mode")
		match mode:
			0: _viewport.debug_draw = Viewport.DEBUG_DRAW_DISABLED
			1: _viewport.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
			2: _viewport.debug_draw = Viewport.DEBUG_DRAW_NORMAL_BUFFER
			3: _viewport.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME

	return result
