class_name GNFamily
## Enum constants for operator families in GONODES.
## Each family represents a category of operators that process a specific data type.

## Operator family enum — matches TouchDesigner's family model.
enum Type {
	TOP,   ## Texture Operators — 2D image/texture processing
	CHOP,  ## Channel Operators — sample-based numeric data (LFO, math, audio)
	SOP,   ## Surface Operators — 3D geometry (meshes, point clouds)
	POP,   ## Point Operators — GPU-accelerated particle/point systems
	DAT,   ## Data Operators — tables, text, scripts
	MAT,   ## Material Operators — shader/material assignment
	COMP,  ## Component Operators — containers, sub-networks, UI
}

## Family display names for UI.
const FAMILY_NAMES: Dictionary = {
	Type.TOP:  "TOP",
	Type.CHOP: "CHOP",
	Type.SOP:  "SOP",
	Type.POP:  "POP",
	Type.DAT:  "DAT",
	Type.MAT:  "MAT",
	Type.COMP: "COMP",
}

## Family colors for port/wire rendering in the graph editor.
const FAMILY_COLORS: Dictionary = {
	Type.TOP:  Color(0.6, 0.2, 0.8),    # Purple
	Type.CHOP: Color(0.2, 0.8, 0.2),    # Green
	Type.SOP:  Color(0.2, 0.4, 0.9),    # Blue
	Type.POP:  Color(0.2, 0.8, 0.8),    # Cyan
	Type.DAT:  Color(0.9, 0.8, 0.2),    # Yellow
	Type.MAT:  Color(0.9, 0.4, 0.2),    # Red/Orange
	Type.COMP: Color(0.5, 0.5, 0.5),    # Gray
}


## Returns the display name for a family enum value.
## Named get_family_name() to avoid collision with Object.get_name().
static func get_family_name(family: Type) -> String:
	return FAMILY_NAMES.get(family, "UNKNOWN")


## Returns the UI color for a family enum value.
static func get_color(family: Type) -> Color:
	return FAMILY_COLORS.get(family, Color.WHITE)
