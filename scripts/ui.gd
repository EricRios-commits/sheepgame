class_name UI
extends Control

@export var star_indicator_scene: PackedScene
@export var result_star_hollow: PackedScene
@export var result_star_filled: PackedScene

@export var main_scene: PackedScene
@export var self_scene: PackedScene
@export var next_scene: PackedScene

@onready var results_screen = $"Results Screen"
@onready var results_star_container = $"Results Screen/VBoxContainer/Stars"

signal on_finish_attempt()

# Yes this is basically a copy of what is already present in level_manager
var star_percentages: Array[float] = []
var star_indicators: Array[StarIndicator] = []

func _ready():
	results_screen.visible = false

func setup_star(percentage: float):
	var star_indicator = star_indicator_scene.instantiate()
	var progress_bar = get_node("ProgressBar")
	star_indicator.position.x = percentage * progress_bar.get_rect().size.x
	progress_bar.add_child(star_indicator)
	star_percentages.append(percentage)
	star_indicators.append(star_indicator)

func update_progress(percentage: float):
	var progress_bar = get_node("ProgressBar")
	progress_bar.value = percentage
	for i in star_indicators.size():
		var star = star_indicators[i]
		var cutoff = star_percentages[i]
		star.set_star(percentage >= cutoff)

func should_show_results(percentage: float, cutoffs: Array[float]):
	for child in results_star_container.get_children():
		results_star_container.remove_child(child)
		child.queue_free()
	
	for cutoff in cutoffs:
		if percentage >= cutoff:
			var filled = result_star_filled.instantiate()
			results_star_container.add_child(filled)
		else:
			var hollow = result_star_hollow.instantiate()
			results_star_container.add_child(hollow)
			
	# TODO: Show other stats from the play
	
	results_screen.visible = true
	pass

# UI Button callbacks

func on_finish_attempt_btn() -> void:
	on_finish_attempt.emit()

func on_main_menu() -> void:
	if main_scene == null:
		push_error("[Level Manager] Main scene is not set up")
		return
	get_tree().change_scene_to_packed(main_scene)

func on_restart_level() -> void:
	if self_scene == null:
		push_error("[Level Manager] Self scene is not set up")
		return
	get_tree().change_scene_to_packed(self_scene)

func on_next_level() -> void:
	if next_scene == null:
		push_error("[Level Manager] Next scene is not set up")
		return
	get_tree().change_scene_to_packed(next_scene)
