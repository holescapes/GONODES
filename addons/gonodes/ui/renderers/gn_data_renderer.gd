class_name GNDataRenderer
extends RefCounted
## Abstract base for family-specific viewer/preview rendering.
##
## Separates display logic from GNData (cook engine layer, editor-agnostic)
## so that data classes never reference viewer/UI APIs.  Renderers live in
## the editor UI layer — the cook engine and headless player never load them.
##
## One renderer instance per family, registered via gn_core.cfg / gn_extension.cfg
## [family.*] "renderer_script" key.  The viewer panel dispatches:
##
##   data = node.get_output_data(port)
##   renderer = GNFamily.get_renderer(data.get_family())
##   renderer.render_for_viewer(data, viewer)
##
## Nodes that need custom visualization (CameraCOMP frustum, LightCOMP cone,
## mapper TOP control points) override render_for_viewer() at the node level
## which takes precedence — the renderer is only consulted when the node
## falls through to the GNNode base implementation.
##
## Viewer interaction state (orbit yaw/pitch/distance, vol slice position,
## texture zoom/pan) lives on the GNViewerPanel — each viewer instance is
## independent.  Renderers read/write viewer state via the viewer parameter.


## Renders [param data] into the viewer panel.
## Override in subclasses to provide family-specific visualization.
func render_for_viewer(_data: GNData, _viewer) -> void:
	_viewer.set_info(_data.get_preview_text(), "")


## Renders a compact inline preview (node thumbnail).
## [param host] exposes set_texture(), set_text(), set_control().
func render_for_preview(_data: GNData, _host) -> void:
	if _host.has_method("set_text"):
		_host.set_text(_data.get_preview_text())


## Whether this family supports wireframe display in the viewer.
func supports_wireframe() -> bool:
	return false


## Handles user input forwarded from the viewer panel.
## Returns true if the event was consumed.
func handle_viewer_input(_data: GNData, _event: InputEvent, _viewer) -> bool:
	return false
