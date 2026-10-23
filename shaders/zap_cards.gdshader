shader_type spatial;
// Разряд ART-068 у окна и у дна (docs/concept-art/razryad-korpus.md): карточки одним мешем, additive, без света и тумана.
// Вид карточки — COLOR.r (Zap.Card: 0 окно, 1 ветвь к дну, 2 искра касания). Числа и двойник огибающих — Zap.card_k.
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D arc_tex : hint_default_black, filter_linear, repeat_disable;
uniform float zap_t = -1.0;        // с после разряда (Zap.arc_time), −1 — нет
uniform float zap_dur = 0.8;       // Zap.FLICKER
uniform float zap_fps = 10.0;      // Zap.ARC_FPS
uniform float zap_flow = 12.0;     // Zap.ARC_FLOW: дуга у окна бежит к +X, м/с
uniform float window_gone = 0.22;  // Zap.WINDOW_GONE
uniform vec3 core_color : source_color = vec3(0.369, 0.949, 0.839);   // #5EF2D6
uniform vec3 halo_color : source_color = vec3(0.404, 0.867, 0.922);   // #67DDEB
uniform float core = 3.0;          // Zap.ARC_CORE

varying float kind;

void vertex() {
	kind = COLOR.r;
	if (kind < 0.5) {
		VERTEX.x += max(zap_t, 0.0) * zap_flow;
	}
}

void fragment() {
	float t = zap_t;
	float k;
	float a;
	if (kind > 1.5) {   // искра: ядро и три луча
		vec2 q = UV - vec2(0.5);
		float r2 = dot(q, q);
		a = exp(-r2 / 0.008) + pow(abs(cos(atan(q.y, q.x) * 3.0)), 24.0) * exp(-r2 / 0.05);
		k = smoothstep(0.12, 0.22, t) * (1.0 - smoothstep(0.4, zap_dur, t));
	} else {
		float fr = min(floor(max(t, 0.0) * zap_fps), 7.0);
		a = texture(arc_tex, (vec2(mod(fr, 4.0), floor(fr / 4.0)) + UV) / vec2(4.0, 2.0)).r;
		k = kind < 0.5 ? 1.0 - smoothstep(0.0, window_gone, t)
				: smoothstep(0.12, 0.28, t) * (1.0 - smoothstep(0.4, zap_dur, t));
	}
	k *= step(0.0, t) * (1.0 - step(zap_dur, t));
	ALBEDO = mix(halo_color, core_color, clamp(a, 0.0, 1.0)) * core * a * k;
	ALPHA = 1.0;
}
