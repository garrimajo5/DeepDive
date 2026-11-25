// Модель художника, у которой светятся голубые места текстуры (#67DDEB): огни голостола, кнопки пультов, рамка сканера.
// Маска — по оттенку исходного цвета текстуры (как в texture_glow.gd, там же числа): голубой, насыщенный и яркий.
// Пульт энергии MOD-005 (#2102): светящаяся часть полосы в пазе равна доле системы — level_k=1 и levels[5]
// (окно полос STRIP_Y, колонки по x — как BridgeProps.SLIDER_X / STRIP_Y / STRIP_HALF; у других моделей level_k=0).
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
uniform float level_k = 0.0;   // 1 — пульт энергии: полосы в пазах светятся до доли systems
uniform float levels[5];       // доля каждого паза 0…1 (порядок BridgeProps.SLIDER_X)

varying vec3 local_pos;

const float STRIP_X[5] = {0.3165, 0.1695, 0.0, -0.1695, -0.3155};   // = BridgeProps.STRIP_X
const vec2 STRIP_Y = vec2(0.705, 1.13);                            // = BridgeProps.STRIP_Y
const float STRIP_HALF = 0.022;                                    // = BridgeProps.STRIP_HALF
const float EDGE = 0.008;   // мягкий край среза свечения, м

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

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 lin = texture(albedo_tex, UV).rgb;
	vec3 srgb = texture(mask_tex, UV).rgb;   // значения как в PNG — маска совпадает с TextureGlow.glows
	ALBEDO = lin;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	float em_k = 1.0;
	if (level_k > 0.5) {   // пульт энергии: светящаяся часть полосы — до высоты доли (#2102)
		for (int i = 0; i < 5; i++) {
			if (abs(local_pos.x - STRIP_X[i]) < STRIP_HALF && local_pos.y > STRIP_Y.x - 0.02 && local_pos.y < STRIP_Y.y + 0.02) {
				float ycut = mix(STRIP_Y.x, STRIP_Y.y, clamp(levels[i], 0.0, 1.0));
				em_k = 1.0 - smoothstep(ycut - EDGE, ycut + EDGE, local_pos.y);
			}
		}
	}
	EMISSION = lin * glow_mask(srgb) * glow_energy * em_k;
}
