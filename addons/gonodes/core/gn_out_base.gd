class_name GNOutBase
extends GNNode
## Base class for all OUT (Output/Sink) family operators.
##
## OUT operators are terminal nodes — they consume data but produce no output.
## Examples: window display, file save, audio output, OSC send.
##
## Provides:
##   • family = GNFamily.Type.OUT set automatically
##   • is_sink = true (always included in the active cooking chain)
##   • No output ports
##   • Input helpers for all data types (subclass picks the one it needs)
##   • Simple text preview showing sink status


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.OUT
	is_sink = true


## Ensures family and sink flag are set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	if family != GNFamily.Type.NET:
		family = GNFamily.Type.OUT
	is_sink = true
	super.initialize(p_id)


## No default output port — OUT operators are sinks.
## Subclasses must override _init_ports() to add their typed input(s).
func _init_ports() -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNTextureData from the inputs array at [param port].
func _get_input_top(inputs: Array[GNData], port: int = 0) -> GNTextureData:
	if port < inputs.size() and inputs[port] is GNTextureData:
		var _ret0 := inputs[port] as GNTextureData
		return _ret0
	return null


## Safely extracts a GNImageData from the inputs array at [param port].
func _get_input_img(inputs: Array[GNData], port: int = 0) -> GNImageData:
	if port < inputs.size() and inputs[port] is GNImageData:
		var _ret0 := inputs[port] as GNImageData
		return _ret0
	return null


## Safely extracts a GNChannelData from the inputs array at [param port].
func _get_input_chop(inputs: Array[GNData], port: int = 0) -> GNChannelData:
	if port < inputs.size() and inputs[port] is GNChannelData:
		var _ret0 := inputs[port] as GNChannelData
		return _ret0
	return null


## Safely extracts a GNTableData from the inputs array at [param port].
func _get_input_dat(inputs: Array[GNData], port: int = 0) -> GNTableData:
	if port < inputs.size() and inputs[port] is GNTableData:
		var _ret0 := inputs[port] as GNTableData
		return _ret0
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Default preview — subclasses should override for richer status.
func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = "sink"


func render_for_preview(host) -> void:
	host.set_text("sink")
