shader_type spatial;
// Арка врат 07 — модель MOD-023 и временные чаши гнёзд (GateView, #1757): минерал с картами (цвет, нормали, ORM),
// кабель и чаши — ровным цветом (карты по умолчанию белые/плоские), полипы — со свечением по маске.
// Туман — слоями воды ART-069, как у дна и дальней воды: штатный туман даёт только базу ART-059, она темнее воды
// со слоями вокруг, и арка за 350 м проступала со старта тёмным силуэтом (отчёт тестера c8b38fa, п. 4).
// Обе стороны граней — как в принятой модели (glTF doubleSided).
render_mode cull_disabled;

uniform vec3 albedo : source_color = vec3(0.22, 0.33, 0.38);
uniform float rough = 0.85;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_k = 0.0;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 glow : source_color = vec3(0.0);
uniform sampler2D glow_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// Ободковый (френель) свет по краям (план графики, этап 3): силуэт арки читается в полумраке. Кромка по
// e = 1 − |N·V| геометрической нормали (сетка двусторонняя — abs; рельеф карт не берём: кромка — по форме),
// в EMISSION, дальше гаснет тем же слоевым туманом, что и тело. Числа — `GateArch.RIM_*`, «Экономно» — слабее
// (`GateView.set_lite`); створки — без ободка (ГД 14.11: «без свечения»). В bloom не уходит: пик ниже порога 0,9.
uniform vec3 rim_color : source_color = vec3(0.0);
uniform float rim_power = 3.0;
uniform float rim_gain = 0.0;
// Тон створок гнёзд (#1757, проба контраста, `GateArch.PETAL_TONE…`): лицо (нормаль +Z модели) и остальное — кромки и изнанка.
// У тела арки оба — 1: цвет как в картах.
uniform float tone = 1.0;
uniform float tone_in = 1.0;

#include "res://shaders/water_layers.gdshaderinc"

varying vec3 w_pos;
varying float inner;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	inner = 1.0 - clamp(NORMAL.z, 0.0, 1.0);
}

void fragment() {
	ALBEDO = albedo * texture(albedo_tex, UV).rgb * mix(tone, tone_in, inner);
	ROUGHNESS = rough * texture(orm_tex, UV).g;
	// Ободок — до записи NORMAL_MAP: NORMAL здесь ещё геометрический, рельеф карт кромку не рябит.
	float rim_e = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_k;
	EMISSION = glow * texture(glow_tex, UV).rgb + rim_color * rim_e * rim_gain;
	FOG = water_layers_fog(CAMERA_POSITION_WORLD, w_pos, -1.0, TIME);
}
