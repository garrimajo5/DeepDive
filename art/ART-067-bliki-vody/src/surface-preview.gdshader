shader_type spatial;
// Поверхности отсеков корабля изнутри (пол, стены, потолок) по ART-054 (мостик, docs/concept-art/mostik-materialy.md)
// и ART-055 (машинное и трюм, otseki-materialy.md): цвет, нормали (OpenGL, +Y) и ORM (R — затенение,
// G — шероховатость, B — металличность), плитка 1 × 1 м.
// UV — метровые планарные из меша (BridgeView.planar_uv), касательные — SurfaceTool.generate_tangents.
// Комплекты в одном материале, чтобы не дробить поверхности: грань, смотрящая вниз (потолок, скос), берёт down_*,
// остальные — side_*, а дальше по кораблю — aft_* (машинное → трюм). У каждого комплекта отрезок z в осях модели
// (*_z: от, до); вне всех — прежняя заливка base_*. skip_up — грани вверх без карт (кромка шлюза в трюме).
// relief = false («Экономно», ART-044) — без нормалей и ORM: цвет из карты, шероховатость и металл — константы.
// Выборки внутри ветки — через textureGrad с производными снаружи, иначе mipmap на стыке граней рвётся.

uniform vec3 base_color : source_color = vec3(0.55, 0.5, 0.42);
uniform float base_rough = 0.75;
uniform float base_metal = 0.0;
uniform bool relief = true;
uniform bool skip_up = false;

uniform bool side_kit = false;
uniform vec2 side_z = vec2(-1e6, 1e6);
uniform sampler2D side_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float side_depth = 0.8;
uniform float side_rough = 0.8;   // «Экономно»
uniform float side_metal = 0.15;

uniform bool aft_kit = false;
uniform vec2 aft_z = vec2(-1e6, 1e6);
uniform sampler2D aft_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aft_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aft_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float aft_depth = 0.8;
uniform float aft_rough = 0.8;
uniform float aft_metal = 0.15;

uniform bool down_kit = false;
uniform vec2 down_z = vec2(-1e6, 1e6);
uniform sampler2D down_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D down_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D down_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float down_depth = 0.7;
uniform float down_rough = 0.78;
uniform float down_metal = 0.2;

uniform sampler2D water_mask : repeat_enable, filter_linear_mipmap;
uniform float water_strength=0.0;
uniform float phase=0.0;
uniform vec3 water_tint : source_color=vec3(0.65,0.85,0.95);
varying vec3 ship_pos;
varying float down;
varying float up;
varying float local_z;

void vertex() {
	ship_pos=VERTEX;
	down = NORMAL.y < -0.5 ? 1.0 : 0.0;
	up = NORMAL.y > 0.5 ? 1.0 : 0.0;
	local_z = VERTEX.z;
}

bool within(vec2 r, float z) {
	return z >= r.x && z < r.y;
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	// 0 — заливка, 1 — side, 2 — aft, 3 — down
	int kit = 0;
	if (down > 0.5) {
		kit = down_kit && within(down_z, local_z) ? 3 : 0;
	} else if (!(skip_up && up > 0.5)) {
		if (side_kit && within(side_z, local_z)) {
			kit = 1;
		} else if (aft_kit && within(aft_z, local_z)) {
			kit = 2;
		}
	}
	if (kit == 0) {
		ALBEDO = base_color;
		ROUGHNESS = base_rough;
		METALLIC = base_metal;
	} else if (kit == 3) {
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
	} else if (kit == 2) {
		ALBEDO = textureGrad(aft_albedo, UV, dx, dy).rgb;
		if (relief) {
			vec3 orm = textureGrad(aft_orm, UV, dx, dy).rgb;
			AO = orm.r;
			ROUGHNESS = orm.g;
			METALLIC = orm.b;
			NORMAL_MAP = textureGrad(aft_normal, UV, dx, dy).rgb;
			NORMAL_MAP_DEPTH = aft_depth;
		} else {
			ROUGHNESS = aft_rough;
			METALLIC = aft_metal;
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
float region=(1.0-smoothstep(-1.0,3.0,ship_pos.z))*smoothstep(-6.7,-5.8,ship_pos.z);
 float facing=max(down,up*0.6);
 vec2 q=ship_pos.xz/3.2;
 float a=texture(water_mask,q+vec2(phase*0.012,phase*0.007)).r;
 float b=texture(water_mask,q*vec2(-1.0,1.0)+vec2(-phase*0.006,phase*0.011)+0.37).r;
 EMISSION+=water_tint*(a*0.6+b*0.4)*water_strength*region*facing;
}
