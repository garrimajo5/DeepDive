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
// Блики воды ART-067 (bliki-vody.md, числа — WaterGlints): маска каустик в EMISSION потолка (×1) и пола (×0,6) в зоне
// мостика по z, две выборки текут; glint_k = 0 (отсеки, «Экономно», глубина) — маска не читается.
// «Корабль устал» ART-074 (ustalost-korpusa.md, двойник — CabinWear.amount): маска wear_mask (R потёки, G пятна пола,
// B порог потери) по метровым UV, вход wear_loss = 1 − корпус/100; потёки на стенах сверху, у бортов на потолке,
// мокрая полоса пола у бортов; только мостик и машинное, у постов и рамки окна сухо. Темнее, глаже, лак — без эмиссии.
// wear_loss < 0,36 (самый низкий порог маски ≈ 0,37) — маска не читается.

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

uniform sampler2D glint_mask : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float glint_k = 0.0;
uniform float glint_time = 0.0;
uniform vec3 glint_tint : source_color = vec3(0.65, 0.85, 0.95);

uniform sampler2D wear_mask : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float wear_loss = 0.0;

varying vec3 ship_pos;
varying float down;
varying float up;
varying float local_z;

void vertex() {
	down = NORMAL.y < -0.5 ? 1.0 : 0.0;
	up = NORMAL.y > 0.5 ? 1.0 : 0.0;
	local_z = VERTEX.z;
	ship_pos = VERTEX;
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
	vec2 q = ship_pos.xz / 3.2;   // производные — до ветки (как у карт выше)
	vec2 qdx = dFdx(q);
	vec2 qdy = dFdy(q);
	if (glint_k >= 0.0001) {   // WaterGlints: zone, facing, flow, MIX
		float region = (1.0 - smoothstep(-1.0, 3.0, ship_pos.z)) * smoothstep(-6.7, -5.8, ship_pos.z);
		float facing = down > 0.5 ? 1.0 : (up > 0.5 ? 0.6 : 0.0);
		if (region * facing > 0.0) {
			float a = textureGrad(glint_mask, q + vec2(0.012, 0.007) * glint_time, qdx, qdy).r;
			float b = textureGrad(glint_mask, q * vec2(-1.0, 1.0) + vec2(-0.006, 0.011) * glint_time + 0.37,
				qdx * vec2(-1.0, 1.0), qdy * vec2(-1.0, 1.0)).r;
			EMISSION += glint_tint * (0.6 * a + 0.4 * b) * glint_k * region * facing;
		}
	}
	if (wear_loss >= 0.36) {   // CabinWear: gate, zone, safe, near_wall, amount
		vec3 data = textureGrad(wear_mask, UV, dx, dy).rgb;
		float zone = max(1.0 - smoothstep(1.8, 2.0, ship_pos.z),
			smoothstep(14.0, 14.2, ship_pos.z) * (1.0 - smoothstep(19.3, 19.5, ship_pos.z)));
		float wall_x = mix(3.0, 4.9, 1.0 - smoothstep(1.8, 2.0, ship_pos.z));
		float near_wall = smoothstep(wall_x - 0.8, wall_x - 0.15, abs(ship_pos.x));
		float safe = smoothstep(-5.7, -5.35, ship_pos.z);
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(0.0, -4.2)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(-3.9, -2.0)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(3.85, -2.0)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(0.0, -1.2)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(-3.9, -0.5)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(-2.2, 17.2)));
		safe *= smoothstep(0.8, 1.25, distance(ship_pos.xz, vec2(2.2, 17.2)));
		float wet = data.r * smoothstep(1.35, 2.85, ship_pos.y);
		if (up > 0.5) {
			wet = data.g * near_wall;
		} else if (down > 0.5) {
			wet = data.r * near_wall * 0.6;
		}
		float amount = wet * smoothstep(data.b, data.b + 0.14, wear_loss) * zone * safe;
		ALBEDO *= 1.0 - amount * 0.68;
		ROUGHNESS = mix(ROUGHNESS, 0.24, amount * 0.72);
		CLEARCOAT = amount * 0.7;
		CLEARCOAT_ROUGHNESS = 0.18;
	}
}
