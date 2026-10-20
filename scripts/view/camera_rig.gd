class_name CameraRig
extends Node3D
## Isometric-ish perspective camera with smoothed pan/zoom and a small shake.

const FOV := 24.0
const DIR := Vector3(1.0, 1.1, 1.0)
const FORWARD := Vector3(-0.7071, 0.0, -0.7071)
const RIGHT := Vector3(0.7071, 0.0, -0.7071)
const BASE_TARGET := Vector3(-4.0, 0.0, -1.95)
const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.8
const PAN_LIMIT := Vector2(7.0, 6.0)

## Slow side-to-side drift on the title screen, driven by an AnimationPlayer.
var sway := 0.0
var zoom_goal := 1.0
var pan_goal := Vector2.ZERO
var _zoom := 1.0
var _pan := Vector2.ZERO
var _shake := 0.0
var _time := 0.0

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	cam.fov = FOV
	cam.near = 3.0
	cam.far = 500.0
	cam.current = true
	_zoom = zoom_goal
	_pan = pan_goal
	_apply(0.0, true)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 0.6)


func zoom_by(factor: float) -> void:
	zoom_goal = clampf(zoom_goal * factor, ZOOM_MIN, ZOOM_MAX)


## Drag the view by a screen delta (pixels).
func pan_by_pixels(delta_px: Vector2) -> void:
	var h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var per_px := 2.0 * _half_height() / h
	pan_goal.x = clampf(pan_goal.x - delta_px.x * per_px, -PAN_LIMIT.x, PAN_LIMIT.x)
	pan_goal.y = clampf(pan_goal.y + delta_px.y * per_px * 1.3, -PAN_LIMIT.y, PAN_LIMIT.y)


func reset_view() -> void:
	zoom_goal = 1.0
	pan_goal = Vector2.ZERO


func _half_height() -> float:
	var size := get_viewport().get_visible_rect().size
	var asp := size.x / maxf(size.y, 1.0)
	return maxf(9.2, (10.4 if asp >= 1.0 else 9.0) / asp) / _zoom


func _process(delta: float) -> void:
	_apply(delta, false)


func _apply(delta: float, snap: bool) -> void:
	_time += delta
	var k := 1.0 if snap else 1.0 - exp(-delta * 9.0)
	_zoom = lerpf(_zoom, zoom_goal, k)
	_pan = _pan.lerp(pan_goal, k)
	_shake = maxf(0.0, _shake - delta * 1.6)
	var size := get_viewport().get_visible_rect().size
	var asp := size.x / maxf(size.y, 1.0)
	var half_h := _half_height()
	var dist := half_h / tan(deg_to_rad(FOV * 0.5))
	var shift := -1.0 if asp < 1.0 else -1.3
	var side := 1.8 if asp < 1.0 else 0.0
	var target := BASE_TARGET + RIGHT * (_pan.x + sway * 1.6 + side) + FORWARD * (_pan.y + shift)
	var jitter := Vector3(sin(_time * 63.0), sin(_time * 71.0 + 1.3), cos(_time * 57.0)) * _shake * 0.12
	cam.global_position = target + DIR.normalized() * dist + jitter
	cam.look_at(target + jitter, Vector3.UP)
