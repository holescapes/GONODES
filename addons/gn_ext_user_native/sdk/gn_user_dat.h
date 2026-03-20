#ifndef GN_USER_DAT_H
#define GN_USER_DAT_H

/// GONODES User Native SDK — DAT (Table/Text) Helpers
///
/// # Return Dictionary Format (Table mode)
///
///   Dictionary result;
///   result["headers"] = PackedStringArray({"col1", "col2", "col3"});
///   Array rows;
///   rows.push_back(PackedStringArray({"a", "b", "c"}));
///   rows.push_back(PackedStringArray({"d", "e", "f"}));
///   result["rows"] = rows;
///   return result;
///
/// # Return Dictionary Format (Text mode)
///
///   Dictionary result;
///   result["text"] = String("Hello, world!");
///   return result;

#include "gn_user_node.h"

namespace gn {

/// Helper: build a DAT table result from headers and rows.
inline godot::Dictionary make_dat_table(
		const PackedStringArray &headers,
		const godot::Array &rows) {
	godot::Dictionary result;
	result["headers"] = headers;
	result["rows"] = rows;
	return result;
}

/// Helper: build a DAT text result.
inline godot::Dictionary make_dat_text(const godot::String &text) {
	godot::Dictionary result;
	result["text"] = text;
	return result;
}

/// Helper: get input DAT as headers + rows. Returns false if input is null/invalid.
inline bool get_input_table(const godot::Array &inputs, int index,
		PackedStringArray &out_headers, godot::Array &out_rows) {
	if (index >= inputs.size() || inputs[index].get_type() == godot::Variant::NIL)
		return false;
	godot::Dictionary data = inputs[index];
	if (data.has("headers")) out_headers = data["headers"];
	if (data.has("rows")) out_rows = data["rows"];
	return true;
}

/// Helper: get input DAT as text string.
inline godot::String get_input_text(const godot::Array &inputs, int index,
		const godot::String &fallback = "") {
	if (index >= inputs.size() || inputs[index].get_type() == godot::Variant::NIL)
		return fallback;
	godot::Dictionary data = inputs[index];
	if (data.has("text")) return data["text"];
	return fallback;
}

} // namespace gn

#endif // GN_USER_DAT_H
