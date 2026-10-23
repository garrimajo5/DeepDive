shader_type spatial;
// Дальняя вода (OceanView.far_wall, issue #456): сфера вокруг камеры радиусом Seabed.FAR_WALL изнутри, цвета тумана.
// В щели между дальним краем льда и дна раньше был виден фон BG_COLOR — на Forward Mobile он темнее тумана на
// геометрии, и у горизонта шла чёрная полоса. Сфера проходит тот же туман, что и дно, — щель того же цвета.
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;

uniform vec3 water : source_color = vec3(0.16, 0.42, 0.50);

#include "res://shaders/water_layers.gdshaderinc"

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = water;
	FOG = water_layers_fog(CAMERA_POSITION_WORLD, w_pos, -1.0, TIME);   // слои воды ART-069: у горизонта — термоклин
}
