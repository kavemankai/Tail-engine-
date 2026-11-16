// Back-bar light box: diffused panel glowing from below (unshaded, no lighting dependency).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D panel : source_color, filter_linear_mipmap;
uniform float energy = 0.7;
instance uniform float flicker = 1.0;

void fragment() {
	ALBEDO = texture(panel, UV).rgb * energy * flicker;
}
