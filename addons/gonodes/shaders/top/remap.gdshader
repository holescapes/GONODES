shader_type canvas_item;
// RemapTOP — remap pixel values using a UV displacement map.
// Uses texture B's red and green channels as UV coordinates to sample texture A.

uniform sampler2D source_tex : hint_default_white;
uniform sampler2D map_tex : hint_default_white;
uniform float strength = 1.0;
uniform int remap_mode : hint_range(0, 1) = 0; // 0=UV Remap, 1=Value Remap (LUT)

void fragment() {
	if (remap_mode == 0) {
		// UV Remap — use map RG as UV coordinates
		vec4 map_val = texture(map_tex, UV);
		vec2 remap_uv = mix(UV, map_val.rg, strength);
		COLOR = texture(source_tex, remap_uv);
	} else {
		// Value Remap — use source luminance as index into map
		vec4 col = texture(source_tex, UV);
		float lum = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
		vec4 remapped = texture(map_tex, vec2(clamp(lum, 0.0, 1.0), 0.5));
		COLOR = vec4(mix(col.rgb, remapped.rgb, strength), col.a);
	}
}
