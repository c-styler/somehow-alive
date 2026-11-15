class_name IntroCutscene
extends CanvasLayer
## Full-screen intro video before the game starts. Pauses the game while it plays.
## SKIP button (bottom-right) with a ring around it that fills with the video's progress;
## Esc also skips. Emits `finished` after fading out (also right away if the video is missing).
##
## Godot only plays Ogg Theora video (.ogv), so convert the .mp4 once, e.g.:
##   ffmpeg -i somehow_alive_intro.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 somehow_alive_intro.ogv

signal finished
## Fired the moment the video ends or is skipped, BEFORE the fade-out, so whatever
## should be underneath (the game world) can be shown in time.
signal ending

const VIDEO_PATH := "res://Assets/somehow_alive_intro.ogv" # 480p Theora+Vorbis (Godot cannot play VP8/Opus .ogv files)
const FONT := preload("res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Nunito/static/Nunito-Black.ttf")
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC")
const DEEP := Color("0B3C5D")

var root: Control
var player: VideoStreamPlayer
var skip_button: Button
var ring: ProgressRing
var _done := false

func _ready() -> void:
	layer = 50 # above everything, including Orbi's dialog and the fade layer
	process_mode = Node.PROCESS_MODE_ALWAYS

## Plays the intro; await it. Returns immediately if the video file isn't there.
func play() -> void:
	if not ResourceLoader.exists(VIDEO_PATH):
		push_warning("Intro video not found at %s (Godot needs .ogv, see intro_cutscene.gd)" % VIDEO_PATH)
		finished.emit.call_deferred()
		await finished
		return
	_build()
	get_tree().paused = true
	player.stream = load(VIDEO_PATH)
	player.finished.connect(_end)
	player.play()
	await finished

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	# keep the video's aspect ratio, letterboxed on black
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	root.add_child(aspect)
	player = VideoStreamPlayer.new()
	player.expand = true
	aspect.add_child(player)

	# SKIP button with a progress ring around it, bottom-right
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(150, 150)
	root.add_child(corner)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN

	ring = ProgressRing.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(ring)

	skip_button = Button.new()
	skip_button.text = "SKIP"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_override("font", FONT)
	skip_button.add_theme_font_size_override("font_size", 22)
	skip_button.add_theme_color_override("font_color", CREAM)
	skip_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(DEEP, 0.85)
	style.set_corner_radius_all(60)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(DEEP.lightened(0.15), 0.95)
	skip_button.add_theme_stylebox_override("normal", style)
	skip_button.add_theme_stylebox_override("hover", hover)
	skip_button.add_theme_stylebox_override("pressed", hover)
	skip_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	corner.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	skip_button.custom_minimum_size = Vector2(108, 108)
	skip_button.position = (corner.custom_minimum_size - skip_button.custom_minimum_size) / 2
	skip_button.pressed.connect(_end)

func _process(_delta: float) -> void:
	if player == null or _done:
		return
	var length := player.get_stream_length()
	if length > 0.0:
		ring.progress = clampf(player.stream_position / length, 0.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if player and not _done and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_end()

func _end() -> void:
	if _done:
		return
	_done = true
	ending.emit()
	ring.progress = 1.0
	var t := create_tween()
	t.tween_property(root, "modulate:a", 0.0, 0.6)
	await t.finished
	player.stop()
	get_tree().paused = false
	finished.emit()
	queue_free()


## Circular progress: a faint full ring with a teal arc that fills clockwise from the top.
class ProgressRing extends Control:
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2 - 8
		draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.18), 8.0, true)
		if progress > 0.0:
			draw_arc(c, r, -PI / 2, -PI / 2 + TAU * progress, 64, Color("00AFB9"), 8.0, true)
