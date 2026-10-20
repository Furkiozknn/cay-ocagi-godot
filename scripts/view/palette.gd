class_name Palette
extends RefCounted
## Shared colours (as 0xRRGGBB ints for MeshMerger, Color for UI) and a flat-material cache.

const WALL := 0xeed7ac
const WALL_D := 0xd8b987
const ROOF := 0xb4552f
const WOOD := 0x8b5a36
const WOOD_L := 0xc2915f
const STONE := 0xbdb09c
const STONE_D := 0x8e8070
const BRONZE := 0xb9772f
const GOLD := 0xe0aa45
const TEAL := 0x3f7f86
const TEAL_D := 0x2d5b62
const RED := 0xc2410c
const CREAM := 0xf8eed8
const AMBER := 0xdc8a3c
const GREEN := 0x5e8c3e
const GREEN_D := 0x40702f
const WHITE := 0xf5f0e6
const DARK := 0x2b2018
const SAND := 0xe3c88c
const SEA := 0x4a97a6
const SEA_D := 0x3b8091

# UI colours
const UI_AMBER := Color("c2410c")
const UI_AMBER_LIGHT := Color("ee7a34")
const UI_AMBER_DARK := Color("8a2d08")
const UI_INK := Color("3a2314")
const UI_INK_SOFT := Color("7a5a44")
const UI_OK := Color("3f8f4a")
const UI_BAD := Color("c0392b")
const UI_GLASS := Color(1.0, 0.973, 0.922, 0.86)
const UI_GLASS_BORDER := Color(1, 1, 1, 0.7)

static var _mats: Dictionary = {}


## Cached lit material of one flat colour.
static func flat(hex: int, emissive: float = 0.0) -> StandardMaterial3D:
	var key := hex * 1000 + int(emissive * 100.0)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.hex(hex * 256 + 255)
		m.roughness = 0.85
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = Color.hex(hex * 256 + 255)
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]
