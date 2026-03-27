class_name GNFamily
## Enum constants and runtime registry for operator families in GONODES.
##
## Core families are defined in the Type enum (values 0–10).
## Extensions can register additional families at runtime via register_family(),
## which assigns IDs starting at 1000.  All family APIs accept int, so core
## enum values and extension IDs are interchangeable.

## Core operator family enum.
enum Type {
	TOP,   ## Texture Operators — GPU 2D image/texture processing (SubViewport / Shader)
	IMG,   ## Image Operators — CPU-side pixel processing (Image, no SubViewport)
	CHOP,  ## Channel Operators — sample-based numeric data (LFO, math, audio)
	SOP,   ## Surface Operators — 3D geometry (meshes, point clouds)
	POP,   ## Point Operators — GPU-accelerated particle/point systems
	DAT,   ## Data Operators — tables, text, scripts
	MAT,   ## Material Operators — shader/material assignment
	COMP,  ## Component Operators — containers, sub-networks, 3D scene composition
	VOL,   ## Volume Operators — GPU 3D texture processing (noise, fluid, blur)
	UI,    ## UI Operators — 2D interface widgets (buttons, sliders, knobs) for PanelTOP
	OUT,   ## Output Operators — terminal sinks (display, file save, audio out)
	SCRIPT,## Script Operators — user-authored GDScript / Python / C++ code nodes
}

## Next ID for extension-registered families.
static var _next_ext_id: int = 1000

## Family display names for UI.  Extensions append to this at runtime.
static var FAMILY_NAMES: Dictionary = {
	Type.TOP:  "TOP",
	Type.IMG:  "IMG",
	Type.CHOP: "CHOP",
	Type.SOP:  "SOP",
	Type.POP:  "POP",
	Type.DAT:  "DAT",
	Type.MAT:  "MAT",
	Type.COMP: "COMP",
	Type.VOL:  "VOL",
	Type.UI:   "UI",
	Type.OUT:  "OUT",
	Type.SCRIPT: "SCRIPT",
}

## Family colors for port/wire rendering in the graph editor.
static var FAMILY_COLORS: Dictionary = {
	Type.TOP:  Color(0.6, 0.2, 0.8),    # Purple
	Type.IMG:  Color(0.3, 0.7, 0.7),    # Teal
	Type.CHOP: Color(0.2, 0.8, 0.2),    # Green
	Type.SOP:  Color(0.2, 0.4, 0.9),    # Blue
	Type.POP:  Color(0.2, 0.8, 0.8),    # Cyan
	Type.DAT:  Color(0.9, 0.8, 0.2),    # Yellow
	Type.MAT:  Color(0.9, 0.4, 0.2),    # Red/Orange
	Type.COMP: Color(0.5, 0.5, 0.5),    # Gray
	Type.VOL:  Color(0.85, 0.35, 0.55),  # Rose — GPU 3D volumetric textures
	Type.UI:   Color(0.2, 0.7, 0.9),    # Sky Blue — interactive 2D widgets
	Type.OUT:  Color(0.9, 0.3, 0.3),    # Red — terminal sink
	Type.SCRIPT: Color(0.5, 0.9, 0.3),  # Lime — user-authored code nodes
}

## Data factory callbacks: family ID → Callable that returns a fresh GNData subclass.
## Extensions register via register_data_factory() so that GDScriptSCRIPT and
## GNScriptHelper can create the correct output data for extension families.
static var _data_factories: Dictionary = {}


## Registers a new extension family at runtime.
## Returns the assigned family ID (>= 1000).
## Call this from your extension's loader / _init.gd.
static func register_family(family_name: String, color: Color) -> int:
	# Check for duplicate — return existing ID if already registered
	for key in FAMILY_NAMES:
		if FAMILY_NAMES[key] == family_name.to_upper():
			return key
	var id := _next_ext_id
	_next_ext_id += 1
	FAMILY_NAMES[id] = family_name.to_upper()
	FAMILY_COLORS[id] = color
	return id


## Registers a data factory for an extension family.
## The callable should take no arguments and return a fresh GNData subclass instance.
## Example: GNFamily.register_data_factory(SDF_ID, func(): return GNSDFData.new())
static func register_data_factory(family_id: int, factory: Callable) -> void:
	_data_factories[family_id] = factory


## Creates a fresh GNData instance for the given family ID using the registered factory.
## Returns null if no factory is registered for this family.
static func create_data_for_family(family_id: int) -> RefCounted:
	if _data_factories.has(family_id):
		return _data_factories[family_id].call()
	return null


## Returns the display name for a family enum value.
static func get_family_name(family: int) -> String:
	return FAMILY_NAMES.get(family, "UNKNOWN")


## Returns the UI color for a family enum value.
static func get_color(family: int) -> Color:
	return FAMILY_COLORS.get(family, Color.WHITE)


## Converts a family name string (e.g. "TOP", "CHOP") to the corresponding ID.
## Works for both core enum values and extension-registered families.
## Returns [param fallback] if the string is not recognized.
static func string_to_type(family_str: String, fallback: int = Type.COMP) -> int:
	var upper := family_str.to_upper()
	for key in FAMILY_NAMES:
		if FAMILY_NAMES[key] == upper:
			return key
	return fallback
