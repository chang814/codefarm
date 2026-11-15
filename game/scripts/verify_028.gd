extends SceneTree
## Focused UI/geometry regression. Progress is earned with ordinary actions.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(seconds: float = 0.3) -> void:
	await create_timer(seconds).timeout
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../shots/" + name + ".png")

func earn(main: Node, amount: int) -> void:
	while main.host.get_hay() < amount:
		main.host.stop()
		main.host.advance_seconds(1.1)
		check(main.host.load_script(main.STARTER) == "", "starter parses")
		main.host.start()
		main.host.advance_seconds(1.1)
	main.host.stop()

func assert_eyes(rig: Node3D, snapshots: Array) -> void:
	for i in 2:
		var eye: Node3D = rig.get_node("EyeLeft" if i == 0 else "EyeRight")
		check(eye.transform.is_equal_approx(snapshots[i]), "eye local transform stays fixed")
		check(eye.get_child(0).transform.is_equal_approx(Transform3D.IDENTITY), "eye mesh never scales or rotates")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.start_on_farm = true
	root.add_child(main)
	await settle()
	main.set_process(false)
	var data = main.FarmSkillData
	var nodes: Array = data.nodes(main.host)
	check(nodes.size() == 39 and data.edges().size() == 38, "all skills remain on one connected learning tree")
	for node in nodes:
		var rect := Rect2(node.pos, data.CARD_SIZE)
		check(Rect2(Vector2.ZERO, data.CANVAS_SIZE).encloses(rect), "node fits canvas: " + node.id)
		for other in nodes:
			if node.id != other.id:
				check(not rect.intersects(Rect2(other.pos, data.CARD_SIZE)), "cards do not overlap")
		check(not data.next_line(node.id).is_empty(), "focused code exists: " + node.id)
	check(data.prerequisite_text("tree").contains("运算") and data.prerequisite_text("mega").contains("引用"), "combined prerequisites remain discoverable")
	check(data.prerequisite_text("timing").contains("或"), "alternative prerequisites are distinguished")
	await earn(main, 5)
	check(main.buy_skill("loop") == 0, "buy loop normally")
	await earn(main, 8)
	check(main.buy_skill("speed") == 0, "buy speed normally")
	main.hint_skill_id = "speed"
	main.call("_apply_hint_text")
	check(main.hint_next_code.text == "if (can_harvest()) harvest();", "speed points directly at condition line")
	check(main.hint_next_label.text.contains("条件"), "preview names the required skill")
	check(main.hint_code.text == data.exemplar("speed") and not main.hint_code.text.contains("if ("), "speed exemplar adds no locked concept")
	check(not main.host.conditions_unlocked(), "condition stays locked during preview")
	main.code_window.visible = false
	await settle()
	await capture("ui-028-hint-default")
	main.hint_window.reveal(Rect2(20, 360, 620, 520))
	await settle()
	await capture("ui-028-hint-speed")
	await earn(main, 12)
	check(main.buy_skill("iff") == 0, "buy condition normally")
	main.hint_skill_id = "iff"
	main.call("_apply_hint_text")
	main.hint_copy_button.pressed.emit()
	check(main.last_copied_template == data.exemplar("iff"), "copy keeps exact complete shared exemplar")
	main.editor.text = main.STARTER
	main.hint_load_button.pressed.emit()
	check(main.editor.text == data.exemplar("iff") and main.editor.text.count("int main()") == 1, "hint load replaces rather than inserts main")
	check(main.host.load_script(main.editor.text) == "", "loaded condition exemplar parses")
	await settle()
	await capture("ui-028-hint-condition")
	await earn(main, 20)
	main.hint_window.visible = false
	main.call("_toggle_panel", "skill")
	await settle()
	var scroll = main.skill_scroll
	scroll.fit_all()
	await settle()
	await capture("ui-028-skills-overview")
	# Keep a readable full-canvas artifact as well as the normal-size overview.
	root.size = Vector2i(1440, 2300)
	await settle()
	main.overlay_card.offset_top = -1100
	main.overlay_card.offset_bottom = 1100
	scroll.zoom_about(1.0, Vector2.ZERO)
	await settle()
	for card in scroll.find_children("Skill_*", "PanelContainer", true, false):
		if card.has_meta("skill_id"):
			check(card.size.is_equal_approx(data.CARD_SIZE), "prices do not expand card geometry: " + card.name)
			card.mouse_entered.emit()
			card.mouse_exited.emit()
			check(card.scale.is_equal_approx(Vector2.ONE), "hover keeps line joints stable")
	await capture("ui-028-skills-full")
	root.size = Vector2i(1280, 800)
	await settle()
	scroll.fit_all()
	await settle()
	await capture("ui-028-skills-1280")
	root.size = Vector2i(1200, 740)
	await settle()
	scroll.fit_all()
	await settle()
	check(scroll.canvas_size.y * scroll.zoom <= scroll.size.y, "overview also fits the smaller desktop")
	# View state survives a rebuild and settings round-trip.
	scroll.zoom_about(1.3, Vector2.ZERO)
	await settle()
	scroll.scroll_vertical = 700
	main.call("_fill_panel", "skill")
	await settle()
	check(is_equal_approx(main.skill_scroll.zoom, 1.3) and main.skill_scroll.scroll_vertical == 700, "tree rebuild preserves zoom and position")
	main.call("_fill_panel", "settings")
	main.call("_fill_panel", "skill")
	await settle()
	check(is_equal_approx(main.skill_scroll.zoom, 1.3) and main.skill_scroll.scroll_vertical == 700, "settings round-trip preserves tree view")
	main.call("_close_panel", true)
	root.size = Vector2i(1440, 900)
	await settle()
	var rig: Node3D = main.bot.get("rig")
	var body: MeshInstance3D = rig.get_node("Body")
	check(body.mesh is SphereMesh and is_equal_approx(body.mesh.height, body.mesh.radius * 2.0), "main body is a true sphere")
	var snapshots := [rig.get_node("EyeLeft").transform, rig.get_node("EyeRight").transform]
	var extras: Dictionary = main.bot.call("spawn_extra_drone", 1)
	var extra_rig: Node3D = extras.rig
	check(extra_rig.get_node("Body").mesh is SphereMesh, "additional machines use the same sphere")
	check(extra_rig.get_node("Body").material_override.albedo_color == body.material_override.albedo_color, "fleet stays milk yellow")
	var extra_snapshots := [extra_rig.get_node("EyeLeft").transform, extra_rig.get_node("EyeRight").transform]
	extras.node.visible = false
	for success in [true, false]:
		main.bot.call("play_harvest_swing", success)
		for frame in 25:
			await process_frame
			assert_eyes(rig, snapshots)
		await settle(0.45)
	main.bot.call("play_till")
	await settle(0.12)
	assert_eyes(rig, snapshots)
	await settle(0.6)
	for frame in 180:
		main.bot.call("animate", 1.0 / 60.0, true, Vector3.RIGHT)
		assert_eyes(rig, snapshots)
		assert_eyes(extra_rig, extra_snapshots)
		await process_frame
	# Front camera targets the actual bot, not the origin of a later big field.
	main.set("_shot_hide_plants", true)
	main.call("_update_grass", 0.0)
	rig.rotation = Vector3.ZERO
	main.camera.size = 1.0
	main.camera.position = main.drone.global_position + Vector3(0, 0.02, 2)
	main.camera.look_at(main.drone.global_position + Vector3(0, 0.02, 0))
	await settle()
	await capture("ui-028-bot-front")
	main.bot.call("play_harvest_swing", false)
	await settle(0.12)
	assert_eyes(rig, snapshots)
	await capture("ui-028-bot-miss")
	print("REFINE_028_OK" if failures == 0 else "REFINE_028_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
