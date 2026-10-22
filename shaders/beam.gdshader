// Видимый луч прожектора в воде: цвета складываются с водой, глубина не пишется, видны обе стороны конуса, тумана нет.
// Яркость вдоль луча — в цвете вершин (Searchlight.beam_shade). Стенки, которые видны с ребра, гаснут: из кресла пилот
// смотрит вдоль луча, и иначе все кольца конуса складываются в резкий обод посреди окна.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.81, 0.965, 1.0, 0.06);
uniform float edge_power = 1.2;
// ART-062: поле взвеси в конусе (Searchlight.FIELD), плотность 0,28 + 0,72·поле с дрейфом; ил — Searchlight.density.
uniform sampler2D field : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float density_base = 0.28;
uniform vec2 drift = vec2(0.006, -0.014);
uniform float animate = 1.0;     // «Экономно» — 0: поле без дрейфа
uniform float silt_dim = 0.0;    // 0,25·k ила
uniform float beam_length = 55.0;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec2 uv = vec2(atan(local.y, local.x) / 6.2831853 + 0.5, clamp(-local.z / beam_length, 0.0, 1.0));
	uv += drift * TIME * animate;
	float dens = (density_base + (1.0 - density_base) * texture(field, uv).r) * (1.0 - silt_dim);
	ALBEDO = beam_color.rgb * COLOR.r * beam_color.a * pow(facing, edge_power) * dens;
}
