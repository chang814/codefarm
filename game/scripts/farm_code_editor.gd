extends CodeEdit
## Protect the supplied main.cpp shell, while keeping helpers and headers editable.
signal framework_blocked
var protect_framework := true
var _accepted := ""
var _restoring := false

func _ready() -> void:
	text_set.connect(_snapshot)
	text_changed.connect(_validate_edit)
	_snapshot()

func _snapshot() -> void:
	if not _restoring:
		_accepted = text
	call_deferred("_paint_framework")

func _ranges(source: String) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	if not protect_framework:
		return ranges
	for fixed in ["#include <bits/stdc++.h>", "using namespace std;", "int main() {"]:
		var offset := source.find(fixed)
		if offset >= 0:
			var end: int = offset + str(fixed).length()
			if source.substr(end, 1) == "\n": end += 1
			ranges.append(Vector2i(offset, end))
	# The teaching programs place main last. Find its matching brace lexically,
	# ignoring braces inside comments and string literals.
	var main_at := source.find("int main")
	if main_at >= 0:
		var open := source.find("{", main_at)
		var depth := 0
		var quote := ""
		var line_comment := false
		var block_comment := false
		var escaped := false
		var i := open
		while i >= 0 and i < source.length():
			var ch := source.substr(i, 1)
			var pair := source.substr(i, 2)
			if line_comment:
				if ch == "\n": line_comment = false
			elif block_comment:
				if pair == "*/":
					block_comment = false
					i += 1
			elif quote != "":
				if escaped: escaped = false
				elif ch == "\\": escaped = true
				elif ch == quote: quote = ""
			elif pair == "//": line_comment = true
			elif pair == "/*": block_comment = true
			elif ch == "\"" or ch == "'": quote = ch
			elif ch == "{": depth += 1
			elif ch == "}":
				depth -= 1
				if depth == 0:
					ranges.append(Vector2i(i, i + 1))
					var ret := source.substr(open, i - open).rfind("return 0;")
					if ret >= 0: ranges.append(Vector2i(open + ret, open + ret + 9))
					break
			i += 1
	return ranges

func _validate_edit() -> void:
	if _restoring:
		return
	var now := text
	# A text diff is ambiguous when the typed characters repeat their
	# neighbours: pressing Enter at the end of the last body line inserts
	# a newline plus indent, which also matches the indent in front of `return 0;`. Read the
	# edit both ways (longest prefix first, longest suffix first) and block it
	# only when neither reading leaves the framework alone.
	var begin := 0
	while begin < mini(now.length(), _accepted.length()) and now[begin] == _accepted[begin]:
		begin += 1
	var old_end := _accepted.length()
	var new_end := now.length()
	while old_end > begin and new_end > begin and _accepted[old_end - 1] == now[new_end - 1]:
		old_end -= 1
		new_end -= 1
	var tail_old := _accepted.length()
	var tail_new := now.length()
	while tail_old > 0 and tail_new > 0 and _accepted[tail_old - 1] == now[tail_new - 1]:
		tail_old -= 1
		tail_new -= 1
	var tail_begin := 0
	while tail_begin < mini(tail_old, tail_new) and now[tail_begin] == _accepted[tail_begin]:
		tail_begin += 1
	var spans := _ranges(_accepted)
	if _touches(spans, begin, old_end) and _touches(spans, tail_begin, tail_old):
		var line := get_caret_line()
		var column := get_caret_column()
		_restoring = true
		if has_undo(): undo()
		if text != _accepted: text = _accepted
		set_caret_line(mini(line, get_line_count() - 1))
		set_caret_column(mini(column, get_line(get_caret_line()).length()))
		_restoring = false
		framework_blocked.emit()
		call_deferred("_paint_framework")
		return
	_accepted = now
	call_deferred("_paint_framework")

func _touches(spans: Array[Vector2i], begin: int, old_end: int) -> bool:
	for span in spans:
		# Replacing or deleting protected characters, or typing strictly inside
		# them. Typing right in front of a protected piece leaves it intact.
		if begin < span.y and old_end > span.x:
			return true
		if begin == old_end and begin > span.x and begin < span.y:
			return true
	return false

func _paint_framework() -> void:
	for i in get_line_count():
		set_line_background_color(i, Color.TRANSPARENT)
	for span in _ranges(text):
		var line := text.substr(0, span.x).count("\n")
		set_line_background_color(line, Color(0.52, 0.65, 0.67, 0.065))
