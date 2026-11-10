extends SceneTree
## Exercise the real Quit button while MP3 playback is active. The strict runner
## also checks engine shutdown diagnostics, which catch retained mixer resources.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var menu = load("res://scenes/main_menu/main_menu_3d.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(0.5).timeout
	if not root.get_node("Global").audio_manager.bgm.playing:
		push_error("Title music must be playing before Quit is exercised")
		quit(1)
		return
	print("MENU QUIT failures=0; exercising live-music Quit")
	menu.get_node("MainMenu/VBoxContainer/QuitButton").pressed.emit()
