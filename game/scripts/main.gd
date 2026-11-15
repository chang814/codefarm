extends Node3D
const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmWindow := preload("res://scripts/farm_window.gd")
const FarmRunButton := preload("res://scripts/farm_run_button.gd")
const FarmChromeButton := preload("res://scripts/farm_chrome_button.gd")
const FarmErrorMarkup := preload("res://scripts/error_markup.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmSkillData := preload("res://scripts/skill_data.gd")
const FarmSave := preload("res://scripts/farm_save.gd")
const FarmAudio := preload("res://scripts/farm_audio.gd")
const FarmCameraRig := preload("res://scripts/farm_camera_rig.gd")
const FarmBot := preload("res://scripts/farm_bot.gd")
const FarmField := preload("res://scripts/farm_field.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")
const FarmChangelog := preload("res://scripts/farm_changelog.gd")
const FarmUiKit := preload("res://scripts/farm_ui_kit.gd")
const FarmEditorAssist := preload("res://scripts/farm_editor_assist.gd")

const VERSION := "0.2.11"
const STARTER := """#include <bits/stdc++.h>
using namespace std;

int main() {
    harvest();
    return 0;
}
"""


const CONTROLS_TEXT := "视角：左键按住地面拖动平移（松手轻轻滑一下），右键拖动转动，滚轮缩放，WASD 移动，F 回正。左键点在窗口和按钮上只操作界面。"



@onready var host: CodefarmHost = $CodefarmHost
@onready var drone: Node3D = $Farm/Drone
@onready var juice_anchor: Node3D = $Farm/Juice
@onready var farm_root: Node3D = $Farm
@onready var farm_tile: MeshInstance3D = $Farm/Tile
@onready var farm_earth: MeshInstance3D = $Farm/Earth
@onready var grass_placeholder: Node3D = $Farm/Grass
@onready var camera: Camera3D = $Camera3D
@onready var ui_root: Control = $UI/Root

var editor: CodeEdit
var run_button: Button
var stop_button: Button
var run_loop_button: FarmRunButton
var run_once_button: FarmRunButton
var hay_label: Label
var wood_wrap: HBoxContainer
var _item_chips: Dictionary = {}
var wood_label: Label
var font_badge: Label
var reset_cam_button: Button
var error_markup: Control
var hint_next_label: Label
var hint_next_code: CodeEdit
var hint_load_button: Button
var hint_code: CodeEdit
var hint_prose_after: Label
var _error_history: PackedStringArray = []
var _error_latched := false
var _error_runtime := false
var hint_line: Label
var title_label: Label
var highlight: Control
var backdrop: ColorRect
var _panel_tabs: Control
var overlay_card: PanelContainer
var overlay_title: Label
var overlay_body: Control
var overlay_close: Button

var _stepping: bool = false
var _open_panel: String = ""
var _reset_confirming: bool = false
var _loops_seen: bool = false
var _speed_seen: bool = false
var _if_seen: bool = false
var _move_seen: bool = false
var _for_seen: bool = false
var _till_seen: bool = false
var _plant_seen: bool = false
var _highlighted_line: int = -1
var _pending_line: int = -1
var _pending_t: float = 0.0
var _hover_t: float = 0.0
var code_window: PanelContainer
var hint_window: PanelContainer
var code_btn: Button
var skill_button: Button
var hint_button: Button
var settings_button: Button
var log_button: Button
var hint_body_label: Label
var hint_scroll: ScrollContainer
var _hint_stashed := false
var _hint_stash_visible := true
var _hint_stash_minimized := false
var _hint_stash_maximized := false
var _hint_stash_rect := Rect2()
var _code_default := Rect2(20, 94, 520, 432)
var _hint_default := Rect2(20, 538, 520, 342)
var skill_detail: Control
var _selected_skill_id := ""
var last_copied_template := ""
# Hint window: one-sentence pain + collapsible 「范本」 (the playthrough's exemplar).
var hint_skill_id := ""
var hint_exemplar_toggle: Button
var hint_copy_button: Button
var hint_copied_label: Label
var hint_header_label: Label
var hint_header_code: CodeEdit
var hint_header_copy: Button
var _hint_exemplar_open := true
var _skill_glow_nodes: Array = []
var skill_scroll: ScrollContainer
var _skill_more_hint: Control
var _skill_view := {"zoom": 1.0, "scroll": Vector2.ZERO}
var _file_bar: HBoxContainer
var _file_bar_wrap: Control
var _user_files: Dictionary = {}
var _active_file := "main.cpp"
var camera_rig: FarmCameraRig
var bot: FarmBot
var field: FarmField
var ui: FarmUiKit
var editor_assist: FarmEditorAssist

@export var persistence_enabled := true
@export var start_on_farm := false  # Explicit scene fixture option for isolated UI tests.
@export var save_path := "user://progress.json"
var _session_phase := "menu"
var _portrait_hidden: Array[Node3D] = []
var audio: FarmAudio
var _sound_level := 2
var _menu: Control
var _start_button: Button
var _save_notice: Label
var _save_timer: Timer
var _save_elapsed := 0.0
var _has_save := false
var _loading_save := false
var _save_message := ""
var _intro_time := 0.0
var _intro_from := Transform3D.IDENTITY
var _intro_to := Transform3D.IDENTITY
var _intro_size := 1.0
var _intro_home_size := 4.15
const INTRO_DURATION := 1.6


func _ready() -> void:
	_setup_field()
	_setup_camera_rig()
	_setup_bot()
	field.size_changed.connect(func(size: int) -> void: camera_rig.apply_home(size, false))
	farm_tile.visible = false
	grass_placeholder.visible = false
	_setup_ui_kit()
	_build_ui()
	editor_assist.setup_highlighter([hint_code, hint_header_code])
	editor_assist.enable_completion()
	field.init()
	if editor.text.strip_edges().is_empty() or editor.text.strip_edges() == "harvest();":
		editor.text = STARTER
	_clear_error_markup()
	_apply_hint_text()
	call_deferred("_refresh_hint_layout")
	_update_hay()
	_update_buttons()
	bot.snap()
	_soften_lights()
	bot.build()
	_setup_session()




func _setup_field() -> void:
	field = FarmField.new()
	field.name = "Field"
	add_child(field)
	field.setup(host, camera, farm_root, farm_earth)


func _setup_camera_rig() -> void:
	camera_rig = FarmCameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	camera_rig.setup(camera, {
		"point_over_ui": _point_over_ui,
		"mouse_over_editor": _mouse_over_editor,
		"text_input_focused": _text_input_has_focus,
		"panel_open": func() -> bool: return _open_panel != "",
		"farm_size": func() -> int: return field.shown_size,
		"code_window_visible": func() -> bool: return code_window != null and code_window.visible,
	})



func _setup_bot() -> void:
	bot = FarmBot.new()
	bot.name = "Bot"
	add_child(bot)
	bot.setup(host, drone, camera, {
		"farm_root": farm_root,
		"juice_anchor": juice_anchor,
		"tile_world": field.tile_world,
		"farm_size": func() -> int: return field.shown_size,
		"sfx": _sfx,
	})


func _setup_session() -> void:
	get_tree().auto_accept_quit = false
	audio = FarmAudio.new()
	audio.name = "FarmAudio"
	add_child(audio)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.8
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)
	_load_progress()
	field.ensure_size(host.get_world_size())
	bot.snap()
	camera_rig.apply_home(host.get_world_size(), true)
	if start_on_farm:
		_session_phase = "playing"
		return
	_intro_to = camera.transform
	_intro_home_size = camera.size
	ui_root.visible = false
	# The same rig leads the welcome screen. No portrait texture or second bot.
	var focus := drone.position + Vector3(0, 0.015, 0)
	camera.position = focus + Vector3(0, 0.10, 2.4)
	camera.look_at(focus)
	camera.size = 0.88
	bot.rig.rotation = Vector3.ZERO
	_clear_portrait(true)
	_intro_from = camera.transform
	_intro_size = camera.size
	_build_menu()


func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "Welcome"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.theme = ui.theme
	$UI.add_child(_menu)
	var title := Label.new()
	title.text = "Codefarm"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.apply_font(title, 38, FarmPalette.SAGE_DEEP, true)
	_menu.add_child(title)
	# Anchor first, then offsets: assigning position/size here is absolute and
	# pushed the title and the start button off-screen.
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -170
	title.offset_right = 170
	title.offset_top = 40
	title.offset_bottom = 104
	var actions := VBoxContainer.new()
	actions.name = "WelcomeActions"
	actions.add_theme_constant_override("separation", 14)
	_menu.add_child(actions)
	actions.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	actions.offset_left = -150
	actions.offset_right = 150
	actions.offset_top = -166
	actions.offset_bottom = -22
	_start_button = ui.make_button("继续游戏" if _has_save else "开始游戏", false, 240)
	_start_button.name = "StartGame"
	_start_button.custom_minimum_size = Vector2(300, 64)
	_start_button.pressed.connect(start_game)
	actions.add_child(_start_button)
	_save_notice = Label.new()
	_save_notice.text = _save_message if not _save_message.is_empty() else _save_summary() if _has_save else "写下第一行，让农场生长"
	_save_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.apply_font(_save_notice, 17, FarmPalette.SAGE_DEEP)
	actions.add_child(_save_notice)
	_start_button.grab_focus()


## What the saved farm holds, so the welcome screen shows the save was read.
func _save_summary() -> String:
	var owned := 0
	for node in FarmSkillData.nodes(host):
		if bool(node.get("owned", false)) and str(node.get("id", "")) != "harvest":
			owned += 1
	var side := int(host.get_world_size())
	return "已读取存档 · %d×%d 农场 · 干草 %d · 技能 %d 项" % [side, side, int(host.get_hay()), owned]


func start_game() -> void:
	if _session_phase != "menu":
		return
	_session_phase = "entering"
	_intro_time = 0.0
	_start_button.disabled = true
	_start_button.release_focus()
	_clear_portrait(false)
	clear_camera_drag()
	var tw := create_tween()
	tw.tween_property(_menu, "modulate:a", 0.0, 0.25)


## The welcome close-up looks straight at the bot. Plants standing between the
## camera and the bot are tucked away for the portrait and return on start.
func _clear_portrait(on: bool) -> void:
	for node in _portrait_hidden:
		if is_instance_valid(node):
			node.visible = true
	_portrait_hidden.clear()
	if field.scenery:
		field.scenery.set_decor_visible(not on)
	if not on:
		return
	for node in field.plants_in_front_of(drone.global_position):
		node.visible = false
		_portrait_hidden.append(node)


func _tick_intro(delta: float) -> void:
	if _session_phase != "entering":
		return
	_intro_time = minf(_intro_time + delta, INTRO_DURATION)
	var t := smootherstep(_intro_time / INTRO_DURATION)
	camera.transform = _intro_from.interpolate_with(_intro_to, t)
	camera.size = lerpf(_intro_size, _intro_home_size, t)
	if _intro_time >= INTRO_DURATION:
		_session_phase = "playing"
		_menu.visible = false
		ui_root.visible = true
		ui_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(ui_root, "modulate:a", 1.0, 0.24)
		_queue_save()


