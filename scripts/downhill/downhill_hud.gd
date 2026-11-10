extends CanvasLayer

var level: Node3D
var classic: Control
var counters: Label
var status: Label
var prompt: Label
var progress: ProgressBar
var modal: PanelContainer
var title: Label
var details: Label
var resume: Button
var arrows: Label
var wind: Control
var pause_button: Button
var retry_button: Button
var results_built := false
var camera_icon: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	wind = preload("res://scripts/downhill/downhill_wind.gd").new()
	wind.level = level
	root.add_child(wind)
	wind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	classic = preload("res://scenes/ui.tscn").instantiate()
	classic.set_script(preload("res://scripts/downhill/downhill_ui_adapter.gd"))
	classic.level = level
	root.add_child(classic)
	classic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var saved_bar: ProgressBar = classic.get_node("ProgressBar")
	saved_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	saved_bar.position = Vector2(24,48)
	saved_bar.size = Vector2(280,12)
	saved_bar.show_percentage = false
	slim_bar(saved_bar,Color("eed57a"))
	saved_bar.size.y = 12
	for star in classic.star_indicators:
		star.scale = Vector2.ONE*0.5
	progress = ProgressBar.new()
	progress.position = Vector2(24,94)
	progress.size = Vector2(280,6)
	progress.hide()
	progress.max_value = 300
	progress.show_percentage = false
	slim_bar(progress,Color("69d4d5"))
	progress.size.y = 6
	root.add_child(progress)
	progress.size = Vector2(280,6)
	counters = label("",18)
	counters.position = Vector2(24,18)
	root.add_child(counters)
	status = label("",15)
	status.position = Vector2(24,110)
	root.add_child(status)
	status.hide()
	prompt = label("",24)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	prompt.offset_left = -240
	prompt.offset_right = 240
	prompt.offset_top = 160
	prompt.offset_bottom = 230
	var hint: Control = classic.get_node("Control")
	hint.set_script(preload("res://scripts/downhill/downhill_controls_hint.gd"))
	hint.scale = Vector2.ONE*0.62
	hint.pivot_offset_ratio = Vector2.ZERO
	hint.offset_left = 10
	hint.offset_top = -66
	arrows = label("",15)
	root.add_child(arrows)
	arrows.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	arrows.offset_left = -350
	arrows.offset_right = -16
	arrows.offset_top = 20
	arrows.offset_bottom = 44
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows.hide()
	camera_icon = preload("res://scripts/downhill/downhill_camera_icon.gd").new()
	root.add_child(camera_icon)
	camera_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	camera_icon.offset_left = -180
	camera_icon.offset_right = -20
	camera_icon.offset_top = 20
	camera_icon.offset_bottom = 78
	var actions := label("Bark: LMB | Sprint: Shift | Switch view: RMB | Wheel: Zoom", 18)
	actions.name = "ActionHints"
	root.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	actions.offset_left = 125
	actions.offset_top = -61
	actions.offset_bottom = -32
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.offset_left = -182
	buttons.offset_right = -16
	buttons.offset_top = -48
	buttons.offset_bottom = -14
	pause_button = button("Pause",level.toggle_pause)
	retry_button = button("Restart",level.retry)
	buttons.add_child(pause_button)
	buttons.add_child(retry_button)
	modal = classic.get_node("Results Screen")
	modal.offset_left = -225
	modal.offset_right = 225
	modal.offset_top = -165
	modal.offset_bottom = 165
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08,0.14,0.17,0.98)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	modal.add_theme_stylebox_override("panel",style)
	var stack: VBoxContainer = modal.get_node("VBoxContainer")
	stack.add_theme_constant_override("separation",12)
	title = stack.get_node("Label")
	title.add_theme_font_size_override("font_size",26)
	details = label("",18)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(details)
	stack.move_child(details,1)
	resume = button("Resume",level.toggle_pause)
	stack.add_child(resume)
	modal.hide()

func label(text: String, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("fff3d7"))
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	node.add_theme_constant_override("shadow_offset_y",2)
	return node
func slim_bar(bar: ProgressBar, color: Color) -> void:
	bar.add_theme_font_size_override("font_size",1)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04,0.1,0.1,0.6)
	bg.set_corner_radius_all(3)
	var fill := bg.duplicate()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background",bg)
	bar.add_theme_stylebox_override("fill",fill)
func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(78,32)
	node.pressed.connect(action)
	return node
func update_display() -> void:
	counters.text = "Saved %d/%d" % [level.saved,level.initial]
	var actions: Label = camera_icon.get_parent().get_node("ActionHints")
	var width := level.get_viewport().get_visible_rect().size.x
	actions.add_theme_font_size_override("font_size", 15 if width < 1100 else 18)
	progress.value = level.progress_z
	classic.update_progress(level.survival())
	for i in classic.star_indicators.size():
		classic.star_indicators[i].position.x = classic.star_percentages[i]*280
	var camera = level.get_viewport().get_camera_3d()
	camera_icon.dog_only = camera.dog_only
	prompt.modulate.a = 1.0
	prompt.text = ""
	if level.phase == level.Phase.COUNTDOWN:
		prompt.text = "Gather your herd\n%d" % maxi(1,ceili(level.countdown_left))
	elif level.notice_left > 0:
		prompt.text = level.notice
		if level.notice == "HERD SPLIT!":
			prompt.modulate.a = minf(1.0, level.notice_left * 3) * (0.8 + 0.2 * sin(level.notice_left * 20))
	var results: bool = level.phase == level.Phase.RESULTS
	if results and not results_built:
		var cutoffs: Array[float] = [0.6,0.8,0.95]
		classic.should_show_results(level.survival(),cutoffs)
		results_built = true
	modal.visible = get_tree().paused or results
	if modal.visible:
		# Main's shared UI hides the Classic win heading for zero-star results.
		# This mode has its own meaningful loss/pause heading in the same node.
		title.show()
		title.text = ("Herd home!" if level.saved > 0 else "Herd lost") if results else "Paused"
		details.text = "%d / %d saved  |  %d lost\n%d / 3 stars" % [level.saved,level.initial,level.lost,level.stars()] if results else "The herd is waiting."
		resume.visible = not results
	pause_button.disabled = results
