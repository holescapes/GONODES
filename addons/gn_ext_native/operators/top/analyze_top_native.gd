class_name AnalyzeTOPNative
extends AnalyzeTOP
## Same neighbourhood statistics as AnalyzeTOP, sampled in the fragment shader.
## The previous native cook downloaded the TOP with get_image() and uploaded
## the result. That round trip is not required for a TOP output.


func _init() -> void:
	super._init()
	node_type = "analyze_native"
	node_description = "Per-pixel min/max/avg/sum on the GPU. Does not read the texture back to the CPU."
