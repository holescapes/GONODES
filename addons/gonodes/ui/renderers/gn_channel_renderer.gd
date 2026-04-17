class_name GNChannelRenderer
extends GNDataRenderer
## Renders GNChannelData in the viewer (interactive waveform control).

## Shared waveform control — reused across all channel renderings.
static var _viewer_waveform: GNWaveformView = null


func render_for_viewer(data: GNData, viewer) -> void:
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
