#ifndef GN_USER_NODE_H
#define GN_USER_NODE_H

/// GONODES User Native SDK — Base Node
///
/// All user C++ operators extend GNUserNode (or a family-specific subclass).
/// The GDScript wrapper calls into this class via ClassDB bindings.
///
/// # Lifecycle
///
///   1. GONODES instantiates via ClassDB::instantiate("YourClassName")
///   2. setup() is called once after instantiation
///   3. cook() is called each frame the node is dirty
///   4. On hot-reload: old instance is freed, new one created, setup() called again
///
/// # Threading Safety
///
///   cook() may run on a WorkerThreadPool thread. You MUST NOT call:
///     - RenderingServer methods
///     - DisplayServer methods
///     - AudioServer methods
///     - Any singleton that isn't thread-safe
///
///   You CAN safely use:
///     - SurfaceTool, ArrayMesh (construction)
///     - Image (create, get/set pixel, resize)
///     - PackedFloat32Array, PackedVector3Array, etc.
///     - All math types (Vector2/3/4, Color, Transform3D, etc.)
///     - Standard C/C++ math and data structures
///

#include "gn_user_types.h"

#include <godot_cpp/core/class_db.hpp>

namespace gn {

/// Base class for all user-written C++ GONODES operators.
/// Subclasses override cook() to implement processing logic.
class GNUserNode : public godot::RefCounted {
	GDCLASS(GNUserNode, godot::RefCounted)

protected:
	static void _bind_methods() {
		using namespace godot;
		ClassDB::bind_method(D_METHOD("get_node_type"), &GNUserNode::get_node_type);
		ClassDB::bind_method(D_METHOD("get_node_description"), &GNUserNode::get_node_description);
		ClassDB::bind_method(D_METHOD("get_port_definitions"), &GNUserNode::get_port_definitions);
		ClassDB::bind_method(D_METHOD("get_param_definitions"), &GNUserNode::get_param_definitions);
		ClassDB::bind_method(D_METHOD("native_setup"), &GNUserNode::native_setup);
		ClassDB::bind_method(D_METHOD("native_cook", "params", "inputs", "context"), &GNUserNode::native_cook);
	}

public:
	virtual ~GNUserNode() = default;

	// ── Identity (override these) ────────────────────────────────

	/// Return a short identifier for this node type (e.g., "wave_deform").
	/// Used as the node_type in GONODES.
	virtual godot::String get_node_type() const { return "user_native"; }

	/// Human-readable description shown in the palette and inspector.
	virtual godot::String get_node_description() const { return "User C++ operator."; }

	// ── Port & Parameter Definitions (override these) ────────────

	/// Return an Array of Dictionaries defining input/output ports.
	/// Each dict: {"name": String, "family": String, "direction": String, "required": bool, "label": String}
	///   direction: "input" or "output"
	///   family: "SOP", "CHOP", "TOP", "IMG", "DAT", "MAT", "POP", "VOL"
	///
	/// Example:
	///   Array ports;
	///   Dictionary p;
	///   p["name"] = "in"; p["family"] = "SOP"; p["direction"] = "input";
	///   p["required"] = true; p["label"] = "Source geometry";
	///   ports.push_back(p);
	///   return ports;
	virtual godot::Array get_port_definitions() const { return godot::Array(); }

	/// Return an Array of Dictionaries defining parameters.
	/// Each dict: {"name": String, "type": String, "default": Variant,
	///             "min": Variant, "max": Variant, "step": Variant,
	///             "label": String, "description": String}
	///   type: "float", "int", "bool", "string", "enum", "color",
	///         "vector2", "vector2i", "vector3", "vector4", "file"
	///   For enum: add "options": PackedStringArray(["A", "B", "C"])
	///
	/// Example:
	///   Array params;
	///   Dictionary p;
	///   p["name"] = "amplitude"; p["type"] = "float";
	///   p["default"] = 1.0; p["min"] = 0.0; p["max"] = 10.0; p["step"] = 0.01;
	///   p["label"] = "Amplitude"; p["description"] = "Wave height";
	///   params.push_back(p);
	///   return params;
	virtual godot::Array get_param_definitions() const { return godot::Array(); }

	// ── Lifecycle ────────────────────────────────────────────────

	/// Called once after instantiation (and after hot-reload).
	/// Use for allocating internal state, lookup tables, etc.
	/// @param context  Dictionary with: "project_dir": String
	virtual void native_setup(const godot::Dictionary &context) {}

	/// Called each frame the node is dirty.
	/// @param params   Dictionary of resolved parameter values: {"name": Variant, ...}
	/// @param inputs   Array of input data objects (GNGeoData, GNChannelData, etc.)
	///                 Null entries for disconnected optional inputs.
	/// @param context  Dictionary with: "delta": float, "elapsed": float,
	///                 "frame": int, "sample_rate": float
	/// @return         Output data (Dictionary with result fields), or empty Dictionary on failure.
	///                 The GDScript wrapper interprets the returned Dictionary based on family.
	virtual godot::Dictionary native_cook(const godot::Dictionary &params,
	                                       const godot::Array &inputs,
	                                       const godot::Dictionary &context) {
		return godot::Dictionary();
	}

	// ── Convenience Helpers ──────────────────────────────────────

	/// Get a float parameter value from the params dictionary.
	static double parf(const godot::Dictionary &params, const godot::String &name, double fallback = 0.0) {
		if (params.has(name)) return (double)params[name];
		return fallback;
	}

	/// Get an int parameter value from the params dictionary.
	static int64_t pari(const godot::Dictionary &params, const godot::String &name, int64_t fallback = 0) {
		if (params.has(name)) return (int64_t)params[name];
		return fallback;
	}

	/// Get a bool parameter value from the params dictionary.
	static bool parb(const godot::Dictionary &params, const godot::String &name, bool fallback = false) {
		if (params.has(name)) return (bool)params[name];
		return fallback;
	}

	/// Get a String parameter value from the params dictionary.
	static godot::String pars(const godot::Dictionary &params, const godot::String &name, const godot::String &fallback = "") {
		if (params.has(name)) return (godot::String)params[name];
		return fallback;
	}

	/// Get a Color parameter value from the params dictionary.
	static godot::Color parc(const godot::Dictionary &params, const godot::String &name, const godot::Color &fallback = godot::Color(1, 1, 1, 1)) {
		if (params.has(name)) return (godot::Color)params[name];
		return fallback;
	}

	/// Get a Vector3 parameter value from the params dictionary.
	static godot::Vector3 parv3(const godot::Dictionary &params, const godot::String &name, const godot::Vector3 &fallback = godot::Vector3()) {
		if (params.has(name)) return (godot::Vector3)params[name];
		return fallback;
	}
};

} // namespace gn

#endif // GN_USER_NODE_H
