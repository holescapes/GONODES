#ifndef GN_USER_SOP_H
#define GN_USER_SOP_H

/// GONODES User Native SDK — SOP (Geometry) Helpers
///
/// Provides convenience methods for building geometry output from cook().
///
/// # Return Dictionary Format
///
///   Dictionary result;
///   result["positions"] = PackedVector3Array(...);   // REQUIRED
///   result["normals"]   = PackedVector3Array(...);   // optional
///   result["uvs"]       = PackedVector2Array(...);   // optional
///   result["colors"]    = PackedColorArray(...);     // optional
///   result["indices"]   = PackedInt32Array(...);     // optional (triangle indices)
///   result["primitive"] = 3;                         // optional: Mesh::PrimitiveType (3=triangles, 0=points)
///   return result;
///
/// If "indices" is omitted, the mesh is built as an unindexed triangle list.
/// If "primitive" is 0 (PRIMITIVE_POINTS), only "positions" is required.

#include "gn_user_node.h"

namespace gn {

/// Helper: build a SOP result dictionary from raw arrays.
inline godot::Dictionary make_sop_result(
		const PackedVector3Array &positions,
		const PackedVector3Array &normals = PackedVector3Array(),
		const PackedVector2Array &uvs = PackedVector2Array(),
		const PackedColorArray &colors = PackedColorArray(),
		const PackedInt32Array &indices = PackedInt32Array(),
		int primitive = 3 /* Mesh::PRIMITIVE_TRIANGLES */) {
	godot::Dictionary result;
	result["positions"] = positions;
	if (normals.size() > 0) result["normals"] = normals;
	if (uvs.size() > 0) result["uvs"] = uvs;
	if (colors.size() > 0) result["colors"] = colors;
	if (indices.size() > 0) result["indices"] = indices;
	result["primitive"] = primitive;
	return result;
}

/// Helper: build a point cloud SOP result (PRIMITIVE_POINTS).
inline godot::Dictionary make_point_cloud(
		const PackedVector3Array &positions,
		const PackedColorArray &colors = PackedColorArray()) {
	godot::Dictionary result;
	result["positions"] = positions;
	if (colors.size() > 0) result["colors"] = colors;
	result["primitive"] = 0; // Mesh::PRIMITIVE_POINTS
	return result;
}

} // namespace gn

#endif // GN_USER_SOP_H
