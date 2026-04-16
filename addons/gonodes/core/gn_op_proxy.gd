class_name GNOpProxy
extends RefCounted
## Lightweight read-only proxy returned by op() in expressions.
## Holds a direct reference to the GNNode — no data copying.
## Properties are computed on access, so op("n").type is just a pointer chase.
## Created per expression eval, auto-freed when unreferenced (RefCounted).

var _node: GNNode


## All properties are read-only getters backed by the live GNNode.

var id: String:
	get: return _node.id if _node else ""
	set(_v): pass

var type: String:
	get: return _node.node_type if _node else ""
	set(_v): pass

var family: String:
	get: return GNFamily.get_family_name(_node.family) if _node else ""
	set(_v): pass

var family_id: int:
	get: return _node.family if _node else -1
	set(_v): pass

var digits: int:
	get:
		if _node == null:
			return 0
		var nid := _node.id
		var i := nid.length() - 1
		while i >= 0 and nid[i].is_valid_int():
			i -= 1
		return nid.substr(i + 1).to_int() if i < nid.length() - 1 else 0
	set(_v): pass

var valid: bool:
	get: return _node.cook_valid if _node else false
	set(_v): pass

var cook_time: float:
	get: return _node.cook_time_ms if _node else 0.0
	set(_v): pass

var time_dependent: bool:
	get: return _node.time_dependent if _node else false
	set(_v): pass

var bypass: bool:
	get: return _node.bypass if _node else false
	set(_v): pass

var num_inputs: int:
	get: return _node.input_ports.size() if _node else 0
	set(_v): pass

var num_outputs: int:
	get: return _node.output_ports.size() if _node else 0
	set(_v): pass

var num_params: int:
	get: return _node.parameters.size() if _node else 0
	set(_v): pass
