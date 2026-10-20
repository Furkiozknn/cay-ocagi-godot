extends Node
## User preferences (language, volumes, quality, fullscreen) saved to user://settings.cfg.

signal changed
signal language_changed

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

var lang := "tr"
var master_volume := 0.9
var music_volume := 0.55
var sfx_volume := 0.9
var muted := false
## "low" disables shadows and halves the particles; "high" is the default.
var quality := "high"
var fullscreen := false


func _ready() -> void:
	_load()
	_apply_language_default()


func _apply_language_default() -> void:
	if not FileAccess.file_exists(PATH):
		lang = "tr" if OS.get_locale_language() == "tr" else "en"


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	lang = str(cf.get_value("game", "lang", lang))
	master_volume = clampf(float(cf.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cf.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cf.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	muted = bool(cf.get_value("audio", "muted", muted))
	quality = str(cf.get_value("video", "quality", quality))
	fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
	if lang != "tr" and lang != "en":
		lang = "tr"
	if quality != "low" and quality != "high":
		quality = "high"


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "lang", lang)
	cf.set_value("audio", "master", master_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "muted", muted)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "fullscreen", fullscreen)
	cf.save(PATH)


func set_language(l: String) -> void:
	if l == lang:
		return
	lang = l
	save()
	language_changed.emit()
	changed.emit()


func toggle_language() -> void:
	set_language("en" if lang == "tr" else "tr")


func set_quality(q: String) -> void:
	quality = q
	save()
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_window()
	save()
	changed.emit()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func set_volume(bus: String, v: float) -> void:
	match bus:
		"master":
			master_volume = v
		"music":
			music_volume = v
		"sfx":
			sfx_volume = v
	save()
	changed.emit()


func set_muted(m: bool) -> void:
	muted = m
	save()
	changed.emit()


func is_low() -> bool:
	return quality == "low"
