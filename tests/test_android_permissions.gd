extends TestCase
## По issue #570: без разрешения INTERNET Android запрещает socket() — сбор экипажа,
## маяк поиска и вход по адресу в APK не работают совсем.

const NEED := ["internet", "access_network_state", "access_wifi_state", "change_wifi_multicast_state"]

func _android_options() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		return {}
	for sec in cfg.get_sections():
		if cfg.get_value(sec, "name", "") == "Android" and cfg.get_value(sec, "platform", "") == "Android":
			var opt := sec + ".options"
			var out := {}
			if cfg.has_section(opt):
				for k in cfg.get_section_keys(opt):
					out[k] = cfg.get_value(opt, k)
			return out
	return {}

func test_network_permissions_on():
	var o := _android_options()
	ok(not o.is_empty(), "пресет Android с опциями есть")
	for p in NEED:
		eq(o.get("permissions/" + p, false), true, "разрешение %s включено" % p)
