class_name WorldGrid
extends Node

signal solid_changed(cell: Vector2i, solid: bool)

@export var tile_map: TileMapLayer
## Thin walls live on cell EDGES, painted in this layer: atlas tile (0,0) = wall on the
## cell's top edge, (1,0) = left edge, (2,0) = both. (Bottom/right edges are the
## neighbour's top/left.)
@export var walls_layer: TileMapLayer

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

## World border, in cells. Everything outside is solid: no walking, no pathing, Orbi
## can't float there either. Keep it well inside the painted ground so the camera never
## shows the edge of the map. Empty rect = no border.
## Base spans roughly x -5..57, y -6..9; this leaves ~10 tiles of Mars around it.
@export var playable_rect := Rect2i(-15, -16, 83, 36)

## Pathfinding runs on a DOUBLE-resolution grid so walls can sit between cells:
##   cell (x, y)             -> node (2x+1, 2y+1)
##   edge between two cells  -> the node in between them
##   grid corners (even, even) are always solid
## A wall just makes its edge node solid. Paths come back as plain cell paths.
var astar := AStarGrid2D.new()
var occupied := {} # for dynamic blockers like npc
var cell_size: Vector2i
var cells_rect: Rect2i # used rect of the tile map, in cells

static func _node(cell: Vector2i) -> Vector2i:
	return cell * 2 + Vector2i.ONE

static func _edge(a: Vector2i, b: Vector2i) -> Vector2i:
	return a + b + Vector2i.ONE # = midpoint of _node(a) and _node(b)

func _ready() -> void:
	cell_size = tile_map.tile_set.tile_size
	cells_rect = tile_map.get_used_rect()
	astar.region = Rect2i(cells_rect.position * 2, cells_rect.size * 2 + Vector2i.ONE)
	astar.cell_size = Vector2(cell_size) / 2.0
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	var r := astar.region
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x % 2 == 0 and y % 2 == 0:
				astar.set_point_solid(Vector2i(x, y)) # grid corners: never walkable

	# legacy: any tile still flagged "solid" blocks its whole cell
	for cell in tile_map.get_used_cells():
		var data := tile_map.get_cell_tile_data(cell)
		if data and data.get_custom_data("solid"):
			astar.set_point_solid(_node(cell))

	if walls_layer:
		for cell in walls_layer.get_used_cells():
			var ac := walls_layer.get_cell_atlas_coords(cell)
			if ac.x == 0 or ac.x == 2:
				set_wall(cell, cell + Vector2i.UP, true)
			if ac.x == 1 or ac.x == 2:
				set_wall(cell, cell + Vector2i.LEFT, true)

	for node in get_tree().get_nodes_in_group("blockers"):
		print(node)
		var shape_node := node as CollisionShape2D
		if shape_node == null:
			continue
		for cell in get_shape_cells(shape_node):
			if astar.is_in_boundsv(_node(cell)):
				set_solid(cell, true)

	for prop in get_tree().get_nodes_in_group("props"):
		for cell in get_rect_cells(prop.get_block_rect()):
			if astar.is_in_boundsv(_node(cell)):
				set_solid(cell, true)

	if playable_rect.has_area():
		for y in range(cells_rect.position.y, cells_rect.end.y):
			for x in range(cells_rect.position.x, cells_rect.end.x):
				if not playable_rect.has_point(Vector2i(x, y)):
					astar.set_point_solid(_node(Vector2i(x, y)))

## How many cells inside the border this cell is (0 = on the edge, negative = outside).
func distance_to_border(cell: Vector2i) -> int:
	if not playable_rect.has_area():
		return 1 << 20
	return mini(
		mini(cell.x - playable_rect.position.x, playable_rect.end.x - 1 - cell.x),
		mini(cell.y - playable_rect.position.y, playable_rect.end.y - 1 - cell.y))

func is_solid(cell: Vector2i) -> bool:
	var n := _node(cell)
	return not astar.is_in_boundsv(n) or astar.is_point_solid(n)

## True if a wall sits on the edge between two neighbouring cells.
func has_wall(a: Vector2i, b: Vector2i) -> bool:
	var e := _edge(a, b)
	return not astar.is_in_boundsv(e) or astar.is_point_solid(e)

func set_wall(a: Vector2i, b: Vector2i, on: bool) -> void:
	var e := _edge(a, b)
	if astar.is_in_boundsv(e):
		astar.set_point_solid(e, on)

## Can you walk from a to its 4-neighbour b? (b not blocked, no wall in between)
func can_step(a: Vector2i, b: Vector2i) -> bool:
	return not is_solid(b) and not has_wall(a, b)

func is_free(cell: Vector2i) -> bool:
	return not is_solid(cell) and not occupied.has(cell)

func get_path_cells(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for n in astar.get_id_path(_node(from), _node(to)):
		if n.x % 2 != 0 and n.y % 2 != 0: # skip the edge nodes in between
			cells.append(Vector2i((n.x - 1) / 2, (n.y - 1) / 2))
	return straighten(cells)

## A* on a 4-way grid has many equally short routes and happily picks staircase ones
## (right, down, right, down...). This rewrites the path with as few turns as possible
## without making it longer: from each point, jump to the furthest later point that can
## be reached by an L (one straight leg, one turn, one straight leg) through free cells.
## An L between two cells is always the shortest possible walk, so length never grows.
func straighten(path: Array[Vector2i]) -> Array[Vector2i]:
	if path.size() < 3:
		return path
	var out: Array[Vector2i] = [path[0]]
	var i := 0
	var heading := Vector2i.ZERO # direction of the last step, to prefer not turning
	while i < path.size() - 1:
		for j in range(path.size() - 1, i, -1):
			var leg := _l_route(path[i], path[j], heading)
			if not leg.is_empty() and leg.size() <= j - i:
				out.append_array(leg)
				heading = leg[-1] - (out[-2])
				i = j
				break
	return out

## Cells from a (exclusive) to b (inclusive) along an L, or [] if both L's are blocked.
## Tries the L whose first leg keeps the current heading first.
func _l_route(a: Vector2i, b: Vector2i, heading: Vector2i) -> Array[Vector2i]:
	var horizontal_first := heading.y == 0 # moving sideways (or not yet) -> keep going sideways
	for attempt in 2:
		var corner := Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
		var cells := _line(a, corner)
		cells.append_array(_line(corner, b))
		var ok := true
		var prev := a
		for c in cells:
			if not can_step(prev, c):
				ok = false
				break
			prev = c
		if ok:
			return cells
		horizontal_first = not horizontal_first
	return []

## Straight axis-aligned run from a (exclusive) to b (inclusive).
func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var step := (b - a).sign()
	var c := a
	while c != b:
		c += step
		cells.append(c)
	return cells

func world_to_cell(global_pos: Vector2) -> Vector2i:
	return tile_map.local_to_map(tile_map.to_local(global_pos))

func cell_to_world(cell: Vector2i) -> Vector2:
	return tile_map.to_global(tile_map.map_to_local(cell))

func set_solid(cell: Vector2i, solid: bool) -> void:
	astar.set_point_solid(_node(cell), solid)
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
	return get_rect_cells(shape_node.global_transform * local_rect)

## Cells whose centers lie inside a global-space rect.
func get_rect_cells(rect: Rect2) -> Array[Vector2i]:
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
			# free, and not on the other side of a wall from the object
			if is_free(n) and not has_wall(c, n):
				result.append(n)
	return result
