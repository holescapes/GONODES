class_name GNReferenceScanner
extends RefCounted
## Static scan helpers for implicit node relationships (reads, writes, @affects).
## Shared by GNCookEngine (demand / active set) and GNGraphEditor (overlay lines).

enum RefKind { READ, WRITE, AFFECTS }

## STRING params holding executable script bodies (GDScript / Python / Native).
const CODE_PARAM_NAMES: PackedStringArray = [
	"code", "py_source", "cpp_source",
]

## CallbackDAT callback bodies.
const CALLBACK_PARAM_NAMES: PackedStringArray = [
	"on_start", "on_cook", "on_value_change", "on_create",
]

static var _read_id_regex: RegEx = null
static var _write_set_par_regex: RegEx = null
static var _write_connect_regex: RegEx = null
static var _affects_regex: RegEx = null
## Alternation of call names. Empty uses the built-in list. Cook engine
## extends this with the expression-function registry so one regex serves
## both read-ids and family demand.
static var _call_alt: String = ""


## Rebuild the call regex when the expression registry adds function names.
## Returns true when the pattern actually changed.
static func configure_call_funcs(func_names: PackedStringArray) -> bool:
	var names: Array[String] = []
	for n in func_names:
		if not n.is_empty() and n not in names:
			names.append(n)
	for fixed in ["lookupf", "lookup", "chops", "chopi", "chopf", "chop",
			"output", "op", "top", "sop", "dat", "mat", "vol", "img", "pop",
			"pars", "pari", "parf", "par", "cellf_by_name", "cell_by_name",
			"cellf", "cell"]:
		if fixed not in names:
			names.append(fixed)
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var alt := "|".join(names)
	if alt == _call_alt and _read_id_regex != null:
		return false
	_call_alt = alt
	_read_id_regex = null
	_ensure_regex()
	return true


static func _ensure_regex() -> void:
	if _read_id_regex != null:
		return
	var alt := _call_alt
	if alt.is_empty():
		alt = "lookupf?|chop[sfi]?|op|top|sop|dat|mat|vol|img|pop|output|par[sfi]?|cellf?_by_name|cellf?"
	_read_id_regex = RegEx.new()
	# Group 1 = function name, group 2 = node id.
	_read_id_regex.compile("(%s)\\s*\\(\\s*\"([^\"]+)\"" % alt)
	_write_set_par_regex = RegEx.new()
	_write_set_par_regex.compile("set_par\\s*\\(\\s*\"([^\"]+)\"")
	_write_connect_regex = RegEx.new()
	_write_connect_regex.compile(
		"network_(?:connect|disconnect)\\s*\\(\\s*\"([^\"]+)\"[^)]*,[^)]*,\\s*\"([^\"]+)\"")
	_affects_regex = RegEx.new()
	_affects_regex.compile("^\\s*#\\s*@affects\\s+(.+)$")


static func is_code_body_param(param: GNParameter) -> bool:
	if param.value_type != GNParameter.ValueType.STRING:
		return false
	return param.param_name in CODE_PARAM_NAMES or param.param_name in CALLBACK_PARAM_NAMES


## All text blobs on a node that may contain references.
static func collect_scan_texts(node: GNNode) -> Array[String]:
	var texts: Array[String] = []
	if node == null:
		return texts
	for param_name in node.parameters:
		var param: GNParameter = node.parameters[param_name]
		if param.mode == GNParameter.Mode.EXPRESSION and param.expression != "":
			texts.append(param.expression)
		for i in range(param.component_expressions.size()):
			if param.component_modes.size() > i \
					and param.component_modes[i] == GNParameter.Mode.EXPRESSION:
				var comp: String = param.component_expressions[i]
				if not comp.is_empty():
					texts.append(comp)
		if is_code_body_param(param):
			var body: String = str(param.value)
			if not body.is_empty():
				texts.append(body)
	return texts


## Node IDs read/referenced (chop, dat, par on remote node, etc.).
static func scan_read_ids(text: String, owner_id: String) -> Array[String]:
	_ensure_regex()
	var refs: Array[String] = []
	for m in _read_id_regex.search_all(text):
		var ref_id: String = m.get_string(2)
		if ref_id != owner_id and not refs.has(ref_id):
			refs.append(ref_id)
	return refs


## Write targets from set_par("node", ...) and network_connect(..., "to", ...).
## Returns Array of { "target_id": String, "detail": String }.
static func scan_write_targets(text: String, owner_id: String) -> Array:
	_ensure_regex()
	var out: Array = []
	for m in _write_set_par_regex.search_all(text):
		var target_id: String = m.get_string(1)
		if target_id == owner_id:
			continue
		var detail := "set_par(\"%s\", …)" % target_id
		if not _has_write_target(out, target_id, detail):
			out.append({"target_id": target_id, "detail": detail})
	for m in _write_connect_regex.search_all(text):
		var to_id: String = m.get_string(2)
		if to_id.is_empty() or to_id == owner_id:
			continue
		var detail := "network_connect(…, \"%s\", …)" % to_id
		if not _has_write_target(out, to_id, detail):
			out.append({"target_id": to_id, "detail": detail})
	return out


static func _has_write_target(arr: Array, target_id: String, detail: String) -> bool:
	for entry in arr:
		if entry.get("target_id", "") == target_id:
			return true
	# Allow multiple details for same target — merge in caller if needed
	return false


