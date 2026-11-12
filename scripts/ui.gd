class_name UI
extends Control

@export_group("UI Graphics")
@export var star_indicator_scene: PackedScene
@export var result_star_hollow: PackedScene
@export var result_star_filled: PackedScene

@export_group("Scenes")
@export var main_scene: PackedScene
@export var next_scene: PackedScene

@export_group("")
@export_multiline() var scene_help: String

@onready var top_text = $"Results Screen/VBoxContainer/Top text"
@onready var time_text = $"Results Screen/VBoxContainer/Time"
@onready var results_screen = $"Results Screen"
@onready var results_star_container = $"Results Screen/VBoxContainer/Stars"
@onready var bottom_text = $Label
@onready var wrong_barn_label = $WrongBarnLabel

@onready var restart_button = $"Results Screen/VBoxContainer/Buttons/Restart Level"
@onready var next_button = $"Results Screen/VBoxContainer/Buttons/Next Level"

@onready var control = $Control

signal on_finish_attempt()

# Yes this is basically a copy of what is already present in level_manager
var star_percentages: Array[float] = []
var star_indicators: Array[StarIndicator] = []

# to keep just one tween going 
var wrong_barn_tween: Tween
var show_controls = true

func _ready():
	bottom_text.text = scene_help
	results_screen.visible = false
	top_text.visible = false
	next_button.visible = false

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

func should_show_results(percentage: float, cutoffs: Array[float], time: float):
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
	
	if percentage >= cutoffs[0]:
		top_text.visible = true
		next_button.visible = true
		next_button.grab_focus()
	else:
		restart_button.grab_focus()
	
	time_text.text = "Time: %ds" % time

func show_wrong_barn_label() -> void:
	if wrong_barn_tween:
		wrong_barn_tween.kill()
	
	wrong_barn_label.modulate.a = 1.0
	wrong_barn_label.show()
	
	wrong_barn_tween = create_tween()
	wrong_barn_tween.tween_interval(2.0)
	wrong_barn_tween.tween_property(wrong_barn_label, "modulate:a", 0.0, 0.5)
	wrong_barn_tween.tween_callback(wrong_barn_label.hide)
	

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		show_controls = true
	elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
		show_controls = false

func _process(_delta: float) -> void:
	control.visible = show_controls

# UI Button callbacks

func on_finish_attempt_btn() -> void:
	on_finish_attempt.emit()

func on_main_menu() -> void:
	if main_scene == null:
		push_error("[Level Manager] Main scene is not set up")
		return
	get_tree().change_scene_to_packed(main_scene)

func on_restart_level() -> void:
	get_tree().reload_current_scene()

func on_next_level() -> void:
	if next_scene == null:
		push_error("[Level Manager] Next scene is not set up")
		return
	get_tree().change_scene_to_packed(next_scene)
	
