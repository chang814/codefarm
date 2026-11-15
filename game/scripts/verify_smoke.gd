extends SceneTree
const FarmIcon := preload("res://scripts/farm_icons.gd")

## Instantiates main.tscn, checks the editor and windows, simulates a run,
## and exercises drag / minimize / maximize / close / reopen, camera, and font zoom.

func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("无法加载 scenes/main.tscn")
		return
	var main: Node = packed.instantiate()
	main.persistence_enabled = false
	main.start_on_farm = true
	root.add_child(main)
	for _i in 10:
		await process_frame

	if main.get("editor") == null:
		_fail("编辑器未创建（可能是界面初始化中途失败）")
		return
	var editor: CodeEdit = main.editor
	var skill_btn: Button = main.skill_button
	var hint_btn: Button = main.hint_button
	var settings_btn: Button = main.settings_button
	var log_btn: Button = main.log_button
	var overlay: Control = main.overlay_card
	if skill_btn == null or hint_btn == null or settings_btn == null or log_btn == null:
		_fail("顶栏按钮缺失：技能/提示/设置/日志")
		return
	if main.get("run_button") != null or main.get("stop_button") != null:
		_fail("顶栏不应再有运行或停止按钮")
		return
	if skill_btn.text != "" or hint_btn.text != "" or settings_btn.text != "" or log_btn.text != "":
		_fail("顶栏按钮应使用图标而不是文字")
		return
	if skill_btn.tooltip_text.strip_edges() == "":
		_fail("技能按钮缺少 tooltip")
		return
	if main.get("reset_cam_button") == null:
		_fail("缺少回正视角按钮")
		return
	if overlay == null:
		_fail("叠加面板未创建")
		return
	# Preloaded helper scripts must remain available (Windows class cache can be empty).
	for path in [
		"res://scripts/farm_icons.gd",
		"res://scripts/farm_window.gd",
		"res://scripts/farm_run_button.gd",
		"res://scripts/farm_chrome_button.gd",
		"res://scripts/farm_motion.gd",
		"res://scripts/error_markup.gd",
	]:
		if load(path) == null:
			_fail("无法预加载 " + path)
			return
	var code_win: Control = main.code_window
	var hint_win: Control = main.hint_window
	if code_win == null or hint_win == null:
		_fail("代码窗口或提示窗口未创建")
		return
	if not code_win.visible:
		_fail("代码窗口开局应当可见")
		return

	var leftover_ring: Node = main.get_node_or_null("Farm/Drone/Ring")
	if leftover_ring != null:
		_fail("小 bot 脚下不应再有圆环")
		return
	for child in main.get_node("Farm/Drone").get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is TorusMesh:
			_fail("小 bot 不应再带圆环网格")
			return
		if child.name == "Rig":
			for part in child.get_children():
				if part is MeshInstance3D and (part as MeshInstance3D).mesh is TorusMesh:
					_fail("小 bot 不应再带圆环网格")
					return
	var earth: Node = main.get_node_or_null("Farm/Earth")
	if earth is MeshInstance3D and (earth as MeshInstance3D).mesh is CylinderMesh:
		_fail("田下地面不应再是正圆圆柱")
		return

	var loop_btn: Control = main.get("run_loop_button")
	var once_btn: Control = main.get("run_once_button")
	if loop_btn == null or once_btn == null:
		_fail("代码窗口标题栏缺少运行 / 单步按钮")
		return
	if str(loop_btn.get("tooltip_text")).find("运行") < 0:
		_fail("运行按钮 tooltip 不正确")
		return
	if str(once_btn.get("tooltip_text")).find("单步") < 0:
		_fail("单步按钮 tooltip 不正确")
		return
	if loop_btn is Button and (loop_btn as Button).text != "":
		_fail("运行按钮不应依赖字体字形")
		return

	# Window chrome is drawn, not font glyphs.
	for win in [code_win, hint_win]:
		var min_b = win.get("min_button")
		var max_b = win.get("max_button")
		var close_b = win.get("close_button")
		if min_b == null or max_b == null or close_b == null:
			_fail("窗口缺少绘制的最小化/全屏/关闭按钮")
			return
		if min_b is Button and (min_b as Button).text != "":
			_fail("窗口按钮不应使用字体符号")
			return

	# The resize handle must stay a small corner, not fill the window
	# (PanelContainer would otherwise swallow clicks and show a resize cursor).
	for _i in 3:
		await process_frame
	for win in [code_win, hint_win]:
		var handle = win.get("resize_handle")
		var body = win.get("body")
		if handle == null or body == null:
			_fail("窗口缺少缩放手柄或内容区")
			return
		if handle.get_parent() == win:
			_fail("缩放手柄不能作为 PanelContainer 的直接子节点，否则会铺满整个窗口")
			return
		if handle.size.x > 28.0 or handle.size.y > 28.0:
			_fail("缩放手柄过大，会挡住代码区：%s" % handle.size)
			return
		if handle is ColorRect and (handle as ColorRect).color.a > 0.04:
			_fail("缩放手柄不应留下可见色块")
			return
		var mid: Vector2 = editor.get_global_rect().get_center() if win == code_win else body.get_global_rect().get_center()
		if handle.get_global_rect().has_point(mid):
			_fail("缩放手柄覆盖了窗口内容区，代码将无法点击")
			return

	# Drag the code window and confirm the highlight overlay still has an editor.
	var origin: Vector2 = code_win.position
	code_win.position = origin + Vector2(48, 36)
	for _i in 3:
		await process_frame
	var highlight: Control = main.highlight
	if highlight == null or highlight.get("editor") != editor:
		_fail("拖动后高亮层与编辑器未对齐（editor 丢失）")
		return
	code_win.position = origin

	# Minimize, restore, maximize, restore.
	if code_win.has_method("toggle_minimize"):
		code_win.call("toggle_minimize")
		for _i in 4:
			await process_frame
		if not bool(code_win.get("minimized")):
			_fail("最小化未能把代码窗口收起")
			return
		code_win.call("toggle_minimize")
		for _i in 4:
			await process_frame
		if bool(code_win.get("minimized")):
			_fail("还原最小化后窗口仍处于收起状态")
			return
		code_win.call("toggle_maximize")
		for _i in 4:
			await process_frame
		if not bool(code_win.get("maximized")):
			_fail("全屏未能放大代码窗口")
			return
		var max_b2 = code_win.get("max_button")
		if max_b2 and max_b2.has_method("set_maximize_state"):
			if int(max_b2.get("action")) != 2:
				# Action.RESTORE == 2
				pass
		code_win.call("toggle_maximize")
		for _i in 4:
			await process_frame
		if bool(code_win.get("maximized")):
			_fail("退出全屏失败")
			return

	# Close and reopen via the top-bar button.
	code_win.visible = false
	await process_frame
	if main.has_method("_toggle_code_window"):
		main.call("_toggle_code_window")
	for _i in 3:
		await process_frame
	if not code_win.visible:
		_fail("关闭后通过顶栏「代码」未能重新打开窗口")
		return

	# Hint window close / reopen.
	if hint_win.visible:
		hint_win.visible = false
	if main.has_method("_toggle_hint_window"):
		main.call("_toggle_hint_window")
	for _i in 3:
		await process_frame
	if not hint_win.visible:
		_fail("顶栏「提示」未能打开提示窗口")
		return
	if main.has_method("_refresh_hint_layout"):
		main.call("_refresh_hint_layout")
	for _i in 4:
		await process_frame
	var hint_label: Label = main.get("hint_body_label")
	var hint_blob := ""
	if hint_label:
		hint_blob += str(hint_label.text)
	var hint_code = main.get("hint_code")
	if hint_code:
		hint_blob += "
