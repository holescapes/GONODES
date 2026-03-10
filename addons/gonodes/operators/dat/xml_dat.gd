class_name XMLDAT
extends GNDatBase
## Parse an XML document into a flat DAT table.
##
## Each row represents one attribute or text node found in the document:
##   path      — XPath-like element path  (e.g. "root/child/item")
##   attribute — attribute name, or "#text" for text content
##   value     — attribute or text value
##
## Source modes:
##   String — parse the inline "XML String" parameter.
##   File   — read and parse a file from disk.


func _init() -> void:
	node_type = "xml"
	node_description = "Parse XML document into a flat path/attribute/value table."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Parsed XML table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("source",
		PackedStringArray(["String", "File"]), 0,
		"Source", "Parse inline XML string or read from a file on disk"))
	add_parameter(GNParameter.create_string("xml_string",
		"<root><item name=\"alpha\" value=\"1\"/><item name=\"beta\" value=\"2\"/></root>",
		"XML String", "XML text to parse (String mode)"))
	add_parameter(GNParameter.create_string("file_path", "",
		"File Path", "Absolute or res:// path to an XML file (File mode)"))
	add_parameter(GNParameter.create_bool("include_text", true,
		"Include Text", "Include element text-content rows (#text attribute)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var source: int         = get_param_value("source")
	var include_text: bool  = get_param_value("include_text")

	var xml_data: String = ""

	if source == 0:
		xml_data = get_param_value("xml_string")
	else:
		var path: String = get_param_value("file_path")
		if not path.is_empty():
			if FileAccess.file_exists(path):
				var f := FileAccess.open(path, FileAccess.READ)
				if f:
					xml_data = f.get_as_text()
					f.close()
			else:
				push_warning("XMLDAT: file not found — '%s'" % path)

	if xml_data.is_empty():
		return out

	_parse_xml(xml_data, out, include_text)
	return out


## Parse XML text into the output table (path, attribute, value columns).
func _parse_xml(text: String, tbl: GNTableData, include_text: bool) -> void:
	tbl.is_table      = true
	tbl.has_header    = true
	tbl.set_headers(PackedStringArray(["path", "attribute", "value"]))

	var parser := XMLParser.new()
	if parser.open_buffer(text.to_utf8_buffer()) != OK:
		push_warning("XMLDAT: failed to open XML buffer")
		return

	# Stack tracks the current element path segments.
	var path_stack: Array[String] = []

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var elem: String = parser.get_node_name()
				path_stack.push_back(elem)
				var path: String = "/".join(path_stack)

				# One row per attribute.
				for i in range(parser.get_attribute_count()):
					tbl.append_row(PackedStringArray([
						path,
						parser.get_attribute_name(i),
						parser.get_attribute_value(i)
					]))
				# Emit a bare "presence" row if the element had no attributes.
				if parser.get_attribute_count() == 0:
					tbl.append_row(PackedStringArray([path, "", ""]))

			XMLParser.NODE_TEXT:
				if include_text:
					var t: String = parser.get_node_data().strip_edges()
					if not t.is_empty() and not path_stack.is_empty():
						tbl.append_row(PackedStringArray([
							"/".join(path_stack),
							"#text",
							t
						]))

			XMLParser.NODE_ELEMENT_END:
				if not path_stack.is_empty():
					path_stack.pop_back()
