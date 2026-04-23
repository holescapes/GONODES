#ifndef GN_USER_TYPES_H
#define GN_USER_TYPES_H

/// GONODES User Native SDK — Common Types
/// This header provides convenient aliases for Godot types used in user C++ operators.

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/surface_tool.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <cmath>

namespace gn {

using godot::Ref;
using godot::RefCounted;
using godot::Image;
using godot::ArrayMesh;
using godot::SurfaceTool;
using godot::ShaderMaterial;
using godot::PackedFloat32Array;
using godot::PackedVector3Array;
using godot::PackedVector2Array;
using godot::PackedColorArray;
using godot::PackedStringArray;
using godot::PackedInt32Array;
using godot::Vector2;
using godot::Vector2i;
using godot::Vector3;
using godot::Vector4;
using godot::Color;
using godot::String;
using godot::Dictionary;
using godot::Array;
using godot::Variant;

} // namespace gn


// ── Param Definition Factory Helpers ─────────────────────────────
// Use these in get_param_definitions() to build param dicts concisely.
// They live in the gn namespace for clean syntax: gn::parf("name", ...)

namespace gn {

/// Create a float param definition.
inline Dictionary make_float(const String &name, double def, double lo, double hi, double step,
                              const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "float"; p["default"] = def;
	p["min"] = lo; p["max"] = hi; p["step"] = step;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}
/// Shorthand alias.
inline Dictionary parf(const String &name, double def, double lo, double hi, double step,
                        const String &label = "", const String &desc = "") {
	return make_float(name, def, lo, hi, step, label, desc);
}

/// Create an int param definition.
inline Dictionary make_int(const String &name, int64_t def, int64_t lo, int64_t hi,
                            const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "int"; p["default"] = def;
	p["min"] = lo; p["max"] = hi;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}
inline Dictionary pari(const String &name, int64_t def, int64_t lo, int64_t hi,
                        const String &label = "", const String &desc = "") {
	return make_int(name, def, lo, hi, label, desc);
}

/// Create a bool param definition.
inline Dictionary make_bool(const String &name, bool def,
                             const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "bool"; p["default"] = def;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}
inline Dictionary parb(const String &name, bool def,
                        const String &label = "", const String &desc = "") {
	return make_bool(name, def, label, desc);
}

/// Create a string param definition.
inline Dictionary make_string(const String &name, const String &def = "",
                               const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "string"; p["default"] = def;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}

/// Create a color param definition.
inline Dictionary make_color(const String &name, const Color &def = Color(1, 1, 1, 1),
                              const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "color"; p["default"] = def;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}
inline Dictionary parc(const String &name, const Color &def = Color(1, 1, 1, 1),
                        const String &label = "", const String &desc = "") {
	return make_color(name, def, label, desc);
}

/// Create an enum param definition.
inline Dictionary make_enum(const String &name, const PackedStringArray &options, int64_t def = 0,
                             const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "enum"; p["default"] = def;
	p["options"] = options; 
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}
inline Dictionary pare(const String &name, const PackedStringArray &options, int64_t def = 0,
                        const String &label = "", const String &desc = "") {
	return make_enum(name, options, def, label, desc);
}

/// Create a vector2 param definition.
inline Dictionary make_vector2(const String &name, const Vector2 &def = Vector2(),
                                const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "vector2"; p["default"] = def;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}

/// Create a vector3 param definition.
/// Note: The GDScript wrapper splits this into three float params (name_x, name_y, name_z)
/// and reassembles them into a Vector3 before passing to native_cook(). Use parv3() to read.
inline Dictionary make_vector3(const String &name, const Vector3 &def = Vector3(),
                                double lo = -100.0, double hi = 100.0, double step = 0.01,
                                const String &label = "", const String &desc = "") {
	Dictionary p;
	p["name"] = name; p["type"] = "vector3"; p["default"] = def;
	p["min"] = lo; p["max"] = hi; p["step"] = step;
	p["label"] = label.is_empty() ? name : label; p["description"] = desc;
	return p;
}

// ─── Multi-Output ─────────────────────────────────────────────────────────────

/// Wraps an array of per-port result dictionaries into the multi-output
/// protocol format.  Each element should be a result from make_chop_result(),
/// make_dat_table(), make_sop_result(), make_img_result(), etc.
///
/// Example:
///   Dictionary chop = gn::make_chop_result(channels);
///   Dictionary dat  = gn::make_dat_table(headers, rows);
///   return gn::make_multi_output({chop, dat});
inline Dictionary make_multi_output(const Array &outputs) {
	Dictionary result;
	result["outputs"] = outputs;
	return result;
}

} // namespace gn

#endif // GN_USER_TYPES_H
