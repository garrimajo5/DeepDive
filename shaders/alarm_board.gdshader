shader_type spatial;
// Лицо табло тревог (ART-025, AlarmBoard): тёмная подложка, надписи пяти полей из текстуры (белые буквы
// на прозрачном), уровни полей lv[i] = (буквы, углы рамки поля). Погашено — серые буквы, горит — янтарные
// буквы и светящиеся углы, мигает — гаснут только углы. Без освещения: табло светит само.
render_mode unshaded, cull_back;

uniform sampler2D words : source_color, filter_linear_mipmap;
uniform float edges[6];          // границы полей по u (0…1), слева направо
uniform vec2 lv[5];              // (буквы, углы) 0…1
uniform vec2 face_size = vec2(7.15, 0.2);   // м — для толщины углов
uniform vec3 back : source_color = vec3(0.043, 0.11, 0.141);
uniform vec3 word_off : source_color = vec3(0.4, 0.455, 0.478);
uniform vec3 word_on : source_color = vec3(1.0, 0.698, 0.349);
uniform float glow = 1.6;        // янтарь ярче единицы — горящее поле отличается яркостью

void fragment() {
	vec2 uv = UV;
	int f = 0;
	for (int i = 1; i < 5; i++) {
		if (uv.x >= edges[i]) { f = i; }
	}
	vec2 l = lv[f];
	float a = texture(words, uv).a;
	vec3 col = back;
	col = mix(col, mix(word_off, word_on * glow, l.x), a);
	// углы поля: уголки длиной 0,08 м и толщиной 0,012 м у краёв поля
	float x0 = edges[f] * face_size.x;
	float x1 = edges[f + 1] * face_size.x;
	float px = uv.x * face_size.x;
	float py = (1.0 - uv.y) * face_size.y;
	float m = 0.018;   // от края поля
	float t = 0.012;
	float len = 0.08;
	float dx = min(px - x0, x1 - px) - m;
	float dy = min(py, face_size.y - py) - m;
	bool in_x = dx >= 0.0 && dx < len;
	bool in_y = dy >= 0.0 && dy < len;
	bool corner = (in_x && dy >= 0.0 && dy < t) || (in_y && dx >= 0.0 && dx < t);
	if (corner && l.y > 0.0) {
		col = mix(col, word_on * glow, l.y);
	}
	ALBEDO = col;
}
