extends PanelContainer

@export var level_manager: LevelManager
@export var star_hollow: PackedScene
@export var star_filled: PackedScene

@onready var star_container = $VBoxContainer/Stars

func _ready() -> void:
	level_manager.should_show_results.connect(on_should_show_results)
	visible = false

func on_should_show_results(percentage: float, cutoffs: Array[float]):
	for child in star_container.get_children():
		star_container.remove_child(child)
		child.queue_free()
	
	for cutoff in cutoffs:
		if percentage >= cutoff:
			var filled = star_filled.instantiate()
			star_container.add_child(filled)
		else:
			var hollow = star_hollow.instantiate()
			star_container.add_child(hollow)
			
	# TODO: Show other stats from the play
	
	visible = true