func smootherstep(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _snapshot_progress() -> Dictionary:
	_flush_active_file()
	if is_instance_valid(skill_scroll):
		_skill_view = {"zoom": skill_scroll.zoom, "scroll": Vector2(skill_scroll.scroll_horizontal, skill_scroll.scroll_vertical)}
	var scroll: Vector2 = _skill_view.scroll
	return {"version": 1, "world": host.save_state(), "files": _user_files.duplicate(),
		"active_file": _active_file, "hint": hint_skill_id, "exemplar_open": _hint_exemplar_open,
		"zoom": _skill_view.zoom, "scroll": [scroll.x, scroll.y], "font_size": editor_assist.font_size,
		"selected_skill": _selected_skill_id, "bot_yaw": bot.rig.rotation.y,
		"hint_visible": hint_window.visible, "code_visible": code_window.visible,
		"sound": _sound_level}


func _valid_progress(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("world") is String or not data.get("files") is Dictionary:
		return false
	var files: Dictionary = data.files
	if not files.get("main.cpp") is String or files.size() > 64:
		return false
	for key in files:
		if not key is String or not files[key] is String or key.length() > 128 or files[key].length() > 524288:
			return false
	if not data.get("active_file") is String or not files.has(data.active_file):
		return false
	if not data.get("hint", "") is String or not data.get("selected_skill", "") is String:
		return false
	var scroll = data.get("scroll")
	if not scroll is Array or scroll.size() != 2:
		return false
	for value in [data.get("zoom"), data.get("font_size"), data.get("bot_yaw"), scroll[0], scroll[1]]:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return float(data.zoom) >= 0.1 and float(data.zoom) <= 3.0 and int(data.font_size) >= FarmEditorAssist.FONT_SIZE_MIN and int(data.font_size) <= FarmEditorAssist.FONT_SIZE_MAX


func _load_progress() -> bool:
	if not persistence_enabled:
		return false
	_loading_save = true
	var existed := FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")
	for path in [save_path, save_path + ".bak"]:
		var data := FarmSave.read_file(path)
		if not _valid_progress(data) or not host.load_state(data.world):
			continue
		_user_files = data.files.duplicate()
		_active_file = data.active_file
		editor.protect_framework = _active_file == "main.cpp"
		editor.text = _user_files[_active_file]
		editor_assist.set_font_size(int(data.font_size), false, false)
		hint_skill_id = data.get("hint", "")
		_hint_exemplar_open = bool(data.get("exemplar_open", false))
		_skill_view = {"zoom": float(data.zoom), "scroll": Vector2(float(data.scroll[0]), float(data.scroll[1]))}
		_selected_skill_id = data.get("selected_skill", "")
		bot.rig.rotation.y = float(data.bot_yaw)
		hint_window.visible = bool(data.get("hint_visible", true))
		code_window.visible = bool(data.get("code_visible", true))
		# Older saves have no sound entry; anything unexpected means full volume.
		var sound = data.get("sound", 2)
		_set_sound_level(int(sound) if (sound is float or sound is int) and is_finite(float(sound)) else 2)
		_rebuild_file_bar()
		_push_includes_to_host()
		_apply_hint_text()
		# Mark already-owned introductory hints seen; reopening must not replace the saved hint.
		_loops_seen = host.loops_unlocked()
		_speed_seen = host.speed_unlocked()
		_if_seen = host.conditions_unlocked()
		_move_seen = host.movement_unlocked()
		_for_seen = host.for_unlocked()
		_till_seen = host.till_unlocked()
		_plant_seen = host.plant_unlocked()
		_has_save = true
		_save_message = "已恢复上次备份；进度仍会自动保存。" if path.ends_with(".bak") else ""
		_loading_save = false
		return true
	_loading_save = false
	if existed:
		_save_message = "存档损坏，已安全回到新农场。"
	return false


func _set_sound_level(value: int) -> void:
	_sound_level = clampi(value, 0, 2)
	if audio:
		audio.level = _sound_level


func _sfx(sound: String) -> void:
	if audio and _session_phase == "playing":
		audio.play(sound)


func _queue_save(restart: bool = false) -> void:
	if not persistence_enabled or _loading_save or _save_timer == null:
		return
	if restart or _save_timer.is_stopped():
		_save_timer.start()


func _save_now() -> bool:
	if not persistence_enabled or _loading_save or not is_instance_valid(editor) or bot.rig == null:
		return false
	var ok := FarmSave.write_file(save_path, _snapshot_progress())
	if not ok:
		_save_message = "保存失败，请检查数据目录空间与权限。"
		if is_instance_valid(_save_notice):
			_save_notice.text = _save_message
		if is_instance_valid(hint_line):
			hint_line.text = _save_message
	else:
		_has_save = true
	return ok


func _exit_tree() -> void:
	_save_now()


func _setup_ui_kit() -> void:
	ui = FarmUiKit.new()
	ui.load_fonts()
	var theme := ui.build_theme()
	if ui_root:
		ui_root.theme = theme
	var win := get_window()
	if win:
		win.theme = theme


func _setup_editor_assist() -> void:
	editor_assist = FarmEditorAssist.new()
	editor_assist.name = "EditorAssist"
	add_child(editor_assist)
	editor_assist.setup(editor, host)
	editor_assist.edited.connect(func() -> void:
		_queue_save(true)
		_maybe_dismiss_error_on_edit()
	)
	editor_assist.clicked.connect(func(pos: Vector2) -> void:
		if host.is_running() or host.is_paused() or _stepping:
			_on_stop()
		_maybe_dismiss_error_on_click(pos)
	)


func _build_ui() -> void:
	ui_root.theme = ui.theme

	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 14
	top.offset_bottom = 84
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	top.add_theme_stylebox_override("panel", ui.flat(FarmPalette.SAGE_BG, 16, Vector4(20, 10, 20, 10), 10))
	ui_root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Codefarm"
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.apply_font(title_label, 24, FarmPalette.CREAM, true)
	top_row.add_child(title_label)

	var ver := Label.new()
	ver.text = VERSION
	ver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.apply_font(ver, 17, FarmPalette.TEXT_DIM)
	title_label.tooltip_text = "Codefarm " + VERSION
	ver.queue_free()
	var resource_scroll := ScrollContainer.new()
	resource_scroll.name = "ResourceStrip"
	resource_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	resource_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resource_scroll.custom_minimum_size = Vector2(70, 48)
	top_row.add_child(resource_scroll)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 14)
	# Fill the strip so chips centre on the bar instead of hugging its top.
	resources.size_flags_vertical = Control.SIZE_EXPAND_FILL
	resource_scroll.add_child(resources)

	var hay_chip := ui.resource_chip(FarmIcon.Kind.HAY, "HayLabel", FarmIcon.item_color("hay", FarmPalette.GOLD_SOFT))
	hay_chip["row"].tooltip_text = "干草余额"
	hay_label = hay_chip["label"]
	resources.add_child(hay_chip["row"])

	var wood_chip := ui.resource_chip(FarmIcon.Kind.WOOD, "WoodLabel", FarmIcon.item_color("wood", FarmPalette.GOLD_SOFT))
	wood_chip["row"].tooltip_text = "木头"
	wood_wrap = wood_chip["row"]
	wood_label = wood_chip["label"]
	wood_wrap.visible = false
	resources.add_child(wood_wrap)

	_item_chips = {}
	for spec in [
		["carrot", "胡萝卜"],
		["pumpkin", "南瓜"],
		["power", "能量"],
		["water_tank", "水"],
		["fertilizer", "肥料"],
		["weird", "奇怪物质"],
		["gold", "金子"],
		["cactus", "仙人掌"],
		["bone", "骨头"],
	]:
		var chip := ui.resource_chip(FarmIcon.kind_from_item(spec[0]), spec[0] + "Label", FarmIcon.item_color(spec[0], FarmPalette.GOLD_SOFT))
		chip["row"].tooltip_text = spec[1]
		chip["row"].visible = false
		resources.add_child(chip["row"])
		_item_chips[spec[0]] = chip

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.queue_free()

	run_button = null
	stop_button = null
	code_btn = ui.make_icon_button(FarmIcon.Kind.CODE, "代码")
	code_btn.name = "CodeButton"
	skill_button = ui.make_icon_button(FarmIcon.Kind.SKILL, "技能树")
	skill_button.name = "SkillButton"
	hint_button = ui.make_icon_button(FarmIcon.Kind.HINT, "提示")
	hint_button.name = "HintButton"
	settings_button = ui.make_icon_button(FarmIcon.Kind.SETTINGS, "设置")
	settings_button.name = "SettingsButton"
	log_button = ui.make_icon_button(FarmIcon.Kind.LOG, "更新日志")
	log_button.name = "LogButton"
	reset_cam_button = ui.make_icon_button(FarmIcon.Kind.RESET_CAM, "回正视角")
	reset_cam_button.name = "ResetCameraButton"
	for b in [code_btn, skill_button, hint_button, settings_button]:
		top_row.add_child(b)
	# Secondary actions live in settings; retain their real handlers and icons.
	ui_root.add_child(log_button)
	ui_root.add_child(reset_cam_button)
	log_button.hide()
	reset_cam_button.hide()
	code_btn.pressed.connect(_toggle_code_window)
	skill_button.pressed.connect(func() -> void: _toggle_panel("skill"))
	hint_button.pressed.connect(_toggle_hint_window)
	settings_button.pressed.connect(func() -> void: _toggle_panel("settings"))
	log_button.pressed.connect(func() -> void: _toggle_panel("log"))
	reset_cam_button.pressed.connect(func() -> void: reset_camera(false))

	_build_code_window()
	_build_hint_window()

	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.07, 0.08, 0.07, 0.46)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.visible = false
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	ui_root.add_child(backdrop)

	overlay_card = PanelContainer.new()
	overlay_card.name = "OverlayCard"
	overlay_card.visible = false
	overlay_card.set_anchors_preset(Control.PRESET_CENTER)
	overlay_card.offset_left = -560
	overlay_card.offset_right = 560
	overlay_card.offset_top = -460
	overlay_card.offset_bottom = 460
	overlay_card.add_theme_stylebox_override("panel", ui.flat(FarmPalette.SAGE_DEEP, 20, Vector4(28, 22, 28, 22), 16))
	ui_root.add_child(overlay_card)
	_fit_overlay()
	get_viewport().size_changed.connect(_fit_overlay)

	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 14)
	overlay_card.add_child(card_v)

	var head := HBoxContainer.new()
	card_v.add_child(head)
	overlay_title = Label.new()
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(overlay_title, 26, FarmPalette.CREAM, true)
	head.add_child(overlay_title)
	_panel_tabs = preload("res://scripts/farm_tabs.gd").new()
	_panel_tabs.chosen.connect(func(id: String) -> void:
		if _open_panel != id:
			_toggle_panel(id)
	)
	head.add_child(_panel_tabs)
	overlay_close = ui.make_icon_button(FarmIcon.Kind.CLOSE, "关闭", false, Vector2(44, 44))
	overlay_close.pressed.connect(_close_panel)
	head.add_child(overlay_close)

	overlay_body = Control.new()
	overlay_body.name = "OverlayBody"
	overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.custom_minimum_size = Vector2(0, 360)
	var body_clip := Control.new()
	body_clip.clip_contents = true
	body_clip.custom_minimum_size = Vector2(0, 360)
	body_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_v.add_child(body_clip)
	overlay_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body_clip.add_child(overlay_body)


func _fit_overlay() -> void:
	if overlay_card == null:
		return
	FarmMotion.stop(overlay_card)
	var viewport_size := get_viewport().get_visible_rect().size
	var half_width := minf(560.0, (viewport_size.x - 48.0) * 0.5)
	var half_height := minf(410.0, (viewport_size.y - 72.0) * 0.5)
	overlay_card.offset_left = -half_width
	overlay_card.offset_right = half_width
	overlay_card.offset_top = -half_height
	overlay_card.offset_bottom = half_height
	overlay_card.set_meta("_fm_base_top", -half_height)
	overlay_card.set_meta("_fm_base_bot", half_height)
	if overlay_card.visible:
		if _open_panel.is_empty():
			# A resize must not cancel a closing tween and leave its invisible
			# backdrop permanently intercepting clicks.
			FarmMotion.close_overlay(backdrop, overlay_card, FarmMotion.CLOSE_DUR, true)
		else:
			overlay_card.modulate.a = 1.0
			backdrop.modulate.a = 1.0


