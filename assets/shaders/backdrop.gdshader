// Unlit exterior city backdrop seen through the windows, with faint twinkle.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform sampler2D city : source_color, filter_linear_mipmap;
uniform float energy = 1.1;
uniform bool animated = true;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(city, UV).rgb;
	float tw = 1.0;
	if (animated) {
		vec2 cell = floor(UV * vec2(160.0, 80.0));
		float h = hash(cell);
		tw = 0.85 + 0.15 * sin(TIME * (0.5 + h * 2.0) + h * 40.0);
	}
	ALBEDO = c * energy * tw;
}
