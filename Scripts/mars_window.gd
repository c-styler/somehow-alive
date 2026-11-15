@tool
extends Interactable
## A round porthole on an outer wall, looking out at a Mars sunset (matches the selfie).
## Its task: take a selfie here -> SelfieView (fade, flash, shutter, photo) -> task done.
## Drawn in code; the node's origin is the center of the porthole.

@export var radius := 44.0:
	set(v):
		radius = v
		queue_redraw()

const RIM := Color("c8cdd6") # metal ring
const RIM_DARK := Color("6b7480")
const BRASS := Color("d9a441") # inner trim, like the window in the selfie
const OUTLINE := Color("0B3C5D")

var _busy := false

func interact(_player: Player) -> void:
	if _busy:
		return
	if not task_available:
		dialogue_requested.emit(&"window_view") # just enjoying the view
		return
	_busy = true
	set_indicator_visible(false)
	var view := SelfieView.new()
	get_tree().root.add_child(view)
	await view.play()
	_busy = false
	task_completed.emit(task_id)

func _draw() -> void:
	var r := radius
	# outer metal ring + outline
	draw_circle(Vector2.ZERO, r + 3, OUTLINE)
	draw_circle(Vector2.ZERO, r, RIM)
	draw_circle(Vector2.ZERO, r - 6, RIM_DARK)
	draw_circle(Vector2.ZERO, r - 8, BRASS)
	var g := r - 11 # glass radius
	# sky: deep blue at the top -> purple -> orange near the horizon, sun glowing blue-white
	var bands := [Color("2a3f9e"), Color("4b4fb0"), Color("7a4fa8"), Color("c4607a"), Color("e98a52")]
	for i in bands.size():
		var y0 := -g + (g * 1.25) * i / bands.size()
		_clip_band(y0, y0 + g * 1.25 / bands.size() + 1, g, bands[i])
	var sun := Vector2(g * 0.45, g * 0.12)
	draw_circle(sun, g * 0.32, Color(0.75, 0.85, 1.0, 0.35)) # blue halo (Mars sunsets are blue)
	draw_circle(sun, g * 0.16, Color("fff4d6"))
	# a few streaky clouds
	for c in [Vector2(-g * 0.5, -g * 0.55), Vector2(g * 0.1, -g * 0.35), Vector2(-g * 0.2, -g * 0.15)]:
		_clip_band_x(c, g * 0.45, 3.0, g, Color("f0a070", 0.8))
	# red canyon ground: two layers of hills
	_hills(g, g * 0.25, Color("9c3b24"), [0.0, -0.08, 0.04, -0.12, 0.02, -0.05, 0.06])
	_hills(g, g * 0.45, Color("6e2a1c"), [0.02, -0.1, -0.02, 0.05, -0.08, 0.0, 0.04])
	# glass reflection
	draw_line(Vector2(-g * 0.6, -g * 0.25), Vector2(-g * 0.25, -g * 0.6), Color(1, 1, 1, 0.35), 3.0, true)
	draw_line(Vector2(-g * 0.45, -g * 0.05), Vector2(-g * 0.05, -g * 0.45), Color(1, 1, 1, 0.2), 2.0, true)
	# bolts on the rim
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		draw_circle(Vector2.from_angle(a) * (r - 3), 1.6, RIM_DARK)

## Horizontal band of the disc between y0 and y1 (clipped to the glass circle).
func _clip_band(y0: float, y1: float, g: float, col: Color) -> void:
	var y := y0
	while y < y1:
		var yy := clampf(y, -g, g)
		var half := sqrt(maxf(g * g - yy * yy, 0.0))
		draw_rect(Rect2(-half, y, half * 2, minf(2.0, y1 - y)), col)
		y += 2.0

func _clip_band_x(center: Vector2, half_len: float, thick: float, g: float, col: Color) -> void:
	var half := sqrt(maxf(g * g - center.y * center.y, 0.0))
	var x0 := maxf(center.x - half_len, -half)
	var x1 := minf(center.x + half_len, half)
	if x1 > x0:
		draw_rect(Rect2(x0, center.y, x1 - x0, thick), col)

## Hills from a base height (offset below center), with bumps, filled down to the bottom.
func _hills(g: float, base: float, col: Color, bumps: Array) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := -g + 2.0 * g * i / n
		var t := float(i) / n * (bumps.size() - 1)
		var k := int(t)
		var b: float = lerpf(bumps[k], bumps[mini(k + 1, bumps.size() - 1)], t - k)
		var y := base + b * g
		var limit := sqrt(maxf(g * g - x * x, 0.0))
		pts.append(Vector2(x, clampf(y, -limit, limit)))
	for i in range(n, -1, -1):
		var x := -g + 2.0 * g * i / n
		pts.append(Vector2(x, sqrt(maxf(g * g - x * x, 0.0))))
	draw_colored_polygon(pts, col)
