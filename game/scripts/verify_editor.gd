extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	await create_timer(0.22).timeout
	await process_frame
func run() -> void:
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	main.persistence_enabled = false
	main.start_on_farm = true
	root.add_child(main)
	await settle()
	var edit = main.editor
	var original: String = edit.text
	# Test editing operations, not set_text (which is reserved for loading files).
	for needle in ["#include", "using namespace", "int main", "return 0;", "}"]:
		edit.text = original
		var offset: int = original.find(needle)
		var line: int = original.substr(0, offset).count("\n")
		var column: int = offset - original.rfind("\n", offset) - 1
		edit.select(line, column, line, column + 1)
		edit.delete_selection()
		await settle()
		check(edit.text == original, "protect " + needle)
	edit.text = original
	edit.select_all()
	edit.delete_selection()
	await settle()
	check(edit.text == original, "select all cannot erase shell")
	edit.deselect()
	edit.set_caret_line(4)
	edit.set_caret_column(4)
	edit.insert_text_at_caret("// 可以写中文注释\n    ")
	await settle()
	check(edit.text.contains("可以写中文注释"), "body remains editable")
	edit.undo()
	await settle()
	check(edit.text == original, "body undo works")
	# 0.2.10: everyday typing next to the protected lines must go through.
	edit.text = original
	edit.set_caret_line(4)
	edit.set_caret_column(edit.get_line(4).length())
	edit.insert_text_at_caret("\n    ")
	await settle()
	check(edit.get_line_count() == original.count("\n") + 2 and edit.get_line(5).strip_edges().is_empty(), "Enter after the last body line adds a line")
	edit.insert_text_at_caret("harvest();")
	await settle()
	check(edit.get_line(5) == "    harvest();" and edit.get_line(6) == "    return 0;", "typing on the new line keeps return in place")
	edit.text = original
	edit.set_caret_line(3)
	edit.set_caret_column(edit.get_line(3).length())
	edit.insert_text_at_caret("\n    ")
	await settle()
	check(edit.get_line(4).strip_edges().is_empty() and edit.get_line(5) == "    harvest();", "Enter after the main brace adds a line")
	edit.text = original
	edit.set_caret_line(4)
	edit.set_caret_column(4)
	edit.insert_text_at_caret("while (true) {\n        harvest();\n    }\n    ")
	await settle()
	check(edit.text.contains("while (true) {\n        harvest();\n    }\n    harvest();\n    return 0;\n}"), "a block with its own closing brace can be typed")
	edit.text = original
	edit.set_caret_line(5)
	edit.set_caret_column(6)
	edit.insert_text_at_caret("x")
	await settle()
	check(edit.text == original, "typing inside return 0; is still refused")
	# A diagnostic whose columns now lie past the end of a shortened line.
	main.error_markup.show_diagnostic(5, 30, 44, "测试", "", "typo")
	await settle()
	check(main.error_markup.call("_token_rect") is Rect2, "stale diagnostic columns are clamped")
	main.error_markup.clear()
	edit.text = original
	edit.set_caret_line(2)
	edit.set_caret_column(0)
	edit.insert_text_at_caret("void helper() {}\n")
	await settle()
	check(edit.text.contains("void helper"), "helper area remains editable")
	main.code_files.call("switch_to", "rows.hpp")
	edit.insert_text_at_caret("void tool() {}")
	await settle()
	check(edit.text.contains("void tool"), "header is fully editable")
	main.code_files.call("switch_to", "main.cpp")
	edit.text = original.replace("harvest();", "harvset();")
	main.call("_on_run")
	await settle()
	var markup = main.error_markup
	check(markup.is_showing(), "diagnostic displayed")
	check(markup.get("_message").contains("第 5 行"), "diagnostic location")
	check(markup.get("_message").contains("harvest"), "typo direction")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../shots/ui-024-error.png")
	edit.text = original.replace("harvest();", "while (true) { harvest(); }")
	main.call("_on_run")
	await settle()
	check(markup.get("_kind") == "locked_syntax", "locked diagnostic category")
	check(markup.get("_message").contains("技能树"), "locked diagnostic next step")
	markup.show_diagnostic(5, 5, 12, "需要检查 ; 和 [x]", "补上分号 ;", "missing_semicolon")
	check(markup.get("_label").text.contains("[x]"), "diagnostic preserves literal code")
	edit.text = original
	markup.clear()
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../shots/ui-024-editor.png")
	print("EDITOR_OK" if failures == 0 else "EDITOR_FAILED: " + str(failures))
	quit(0 if failures == 0 else 1)
