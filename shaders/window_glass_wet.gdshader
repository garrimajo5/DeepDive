shader_type spatial;
// Стекло носовых окон ART-057 с полным конденсатом ART-077 — только уровень «Красиво» (BridgeView.set_wet,
// Main._apply_graphics): нормали капель из производных высоты и слабое экранное преломление (+1 выборка экрана,
// копия экрана каждый кадр на Forward Mobile). На «Обычно» — после замера на телефоне. Тело — window_glass.gdshaderinc.
#define WET_REFRACT
#include "res://shaders/window_glass.gdshaderinc"
