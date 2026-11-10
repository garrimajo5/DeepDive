// Слои воды по ART-069 (`WaterLayers`, docs/concept-art/sloi-vody.md): подлёдная муть, термоклин, придонная пыль —
// поверх тумана по глубине ART-059. Подключают дно, лёд и дальняя вода. Запись FOG заменяет штатный туман
// Forward Mobile, поэтому база `1 − exp(−dist · density)` цвета `fog_light_color` считается здесь же.
// Числа и двойник формул — scripts/core/water_layers.gd (тесты). Ставит OceanView.apply_water / _process.

// Цвета — уже линейные (srgb_to_linear в OceanView), без подсказки цвета: в Compatibility она vec3 не переводит.
uniform vec3 layer_base = vec3(0.022, 0.147, 0.214);               // env.fog_light_color, линейный
uniform float layer_density = 0.02;                               // env.fog_density
uniform float layer_gain = 0.0;                                   // WaterLayers.gain: 0 — «Экономно», только база
uniform float layer_cam_above = 10.0;                             // высота камеры над дном (Seabed.mesh_height), м
uniform float layer_floor_y = -20.0;                              // y дна под камерой — для высоты точки над дном
uniform vec3 layer_ice_color = vec3(0.0423, 0.2195, 0.2789);     // WaterLayers.ICE #3A8190
uniform vec3 layer_thermo_color = vec3(0.0168, 0.0782, 0.1413);  // WaterLayers.THERMO #234F69
uniform vec3 layer_dust_color = vec3(0.0242, 0.0865, 0.0999);    // WaterLayers.DUST #2B5359

float wl_soft(float y, float a, float b) {
	if (y <= a) return 0.0;
	if (y >= b) return y - (a + b) * 0.5;
	float t = (y - a) / (b - a);
	return (b - a) * (t * t * t - 0.5 * t * t * t * t);
}

float wl_band_int(float y, float lo, float hi, float e) {
	return wl_soft(y, lo - e, lo + e) - wl_soft(y, hi - e, hi + e);
}

float wl_band_len(float ya, float yb, float len, float lo, float hi, float e) {
	float dy = yb - ya;
	if (abs(dy) < 0.0001) return (smoothstep(lo - e, lo + e, ya) - smoothstep(hi - e, hi + e, ya)) * len;
	return max(0.0, (wl_band_int(yb, lo, hi, e) - wl_band_int(ya, lo, hi, e)) / dy * len);
}

// Край подлёдного слоя и термоклина шире вдали (issue #516, WaterLayers.edge): у дальней воды не линия, а полоса.
float wl_edge(float e, float dist) {
	return e + clamp((dist - 60.0) * 0.1, 0.0, 30.0);
}

// p — мировая точка пикселя, p_above — её высота над дном (у дна 0; < 0 — оценить по layer_floor_y).
vec4 water_layers_fog(vec3 cam, vec3 p, float p_above, float t) {
	float dist = length(p - cam);
	float a0 = 1.0 - exp(-dist * layer_density);
	if (layer_gain <= 0.0) return vec4(layer_base, a0);
	float h = p_above < 0.0 ? max(p.y - layer_floor_y, 0.0) : p_above;
	float w = 0.12 * sin(p.x * 0.09 + t * 0.25) * sin(p.z * 0.07 - t * 0.15);
	float li = wl_band_len(cam.y, p.y, dist, -6.0, 0.0, wl_edge(1.5, dist));
	float lt = wl_band_len(cam.y, p.y, dist, -31.5 + w, -28.5 + w, wl_edge(1.0, dist));
	float ld = wl_band_len(layer_cam_above, h, dist, 0.0, 3.0, 1.0);
	float ai = 0.11 * (1.0 - exp(-li * 0.008 / 0.11));   // мягкий предел: min() давал излом-линию у горизонта
	float at = 0.10 * (1.0 - exp(-lt * 0.017 / 0.10));
	float ad = 0.10 * (1.0 - exp(-ld * 0.035 / 0.10)) * smoothstep(12.0, 45.0, dist);
	float total = ai + at + ad;
	vec3 lc = (layer_ice_color * ai + layer_thermo_color * at + layer_dust_color * ad) / max(total, 0.00001);
	float la = clamp(total * layer_gain, 0.0, 0.16);
	float a = a0 + la * (1.0 - a0);
	vec3 c = (layer_base * a0 * (1.0 - la) + lc * la) / max(a, 0.00001);
	return vec4(c, a);
}
