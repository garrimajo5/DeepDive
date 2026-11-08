// Лучи света сквозь трещины льда ART-052 — полный вариант с мягким касанием по глубине кадра. Тело — light_shafts.gdshaderinc.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_default, fog_disabled, shadows_disabled;
#define SOFT_DEPTH
#include "res://shaders/light_shafts.gdshaderinc"
