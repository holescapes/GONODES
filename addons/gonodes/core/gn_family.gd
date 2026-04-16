class_name GNFamily
## Enum constants and runtime registry for operator families in GONODES.
##
## Core families are defined in the Type enum (values 0–11).
## Extensions can register additional families at runtime via register_family(),
## which assigns IDs starting at 1000.  All family APIs accept int, so core
## enum values and extension IDs are interchangeable.
##
## NOTE — Families vs Data/Port Types (Apr 2026 design discussion):
## A "family" is an operator classification (what an operator IS), while a
## "data type" (= port type) is what flows on wires (GNTextureData, etc.).
## Most families map 1:1 to a data type (TOP → GNTextureData, SDF → GNSDFData).
## COMP → GNCompData (wraps Node3D scene node), UI → GNUIData (wraps Control).
## Classification-only families have no wire data type:
##   OUT    — terminal sinks that consume other families' data
##   SCRIPT — user-authored nodes that produce other families' data
##
## The single source of truth is _data_factories: a family is data-carrying if
## and only if it has a registered factory.  Both core and extension families
## register through gn_core.cfg / gn_extension.cfg [family.*] sections,
## processed by GNExtensionRegistry._load_extension().  GNFamily is the sole
## authority on ID assignment: core names resolve to enum values via
## _CORE_FAMILY_IDS; unknown names get auto-assigned IDs >= 1000.
## No config file may specify an ID — it's always resolved by GNFamily.
##
## Two query methods reflect this:
##   get_all_families()  — every registered family (for filters like OPFindDAT)
##   get_data_families() — families with a _data_factories entry (for tunnel/port dropdowns)

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

## Authoritative mapping of core family names to their enum IDs.
## GNFamily is the sole authority on ID assignment — no config file may
## specify an ID.  Core names resolve here; everything else gets auto-assigned.
static var _CORE_FAMILY_IDS: Dictionary = {
	"TOP":    Type.TOP,
	"IMG":    Type.IMG,
	"CHOP":   Type.CHOP,
	"SOP":    Type.SOP,
	"POP":    Type.POP,
	"DAT":    Type.DAT,
	"MAT":    Type.MAT,
	"COMP":   Type.COMP,
	"VOL":    Type.VOL,
	"UI":     Type.UI,
	"OUT":    Type.OUT,
	"SCRIPT": Type.SCRIPT,
}

## Family display names for UI.  Populated at startup from gn_core.cfg
## (core families) and gn_extension.cfg (extension families) via the same
## _load_extension() path.  Empty until GNExtensionRegistry runs.
static var FAMILY_NAMES: Dictionary = {}

## Family colors for port/wire rendering in the graph editor.
## Populated at startup alongside FAMILY_NAMES.
static var FAMILY_COLORS: Dictionary = {}

## Data factory callbacks: family ID → Callable that returns a fresh GNData subclass.
## Populated at startup from the "data_script" key in [family.*] config sections.
## This dictionary is the single source of truth for "which families carry data"
## — get_data_families() and create_data_for_family() both derive from it.
static var _data_factories: Dictionary = {}

## Data renderer instances: family ID → GNDataRenderer subclass instance.
## Populated at startup from the "renderer_script" key in [family.*] config sections.
## Used by the viewer panel to dispatch rendering by data type rather than node type.
## Lives in the editor UI layer — never loaded by the cook engine or headless player.
static var _renderer_registry: Dictionary = {}

## Expression function registry: func name (e.g. "chop") → family ID.
## Populated from "expression_func" key in [family.*] config sections.
## Used by the cook engine to resolve family-typed expression proxies
## and by _EXPR_FUNC_TO_FAMILY for wireless demand tracking.
static var _expression_func_registry: Dictionary = {}


