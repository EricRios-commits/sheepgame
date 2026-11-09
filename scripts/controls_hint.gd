extends Control

# The keys mirror the physical keys used by player.gd and isometric_camera.gd.
const KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_SPACE]
const KEY_SIZE := Vector2(44.0, 44.0)
const SPACE_SIZE := Vector2(144.0, 38.0)
const PRESS_TRANSITION := 0.16

const KEY_SHADOW := Color(0.07, 0.12, 0.12, 0.95)
const KEY_RIM := Color(0.30, 0.43, 0.38)
const KEY_FACE := Color(0.50, 0.61, 0.52)
const KEY_HIGHLIGHT := Color(0.69, 0.78, 0.68)
const PRESSED_RIM := Color(0.72, 0.78, 0.73)
const PRESSED_FACE := Color(0.98, 0.98, 0.95)
const TEXT_LIGHT := Color(0.96, 0.96, 0.89)
const TEXT_DARK := Color(0.16, 0.25, 0.22)

var _press_progress: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var changed := false
	for index in KEYS.size():
		var target := 1.0 if Input.is_physical_key_pressed(KEYS[index]) else 0.0
		var next := move_toward(_press_progress[index], target, delta / PRESS_TRANSITION)
		if next != _press_progress[index]:
			_press_progress[index] = next
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var offset = Vector2(0,-50)
	
	_draw_key(Vector2(65, 0) + offset, KEY_SIZE, "W", 0, 22)
	_draw_key(Vector2(15, 50) + offset, KEY_SIZE, "A", 1, 22)
	_draw_key(Vector2(65, 50) + offset, KEY_SIZE, "S", 2, 22)
	_draw_key(Vector2(115, 50) + offset, KEY_SIZE, "D", 3, 22)
	_draw_key(Vector2(15, 100) + offset, SPACE_SIZE, "SPACE", 6, 15)

	_draw_key(Vector2(203, 50) + offset, KEY_SIZE, "Q", 4, 22)
	_draw_key(Vector2(261, 50) + offset, KEY_SIZE, "E", 5, 22)


func _draw_key(pos: Vector2, key_size: Vector2, label: String, index: int, font_size: int) -> void:
	var amount := smoothstep(0.0, 1.0, _press_progress[index])
	var depth := 2.0 * amount
	var shadow := _cut_corners(Rect2(pos + Vector2(0, 4), key_size), 5.0)
	var rim := _cut_corners(Rect2(pos, key_size), 5.0)
	var face := _cut_corners(Rect2(pos + Vector2(2, 2 + depth), key_size - Vector2(4, 6)), 4.0)

	draw_colored_polygon(shadow, KEY_SHADOW)
	draw_colored_polygon(rim, KEY_RIM.lerp(PRESSED_RIM, amount))
	draw_colored_polygon(face, KEY_FACE.lerp(PRESSED_FACE, amount))
	draw_line(pos + Vector2(8, 3 + depth),
		pos + Vector2(key_size.x - 8, 3 + depth),
		KEY_HIGHLIGHT.lerp(PRESSED_FACE, amount), 1.0, true)
	draw_string(get_theme_default_font(), pos + Vector2(2, key_size.y * 0.7 + depth), label,
		HORIZONTAL_ALIGNMENT_CENTER, key_size.x - 4, font_size,
		TEXT_LIGHT.lerp(TEXT_DARK, amount))


func _cut_corners(rect: Rect2, cut: float) -> PackedVector2Array:
	var x := rect.position.x
	var y := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	return PackedVector2Array([
		Vector2(x + cut, y), Vector2(right - cut, y),
		Vector2(right, y + cut), Vector2(right, bottom - cut),
		Vector2(right - cut, bottom), Vector2(x + cut, bottom),
		Vector2(x, bottom - cut), Vector2(x, y + cut),
	])