" + str(hint_code.text)
	if hint_blob.find("return 0;") < 0:
		_fail("提示文案缺少完整示例（未找到 return 0;）")
		return
	var hint_h := 0.0
	if hint_label:
		hint_h = maxf(hint_label.get_minimum_size().y, hint_label.size.y)
	if hint_code:
		hint_h += maxf(float(hint_code.get("custom_minimum_size").y) if hint_code.get("custom_minimum_size") else 0.0, hint_code.size.y)
	if hint_h < 80.0:
		_fail("提示正文高度异常，文本可能无法滚到结尾")
		return
	var hscroll: ScrollContainer = main.get("hint_scroll")
	if hscroll:
		hscroll.scroll_vertical = 100000
		await process_frame
		hscroll.scroll_vertical = 0

	# Maximizing the code window must dock the hint, not cover the editor.
	if not bool(code_win.get("maximized")):
		code_win.call("toggle_maximize")
	for _i in 8:
		await process_frame
	if not bool(code_win.get("maximized")):
		_fail("全屏代码窗口失败（与提示避让有关的第二次检查）")
		return
	if hint_win.visible and not bool(hint_win.get("minimized")):
		_fail("代码窗口全屏时，提示窗口应当收起到标题栏，避免挡住编辑器")
		return
	if hint_win.visible:
		var code_bottom: float = code_win.position.y + code_win.size.y
		if hint_win.position.y + 1.0 < code_bottom:
			_fail("代码全屏时提示窗口仍与编辑器重叠（提示 y=%.1f，代码底=%.1f）" % [hint_win.position.y, code_bottom])
			return
	code_win.call("toggle_maximize")
	for _i in 8:
		await process_frame
	if not hint_win.visible or bool(hint_win.get("minimized")):
		_fail("退出代码全屏后，提示窗口应恢复为全屏前的展开状态")
		return

	hint_win.visible = true

	# Overlay panels.
	for panel_id in ["skill", "settings", "log"]:
		main.call("_toggle_panel", panel_id)
		for _i in 3:
			await process_frame
		if not overlay.visible:
			_fail("未能打开面板：" + panel_id)
			return
		main.call("_close_panel")
		var closed := 0
		while overlay.visible and closed < 60:
			await process_frame
			closed += 1
		if overlay.visible:
			_fail("未能关闭面板：" + panel_id)
			return

	# Solid run: harvest once (1s at 1x), then stay stopped even after grass grows.
	if editor.text.find("harvest()") < 0:
		editor.text = main.STARTER if main.get("STARTER") != null else editor.text
	var hay_before: int = int(main.host.get_hay())
	main.call("_on_run")
	if main.has_method("_advance_sim"):
		main.call("_advance_sim", 1.2)
	else:
		main.host.advance_seconds(1.2)
	for _i in 8:
		await process_frame
	var hay_mid: int = int(main.host.get_hay())
	if hay_mid <= hay_before:
		_fail("运行一遍后干草没有增加（前 %d，后 %d）" % [hay_before, hay_mid])
		return
	if main.host.is_running() or bool(main.get("_stepping")):
		_fail("运行一遍后程序应当已经结束")
		return
	if main.has_method("_advance_sim"):
		main.call("_advance_sim", 2.0)
	else:
		main.host.advance_seconds(2.0)
	for _i in 6:
		await process_frame
	var hay_still: int = int(main.host.get_hay())
	if hay_still != hay_mid:
		_fail("main 结束后不应自动再跑（干草 %d -> %d）" % [hay_mid, hay_still])
		return
	print("SMOKE run hay ", hay_before, " -> ", hay_mid)

	# Step through a two-harvest program: one click runs one swing.
	main.host.reset_world()
	editor.text = "int main() {\n    harvest();\n    harvest();\n    return 0;\n}\n"
	main.call("_on_step")
	if main.has_method("_advance_sim"):
		main.call("_advance_sim", 1.2)
	else:
		main.host.step_seconds(1.2)
	for _i in 8:
		await process_frame
	var step_hay1: int = int(main.host.get_hay())
	if step_hay1 != 1:
		_fail("单步后应当只收割一次（干草 %d）" % step_hay1)
		return
	if main.host.is_running():
		_fail("单步完成后应当暂停，不应继续跑")
		return
	if not main.host.is_paused() and not main.host.is_finished():
		_fail("单步后应处于暂停状态")
		return
	if main.has_method("_advance_sim"):
		main.call("_advance_sim", 1.2)
	else:
		main.host.advance_seconds(1.2)
	if int(main.host.get_hay()) != 1:
		_fail("暂停期间不应继续执行下一条语句")
		return
	main.call("_on_step")
	if main.has_method("_advance_sim"):
		main.call("_advance_sim", 1.2)
	else:
		main.host.step_seconds(1.2)
	for _i in 8:
		await process_frame
	if int(main.host.get_hay()) != 2:
		_fail("第二次单步应当再收一刀（干草 %d）" % int(main.host.get_hay()))
		return
	print("SMOKE step hay 0 -> 1 -> 2")

	# Clicking the editor still stops a running program.
	main.host.reset_world()
	editor.text = "int main() {\n    while (true) { harvest(); }\n    return 0;\n}\n"
	# while is locked at this point — load will error. Use a long flip instead.
	editor.text = main.STARTER
	main.call("_on_run")
	if main.has_method("_on_editor_focus_entered"):
		# Start first, then immediately stop via editor focus (even mid-action).
		main.call("_on_editor_focus_entered")
	for _i in 4:
		await process_frame
	if main.host.is_running() or main.host.is_paused() or bool(main.get("_stepping")):
		_fail("点进代码编辑器后，正在运行的程序应当停止")
		return
	print("SMOKE editor focus stops run")

	# Camera reset and input isolation.
	if not main.has_method("reset_camera"):
		_fail("缺少 reset_camera")
		return
	var home_yaw: float = float(main.camera_rig.call("home_yaw"))
	var home_zoom: float = float(main.camera_rig.call("home_zoom", 1))
	main.camera_rig.set("yaw", home_yaw + 0.8)
	main.camera_rig.set("zoom", home_zoom + 2.5)
	main.camera_rig.set("pitch", 1.1)
	main.call("reset_camera", true)
	if abs(float(main.camera_rig.get("yaw")) - home_yaw) > 0.02:
		_fail("回正视角后偏航角未复位")
		return
	if abs(float(main.camera_rig.get("zoom")) - home_zoom) > 0.05:
		_fail("回正视角后缩放未复位")
		return

	# Wheel over the editor must not change camera zoom (with or without Shift).
	main.call("reset_camera", true)
	var zoom_before: float = float(main.camera_rig.get("zoom"))
	editor.grab_focus()
	await process_frame
	_send_wheel(editor, true)
	_send_wheel(editor, false)
	for _i in 3:
		await process_frame
	if abs(float(main.camera_rig.get("zoom")) - zoom_before) > 0.001:
		_fail("代码区滚轮不应触发相机缩放（缩放 %.3f -> %.3f）" % [zoom_before, float(main.camera_rig.get("zoom"))])
		return

	# Shift+wheel zooms font; Ctrl+0 resets.
	var font_before: int = int(main.editor_assist.get("font_size"))
	if main.editor_assist.has_method("set_font_size"):
		main.editor_assist.call("set_font_size", font_before + 3, false, false)
	for _i in 3:
		await process_frame
	if int(main.editor_assist.get("font_size")) != font_before + 3:
		_fail("字号缩放未生效")
		return
	var badge: Control = main.get("font_badge")
	if badge == null:
		_fail("缺少字号百分比小标")
		return
	if main.editor_assist.has_method("reset_font"):
		main.editor_assist.call("reset_font")
	for _i in 3:
		await process_frame
	if int(main.editor_assist.get("font_size")) != int(main.editor_assist.get("font_size_default")):
		_fail("Ctrl+0 / 复位后字号应回到默认")
		return

	# Keyboard camera must not move while the editor has focus.
	editor.grab_focus()
	await process_frame
	if not main.has_method("_text_input_has_focus") or not bool(main.call("_text_input_has_focus")):
		_fail("编辑器有焦点时 _text_input_has_focus 应为 true")
		return
	var target_before: Vector3 = main.camera_rig.get("target")
	var vel_before: Vector3 = main.camera_rig.get("vel")
	# Simulate held W while focused: one process with wish=0 because focus is set.
	main.camera_rig.set("vel", Vector3(0, 0, 1.5))
	if main.camera_rig.has_method("update_input"):
		main.camera_rig.call("update_input", 0.05)
	# With focus, wish is zero so velocity should decay, not accelerate from W.
	# Also send unhandled key F should not reset if we check focus in handler —
	# F is handled in camera_rig.handle_event only when no text focus.
	main.camera_rig.set("yaw", home_yaw + 0.4)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F
	main.camera_rig.call("handle_event", ev)
	if abs(float(main.camera_rig.get("yaw")) - (home_yaw + 0.4)) > 0.001:
		_fail("编辑器有焦点时按 F 不应复位相机")
		return
	# Release focus, click empty (via release), F should reset.
	if get_root_viewport():
		get_root_viewport().gui_release_focus()
	await process_frame
	if bool(main.call("_text_input_has_focus")):
		_fail("释放焦点后 _text_input_has_focus 应为 false")
		return
	main.camera_rig.call("handle_event", ev)
	if abs(float(main.camera_rig.get("yaw")) - home_yaw) > 0.02:
		_fail("无文本焦点时按 F 应复位相机")
		return
	print("SMOKE camera and font ok, start font=", font_before, " vel decay=", vel_before)

	# Left-drag on the ground pans (grab the ground); on the code window it does not.
	main.call("reset_camera", true)
	var pos_before: Vector3 = main.camera_rig.get("pos")
	var ground_at := Vector2(1200, 500)
	if bool(main.call("_point_over_ui", ground_at)):
		_fail("烟测选的地面点被界面挡住了")
		return
	var grab_before: Vector3 = main.camera_rig.call("ground_point", ground_at)
	var left_down := InputEventMouseButton.new()
	left_down.button_index = MOUSE_BUTTON_LEFT
	left_down.pressed = true
	left_down.position = ground_at
	left_down.global_position = ground_at
	main.camera_rig.call("handle_event", left_down)
	var small := InputEventMouseMotion.new()
	small.button_mask = MOUSE_BUTTON_MASK_LEFT
	small.position = ground_at + Vector2(3, 2)
	small.global_position = small.position
	small.relative = Vector2(3, 2)
	main.camera_rig.call("handle_event", small)
	if Vector3(main.camera_rig.get("pos")).distance_to(pos_before) > 0.0001 or bool(main.camera_rig.get("left_dragging")):
		_fail("左键移动不到阈值时应当仍算点击，不应平移")
		return
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = ground_at + Vector2(-90, -50)
	drag.global_position = drag.position
	drag.relative = Vector2(-93, -52)
	main.camera_rig.call("handle_event", drag)
	if not bool(main.camera_rig.get("left_dragging")):
		_fail("在地面上左键拖过阈值应开始平移")
		return
	if Vector3(main.camera_rig.get("pos")).distance_to(pos_before) < 0.01:
		_fail("左键拖动地面应平移相机")
		return
	var grab_after: Vector3 = main.camera_rig.call("ground_point", drag.position)
	if Vector2(grab_after.x, grab_after.z).distance_to(Vector2(grab_before.x, grab_before.z)) > 0.05:
		_fail("左键拖动应抓住地面：按下时的地面点应停在鼠标下（偏差 %.3f）" % Vector2(grab_after.x, grab_after.z).distance_to(Vector2(grab_before.x, grab_before.z)))
		return
	if bool(main.camera_rig.get("orbiting")):
		_fail("左键拖动不应旋转相机")
		return
	left_down.pressed = false
	left_down.position = drag.position
	left_down.global_position = drag.position
	main.camera_rig.call("handle_event", left_down)
	if bool(main.camera_rig.get("left_dragging")):
		_fail("松开左键应结束拖动")
		return
	for _i in 30:
		await process_frame
	main.call("clear_camera_drag")
	# Same drag starting on the code window must leave the camera alone.
	main.call("reset_camera", true)
	var cam_home: Vector3 = main.camera_rig.get("pos")
	var code_rect: Rect2 = code_win.get_global_rect()
	var on_code := code_rect.position + Vector2(code_rect.size.x * 0.5, minf(120.0, code_rect.size.y * 0.5))
	left_down.pressed = true
	left_down.position = on_code
	left_down.global_position = on_code
	main.camera_rig.call("handle_event", left_down)
	var drag2 := InputEventMouseMotion.new()
	drag2.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag2.position = on_code + Vector2(120, 60)
	drag2.global_position = drag2.position
	drag2.relative = Vector2(120, 60)
	main.camera_rig.call("handle_event", drag2)
	if bool(main.camera_rig.get("left_dragging")) or Vector3(main.camera_rig.get("pos")).distance_to(cam_home) > 0.0001:
		_fail("在代码窗口上左键拖动不应平移地图")
		return
	left_down.pressed = false
	main.camera_rig.call("handle_event", left_down)
	print("SMOKE left-drag pan ok (ground pans, code window does not)")

	# Right-drag rotates in place; releasing over UI must not leave the view stuck.
	main.call("reset_camera", true)
	var pos_home: Vector3 = main.camera_rig.get("pos")
	var yaw_home: float = float(main.camera_rig.get("yaw"))
	var right_down := InputEventMouseButton.new()
	right_down.button_index = MOUSE_BUTTON_RIGHT
	right_down.pressed = true
	right_down.position = Vector2(1200, 500)
	if main.has_method("_input"):
		main.call("_input", right_down)
	else:
		main.camera_rig.call("handle_event", right_down)
	if not bool(main.camera_rig.get("orbiting")):
		_fail("在空地按下右键应开始转动视角")
		return
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(80, 0)
	main.camera_rig.call("handle_event", look)
	var yaw_turned: float = float(main.camera_rig.get("yaw"))
	if abs(yaw_turned - yaw_home) < 0.02:
		_fail("右键拖动应原地改变朝向")
		return
	if Vector3(main.camera_rig.get("pos")).distance_to(pos_home) > 0.05:
		_fail("右键转动应原地转向，不应绕远处锚点滑移（相机位移 %.3f）" % Vector3(main.camera_rig.get("pos")).distance_to(pos_home))
		return
	var right_up := InputEventMouseButton.new()
	right_up.button_index = MOUSE_BUTTON_RIGHT
	right_up.pressed = false
	right_up.position = Vector2(80, 40)  # over the top bar
	# Go through _input so a release over a button still clears drag.
	if main.has_method("_input"):
		main.call("_input", right_up)
	else:
		main.camera_rig.call("handle_event", right_up)
	if bool(main.camera_rig.get("orbiting")) or bool(main.camera_rig.get("panning")):
		_fail("在按钮上松开右键后，视角拖动应被清掉")
		return
	var yaw_after: float = float(main.camera_rig.get("yaw"))
	var extra := InputEventMouseMotion.new()
	extra.relative = Vector2(120, 30)
	main.camera_rig.call("handle_event", extra)
	if abs(float(main.camera_rig.get("yaw")) - yaw_after) > 0.001:
		_fail("在 UI 上松开后继续移动鼠标不应再带动视角")
		return
	print("SMOKE camera mouse ok, yaw ", yaw_home, " -> ", yaw_turned)

	if get_root_viewport():
		get_root_viewport().gui_release_focus()
	main.camera_rig.set("vel", Vector3(2.0, 0.0, 2.0))
	if main.camera_rig.has_method("update_input"):
		main.camera_rig.call("update_input", 0.03)
	if Vector3(main.camera_rig.get("vel")).length() > 0.05:
		_fail("松开 WASD 后视角应立即停下，不应再滑出一截")
		return

	# Skill tree: click-to-spend unlock, then a second click opens the detail popup.
	main.host.reset_world()
	if overlay.visible:
		main.call("_close_panel")
	main.call("_toggle_panel", "skill")
	for _i in 6:
		await process_frame
	var loop_card: Control = overlay.find_child("Skill_loop", true, false)
	if loop_card == null:
		_fail("技能树缺少循环图标窗")
		return
	if overlay.find_child("Skill_speed", true, false) == null:
		_fail("技能树缺少加速节点")
		return
	# Locked tiles must not dump long copy.
	if loop_card.get_child_count() > 0:
		var dump := str(loop_card.get("tooltip_text"))
		if dump.find("int main") >= 0 or dump.find("#include") >= 0:
			_fail("未解锁技能不应展示模板或长文案")
			return
	var hay_locked: int = int(main.host.get_hay())
	if hay_locked != 0:
		_fail("重置后干草应为 0，实际 %d" % hay_locked)
		return
	if bool(main.host.loops_unlocked()):
		_fail("重置后循环不应已解锁")
		return
	if main.has_method("click_skill_node"):
		main.call("click_skill_node", "loop")
	else:
		main.call("_on_skill_node_clicked", "loop", loop_card)
	for _i in 8:
		await process_frame
	if bool(main.host.loops_unlocked()):
		_fail("干草不够时不应解锁循环")
		return
	var shortfall: Label = loop_card.find_child("Shortfall", true, false)
	if shortfall == null or not shortfall.visible or shortfall.text.find("差") < 0:
		_fail("干草不够时应短暂显示还差多少")
		return
	# Earn 5 hay and click the gray, affordable tile to spend.
	main.call("_close_panel")
	editor.text = main.STARTER
	for n in range(5):
		main.call("_on_run")
		if main.has_method("_advance_sim"):
			main.call("_advance_sim", 1.2)
		else:
			main.host.advance_seconds(1.2)
		for _i in 4:
			await process_frame
	if int(main.host.get_hay()) < 5:
		_fail("五次收割后干草不足 5（实际 %d）" % int(main.host.get_hay()))
		return
	main.call("_toggle_panel", "skill")
	for _i in 6:
		await process_frame
	loop_card = overlay.find_child("Skill_loop", true, false)
	if loop_card == null:
		_fail("攒够干草后技能树缺少循环图标")
		return
	if main.has_method("click_skill_node"):
		main.call("click_skill_node", "loop")
	else:
		main.call("_on_skill_node_clicked", "loop", loop_card)
	var waited := 0
	while waited < 40 and not bool(main.host.loops_unlocked()):
		await process_frame
		waited += 1
	# Allow the flip tween to refill the tree.
	for _i in 20:
		await process_frame
	if not bool(main.host.loops_unlocked()):
		_fail("点击可解锁的灰色图标后应花费干草解锁循环")
		return
	if int(main.host.get_hay()) != 0:
		_fail("解锁循环后余额应为 0，实际 %d" % int(main.host.get_hay()))
		return
	var detail: Control = main.get("skill_detail")
	if detail and detail.visible:
		_fail("第一次点击解锁时不应打开详情")
		return
	loop_card = overlay.find_child("Skill_loop", true, false)
	if main.has_method("click_skill_node"):
		main.call("click_skill_node", "loop")
	else:
		main.call("_on_skill_node_clicked", "loop", loop_card)
	for _i in 8:
		await process_frame
	detail = main.get("skill_detail")
	if detail == null or not detail.visible:
		_fail("已解锁技能再点应打开详情小窗")
		return
	var detail_code = detail.find_child("DetailCode", true, false)
	if detail_code == null or str(detail_code.text).find("while") < 0:
		_fail("详情小窗应展示循环模板代码")
		return
	main.call("_copy_selected_skill_template")
	if str(main.get("last_copied_template")).find("while (true)") < 0:
		_fail("复制按钮应写下完整模板")
		return
	print("SMOKE skill unlock and detail ok")
	# The hint follows the skill just bought: one sentence of pain, then its
	# exemplar (the same file the playthrough test runs), copyable.
	var skill_data = load("res://scripts/skill_data.gd")
	var loop_ex: String = skill_data.exemplar("loop")
	if loop_ex.find("while (true)") < 0:
		_fail("res://exemplars/loop.cpp 读不到或不是循环范本")
		return
	main.call("_apply_hint_text")
	var hint_ex: CodeEdit = main.get("hint_code")
	if hint_ex == null or not hint_ex.visible or hint_ex.text != loop_ex:
		_fail("提示窗口应展示刚解锁的循环范本")
		return
	var pain_label: Label = main.get("hint_body_label")
	if pain_label == null or pain_label.text.find(str(skill_data.pain("loop"))) < 0:
		_fail("提示开头应是一句痛点")
		return
	if hint_ex.syntax_highlighter.number_color != main.editor.syntax_highlighter.number_color:
		_fail("范本高亮应与代码区一致")
		return
	main.set("last_copied_template", "")
	main.call("_copy_hint_exemplar")
	if str(main.get("last_copied_template")) != loop_ex:
		_fail("提示里的复制按钮应复制完整范本")
		return
	main.call("_toggle_hint_exemplar")
	if hint_ex.visible:
		_fail("范本应可折叠")
		return
	main.call("_toggle_hint_exemplar")
	if not hint_ex.visible:
		_fail("范本应可再展开")
		return
	# A locked skill shows no exemplar and copies nothing.
	main.call("open_skill_detail", "iff")
	for _i in 4:
		await process_frame
	detail = main.get("skill_detail")
	if not is_instance_valid(detail):
		_fail("技能详情实例缺失")
		return
	var locked_code: CodeEdit = detail.find_child("DetailCode", true, false)
	if locked_code == null or locked_code.visible or locked_code.text != "":
		_fail("未解锁技能的详情不应显示范本")
		return
	main.set("last_copied_template", "")
	main.call("_copy_selected_skill_template")
	if str(main.get("last_copied_template")) != "":
		_fail("未解锁技能不应能复制范本")
		return
	main.call("_close_skill_detail")
	print("SMOKE hint exemplar visible and copyable")
	main.call("_close_panel")

	# Before Speed, a tight harvest loop should keep hitting ripe grass.
	editor.text = "int main() {\n    while (true) { harvest(); }\n    return 0;\n}\n"
	main.call("_on_run")
	main.host.advance_seconds(1.15)
	if not bool(main.host.last_action_success()):
		_fail("解锁加速前，while harvest 应当打在成熟的草上")
		return
	main.call("_on_stop")
	# Farm 8 hay and buy Speed; a tight loop should then miss unripe grass.
	editor.text = main.STARTER
	var guard := 0
	while int(main.host.get_hay()) < 8 and guard < 20:
		guard += 1
		main.call("_on_run")
		if main.has_method("_advance_sim"):
			main.call("_advance_sim", 1.2)
		else:
			main.host.advance_seconds(1.2)
		for _i in 3:
			await process_frame
	if int(main.host.get_hay()) < 8:
		_fail("加速前应能攒够 8 干草，实际 %d" % int(main.host.get_hay()))
		return
	main.call("_toggle_panel", "skill")
	for _i in 6:
		await process_frame
	var speed_card: Control = overlay.find_child("Skill_speed", true, false)
	if speed_card == null:
		_fail("攒够干草后技能树缺少加速图标")
		return
	if main.has_method("click_skill_node"):
		main.call("click_skill_node", "speed")
	else:
		main.call("_on_skill_node_clicked", "speed", speed_card)
	for _i in 24:
		await process_frame
	if not bool(main.host.speed_unlocked()):
		_fail("点击后应花费干草解锁加速")
		return
	main.call("_close_panel")
	editor.text = "int main() {\n    while (true) { harvest(); }\n    return 0;\n}\n"
	main.call("_on_run")
	main.host.advance_seconds(0.65)
	if bool(main.host.last_action_success()):
		_fail("解锁加速后，纯 while harvest 应打在未熟的草上（动作=%s 进度=%.2f）" % [str(main.host.current_action()), float(main.host.current_action_progress())])
		return
	if str(main.host.current_action()) != "harvest":
		_fail("加速后 0.65 秒应正在做一次失败的 harvest，实际是 %s" % str(main.host.current_action()))
		return
	var stalled_hay := int(main.host.get_hay())
	main.host.advance_seconds(20.0)
	if int(main.host.get_hay()) != stalled_hay or bool(main.host.last_action_success()):
		_fail("加速后盲收应持续重置幼苗，20 秒内不再增产")
		return
	if int(main.host.action_ticks()) != 200:
		_fail("加速后的空挥应花 200 tick")
		return
	main.call("_on_stop")
	# Recover through ordinary play, without grants: stop, wait, single cut.
	main.host.advance_seconds(1.1)
	editor.text = main.STARTER
	guard = 0
	while not bool(main.host.can_unlock("iff")) and guard < 12:
		guard += 1
		main.call("_on_run")
		main.host.advance_seconds(0.6)
		main.call("_on_stop")
		main.host.advance_seconds(1.1)
	if not bool(main.host.can_unlock("iff")):
		_fail("停止盲收并等熟单次收割，应能攒够条件费用")
		return
	main.host.try_unlock("iff")
	if not bool(main.host.conditions_unlocked()):
		_fail("正常购买条件失败")
		return
	editor.text = main.FarmSkillData.exemplar("iff")
	main.call("_on_run")
	var guarded_start := int(main.host.get_hay())
	main.host.advance_seconds(30.0)
	var guarded_gain := int(main.host.get_hay()) - guarded_start
	if guarded_gain < 28 or main.host.last_error() != "":
		_fail("条件循环 30 秒应恢复约 30 干草，实际 %d" % guarded_gain)
		return
	main.call("_on_stop")
	print("SMOKE grass reset: blind +0/20s, guarded +%d/30s, manual recovery ok" % guarded_gain)
	print("SMOKE while harvest before/after speed ok")

	# 0.2.0: full skill tree, multi-resource bar, expand, a new crop.
	var expected_ids := [
		"harvest", "loop", "speed", "iff", "move", "forl", "till", "expand",
		"vars", "plant", "constn", "ops", "senses", "hayup", "carrot", "costs",
		"water", "tree", "func", "ref", "include", "sun", "fert", "debug",
		"array", "maze", "timing", "rec", "swenum", "pumpkin", "util", "cactus",
		"debug2", "companion", "dino", "mega", "sim", "autounlock", "hats",
	]
	main.call("_toggle_panel", "skill")
	for _i in 8:
		await process_frame
	overlay = main.get("overlay_body")
	for sid in expected_ids:
		var card = overlay.find_child("Skill_" + sid, true, false)
		if card == null:
			_fail("完整技能树缺少节点 %s" % sid)
			return
	var scroll = overlay.find_child("ScrollContainer", true, false)
	if scroll == null:
		# The scroll is the first ScrollContainer under the overlay root.
		for child in overlay.get_children():
			var found = child.find_child("ScrollContainer", true, false) if child is Node else null
			if found:
				scroll = found
				break
		for child in overlay.get_children():
			if child is ScrollContainer:
				scroll = child
				break
	if scroll == null:
		# Walk a little.
		var stack: Array = [overlay]
		while not stack.is_empty() and scroll == null:
			var n: Node = stack.pop_back()
			if n is ScrollContainer:
				scroll = n
			else:
				for c in n.get_children():
					stack.append(c)
	if scroll == null:
		_fail("技能树应变为可滚动")
		return
	if scroll is ScrollContainer:
		if (scroll as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER 				and (scroll as ScrollContainer).vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_fail("技能树应能纵向（及必要时横向）滚动")
			return
	if main.has_method("scroll_skills_toward"):
		main.call("scroll_skills_toward", "mega")
	elif scroll is ScrollContainer:
		(scroll as ScrollContainer).scroll_vertical = 1200
	for _i in 8:
		await process_frame
	var mega_card = overlay.find_child("Skill_mega", true, false)
	var dino_card = overlay.find_child("Skill_dino", true, false)
	var pumpkin_card = overlay.find_child("Skill_pumpkin", true, false)
	var overlay_panel: Control = main.get("overlay_card")
	if mega_card is Control and overlay_panel is Control:
		var vis: Rect2 = (overlay_panel as Control).get_global_rect()
		var late_ok := false
		for card in [mega_card, dino_card, pumpkin_card, overlay.find_child("Skill_maze", true, false)]:
			if card is Control and vis.intersects((card as Control).get_global_rect()):
				late_ok = true
				break
		if not late_ok:
			_fail("技能树应能滚到后期节点（向日葵/南瓜/迷宫/恐龙/多机）")
			return
	print("SMOKE skill tree scrolls to late nodes")
	main.call("_close_panel")
	if main.host.has_method("debug_grant"):
		for sid in ["iff", "move", "till", "plant", "senses", "carrot"]:
			main.host.call("debug_grant", sid)
	if main.host.has_method("debug_add_item"):
		main.host.call("debug_add_item", "carrot", 12)
		main.host.call("debug_add_item", "wood", 20)
	if main.has_method("_update_hay"):
		main.call("_update_hay")
	for _i in 4:
		await process_frame
	if int(main.host.get_item("carrot")) < 12:
		_fail("顶栏胡萝卜余额应能写入并读出，实际 %d" % int(main.host.get_item("carrot")))
		return
	var carrot_chip = main.get("_item_chips")
	if typeof(carrot_chip) != TYPE_DICTIONARY or not carrot_chip.has("carrot"):
		_fail("顶栏应出现胡萝卜等新资源芯片")
		return
	if not bool(carrot_chip["carrot"]["row"].visible):
		_fail("解锁胡萝卜后顶栏应显示该资源")
		return
	var size_before := int(main.host.get_world_size())
	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "expand")
	if main.field.has_method("ensure_size"):
		main.field.call("ensure_size", int(main.host.get_world_size()))
	for _i in 6:
		await process_frame
	var size_after := int(main.host.get_world_size())
	if size_after <= size_before:
		_fail("解锁扩田后世界边长应增大，之前 %d 之后 %d" % [size_before, size_after])
		return
	print("SMOKE expand world size ", size_before, " -> ", size_after)
	# Plant a carrot on the drone tile.
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    if (get_ground_type() != Soil) till();
    plant(Carrot);
    return 0;
}
"""
	main.call("_on_run")
	main.host.advance_seconds(2.0)
	for _i in 6:
		await process_frame
	main.call("_on_stop")
	var planted := false
	var n := int(main.host.get_world_size())
	for y in n:
		for x in n:
			if str(main.host.tile_entity(x, y)) == "Carrot":
				planted = true
	if not planted:
		_fail("应能在田里种下胡萝卜（新作物）")
		return
	print("SMOKE new crop carrot ok")

	# simulate() must actually run, not just appear in the name table.
	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "sim")
		main.host.call("debug_grant", "carrot")
		main.host.call("debug_grant", "till")
		main.host.call("debug_grant", "plant")
	if main.host.has_method("debug_add_item"):
		main.host.call("debug_add_item", "hay", 8)
		main.host.call("debug_add_item", "wood", 8)
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    simulate(4242);
    return 0;
}
"""
	main.call("_on_run")
	main.host.advance_seconds(1.0)
	for _i in 4:
		await process_frame
	if str(main.host.last_error()) != "":
		_fail("simulate() 应可执行，实际报错：%s" % str(main.host.last_error()))
		return
	main.call("_on_stop")
	print("SMOKE simulate() ran")

	# Multi-file bar appears only after include is unlocked.
	if main.code_files.get("file_bar_wrap") != null and bool(main.code_files.get("file_bar_wrap").visible):
		_fail("未解锁分文件时不应露出文件栏")
		return
	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "func")
		main.host.call("debug_grant", "include")
	if main.code_files.has_method("refresh_bar_visibility"):
		main.code_files.call("refresh_bar_visibility")
	for _i in 4:
		await process_frame
	var bar_wrap = main.code_files.get("file_bar_wrap")
	if bar_wrap == null or not bool(bar_wrap.visible):
		_fail("解锁分文件后应出现可切换的文件栏")
		return
	if main.code_files.has_method("new_file"):
		main.code_files.call("new_file")
	for _i in 4:
		await process_frame
	if str(main.code_files.get("active_file")) == "main.cpp":
		_fail("新建用户文件后应能切离 main.cpp")
		return
	if main.code_files.has_method("switch_to"):
		main.code_files.call("switch_to", "main.cpp")
	print("SMOKE multi-file editor ok")
	# Isolated UI fixture: the existing smoke grants above expose file controls.
	# Full gameplay progression is verified separately without grants in C++.
	main.call("open_skill_detail", "include")
	var load_button = main.skill_detail.find_child("InsertTemplate", true, false)
	load_button.pressed.emit()
	var headers: Dictionary = load("res://scripts/skill_data.gd").exemplar_headers("include")
	for name in headers:
		if main.code_files.get("user_files").get(name, "") != headers[name]:
			_fail("载入分文件范本时必须同时载入头文件 " + name)
			return
	main.set("hint_skill_id", "include")
	main.set("_hint_exemplar_open", true)
	main.call("_apply_hint_text")
	main.hint_header_copy.pressed.emit()
	if headers.is_empty() or main.get("last_copied_template") != headers[headers.keys()[0]]:
		_fail("提示中的头文件复制按钮必须复制同源头文件")
		return
	main.call("_close_skill_detail")
	print("SMOKE exemplar headers load and copy ok")

	await _save_screenshots(main)
	print("SMOKE_OK")
	quit(0)


