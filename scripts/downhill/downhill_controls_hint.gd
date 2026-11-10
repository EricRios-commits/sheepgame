extends "res://scripts/controls_hint.gd"
# Reuse Classic key geometry/animation with mode-specific labels only.
func _draw() -> void:
	_draw_key(Vector2(65,-50),KEY_SIZE,"W",0,22)
	_draw_key(Vector2(15,0),KEY_SIZE,"A",1,22)
	_draw_key(Vector2(65,0),KEY_SIZE,"S",2,22)
	_draw_key(Vector2(115,0),KEY_SIZE,"D",3,22)
	_draw_key(Vector2(15,50),SPACE_SIZE,"JUMP",6,15)