## Parses `# @affects node_id` and `# @affects node_id:param` annotations.
static func parse_affects_annotations(code: String) -> Array:
	_ensure_regex()
	var out: Array = []
	for line in code.split("\n"):
		var m := _affects_regex.search(line.strip_edges())
		if m == null:
			continue
		var spec: String = m.get_string(1).strip_edges()
		if spec.is_empty():
			continue
		var node_id: String = spec
		var param_name: String = ""
		if ":" in spec:
			var parts := spec.split(":", false, 1)
			node_id = parts[0].strip_edges()
			param_name = parts[1].strip_edges() if parts.size() > 1 else ""
		if not node_id.is_empty():
			out.append({"target_id": node_id, "param": param_name,
				"detail": "@affects %s" % spec})
	return out


## Full scan of one node: reads, calls (func + id), static writes, @affects.
## Call extraction shares the read regex — one pass per text blob.
static func scan_node(node: GNNode) -> Dictionary:
	var reads: Array[String] = []
	var calls: Array = []
	var writes: Array = []
	var affects: Array = []
	if node == null:
		return {"reads": reads, "calls": calls, "writes": writes, "affects": affects}
	_ensure_regex()
	for text in collect_scan_texts(node):
		for m in _read_id_regex.search_all(text):
			var func_name: String = m.get_string(1)
			var ref_id: String = m.get_string(2)
			calls.append({"func": func_name, "target_id": ref_id})
			if ref_id != node.id and not reads.has(ref_id):
				reads.append(ref_id)
		for w in scan_write_targets(text, node.id):
			if not _writes_has(writes, w["target_id"]):
				writes.append(w)
	for p_name in node.parameters:
		var param: GNParameter = node.parameters[p_name]
		if is_code_body_param(param):
			for aff in parse_affects_annotations(str(param.value)):
				affects.append(aff)
				if not _writes_has(writes, aff["target_id"]):
					writes.append({"target_id": aff["target_id"],
						"detail": aff["detail"]})
	return {"reads": reads, "calls": calls, "writes": writes, "affects": affects}


static func _writes_has(writes: Array, target_id: String) -> bool:
	for w in writes:
		if w.get("target_id", "") == target_id:
			return true
	return false


## Edge detail strings for tooltips: key "consumer→source" → [call texts].
## Each call stays on the node id inside that same call. Pairing the two
## regexes by index shifts the label onto the next node when a call contains
## another call, such as set_par("node", "param", str(par("x"))).
static func build_read_edge_details(text: String, consumer_id: String) -> Dictionary:
	_ensure_regex()
	var details: Dictionary = {}
	for m in _read_id_regex.search_all(text):
		var ref_id: String = m.get_string(2)
		if ref_id == consumer_id:
			continue
		var call_text := _balanced_call_from(text, m.get_start())
		var edge_key := "%s→%s" % [consumer_id, ref_id]
		if not details.has(edge_key):
			details[edge_key] = []
		var arr: Array = details[edge_key]
		if not arr.has(call_text):
			arr.append(call_text)
	return details


## Call text starting at a function name, through the matching close paren.
static func _balanced_call_from(text: String, start: int) -> String:
	var paren := text.find("(", start)
	if paren < 0:
		return text.substr(start)
	var depth := 0
	var in_string := false
	var i := paren
	while i < text.length():
		var c := text.unicode_at(i)
		if in_string:
			if c == 92:
				i += 2
				continue
			if c == 34:
				in_string = false
		elif c == 34:
			in_string = true
		elif c == 40:
			depth += 1
		elif c == 41:
			depth -= 1
			if depth == 0:
				return text.substr(start, i - start + 1)
		i += 1
	return text.substr(start)


## Scan entire network into overlay-friendly maps.
## Returns {
##   reads: { consumer_id: [source_id, ...] },
##   writes: { writer_id: [ {target_id, detail}, ... ] },
##   read_details: { "consumer→source": [calls] }
## }
static func scan_network(network: GNNetwork) -> Dictionary:
	var reads: Dictionary = {}
	var writes: Dictionary = {}
	var read_details: Dictionary = {}
	if network == null:
		return {"reads": reads, "writes": writes, "read_details": read_details}
	for node_id in network.nodes:
		var node: GNNode = network.nodes[node_id]
		var scan := scan_node(node)
		var rids: Array = scan["reads"]
		if not rids.is_empty():
			reads[node_id] = rids
		var warr: Array = scan["writes"]
		if not warr.is_empty():
			writes[node_id] = warr
		for text in collect_scan_texts(node):
			var partial := build_read_edge_details(text, node_id)
			for k in partial:
				if not read_details.has(k):
					read_details[k] = []
				for d in partial[k]:
					if d not in read_details[k]:
						read_details[k].append(d)
	return {"reads": reads, "writes": writes, "read_details": read_details}


## Nodes whose static reads reference [param target_id].
static func find_readers_of(network: GNNetwork, target_id: String) -> Array[String]:
	var readers: Array[String] = []
	if network == null or target_id.is_empty():
		return readers
	var scan := scan_network(network)
	var reads_map: Dictionary = scan["reads"]
	for consumer_id in reads_map:
		var sources: Array = reads_map[consumer_id]
		if target_id in sources and not readers.has(consumer_id):
			readers.append(consumer_id)
	return readers
