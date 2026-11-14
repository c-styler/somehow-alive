class_name SolarMinigame
extends CanvasLayer
## Full-screen solar panel maintenance, in two kid-friendly steps:
##   1. Wipe the Mars dust off the panel (drag over it, like a scratch card).
##   2. Plug the 3 cables into the matching sockets (colors + shapes, colorblind-safe).
## The POWER bar fills as you go. Emits finished(true) when done, finished(false) if closed.

signal finished(success: bool)

const FONT := preload("res://Assets/Fonts/Fredoka,Nunito,Press_Start_2P/Nunito/static/Nunito-Black.ttf")

# palette
const CERULEAN := Color("0081A7")
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC")
const CORAL := Color("F07167")
const DEEP := Color("0B3C5D")
const SUN := Color("FFD166")
const DUST := Color("C9845A") # Mars dust

@export var clean_needed := 0.88 # fraction of dust to wipe before step 2
@export var brush_radius := 5.0 # in dust-texture pixels (x4 on screen)

var root: Control
var step_label: Label
var power_fill: ColorRect
var power := 0.0
var stage := 1
var dust_view: DustPanel
var cables: CableBoard
var banner: Label

func _ready() -> void:
	layer = 15 # above HUD (3), below Orbi's dialog (20)
	_build()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DEEP
	style.border_color = TEAL
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	root.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("SOLAR PANEL REPAIR", 22, SUN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = " X "
	close.add_theme_font_override("font", FONT)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _finish(false))
	header.add_child(close)

	step_label = _label("", 18, CREAM)
	column.add_child(step_label)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var stack := Control.new() # both stages live here; only one is visible at a time
	stack.custom_minimum_size = Vector2(420, 240)
	body.add_child(stack)

	dust_view = DustPanel.new()
	dust_view.brush_radius = brush_radius
	dust_view.cleaned.connect(_on_dust_progress)
	stack.add_child(dust_view)

	cables = CableBoard.new()
	cables.visible = false
	cables.progress.connect(_on_cable_progress)
	stack.add_child(cables)

	# POWER meter
	var meter := VBoxContainer.new()
	meter.add_theme_constant_override("separation", 6)
	body.add_child(meter)
	meter.add_child(_label("POWER", 14, SUN))
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.4)
	bar.custom_minimum_size = Vector2(46, 210)
	meter.add_child(bar)
	power_fill = ColorRect.new()
	power_fill.color = SUN
	power_fill.anchor_left = 0.0
	power_fill.anchor_right = 1.0
	power_fill.anchor_top = 1.0
	power_fill.anchor_bottom = 1.0
	bar.add_child(power_fill)

	banner = _label("", 44, SUN)
	banner.add_theme_color_override("font_outline_color", DEEP)
	banner.add_theme_constant_override("outline_size", 12)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	root.add_child(banner)

	_set_step()

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

func _set_step() -> void:
	if stage == 1:
		step_label.text = "Step 1: Wipe off the red Mars dust!"
	else:
		step_label.text = "Step 2: Plug each cable into its matching socket!"

func _set_power(p: float) -> void:
	power = clampf(p, 0.0, 1.0)
	var bar := power_fill.get_parent() as Control
	power_fill.offset_top = -bar.size.y * power
	power_fill.color = CORAL.lerp(SUN, power)

# dust counts for 60% of the power, cables for the last 40%
func _on_dust_progress(fraction: float) -> void:
	_set_power(0.6 * clampf(fraction / clean_needed, 0.0, 1.0))
	if stage == 1 and fraction >= clean_needed:
		stage = 2
		dust_view.wipe_all()
		await get_tree().create_timer(0.6).timeout
		dust_view.visible = false
		cables.visible = true
		_set_step()

func _on_cable_progress(connected: int, total: int) -> void:
	_set_power(0.6 + 0.4 * float(connected) / total)
	if connected == total:
		_win()

func _win() -> void:
	step_label.text = "Great job!"
	banner.text = "POWER RESTORED!"
	banner.visible = true
	banner.pivot_offset = banner.size / 2
	banner.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.4).timeout
	_finish(true)

func _finish(success: bool) -> void:
	finished.emit(success)
	queue_free()


