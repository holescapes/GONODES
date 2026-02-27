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
func get_family() -> GNFamily.Type:
	push_error("GNData.get_family() called on base class — must override in subclass")
	return GNFamily.Type.TOP  # Fallback


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
