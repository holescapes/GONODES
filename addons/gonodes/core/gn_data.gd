class_name GNData
extends Resource
## Base class for all operator output data in GONODES.
## Subclassed by GNTextureData (TOPs), GNChannelData (CHOPs), etc.

## Whether this data was produced by a successful cook.
@export var valid: bool = false

## Frame number when this data was last cooked.
@export var timestamp: int = -1


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
	return copy
