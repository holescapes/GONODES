#ifndef GN_USER_SDF_H
#define GN_USER_SDF_H

/// GONODES User Native SDK — SDF (Signed Distance Field) Helpers
///
/// # SDF Data Model
///
///   SDF operators pass an **AST** (Abstract Syntax Tree) between each other.
///   Each node in the tree is a Dictionary:
///
///   {
///       "op":       String,     // "sphere", "box", "union", "twist", etc.
///       "params":   Dictionary, // op-specific parameters
///       "children": Array,      // child SDF tree nodes (for booleans/modifiers)
///       "material": Dictionary  // optional PBR material properties
///   }
///
///   The final RaymarchSDF operator compiles this AST into GLSL for rendering.
///
/// # Return Dictionary Format
///
///   Dictionary result;
///   result["sdf_tree"]  = Dictionary();  // the SDF AST
///   result["tree_hash"] = int64_t(hash); // optional change-detection hash
///   return result;
///
/// # Available Primitive ops:
///   "sphere", "box", "torus", "cylinder", "capsule", "plane", "cone",
///   "pyramid", "octahedron", "gyroid"
///
/// # Available Boolean ops:
///   "union", "intersection", "subtract", "smooth_union", "smooth_subtract"
///   Boolean ops expect 2 children in the "children" array.
///   Smooth variants accept "smoothness" in params.
///
/// # Available Domain Modifier ops:
///   "repeat", "mirror", "twist", "bend", "elongate", "round", "onion",
///   "displace"
///   Modifiers expect 1 child in the "children" array.
///
/// # Material Dictionary (optional):
///   { "albedo": Color, "roughness": float, "metallic": float,
///     "emission": float }

#include "gn_user_node.h"

