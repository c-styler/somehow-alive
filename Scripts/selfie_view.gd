class_name SelfieView
extends CanvasLayer
## The selfie moment: fade to black -> camera flash + shutter sound -> the photo pops in.
## Close with the CLOSE button, Esc/Enter/Space or a click; fades back to the game.
## Pauses the game while open. Await play().

signal finished

const PHOTO_PATH := "res://Assets/selfie.png"
const SHUTTER_PATH := "res://Assets/camera_shutter.mp3"
const FONT := preload("res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Nunito/static/Nunito-Black.ttf")
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC")
const DEEP := Color("0B3C5D")

var root: Control
var black: ColorRect
var flash: ColorRect
var photo: TextureRect
var close_button: Button
var _can_close := false
var _closing := false

func _ready() -> void:
	layer = 40 # above HUD and Orbi's dialog
	process_mode = Node.PROCESS_MODE_ALWAYS

func play() -> void:
	_build()
	get_tree().paused = true
	# 1. fade to black
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 0.45)
	await t.finished
	# 2. click! white flash + shutter
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load(SHUTTER_PATH)
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	sfx.play()
	flash.color.a = 1.0
	# 3. the photo pops in as the flash fades
	photo.visible = true
	photo.pivot_offset = photo.size / 2
	photo.scale = Vector2(0.85, 0.85)
	photo.rotation = deg_to_rad(-4)
	t = create_tween().set_parallel()
	t.tween_property(flash, "color:a", 0.0, 0.5)
	t.tween_property(photo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(photo, "rotation", deg_to_rad(1.5), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	close_button.visible = true
	_can_close = true
	await finished

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_root_input)
	add_child(root)

	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)

	# the photo: square, ~78% of the screen height, centered
	var viewport := get_viewport().get_visible_rect().size
	var side := viewport.y * 0.78
	photo = TextureRect.new()
	photo.texture = load(PHOTO_PATH)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.size = Vector2(side, side)
	photo.position = (viewport - photo.size) / 2 - Vector2(0, viewport.y * 0.03)
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo.visible = false
	root.add_child(photo)

	close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.add_theme_color_override("font_color", CREAM)
	var style := StyleBoxFlat.new()
	style.bg_color = DEEP
	style.border_color = TEAL
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = DEEP.lightened(0.15)
	close_button.add_theme_stylebox_override("normal", style)
	close_button.add_theme_stylebox_override("hover", hover)
	close_button.add_theme_stylebox_override("pressed", hover)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.pressed.connect(_close)
	close_button.visible = false
	root.add_child(close_button)
	close_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	close_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	close_button.grow_vertical = Control.GROW_DIRECTION_BEGIN

	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if not _can_close or _closing:
		return
	_closing = true
	close_button.visible = false
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.45)
	await t.finished
	get_tree().paused = false
	finished.emit()
	queue_free()
