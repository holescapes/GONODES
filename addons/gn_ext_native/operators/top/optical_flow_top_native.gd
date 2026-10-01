class_name OpticalFlowTOPNative
extends OpticalFlowTOP
## Same Horn-Schunck flow as OpticalFlowTOP, sampled from the current and
## previous ViewportTextures. The previous native cook downloaded both frames.


func _init() -> void:
	super._init()
	node_type = "opticalflow_native"
	node_description = "Motion vectors between frames on the GPU. Does not read the texture back to the CPU."
