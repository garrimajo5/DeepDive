shader_type spatial;
// Временная арка врат 07 и чаши гнёзд (GateView, #826) до модели MOD-023: матовый минерал без свечения.
// Туман — слоями воды ART-069, как у дна и дальней воды: штатный туман даёт только базу ART-059, она темнее воды
// со слоями вокруг, и арка за 350 м проступала со старта тёмным силуэтом (отчёт тестера c8b38fa, п. 4).
render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.22, 0.33, 0.38);
uniform float rough = 0.85;

#include "res://shaders/water_layers.gdshaderinc"

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = rough;
	FOG = water_layers_fog(CAMERA_POSITION_WORLD, w_pos, -1.0, TIME);
}
