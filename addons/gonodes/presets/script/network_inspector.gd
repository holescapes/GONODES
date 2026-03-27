# @output dat  Network topology report

func cook():
	outputs[0].set_headers(PackedStringArray(["node_id", "type", "family", "connections_in"]))
	var ids := network_node_ids()
	for nid in ids:
		var info := network_node_info(nid)
		outputs[0].append_row(PackedStringArray([
			nid,
			info.get("type", "?"),
			info.get("family", "?"),
			str(info.get("valid", false))]))