## Registers a family (core or extension) at runtime.
## GNFamily is the sole authority on ID assignment.  Core family names
## (TOP, CHOP, SOP, etc.) resolve to their enum values via _CORE_FAMILY_IDS.
## Unknown names are auto-assigned IDs >= 1000 in the extension range.
## Returns the assigned family ID.
static func register_family(family_name: String, color: Color) -> int:
	var upper := family_name.to_upper()
	# Already registered? Return existing ID.
	for key in FAMILY_NAMES:
		if FAMILY_NAMES[key] == upper:
			return key
	# Resolve ID: core families get their enum value, extensions get auto-assigned.
	var id: int
	if _CORE_FAMILY_IDS.has(upper):
		id = _CORE_FAMILY_IDS[upper]
	else:
		id = _next_ext_id
		_next_ext_id += 1
	FAMILY_NAMES[id] = upper
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


## Registers a data renderer instance for a family.
## Called by GNExtensionRegistry when loading [family.*] sections with renderer_script.
static func register_renderer(family_id: int, renderer: RefCounted) -> void:
	_renderer_registry[family_id] = renderer


## Returns the GNDataRenderer for the given family, or null if none registered.
static func get_renderer(family_id: int) -> RefCounted:
	return _renderer_registry.get(family_id, null)


## Registers an expression function name for a family.
## e.g. register_expression_func("chop", Type.CHOP) so users can write chop("lfo1", "out").
static func register_expression_func(func_name: String, family_id: int) -> void:
	_expression_func_registry[func_name] = family_id


## Returns the full expression function → family mapping (for cook engine).
static func get_expression_func_registry() -> Dictionary:
	return _expression_func_registry


## Returns all expression function names including variant suffixes
## (f, i, s) sorted by length descending.  Used by autocomplete
## to build regex alternation patterns that prefer longer matches first.
## Note: p/pf suffixes are deprecated — base functions now support port args.
static func get_expression_func_variants() -> Array[String]:
	var result: Array[String] = []
	for func_name: String in _expression_func_registry:
		result.append(func_name)
		for suffix in ["f", "i", "s"]:
			result.append(func_name + suffix)
	result.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return result


## Returns expression function names with value-type suffixes only (f, i, s)
## — same as get_expression_func_variants() now that p/pf are deprecated.
## Kept as a separate method for semantic clarity in autocomplete:
## second-arg context triggers data key/channel completions.
static func get_expression_func_value_variants() -> Array[String]:
	return get_expression_func_variants()


## Resolves a function name (possibly with a variant suffix like "chopf")
## to its registered family ID.  Returns -1 if not found.
static func resolve_expression_func_family(func_name: String) -> int:
	if _expression_func_registry.has(func_name):
		return _expression_func_registry[func_name]
	for suffix in ["f", "i", "s"]:
		if func_name.ends_with(suffix):
			var base := func_name.substr(0, func_name.length() - suffix.length())
			if _expression_func_registry.has(base):
				return _expression_func_registry[base]
	return -1


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


## Returns all registered families as two parallel arrays:
## [param ids] sorted (core 0–11 first, then extensions 1000+) and
## [param names] with matching display strings.
## Optionally pass [param exclude] to skip specific family IDs.
## Use for dropdowns that need every family (e.g. OPFindDAT filter).
static func get_all_families(exclude: Array[int] = []) -> Array:
	var ids: Array[int] = []
	for key in FAMILY_NAMES:
		if key in exclude:
			continue
		ids.append(key)
	ids.sort()
	var names := PackedStringArray()
	for fid in ids:
		names.append(FAMILY_NAMES[fid])
	return [ids, names]


## Returns only families that carry data on wires — suitable for port/tunnel
## type dropdowns.  Derived from _data_factories: a family is a "data family"
## if and only if it has a registered factory (has data_script in config).
## Currently excludes only OUT and SCRIPT (classification-only, no data_script).
static func get_data_families() -> Array:
	var ids: Array[int] = []
	for fid in _data_factories:
		if FAMILY_NAMES.has(fid):
			ids.append(fid)
	ids.sort()
	var names := PackedStringArray()
	for fid in ids:
		names.append(FAMILY_NAMES[fid])
	return [ids, names]
