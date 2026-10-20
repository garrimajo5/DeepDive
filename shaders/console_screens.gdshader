shader_type spatial;
// Экраны пульта пилота (pult-ekrany): ровное голубое свечение, три экрана по x модели — у каждого своя яркость
// (помехи при стеклоусте, Vitals.screen_k). Граница экранов — edge от центра модели.
uniform vec3 glow : source_color = vec3(0.06, 0.26, 0.32);
uniform float energy = 1.1;
uniform vec3 k = vec3(1.0);
uniform float edge = 0.35;
varying float vx;

void vertex() {
	vx = VERTEX.x;
}

void fragment() {
	float kk = vx < -edge ? k.x : (vx > edge ? k.z : k.y);
	ALBEDO = glow * kk;
	EMISSION = glow * energy * kk;
}
