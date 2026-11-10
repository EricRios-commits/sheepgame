extends Control
var level: Node3D
var clock := 0.0
var intensity := 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	intensity = minf(1,level.motion.dog_boost_left*3) if level.phase == level.Phase.RUNNING else 0.0
	clock += delta*1.8
	queue_redraw()
func _draw() -> void:
	if intensity <= 0:
		return
	# Sparse peripheral rays leave the middle half of the screen clear.
	for side in [-1,1]:
		for i in 9:
			var t := fposmod(clock+i*0.137,1)
			var x := lerpf(size.x*0.23, -size.x*0.06,t)
			if side > 0:
				x = size.x-x
			var y := size.y*(0.08+i*0.105)
			var p := Vector2(x,y)
			draw_line(p,p+Vector2(-side*lerpf(24,65,t),(y-size.y/2)*0.06),Color(0.65,1,1,intensity*0.48*sin(PI*t)),2,true)
