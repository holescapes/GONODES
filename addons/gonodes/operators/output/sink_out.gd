class_name SinkOUT
extends GNOutBase
## Keep-alive sink — holds its upstream chain active without doing anything.
##
## Accepts any data family. Use this to keep a headless processing chain
## alive when there is no WindowOUT, file-save, or network output downstream.
##
## Typical uses:
##   • Headless automation: a CHOP pipeline feeding expression references
##     that other patches read, with no display needed.
##   • Background processing: keep a compute chain hot without rendering.
##   • Debugging: temporarily anchor a chain as active to inspect cooks.
##
## For Script operators with side-effect code, the "Force Active" toggle
## is a lighter alternative (the script itself becomes the sink).


func _init() -> void:
	node_type = "sink"
	# Default to CHOP; adapts to whatever is connected
	family = GNFamily.Type.OUT


func _init_ports() -> void:
	add_input("in", GNFamily.Type.CHOP, false, "Any data to keep alive")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", true,
		"Active", "When ON this node acts as a sink, keeping its chain cooking"))


func _cook(inputs: Array[GNData]) -> GNData:
	is_sink = get_param_value("active")
	# Pure no-op — data is consumed but not processed
	return null


## Accept connections from any family.
func can_accept_connection(_from_family: GNFamily.Type, _to_port: int) -> bool:
	return true


## Adapt port family when a wire is connected, like DotNode.
func adapt_to_family(new_family: GNFamily.Type) -> void:
	if input_ports.size() > 0:
		input_ports[0].family = new_family
	ports_changed.emit(id)


func update_preview_control(control: Control) -> void:
	if control is Label:
		var active: bool = get_param_value("active") if get_parameter("active") != null else true
		(control as Label).text = "sink (active)" if active else "sink (off)"
