class_name GNUrlCache
extends Node
## Shared URL fetch + disk-cache utility for GONODES operators.
##
## Any operator that accepts a file path can transparently accept an HTTP(S) URL
## instead.  The cache downloads the resource once, stores it under
## user://gonodes_url_cache/ keyed by SHA-256(url), and returns the local path.
##
## Usage from an operator:
##   var result: Dictionary = GNUrlCache.resolve_url(url, self)
##   match result.status:
##       "ready":   use result.path  (local cached file)
##       "pending": return placeholder data (fetch in flight)
##       "error":   log result.error
##
## The cache is per-process (static Dictionary).  Files persist across sessions
## until manually cleared.  No automatic eviction — the cache directory can be
## deleted by the user.
##
## Thread safety: NOT thread-safe (uses HTTPRequest which needs the scene tree).
## Operators using this should set thread_safe = false.


const CACHE_DIR := "user://gonodes_url_cache/"

## Map of URL → { "path": String, "status": String, "error": String }
## status: "pending" | "ready" | "error"
static var _entries: Dictionary = {}

## Map of URL → HTTPRequest node (while in flight)
static var _in_flight: Dictionary = {}

## Map of URL → Array of GNNode references to mark dirty when fetch completes
static var _waiters: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## Returns true if the string looks like an HTTP(S) URL.
static func is_url(path: String) -> bool:
	var lower := path.strip_edges().to_lower()
	return lower.begins_with("http://") or lower.begins_with("https://")


## Resolve a URL to a local cached file path.
## [param url]     — the HTTP(S) URL to fetch.
## [param caller]  — the GNNode requesting the resource (used as scene tree
##                   host for HTTPRequest and to mark dirty on completion).
## Returns: { "status": "ready"|"pending"|"error", "path": String, "error": String }
static func resolve_url(url: String, caller: Node) -> Dictionary:
	var key := url.strip_edges()

	# Already cached on disk?
	if _entries.has(key):
		var entry: Dictionary = _entries[key]
		return entry

	# Already in flight?
	if _in_flight.has(key):
		# Register this caller as a waiter
		if not _waiters.has(key):
			_waiters[key] = []
		var arr: Array = _waiters[key]
		if caller not in arr:
			arr.append(caller)
		return {"status": "pending", "path": "", "error": ""}

	# Check if already on disk from a previous session
	var cached_path := _cache_path_for(key)
	if FileAccess.file_exists(cached_path):
		var entry := {"status": "ready", "path": cached_path, "error": ""}
		_entries[key] = entry
		return entry

	# Start a new fetch
	_start_fetch(key, caller)
	return {"status": "pending", "path": "", "error": ""}


## Clears the in-memory cache (does not delete files on disk).
static func clear_memory_cache() -> void:
	_entries.clear()
	_waiters.clear()
	# In-flight requests will still complete but results won't be stored


## Clears a single URL from the in-memory cache so it will be re-fetched.
static func invalidate(url: String) -> void:
	var key := url.strip_edges()
	_entries.erase(key)


# ═══════════════════════════════════════════════════════════════════════════════
# Internal
# ═══════════════════════════════════════════════════════════════════════════════

static func _cache_path_for(url: String) -> String:
	var hash_str: String = url.sha256_text()
	var ext := url.get_file().get_extension()
	# Strip query params from extension
	if ext.contains("?"):
		ext = ext.substr(0, ext.find("?"))
	if ext.is_empty():
		ext = "bin"
	return CACHE_DIR + hash_str + "." + ext


static func _start_fetch(url: String, caller: Node) -> void:
	# Ensure cache directory exists
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)

	var http := HTTPRequest.new()
	http.name = "GNUrlCache_%d" % (hash(url) & 0x7FFFFFFF)
	http.download_file = _cache_path_for(url)
	# Allow large files (100 MB)
	http.max_redirects = 8
	http.timeout = 30.0

	# Store caller as first waiter
	_waiters[url] = [caller]
	_in_flight[url] = http

	# HTTPRequest must live in the scene tree or request() returns ERR_UNCONFIGURED.
	var parent: Node = null
	if caller.is_inside_tree():
		parent = caller
	else:
		var tree := Engine.get_main_loop()
		if tree is SceneTree:
			parent = (tree as SceneTree).root
	if parent == null:
		var entry := {"status": "error", "path": "", "error": "HTTP request start failed: %s" % error_string(ERR_UNCONFIGURED)}
		_entries[url] = entry
		_in_flight.erase(url)
		_waiters.erase(url)
		_cleanup_http(http)
		GNLogger.warn("GNUrlCache", "Failed to start fetch for '%s': %s" % [url, error_string(ERR_UNCONFIGURED)])
		return

	parent.add_child(http)
	http.request_completed.connect(_on_fetch_completed.bind(url, http))

	if http.is_inside_tree():
		_complete_fetch_start(url, http)
	else:
		http.tree_entered.connect(_complete_fetch_start.bind(url, http), CONNECT_ONE_SHOT)


static func _complete_fetch_start(url: String, http: HTTPRequest) -> void:
	if not _in_flight.has(url) or _in_flight[url] != http:
		return
	var err := http.request(url)
	if err != OK:
		var entry := {"status": "error", "path": "", "error": "HTTP request start failed: %s" % error_string(err)}
		_entries[url] = entry
		_in_flight.erase(url)
		_waiters.erase(url)
		_cleanup_http(http)
		GNLogger.warn("GNUrlCache", "Failed to start fetch for '%s': %s" % [url, error_string(err)])


static func _on_fetch_completed(result: int, response_code: int,
		_headers: PackedStringArray, _body: PackedByteArray,
		url: String, http: HTTPRequest) -> void:

	_in_flight.erase(url)
	_cleanup_http(http)

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var msg := "HTTP %d (result %d)" % [response_code, result]
		var entry := {"status": "error", "path": "", "error": msg}
		_entries[url] = entry
		GNLogger.warn("GNUrlCache", "Fetch failed for '%s': %s" % [url, msg])
		_notify_waiters(url)
		return

	var cached_path := _cache_path_for(url)
	if not FileAccess.file_exists(cached_path):
		var entry := {"status": "error", "path": "", "error": "Download completed but file not found on disk"}
		_entries[url] = entry
		GNLogger.warn("GNUrlCache", "Cache file missing after download: %s" % cached_path)
		_notify_waiters(url)
		return

	var entry := {"status": "ready", "path": cached_path, "error": ""}
	_entries[url] = entry
	GNLogger.info("GNUrlCache", "Cached '%s' → %s" % [url, cached_path])
	_notify_waiters(url)


static func _notify_waiters(url: String) -> void:
	if not _waiters.has(url):
		return
	var arr: Array = _waiters[url]
	for node in arr:
		if is_instance_valid(node) and node is GNNode:
			(node as GNNode).dirty = true
	_waiters.erase(url)


static func _cleanup_http(http: HTTPRequest) -> void:
	if is_instance_valid(http):
		if http.get_parent() != null:
			http.get_parent().remove_child(http)
		http.queue_free()
