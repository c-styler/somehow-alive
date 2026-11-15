@tool
class_name FloorDecals
extends Node2D
## Paints one region of a texture into each listed floor cell (scaled to the tile size),
## e.g. metal deck plates, vent grates or hazard stripes from a sheet that isn't on the
## tile grid. Put it between the TileMapLayer and ThinWalls in the tree so the thin walls
## draw over the decal edges. Walk-through; purely visual.

@export var tile_map: TileMapLayer:
	set(v):
		tile_map = v
		queue_redraw()
@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var region := Rect2():
	set(v):
		region = v
		queue_redraw()
## Fill a whole rectangle of cells (inclusive rect in tile coords)...
@export var fill_rect := Rect2i():
	set(v):
		fill_rect = v
		queue_redraw()
## ...and/or individual cells.
@export var cells: Array[Vector2i] = []:
	set(v):
		cells = v
		queue_redraw()
## Cells to leave out of fill_rect (e.g. where another decal goes).
@export var skip_cells: Array[Vector2i] = []:
	set(v):
		skip_cells = v
		queue_redraw()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()

func _draw() -> void:
	if tile_map == null or texture == null or tile_map.tile_set == null:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse() * tile_map.get_global_transform())
	var size := Vector2(tile_map.tile_set.tile_size)
	var all: Array[Vector2i] = cells.duplicate()
	for y in range(fill_rect.position.y, fill_rect.end.y):
		for x in range(fill_rect.position.x, fill_rect.end.x):
			var c := Vector2i(x, y)
			if c not in skip_cells and c not in all:
				all.append(c)
	for c in all:
		var dest := Rect2(tile_map.map_to_local(c) - size / 2, size)
		draw_texture_rect_region(texture, dest, region, tint)
