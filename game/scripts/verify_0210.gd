extends SceneTree
## 0.2.10 regressions: the bot stays on its tile under rapid repeats, the
## welcome close-up is unobstructed, scenery stays outside the field, skills
## have their own icons, and the welcome screen reports what the save holds.
const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmSkillData := preload("res://scripts/skill_data.gd")
const FarmLayout := preload("res://scripts/farm_layout.gd")
const SAVE := "user://verify_0210_test.json"
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

func _run() -> void:
	root.size = Vector2i(1440, 900)
	wipe()
	var main = await open_game()

	# Welcome close-up: nothing visible stands between the camera and the bot.
	var bot: Vector3 = main.drone.global_position
	var blocked := 0
	var tucked: Array = main.get("_portrait_hidden")
	for key in main.field.get("plots"):
		var plot: Dictionary = main.field.get("plots")[key]
		for blade in plot["blades"]:
			var pivot: Node3D = blade["pivot"]
			if pivot.visible and pivot.global_position.z > bot.z - 0.10 and absf(pivot.global_position.x - bot.x) < 0.62:
				blocked += 1
	check(blocked == 0, "welcome close-up has %d blades in front of the bot" % blocked)
	check(not tucked.is_empty(), "foreground blades are tucked away for the portrait")
	check(not main.field.scenery.get("_decor").visible, "scenery decoration is hidden behind the portrait")
	main.start_game()
	await settle(2.4)
	check((main.get("_portrait_hidden") as Array).is_empty(), "blades return when the game starts")
	check(main.field.scenery.get("_decor").visible, "scenery returns when the game starts")
	var hidden_after := 0
	for key in main.field.get("plots"):
		for blade in main.field.get("plots")[key]["blades"]:
			if not (blade["pivot"] as Node3D).visible:
				hidden_after += 1
	check(hidden_after == 0, "no blade stays hidden after the intro")

	# Scenery: plenty of it, and none of it on the field.
	var field_half := float(main.host.get_world_size()) * FarmLayout.TILE_SPACING * 0.5
	check(main.field.scenery.decoration_count() > 150, "meadow has decoration")
	check(main.field.scenery.nearest_decoration() > field_half + 0.9, "decoration keeps off the field and its pad")
	check(main.field.get("meadow").material_override is ShaderMaterial, "meadow uses the patch and cloud shader")

	# Rapid repeats must not walk the bot off its tile.
	var rig: Node3D = main.bot.get("rig")
	for i in 14:
		main.bot.call("play_stuck")
		await create_timer(0.03).timeout
	await settle(0.8)
	check(absf(rig.position.x) < 0.001, "rapid shakes leave the rig centred, x=%f" % rig.position.x)
	check(absf(rig.rotation.z) < 0.12, "rapid shakes leave the rig upright")
	for i in 5:
		main.bot.call("play_flip")
		await create_timer(0.07).timeout
	await settle(1.2)
	var base := float(main.bot.get("base_y"))
	check(absf(main.drone.position.y - base) < 0.03, "rapid flips land at standing height, y=%f" % main.drone.position.y)
	var tile: Vector3 = main.field.call("tile_world", 0, 0)
	check(absf(main.drone.position.x - tile.x) < 0.01 and absf(main.drone.position.z - tile.z - 0.06) < 0.01, "bot stands on its tile after rapid actions")
	# The same through the real path: a failing program run again and again.
	main.editor.text = str(main.editor.text).replace("harvest();", "harvset();")
	for i in 10:
		main.call("_on_run")
		await create_timer(0.05).timeout
	await settle(0.9)
	check(absf(rig.position.x) < 0.001, "repeated failing runs leave the rig centred")

	# Icons: each skill reads as its own picture.
	var kinds := {}
	var ids := 0
	for node in FarmSkillData.nodes(main.host):
		var id := str(node["id"])
		ids += 1
		var kind: int = FarmIcon.kind_from_name(id)
		check(kind != FarmIcon.Kind.CHECK, "skill has an icon: " + id)
		kinds[kind] = true
	check(kinds.size() >= ids - 4, "skills share at most a few icons: %d kinds for %d skills" % [kinds.size(), ids])
	for id in ["hats", "maze", "debug", "timing", "array", "rec", "swenum", "include", "sim", "mega"]:
		check(FarmIcon.kind_from_name(id) != FarmIcon.Kind.LOG and FarmIcon.kind_from_name(id) != FarmIcon.Kind.MOVE and FarmIcon.kind_from_name(id) != FarmIcon.Kind.VARS, "no longer a borrowed icon: " + id)

	# Earn one hay, close, reopen: the welcome screen says what it read.
	main.editor.text = main.STARTER
	main.call("_on_run")
	await settle(1.6)
	check(int(main.host.get_hay()) == 1, "one harvest before closing")
	main.call("_save_now")
	root.remove_child(main)
	main.free()
	await settle(0.1)
	main = await open_game()
	var notice: Label = main.get("_save_notice")
	check(main.get("_start_button").text == "继续游戏", "saved game offers 继续游戏")
	check(notice.text.contains("已读取存档") and notice.text.contains("干草 1"), "welcome screen reports the save: " + notice.text)
	main.persistence_enabled = false
	root.remove_child(main)
	main.free()
	wipe()
	print("REFINE_0210_OK" if failures == 0 else "REFINE_0210_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
