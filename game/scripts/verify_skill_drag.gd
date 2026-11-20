extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	await create_timer(0.28).timeout
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
func run() -> void:
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.start_on_farm = true
	root.add_child(main)
	await settle()
	# Earn the loop price with ordinary harvest actions.
	for i in 5:
		main.host.load_script(main.editor.text)
		main.host.start()
		main.host.advance_seconds(1.1)
	main.call("_toggle_panel", "skill")
	await settle()
	var scroll = main.skill_tree.scroll
	scroll.zoom_about(1.5, Vector2.ZERO)
	await settle()
	scroll.scroll_horizontal = 150
	scroll.scroll_vertical = 200
	await settle()
	var point: Vector2 = scroll.global_position + Vector2(150, 200)
	mouse(point, true)
	motion(point - Vector2(70, 100))
	await process_frame
	mouse(point - Vector2(70, 100), false)
	check(scroll.scroll_horizontal == 220 and scroll.scroll_vertical == 300, "left drag pans both axes")
	var release_y: int = scroll.scroll_vertical
	await create_timer(0.08).timeout
	check(scroll.scroll_vertical > release_y, "release glides briefly in the drag direction")
	await create_timer(0.55).timeout
	var settled_y: int = scroll.scroll_vertical
	await create_timer(0.3).timeout
	check(absi(scroll.scroll_vertical - settled_y) <= 1, "glide settles quickly")
	scroll.zoom_about(1.0, Vector2.ZERO)
	await settle()
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	await settle()
	var card: Control = scroll.find_child("Skill_loop", true, false)
	point = card.get_global_rect().get_center()
	var hay: int = main.host.get_hay()
	mouse(point, true)
	motion(point - Vector2(40, 40))
	mouse(point - Vector2(40, 40), false)
	await settle()
	check(not main.host.loops_unlocked() and main.host.get_hay() == hay, "dragging an affordable node does not purchase")
	scroll.scroll_horizontal = 0
	scroll.scroll_vertical = 0
	await settle()
	point = card.get_global_rect().get_center()
	mouse(point, true)
	motion(point + Vector2(2, 1))
	mouse(point + Vector2(2, 1), false)
	await settle()
	check(main.host.loops_unlocked(), "small motion remains a click and buys the node")
	scroll = main.skill_tree.scroll
	card = scroll.find_child("Skill_loop", true, false)
	point = card.get_global_rect().get_center()
	mouse(point, true)
	mouse(point, false)
	await settle()
	check(main.skill_tree.detail.visible, "clicking owned node opens details")
	var before := Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)
	point = main.skill_tree.detail.get_global_rect().get_center()
	mouse(point, true)
	motion(point - Vector2(30, 50))
	mouse(point - Vector2(30, 50), false)
	check(Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) == before, "detail panel does not pan the tree")
	main.skill_tree.call("close_detail")
	await settle()
	point = scroll.global_position + Vector2(50, 150)
	mouse(point, true)
	motion(point - Vector2(0, 50))
	mouse(Vector2(4, 4), false)
	check(not scroll.get("_held"), "release outside clears drag")
	mouse(point, true)
	scroll.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not scroll.get("_held"), "focus loss clears drag")
	# Real wheel input zooms around its cursor, without moving the farm camera.
	scroll.zoom_about(1.2, Vector2.ZERO)
	await settle()
	scroll.scroll_vertical = 300
	point = scroll.global_position + Vector2(350, 220)
	var anchor: Vector2 = point - scroll.global_position
	var logical: Vector2 = (Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) + anchor - scroll.canvas.position) / scroll.zoom
	var camera_before: Transform3D = main.camera.transform
	var wheel := InputEventMouseButton.new()
	wheel.position = point
	wheel.global_position = point
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	await settle()
	check(scroll.zoom > 1.2, "wheel zooms the tree")
	var after_logical: Vector2 = (Vector2(scroll.scroll_horizontal, scroll.scroll_vertical) + anchor - scroll.canvas.position) / scroll.zoom
	check(logical.distance_to(after_logical) < 2.0, "wheel keeps the cursor's canvas position")
	check(main.camera.transform == camera_before, "skill wheel does not zoom the farm")
	scroll.fit_all()
	await settle()
	check(scroll.canvas_size.y * scroll.zoom < scroll.size.y and scroll.scroll_vertical == 0, "overview shows the final row")
	main.skill_tree.click("loop")
	await settle()
	var zoom_before: float = scroll.zoom
	wheel.position = main.skill_tree.detail.get_global_rect().get_center()
	root.push_input(wheel, true)
	await settle()
	check(scroll.zoom == zoom_before and main.skill_tree.detail.scale.is_equal_approx(Vector2.ONE), "detail stays fixed and blocks background zoom")
	main.skill_tree.call("close_detail")
	await settle()
	scroll.zoom_about(1.0, Vector2.ZERO)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../shots/ui-028-skill-drag.png")
	print("SKILL_DRAG_OK" if failures == 0 else "SKILL_DRAG_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
