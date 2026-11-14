class_name OrbiDialog
extends CanvasLayer
## Full-screen Orbi conversation: dims and pauses the game, shows Orbi (by mood),
## a speech bubble with typewriter text, an optional picture + caption, and NEXT.
## Usage: dialog.play(Dialogues.get_lines(id)); await dialog.finished

signal finished

const MOODS := {
	"neutral": "res://Assets/Orbi/orbi.png",
	"happy": "res://Assets/Orbi/orbi_happy.png",
	"sad": "res://Assets/Orbi/orbi_sad.png",
	"anger": "res://Assets/Orbi/orbi_anger.png",
}
const BODY_FONT := "res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Fredoka/static/Fredoka-Medium.ttf"
const BUTTON_FONT := "res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Nunito/static/Nunito-Black.ttf"

# palette
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC")
const CORAL := Color("F07167")
const DEEP := Color("0B3C5D")

@export var chars_per_second := 45.0

var lines: Array = []
var index := -1
var typing := false
var shown_chars := 0.0
var time := 0.0

var root: Control
var dim: ColorRect
var orbi_holder: Control
var orbi: TextureRect
var bubble: SpeechBubble
var text_label: Label
var media_row: HBoxContainer
var image_frame: PanelContainer
var image_rect: TextureRect
var caption_label: Label
var next_button: Button

func _ready() -> void:
	layer = 20 # above HUD
	process_mode = Node.PROCESS_MODE_ALWAYS # keeps running while the game is paused
	_build()
	visible = false

## Starts a conversation. Does nothing if lines is empty.
func play(new_lines: Array) -> void:
	if new_lines.is_empty():
		return
	lines = new_lines
	index = -1
	visible = true
	get_tree().paused = true
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	_advance()

func _close() -> void:
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.2)
	await t.finished
	visible = false
	get_tree().paused = false
	finished.emit()

func _advance() -> void:
	if typing:
		# first press just finishes the current line
		_finish_typing()
		return
	index += 1
	if index >= lines.size():
		_close()
		return
	_show_line(lines[index])

func _show_line(line: Dictionary) -> void:
	var tex: Texture2D = load(MOODS.get(line.get("mood", "neutral"), MOODS.neutral))
	if tex != orbi.texture:
		orbi.texture = tex
		# little pop on mood change
		orbi.pivot_offset = orbi.size / 2
		orbi.scale = Vector2(1.08, 1.08)
		create_tween().tween_property(orbi, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	text_label.text = line.get("text", "")
	text_label.visible_characters = 0
	shown_chars = 0.0
	typing = true

	var image_path: String = line.get("image", "")
	image_frame.visible = image_path != ""
	if image_path != "":
		image_rect.texture = load(image_path)
	caption_label.text = line.get("caption", "")
	caption_label.visible = caption_label.text != ""
	media_row.visible = image_frame.visible or caption_label.visible
	media_row.modulate.a = 0.0 # revealed once typing ends

	next_button.text = "NEXT ›" if index < lines.size() - 1 else "OK!"

func _finish_typing() -> void:
	typing = false
	text_label.visible_characters = -1
	create_tween().tween_property(media_row, "modulate:a", 1.0, 0.2)

func _process(delta: float) -> void:
	if not visible:
		return
	time += delta
	orbi.position.y = sin(time * 2.2) * 6.0 # gentle hover bob
	if typing:
		shown_chars += chars_per_second * delta
		text_label.visible_characters = int(shown_chars)
		if shown_chars >= text_label.get_total_character_count():
			_finish_typing()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()

func _on_root_gui_input(event: InputEvent) -> void:
	# clicking anywhere also advances, like most visual novels
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

# --- layout (built in code, like the rest of the UI) ---

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP # swallow clicks so nothing reaches the world
	root.gui_input.connect(_on_root_gui_input)
	add_child(root)

	dim = ColorRect.new()
	dim.color = Color(DEEP.darkened(0.6), 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	# Orbi, big, bottom-left
	orbi_holder = Control.new()
	_anchor(orbi_holder, 0.0, 0.3, 0.4, 1.05)
	orbi_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(orbi_holder)
	orbi = TextureRect.new()
	orbi.set_anchors_preset(Control.PRESET_FULL_RECT)
	orbi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orbi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orbi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # crisp pixel art
	orbi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbi_holder.add_child(orbi)

	# right column: bubble, then picture + caption
	var column := VBoxContainer.new()
	_anchor(column, 0.42, 0.2, 0.95, 0.85)
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	bubble = SpeechBubble.new()
	column.add_child(bubble)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(200, 0)
	text_label.add_theme_font_override("font", load(BODY_FONT))
	text_label.add_theme_font_size_override("font_size", 26)
	text_label.add_theme_color_override("font_color", DEEP)
	bubble.add_child(text_label)

	media_row = HBoxContainer.new()
	media_row.add_theme_constant_override("separation", 14)
	media_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(media_row)

	image_frame = PanelContainer.new()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color.WHITE
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(5)
	image_frame.add_theme_stylebox_override("panel", frame_style)
	media_row.add_child(image_frame)
	image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(180, 120)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image_frame.add_child(image_rect)

	caption_label = Label.new()
	caption_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption_label.add_theme_font_override("font", load(BODY_FONT))
	caption_label.add_theme_font_size_override("font_size", 18)
	caption_label.add_theme_color_override("font_color", CREAM)
	media_row.add_child(caption_label)

	# NEXT, bottom-right
	next_button = Button.new()
	next_button.add_theme_font_override("font", load(BUTTON_FONT))
	next_button.add_theme_font_size_override("font_size", 26)
	next_button.add_theme_color_override("font_color", CREAM)
	next_button.add_theme_color_override("font_hover_color", Color.WHITE)
	next_button.add_theme_stylebox_override("normal", _button_style(DEEP))
	next_button.add_theme_stylebox_override("hover", _button_style(DEEP.lightened(0.15)))
	next_button.add_theme_stylebox_override("pressed", _button_style(TEAL.darkened(0.3)))
	next_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	next_button.pressed.connect(_advance)
	root.add_child(next_button)
	next_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	next_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	next_button.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _button_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = TEAL
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

func _anchor(c: Control, left: float, top: float, right: float, bottom: float) -> void:
	c.anchor_left = left
	c.anchor_top = top
	c.anchor_right = right
	c.anchor_bottom = bottom


## Rounded cream bubble with a tail pointing left toward Orbi.
class SpeechBubble extends PanelContainer:
	const FILL := Color("FDFCDC")
	const BORDER := Color("0B3C5D")
	const TAIL := 22.0

	func _init() -> void:
		var s := StyleBoxFlat.new()
		s.bg_color = FILL
		s.border_color = BORDER
		s.set_border_width_all(3)
		s.set_corner_radius_all(22)
		s.content_margin_left = 30
		s.content_margin_right = 30
		s.content_margin_top = 22
		s.content_margin_bottom = 22
		add_theme_stylebox_override("panel", s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.6
		var tip := Vector2(-TAIL, y + TAIL * 0.6)
		var top := Vector2(2, y - TAIL * 0.5)
		var bottom := Vector2(2, y + TAIL * 0.5)
		draw_colored_polygon(PackedVector2Array([top, tip, bottom]), FILL)
		draw_line(Vector2(0, top.y), tip, BORDER, 3.0, true)
		draw_line(tip, Vector2(0, bottom.y), BORDER, 3.0, true)
