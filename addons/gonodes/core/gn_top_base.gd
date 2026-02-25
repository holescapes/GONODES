class_name GNTopBase
extends GNNode
## Base class for all TOP (Texture Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.TOP set automatically
##   • Default output port "out" of type TOP
##   • Input validation via _get_input_top()
##   • Inline texture preview (create_preview_control / update_preview_control)
##
## Viewport setup and caching remain in each operator for now, since TOPs vary
## significantly in their rendering pipelines (shader generators, filter chains,
## Text/Label-based, 3D render, etc.).  A future pass can consolidate common
## viewport patterns via _init_viewport_content() hooks.


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.TOP


## Default output port.  Override _init_ports() in subclass to add inputs
## or extra outputs, but call super._init_ports() first (or add "out" yourself).
func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Texture output")


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNTextureData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNTextureData.
func _get_input_top(inputs: Array[GNData], port: int = 0) -> GNTextureData:
	if port < inputs.size() and inputs[port] is GNTextureData:
		return inputs[port] as GNTextureData
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a TextureRect thumbnail that shows the TOP's output texture.
func create_preview_control() -> Control:
	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex_rect


## Updates the texture preview from cached_output.
func update_preview_control(control: Control) -> void:
	if control is TextureRect:
		var tex_rect: TextureRect = control as TextureRect
		if cached_output is GNTextureData:
			var tex_data: GNTextureData = cached_output as GNTextureData
			tex_rect.texture = tex_data.texture
		else:
			tex_rect.texture = null
