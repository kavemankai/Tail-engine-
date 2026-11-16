// Additive holographic projection (Booth 7 data display).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D holo_texture : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.35, 0.85, 1.0);
uniform float energy = 1.4;
uniform float rotate_speed = 0.15;
uniform bool animated = true;
instance uniform float power = 1.0;

void vertex() {
	// cylindrical (Y-axis) billboard so the display always reads correctly
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = animated ? TIME : 0.0;
	vec2 p = UV - 0.5;
	float a = t * rotate_speed;
	p = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * p;
	vec3 c = texture(holo_texture, p + 0.5).rgb;
	float scan = 0.75 + 0.25 * sin(UV.y * 300.0 - t * 6.0);
	float edge = 1.0 - smoothstep(0.42, 0.5, length(UV - 0.5));
	float jitter = animated ? 0.92 + 0.08 * sin(t * 37.0) * sin(t * 11.0) : 1.0;
	ALBEDO = c * tint * energy * scan * edge * jitter * power;
}
