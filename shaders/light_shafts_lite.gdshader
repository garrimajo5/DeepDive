// Лучи света ART-052 на «Экономно» (#852): без чтения глубины кадра — край у дна и корпуса резче, зато нет копии
// буфера глубины каждый кадр. Тело — light_shafts.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_default, fog_disabled, shadows_disabled;
#include "res://shaders/light_shafts.gdshaderinc"