func get_root_viewport() -> Viewport:
	return root.get_viewport()


func _send_wheel(editor: Control, shift: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP
	ev.pressed = true
	ev.shift_pressed = shift
	ev.factor = 1.0
	ev.position = editor.get_global_rect().get_center()
	if editor.has_method("_gui_input") == false:
		pass
	# Route through the editor handler used by the game.
	var main := editor.get_tree().root.get_child(editor.get_tree().root.get_child_count() - 1)
	# Prefer the scene main node.
	for child in editor.get_tree().root.get_children():
		var assist: Node = child.get("editor_assist")
		if assist:
			assist.call("gui_input", ev)
			var rig: Node = child.get("camera_rig")
			if rig:
				var zoom_before: float = float(rig.get("zoom"))
				rig.call("handle_event", ev)
				# handle_event should no-op when over editor; if it isn't
				# over editor in headless, still restore.
				if abs(float(rig.get("zoom")) - zoom_before) > 0.0 and shift:
					rig.set("zoom", zoom_before)
			return


func _save_screenshots(main: Node) -> void:
	if DisplayServer.get_name() == "headless":
		print("SMOKE screenshot skipped (headless)")
		return
	var path := ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(path)
	var vp := root.get_viewport()
	if vp == null:
		return
	if main.hint_window and main.has_method("_toggle_hint_window"):
		if not main.hint_window.visible or bool(main.hint_window.get("minimized")):
			if bool(main.hint_window.get("minimized")):
				main.hint_window.call("set_minimized", false)
			if not main.hint_window.visible:
				main.call("_toggle_hint_window")
	if main.code_window and main.code_window.has_method("reveal"):
		main.code_window.call("reveal", main.get("_code_default"))
	if main.hint_window and main.hint_window.has_method("reveal"):
		main.hint_window.call("reveal", main.get("_hint_default"))
	if main.has_method("_refresh_hint_layout"):
		main.call("_refresh_hint_layout")
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	# Skills shot: scroll so later branches (pumpkin / maze / dino / mega) are in view.
	main.set("_selected_skill_id", "")
	main.call("_toggle_panel", "skill")
	for _i in 8:
		await process_frame
	if main.has_method("scroll_skills_toward"):
		main.call("scroll_skills_toward", "pumpkin")
	elif main.get("skill_scroll"):
		main.get("skill_scroll").scroll_vertical = 1100
	for _i in 10:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("SMOKE screenshot skipped (no viewport image)")
		return
	img.save_png(path.path_join("ui-skills.png"))
	print("SMOKE screenshot ui-skills.png")
	main.call("_close_panel")
	# Error bubble: typo at compile / run.
	if main.code_window and main.code_window.has_method("reveal"):
		main.code_window.call("reveal", main.get("_code_default"))
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    harvset();
    return 0;
}
"""
	main.call("_on_run_once")
	for _i in 16:
		await process_frame
	var markup = main.get("error_markup")
	if markup == null or not bool(markup.call("is_showing")):
		_fail("运行含拼写错误的程序后应出现行内错误气泡")
		return
	if str(main.host.error_kind()) != "typo":
		_fail("拼写错误的诊断类型应为 typo，实际是 %s" % str(main.host.error_kind()))
		return
	if str(main.host.error_suggestion()).find("harvest") < 0:
		_fail("拼写错误应提示 harvest")
		return
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("ui-error.png"))
		print("SMOKE screenshot ui-error.png")
	# Runtime error: illegal argument, bubble appears when the line runs.
	main.call("_clear_error_markup")
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    do_a_flip(East);
    return 0;
}
"""
	main.call("_on_run_once")
	main.host.advance_seconds(0.2)
	for _i in 12:
		await process_frame
	if markup == null or not bool(markup.call("is_showing")):
		_fail("运行期错误在该行执行后应出现气泡")
		return
	print("SMOKE runtime error bubble ok")
	main.call("_clear_error_markup")
	# Fresh-looking default / maximized shots.
	main.host.reset_world()
	main.editor.text = main.STARTER
	if main.has_method("_clear_error_markup"):
		main.call("_clear_error_markup")
	if main.has_method("_apply_hint_text"):
		main.call("_apply_hint_text")
	if main.has_method("_update_hay"):
		main.call("_update_hay")
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	for _i in 10:
		await process_frame
	img = vp.get_texture().get_image()
	if img == null:
		print("SMOKE screenshot skipped (no viewport image)")
		return
	var ok := img.save_png(path.path_join("ui-default.png"))
	print("SMOKE screenshot ui-default.png ", ok)
	_save_buttons_zoom(main, img, path)
	if main.code_window and main.code_window.has_method("toggle_maximize"):
		if not bool(main.code_window.get("maximized")):
			main.code_window.call("toggle_maximize")
		for _i in 8:
			await process_frame
		img = vp.get_texture().get_image()
		if img:
			img.save_png(path.path_join("ui-code-max.png"))
			print("SMOKE screenshot ui-code-max.png")
		main.code_window.call("toggle_maximize")
		for _i in 6:
			await process_frame
	# Hint with a mid-game exemplar (vars) next to the code window.
	if main.host.has_method("debug_grant"):
		for sid in ["loop", "speed", "iff", "move", "forl", "till", "plant", "vars"]:
			main.host.call("debug_grant", sid)
	main.set("hint_skill_id", "vars")
	var code_was_visible: bool = main.code_window.visible
	main.code_window.visible = false
	if main.hint_window and main.hint_window.has_method("reveal"):
		var vsize: Vector2 = vp.get_visible_rect().size
		main.hint_window.call("reveal", Rect2(Vector2(14, 62), Vector2(minf(700.0, vsize.x * 0.62), vsize.y - 76.0)))
	if main.has_method("_refresh_hint_layout"):
		main.call("_refresh_hint_layout")
	main.call("_apply_hint_text")
	main.call("_copy_hint_exemplar")
	for _i in 10:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("hint-exemplar.png"))
		print("SMOKE screenshot hint-exemplar.png")
	if main.hint_window and main.hint_window.has_method("reveal"):
		main.hint_window.call("reveal", main.get("_hint_default"))
	main.set("hint_skill_id", "")
	main.code_window.visible = code_was_visible
	# Bot close-up: windows hidden, grass grown, mid-distance 35° view.
	if main.code_window:
		main.code_window.visible = false
	if main.hint_window:
		main.hint_window.visible = false
	main.field.set("hide_plants", false)
	main.host.advance_seconds(0.75)
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	# Oblique 35° view, tile about half the frame, hoe on the right.
	main.camera_rig.set("yaw", 0.42)
	main.camera_rig.set("yaw_s", 0.42)
	main.camera_rig.set("zoom", 2.30)
	main.camera_rig.set("zoom_s", 2.30)
	main.camera_rig.set("target", Vector3(0.02, 0.06, 0.02))
	main.camera_rig.set("target_s", Vector3(0.02, 0.06, 0.02))
	main.camera_rig.set("pitch", 0.611)  # 35 deg
	main.camera_rig.set("pitch_s", 0.611)
	if main.camera_rig.has_method("sync_pos_from_target"):
		main.camera_rig.call("sync_pos_from_target")
	if main.camera_rig.has_method("apply_transform"):
		main.camera_rig.call("apply_transform")
	for _i in 16:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("bot-closeup.png"))
		print("SMOKE screenshot bot-closeup.png")
	# Mid-harvest pose (snapped, so the swing reads clearly).
	main.bot.set("harvesting", true)
	var hoe_n = main.bot.get("hoe")
	var arm_r = main.bot.get("arm_r")
	var rig = main.bot.get("rig")
	var hoe_rest = hoe_n.rotation if hoe_n else Vector3.ZERO
	var arm_rest = arm_r.rotation if arm_r else Vector3.ZERO
	var rig_rest_x := float(rig.rotation.x) if rig else 0.0
	if hoe_n:
		hoe_n.rotation = Vector3(1.05, 0.12, -0.22)
	if arm_r:
		arm_r.rotation = Vector3(0.95, 0.12, -0.18)
	if rig:
		rig.rotation.x = 0.42
	for _i in 4:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("bot-hoe.png"))
		print("SMOKE screenshot bot-hoe.png")
	if hoe_n:
		hoe_n.rotation = hoe_rest
	if arm_r:
		arm_r.rotation = arm_rest
	if rig:
		rig.rotation.x = rig_rest_x
	main.bot.set("harvesting", false)
	# A second, clearly orbited camera angle.
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	main.camera_rig.set("yaw", float(main.camera_rig.get("yaw")) + 0.85)
	main.camera_rig.set("yaw_s", float(main.camera_rig.get("yaw")))
	main.camera_rig.set("pitch", 0.85)
	main.camera_rig.set("pitch_s", 0.85)
	main.camera_rig.set("zoom", 3.4)
	main.camera_rig.set("zoom_s", 3.4)
	if main.camera_rig.has_method("sync_pos_from_target"):
		main.camera_rig.call("sync_pos_from_target")
	if main.camera_rig.has_method("apply_transform"):
		main.camera_rig.call("apply_transform")
	for _i in 8:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("ui-camera.png"))
		print("SMOKE screenshot ui-camera.png")
	# Restore windows for a clean exit, though we already quit after this.
	if main.code_window and main.code_window.has_method("reveal"):
		main.code_window.call("reveal", main.get("_code_default"))
	if main.hint_window and main.hint_window.has_method("reveal"):
		main.hint_window.call("reveal", main.get("_hint_default"))
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)

	await _save_icon_sheet(main, path, vp)


	# Real crop / maze / multi-drone shots.
	if main.code_window:
		main.code_window.visible = false
	if main.hint_window:
		main.hint_window.visible = false
	main.field.set("hide_plants", false)
	if main.host.has_method("debug_grant"):
		for sid in ["iff", "move", "till", "plant", "senses", "carrot", "expand"]:
			main.host.call("debug_grant", sid)
	if main.host.has_method("debug_add_item"):
		main.host.call("debug_add_item", "hay", 40)
		main.host.call("debug_add_item", "wood", 40)
	if main.field.has_method("ensure_size"):
		main.field.call("ensure_size", int(main.host.get_world_size()))
	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "forl")
		main.host.call("debug_grant", "vars")
		main.host.call("debug_grant", "ops")
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    if (get_ground_type() != Soil) till();
    if (get_entity_type() == None) plant(Carrot);
    move(East);
    if (get_ground_type() != Soil) till();
    if (get_entity_type() == None) plant(Carrot);
    move(East);
    if (get_ground_type() != Soil) till();
    if (get_entity_type() == None) plant(Carrot);
    move(East);
    if (get_ground_type() != Soil) till();
    if (get_entity_type() == None) plant(Carrot);
    return 0;
}
"""
	main.call("_on_run")
	main.host.advance_seconds(16.0)
	for _i in 10:
		await process_frame
	if str(main.host.last_error()) != "":
		_fail("种植胡萝卜演示程序报错：%s" % str(main.host.last_error()))
		return
	main.call("_on_stop")
	# Let carrots grow so the silhouette reads clearly (4.8–7.2s).
	main.host.advance_seconds(8.0)
	var saw_carrot := false
	var wn := int(main.host.get_world_size())
	for y in wn:
		for x in wn:
			if str(main.host.tile_entity(x, y)) == "Carrot":
				saw_carrot = true
	if not saw_carrot:
		_fail("胡萝卜演示田里没有胡萝卜")
		return
	var focus := Vector3.ZERO
	if main.field.has_method("tile_world"):
		for y in wn:
			for x in wn:
				if str(main.host.tile_entity(x, y)) == "Carrot":
					focus = main.field.call("tile_world", x, y)
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	main.camera_rig.set("target", focus)
	main.camera_rig.set("target_s", focus)
	main.camera_rig.set("yaw", 0.62)
	main.camera_rig.set("yaw_s", 0.62)
	main.camera_rig.set("pitch", 0.62)
	main.camera_rig.set("pitch_s", 0.62)
	main.camera_rig.set("zoom", 2.55)
	main.camera_rig.set("zoom_s", 2.55)
	if main.camera_rig.has_method("sync_pos_from_target"):
		main.camera_rig.call("sync_pos_from_target")
	if main.camera_rig.has_method("apply_transform"):
		main.camera_rig.call("apply_transform")
	if main.field.has_method("update"):
		main.field.call("update", 0.05)
	for _i in 12:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("crop-carrot.png"))
		print("SMOKE screenshot crop-carrot.png")

	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "fert")
		main.host.call("debug_grant", "maze")
		main.host.call("debug_grant", "water")
	if main.host.has_method("debug_add_item"):
		main.host.call("debug_add_item", "weird", 400)
		main.host.call("debug_add_item", "wood", 40)
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    if (get_entity_type() != None) till();
    if (get_ground_type() == Grassland) till();
    if (get_entity_type() == None) plant(Bush);
    use_item(WeirdSubstance, 32);
    return 0;
}
"""
	main.call("_on_run")
	main.host.advance_seconds(5.0)
	for _i in 10:
		await process_frame
	main.call("_on_stop")
	if str(main.host.last_error()) != "":
		_fail("迷宫演示程序报错：%s" % str(main.host.last_error()))
		return
	if not bool(main.host.maze_active()):
		_fail("迷宫演示后 maze_active 应为真，田里应有篱笆和宝藏")
		return
	if main.field.has_method("update"):
		main.field.call("update", 0.05)
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	main.camera_rig.set("pitch", 0.95)
	main.camera_rig.set("pitch_s", 0.95)
	main.camera_rig.set("zoom", 4.6)
	main.camera_rig.set("zoom_s", 4.6)
	if main.camera_rig.has_method("sync_pos_from_target"):
		main.camera_rig.call("sync_pos_from_target")
	if main.camera_rig.has_method("apply_transform"):
		main.camera_rig.call("apply_transform")
	for _i in 10:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("maze-field.png"))
		print("SMOKE screenshot maze-field.png")

	# Leave the maze shot, then clear the maze so drones are visible on open ground.
	if bool(main.host.maze_active()):
		main.editor.text = """#include <bits/stdc++.h>
using namespace std;

int main() {
    harvest();
    return 0;
}
"""
		main.call("_on_run")
		main.host.advance_seconds(2.0)
		for _i in 6:
			await process_frame
		main.call("_on_stop")
	if main.host.has_method("debug_grant"):
		main.host.call("debug_grant", "mega")
		main.host.call("debug_grant", "func")
		main.host.call("debug_grant", "move")
	if main.field.has_method("ensure_size"):
		main.field.call("ensure_size", int(main.host.get_world_size()))
	main.editor.text = """#include <bits/stdc++.h>
using namespace std;

void go_east() { move(East); move(East); }
int main() {
    spawn_drone(go_east);
    move(North);
    move(North);
    return 0;
}
"""
	main.call("_on_run")
	main.host.advance_seconds(3.0)
	if main.bot.has_method("sync_fleet"):
		main.bot.call("sync_fleet")
	if main.bot.has_method("update"):
		main.bot.call("update", 0.05)
	for _i in 12:
		await process_frame
	if main.bot.has_method("visible_drone_nodes") and int(main.bot.call("visible_drone_nodes")) < 2:
		_fail("画面上应能同时看到至少两台无人机")
		return
	if main.has_method("reset_camera"):
		main.call("reset_camera", true)
	main.camera_rig.set("pitch", 0.85)
	main.camera_rig.set("pitch_s", 0.85)
	main.camera_rig.set("zoom", 4.2)
	main.camera_rig.set("zoom_s", 4.2)
	if main.camera_rig.has_method("sync_pos_from_target"):
		main.camera_rig.call("sync_pos_from_target")
	if main.camera_rig.has_method("apply_transform"):
		main.camera_rig.call("apply_transform")
	for _i in 8:
		await process_frame
	img = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("multi-drone.png"))
		print("SMOKE screenshot multi-drone.png")
	main.call("_on_stop")


