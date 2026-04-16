class_name GNData
extends RefCounted
## Base class for all operator output data in GONODES.
## Subclassed by GNTextureData (TOPs), GNChannelData (CHOPs), etc.
## RefCounted — transient compute results, never serialized.

## Whether this data was produced by a successful cook.
var valid: bool = false

## Frame number when this data was last cooked.
var timestamp: int = -1

## True when this data's producer feeds more than one downstream consumer.
## Set by the cook engine from connection topology — never set by operators.
## Operators that need to mutate input data should call
## [method GNNode._mutable_input] which checks this flag and duplicates only
## when shared (copy-on-write).
var _shared: bool = false


## Returns the operator family this data type belongs to.
## Must be overridden by subclasses.
func get_family() -> int:
	push_error("GNData.get_family() called on base class — must override in subclass")
	return GNFamily.Type.TOP  # Fallback


## Returns a multi-line string for the on-node inline preview label.
## Override in subclasses to show family-specific summaries.
func get_preview_text() -> String:
	return ""


## Returns a compact one-line string for debug overlays and status bars.
## Override in subclasses to show family-specific dimension info.
func get_data_summary() -> String:
	return ""


## Marks this data as invalid and resets its state.
func invalidate() -> void:
	valid = false


## Creates a deep copy of this data.  Override in subclasses for proper cloning.
func duplicate_data() -> GNData:
	var copy := GNData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	# _shared is NOT copied — the clone is a private copy, not shared.
	return copy


# ═══════════════════════════════════════════════════════════════════════════════
# Introspection API — Used by UI for autocomplete/status without type casts
# ═══════════════════════════════════════════════════════════════════════════════

## Returns completion items for expression editors and inline autocomplete.
## Each entry: {"label": "channel_name", "kind": "member"}.
## Override in subclasses that expose named sub-values (e.g. CHOP channels).
func get_completions() -> Array[Dictionary]:
	return []


## Saves mutable runtime state for hot-reload preservation.
## Returns a dictionary that can be passed to [method restore_state].
## Override in subclasses with mutable state (e.g. CHOP channel arrays).
func save_state() -> Dictionary:
	return {}


## Restores mutable runtime state from a dictionary saved by [method save_state].
func restore_state(state: Dictionary) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# Expression API — Called by cook engine expression proxies
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a property value for expression access.
## [param key]: property name (e.g. "resolution", "aspect" for TOP; channel name for CHOP).
## [param index]: sample index for array-like data (-1 = last sample).
## Override in subclasses.  Returns 0.0 if key is unknown.
func get_expression_value(key: String, index: int = -1) -> Variant:
	return 0.0


## Returns a summary dict for no-argument expression calls.
## e.g. chop("lfo1") with no channel → {"channels": [...], "length": N, ...}
## Override in subclasses.  Returns empty dict by default.
func get_expression_info() -> Dictionary:
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# Export API — Called by graph editor export system
# ═══════════════════════════════════════════════════════════════════════════════

## Returns export file filters for the save dialog.
## Each entry: {"filter": "*.png", "description": "PNG Image"}.
## Returns empty array if this data type doesn't support export.
func get_export_filters() -> Array[Dictionary]:
	return []


## Exports this data to the given file path.
## Returns OK on success, or an error code.  Override in subclasses.
func export_to_file(path: String) -> Error:
	return ERR_UNAVAILABLE
