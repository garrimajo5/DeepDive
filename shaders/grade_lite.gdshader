shader_type canvas_item;
render_mode unshaded, blend_mul;
// «Экономно» ART-044 для виньетки ART-065 (#842): только овал, без чтения экрана — умножение кадра на рамку.
// Полный проход (`grade.gdshader`) копирует весь экран каждый кадр; здесь копии нет. Двойник на CPU — `Grade.shade(…, lite)`.
uniform float strength = 0.10;

void fragment() {
	vec2 p = (SCREEN_UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.36, 1.28, length(p * vec2(0.90, 1.0)));
	float amount = strength * edge;
	COLOR = vec4(1.0 - amount, 1.0 - amount * 0.88, 1.0 - amount * 0.65, 1.0);
}
