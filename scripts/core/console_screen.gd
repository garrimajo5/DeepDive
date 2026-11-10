class_name ConsoleScreen
## Показ экранов пульта у штурвала ART-061 (`docs/concept-art/ekrany-pultov.md`, #1568): что рисует
## `shaders/console_screens.gdshader`. Значения округлены до того, что видно на экране, — `BridgeView.set_readout`
## пишет uniform только при смене показа.

const MAX_DEPTH := 999   ## три цифры глубины


## Курс (°, целый 0…359), глубина (м, целая 0…999), ход (м/с со знаком, до 0,1).
static func values(yaw: float, depth: float, speed: float) -> Vector3:
	var h := roundi(wrapf(-rad_to_deg(yaw), 0.0, 360.0)) % 360
	var d := clampi(roundi(depth), 0, MAX_DEPTH)
	var s := snappedf(speed, 0.1)
	if absf(s) < 0.05:
		s = 0.0   # «−0.0» не рисуем
	return Vector3(h, d, s)


## Свет (1 — горит), сонар (1 — готов к импульсу, 0 — перезаряд), тревога (1 — янтарная рамка).
static func status(light: bool, sonar_ready: bool, alarm: bool) -> Vector3:
	return Vector3(1.0 if light else 0.0, 1.0 if sonar_ready else 0.0, 1.0 if alarm else 0.0)
