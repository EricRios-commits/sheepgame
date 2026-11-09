extends CanvasLayer

var level: Node3D
var counters: Label
var status: Label
var prompt: Label
var progress: ProgressBar
var modal: PanelContainer
var title: Label
var details: Label
var resume: Button
var arrows: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	root.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	counters = label("", 26)
	stack.add_child(counters)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 10
	progress.show_percentage = false
	progress.max_value = 300
	stack.add_child(progress)
	status = label("", 19)
	stack.add_child(status)
	prompt = label("", 36)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -360
	prompt.offset_right = 360
	prompt.offset_top = -85
	prompt.offset_bottom = 45
	root.add_child(prompt)
	var controls := label("WASD  Move    SHIFT  Sprint    E / LEFT CLICK  Bark    SPACE  Jump    ESC  Pause", 18)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -48
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(controls)
	arrows = label("", 20)
	arrows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	arrows.offset_top = -82
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(arrows)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -245
	modal.offset_right = 245
	modal.offset_top = -185
	modal.offset_bottom = 185
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.14, 0.17, 0.97)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.set_corner_radius_all(16)
	modal.add_theme_stylebox_override("panel", style)
	root.add_child(modal)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	modal.add_child(buttons)
	title = label("", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(title)
	details = label("", 22)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(details)
	resume = button("Resume", level.toggle_pause)
	buttons.add_child(resume)
	buttons.add_child(button("Retry  [R]", level.retry))
	buttons.add_child(button("Back to Menu", level.back_to_menu))
	modal.hide()

func label(text: String, size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color("fff3d7"))
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.add_theme_font_size_override("font_size", 22)
	node.pressed.connect(action)
	return node

func update_display() -> void:
	counters.text = "DOWNHILL HERD     Saved %d / %d     Lost %d     Remaining %d" % [level.saved, level.initial, level.lost, level.remaining()]
	var z: float = level.flock_center().z
	progress.value = level.progress_z
	var bark = level.dog.bark
	status.text = "%dm to barn   |   %s   |   %s" % [maxi(0, int(300 - z)),
		"BARK READY" if bark.cooldown_left <= 0 else "Bark %.1fs" % bark.cooldown_left,
		"Flock split - work the flanks" if level.split else "Herd together"]
	if level.phase == level.Phase.RESULTS:
		status.text = "Round complete   |   R to retry"
	prompt.text = ""
	if level.phase == level.Phase.COUNTDOWN:
		prompt.text = "Gather your herd\n%d" % maxi(1, ceili(level.countdown_left))
	elif level.notice_left > 0:
		prompt.text = level.notice
	modal.visible = get_tree().paused or level.phase == level.Phase.RESULTS
	if modal.visible:
		var results: bool = level.phase == level.Phase.RESULTS
		title.text = ("Herd home!" if level.saved > 0 else "Herd lost") if results else "Paused"
		details.text = "%d / %d saved  -  %.1f%%\n%d / 3 stars   |   %d lost" % [level.saved, level.initial,
			level.survival() * 100, level.stars(), level.lost] if results else "The herd is waiting."
		resume.visible = not results
	# Exceptional stragglers get a direction instead of unlimited camera zoom.
	var camera := level.get_viewport().get_camera_3d()
	var left := 0
	var right := 0
	var behind := 0
	for p in level.living_positions():
		var world := Vector3(p.x, level.system.ground.height_at(p), p.y)
		if camera.is_position_behind(world):
			behind += 1
		else:
			var screen := camera.unproject_position(world)
			var viewport_size := level.get_viewport().get_visible_rect().size
			if screen.x < 0:
				left += 1
			elif screen.x > viewport_size.x:
				right += 1
			elif screen.y < 0 or screen.y > viewport_size.y:
				behind += 1
	arrows.text = ""
	if left + right + behind > 0:
		arrows.text = "Offscreen sheep:   < %d     > %d     ahead / behind %d" % [left, right, behind]
