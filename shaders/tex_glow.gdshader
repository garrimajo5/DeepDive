// Модель художника, у которой светятся голубые места текстуры (#67DDEB): огни голостола, кнопки пультов, рамка сканера.
// Маска — по оттенку исходного цвета текстуры (как в texture_glow.gd, там же числа): голубой, насыщенный и яркий.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;   // та же текстура без перевода в линейный цвет — для маски
uniform float glow_energy = 2.2;
uniform float hue_min = 0.45;
uniform float hue_max = 0.56;
uniform float sat_min = 0.4;
uniform float val_min = 0.55;
uniform float roughness = 0.75;
uniform float metallic = 0.2;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float glow_mask(vec3 srgb) {
	vec3 hsv = rgb2hsv(srgb);
	float h = smoothstep(hue_min - 0.02, hue_min, hsv.x) * (1.0 - smoothstep(hue_max, hue_max + 0.02, hsv.x));
	float s = smoothstep(sat_min - 0.08, sat_min, hsv.y);
	float v = smoothstep(val_min - 0.08, val_min, hsv.z);
	return h * s * v;
}

void fragment() {
	vec3 lin = texture(albedo_tex, UV).rgb;
	vec3 srgb = texture(mask_tex, UV).rgb;   // значения как в PNG — маска совпадает с TextureGlow.glows
	ALBEDO = lin;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = lin * glow_mask(srgb) * glow_energy;
}
