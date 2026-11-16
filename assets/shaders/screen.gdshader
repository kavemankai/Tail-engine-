// Lit glossy display panel with scrolling emissive content and scanlines.
shader_type spatial;
render_mode cull_back;

uniform sampler2D content : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 scroll_speed = vec2(0.0, 0.02);
uniform float energy = 1.6;
uniform float scanline_strength = 0.18;
uniform float scanline_count = 220.0;
uniform bool animated = true;
instance uniform float power = 1.0;
instance uniform float flicker = 1.0;

void fragment() {
	float t = animated ? TIME : 0.0;
	vec2 uv = UV + scroll_speed * t;
	vec3 c = texture(content, uv).rgb;
	float scan = 1.0 - scanline_strength * (0.5 + 0.5 * sin((UV.y + t * 0.05) * scanline_count * 6.2831));
	float vign = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x) * smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.08, 1.0 - UV.y);
	float roll = animated ? 0.94 + 0.06 * sin(t * 1.3 + UV.y * 3.0) : 1.0;
	ALBEDO = vec3(0.01);
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	EMISSION = c * energy * scan * mix(0.6, 1.0, vign) * roll * power * flicker;
}