## Step 1: a solar panel under a layer of dust; dragging wipes it off.
class DustPanel extends Control:
	signal cleaned(fraction: float)
	const SCALE := 4 # screen px per dust pixel
	var brush_radius := 5.0
	var img: Image
	var tex: ImageTexture
	var total := 0
	var remaining := 0
	var wiping := false

	func _init() -> void:
		custom_minimum_size = Vector2(420, 240)
		size = custom_minimum_size
		var w := int(size.x / SCALE)
		var h := int(size.y / SCALE)
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.08
		for y in h:
			for x in w:
				var n := noise.get_noise_2d(x, y) # -1..1, makes blotchy dust
				var c := SolarMinigame.DUST.darkened(0.15 * (n + 1.0)).lightened(randf() * 0.08)
				img.set_pixel(x, y, Color(c, 0.92))
		total = w * h
		remaining = total
		tex = ImageTexture.create_from_image(img)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			wiping = event.pressed
			if wiping:
				_wipe(event.position)
			accept_event()
		elif event is InputEventMouseMotion and wiping:
			_wipe(event.position)
			accept_event()

	func _wipe(at: Vector2) -> void:
		var c := at / SCALE
		var r := brush_radius
		var changed := false
		for y in range(int(c.y - r), int(c.y + r) + 1):
			for x in range(int(c.x - r), int(c.x + r) + 1):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				if Vector2(x, y).distance_to(c) > r:
					continue
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					remaining -= 1
					changed = true
		if changed:
			tex.update(img)
			queue_redraw()
			cleaned.emit(1.0 - float(remaining) / total)

	func wipe_all() -> void:
		img.fill(Color(0, 0, 0, 0))
		remaining = 0
		tex.update(img)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# the panel underneath: frame + grid of photovoltaic cells
		draw_rect(r, Color("2a3440"))
		var cols := 6
		var rows := 3
		var pad := 10.0
		var cw := (size.x - pad * 2) / cols
		var ch := (size.y - pad * 2) / rows
		for j in rows:
			for i in cols:
				var cell := Rect2(pad + i * cw + 3, pad + j * ch + 3, cw - 6, ch - 6)
				draw_rect(cell, SolarMinigame.CERULEAN.darkened(0.35))
				draw_line(cell.position + Vector2(6, 6), cell.position + Vector2(cell.size.x * 0.4, 6), Color(1, 1, 1, 0.25), 3.0) # shine
				for k in range(1, 4): # thin busbar lines
					var x := cell.position.x + cell.size.x * k / 4.0
					draw_line(Vector2(x, cell.position.y), Vector2(x, cell.end.y), Color(1, 1, 1, 0.08), 1.0)
		# dust layer on top, scaled up crisply
		draw_texture_rect(tex, r, false)
		draw_rect(r, SolarMinigame.TEAL, false, 3.0)


## Step 2: drag each plug on the left to the socket with the same color and shape.
class CableBoard extends Control:
	signal progress(connected: int, total: int)
	const COLORS := [Color("F07167"), Color("00AFB9"), Color("FFD166")]
	const SHAPES := ["circle", "triangle", "square"]
	const R := 20.0
	var plugs: Array[Vector2] = []
	var sockets: Array[Vector2] = []
	var socket_kind: Array[int] = [] # which plug kind each socket accepts
	var connected := {} # plug index -> true
	var dragging := -1
	var mouse := Vector2.ZERO
	var flash := {} # socket index -> seconds of red "wrong" flash

	func _init() -> void:
		custom_minimum_size = Vector2(420, 240)
		size = custom_minimum_size
		var order := [0, 1, 2]
		order.shuffle()
		while order == [0, 1, 2]: # make sure it's actually a puzzle
			order.shuffle()
		for i in 3:
			plugs.append(Vector2(50, 50 + i * 70))
			sockets.append(Vector2(370, 50 + i * 70))
			socket_kind.append(order[i])

	func _process(delta: float) -> void:
		for k in flash.keys():
			flash[k] -= delta
			if flash[k] <= 0.0:
				flash.erase(k)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			mouse = event.position
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			mouse = event.position
			if event.pressed:
				for i in plugs.size():
					if not connected.has(i) and plugs[i].distance_to(mouse) < R * 1.4:
						dragging = i
			elif dragging >= 0:
				for s in sockets.size():
					if sockets[s].distance_to(mouse) < R * 1.6:
						if socket_kind[s] == dragging:
							connected[dragging] = s
							progress.emit(connected.size(), plugs.size())
						else:
							flash[s] = 0.4
				dragging = -1
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a3440"))
		draw_rect(Rect2(Vector2.ZERO, size), SolarMinigame.TEAL, false, 3.0)
		# sockets
		for s in sockets.size():
			var kind: int = socket_kind[s]
			var lit := connected.values().has(s)
			draw_circle(sockets[s], R + 8, Color("1a222b"))
			var ring: Color = CORAL_FLASH if flash.has(s) else (COLORS[kind] if lit else COLORS[kind].darkened(0.4))
			draw_arc(sockets[s], R + 8, 0, TAU, 32, ring, 4.0)
			_shape(sockets[s], SHAPES[kind], COLORS[kind] if lit else COLORS[kind].darkened(0.5), 10.0)
		# cables
		for i in plugs.size():
			if connected.has(i):
				_cable(plugs[i], sockets[connected[i]], COLORS[i])
			elif dragging == i:
				_cable(plugs[i], mouse, COLORS[i])
		# plugs
		for i in plugs.size():
			draw_circle(plugs[i], R, COLORS[i])
			draw_arc(plugs[i], R, 0, TAU, 32, SolarMinigame.DEEP, 3.0)
			_shape(plugs[i], SHAPES[i], SolarMinigame.CREAM, 9.0)

	const CORAL_FLASH := Color(1, 0.2, 0.2)

	func _cable(a: Vector2, b: Vector2, color: Color) -> void:
		# saggy bezier so it reads as a real cable
		var mid := (a + b) / 2 + Vector2(0, 30)
		var pts := PackedVector2Array()
		for k in 21:
			var t := k / 20.0
			pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
		draw_polyline(pts, SolarMinigame.DEEP, 12.0, true)
		draw_polyline(pts, color, 7.0, true)
		draw_circle(b, 8, color)

	func _shape(c: Vector2, kind: String, color: Color, s: float) -> void:
		match kind:
			"circle":
				draw_circle(c, s * 0.8, color)
			"triangle":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), color)
			"square":
				draw_rect(Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), color)
