extends Node2D

@export var tile_map: TileMapLayer
@export var world: WorldGrid
@export var draw_outline: bool

var _last_range := Rect2i()


func _process(_delta) -> void:
	if Input.is_action_just_pressed("show_outline"):
		draw_outline = !draw_outline
		_last_range = Rect2i()
		queue_redraw()
		return

	if !draw_outline:
		return

	# Redraw only when the camera crosses into a different cell range
	var r := _get_cell_range()
	if r != _last_range:
		_last_range = r
		queue_redraw()


func _get_cell_range() -> Rect2i:
	var tile_size := Vector2(tile_map.tile_set.tile_size)
	var view: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()

	var start := Vector2i((view.position / tile_size).floor()) - Vector2i.ONE
	var end := Vector2i((view.end / tile_size).ceil()) + Vector2i.ONE

	var map_rect := tile_map.get_used_rect()
	start = start.max(map_rect.position)
	end = end.min(map_rect.end)

	return Rect2i(start, (end - start).max(Vector2i.ZERO))


func _draw() -> void:
	if !draw_outline or !tile_map.tile_set:
		return

	var cells := _get_cell_range()
	var tile_size := Vector2(tile_map.tile_set.tile_size)

	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var color := Color.RED if world.is_solid(Vector2i(x, y)) else Color.BLUE
			draw_rect(Rect2(Vector2(x, y) * tile_size, tile_size), color, false, 1.0)


func _on_world_grid_solid_changed(cell: Vector2i, solid: bool) -> void:
	if draw_outline and _last_range.has_point(cell):
		queue_redraw()
