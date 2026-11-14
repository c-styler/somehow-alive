class_name WorldBorder
extends Node2D
## Visualises WorldGrid.playable_rect as a glowing "force field" line: marching coral dashes
## plus blinking beacon posts. It's only revealed near the player and fades out with
## distance, so it appears when you stumble upon it instead of cluttering the map.

@export var grid: WorldGrid
@export var player: Node2D
## Optional: cancels the day/night tint so the border reads at night (same trick as TileMarker).
@export var canvas_modulate: CanvasModulate

@export var reveal_radius := 420.0 # px around the player where the line is visible
@export var dash_length := 18.0
@export var dash_speed := 30.0 # px/s the dashes march along the edge
@export var post_every := 2 # tiles between beacon posts
@export var color := Color("F07167") # palette coral

var time := 0.0
var rect := Rect2() # border in global space

func _ready() -> void:
	z_index = 40 # above ground and props, below UI-ish world elements
	var tm := grid.tile_map
	var half := Vector2(tm.tile_set.tile_size) / 2
	var r := grid.playable_rect
	var tl := tm.to_global(tm.map_to_local(r.position) - half)
	var br := tm.to_global(tm.map_to_local(r.end) - half)
	rect = Rect2(tl, br - tl)

func _process(delta: float) -> void:
	time += delta
	if canvas_modulate:
		var c := canvas_modulate.color
		self_modulate = Color(1.0 / maxf(c.r, 0.05), 1.0 / maxf(c.g, 0.05), 1.0 / maxf(c.b, 0.05))
	queue_redraw()

func _alpha_at(p: Vector2) -> float:
	var d := p.distance_to(player.global_position)
	return clampf(1.0 - d / reveal_radius, 0.0, 1.0)

func _draw() -> void:
	if player == null or not grid.playable_rect.has_area():
		return
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		_draw_edge(to_local(corners[i]), to_local(corners[(i + 1) % 4]))
	_draw_posts()

func _draw_edge(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / length
	# only walk the part of the edge that can be visible
	var pp := to_local(player.global_position)
	var along := (pp - a).dot(dir)
	var start := maxf(0.0, along - reveal_radius)
	var stop := minf(length, along + reveal_radius)
	if stop <= start:
		return
	var period := dash_length * 2.0
	var offset := fmod(time * dash_speed, period)
	var s := floorf(start / period) * period + offset - period
	while s < stop:
		var d0 := maxf(s, start)
		var d1 := minf(s + dash_length, stop)
		if d1 > d0:
			var p0 := a + dir * d0
			var p1 := a + dir * d1
			var alpha := _alpha_at(to_global((p0 + p1) / 2))
			if alpha > 0.0:
				draw_line(p0, p1, Color(color, alpha * 0.25), 10.0) # glow
				draw_line(p0, p1, Color(color.lightened(0.3), alpha), 3.0) # core
		s += period

func _draw_posts() -> void:
	var tile := float(grid.tile_map.tile_set.tile_size.x) * grid.tile_map.global_scale.x * post_every
	var blink := 0.6 + 0.4 * sin(time * 4.0)
	var x := rect.position.x
	while x <= rect.end.x + 0.1:
		_post(Vector2(x, rect.position.y), blink)
		_post(Vector2(x, rect.end.y), blink)
		x += tile
	var y := rect.position.y + tile
	while y < rect.end.y - 0.1:
		_post(Vector2(rect.position.x, y), blink)
		_post(Vector2(rect.end.x, y), blink)
		y += tile

func _post(global_p: Vector2, blink: float) -> void:
	var alpha := _alpha_at(global_p)
	if alpha <= 0.0:
		return
	var p := to_local(global_p)
	draw_circle(p, 9.0, Color("0B3C5D", alpha)) # base
	draw_circle(p, 5.0, Color(color, alpha * blink)) # beacon
	draw_circle(p, 14.0, Color(color, alpha * blink * 0.15)) # halo
