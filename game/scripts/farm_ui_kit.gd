extends RefCounted
## Fonts, the shared Theme, and small factories for the warm sage UI: flat
## style boxes, text and icon buttons, and resource chips. Every panel builds
## its controls through one kit so sizes, colors and fonts stay consistent.

const FarmIcon := preload("res://scripts/farm_icons.gd")
const FarmMotion := preload("res://scripts/farm_motion.gd")
const FarmPalette := preload("res://scripts/farm_palette.gd")

var font_ui: Font
var font_ui_bold: Font
var font_mono: Font
var theme: Theme


func _load_font_file(path: String) -> FontFile:
	# Exported font paths resolve to imported .fontdata, not raw source bytes.
	var font: FontFile
	if ResourceLoader.exists(path):
		font = ResourceLoader.load(path) as FontFile
		if font:
			font = font.duplicate()
	if font == null:
		font = FontFile.new()
		if font.load_dynamic_font(path) != OK:
			return null
	font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	font.hinting = TextServer.HINTING_LIGHT
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


func _ui_font_with_fallback(base: Font, fallbacks: Array) -> Font:
	if base == null:
		return null
	var extras: Array = []
	for item in fallbacks:
		if item and item != base:
			extras.append(item)
	if extras.is_empty():
		return base
	var variation := FontVariation.new()
	variation.base_font = base
	variation.fallbacks = extras
	return variation


func _soften_ui_font(base: Font, embolden: float = 0.0) -> Font:
	if base == null:
		return null
	var v := FontVariation.new()
	if base is FontVariation:
		var src := base as FontVariation
		v.base_font = src.base_font
		v.fallbacks = src.fallbacks
	else:
		v.base_font = base
	v.spacing_glyph = 1
	v.spacing_space = 1
	v.spacing_top = 1
	v.spacing_bottom = 2
	if embolden != 0.0:
		v.variation_embolden = embolden
	return v


## Load the UI (Noto Sans CJK SC, Droid fallback) and code (JetBrains Mono) fonts.
func load_fonts() -> void:
	var droid := _load_font_file("res://fonts/DroidSansFallback.ttf")
	var noto := _load_font_file("res://fonts/NotoSansCJKsc-Regular.otf")
	var noto_bold := _load_font_file("res://fonts/NotoSansCJKsc-Bold.otf")
	var cjk: Font = noto if noto else droid
	var cjk_bold: Font = noto_bold if noto_bold else cjk
	var mono := _load_font_file("res://fonts/JetBrainsMono-Regular.ttf")
	if mono == null:
		mono = _load_font_file("res://fonts/NotoSansMono.ttf")
	if mono and cjk:
		var code_font := FontVariation.new()
		code_font.base_font = mono
		code_font.fallbacks = [cjk]
		font_mono = code_font
	elif mono:
		font_mono = mono
	font_ui = _soften_ui_font(_ui_font_with_fallback(cjk, [droid]), 0.0)
	# Slight embolden on regular, not the heavy Bold cut — softer weight for titles.
	font_ui_bold = _soften_ui_font(_ui_font_with_fallback(cjk, [cjk_bold, droid]), 0.32)


