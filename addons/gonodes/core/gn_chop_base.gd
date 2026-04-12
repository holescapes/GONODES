class_name GNChopBase
extends GNNode
## Base class for all CHOP (Channel Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.CHOP set automatically
##   • Default output port "out" of type CHOP
##   • Cached GNChannelData with _prepare_output() helper
##   • Input validation via _get_input_chop()
##   • Inline channel preview (create_preview_control / update_preview_control)

# ─── Shared CHOP Infrastructure ────────────────────────────────────────────────

## Reusable output data object (created once, cleared each cook).
var _cached_channel_data: GNChannelData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.CHOP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	family = GNFamily.Type.CHOP
	super.initialize(p_id)


## Default output port.  Override in subclass to add inputs or extra outputs.
func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Channel data output")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates or clears the cached channel data and sets the sample rate.
## Call at the top of _cook() to get a clean slate for channel output.
func _prepare_output(sample_rate: float = 60.0) -> GNChannelData:
	if _cached_channel_data == null:
		_cached_channel_data = GNChannelData.new()
	else:
		_cached_channel_data.channels.clear()
		_cached_channel_data.length = 0
	_cached_channel_data.sample_rate = sample_rate
	return _cached_channel_data


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNChannelData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNChannelData.
func _get_input_chop(inputs: Array[GNData], port: int = 0) -> GNChannelData:
	if port < inputs.size() and inputs[port] is GNChannelData:
		return inputs[port] as GNChannelData
	return null


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


func render_for_preview(host) -> void:
	if cached_output != null:
		host.set_text(cached_output.get_preview_text())
	else:
		host.set_text("")


## Shared waveform control — uses GNWaveformView (grid, zoom, pan, legends).
static var _viewer_waveform: GNWaveformView = null


func render_for_viewer(viewer, port_index: int = 0) -> void:
	var data: GNData = get_output_data(port_index)
	if data is GNChannelData:
		var ch: GNChannelData = data as GNChannelData
		if not ch.channels.is_empty():
			if _viewer_waveform == null:
				_viewer_waveform = GNViewerRenderHelpers.create_waveform_view()
			_viewer_waveform.set_channel_data(ch)
			var info := "%d ch × %d samples" % [ch.channels.size(), ch.length]
			viewer.set_control(_viewer_waveform, info)
			return
	viewer.set_info("No CHOP output", "")
