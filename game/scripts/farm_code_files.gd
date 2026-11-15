extends Node
## The player's code files: main.cpp plus any headers they add once the
## 分文件 (include) skill is owned. Owns the file bar above the editor, keeps
## the editor text and the stored files in sync, and hands headers to the
## simulator so `#include "name.hpp"` resolves.

const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")
const FarmUiKit := preload("res://scripts/farm_ui_kit.gd")

const MAIN_FILE := "main.cpp"
const NEW_FILE_TEMPLATE := "void harvest_row() {\n    for (int i = 0; i < get_world_size(); i++) {\n        if (can_harvest()) harvest();\n        move(East);\n    }\n}\n"

var editor: CodeEdit
var host: CodefarmHost
var ui: FarmUiKit
## File name -> source text. The editor holds the active file's live text.
var user_files: Dictionary = {}
var active_file := MAIN_FILE
## Row of file buttons, and the wrapper that is shown only with the include skill.
var file_bar: HBoxContainer
var file_bar_wrap: Control

var _starter := ""


func setup(code_edit: CodeEdit, sim_host: CodefarmHost, ui_kit: FarmUiKit, starter: String) -> void:
	editor = code_edit
	host = sim_host
	ui = ui_kit
	_starter = starter


## Restore files from a save and open the file that was active.
func restore(files: Dictionary, active: String) -> void:
	user_files = files.duplicate()
	active_file = active
	editor.protect_framework = active_file == MAIN_FILE
	editor.text = user_files[active_file]


## Back to a single starter main.cpp (farm reset).
func reset_to_starter() -> void:
	user_files = {MAIN_FILE: _starter}
	active_file = MAIN_FILE
	editor.protect_framework = true
	editor.text = _starter
	rebuild_bar()


## Replace main.cpp with a whole program (an exemplar) plus its headers.
func load_program(text: String, headers: Dictionary) -> void:
	if active_file != MAIN_FILE:
		switch_to(MAIN_FILE)
	editor.text = text
	user_files[MAIN_FILE] = text
	for name in headers:
		user_files[str(name)] = str(headers[name])
	rebuild_bar()
	push_includes_to_host()


## Copy the editor text into the active file's slot.
func flush_active() -> void:
	if editor == null:
		return
	user_files[active_file] = editor.text
	if active_file != MAIN_FILE and not user_files.has(MAIN_FILE):
		user_files[MAIN_FILE] = _starter


## The source the program runs from, whichever file is open.
func main_source() -> String:
	flush_active()
	return str(user_files.get(MAIN_FILE, editor.text if editor else ""))


## Send every header to the simulator (only once includes are unlocked).
func push_includes_to_host() -> void:
	if host == null or not host.has_method("set_include"):
		return
	if not host.is_unlocked("include"):
		return
	flush_active()
	for name in user_files.keys():
		if str(name) == MAIN_FILE:
			continue
		host.set_include(str(name), str(user_files[name]))


func refresh_bar_visibility() -> void:
	var show := host != null and host.is_unlocked("include")
	if file_bar_wrap:
		file_bar_wrap.visible = show
	if show and file_bar and file_bar.get_child_count() == 0:
		if not user_files.has(MAIN_FILE) and editor:
			user_files[MAIN_FILE] = editor.text
		rebuild_bar()


func rebuild_bar() -> void:
	if file_bar == null:
		return
	for child in file_bar.get_children():
		file_bar.remove_child(child)
		child.queue_free()
	var names: Array = [MAIN_FILE]
	for k in user_files.keys():
		if str(k) != MAIN_FILE and str(k) not in names:
			names.append(str(k))
	for name in names:
		var btn := Button.new()
		btn.text = str(name)
		btn.flat = true
		btn.set_meta("file_name", str(name))
		btn.custom_minimum_size = Vector2(72, 28)
		ui.apply_font(btn, 15, FarmPalette.GOLD_SOFT if active_file == str(name) else FarmPalette.TEXT_DIM, true)
		var chosen := str(name)
		btn.pressed.connect(func() -> void:
			switch_to(chosen)
		)
		file_bar.add_child(btn)
		FarmMotion.bind_hover(btn, 1.02, 0.97)
	var add := Button.new()
	add.text = "+"
	add.tooltip_text = "新建文件"
	add.custom_minimum_size = Vector2(32, 28)
	ui.apply_font(add, 18, FarmPalette.GOLD_SOFT, true)
	add.pressed.connect(new_file)
	file_bar.add_child(add)


## Open `name` in the editor (creating it empty if needed). Only main.cpp
## keeps the protected #include / int main() frame.
func switch_to(name: String) -> void:
	flush_active()
	active_file = name
	if editor:
		editor.protect_framework = name == MAIN_FILE
	if not user_files.has(name):
		user_files[name] = ""
	if editor:
		editor.text = str(user_files[name])
	if file_bar:
		for button in file_bar.get_children():
			if button is Button and button.has_meta("file_name"):
				var is_active: bool = str(button.get_meta("file_name")) == name
				button.add_theme_color_override("font_color", FarmPalette.GOLD_SOFT if is_active else FarmPalette.TEXT_DIM)
	if editor:
		FarmMotion.stop(editor, "_file_fade")
		editor.modulate.a = 0.65
		var fade := editor.create_tween()
		editor.set_meta("_file_fade", fade)
		fade.tween_property(editor, "modulate:a", 1.0, 0.18)


## Add a header with a small starter function and open it.
func new_file() -> void:
	var n := 1
	var name := "rows.hpp"
	while user_files.has(name):
		n += 1
		name = "rows_%d.hpp" % n
	user_files[name] = NEW_FILE_TEMPLATE
	switch_to(name)
	rebuild_bar()
