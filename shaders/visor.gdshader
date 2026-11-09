// Щиток сварщика (`Breach.VISOR`, ART-014): экран затемнён цветом тени, но яркое — искры ART-072, вспышка электрода,
// раскалённый шов — проходит без тона и затемнения (по issue #530). Двойник — `Breach.visor_pass`.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 shade : source_color = vec4(0.043, 0.11, 0.141, 0.6);
uniform vec2 knee = vec2(0.75, 0.95);

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 0.0).rgb;
	float l = max(c.r, max(c.g, c.b));
	float keep = smoothstep(knee.x, knee.y, l);
	COLOR = vec4(mix(c, shade.rgb, shade.a * (1.0 - keep)), 1.0);
}
