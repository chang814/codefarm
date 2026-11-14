extends SceneTree
## Progress persistence and welcome screen: save, reopen, restore, recover from
## a damaged file. Uses its own save file; never touches the player's progress.
const SAVE := "user://verify_save_test.json"
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle(seconds := 0.3) -> void:
	await create_timer(seconds).timeout
	await process_frame

func wipe() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))

func open_game() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await settle(0.5)
	return main

func close_game(main: Node) -> void:
	main.call("_save_now")
	root.remove_child(main)
	main.free()
	await settle(0.1)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	wipe()
	# Fresh start: welcome screen with a reachable start button.
	var main = await open_game()
	var start: Button = main.get("_start_button")
	check(main.get("_session_phase") == "menu", "fresh launch shows the welcome screen")
	check(start != null and start.text == "开始游戏", "fresh launch offers 开始游戏")
	var view := Rect2(Vector2.ZERO, Vector2(root.size))
	check(start != null and view.encloses(start.get_global_rect()), "start button is on screen")
	var title: Control = main.get("_menu").get_child(0)
	check(view.encloses(title.get_global_rect()), "welcome title is on screen")
	check(not main.ui_root.visible, "game UI stays hidden behind the welcome screen")
	# A real click on the button enters the farm.
	var point := start.get_global_rect().get_center()
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = point
		e.global_position = point
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e, true)
	await settle(2.4)
	check(main.get("_session_phase") == "playing", "clicking start enters the farm")
	check(main.ui_root.visible, "game UI appears after the intro")
	# Earn something by actually running the starter program, and edit the code.
	main.call("_on_run_once")
	await settle(1.6)
	var hay := int(main.host.get_hay())
	check(hay == 1, "starter program harvests one hay, got %d" % hay)
	var code := str(main.editor.text).replace("    harvest();", "    harvest();\n    harvest();")
	main.editor.text = code
	main.call("_on_editor_text_changed")
	main.call("_set_sound_level", 1)
	for sound in ["harvest", "miss", "till", "stuck", "flip", "unlock", "deny"]:
		check(main.audio.has_sound(sound), "sound is synthesized: " + sound)
	var world_before := str(main.host.save_state())
	await close_game(main)
	check(FileAccess.file_exists(SAVE), "closing writes a save file")

	# Reopen: continue, same hay, same code, same world.
	main = await open_game()
	start = main.get("_start_button")
	check(start != null and start.text == "继续游戏", "saved game offers 继续游戏")
	check(int(main.host.get_hay()) == hay, "hay survives a restart")
	check(str(main.editor.text) == code, "player code survives a restart")
	check(int(main.get("_sound_level")) == 1 and main.audio.level == 1, "sound setting survives a restart")
	check(str(main.host.save_state()) == world_before, "world state survives a restart byte for byte")
	main.start_game()
	await settle(2.4)
	main.call("_on_run_once")
	await settle(2.6)
	check(int(main.host.get_hay()) > hay, "restored farm keeps playing")
	hay = int(main.host.get_hay())
	await close_game(main)
	check(FileAccess.file_exists(SAVE + ".bak"), "previous save is kept as a backup")

	# Damage the main file: the backup takes over and says so.
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string("{ not a save")
	f.close()
	main = await open_game()
	check(int(main.host.get_hay()) >= 1, "damaged save falls back to the backup")
	check(str(main.get("_save_message")).contains("备份"), "backup recovery is announced")
	root.remove_child(main)
	main.free()

	# Damage both: a new farm, never a crash.
	for suffix in ["", ".bak"]:
		f = FileAccess.open(SAVE + suffix, FileAccess.WRITE)
		f.store_string("garbage")
		f.close()
	main = await open_game()
	check(int(main.host.get_hay()) == 0, "two damaged files start a new farm")
	check(str(main.get("_save_message")).contains("损坏"), "damaged save is announced")
	check(main.get("_start_button").text == "开始游戏", "new farm offers 开始游戏")
	root.remove_child(main)
	main.free()
	wipe()
	if failures == 0:
		print("SAVE_OK")
		quit(0)
	else:
		print("SAVE_FAILED: ", failures)
		quit(1)
