#ifndef GN_USER_CHOP_H
#define GN_USER_CHOP_H

/// GONODES User Native SDK — CHOP (Channel) Helpers
///
/// # Return Dictionary Format
///
///   Dictionary result;
///   result["channels"] = Dictionary();  // {"chan_name": PackedFloat32Array, ...}
///   result["sample_rate"] = 60.0;       // optional, default = engine sample rate
///   return result;
///
/// For single-value channels (most common), use make_chop_single().
/// For multi-sample channels, pass full PackedFloat32Array per channel.

#include "gn_user_node.h"

namespace gn {

/// Helper: build a CHOP result with a single named channel.
/// @param name    Channel name (e.g., "value")
/// @param values  Sample array for that channel
inline godot::Dictionary make_chop_single(
		const godot::String &name,
		const PackedFloat32Array &values) {
	godot::Dictionary channels;
	channels[name] = values;
	godot::Dictionary result;
	result["channels"] = channels;
	return result;
}

/// Helper: build a CHOP result with single-value channels.
/// @param names   Channel names (e.g., {"tx", "ty", "tz"})
/// @param values  Corresponding values
inline godot::Dictionary make_chop_single(
		const PackedStringArray &names,
		const PackedFloat32Array &values) {
	godot::Dictionary channels;
	int count = std::min((int)names.size(), (int)values.size());
	for (int i = 0; i < count; i++) {
		PackedFloat32Array arr;
		arr.push_back(values[i]);
		channels[names[i]] = arr;
	}
	godot::Dictionary result;
	result["channels"] = channels;
	return result;
}

/// Helper: build a CHOP result from a Dictionary of name → PackedFloat32Array.
inline godot::Dictionary make_chop_result(
		const godot::Dictionary &channels,
		double sample_rate = 0.0) {
	godot::Dictionary result;
	result["channels"] = channels;
	if (sample_rate > 0.0) result["sample_rate"] = sample_rate;
	return result;
}

/// Helper: get input CHOP channel as a PackedFloat32Array, or empty if missing.
inline PackedFloat32Array get_input_channel(
		const godot::Array &inputs, int input_index,
		const godot::String &channel_name) {
	if (input_index >= inputs.size() || inputs[input_index].get_type() == godot::Variant::NIL)
		return PackedFloat32Array();
	godot::Dictionary data = inputs[input_index];
	if (!data.has("channels")) return PackedFloat32Array();
	godot::Dictionary channels = data["channels"];
	if (!channels.has(channel_name)) return PackedFloat32Array();
	return channels[channel_name];
}

/// Helper: get the last value of an input CHOP channel (single-value shorthand).
inline float get_input_value(
		const godot::Array &inputs, int input_index,
		const godot::String &channel_name, float fallback = 0.0f) {
	PackedFloat32Array arr = get_input_channel(inputs, input_index, channel_name);
	if (arr.size() == 0) return fallback;
	return arr[arr.size() - 1];
}

} // namespace gn

#endif // GN_USER_CHOP_H