namespace gn {

// ─── Tree Construction ───────────────────────────────────────────────────────

/// Build an SDF tree node.
/// @param op       Operator name (e.g. "sphere", "union", "twist")
/// @param params   Op-specific parameters
/// @param children Child SDF tree nodes (empty for primitives)
/// @param material Optional PBR material properties
inline godot::Dictionary make_sdf_node(
		const godot::String &op,
		const godot::Dictionary &params,
		const godot::Array &children = godot::Array(),
		const godot::Dictionary &material = godot::Dictionary()) {
	godot::Dictionary node;
	node["op"] = op;
	node["params"] = params;
	node["children"] = children;
	if (!material.is_empty()) node["material"] = material;
	return node;
}

/// Build a result dictionary from an SDF tree node.
inline godot::Dictionary make_sdf_result(const godot::Dictionary &sdf_tree) {
	godot::Dictionary result;
	result["sdf_tree"] = sdf_tree;
	// Compute a simple change-detection hash
	result["tree_hash"] = sdf_tree.hash();
	return result;
}

// ─── Primitive Helpers ───────────────────────────────────────────────────────

/// Sphere primitive.
inline godot::Dictionary sdf_sphere(float radius = 1.0f,
		const godot::Vector3 &position = godot::Vector3()) {
	godot::Dictionary p;
	p["radius"] = radius;
	p["position"] = position;
	return make_sdf_node("sphere", p);
}

/// Box primitive.
inline godot::Dictionary sdf_box(const godot::Vector3 &size = godot::Vector3(1, 1, 1),
		const godot::Vector3 &position = godot::Vector3()) {
	godot::Dictionary p;
	p["size"] = size;
	p["position"] = position;
	return make_sdf_node("box", p);
}

/// Torus primitive.
inline godot::Dictionary sdf_torus(float major_radius = 1.0f, float minor_radius = 0.3f,
		const godot::Vector3 &position = godot::Vector3()) {
	godot::Dictionary p;
	p["major_radius"] = major_radius;
	p["minor_radius"] = minor_radius;
	p["position"] = position;
	return make_sdf_node("torus", p);
}

/// Cylinder primitive.
inline godot::Dictionary sdf_cylinder(float radius = 0.5f, float height = 2.0f,
		const godot::Vector3 &position = godot::Vector3()) {
	godot::Dictionary p;
	p["radius"] = radius;
	p["height"] = height;
	p["position"] = position;
	return make_sdf_node("cylinder", p);
}

// ─── Boolean Helpers ─────────────────────────────────────────────────────────

/// Union of two SDF trees.
inline godot::Dictionary sdf_union(const godot::Dictionary &a, const godot::Dictionary &b) {
	godot::Array children;
	children.push_back(a);
	children.push_back(b);
	return make_sdf_node("union", godot::Dictionary(), children);
}

/// Smooth union of two SDF trees.
inline godot::Dictionary sdf_smooth_union(const godot::Dictionary &a,
		const godot::Dictionary &b, float smoothness = 0.5f) {
	godot::Dictionary p;
	p["smoothness"] = smoothness;
	godot::Array children;
	children.push_back(a);
	children.push_back(b);
	return make_sdf_node("smooth_union", p, children);
}

/// Subtraction: a minus b.
inline godot::Dictionary sdf_subtract(const godot::Dictionary &a, const godot::Dictionary &b) {
	godot::Array children;
	children.push_back(a);
	children.push_back(b);
	return make_sdf_node("subtract", godot::Dictionary(), children);
}

/// Intersection of two SDF trees.
inline godot::Dictionary sdf_intersection(const godot::Dictionary &a,
		const godot::Dictionary &b) {
	godot::Array children;
	children.push_back(a);
	children.push_back(b);
	return make_sdf_node("intersection", godot::Dictionary(), children);
}

// ─── Modifier Helpers ────────────────────────────────────────────────────────

/// Apply twist modifier around Y axis.
inline godot::Dictionary sdf_twist(const godot::Dictionary &child, float amount = 1.0f) {
	godot::Dictionary p;
	p["amount"] = amount;
	godot::Array children;
	children.push_back(child);
	return make_sdf_node("twist", p, children);
}

/// Repeat in 3D space.
inline godot::Dictionary sdf_repeat(const godot::Dictionary &child,
		const godot::Vector3 &spacing = godot::Vector3(3, 3, 3)) {
	godot::Dictionary p;
	p["spacing"] = spacing;
	godot::Array children;
	children.push_back(child);
	return make_sdf_node("repeat", p, children);
}

/// Mirror across axes.
inline godot::Dictionary sdf_mirror(const godot::Dictionary &child,
		bool x = true, bool y = false, bool z = false) {
	godot::Dictionary p;
	p["mirror_x"] = x;
	p["mirror_y"] = y;
	p["mirror_z"] = z;
	godot::Array children;
	children.push_back(child);
	return make_sdf_node("mirror", p, children);
}

/// Round edges (shell operation).
inline godot::Dictionary sdf_round(const godot::Dictionary &child, float radius = 0.1f) {
	godot::Dictionary p;
	p["radius"] = radius;
	godot::Array children;
	children.push_back(child);
	return make_sdf_node("round", p, children);
}

// ─── Material Helpers ────────────────────────────────────────────────────────

/// Apply material properties to an SDF tree node.
inline godot::Dictionary sdf_material(const godot::Dictionary &child,
		const godot::Color &albedo = godot::Color(0.8f, 0.8f, 0.8f, 1.0f),
		float roughness = 0.5f, float metallic = 0.0f, float emission = 0.0f) {
	godot::Dictionary mat;
	mat["albedo"] = albedo;
	mat["roughness"] = roughness;
	mat["metallic"] = metallic;
	mat["emission"] = emission;
	// Deep-copy child and add material
	godot::Dictionary result = child.duplicate(true);
	result["material"] = mat;
	return result;
}

// ─── Input Helpers ───────────────────────────────────────────────────────────

/// Extract an input SDF tree Dictionary, or empty dict if not available.
inline godot::Dictionary get_input_sdf(const godot::Array &inputs, int input_index) {
	if (input_index >= inputs.size() || inputs[input_index].get_type() == godot::Variant::NIL)
		return godot::Dictionary();
	godot::Dictionary data = inputs[input_index];
	if (!data.has("sdf_tree")) return godot::Dictionary();
	return data["sdf_tree"];
}

/// Check whether an input SDF is connected and non-empty.
inline bool has_input_sdf(const godot::Array &inputs, int input_index) {
	return !get_input_sdf(inputs, input_index).is_empty();
}

} // namespace gn

#endif // GN_USER_SDF_H
