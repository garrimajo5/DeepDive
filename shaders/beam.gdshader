// Видимый луч прожектора в воде: цвета складываются с водой, глубина не пишется, видны обе стороны конуса, тумана нет.
// Яркость вдоль луча — в цвете вершин (Searchlight.beam_shade). Стенки, которые видны с ребра, гаснут: из кресла пилот
// смотрит вдоль луча, и иначе все кольца конуса складываются в резкий обод посреди окна.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.81, 0.965, 1.0, 0.06);
uniform float edge_power = 1.2;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = beam_color.rgb * COLOR.r * beam_color.a * pow(facing, edge_power);
}