func _window_bar_style() -> StyleBoxFlat:
	return ui.flat(Color(0.20, 0.24, 0.21, 1), 0, Vector4(12, 6, 10, 6), 0)


func _build_code_window() -> void:
	code_window = preload("res://scripts/farm_window.gd").new()
	code_window.name = "CodeWindow"
	ui_root.add_child(code_window)
	code_window.setup("代码", ui.make_button, ui.flat(FarmPalette.SAGE_BG, 16, Vector4(0, 0, 0, 0), 14), _window_bar_style(), ui.apply_font)
	code_window.min_window_size = Vector2(360, 280)
	code_window.set_position(_code_default.position)
	code_window.set_size(_code_default.size)
	_attach_run_buttons(code_window)
	# FarmWindow owns its close animation; listeners must not hide it early.
	code_window.close_requested.connect(_restore_hint_after_code_max)
	code_window.maximize_changed.connect(_on_code_maximize_changed)
	code_window.resized.connect(func() -> void:
		if highlight:
			highlight.queue_redraw()
	)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	code_window.content.add_child(vbox)

	_file_bar_wrap = Control.new()
	_file_bar_wrap.name = "FileBarWrap"
	_file_bar_wrap.custom_minimum_size = Vector2(0, 32)
	_file_bar_wrap.visible = false
	vbox.add_child(_file_bar_wrap)
	_file_bar = HBoxContainer.new()
	_file_bar.name = "FileBar"
	_file_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_file_bar.add_theme_constant_override("separation", 6)
	_file_bar_wrap.add_child(_file_bar)

	var editor_wrap := Control.new()
	editor_wrap.name = "EditorWrap"
	editor_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_wrap.clip_contents = true
	var framework_note := Label.new()
	framework_note.name = "FrameworkNote"
	framework_note.text = "框架已锁定 · 在 main 内编写操作，可在 main 前添加函数"
	framework_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.apply_font(framework_note, 14, Color(0.65, 0.75, 0.68))
	vbox.add_child(framework_note)
	vbox.add_child(editor_wrap)

	editor = preload("res://scripts/farm_code_editor.gd").new()
	_setup_editor_assist()
	editor.name = "CodeEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.gutters_draw_line_numbers = true
	editor.draw_tabs = false
	editor.draw_spaces = false
	editor.indent_automatic = true
	editor.indent_size = 4
	editor.indent_use_spaces = true
	editor.set_tab_size(4)
	editor.indent_wrapped_lines = true
	editor.auto_brace_completion_enabled = true
	editor.auto_brace_completion_highlight_matching = true
	editor.indent_automatic_prefixes = PackedStringArray(["{", ":"])
	editor.placeholder_text = "int main() { harvest(); }"
	editor.text = STARTER
	editor.highlight_current_line = true
	editor.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	var ed_style := ui.flat(Color(0.09, 0.11, 0.10, 1), 12, Vector4(14, 12, 14, 12))
	editor.add_theme_stylebox_override("normal", ed_style)
	editor.add_theme_stylebox_override("focus", ed_style)
	editor.add_theme_stylebox_override("read_only", ed_style)
	if ui.font_mono:
		editor.add_theme_font_override("font", ui.font_mono)
	editor_assist.apply_font_size()
	editor.add_theme_color_override("font_color", FarmPalette.SYN_IDENT)
	editor.add_theme_color_override("font_readonly_color", FarmPalette.TEXT_DIM)
	editor.add_theme_color_override("caret_color", FarmPalette.GOLD_SOFT)
	editor.add_theme_color_override("current_line_color", Color(0.82, 0.68, 0.44, 0.06))
	editor.add_theme_color_override("selection_color", Color(0.78, 0.62, 0.38, 0.28))
	editor.add_theme_color_override("font_selected_color", FarmPalette.CREAM)
	editor.add_theme_color_override("word_highlighted_color", Color(0.78, 0.62, 0.38, 0.16))
	editor.add_theme_color_override("brace_mismatch_color", FarmPalette.DANGER)
	editor.add_theme_color_override("font_placeholder_color", Color(0.62, 0.60, 0.54, 0.55))
	editor.add_theme_color_override("completion_background_color", Color(0.14, 0.17, 0.15, 0.98))
	editor.add_theme_color_override("completion_selected_color", Color(0.78, 0.64, 0.42, 0.30))
	editor.add_theme_color_override("completion_existing_color", Color(0.78, 0.64, 0.42, 0.12))
	editor.add_theme_color_override("completion_font_color", FarmPalette.CREAM)
	editor.add_theme_color_override("line_number_color", Color(0.70, 0.72, 0.66, 0.90))
	editor.add_theme_constant_override("caret_width", 2)
	editor.gui_input.connect(editor_assist.gui_input)
	editor.focus_entered.connect(_on_editor_focus_entered)
	editor.resized.connect(func() -> void:
		if highlight:
			highlight.queue_redraw()
	)
	editor_wrap.add_child(editor)
	editor.framework_blocked.connect(func() -> void:
		framework_note.text = "固定框架受保护 · 请在 main 内编写，或在前面空行添加函数"
		FarmMotion.stop(framework_note)
		framework_note.modulate.a = 0.6
		var notice := framework_note.create_tween()
		framework_note.set_meta("_fm_tw", notice)
		notice.tween_property(framework_note, "modulate:a", 1.0, 0.2)
	)

	font_badge = Label.new()
	font_badge.name = "FontBadge"
	font_badge.text = "100%"
	font_badge.visible = false
	font_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	font_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	font_badge.tooltip_text = "双击复位字号"
	font_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	font_badge.anchor_left = 1.0
	font_badge.anchor_top = 1.0
	font_badge.anchor_right = 1.0
	font_badge.anchor_bottom = 1.0
	font_badge.offset_left = -78
	font_badge.offset_top = -28
	font_badge.offset_right = -10
	font_badge.offset_bottom = -8
	font_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.apply_font(font_badge, 16, FarmPalette.GOLD_SOFT, true)
	editor_assist.attach_font_badge(font_badge)
	editor_wrap.add_child(font_badge)

	highlight = preload("res://scripts/highlight_overlay.gd").new()
	highlight.name = "HighlightOverlay"
	editor_wrap.add_child(highlight)
	highlight.set_editor(editor)
	editor_assist.overlay = highlight

	error_markup = preload("res://scripts/error_markup.gd").new()
	error_markup.name = "ErrorMarkup"
	editor_wrap.add_child(error_markup)
	error_markup.set_editor(editor, ui.font_ui, ui.font_mono)
	var diagnostic_dock := ScrollContainer.new()
	diagnostic_dock.name = "DiagnosticDock"
	diagnostic_dock.custom_minimum_size = Vector2(0, 112)
	diagnostic_dock.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	diagnostic_dock.visible = false
	vbox.add_child(diagnostic_dock)
	error_markup.set_diagnostic_dock(diagnostic_dock)


func _build_hint_window() -> void:
	hint_window = preload("res://scripts/farm_window.gd").new()
	hint_window.name = "HintWindow"
	ui_root.add_child(hint_window)
	hint_window.setup("提示", ui.make_button, ui.flat(FarmPalette.SAGE_BG, 16, Vector4(0, 0, 0, 0), 14), _window_bar_style(), ui.apply_font)
	hint_window.min_window_size = Vector2(360, 180)
	hint_window.set_position(_hint_default.position)
	hint_window.set_size(_hint_default.size)
	hint_window.close_requested.connect(func() -> void:
		_hint_stash_visible = false
		_hint_stashed = false
		code_window.max_bottom_margin = 10.0
		code_window.refresh_max_rect()
	)
	hint_window.resized.connect(func() -> void: _refresh_hint_layout())

	hint_scroll = ScrollContainer.new()
	hint_scroll.name = "HintScroll"
	hint_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	hint_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	hint_window.content.add_child(hint_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 20)
	hint_scroll.add_child(margin)
	var hint_col := VBoxContainer.new()
	hint_col.name = "HintCol"
	hint_col.add_theme_constant_override("separation", 10)
	hint_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(hint_col)
	hint_body_label = Label.new()
	hint_body_label.name = "HintBody"
	hint_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ui.apply_font(hint_body_label, 20, FarmPalette.TEXT)
	hint_col.add_child(hint_body_label)
	hint_next_label = Label.new()
	hint_next_label.name = "HintNextLabel"
	ui.apply_font(hint_next_label, 17, FarmPalette.GOLD_SOFT)
	hint_col.add_child(hint_next_label)
	hint_next_code = CodeEdit.new()
	hint_next_code.name = "HintNextCode"
	hint_next_code.editable = false
	hint_next_code.caret_blink = false
	hint_next_code.context_menu_enabled = false
	hint_next_code.highlight_current_line = false
	hint_next_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	hint_next_code.scroll_fit_content_height = true
	hint_next_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui.font_mono:
		hint_next_code.add_theme_font_override("font", ui.font_mono)
	hint_next_code.add_theme_font_size_override("font_size", editor_assist.font_size_default)
	hint_next_code.add_theme_color_override("font_readonly_color", FarmPalette.SYN_IDENT)
	var next_style := ui.flat(Color(0.09, 0.11, 0.10, 1), 10, Vector4(12, 10, 12, 10))
	for state in ["normal", "read_only", "focus"]:
		hint_next_code.add_theme_stylebox_override(state, next_style)
	hint_col.add_child(hint_next_code)
	var next_step := Label.new()
	next_step.name = "HintNextStep"
	next_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(next_step, 17, FarmPalette.TEXT)
	hint_col.add_child(next_step)
	var bar := HBoxContainer.new()
	bar.name = "HintExemplarBar"
	bar.add_theme_constant_override("separation", 8)
	hint_col.add_child(bar)
	hint_exemplar_toggle = ui.make_button("范本 ▾", false, 90)
	hint_exemplar_toggle.name = "HintExemplarToggle"
	hint_exemplar_toggle.tooltip_text = "展开或收起范本"
	hint_exemplar_toggle.pressed.connect(_toggle_hint_exemplar)
	bar.add_child(hint_exemplar_toggle)
	hint_copy_button = ui.make_button("复制", false, 88)
	hint_copy_button.name = "HintCopyExemplar"
	hint_copy_button.tooltip_text = "复制完整主程序到剪贴板"
	hint_copy_button.pressed.connect(_copy_hint_exemplar)
	bar.add_child(hint_copy_button)
	hint_load_button = ui.make_button("载入", false, 76)
	hint_load_button.name = "HintLoadExemplar"
	hint_load_button.tooltip_text = "替换 main.cpp，并载入配套头文件"
	hint_load_button.pressed.connect(_load_hint_exemplar)
	bar.add_child(hint_load_button)
	hint_copied_label = Label.new()
	hint_copied_label.name = "HintCopied"
	hint_copied_label.text = "已复制"
	hint_copied_label.visible = false
	ui.apply_font(hint_copied_label, 17, FarmPalette.GOLD_SOFT)
	bar.add_child(hint_copied_label)
	hint_code = CodeEdit.new()
	hint_code.name = "HintCode"
	hint_code.editable = false
	hint_code.gutters_draw_line_numbers = true
	hint_code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	hint_code.scroll_fit_content_height = true
	hint_code.context_menu_enabled = false
	hint_code.caret_blink = false
	hint_code.highlight_current_line = false
	hint_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ui.font_mono:
		hint_code.add_theme_font_override("font", ui.font_mono)
	hint_code.add_theme_font_size_override("font_size", editor_assist.font_size_default)
	hint_code.add_theme_color_override("font_color", FarmPalette.SYN_IDENT)
	hint_code.add_theme_color_override("font_readonly_color", FarmPalette.SYN_IDENT)
	hint_code.add_theme_color_override("line_number_color", Color(0.70, 0.72, 0.66, 0.90))
	var hint_ed := ui.flat(Color(0.09, 0.11, 0.10, 1), 10, Vector4(12, 10, 12, 10))
	hint_code.add_theme_stylebox_override("normal", hint_ed)
	hint_code.add_theme_stylebox_override("read_only", hint_ed)
	hint_code.add_theme_stylebox_override("focus", hint_ed)
	hint_col.add_child(hint_code)
	var header_bar := HBoxContainer.new()
	header_bar.name = "HintHeaderBar"
	header_bar.add_theme_constant_override("separation", 8)
	hint_col.add_child(header_bar)
	hint_header_label = Label.new()
	hint_header_label.name = "HintHeaderName"
	hint_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(hint_header_label, 18, FarmPalette.TEXT)
	header_bar.add_child(hint_header_label)
	hint_header_copy = ui.make_button("复制", false, 88)
	hint_header_copy.name = "HintCopyHeader"
	hint_header_copy.tooltip_text = "复制这个头文件"
	hint_header_copy.pressed.connect(_copy_hint_header)
	header_bar.add_child(hint_header_copy)
	hint_header_code = hint_code.duplicate() as CodeEdit
	hint_header_code.name = "HintHeaderCode"
	hint_col.add_child(hint_header_code)
	hint_prose_after = Label.new()
	hint_prose_after.name = "HintAfter"
	hint_prose_after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_prose_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(hint_prose_after, 16, FarmPalette.TEXT)
	hint_col.add_child(hint_prose_after)
	hint_col.move_child(hint_prose_after, hint_code.get_index())
	hint_line = hint_body_label


