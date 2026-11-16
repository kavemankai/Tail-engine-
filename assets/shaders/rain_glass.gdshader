// Rain-streaked window glass: refracts and slightly blurs what is behind it,
// static droplets plus running streaks. Set rain_enabled = 0 to freeze/clear.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D drops_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.62, 0.72, 0.85);
uniform vec2 tiling = vec2(2.0, 1.4);
uniform float refraction = 0.018;
uniform float blur_lod = 0.5;
uniform float rain_speed = 0.22;
uniform float rain_enabled = 1.0;

vec3 unpack(vec3 n) { return n * 2.0 - 1.0; }

void fragment() {
	vec2 uv = UV * tiling;
	vec3 n_static = unpack(texture(drops_normal, uv).rgb);
	float t = TIME * rain_speed * rain_enabled;
	// three columns layers of falling streak drops with per-column speed
	float lanes = 18.0;
	float lane = floor(uv.x * lanes);
	float rnd = fract(sin(lane * 127.1) * 43758.5453);
	vec2 suv = vec2(uv.x * 1.7, uv.y * 0.35 + t * (0.6 + rnd));
	vec3 n_run = unpack(texture(drops_normal, suv + vec2(rnd, 0.0)).rgb);
	vec3 n = normalize(vec3(n_static.xy + n_run.xy * rain_enabled, 1.0));
	vec2 off = n.xy * refraction;
	vec3 bg = textureLod(screen_tex, SCREEN_UV + off, blur_lod).rgb;
	ALBEDO = vec3(0.0);
	EMISSION = bg * tint;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	METALLIC = 0.0;
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.6;
	ALPHA = 1.0;
}
