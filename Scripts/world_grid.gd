class_name WorldGrid
extends Node

signal solid_changed(cell: Vector2i, solid: bool)

@export var tile_map: TileMapLayer

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var astar := AStarGrid2D.new()
var occupied := {} # for dynamic blockers like npc

func _ready() -> void:
	print("hello world")
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

	for node in get_tree().get_nodes_in_group("blockers"):
		print(node)
		var shape_node := node as CollisionShape2D
		if shape_node == null:
			continue
		for cell in get_shape_cells(shape_node):
			if astar.is_in_boundsv(cell):
				set_solid(cell, true)

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

func get_shape_cells(shape_node: CollisionShape2D) -> Array[Vector2i]:
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		push_warning("%s: only RectangleShape2D is supported for blockers" % shape_node.get_path())
		return []

	# Bounding rect of the shape in global space (handles position, scale, rotation)
	var local_rect := Rect2(-rect_shape.size * 0.5, rect_shape.size)
	var rect := shape_node.global_transform * local_rect

	var a := world_to_cell(rect.position)
	var b := world_to_cell(rect.end)

	var cells: Array[Vector2i] = []
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			var cell := Vector2i(x, y)
			# include a cell only if its center is inside the rect
			if rect.has_point(cell_to_world(cell)):
				cells.append(cell)
	return cells

func get_perimeter_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var footprint := {}
	for c in cells:
		footprint[c] = true

	var seen := {}
	var result: Array[Vector2i] = []
	for c in cells:
		for dir in DIRS:
			var n := c + dir
			if footprint.has(n) or seen.has(n):
				continue
			seen[n] = true
			if is_free(n): # also rejects walls and out-of-bounds
				result.append(n)
	return result