func _toggle_code_window() -> void:
	if code_window == null:
		return
	if code_window.visible and not code_window.minimized and not code_window.is_closing():
		if code_window.has_method("dismiss"):
			code_window.call("dismiss")
		else:
			code_window.visible = false
		return
	code_window.reveal(code_window.current_restore_rect())
	code_window.move_to_front()


func _toggle_hint_window() -> void:
	if hint_window == null:
		return
	if hint_window.visible and not hint_window.minimized and _open_panel != "hint":
		# Refresh text and bring forward; second click hides.
		if hint_window.has_focus() or true:
			pass
	if hint_window.visible and not hint_window.minimized and not hint_window.is_closing():
		if hint_window.has_method("dismiss"):
			hint_window.call("dismiss")
		else:
			hint_window.visible = false
		return
	_apply_hint_text()
	hint_window.reveal(hint_window.current_restore_rect())
	hint_window.move_to_front()
	_refresh_hint_layout()


func _refresh_hint_layout() -> void:
	if hint_body_label == null or hint_scroll == null:
		return
	var width := hint_scroll.size.x
	if width < 80.0 and hint_window:
		width = maxf(80.0, hint_window.size.x - 44.0)
	width = maxf(160.0, width - 36.0)
	for node in [hint_body_label, hint_prose_after, hint_next_label, hint_scroll.find_child("HintNextStep", true, false)]:
		if node == null or not node.visible or node.text.is_empty():
			if node:
				node.custom_minimum_size = Vector2(width, 0)
			continue
		var font: Font = node.get_theme_font("font")
		var fs: int = node.get_theme_font_size("font_size")
		var height := 24.0
		if font:
			var sz := font.get_multiline_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, width, fs)
			height = sz.y + 8.0
		node.custom_minimum_size = Vector2(width, height)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hint_next_code and hint_next_code.visible:
		hint_next_code.custom_minimum_size = Vector2(width, 0)
	for code_box in [hint_code, hint_header_code]:
		if code_box and code_box.visible:
			var lines := maxi(code_box.get_line_count(), 1)
			var fs := editor_assist.font_size_default
			code_box.custom_minimum_size = Vector2(width, float(lines) * float(fs + 8) + 24.0)


func _on_code_maximize_changed(is_max: bool) -> void:
	if is_max:
		_stash_hint_for_code_max()
	else:
		_restore_hint_after_code_max()
	if highlight:
		highlight.queue_redraw()


func _stash_hint_for_code_max() -> void:
	if hint_window == null or _hint_stashed:
		return
	_hint_stashed = true
	_hint_stash_visible = hint_window.visible
	_hint_stash_minimized = bool(hint_window.get("minimized"))
	_hint_stash_maximized = bool(hint_window.get("maximized"))
	_hint_stash_rect = hint_window.current_restore_rect()
	if _hint_stash_visible:
		code_window.max_bottom_margin = 64.0
		if not _hint_stash_minimized and hint_window.has_method("set_minimized"):
			hint_window.call("set_minimized", true, true)
	else:
		code_window.max_bottom_margin = 10.0
	if code_window.has_method("refresh_max_rect"):
		code_window.call("refresh_max_rect")


func _restore_hint_after_code_max() -> void:
	if hint_window == null or not _hint_stashed:
		return
	_hint_stashed = false
	code_window.max_bottom_margin = 10.0
	if not _hint_stash_visible:
		hint_window.visible = false
		return
	hint_window.visible = true
	if hint_window.has_method("set_minimized"):
		hint_window.call("set_minimized", _hint_stash_minimized, true)
	if not _hint_stash_minimized:
		hint_window.reveal(_hint_stash_rect)
		if _hint_stash_maximized and not hint_window.maximized:
			hint_window.toggle_maximize()
	_refresh_hint_layout()


func _attach_run_buttons(win: FarmWindow) -> void:
	if win.tools_left == null:
		return
	run_loop_button = FarmRunButton.new()
	run_loop_button.name = "RunLoopButton"
	run_loop_button.mode = FarmRunButton.Mode.LOOP
	run_loop_button.tooltip_text = "运行"
	run_loop_button.pressed.connect(_on_run)
	run_once_button = FarmRunButton.new()
	run_once_button.name = "RunOnceButton"
	run_once_button.mode = FarmRunButton.Mode.ONCE
	run_once_button.tooltip_text = "单步"
	run_once_button.pressed.connect(_on_step)
	win.tools_left.add_child(run_loop_button)
	win.tools_left.add_child(run_once_button)


func _advance_sim(delta: float) -> void:
	if _stepping and (host.is_running() or host.is_paused()):
		host.step_seconds(delta)
		if host.is_finished() or host.last_error() != "":
			_stepping = false
		elif host.is_paused():
			_stepping = false
			if editor:
				editor.editable = true
			_update_buttons()
		return
	host.advance_seconds(delta)


func _process(delta: float) -> void:
	if _session_phase != "playing":
		_tick_intro(delta)
		return
	_save_elapsed += delta
	if _save_elapsed >= 5.0:
		_save_elapsed = 0.0
		_queue_save()
	_hover_t += delta
	camera_rig.update_input(delta)
	_advance_sim(delta)
	var err: String = host.last_error()
	if err != "":
		_stepping = false
		if not _error_latched:
			_present_host_error(true)
		if _error_runtime:
			_sync_highlight(delta)
		if editor:
			editor.editable = true
		_update_buttons()
	elif host.is_running() or host.is_paused() or _stepping:
		_sync_highlight(delta)
		if host.take_flip_pulse():
			bot.play_flip()
		if (not bot.tilling) and str(host.current_action()) == "till" and float(host.current_action_progress()) < 0.28:
			bot.play_till()
	elif host.is_finished():
		_clear_highlight()
		_update_buttons()

	# These signals describe the result at action START. Grass becoming ripe
	# during a failed swing must never turn it into a successful harvest effect.
	var harvested: bool = host.take_harvest_pulse()
	var missed: bool = host.take_harvest_miss_pulse()
	if harvested:
		_on_harvested()
		_queue_save()
	elif missed:
		bot.play_harvest_swing(false)
		_sfx("miss")

	field.ensure_size(host.get_world_size())
	field.update(delta)
	bot.sync_fleet()
	bot.update(delta)
	_refresh_file_bar_visibility()
	camera_rig.update(delta)
	_update_hay()
	_maybe_unlock_hint()
	if _open_panel == "skill":
		var pulse := 0.5 + 0.5 * sin(_hover_t * 2.4)
		for card in _skill_glow_nodes:
			if card is Control and is_instance_valid(card):
				var m := 1.0 + 0.08 * pulse
				(card as Control).modulate = Color(m, m, 0.92 + 0.08 * pulse, 1)


func _on_run() -> void:
	if host.is_running() and not host.is_paused() and not _stepping:
		_on_stop()
		return
	_stepping = false
	if host.is_paused():
		host.resume()
		if editor:
			editor.release_focus()
			editor.editable = false
		_update_buttons()
		return
	_start_program()


func _on_run_loop() -> void:
	_on_run()


func _on_run_once() -> void:
	_on_run()


func _on_step() -> void:
	if host.is_running() and not host.is_paused():
		if _stepping:
			_on_stop()
			return
		_stepping = true
		_update_buttons()
		return
	if host.is_paused():
		_stepping = true
		host.resume()
		if editor:
			editor.release_focus()
			editor.editable = false
		_update_buttons()
		return
	_start_program()
	_stepping = true


func _start_program() -> void:
	if host.is_running():
		return
	_clear_error_markup()
	_clear_highlight()
	_flush_active_file()
	_push_includes_to_host()
	var src := editor.text if _active_file == "main.cpp" else str(_user_files.get("main.cpp", editor.text))
	if _active_file != "main.cpp" and _user_files.has("main.cpp"):
		src = str(_user_files["main.cpp"])
	# Always run the main file; unsaved current include is already pushed.
	if _active_file == "main.cpp":
		src = editor.text
	var err: String = host.load_script(src)
	if err != "":
		_present_host_error(false)
		_stepping = false
		_update_buttons()
		return
	if editor:
		editor.release_focus()
	host.start()
	if editor:
		editor.editable = false
	_update_buttons()


func _on_stop() -> void:
	_stepping = false
	host.stop()
	bot.reset_actions()
	if editor:
		editor.editable = true
	_clear_highlight()
	_update_buttons()


func _on_editor_focus_entered() -> void:
	if host.is_running() or host.is_paused() or _stepping:
		_on_stop()


func _update_hay() -> void:
	if hay_label:
		hay_label.text = str(host.get_hay())
	if wood_label:
		wood_label.text = str(host.get_wood())
	if wood_wrap:
		wood_wrap.visible = host.get_wood() > 0 or host.plant_unlocked()
	if _item_chips:
		for key in _item_chips.keys():
			var chip: Dictionary = _item_chips[key]
			var n := int(host.get_item(key))
			chip["label"].text = str(n)
			var show := n > 0
			if key == "carrot":
				show = show or host.is_unlocked("carrot")
			elif key == "pumpkin":
				show = show or host.is_unlocked("pumpkin")
			elif key == "power":
				show = show or host.is_unlocked("sun")
			elif key == "water_tank":
				show = show or host.is_unlocked("water")
			elif key == "fertilizer" or key == "weird":
				show = show or host.is_unlocked("fert")
			elif key == "gold":
				show = show or host.is_unlocked("maze")
			elif key == "cactus":
				show = show or host.is_unlocked("cactus")
			elif key == "bone":
				show = show or host.is_unlocked("dino")
			chip["row"].visible = show


func _update_buttons() -> void:
	var running: bool = host.is_running()
	var paused: bool = host.is_paused()
	if run_loop_button:
		run_loop_button.active = running and not _stepping and not paused
	if run_once_button:
		run_once_button.active = _stepping and running
	if not running and not _stepping and editor:
		editor.editable = true


func _skill_owned(id: String) -> bool:
	return id == "harvest" or bool(host.is_unlocked(id))


# The skill the hint is about: the one bought last, else the furthest owned
# skill along the playthrough order.
func _hint_skill() -> String:
	if hint_skill_id != "" and _skill_owned(hint_skill_id):
		return hint_skill_id
	var best := "harvest"
	for id in FarmSkillData.EXEMPLAR_ORDER:
		if _skill_owned(str(id)):
			best = str(id)
	return best


