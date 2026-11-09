class_name StarIndicator
extends Node2D

@onready var star_hollow = $"Star Hollow"
@onready var star_filled = $"Star Filled"
@onready var animation = $AnimationPlayer

var state = false

func _ready() -> void:
	set_star(false)

func set_star(gotten: bool):
	star_hollow.visible = !gotten
	star_filled.visible = gotten
	
	if !state && gotten:
		animation.play("star_grab")
	
	state = gotten
