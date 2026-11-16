// Emissive neon tube sign. Texture is the lit tube + halo on black (additive).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D sign_texture : source_color, filter_linear_mipmap;
uniform float energy = 2.2;
instance uniform float flicker = 1.0;

void fragment() {
	vec3 c = texture(sign_texture, UV).rgb;
	ALBEDO = c * energy * flicker;
}