func _skill_display_name(id: String) -> String:
	for n in _skill_nodes():
		if str(n["id"]) == id:
			return str(n["name"])
	return id


func _hint_header() -> Dictionary:
	var headers := FarmSkillData.exemplar_headers(_hint_skill())
	for k in headers.keys():
		return {"name": str(k), "text": str(headers[k])}
	return {}


func _apply_hint_text() -> void:
	if hint_line == null:
		return
	var id := _hint_skill()
	# One sentence of pain, then the exemplar.
	hint_body_label.text = "%s：%s" % [_skill_display_name(id), FarmSkillData.pain(id)]
	hint_body_label.visible = true
	var focus_line := FarmSkillData.next_line(id)
	hint_next_label.text = "买「条件」后，在 while 里加这一行" if id == "speed" else "这一行写在原有 while 里" if id == "iff" else "这次用到"
	hint_next_label.visible = not focus_line.is_empty()
	hint_next_code.text = focus_line
	hint_next_code.visible = not focus_line.is_empty()
	if editor_assist.highlighter:
		hint_next_code.syntax_highlighter = editor_assist.highlighter.duplicate()
	var next_step: Label = hint_scroll.find_child("HintNextStep", true, false)
	next_step.text = "停循环，等熟单收 → 攒 12 干草买「条件」。" if id == "speed" else "未熟时只查询，不伤幼苗。" if id == "iff" else ""
	if next_step.text.is_empty():
		next_step.text = FarmSkillData.remedy(id)
	next_step.visible = not next_step.text.is_empty()
	var code := FarmSkillData.exemplar(id)
	if code.is_empty():
		code = _skill_template(id)
	var has_code := not code.is_empty()
	if hint_exemplar_toggle:
		hint_exemplar_toggle.visible = has_code
		hint_exemplar_toggle.text = "范本 ▾" if _hint_exemplar_open else "范本 ▸"
	if hint_copy_button:
		hint_copy_button.visible = has_code
	if hint_load_button:
		hint_load_button.visible = has_code
	if hint_code:
		hint_code.text = code
		hint_code.visible = has_code and _hint_exemplar_open
		hint_code.add_theme_font_size_override("font_size", editor_assist.font_size_default)
		if editor_assist.highlighter:
			hint_code.syntax_highlighter = editor_assist.highlighter.duplicate()
	var header := _hint_header()
	var show_header := not header.is_empty() and _hint_exemplar_open
	if hint_header_label:
		hint_header_label.text = "还要新建 %s：" % str(header.get("name", "")) if show_header else ""
		hint_header_label.get_parent().visible = show_header
	if hint_header_code:
		hint_header_code.text = str(header.get("text", ""))
		hint_header_code.visible = show_header
		hint_header_code.add_theme_font_size_override("font_size", editor_assist.font_size_default)
		if editor_assist.highlighter:
			hint_header_code.syntax_highlighter = editor_assist.highlighter.duplicate()
	if hint_prose_after:
		hint_prose_after.text = "复制完整程序；载入会替换主程序。"
		hint_prose_after.visible = has_code and _hint_exemplar_open
	_refresh_hint_layout()
	# Sizes settle a frame later (e.g. right after a reset); lay out again then.
	call_deferred("_refresh_hint_layout")


func _toggle_hint_exemplar() -> void:
	_hint_exemplar_open = not _hint_exemplar_open
	_apply_hint_text()


func _flash_copied(label: Label) -> void:
	if label == null:
		return
	label.visible = true
	label.modulate = Color(1, 1, 1, 1)
	FarmMotion.stop(label, "_copied")
	var tw := label.create_tween()
	label.set_meta("_copied", tw)
	tw.tween_interval(0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.visible = false
			label.modulate = Color(1, 1, 1, 1)
	)


func _copy_hint_exemplar() -> void:
	var text := FarmSkillData.exemplar(_hint_skill())
	if text.is_empty():
		return
	last_copied_template = text
	DisplayServer.clipboard_set(text)
	_flash_copied(hint_copied_label)


func _copy_hint_header() -> void:
	var header := _hint_header()
	if header.is_empty():
		return
	last_copied_template = str(header["text"])
	DisplayServer.clipboard_set(last_copied_template)
	_flash_copied(hint_copied_label)


func _maybe_unlock_hint(refresh_panel: bool = true) -> void:
	var changed := false
	if host.loops_unlocked() and not _loops_seen:
		_loops_seen = true
		changed = true
	if host.speed_unlocked() and not _speed_seen:
		_speed_seen = true
		changed = true
	if host.conditions_unlocked() and not _if_seen:
		_if_seen = true
		changed = true
	if host.movement_unlocked() and not _move_seen:
		_move_seen = true
		changed = true
	if host.for_unlocked() and not _for_seen:
		_for_seen = true
		changed = true
	if host.till_unlocked() and not _till_seen:
		_till_seen = true
		changed = true
	if host.plant_unlocked() and not _plant_seen:
		_plant_seen = true
		changed = true
	if changed:
		_apply_hint_text()
		if hint_window and hint_window.visible:
			_apply_hint_text()
		if refresh_panel and _open_panel == "skill":
			_fill_panel("skill")
		elif refresh_panel and _open_panel == "hint":
			_fill_panel("hint")



func _present_host_error(runtime: bool) -> void:
	var message := str(host.last_error())
	if message.is_empty():
		return
	_error_latched = true
	_error_runtime = runtime
	_error_history.append(message)
	if editor and _active_file != "main.cpp":
		_switch_user_file("main.cpp")
	if editor:
		var target_line := clampi(int(host.error_line()) - 1, 0, editor.get_line_count() - 1)
		editor.set_caret_line(target_line)
		editor.set_caret_column(maxi(int(host.error_col_start()) - 1, 0))
		editor.center_viewport_to_caret()
	if error_markup:
		error_markup.show_diagnostic(
			int(host.error_line()),
			int(host.error_col_start()),
			int(host.error_col_end()),
			message,
			str(host.error_suggestion()),
			str(host.error_kind())
		)
	if runtime:
		bot.play_stuck()
		# Keep the execution highlight on the failing line.
		_apply_highlight(int(host.error_line()) - 1)
	if editor:
		editor.editable = true


func _clear_error_markup() -> void:
	_error_latched = false
	_error_runtime = false
	if error_markup and error_markup.has_method("clear"):
		error_markup.clear()


func _dismiss_error() -> void:
	if error_markup and error_markup.has_method("is_showing") and error_markup.is_showing():
		error_markup.dismiss()
	_error_latched = false


func _maybe_dismiss_error_on_edit() -> void:
	if error_markup == null or not error_markup.is_showing():
		return
	var line_1: int = int(error_markup.shown_line_1())
	if line_1 <= 0:
		_dismiss_error()
		return
	var idx := line_1 - 1
	if idx < 0 or idx >= editor.get_line_count():
		_dismiss_error()
		return
	if editor.get_line(idx) != error_markup.shown_source():
		_dismiss_error()


func _maybe_dismiss_error_on_click(local_pos: Vector2) -> void:
	if error_markup == null or not error_markup.is_showing():
		return
	var lc: Vector2i = editor.get_line_column_at_pos(local_pos, true)
	# Godot returns Vector2i(column, line).
	if lc.y < 0:
		_dismiss_error()
		return
	if lc.y != error_markup.shown_line_1() - 1:
		_dismiss_error()


func _sync_highlight(delta: float) -> void:
	var line: int = host.get_current_line() - 1
	var action: String = host.current_action()
	var long_action: bool = action == "harvest" or action == "do_a_flip" or action == "move" or action == "till" or action == "plant"
	if long_action:
		highlight.set_progress(host.current_action_progress())
	elif line == _highlighted_line:
		highlight.set_progress(host.current_action_progress())
	if line == _highlighted_line:
		_pending_line = -1
		_pending_t = 0.0
		if line >= 0:
			editor.set_caret_line(line)
		return
	if long_action or line < 0:
		_apply_highlight(line)
		if long_action:
			highlight.set_progress(host.current_action_progress())
		return
	if line != _pending_line:
		_pending_line = line
		_pending_t = 0.0
	_pending_t += delta
	if _pending_t >= 0.08:
		_apply_highlight(line)


func _apply_highlight(line: int) -> void:
	if line >= 0 and line < editor.get_line_count():
		highlight.set_current_line(line)
		editor.set_caret_line(line)
		_highlighted_line = line
	else:
		highlight.clear_line()
		_highlighted_line = -1
	_pending_line = -1
	_pending_t = 0.0


func _clear_highlight() -> void:
	highlight.clear_line()
	_highlighted_line = -1
	_pending_line = -1
	_pending_t = 0.0


