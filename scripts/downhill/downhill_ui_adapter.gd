extends "res://scripts/ui.gd"
## Packed Classic layout/assets, overridden callbacks stay mode-local.
var level: Node3D
func _ready() -> void:
	star_indicator_scene = preload("res://scenes/star_gameplay.tscn")
	result_star_hollow = preload("res://scenes/star_results_hollow.tscn")
	result_star_filled = preload("res://scenes/star_results_filled.tscn")
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Button.hide()
	$Button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$"Results Screen/VBoxContainer/Buttons/Next Level".hide()
	$Label.hide()
	for cutoff in [0.6,0.8,0.95]:
		setup_star(cutoff)
func on_finish_attempt_btn() -> void:
	pass
func should_show_results(percentage: float, cutoffs: Array[float]) -> void:
	super.should_show_results(percentage,cutoffs)
	results_star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	results_star_container.add_theme_constant_override("separation",16)
	for star in results_star_container.get_children():
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star.custom_minimum_size = Vector2(64,64)
		star.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
func on_main_menu() -> void:
	level.back_to_menu()
func on_restart_level() -> void:
	level.retry()
func on_next_level() -> void:
	pass
