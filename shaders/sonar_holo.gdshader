// Голограмма сонара на голостоле (js/sonar.js So.update): круг, на нём рельеф вокруг корабля носом вверх,
// кольца дальности, волна импульса и отметки существ; цвета складываются, как свет над столом.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D map_tex : source_color, filter_linear, repeat_disable;
uniform float map_size = 700.0;
uniform vec2 ship_xz = vec2(0.0);
uniform float ship_yaw = 0.0;
uniform float range_m = 110.0;
uniform float ping_age = 99.0;
uniform float disc_r = 1.02;
uniform int blip_count = 0;
uniform vec4 blips[32];       // x, z мира, размер (м на голограмме, доля радиуса), яркость
uniform vec3 blip_cols[32];
uniform float brightness = 1.0;

varying vec2 local;

void vertex() {
	local = VERTEX.xz / disc_r;   // −1…1: x вправо (+X корабля), y к корме (+Z корабля)
}

void fragment() {
	float r = length(local);
	if (r > 1.0) discard;
	// точка голограммы → мир: оси корабля повёрнуты на курс
	vec2 l = local * range_m;
	float c = cos(ship_yaw), s = sin(ship_yaw);
	vec2 w = ship_xz + vec2(l.x * c + l.y * s, -l.x * s + l.y * c);
	vec3 col = vec3(0.008, 0.07, 0.094);
	vec2 uv = w / map_size + 0.5;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0)
		col = texture(map_tex, uv).rgb * 0.45 * (0.3 + 0.7 * max(0.0, 1.0 - ping_age / 12.0));
	vec3 teal = vec3(0.37, 0.95, 0.84);
	col += teal * 0.18 * (step(abs(r - 0.33), 0.006) + step(abs(r - 0.66), 0.006));
	col += teal * 0.5 * step(0.985, r);
	if (ping_age < 2.5)
		col += teal * 0.6 * (1.0 - ping_age / 2.5) * step(abs(r - ping_age / 2.2), 0.02);
	for (int i = 0; i < 32; i++) {
		if (i >= blip_count) break;
		vec2 d = blips[i].xy - w;
		float k = 1.0 - smoothstep(0.6, 1.0, length(d) / (blips[i].z * range_m));
		col = mix(col, blip_cols[i], k * blips[i].w);
	}
	// корабль в центре — треугольник носом вверх (к −Z, local.y < 0)
	if (local.y > -0.075 && local.y < 0.055 && abs(local.x) < (local.y + 0.075) * 0.35) col = teal;
	ALBEDO = col * brightness;
}