func _input(event: InputEvent) -> void:
	if _session_phase != "playing":
		return
	# Camera press *and* release must be seen even if the cursor is over UI
	# when the button comes up; otherwise orbit/pan stick and the view follows
	# the mouse. Never capture the cursor.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		clear_camera_drag()
	camera_rig.handle_event(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _open_panel != "":
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_error()
		# Clicking empty farm gives the keyboard back to the camera.
		if not _point_over_ui(camera_rig.event_mouse_pos(event)):
			if get_viewport():
				get_viewport().gui_release_focus()
			if event.double_click:
				reset_camera(false)
				get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()
		get_tree().quit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_now()
		clear_camera_drag()
	elif what == NOTIFICATION_WM_MOUSE_EXIT:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			clear_camera_drag()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_panel()


func _toggle_panel(panel_id: String) -> void:
	if _open_panel == panel_id:
		_close_panel()
		return
	var previous := _open_panel
	var switching := overlay_card.visible and previous != ""
	_open_panel = panel_id
	_reset_confirming = false
	backdrop.move_to_front()
	overlay_card.move_to_front()
	_fill_panel(panel_id)
	_panel_tabs.select(panel_id, switching)
	if switching:
		var order := ["skill", "settings", "log"]
		FarmMotion.slide_content(overlay_body, 1.0 if order.find(panel_id) > order.find(previous) else -1.0)
	else:
		FarmMotion.stop(overlay_body, "_fm_content")
		overlay_body.position.x = 0.0
		overlay_body.modulate.a = 1.0
		FarmMotion.open_overlay(backdrop, overlay_card)


func _close_panel(instant: bool = false) -> void:
	_open_panel = ""
	_reset_confirming = false
	_close_skill_detail()
	FarmMotion.close_overlay(backdrop, overlay_card, FarmMotion.CLOSE_DUR, instant)


func _clear_overlay_body() -> void:
	for button in [log_button, reset_cam_button]:
		if is_instance_valid(button) and button.get_parent() != ui_root:
			button.reparent(ui_root)
			button.hide()
	if is_instance_valid(skill_scroll) and skill_scroll.is_inside_tree():
		_skill_view = {"zoom": skill_scroll.get("zoom"), "scroll": Vector2(skill_scroll.scroll_horizontal, skill_scroll.scroll_vertical)}
		skill_scroll = null
	_skill_glow_nodes.clear()
	skill_detail = null
	for child in overlay_body.get_children():
		overlay_body.remove_child(child)
		child.queue_free()


func _fill_panel(panel_id: String) -> void:
	_clear_overlay_body()
	match panel_id:
		"skill":
			overlay_title.text = "技能树"
			_fill_skill_tree()
		"hint":
			overlay_title.text = "提示"
			_fill_hint_panel()
		"settings":
			overlay_title.text = "设置"
			_fill_settings_panel()
		"log":
			overlay_title.text = "更新日志"
			_fill_log_panel()


func _fill_hint_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var id := _hint_skill()
	label.text = "%s：%s\n\n范本\n\n%s" % [_skill_display_name(id), FarmSkillData.pain(id), FarmSkillData.exemplar(id)]
	ui.apply_font(label, 20, FarmPalette.TEXT)
	scroll.add_child(label)
	label.custom_minimum_size = Vector2(620, 0)


func _fill_log_panel() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(scroll)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = FarmChangelog.TEXT
	ui.apply_font(label, 20, FarmPalette.TEXT)
	scroll.add_child(label)
	label.custom_minimum_size = Vector2(620, 0)


func _fill_settings_panel() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 18)
	overlay_body.add_child(box)
	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 14)
	box.add_child(utility_row)
	for spec in [[reset_cam_button, "视角回正"], [log_button, "更新日志"]]:
		var button: Button = spec[0]
		button.reparent(utility_row)
		button.show()
		var label := _settings_label(spec[1])
		utility_row.add_child(label)
	var save_status := Label.new()
	save_status.text = _save_message if not _save_message.is_empty() else "进度自动保存 · 关闭后可继续"
	ui.apply_font(save_status, 17, FarmPalette.TEXT_DIM)
	box.add_child(save_status)

	box.add_child(_settings_label("运行速度"))
	var speed_note := Label.new()
	speed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var speed_text := "开局为 1×。速度由技能决定，不能在设置里拉快。"
	if host.speed_unlocked():
		speed_text = "收割与挥空都随技能加快；草仍长 1 秒，未熟就砍会重新长。"
	speed_note.text = speed_text
	ui.apply_font(speed_note, 19, FarmPalette.TEXT)
	box.add_child(speed_note)

	box.add_child(_settings_label("编辑器字号"))
	var font_row := preload("res://scripts/farm_tabs.gd").new()
	font_row.name = "FontOptions"
	font_row.options = [["16", "16"], ["18", "18"], ["20", "20"]]
	font_row.selected = str(editor_assist.font_size)
	font_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	font_row.chosen.connect(func(value: String) -> void:
		editor_assist.set_font_size(int(value), true, false)
		font_row.select(value)
	)
	box.add_child(font_row)

	box.add_child(_settings_label("声音"))
	var sound_row := preload("res://scripts/farm_tabs.gd").new()
	sound_row.name = "SoundOptions"
	sound_row.options = [["0", "关"], ["1", "轻"], ["2", "开"]]
	sound_row.selected = str(_sound_level)
	sound_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sound_row.chosen.connect(func(value: String) -> void:
		_set_sound_level(int(value))
		sound_row.select(value)
		_sfx("harvest")
		_queue_save(true)
	)
	box.add_child(sound_row)

	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "重置会清空当前干草、木头、累计收获和已解锁的能力，并把农场、窗口和编辑器恢复到开局。字号和声音设置会保留。"
	ui.apply_font(note, 18, FarmPalette.TEXT_DIM)
	box.add_child(note)

	if _reset_confirming:
		var warn := Label.new()
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.text = "确认重置农场吗？进度将全部清除，无法撤回。"
		ui.apply_font(warn, 20, FarmPalette.DANGER)
		box.add_child(warn)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var yes := ui.make_button("确认重置", true, 120)
		var no := ui.make_button("取消", false, 88)
		yes.pressed.connect(_confirm_reset)
		no.pressed.connect(func() -> void:
			_reset_confirming = false
			_fill_panel("settings")
		)
		row.add_child(yes)
		row.add_child(no)
	else:
		var reset_btn := ui.make_button("重置农场", false, 120)
		reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		reset_btn.pressed.connect(func() -> void:
			_reset_confirming = true
			_fill_panel("settings")
		)
		box.add_child(reset_btn)


func _settings_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	ui.apply_font(label, 20, FarmPalette.GOLD_SOFT, true)
	return label


func _confirm_reset() -> void:
	_on_stop()
	host.reset_world()
	_user_files = {"main.cpp": STARTER}
	_active_file = "main.cpp"
	hint_skill_id = ""
	editor.protect_framework = true
	editor.text = STARTER
	_rebuild_file_bar()
	editor.editable = true
	_clear_error_markup()
	_loops_seen = false
	_speed_seen = false
	_if_seen = false
	_move_seen = false
	_for_seen = false
	_till_seen = false
	_plant_seen = false
	_reset_confirming = false
	bot.reset_actions()
	_stepping = false
	_clear_highlight()
	_apply_hint_text()
	field.ensure_size(1)
	reset_camera(true)
	bot.snap()
	camera_rig.apply_home(1, false)
	if code_window:
		if code_window.maximized:
			code_window.toggle_maximize()
		code_window.set_minimized(false, true)
		code_window.reveal(_code_default)
	if hint_window:
		if hint_window.maximized:
			hint_window.toggle_maximize()
		hint_window.set_minimized(false, true)
		hint_window.reveal(_hint_default)
	_update_hay()
	_update_buttons()
	_close_panel()
	_queue_save()


func _skill_nodes() -> Array:
	return FarmSkillData.nodes(host)


func _skill_template(id: String) -> String:
	return FarmSkillData.exemplar(id)


func _skill_knowledge(id: String) -> String:
	var extra := FarmSkillData.knowledge(id)
	if extra != "":
		return extra
	match id:
		"harvest":
			return "harvest() 是一次函数调用，做完就往下走。把语句放进 int main()，程序才有入口。do_a_flip() 只是表演，不改农场。"
		"loop":
			return "while (true) 会反复执行花括号里的语句，直到你停下。开局一次收割大约要 1 秒，和草长熟的时间一样，所以循环正好能一刀接一刀收到成熟的草。"
		"speed":
			return "所有挥刀约快 2 倍，每刀 200 tick；草仍要 400 tick 才熟。未熟就砍会打回幼苗，连续盲收会长不熟。先停循环，等熟再单收攒够 12 干草；买「条件」后用 can_harvest() 等熟再收。"
		"iff":
			return "在已有的 while 里加 if (can_harvest()) harvest();，只在成熟时收割。查询只花 1 tick，不打断幼苗生长；一档加速后约每 400 tick 收一棵。"
		"move":
			return "move(East) 走到邻格，到边缘会从对侧出现。解锁时农场扩大为 3×3。方向名可以写成 enum Dir。"
		"forl":
			return "for (int i = 0; i < 3; i++) 把同一段动作做固定次数，适合走完一垄。现在 i 还不能拿来运算。"
		"till":
			return "till() 把草地翻成土壤（并清掉上面的植物），再翻一次变回草地。土壤自己不会长草。"
		"plant":
			return "plant(Bush) 只能种在空的土壤上，灌木 2 秒成熟，收割得到木头。用 get_entity_type() 和 get_ground_type() 判断格子。"
		"vars":
			return "变量用来记住一个有类型的值，例如 int 或 bool。有了它，循环变量才能真正拿来计数。"
		"fn":
			return "把一段重复的动作写成函数，main 里只要调用名字。以后可以在 main 外面定义 harvest_row()。"
		_:
			return ""


func _fill_skill_tree() -> void:
	_skill_glow_nodes.clear()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_body.add_child(root)

	var scroll := preload("res://scripts/farm_skill_scroll.gd").new()
	scroll.node_clicked.connect(click_skill_node)
	scroll.name = "SkillScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 44
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)
	skill_scroll = scroll

	var wrap := Control.new()
	wrap.name = "SkillWrap"
	wrap.custom_minimum_size = FarmSkillData.CANVAS_SIZE
	scroll.add_child(wrap)
	var canvas := Control.new()
	canvas.name = "SkillCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_child(canvas)
	scroll.configure(canvas, wrap, FarmSkillData.CANVAS_SIZE)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(toolbar)
	var guide := Label.new()
	guide.text = "学习路线 · 左拖 / 滚轮缩放"
	guide.tooltip_text = "主线向下，支线补充；完整前置见节点提示。左键拖动，滚轮缩放。"
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(guide, 17, FarmPalette.TEXT)
	toolbar.add_child(guide)
	var zoom_label := Label.new()
	ui.apply_font(zoom_label, 16, FarmPalette.TEXT)
	zoom_label.text = "100%"
	toolbar.add_child(zoom_label)
	scroll.zoom_changed.connect(func(value: float) -> void: zoom_label.text = "%d%%" % roundi(value * 100.0))
	var overview := ui.make_button("全貌", false, 72)
	overview.name = "SkillFitAll"
	overview.tooltip_text = "缩放到完整技能树"
	overview.pressed.connect(scroll.fit_all)
	toolbar.add_child(overview)
	var actual := ui.make_button("还原", false, 72)
	actual.name = "SkillZoomReset"
	actual.pressed.connect(func() -> void: scroll.zoom_about(1.0))
	toolbar.add_child(actual)

	var nodes := _skill_nodes()
	var index := {}
	for node in nodes:
		index[node["id"]] = node

	var lines := Control.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_w := 100.0
	var node_h := 120.0
	lines.draw.connect(func() -> void:
		var pairs := FarmSkillData.edges()
		for pair in pairs:
			var a: Dictionary = index[pair[0]]
			var b: Dictionary = index[pair[1]]
			var same_row: bool = absf(float((a["pos"] as Vector2).y) - float((b["pos"] as Vector2).y)) < 8.0
			var pa: Vector2
			var pb: Vector2
			var detour := false
			if same_row:
				var left_first: bool = (a["pos"] as Vector2).x <= (b["pos"] as Vector2).x
				pa = a["pos"] + Vector2(node_w if left_first else 0.0, node_h * 0.5)
				pb = b["pos"] + Vector2(0.0 if left_first else node_w, node_h * 0.5)
				var x0 := minf(pa.x, pb.x)
				var x1 := maxf(pa.x, pb.x)
				for other in nodes:
					if str(other["id"]) == str(a["id"]) or str(other["id"]) == str(b["id"]):
						continue
					var op: Vector2 = other["pos"]
					if absf(op.y - float((a["pos"] as Vector2).y)) < 8.0 and op.x + 10.0 < x1 and op.x + node_w - 10.0 > x0:
						detour = true
						break
			else:
				pa = a["pos"] + Vector2(node_w * 0.5, node_h - 2.0)
				pb = b["pos"] + Vector2(node_w * 0.5, 2.0)
			var col := Color(0.72, 0.70, 0.64, 0.18)
			var width := 2.0
			if a["owned"] and b["owned"]:
				col = Color(0.80, 0.70, 0.50, 0.72)
				width = 2.6
			elif a["owned"] and not b.get("soon", false):
				col = Color(0.80, 0.70, 0.50, 0.34)
				width = 2.2
			_draw_skill_branch(lines, pa, pb, col, width, detour)
	)
	canvas.add_child(lines)

	for node in nodes:
		var card := _skill_node_card(node)
		card.position = node["pos"]
		canvas.add_child(card)
	lines.queue_redraw()

	_skill_more_hint = Control.new()
	_skill_more_hint.name = "SkillMoreHint"
	_skill_more_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_more_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skill_more_hint.offset_top = -36
	_skill_more_hint.offset_bottom = 0
	_skill_more_hint.draw.connect(func() -> void:
		if skill_scroll == null:
			return
		var bar := skill_scroll.get_v_scroll_bar()
		if bar and bar.value < bar.max_value - skill_scroll.size.y - 8:
			var w := _skill_more_hint.size.x
			var h := _skill_more_hint.size.y
			_skill_more_hint.draw_rect(Rect2(0, 0, w, h), Color(0.11, 0.14, 0.13, 0.0))
			var fade := Color(0.11, 0.14, 0.13, 0.55)
			for i in 10:
				var a := 0.0 + 0.07 * float(i)
				_skill_more_hint.draw_rect(Rect2(0, h * float(i) / 10.0, w, h / 10.0 + 1), Color(fade.r, fade.g, fade.b, a))
			var mid := Vector2(w * 0.5, h * 0.62)
			_skill_more_hint.draw_colored_polygon(PackedVector2Array([
				mid + Vector2(-10, -4), mid + Vector2(10, -4), mid + Vector2(0, 6)
			]), Color(0.86, 0.78, 0.58, 0.55))
	)
	root.add_child(_skill_more_hint)
	var vbar := scroll.get_v_scroll_bar()
	if vbar:
		vbar.value_changed.connect(func(_v: float) -> void:
			if _skill_more_hint:
				_skill_more_hint.queue_redraw()
		)
	# Nudge scroll so the first view already shows a cut-off lower branch.
	scroll.zoom_about(float(_skill_view["zoom"]), Vector2.ZERO)
	scroll.call_deferred("_apply_zoom_scroll", _skill_view["scroll"])
	skill_detail = _make_skill_detail()
	skill_detail.visible = false
	root.add_child(skill_detail)
	scroll.blocking_control = skill_detail
	if _selected_skill_id != "":
		_open_skill_detail(_selected_skill_id)


