class_name NullFIX
extends GNFixtureBase
## FIX pass-through.
## Forwards its input fixture unchanged. Useful as a labelled relay point.


func _init() -> void:
	super._init()
	node_type = "null_fix"
	node_description = "FIX pass-through — forwards input fixture unchanged."


func _init_ports() -> void:
	add_input("in", GNFixtureBase.FIX_FAMILY, false, "Input fixture")
	add_output("out", GNFixtureBase.FIX_FAMILY, "Same fixture (pass-through)")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	return _null_cook(inputs)
