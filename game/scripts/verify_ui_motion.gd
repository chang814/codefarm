extends SceneTree
## Interaction regression + real renderer captures for the 0.2.8 UI.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(seconds: float = 0.32) -> void:
	await create_timer(seconds).timeout
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image:
		image.save_png("res://../shots/" + name + ".png")

func mouse(point: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = point
	e.global_position = point
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	root.push_input(e, true)

func motion(point: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = point
	e.global_position = point
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	mouse(point, true)
	mouse(point, false)

func same_rect(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 1.0 and a.size.distance_to(b.size) < 1.0

func text_button(node: Node, label: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == label:
			return child
		var found := text_button(child, label)
		if found:
			return found
	return null

func controls_and_harvest_checks(main: Node) -> void:
	main.call("_close_panel", true)
	root.size = Vector2i(1440, 900)
	await settle()
	# Drive normal actions in exact budgets; animation timers still run.
	main.set_process(false)
	main.editor.text = main.STARTER
	main.run_loop_button.pressed.emit()
	main.host.advance_seconds(1.1)
	main.call("_process", 0.0)
	check(main.host.get_hay() == 1 and main.host.is_finished(), "solid triangle runs main once")
	main.host.advance_seconds(1.1)
	check(main.host.get_hay() == 1, "solid run stays stopped after completion")
	# Reproduce reset with a header active and old files present.
	main.code_files.call("switch_to", "old.hpp")
	main.editor.text = "void old() {}"
	main.code_files.call("flush_active")
	click(main.settings_button)
	await settle()
	click(text_button(main.overlay_body, "重置农场"))
	await settle()
	click(text_button(main.overlay_body, "取消"))
	await settle()
	check(main.host.get_hay() == 1 and not main.get("_reset_confirming"), "reset cancellation preserves progress")
	click(text_button(main.overlay_body, "重置农场"))
	await settle()
	click(text_button(main.overlay_body, "确认重置"))
	await settle()
	check(main.host.get_hay() == 0 and main.editor.text == main.STARTER.replace("\r", ""), "reset confirmation restores farm and editor")
	check(main.code_files.get("active_file") == "main.cpp" and main.code_files.get("user_files").size() == 1, "reset clears user files")
	check(main.editor.protect_framework, "reset restores main framework protection from an active header")
	main.editor.text = main.STARTER.replace("harvest();", "harvest();\n    harvest();")
	for expected in [1, 2]:
		main.run_once_button.pressed.emit()
		main.host.step_seconds(1.1)
		main.call("_process", 0.0)
		check(main.host.get_hay() == expected and not main.host.is_running(), "hollow triangle steps one action " + str(expected))
	main.call("_confirm_reset")
	await settle()
	for i in 5:
		main.run_loop_button.pressed.emit()
		main.host.advance_seconds(1.1)
		main.call("_process", 0.0)
	click(main.skill_button)
	await settle()
	var card: Control = main.skill_tree.scroll.find_child("Skill_loop", true, false)
	click(card)
	await settle(0.5)
	check(main.host.loops_unlocked(), "skill node buys with earned hay")
	card = main.skill_tree.scroll.find_child("Skill_loop", true, false)
	click(card)
	await settle()
	var detail: Control = main.skill_tree.detail
	click(detail.find_child("CopyTemplate", true, false))
	check(main.last_copied_template == main.FarmSkillData.exemplar("loop"), "detail copy uses shared exemplar")
	main.editor.text = main.STARTER.replace("harvest();", "do_a_flip();")
	click(detail.find_child("InsertTemplate", true, false))
	check(main.editor.text == main.FarmSkillData.exemplar("loop"), "load exemplar replaces full program instead of nesting main")
	check(main.host.load_script(main.editor.text).is_empty(), "loaded exemplar compiles")
	for node in detail.find_children("*", "Button", true, false):
		if node.tooltip_text == "关闭":
			click(node)
			break
	await settle()
	check(not detail.visible, "skill detail close button")
	click(main.overlay_close)
	await settle()
	main.run_loop_button.pressed.emit()
	main.host.advance_seconds(10.0)
	main.call("_process", 0.0)
	main.run_loop_button.pressed.emit()
	check(not main.host.is_running(), "solid triangle stops a running loop")
	click(main.skill_button)
	await settle()
	card = main.skill_tree.scroll.find_child("Skill_speed", true, false)
	main.skill_tree.scroll.ensure_control_visible(card)
	await settle()
	click(card)
	await settle(0.5)
	check(main.host.speed_unlocked() and not main.host.conditions_unlocked(), "speed bought before Conditions")
	check(main.hint_next_code.text.contains("if (can_harvest()) harvest();") and main.hint_body_label.text.contains("挥空"), "speed hint points to the next lesson immediately")
	click(main.overlay_close)
	await settle()
	# Remove old success strands by letting their normal lifetime finish.
	await settle(0.7)
	# A stopped loop may leave half-grown grass; ordinary idle time finishes it.
	main.host.advance_seconds(1.0)
	main.editor.text = main.FarmSkillData.exemplar("speed")
	main.run_loop_button.pressed.emit()
	main.host.advance_seconds(0.025) # includes the while-condition query tick
	main.call("_process", 0.0)
	check(main.host.last_action_success(), "first accelerated swing succeeds")
	await settle(0.7)
	var hay: int = main.host.get_hay()
	main.host.advance_seconds(0.5)
	main.call("_process", 0.0)
	check(not main.host.last_action_success() and main.bot.get("harvesting"), "miss starts its own swing animation")
	check(main.host.get_hay() == hay and main.juice_anchor.get_child_count() == 0, "miss has no income or reward particles")
	await settle(0.12)
	await capture("ui-028-miss")
	main.host.advance_seconds(0.4975)
	main.call("_process", 0.0)
	check(not main.host.grass_mature() and not main.host.last_action_success(), "blind fast swings keep resetting the young grass")
	check(main.host.get_hay() == hay and main.juice_anchor.get_child_count() == 0, "repeated misses cannot turn into success feedback")
	main.call("_on_stop")
	main.host.advance_seconds(1.0)
	main.call("_process", 0.0)
	check(main.host.grass_mature(), "stopping the loop lets the young grass recover")
	check(main.host.get_hay() == hay and main.juice_anchor.get_child_count() == 0, "idle ripening gives no harvest income or rewards")
	main.set_process(true)

func window_checks(main: Node) -> void:
	var win = main.code_window
	var original: Rect2 = win.get_rect()
	var hint_original: Rect2 = main.hint_window.get_rect()
	var camera: Vector3 = main.camera_rig.get("target")
	click(win.max_button)
	check(win.maximized, "actual maximize button changes state")
	check(same_rect(win.get_rect(), original), "docking listener must not snap maximize geometry")
	var target: Rect2 = win.call("_max_rect")
	var previous: Rect2 = original
	for frame in 10:
		await settle(0.024)
		var current: Rect2 = win.get_rect()
		check(current.size.x >= previous.size.x - 1.0, "maximize width grows monotonically")
		check(current.size.x <= target.size.x + 1.0, "maximize never overshoots")
		if frame == 2:
			check(not same_rect(current, original) and not same_rect(current, target), "intermediate geometry exists")
			await capture("ui-028-max-mid")
		previous = current
	await settle()
	check(same_rect(win.get_rect(), target), "maximize fills usable bounds")
	check(win.position.y == win.max_top_margin and win.get_rect().end.y <= root.size.y - 63, "maximize respects toolbar and docked hint")
	check(main.hint_window.minimized, "hint docks during maximize")
	check(main.camera_rig.get("target") == camera, "chrome click cannot pan the farm")
	await capture("ui-028-max")
	click(win.max_button)
	await settle()
	check(same_rect(win.get_rect(), original), "restore returns original rect")
	check(same_rect(main.hint_window.get_rect(), hint_original) and not main.hint_window.minimized, "hint restores original rect")
	# Reverse before either transition has completed; destinations must survive.
	for i in 4:
		win.max_button.pressed.emit()
		await settle(0.025)
	await settle()
	check(not win.maximized and same_rect(win.get_rect(), original), "rapid maximize/restore preserves original rect")
	for from_max in [false, true]:
		if from_max:
			win.max_button.pressed.emit()
			await settle()
		win.min_button.pressed.emit()
		await settle()
		check(win.minimized and not win.body.visible, "minimize hides body")
		win.max_button.pressed.emit()
		await settle()
		check(win.maximized and not win.minimized and win.body.visible, "maximize from minimized expands body")
		win.max_button.pressed.emit()
		await settle()
		check(same_rect(win.get_rect(), original), "minimize/maximize never replaces restore with chip rect")
	# Window chrome close, topbar reopen, including reversal during close.
	click(win.close_button)
	check(win.is_closing(), "close chrome starts close transition")
	await settle(0.035)
	click(main.code_btn)
	await settle()
	check(win.visible and not win.is_closing() and is_equal_approx(win.modulate.a, 1.0), "topbar reopens during close")
	click(win.close_button)
	await settle()
	check(not win.visible, "close chrome actually hides window")
	click(main.code_btn)
	await settle()
	check(win.visible and same_rect(win.get_rect(), original), "code topbar restores hidden window")
	# Actual title and resize-corner input after maximizing/restoring.
	var point: Vector2 = win.title_label.get_global_rect().get_center()
	mouse(point, true)
	motion(point + Vector2(45, 28))
	mouse(point + Vector2(45, 28), false)
	check(win.position.distance_to(original.position + Vector2(45, 28)) < 1.0, "title drag works after restore")
	var old_size: Vector2 = win.size
	point = win.resize_handle.get_global_rect().get_center()
	mouse(point, true)
	motion(point + Vector2(35, 22))
	mouse(point + Vector2(35, 22), false)
	check(win.size.distance_to(old_size + Vector2(35, 22)) < 1.0, "corner resize works after restore")
	check(not win.get("_dragging") and not win.get("_resizing"), "release ends pointer gestures")
	win.call("_apply_rect", original)
	win.max_button.pressed.emit()
	await settle(0.04)
	root.size = Vector2i(1100, 720)
	await settle()
	check(same_rect(win.get_rect(), win.call("_max_rect")), "viewport resize cancels stale maximize target")
	win.max_button.pressed.emit()
	await settle()
	check(win.get_rect().end.x <= root.size.x and win.get_rect().end.y <= root.size.y, "restore fits smaller viewport")
	root.size = Vector2i(1440, 900)
	await settle()
	win.call("_apply_rect", original)
	main.hint_window.call("_apply_rect", hint_original)
	# Same chrome for hint window; its closure must not be undone by docking.
	var hint = main.hint_window
	click(hint.min_button)
	await settle()
	check(hint.minimized, "hint minimize button")
	click(hint.min_button)
	await settle()
	click(hint.max_button)
	await settle()
	check(hint.maximized, "hint maximize button")
	win.max_button.pressed.emit()
	await settle()
	win.max_button.pressed.emit()
	await settle()
	check(hint.maximized, "docking restores a previously maximized hint")
	click(hint.max_button)
	await settle()
	check(same_rect(hint.get_rect(), hint_original), "hint restore button")
	click(hint.close_button)
	await settle()
	check(not hint.visible, "hint close button")
	click(main.hint_button)
	await settle()
	check(hint.visible, "hint topbar opens window")
	var expanded: bool = main.get("_hint_exemplar_open")
	click(main.hint_exemplar_toggle)
	await settle()
	check(main.get("_hint_exemplar_open") != expanded, "hint exemplar disclosure button")
	click(main.hint_copy_button)
	await settle(0.04)
	check(main.get("last_copied_template") == main.FarmSkillData.exemplar("harvest"), "hint copies exact shared exemplar")
	click(main.hint_copy_button)
	await settle()
	check(main.hint_copied_label.visible, "repeated copy renews feedback")
	# Restore camera through its actual topbar control.
	main.camera_rig.set("yaw", float(main.camera_rig.call("home_yaw")) + 0.5)
	# 0.2.9: reset and changelog live in the settings panel, not the top bar.
	click(main.settings_button)
	await settle()
	check(main.reset_cam_button.is_visible_in_tree(), "settings panel hosts camera reset")
	click(main.reset_cam_button)
	await settle(0.45)
	click(main.overlay_close)
	await settle()
	check(not main.reset_cam_button.is_visible_in_tree(), "camera reset leaves with the panel")
	check(absf(float(main.camera_rig.get("yaw")) - float(main.camera_rig.call("home_yaw"))) < 0.01, "camera reset button")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.start_on_farm = true
	root.add_child(main)
	await settle(0.6)
	await window_checks(main)
	for button in [main.code_btn, main.skill_button, main.hint_button, main.settings_button, main.log_button, main.reset_cam_button, main.run_loop_button, main.run_once_button]:
		check(absf(button.size.x - button.size.y) < 1.0, "icon button must be square: " + button.name)
	var button: Button = main.code_btn
	button.mouse_entered.emit()
	await settle(0.22)
	check(button.scale.x > 1.0, "hover feedback")
	button.button_down.emit()
	await settle(0.12)
	check(button.scale.x < 1.0, "press feedback")
	button.button_up.emit()
	button.mouse_exited.emit()
	await settle()
	check(button.scale.is_equal_approx(Vector2.ONE), "button returns to rest")
	await capture("ui-028-default")
	click(main.settings_button)
	await settle()
	var fonts = main.overlay_body.find_child("FontOptions", true, false)
	click(fonts.buttons["20"])
	await settle()
	check(int(main.editor_assist.get("font_size")) == 20, "font option applied")
	check(fonts.indicator.position.distance_to(fonts.buttons["20"].position) < 0.5, "font selection glides into place")
	for value in ["16", "18", "20"]:
		click(fonts.buttons[value])
		await settle()
		check(int(main.editor_assist.get("font_size")) == int(value), "font button " + value)
	await capture("ui-028-settings")
	# The modal backdrop intentionally owns input until its close button is used.
	click(main.log_button)
	await settle()
	check(main.get("_open_panel") == "log", "settings log button opens changelog")
	click(main.overlay_close)
	await settle()
	click(main.settings_button)
	await settle()
	for id in ["skill", "log", "settings", "skill", "log", "settings"]:
		click(main.get("_panel_tabs").buttons[id])
		await settle(0.035)
	await settle()
	check(main.get("_open_panel") == "settings", "last requested panel wins")
	check(absf(main.overlay_body.position.x) < 0.1, "content translation settles")
	check(is_equal_approx(main.overlay_body.modulate.a, 1.0), "content opacity restores")
	var tabs = main.get("_panel_tabs")
	var selected: Button = tabs.buttons["settings"]
	check(tabs.indicator.position.distance_to(selected.position) < 0.5, "selection aligns after interruption")
	click(main.overlay_close)
	await settle(0.04)
	main.call("_toggle_panel", "skill")
	await settle()
	check(main.overlay_card.visible and main.backdrop.visible, "reopen interrupts close")
	await capture("ui-028-skills")
	root.size = Vector2i(1280, 800)
	await settle()
	var bounds: Rect2 = main.overlay_card.get_global_rect()
	check(bounds.position.y >= 0 and bounds.end.y <= root.get_visible_rect().size.y + 1, "overlay fits smaller desktop")
	await capture("ui-028-1280")
	click(main.overlay_close)
	await settle(0.035)
	root.size = Vector2i(1200, 740)
	await settle()
	check(not main.overlay_card.visible and not main.backdrop.visible, "resize during close cannot leave an input-blocking backdrop")
	await controls_and_harvest_checks(main)
	print("UI_MOTION_OK" if failures == 0 else "UI_MOTION_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
