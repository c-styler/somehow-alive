class_name WorldGrid
extends Node

signal solid_changed(cell: Vector2i, solid: bool)

@export var tile_map: TileMapLayer

var astar := AStarGrid2D.new()
var occupied := {} # for dynamic blockers like npc

func _ready() -> void:
	astar.region = tile_map.get_used_rect()
	astar.cell_size = tile_map.tile_set.tile_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	# for y in range(4, 8):
	# 	for x in range(4, 8):
	# 		astar.set_point_solid(Vector2i(x, y))
	for cell in tile_map.get_used_cells():
		var data := tile_map.get_cell_tile_data(cell)
		if data and data.get_custom_data("solid"):
			astar.set_point_solid(cell)

func is_solid(cell: Vector2i) -> bool:
	return not astar.is_in_boundsv(cell) or astar.is_point_solid(cell)

func is_free(cell: Vector2i) -> bool:
	return not is_solid(cell) and not occupied.has(cell)

func get_path_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return astar.get_id_path(from, to)

func world_to_cell(global_pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(global_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(cell))

func set_solid(cell: Vector2i, solid: bool) -> void:
	astar.set_point_solid(cell, solid)
	solid_changed.emit(cell, solid)

func occupy(cell: Vector2i, who: Node) -> void:
	occupied[cell] = who

func vacate(cell: Vector2i, who: Node) -> void:
	if occupied.get(cell) == who:
		occupied.erase(cell)
