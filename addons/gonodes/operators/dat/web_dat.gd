class_name WebDAT
extends GNDatBase
## Fetches data from a URL via HTTP request.
## Supports GET and POST methods with optional auto-parsing of JSON/CSV.
##
## Uses a cached response approach: cook returns the last successful response
## while a new request may be in flight. The first cook with a given URL
## triggers an async fetch; subsequent cooks return cached data until the
## response arrives.


## Cached response body from the last successful HTTP request.
var _last_response: String = ""

## Whether a request is currently in flight.
var _request_pending: bool = false

## The URL of the currently cached response (to detect URL changes).
var _cached_url: String = ""

## Internal HTTPRequest node for async fetching.
var _http_request: HTTPRequest = null


func _init() -> void:
	node_type = "web"
	time_dependent = false
	thread_safe = false  # HTTPRequest I/O


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "HTTP response data")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("url", "URL address",
		"URL", "Target URL to fetch"))
	add_parameter(GNParameter.create_enum("method",
		PackedStringArray(["GET", "POST"]), 0,
		"Method", "HTTP method"))
	add_parameter(GNParameter.create_string("body", "The body string",
		"Body", "Request body (POST only)"))
	add_parameter(GNParameter.create_string("content_type", "application/json",
		"Content Type", "Content-Type header value"))
	add_parameter(GNParameter.create_bool("auto_parse", true,
		"Auto Parse", "Attempt to parse response as JSON or CSV"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var url: String = get_param_value("url")

	if url.is_empty():
		out.is_table = false
		out.set_text("")
		return out

	# Trigger a new request if URL changed or no cached data
	if url != _cached_url and not _request_pending:
		_trigger_request(url)

	# Return cached data
	if _last_response.is_empty():
		out.is_table = false
		out.set_text("(awaiting response...)")
		return out

	var auto_parse: bool = get_param_value("auto_parse")
	if auto_parse:
		# Try JSON first
		var parsed = JSON.parse_string(_last_response)
		if parsed != null:
			out.is_table = true
			out.has_header = true
			if parsed is Array and parsed.size() > 0 and parsed[0] is Dictionary:
				var keys: Array = parsed[0].keys()
				var hdr := PackedStringArray()
				for k in keys:
					hdr.append(str(k))
				out.set_headers(hdr)
				for item in parsed:
					var row := PackedStringArray()
					for k in keys:
						row.append(str(item.get(k, "")))
					out.append_row(row)
				return out
			elif parsed is Dictionary:
				out.set_headers(PackedStringArray(["key", "value"]))
				for k in parsed.keys():
					out.append_row(PackedStringArray([str(k), str(parsed[k])]))
				return out

		# Try CSV (if response contains commas and newlines)
		if _last_response.contains(",") and _last_response.contains("\n"):
			var lines := _last_response.split("\n", false)
			if lines.size() > 1:
				out.is_table = true
				out.has_header = true
				for i in range(lines.size()):
					var cells := PackedStringArray()
					for cell_val in lines[i].split(","):
						cells.append(cell_val.strip_edges())
					if i == 0:
						out.set_headers(cells)
					else:
						out.append_row(cells)
				return out

	# Fallback: return as plain text
	out.is_table = false
	out.set_text(_last_response)
	return out


## Triggers an async HTTP request. Creates HTTPRequest node on demand.
func _trigger_request(url: String) -> void:
	_request_pending = true

	if _http_request == null:
		_http_request = HTTPRequest.new()
		add_child(_http_request)
		_http_request.request_completed.connect(_on_request_completed)

	var method_idx: int = get_param_value("method")
	var body: String = get_param_value("body")
	var content_type: String = get_param_value("content_type")
	var headers := PackedStringArray(["Content-Type: %s" % content_type])

	var http_method: HTTPClient.Method = HTTPClient.METHOD_GET if method_idx == 0 else HTTPClient.METHOD_POST

	var error: Error = _http_request.request(url, headers, http_method, body)
	if error != OK:
		push_warning("WebDAT: HTTP request failed to start: %s" % error_string(error))
		_request_pending = false


## Callback for completed HTTP request.
func _on_request_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("WebDAT: Request failed with result %d, HTTP %d" % [result, response_code])
		return
	_last_response = body.get_string_from_utf8()
	_cached_url = get_param_value("url")
	# Mark dirty so next cook picks up new data
	dirty = true