func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _append_round_corner(points: PackedVector2Array, p: Vector2, q: Vector2, r: Vector2, radius: float) -> void:
	var v1 := p - q
	var v2 := r - q
	var l1 := v1.length()
	var l2 := v2.length()
	if l1 < 1.0 or l2 < 1.0:
		points.append(q)
		return
	var rad := minf(radius, minf(l1, l2) * 0.48)
	var a := q + v1 * (rad / l1)
	var c := q + v2 * (rad / l2)
	points.append(a)
	for i in range(1, 7):
		var t := float(i) / 6.0
		points.append(_cubic_bezier(a, a.lerp(q, 0.55), c.lerp(q, 0.55), c, t))
	points.append(c)


func _draw_skill_branch(ci: Control, a: Vector2, b: Vector2, col: Color, width: float, detour_below: bool = false) -> void:
	var dy := b.y - a.y
	var dx := b.x - a.x
	var points := PackedVector2Array()
	if detour_below:
		var dip := 28.0
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), 14.0)
		_append_round_corner(points, Vector2(a.x, a.y + dip), Vector2(b.x, a.y + dip), b, 14.0)
		points.append(b)
	elif absf(dx) < 8.0:
		# Same column: a slightly eased vertical.
		var mid := (a + b) * 0.5
		for i in 8:
			var t := float(i) / 7.0
			points.append(_cubic_bezier(a, Vector2(a.x, mid.y), Vector2(b.x, mid.y), b, t))
	elif absf(dy) < 28.0:
		var sx := signf(dx) * clampf(absf(dx) * 0.4, 24.0, 56.0)
		_append_round_corner(points, a, a + Vector2(sx, 0), b, 18.0)
		points.append(b)
		if points.is_empty() or points[0] != a:
			var prefixed := PackedVector2Array([a])
			prefixed.append_array(points)
			points = prefixed
	else:
		# Rounded orthogonal: down from parent, across, down into the child.
		# Keep the horizontal in the corridor just below the parent so lines don't cut cards.
		var stub := 22.0
		var mid := Vector2(b.x, a.y + stub)
		var drop := Vector2(b.x, b.y)
		points.append(a)
		_append_round_corner(points, a, Vector2(a.x, a.y + stub), mid, 16.0)
		_append_round_corner(points, Vector2(a.x, a.y + stub), mid, drop, 16.0)
		points.append(b)
	if points.size() < 2:
		return
	ci.draw_polyline(points, col, width, true)


