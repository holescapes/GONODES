class_name InteractiveTOPStub
extends GNTopInteractiveBase
## Minimal interactive TOP for unit tests (no extension dependency).

const _PANEL_SCRIPT := preload("res://tests/unit/fixtures/interactive_panel_stub.gd")


func _init() -> void:
	node_type = "test_interactive_top"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "", "In")
	add_output("out", GNFamily.Type.TOP, "", "Out")
	add_panel_output()


func _create_interactive_panel() -> GNInteractivePanel:
	return _PANEL_SCRIPT.new()


func _cook(_inputs: Array[GNData]) -> GNData:
	return null
