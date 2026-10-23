// Лёд снизу по ART-056 (docs/concept-art/led-snizu.md): плоскость «Лёд» OceanView лицом вниз. Карты textures/ice/
// по world.xz / 16 (цвет sRGB, нормали OpenGL и маска трещин — линейные), сеть трещин светит только там, где её
// открывает крупный мировой шум (как IceSheet.gate — тот же хеш HashNoise), свечение гаснет по глубине наблюдателя.
// Числа — IceSheet (scripts/core/ice_sheet.gd). Один вызов, тот же меш.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D color_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D crack_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 glow_color : source_color = vec3(0.604, 0.851, 0.910);  // #9AD9E8
uniform vec3 water : source_color = vec3(0.1, 0.4, 0.46);            // цвет воды на глубине наблюдателя
uniform float tile = 16.0;
uniform float glow_base = 0.02;
uniform float glow_crack = 0.08;
uniform float glow_gain = 1.0;      // общая сила (уровни ART-044, экспозиция)
uniform float glow_k = 1.0;         // exp(−depth/9) по глубине наблюдателя — ставит OceanView
uniform float contrast = 1.0;       // IceSheet.contrast(depth)
uniform float relief = 0.35;        // IceSheet.relief(depth); 0 — «Экономно», без выборки нормалей
uniform float roughness = 0.62;
uniform float gate_scale = 60.0;
uniform vec2 gate_edge = vec2(0.48, 0.62);

varying vec3 w_pos;

float hash2(int ix, int iz) {   // HashNoise.hash2: 32-битная арифметика
	uint h = uint(ix) * 374761393u + uint(iz) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float value(vec2 p) {   // HashNoise.value
	vec2 f0 = floor(p);
	ivec2 i = ivec2(f0);
	vec2 f = p - f0;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i.x, i.y);
	float b = hash2(i.x + 1, i.y);
	float c = hash2(i.x, i.y + 1);
	float d = hash2(i.x + 1, i.y + 1);
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

float gate(vec2 xz) {   // IceSheet.gate: две октавы HashNoise.fbm
	vec2 p = xz / gate_scale;
	float n = (0.5 * value(p) + 0.25 * value(p * 2.0 + vec2(17.3, -9.1))) / 0.75;
	return smoothstep(gate_edge.x, gate_edge.y, n);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

uniform vec3 base_fog : source_color=vec3(0.1);
uniform float base_density=.01;
uniform float layer_phase=0.0;
uniform float layer_gain=1.0;
uniform vec3 layer_ice : source_color=vec3(0.227,0.506,0.565);
uniform vec3 layer_thermo : source_color=vec3(0.137,0.310,0.412);
uniform vec3 layer_dust : source_color=vec3(0.169,0.325,0.349);
float soft_integral(float y,float a,float b){
 if(y<=a)return 0.0;
 if(y>=b)return y-(a+b)*0.5;
 float t=(y-a)/(b-a);
 return (b-a)*(t*t*t-0.5*t*t*t*t);
}
float band_integral(float y,float lo,float hi,float e){return soft_integral(y,lo-e,lo+e)-soft_integral(y,hi-e,hi+e);}
float segment_band(vec3 a,vec3 b,float y0,float y1){
 float e=y0< -10.0 ? 1.0:1.5;
 float dy=b.y-a.y;
 if(abs(dy)<0.0001)return (smoothstep(y0-e,y0+e,a.y)-smoothstep(y1-e,y1+e,a.y))*length(b-a);
 return max(0.0,(band_integral(b.y,y0,y1,e)-band_integral(a.y,y0,y1,e))/dy)*length(b-a);
}

void fragment() {
	vec2 uv = w_pos.xz / tile;
	vec3 c = texture(color_tex, uv).rgb;
	ALBEDO = mix(water, c, contrast);
	ROUGHNESS = roughness;
	METALLIC = 0.0;

	float crack = texture(crack_tex, uv).r;
	float g = gate(w_pos.xz);
	EMISSION = glow_color * (glow_base + glow_crack * crack * g) * glow_k * glow_gain;

	if (relief > 0.001) {
		// мировой базис нижней стороны: T = +X (растёт u), B = −Z (верх картинки), N = −Y (лицом вниз)
		vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		n.xy *= relief;
		vec3 wn = normalize(n.x * vec3(1.0, 0.0, 0.0) + n.y * vec3(0.0, 0.0, -1.0) + n.z * vec3(0.0, -1.0, 0.0));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}
vec3 ray_start=CAMERA_POSITION_WORLD;
 float wave=0.12*sin(w_pos.x*0.09+layer_phase*0.25)*sin(w_pos.z*0.07-layer_phase*0.15);
 float ice_len=segment_band(ray_start,w_pos,-6.0,0.0);
 float thermo_len=segment_band(ray_start,w_pos,-31.5+wave,-28.5+wave);
 float ai=min(0.11,1.0-exp(-ice_len*0.008));
 float at=min(0.10,1.0-exp(-thermo_len*0.017));
 float dust=0.0;
 
 float total=ai+at+dust;
 vec3 lc=(layer_ice*ai+layer_thermo*at+layer_dust*dust)/max(total,0.00001);
 float base_a=1.0-exp(-length(w_pos-ray_start)*base_density);
 float la=clamp(total*layer_gain,0.0,0.16);
 float fa=base_a+la*(1.0-base_a);
 vec3 fc=(base_fog*base_a*(1.0-la)+lc*la)/max(fa,0.00001);
 FOG=vec4(fc,fa);
}