## The shared Theme for every window, button, tooltip, popup and editor.
func build_theme() -> Theme:
	theme = Theme.new()
	if font_ui:
		theme.default_font = font_ui
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", FarmPalette.TEXT)
	theme.set_color("font_color", "Button", FarmPalette.CREAM)
	theme.set_color("font_hover_color", "Button", FarmPalette.CREAM)
	theme.set_color("font_pressed_color", "Button", FarmPalette.CREAM)
	theme.set_color("font_disabled_color", "Button", FarmPalette.TEXT_DIM)
	theme.set_color("font_color", "TooltipLabel", FarmPalette.CREAM)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_font_size("font_size", "Label", 20)
	theme.set_color("font_color", "PopupMenu", FarmPalette.CREAM)
	theme.set_color("font_hover_color", "PopupMenu", FarmPalette.CREAM)
	theme.set_color("font_accelerator_color", "PopupMenu", FarmPalette.TEXT_DIM)
	theme.set_color("font_color", "ItemList", FarmPalette.CREAM)
	theme.set_color("font_hovered_color", "ItemList", FarmPalette.CREAM)
	theme.set_color("font_selected_color", "ItemList", FarmPalette.CREAM)
	if font_mono:
		theme.set_font("font", "CodeEdit", font_mono)
		theme.set_font("font", "TextEdit", font_mono)
		theme.set_font("font", "LineEdit", font_ui if font_ui else font_mono)
	if font_ui:
		for typ in ["Label", "Button", "TooltipLabel", "PopupMenu", "ItemList", "CheckBox", "RichTextLabel", "OptionButton"]:
			theme.set_font("font", typ, font_ui)
	var panel := flat(FarmPalette.SAGE_BG, 16, Vector4(16, 12, 16, 12), 10)
	var deep := flat(FarmPalette.SAGE_DEEP, 16, Vector4(16, 12, 16, 12), 12)
	var tip := flat(FarmPalette.SAGE_DEEP, 10, Vector4(12, 8, 12, 8), 8)
	var popup := flat(Color(0.14, 0.17, 0.15, 0.98), 10, Vector4(8, 6, 8, 6), 8)
	popup.border_color = Color(0.78, 0.62, 0.38, 0.35)
	popup.set_border_width_all(1)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupPanel", popup)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", flat(Color(0.78, 0.64, 0.42, 0.30), 6, Vector4(8, 4, 8, 4)))
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_stylebox("tooltip", "PopupMenu", tip)
	theme.set_stylebox("normal", "Button", flat(Color(0.30, 0.36, 0.32, 0.95), 9, Vector4(14, 6, 14, 6)))
	theme.set_stylebox("hover", "Button", flat(Color(0.36, 0.42, 0.37, 1), 9, Vector4(14, 6, 14, 6)))
	theme.set_stylebox("pressed", "Button", flat(Color(0.42, 0.38, 0.26, 1), 9, Vector4(14, 6, 14, 6)))
	theme.set_stylebox("disabled", "Button", flat(Color(0.24, 0.27, 0.25, 0.7), 9, Vector4(14, 6, 14, 6)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var scroll := flat(Color(0.22, 0.26, 0.23, 0.95), 6, Vector4(0, 0, 0, 0))
	scroll.set_corner_radius_all(6)
	var grab := flat(Color(0.70, 0.56, 0.32, 0.85), 6, Vector4(0, 0, 0, 0))
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, scroll)
		theme.set_stylebox("grabber", bar, grab)
		theme.set_stylebox("grabber_highlight", bar, flat(FarmPalette.GOLD_SOFT, 6, Vector4(0, 0, 0, 0)))
		theme.set_stylebox("grabber_pressed", bar, flat(FarmPalette.GOLD, 6, Vector4(0, 0, 0, 0)))
		theme.set_stylebox("scroll_focus", bar, scroll)
	var ed := flat(Color(0.10, 0.12, 0.11, 1), 10, Vector4(10, 8, 10, 8))
	theme.set_stylebox("normal", "CodeEdit", ed)
	theme.set_stylebox("focus", "CodeEdit", ed)
	theme.set_stylebox("read_only", "CodeEdit", ed)
	theme.set_stylebox("completion", "CodeEdit", popup)
	theme.set_color("background_color", "CodeEdit", Color(0.09, 0.11, 0.10, 1))
	return theme


static func flat(color: Color, radius: int = 12, pad := Vector4(16, 12, 16, 12), shadow: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	if shadow > 0:
		sb.shadow_color = Color(0, 0, 0, 0.16)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 2)
	return sb


func apply_font(node: Control, size: int = 20, color: Color = FarmPalette.TEXT, bold: bool = false) -> void:
	var font: Font = font_ui_bold if bold and font_ui_bold else font_ui
	if font:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	if node is Label:
		node.add_theme_constant_override("line_spacing", 8)
	if node is RichTextLabel:
		node.add_theme_constant_override("line_separation", 8)
	if node is Label or node is Button or node is RichTextLabel:
		node.add_theme_color_override("font_color", color)


func make_button(text: String, gold := false, min_w := 76) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, 44)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := flat(Color(0.30, 0.36, 0.32, 0.95) if not gold else Color(0.70, 0.50, 0.28, 1), 9, Vector4(14, 6, 14, 6))
	var hover := flat(Color(0.36, 0.42, 0.37, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(14, 6, 14, 6))
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", flat(Color(0.24, 0.27, 0.25, 0.7), 9, Vector4(14, 6, 14, 6)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	apply_font(btn, 20, FarmPalette.CREAM)
	FarmMotion.bind_hover.call_deferred(btn)
	return btn


func make_icon_button(kind: FarmIcon.Kind, tip: String, gold := false, min_size := Vector2(52, 52)) -> Button:
	var btn := make_button("", gold, int(min_size.x))
	btn.text = ""
	btn.tooltip_text = tip
	var edge := maxf(min_size.x, min_size.y)
	btn.custom_minimum_size = Vector2(edge, edge)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_stylebox_override("normal", flat(Color(0.30, 0.36, 0.32, 0.95) if not gold else Color(0.70, 0.50, 0.28, 1), 9, Vector4(6, 4, 6, 4)))
	btn.add_theme_stylebox_override("hover", flat(Color(0.36, 0.42, 0.37, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(6, 4, 6, 4)))
	btn.add_theme_stylebox_override("pressed", flat(Color(0.42, 0.38, 0.26, 1) if not gold else Color(0.78, 0.58, 0.34, 1), 9, Vector4(6, 4, 6, 4)))
	var icon := FarmIcon.new()
	icon.kind = kind
	icon.icon_color = Color(0.88, 0.84, 0.76, 1) if not gold else Color(0.90, 0.84, 0.70, 1)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	btn.add_child(icon)
	btn.set_meta("farm_icon", icon)
	return btn


func resource_chip(kind: FarmIcon.Kind, name: String, tint: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := FarmIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(28, 28)
	icon.icon_color = tint if tint.a > 0.0 else FarmPalette.GOLD_SOFT
	row.add_child(icon)
	var label := Label.new()
	label.name = name
	label.text = "0"
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	apply_font(label, 22, FarmPalette.GOLD_SOFT, false)
	row.add_child(label)
	return {"row": row, "label": label, "icon": icon}