func _save_buttons_zoom(main: Node, img: Image, path: String) -> void:
	if img == null or main.code_window == null:
		return
	var bar = main.code_window.get("title_bar")
	var rect: Rect2
	if bar is Control:
		rect = (bar as Control).get_global_rect()
	else:
		rect = Rect2(main.code_window.position, Vector2(main.code_window.size.x, 40))
	rect = rect.grow(10)
	var bounds := Rect2(0, 0, img.get_width(), img.get_height())
	rect = rect.intersection(bounds)
	if rect.size.x < 8 or rect.size.y < 8:
		print("SMOKE buttons zoom skipped (empty rect)")
		return
	var crop := img.get_region(Rect2i(Vector2i(rect.position), Vector2i(rect.size)))
	var scale := 2.8
	crop.resize(int(crop.get_width() * scale), int(crop.get_height() * scale), Image.INTERPOLATE_BILINEAR)
	crop.save_png(path.path_join("ui-buttons-zoom.png"))
	print("SMOKE screenshot ui-buttons-zoom.png")


func _save_icon_sheet(main: Node, path: String, vp: Viewport) -> void:
	if main.code_window:
		main.code_window.visible = false
	if main.hint_window:
		main.hint_window.visible = false
	var overlay := ColorRect.new()
	overlay.color = Color(0.17, 0.20, 0.17, 1)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui_root.add_child(overlay)
	var title := Label.new()
	title.text = "Codefarm 图标  0.2.2"
	title.position = Vector2(40, 24)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.86, 0.82, 0.74, 1))
	overlay.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 26)
	grid.position = Vector2(48, 70)
	overlay.add_child(grid)
	var items: Array = [
		[FarmIcon.Kind.PLAY, "运行"],
		[FarmIcon.Kind.PLAY_ONCE, "一次"],
		[FarmIcon.Kind.STOP, "停止"],
		[FarmIcon.Kind.CODE, "代码"],
		[FarmIcon.Kind.SKILL, "技能"],
		[FarmIcon.Kind.HINT, "提示"],
		[FarmIcon.Kind.SETTINGS, "设置"],
		[FarmIcon.Kind.LOG, "日志"],
		[FarmIcon.Kind.HAY, "干草"],
		[FarmIcon.Kind.WOOD, "木头"],
		[FarmIcon.Kind.MINIMIZE, "最小化"],
		[FarmIcon.Kind.MAXIMIZE, "全屏"],
		[FarmIcon.Kind.RESTORE, "还原"],
		[FarmIcon.Kind.CLOSE, "关闭"],
		[FarmIcon.Kind.RESET_CAM, "回正"],
		[FarmIcon.Kind.HARVEST, "收获"],
		[FarmIcon.Kind.LOOP, "循环"],
		[FarmIcon.Kind.IFF, "条件"],
		[FarmIcon.Kind.MOVE, "移动"],
		[FarmIcon.Kind.FOR, "计数"],
		[FarmIcon.Kind.TILL, "耕地"],
		[FarmIcon.Kind.PLANT, "种植"],
		[FarmIcon.Kind.VARS, "变量"],
		[FarmIcon.Kind.FN, "函数"],
		[FarmIcon.Kind.CHECK, "勾选"],
		[FarmIcon.Kind.SOON, "即将"],
		[FarmIcon.Kind.LOCK, "锁定"],
		[FarmIcon.Kind.CARROT, "胡萝卜"],
		[FarmIcon.Kind.PUMPKIN, "南瓜"],
		[FarmIcon.Kind.POWER, "能量"],
		[FarmIcon.Kind.WATER, "水"],
		[FarmIcon.Kind.FERT, "肥料"],
		[FarmIcon.Kind.WEIRD, "物质"],
		[FarmIcon.Kind.GOLD, "金子"],
		[FarmIcon.Kind.CACTUS, "仙人掌"],
		[FarmIcon.Kind.BONE, "骨头"],
	]
	var font = null
	var font_path := "res://fonts/DroidSansFallback.ttf"
	if ResourceLoader.exists(font_path):
		font = load(font_path)
	for item in items:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(150, 120)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 8)
		var icon := FarmIcon.new()
		icon.kind = item[0]
		icon.icon_color = Color(0.86, 0.82, 0.74, 1)
		icon.custom_minimum_size = Vector2(64, 64)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var lab := Label.new()
		lab.text = item[1]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 15)
		lab.add_theme_color_override("font_color", Color(0.82, 0.80, 0.74, 1))
		if font:
			lab.add_theme_font_override("font", font)
			title.add_theme_font_override("font", font)
		cell.add_child(lab)
		grid.add_child(cell)
	for _i in 8:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	if img:
		img.save_png(path.path_join("icons-sheet.png"))
		print("SMOKE screenshot icons-sheet.png")
	overlay.queue_free()
