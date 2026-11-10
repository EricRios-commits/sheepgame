extends Control
## Font-independent camera -> subject pictogram.
var dog_only := true:
	set(value):
		dog_only = value
		queue_redraw()
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	var ink := Color("fff3d7")
	draw_rect(Rect2(12,21,20,16),ink)
	draw_colored_polygon(PackedVector2Array([Vector2(32,25),Vector2(40,20),Vector2(40,38),Vector2(32,33)]),ink)
	draw_line(Vector2(46,29),Vector2(58,29),ink,2,true)
	draw_line(Vector2(54,25),Vector2(58,29),ink,2,true)
	draw_line(Vector2(54,33),Vector2(58,29),ink,2,true)
	# Long body, pointed ears/muzzle, tail and legs distinguish dog from sheep.
	draw_colored_polygon(PackedVector2Array([Vector2(67,25),Vector2(88,25),Vector2(91,15),Vector2(95,21),Vector2(100,23),Vector2(96,29),Vector2(91,30),Vector2(89,40),Vector2(85,40),Vector2(85,32),Vector2(72,32),Vector2(70,40),Vector2(66,40),Vector2(68,30),Vector2(62,21)]),ink)
	if not dog_only:
		for p in [Vector2(119,25),Vector2(127,23),Vector2(135,25)]:
			draw_circle(p,7,ink)
		draw_circle(Vector2(143,28),5,ink)
		for x in [119,135]:
			draw_line(Vector2(x,30),Vector2(x,40),ink,3,true)
func _panel() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.04,0.1,0.1,0.7)
	panel.set_corner_radius_all(9)
	return panel
