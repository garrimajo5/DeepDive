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
uniform float noise = 0.0;    // помехи (сонарная тьма): рябь вместо карты и отметок
uniform float time = 0.0;
uniform vec2 wp_xz = vec2(0.0);  // точка маршрута (Run.waypoint), x, z мира
uniform float wp_on = 0.0;

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
	if (noise > 0.0) {   // ил: карта гаснет, по столу бежит рябь
		vec2 cell = floor(local * 70.0);
		float n = fract(sin(dot(cell, vec2(12.9898, 78.233)) + floor(time * 12.0) * 3.7) * 43758.5453);
		col = mix(col, vec3(0.008, 0.07, 0.094), noise * 0.8) + teal * noise * 0.45 * step(0.82, n) * n;
	}
	if (wp_on > 0.5) {   // точка маршрута: светлое кольцо, дальше дальности — на краю круга в её сторону
		vec2 d = wp_xz - ship_xz;
		vec2 lp = vec2(d.x * c - d.y * s, d.x * s + d.y * c) / range_m;
		float far = step(0.9, length(lp));
		lp *= mix(1.0, 0.9 / max(length(lp), 1e-4), far);
		float ring = step(abs(length(local - lp) - 0.07), 0.018) + step(length(local - lp), 0.022);
		float pulse = 0.65 + 0.35 * sin(time * 4.0);
		col = mix(col, vec3(0.84, 0.89, 0.91), ring * pulse);
	}
	// корабль в центре — треугольник носом вверх (к −Z, local.y < 0)
	if (local.y > -0.075 && local.y < 0.055 && abs(local.x) < (local.y + 0.075) * 0.35) col = teal;
	ALBEDO = col * brightness;
}
