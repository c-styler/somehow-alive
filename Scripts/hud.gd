class_name HUD
extends CanvasLayer

@export var location: Label

const TASK_FONT := preload("res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Nunito/static/Nunito-Black.ttf")

# palette (same as the water minigame)
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC")
const DEEP := Color("0B3C5D")

var task_list: VBoxContainer
var day_label: Label
var task_rows := {} # task_id -> {box: TaskBox, label: Label}

var clock_box: VBoxContainer
var clock_title: Label
var clock_time: Label

func _ready() -> void:
	_build_task_panel()
	_build_clock()
	_build_controls()

# --- controls hint (center left) ---

## key cap text -> what it does
const CONTROLS := [
	["LMB", "Move / Interact"],
	["RMB", "Hold to walk faster"],
	["K", "Helmet light"],
]

func _build_controls() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DEEP, 0.75)
	style.border_color = Color(TEAL, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_override("font", TASK_FONT)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", TEAL)
	column.add_child(title)

	for entry in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)

		var cap := PanelContainer.new()
		var cap_style := StyleBoxFlat.new()
		cap_style.bg_color = CREAM
		cap_style.border_color = Color("9fb3c0")
		cap_style.border_width_bottom = 3 # little 3D key edge
		cap_style.set_corner_radius_all(5)
		cap_style.content_margin_left = 6
		cap_style.content_margin_right = 6
		cap_style.content_margin_top = 1
		cap_style.content_margin_bottom = 1
		cap.add_theme_stylebox_override("panel", cap_style)
		cap.custom_minimum_size = Vector2(44, 0)
		row.add_child(cap)

		var key := Label.new()
		key.text = entry[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_font_override("font", TASK_FONT)
		key.add_theme_font_size_override("font_size", 13)
		key.add_theme_color_override("font_color", DEEP)
		cap.add_child(key)

		var action := Label.new()
		action.text = entry[1]
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action.add_theme_font_override("font", TASK_FONT)
		action.add_theme_font_size_override("font_size", 14)
		action.add_theme_color_override("font_color", CREAM)
		row.add_child(action)

# --- big centered clock (task moments / game start) ---

func _build_clock() -> void:
	clock_box = VBoxContainer.new()
	clock_box.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_box)
	clock_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	clock_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clock_box.grow_vertical = Control.GROW_DIRECTION_BOTH

	clock_title = _clock_label(28, TEAL)
	clock_time = _clock_label(84, CREAM)
	var subtitle := _clock_label(20, TEAL)
	subtitle.text = "MARS TIME"
	clock_box.add_child(clock_title)
	clock_box.add_child(clock_time)
	clock_box.add_child(subtitle)
	clock_box.modulate.a = 0.0
	clock_box.visible = false

func _clock_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", TASK_FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", DEEP)
	l.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
	return l

func update_clock(title: String, time: String) -> void:
	clock_title.text = title
	clock_time.text = time

## Fades the clock in; await it to know when it's fully shown.
func show_clock(title: String, time: String) -> void:
	update_clock(title, time)
	clock_box.visible = true
	clock_box.scale = Vector2.ONE
	var t := create_tween()
	t.tween_property(clock_box, "modulate:a", 1.0, 0.4)
	await t.finished

func hide_clock() -> void:
	var t := create_tween()
	t.tween_property(clock_box, "modulate:a", 0.0, 0.6)
	await t.finished
	clock_box.visible = false

func set_location_text(text: String, color: Color) -> void:
	location.text = text
	location.modulate = color

func set_day(day: int) -> void:
	day_label.text = "DAY %d" % day

# --- task checklist (center right) ---

func _build_task_panel() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DEEP, 0.85)
	style.border_color = TEAL
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	# anchor to the right edge, vertically centered, growing leftward/both ways
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	day_label = Label.new()
	day_label.text = "DAY 1"
	day_label.add_theme_font_override("font", TASK_FONT)
	day_label.add_theme_font_size_override("font_size", 24)
	day_label.add_theme_color_override("font_color", CREAM)
	column.add_child(day_label)

	var title := Label.new()
	title.text = "TASKS"
	title.add_theme_font_override("font", TASK_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", TEAL)
	column.add_child(title)

	task_list = VBoxContainer.new()
	task_list.add_theme_constant_override("separation", 4)
	column.add_child(task_list)

func clear_tasks() -> void:
	for child in task_list.get_children():
		child.queue_free()
	task_rows.clear()

func add_task(task_id: StringName, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var box := TaskBox.new()
	row.add_child(box)

	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", TASK_FONT)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", CREAM)
	row.add_child(label)

	task_list.add_child(row)
	task_rows[task_id] = {box = box, label = label}

func set_task_done(task_id: StringName) -> void:
	if not task_rows.has(task_id):
		return
	var row: Dictionary = task_rows[task_id]
	var box: TaskBox = row.box
	var label: Label = row.label
	var t := create_tween()
	# draw the check stroke in, with a little bounce on the box
	t.tween_property(box, "check", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(box, "scale", Vector2(1.35, 1.35), 0.12)
	t.tween_property(box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# then fade the text back so open tasks stand out
	t.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0.5), 0.4)


## Rounded checkbox that draws its own checkmark; `check` animates 0..1.
class TaskBox extends Control:
	const SIZE := 18.0
	var check := 0.0:
		set(v):
			check = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pivot_offset = Vector2(SIZE, SIZE) / 2

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
		var bg := StyleBoxFlat.new()
		bg.bg_color = TEAL if check > 0.0 else Color(0, 0, 0, 0.25)
		bg.border_color = CREAM
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(4)
		draw_style_box(bg, r)
		if check <= 0.0:
			return
		# checkmark: short stroke down-right, then long stroke up-right; drawn progressively
		var a := Vector2(4, 9.5)
		var b := Vector2(7.5, 13)
		var c := Vector2(14, 5)
		var first := clampf(check / 0.4, 0.0, 1.0)
		var second := clampf((check - 0.4) / 0.6, 0.0, 1.0)
		draw_line(a, a.lerp(b, first), CREAM, 2.5, true)
		if second > 0.0:
			draw_line(b, b.lerp(c, second), CREAM, 2.5, true)
