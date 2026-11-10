extends "res://scripts/controls_hint.gd"
# Reuse Classic key geometry/animation with mode-specific labels only.
func _draw() -> void:
	_draw_key(Vector2(65,-50),KEY_SIZE,"W",0,22)
	_draw_key(Vector2(15,0),KEY_SIZE,"A",1,22)
	_draw_key(Vector2(65,0),KEY_SIZE,"S",2,22)
	_draw_key(Vector2(115,0),KEY_SIZE,"D",3,22)
	_draw_key(Vector2(15,50),SPACE_SIZE,"JUMP",6,15)
	_draw_key(Vector2(180,0),KEY_SIZE,"E",5,22)
	draw_string(get_theme_default_font(),Vector2(235,15),"Bark / LMB   |   Shift Sprint",HORIZONTAL_ALIGNMENT_LEFT,-1,18,TEXT_LIGHT)
	draw_string(get_theme_default_font(),Vector2(180,67),"RMB click: view  |  drag: orbit  |  wheel / C",HORIZONTAL_ALIGNMENT_LEFT,-1,17,TEXT_LIGHT)