func _skill_node_card(node: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Skill_" + str(node["id"])
	card.custom_minimum_size = FarmSkillData.CARD_SIZE
	card.size = FarmSkillData.CARD_SIZE
	var owned: bool = node["owned"]
	var soon: bool = node.get("soon", false)
	var id := str(node["id"])
	var can_buy := false
	if not soon and id != "harvest":
		can_buy = bool(node.get("can_buy", false)) or (not owned and host.can_unlock(id))
	var bg := Color(0.30, 0.27, 0.20, 0.95) if owned else Color(0.18, 0.19, 0.18, 0.90)
	if soon:
		bg = Color(0.15, 0.16, 0.15, 0.72)
	elif not owned:
		bg = Color(0.16, 0.17, 0.16, 0.88)
	var style := ui.flat(bg, 12, Vector4(6, 5, 6, 4), 2)
	if can_buy:
		style.border_color = Color(0.65, 0.81, 0.64, 0.90)
		style.set_border_width_all(2)
	elif owned:
		style.border_color = Color(0.80, 0.70, 0.50, 0.30)
		style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not soon else Control.CURSOR_ARROW
	if soon:
		card.tooltip_text = "即将开放"
	elif not owned:
		card.tooltip_text = "前置：%s\n%s" % [FarmSkillData.prerequisite_text(id), FarmSkillData.cost_text(node.get("cost_map", {}))]
	else:
		card.tooltip_text = "已解锁 · 点击查看"
	card.tooltip_text = FarmSkillData.guidance(id) + "\n" + card.tooltip_text

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var icon := FarmIcon.new()
	if soon:
		icon.kind = FarmIcon.Kind.LOCK
		icon.icon_color = Color(0.62, 0.62, 0.58, 0.45)
	else:
		icon.kind = FarmIcon.kind_from_name(id)
		icon.icon_color = FarmPalette.GOLD_SOFT if owned else Color(0.62, 0.62, 0.58, 0.70)
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)

	var title := Label.new()
	title.text = str(node["name"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(title, 18, Color(0.84, 0.76, 0.58, 1) if owned else Color(0.74, 0.73, 0.68, 0.78 if not soon else 0.42), false)
	col.add_child(title)
	var purpose := Label.new()
	purpose.name = "SkillPurpose"
	purpose.text = str(node["pain"])
	purpose.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purpose.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	purpose.custom_minimum_size.x = 0
	ui.apply_font(purpose, 12, FarmPalette.TEXT_DIM)
	purpose.add_theme_constant_override("line_spacing", -4)
	col.add_child(purpose)

	var cmap: Dictionary = node.get("cost_map", {})
	var price_text := FarmSkillData.cost_text(cmap) if not cmap.is_empty() else (str(node.get("cost", 0)) if int(node.get("cost", 0)) > 0 else "")
	if (not owned or can_buy) and not soon and price_text != "" and price_text != "0":
		var cost := Label.new()
		cost.text = price_text.replace(" + ", "\n")
		cost.name = "CostLabel"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.max_lines_visible = 2
		cost.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cost.tooltip_text = price_text
		ui.apply_font(cost, 12, FarmPalette.GOLD if can_buy else Color(0.70, 0.68, 0.62, 0.80), false)
		cost.add_theme_constant_override("line_spacing", -4)
		col.add_child(cost)

	var shortfall := Label.new()
	shortfall.name = "Shortfall"
	shortfall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shortfall.visible = false
	ui.apply_font(shortfall, 14, FarmPalette.DANGER)
	var feedback := Control.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(feedback)
	feedback.add_child(shortfall)
	shortfall.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shortfall.offset_top = -26
	shortfall.offset_bottom = -2

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_skill_node_clicked(id, card)
			card.accept_event()
	)
	if not soon:
		card.mouse_entered.connect(func() -> void: style.bg_color = bg.lightened(0.10))
		card.mouse_exited.connect(func() -> void: style.bg_color = bg)
	card.set_meta("skill_id", id)
	card.set_meta("can_buy", can_buy)
	card.set_meta("base_border", style.border_color)
	if can_buy:
		_skill_glow_nodes.append(card)
	return card


func _on_skill_node_clicked(id: String, card: Control = null) -> void:
	var nodes := _skill_nodes()
	var node: Dictionary = {}
	for n in nodes:
		if str(n["id"]) == id:
			node = n
			break
	if node.is_empty() or node.get("soon", false):
		return
	if id == "harvest" or (node["owned"] and not host.can_unlock(id)):
		_open_skill_detail(id)
		return
	if host.can_unlock(id):
		var code: int = int(host.try_unlock(id))
		if code == 0:
			_queue_save()
			hint_skill_id = id
			_update_hay()
			_apply_hint_text()
			_maybe_unlock_hint(false)
			_selected_skill_id = ""
			if card:
				var shown_scroll_id := skill_scroll.get_instance_id()
				card.pivot_offset = card.size * 0.5
				_play_unlock_flourish(card)
				var tw := create_tween()
				tw.tween_interval(0.26)
				tw.tween_callback(func() -> void:
					# A late unlock flourish must not rebuild a NEW tree after
					# close/reopen and reset the player's current scroll.
					if _open_panel == "skill" and is_instance_valid(skill_scroll) and skill_scroll.get_instance_id() == shown_scroll_id:
						_fill_panel("skill")
				)
			elif _open_panel == "skill":
				_fill_panel("skill")
		return
	# Not enough hay or missing prerequisite: shake, show shortfall if it's hay.
	_open_skill_detail(id)
	if card:
		_shake_skill_card(card)
		if host.prerequisite_met(id):
			var need: int = int(host.hay_shortfall(id))
			var badge: Label = card.find_child("Shortfall", true, false)
			if badge:
				badge.text = "差 %d" % need
				badge.visible = true
				var cost: Label = card.find_child("CostLabel", true, false)
				if cost:
					cost.visible = false
				var tw := card.create_tween()
				tw.tween_interval(0.9)
				tw.tween_callback(func() -> void:
					if is_instance_valid(badge):
						badge.visible = false
					if is_instance_valid(cost):
						cost.visible = true
				)


func _shake_skill_card(card: Control) -> void:
	_sfx("deny")
	FarmMotion.stop(card, "_fm_shake")
	var origin: Vector2 = card.get_meta("_fm_shake_origin", card.position)
	card.set_meta("_fm_shake_origin", origin)
	var tw := card.create_tween()
	card.set_meta("_fm_shake", tw)
	tw.tween_property(card, "position:x", origin.x - 5, 0.04)
	tw.tween_property(card, "position:x", origin.x + 5, 0.05)
	tw.tween_property(card, "position:x", origin.x - 3, 0.04)
	tw.tween_property(card, "position:x", origin.x, 0.05)


func _play_unlock_flourish(card: Control) -> void:
	_sfx("unlock")
	if card == null:
		return
	FarmMotion.stop(card, "_fm_feedback")
	var tw := card.create_tween()
	card.set_meta("_fm_feedback", tw)
	tw.tween_property(card, "scale:x", 0.08, 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(card, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_skill_detail() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SkillDetail"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -210
	panel.offset_bottom = 210
	panel.add_theme_stylebox_override("panel", ui.flat(FarmPalette.SAGE_DEEP, 16, Vector4(18, 16, 18, 16), 12))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.name = "DetailTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.apply_font(title, 22, FarmPalette.GOLD_SOFT, true)
	head.add_child(title)
	var close := ui.make_icon_button(FarmIcon.Kind.CLOSE, "关闭", false, Vector2(44, 44))
	close.pressed.connect(func() -> void:
		_close_skill_detail()
	)
	head.add_child(close)
	var knowledge := Label.new()
	knowledge.name = "DetailKnowledge"
	knowledge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.apply_font(knowledge, 19, FarmPalette.TEXT)
	v.add_child(knowledge)
	var ex_title := Label.new()
	ex_title.name = "DetailExemplarTitle"
	ex_title.text = "范本"
	ui.apply_font(ex_title, 18, FarmPalette.GOLD_SOFT, true)
	v.add_child(ex_title)
	var code := CodeEdit.new()
	code.name = "DetailCode"
	code.editable = false
	code.gutters_draw_line_numbers = false
	code.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	code.custom_minimum_size = Vector2(0, 168)
	code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if ui.font_mono:
		code.add_theme_font_override("font", ui.font_mono)
	code.add_theme_font_size_override("font_size", 16)
	code.add_theme_color_override("font_color", FarmPalette.SYN_IDENT)
	code.add_theme_color_override("font_readonly_color", FarmPalette.SYN_IDENT)
	var ed := ui.flat(Color(0.10, 0.12, 0.11, 1), 10, Vector4(10, 8, 10, 8))
	code.add_theme_stylebox_override("normal", ed)
	code.add_theme_stylebox_override("read_only", ed)
	code.add_theme_stylebox_override("focus", ed)
	v.add_child(code)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	var copy_btn := ui.make_button("复制", false, 88)
	copy_btn.name = "CopyTemplate"
	copy_btn.tooltip_text = "复制完整主程序到剪贴板"
	copy_btn.pressed.connect(_copy_selected_skill_template)
	actions.add_child(copy_btn)
	var insert_btn := ui.make_button("载入", false, 88)
	insert_btn.name = "InsertTemplate"
	insert_btn.tooltip_text = "替换 main.cpp，并载入配套头文件"
	insert_btn.pressed.connect(_insert_selected_skill_template)
	actions.add_child(insert_btn)
	var copied := Label.new()
	copied.name = "CopiedHint"
	copied.text = "已复制"
	copied.visible = false
	ui.apply_font(copied, 17, FarmPalette.GOLD_SOFT)
	actions.add_child(copied)
	return panel


func _mark_skill_selection(id: String) -> void:
	if not is_instance_valid(skill_scroll):
		return
	for card in skill_scroll.find_children("Skill_*", "PanelContainer", true, false):
		if card.has_meta("skill_id"):
			var style: StyleBoxFlat = card.get_theme_stylebox("panel")
			style.border_color = FarmPalette.GOLD_SOFT if str(card.get_meta("skill_id")) == id else card.get_meta("base_border")


func _open_skill_detail(id: String) -> void:
	_selected_skill_id = id
	_mark_skill_selection(id)
	if is_instance_valid(skill_scroll):
		skill_scroll.call("_cancel_drag")
	if skill_detail == null:
		return
	var title: Label = skill_detail.find_child("DetailTitle", true, false)
	var knowledge: Label = skill_detail.find_child("DetailKnowledge", true, false)
	var code: CodeEdit = skill_detail.find_child("DetailCode", true, false)
	var name := id
	for n in _skill_nodes():
		if str(n["id"]) == id:
			name = str(n["name"])
			break
	if title:
		title.text = name
	var owned := _skill_owned(id)
	if knowledge:
		var lines: PackedStringArray = []
		if FarmSkillData.pain(id) != "":
			lines.append(FarmSkillData.pain(id))
		if _skill_knowledge(id) != "":
			lines.append(_skill_knowledge(id))
		lines = [FarmSkillData.pain(id), FarmSkillData.remedy(id), "下一行：" + FarmSkillData.next_line(id)]
		if id in ["speed", "iff"]:
			lines = [FarmSkillData.pain(id), "在 while 里加：if (can_harvest()) harvest();"]
		if not owned:
			lines.append("前置：" + FarmSkillData.prerequisite_text(id))
		knowledge.text = "\n".join(lines)
	var ex_title: Label = skill_detail.find_child("DetailExemplarTitle", true, false)
	if ex_title:
		ex_title.text = "完整范本 · 载入替换主程序" if owned else "范本：解锁后显示"
	if code:
		# The exemplar is shown only once the skill is owned.
		code.text = _skill_template(id) if owned else ""
		code.visible = owned
		if editor_assist.highlighter:
			code.syntax_highlighter = editor_assist.highlighter.duplicate()
	for btn_name in ["CopyTemplate", "InsertTemplate"]:
		var btn: Control = skill_detail.find_child(btn_name, true, false)
		if btn:
			btn.visible = owned
	FarmMotion.open_popup(skill_detail)


func _close_skill_detail() -> void:
	_selected_skill_id = ""
	_mark_skill_selection("")
	if skill_detail:
		FarmMotion.close_popup(skill_detail)


func _copy_selected_skill_template() -> void:
	if not _skill_owned(_selected_skill_id):
		return
	var text := _skill_template(_selected_skill_id)
	if text.is_empty():
		return
	last_copied_template = text
	DisplayServer.clipboard_set(text)
	if skill_detail:
		var hint: Label = skill_detail.find_child("CopiedHint", true, false)
		_flash_copied(hint)


func _load_hint_exemplar() -> void:
	_load_exemplar(_hint_skill())


func _insert_selected_skill_template() -> void:
	_load_exemplar(_selected_skill_id)


func _load_exemplar(id: String) -> void:
	if editor == null:
		return
	if not _skill_owned(id):
		return
	var text := _skill_template(id)
	if text.is_empty():
		return
	# An exemplar is a whole C++ program, never a snippet to put inside main.
	_on_stop()
	if _active_file != "main.cpp":
		_switch_user_file("main.cpp")
	editor.text = text
	_user_files["main.cpp"] = text
	var headers := FarmSkillData.exemplar_headers(id)
	for name in headers:
		_user_files[str(name)] = str(headers[name])
	_rebuild_file_bar()
	_push_includes_to_host()


func click_skill_node(id: String) -> void:
	var card: Control = null
	if overlay_body:
		card = overlay_body.find_child("Skill_" + id, true, false)
	_on_skill_node_clicked(id, card)


func buy_skill(id: String) -> int:

	var code: int = int(host.try_unlock(id))
	if code == 0:
		_queue_save()
		hint_skill_id = id
		_apply_hint_text()
	_update_hay()
	if _open_panel == "skill":
		_fill_panel("skill")
	return code


func open_skill_detail(id: String) -> void:
	_open_skill_detail(id)


## Public camera actions (buttons, F key, tests).
func reset_camera(instant: bool = false) -> void:
	camera_rig.reset(instant)


func clear_camera_drag() -> void:
	if camera_rig:
		camera_rig.clear_drag()


# --- UI hit testing (shared by the camera rig and click handling) ---

func _text_input_has_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() else null
	if focus == null:
		return false
	return focus is TextEdit or focus is LineEdit or focus is CodeEdit or focus is SpinBox


func _mouse_over_editor() -> bool:
	if editor == null or not editor.is_visible_in_tree():
		return false
	return editor.get_global_rect().has_point(editor.get_global_mouse_position())


func _is_under_ui_root(node: Node) -> bool:
	var n := node
	while n:
		if n == ui_root:
			return true
		n = n.get_parent()
	return false


func _point_over_ui(pos: Vector2) -> bool:
	if _open_panel != "" and backdrop and backdrop.visible:
		return true
	for w in [code_window, hint_window]:
		if w and w.visible and w.get_global_rect().has_point(pos):
			return true
	if skill_detail and skill_detail.visible and skill_detail.get_global_rect().has_point(pos):
		return true
	if ui_root:
		var top := ui_root.get_node_or_null("TopBar")
		if top and top is Control and (top as Control).visible and (top as Control).get_global_rect().has_point(pos):
			return true
	if get_viewport():
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered and hovered != ui_root and _is_under_ui_root(hovered) and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false


## A harvest landed: sound, flattened crop on the tile, and the bot's swing.
func _on_harvested() -> void:
	_sfx("harvest")
	var key := Vector2i(host.get_drone_x(), host.get_drone_y())
	field.flatten_after_harvest(key)
	bot.play_harvest_success(key, host.last_harvested() == "Bush")


func _soften_lights() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_energy = 0.88
		sun.light_color = Color(1.0, 0.93, 0.82, 1)
		sun.shadow_opacity = 0.56
		sun.shadow_blur = 2.4
		sun.light_angular_distance = 2.5
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env: Environment = env_node.environment
		env.ambient_light_energy = 0.34
		env.ambient_light_color = Color(0.90, 0.84, 0.74, 1)
	if get_node_or_null("FillLight") == null:
		var fill := DirectionalLight3D.new()
		fill.name = "FillLight"
		fill.light_energy = 0.22
		fill.light_color = Color(0.80, 0.86, 0.88, 1)
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-25, 130, 0)
		add_child(fill)


func _flush_active_file() -> void:
	if editor == null:
		return
	_user_files[_active_file] = editor.text
	if _active_file != "main.cpp" and not _user_files.has("main.cpp"):
		_user_files["main.cpp"] = STARTER


func _push_includes_to_host() -> void:
	if host == null or not host.has_method("set_include"):
		return
	if not host.is_unlocked("include"):
		return
	_flush_active_file()
	for name in _user_files.keys():
		if str(name) == "main.cpp":
			continue
		host.set_include(str(name), str(_user_files[name]))


func _refresh_file_bar_visibility() -> void:
	var show := host != null and host.is_unlocked("include")
	if _file_bar_wrap:
		_file_bar_wrap.visible = show
	if show and _file_bar and _file_bar.get_child_count() == 0:
		if not _user_files.has("main.cpp") and editor:
			_user_files["main.cpp"] = editor.text
		_rebuild_file_bar()


func _rebuild_file_bar() -> void:
	if _file_bar == null:
		return
	for child in _file_bar.get_children():
		_file_bar.remove_child(child)
		child.queue_free()
	var names: Array = ["main.cpp"]
	for k in _user_files.keys():
		if str(k) != "main.cpp" and str(k) not in names:
			names.append(str(k))
	for name in names:
		var btn := Button.new()
		btn.text = str(name)
		btn.flat = true
		btn.set_meta("file_name", str(name))
		btn.custom_minimum_size = Vector2(72, 28)
		ui.apply_font(btn, 15, FarmPalette.GOLD_SOFT if _active_file == str(name) else FarmPalette.TEXT_DIM, true)
		var chosen := str(name)
		btn.pressed.connect(func() -> void:
			_switch_user_file(chosen)
		)
		_file_bar.add_child(btn)
		FarmMotion.bind_hover(btn, 1.02, 0.97)
	var add := Button.new()
	add.text = "+"
	add.tooltip_text = "新建文件"
	add.custom_minimum_size = Vector2(32, 28)
	ui.apply_font(add, 18, FarmPalette.GOLD_SOFT, true)
	add.pressed.connect(_new_user_file)
	_file_bar.add_child(add)


func _switch_user_file(name: String) -> void:
	_flush_active_file()
	_active_file = name
	if editor:
		editor.protect_framework = name == "main.cpp"
	if not _user_files.has(name):
		_user_files[name] = ""
	if editor:
		editor.text = str(_user_files[name])
	if _file_bar:
		for button in _file_bar.get_children():
			if button is Button and button.has_meta("file_name"):
				var is_active: bool = str(button.get_meta("file_name")) == name
				button.add_theme_color_override("font_color", FarmPalette.GOLD_SOFT if is_active else FarmPalette.TEXT_DIM)
	if editor:
		FarmMotion.stop(editor, "_file_fade")
		editor.modulate.a = 0.65
		var fade := editor.create_tween()
		editor.set_meta("_file_fade", fade)
		fade.tween_property(editor, "modulate:a", 1.0, 0.18)


func _new_user_file() -> void:
	var n := 1
	var name := "rows.hpp"
	while _user_files.has(name):
		n += 1
		name = "rows_%d.hpp" % n
	_user_files[name] = "void harvest_row() {\n    for (int i = 0; i < get_world_size(); i++) {\n        if (can_harvest()) harvest();\n        move(East);\n    }\n}\n"
	_switch_user_file(name)
	_rebuild_file_bar()


func scroll_skills_toward(id: String) -> void:
	if skill_scroll == null:
		return
	for node in FarmSkillData.nodes(host):
		if str(node["id"]) == id:
			var pos: Vector2 = node["pos"] * float(skill_scroll.get("zoom"))
			skill_scroll.scroll_vertical = int(max(0.0, pos.y - 280.0))
			skill_scroll.scroll_horizontal = int(max(0.0, pos.x - 420.0))
			return

