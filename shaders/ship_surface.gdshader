shader_type spatial;
// Поверхности отсеков корабля изнутри (пол, стены, потолок) по ART-054 (docs/concept-art/mostik-materialy.md):
// цвет, нормали (OpenGL, +Y) и ORM (R — затенение, G — шероховатость, B — металличность), плитка 1 × 1 м.
// UV — метровые планарные из меша (BridgeView.planar_uv), касательные — SurfaceTool.generate_tangents.
// Две «стороны» в одном материале, чтобы не дробить поверхности: грань, смотрящая вниз (потолок, скос), берёт
// комплект down_*, остальные — side_*; комплекта нет — прежняя заливка base_*. Выбор по нормали в осях модели.
// relief = false («Экономно», ART-044) — без нормалей и ORM: цвет из карты, шероховатость и металл — константы.
// Выборки внутри ветки — через textureGrad с производными снаружи, иначе mipmap на стыке граней рвётся.

uniform vec3 base_color : source_color = vec3(0.55, 0.5, 0.42);
uniform float base_rough = 0.75;
uniform float base_metal = 0.0;
uniform bool relief = true;

uniform bool side_kit = false;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float side_depth = 0.8;
uniform float side_rough = 0.8;   // «Экономно»
uniform float side_metal = 0.15;

uniform bool down_kit = false;
uniform sampler2D down_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D down_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D down_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float down_depth = 0.7;
uniform float down_rough = 0.78;
uniform float down_metal = 0.2;

varying float down;

void vertex() {
	down = NORMAL.y < -0.5 ? 1.0 : 0.0;
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	bool d = down > 0.5;
	bool kit = d ? down_kit : side_kit;
	if (!kit) {
		ALBEDO = base_color;
		ROUGHNESS = base_rough;
		METALLIC = base_metal;
	} else if (d) {
		ALBEDO = textureGrad(down_albedo, UV, dx, dy).rgb;
		if (relief) {
			vec3 orm = textureGrad(down_orm, UV, dx, dy).rgb;
			AO = orm.r;
			ROUGHNESS = orm.g;
			METALLIC = orm.b;
			NORMAL_MAP = textureGrad(down_normal, UV, dx, dy).rgb;
			NORMAL_MAP_DEPTH = down_depth;
		} else {
			ROUGHNESS = down_rough;
			METALLIC = down_metal;
		}
	} else {
		ALBEDO = textureGrad(side_albedo, UV, dx, dy).rgb;
		if (relief) {
			vec3 orm = textureGrad(side_orm, UV, dx, dy).rgb;
			AO = orm.r;
			ROUGHNESS = orm.g;
			METALLIC = orm.b;
			NORMAL_MAP = textureGrad(side_normal, UV, dx, dy).rgb;
			NORMAL_MAP_DEPTH = side_depth;
		} else {
			ROUGHNESS = side_rough;
			METALLIC = side_metal;
		}
	}
}
