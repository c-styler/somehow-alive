@tool
class_name ThinWalls
extends Node2D
## Draws the thin walls painted in the Walls layer (walls sit on cell EDGES):
##   Walls layer atlas tile (0,0) = wall on that cell's top edge
##                          (1,0) = wall on its left edge
##                          (2,0) = both (a corner)
## Straight runs are merged into one strip each, extended by half the thickness at
## both ends so corners and T-junctions join cleanly. Also builds matching light
## occluders at runtime. The Walls layer itself (orange markers) is just data and is
## hidden in game. Redraws live in the editor while you paint.

@export var tile_map: TileMapLayer # kept for reference/placement; walls_layer drives drawing
@export var walls_layer: TileMapLayer:
	set(v):
		if walls_layer and walls_layer.changed.is_connected(_rebuild):
			walls_layer.changed.disconnect(_rebuild)
		walls_layer = v
		if walls_layer and Engine.is_editor_hint():
			walls_layer.changed.connect(_rebuild)
		_rebuild()
@export var wall_texture: Texture2D = preload("res://Assets/thin_wall.png"): # vertical strip
	set(v):
		wall_texture = v
		queue_redraw()
@export var thickness := 19.0: # px; thin_wall.png is 19 wide
	set(v):
		thickness = v
		_rebuild()
@export var build_occluders := true

var runs: Array[Rect2] = [] # merged wall strips, in walls_layer local space
var vertical: Array[bool] = []

func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	if walls_layer:
		walls_layer.visible = false # markers are data only
	if build_occluders:
		_build_occluders()

func _rebuild() -> void:
	runs.clear()
	vertical.clear()
	if walls_layer == null or walls_layer.tile_set == null:
		queue_redraw()
		return
	var size := Vector2(walls_layer.tile_set.tile_size)
	var t := thickness
	var tops := {} # row y -> [x...]
	var lefts := {} # column x -> [y...]
	for cell in walls_layer.get_used_cells():
		var ac := walls_layer.get_cell_atlas_coords(cell)
		if ac.x == 0 or ac.x == 2:
			tops.get_or_add(cell.y, []).append(cell.x)
		if ac.x == 1 or ac.x == 2:
			lefts.get_or_add(cell.x, []).append(cell.y)
	# horizontal runs along top edges
	for y in tops:
		for run in _runs(tops[y]):
			var tl := _corner(Vector2i(run.x, y), size)
			runs.append(Rect2(tl.x - t / 2, tl.y - t / 2, (run.y - run.x + 1) * size.x + t, t))
			vertical.append(false)
	# vertical runs along left edges
	for x in lefts:
		for run in _runs(lefts[x]):
			var tl := _corner(Vector2i(x, run.x), size)
			runs.append(Rect2(tl.x - t / 2, tl.y - t / 2, t, (run.y - run.x + 1) * size.y + t))
			vertical.append(true)
	queue_redraw()

## Groups sorted ints into consecutive runs: [1,2,3,7,8] -> [(1,3), (7,8)]
func _runs(values: Array) -> Array[Vector2i]:
	values.sort()
	var out: Array[Vector2i] = []
	var start: int = values[0]
	var prev: int = values[0]
	for v in values.slice(1):
		if v != prev + 1:
			out.append(Vector2i(start, prev))
			start = v
		prev = v
	out.append(Vector2i(start, prev))
	return out

## Top-left corner of a cell in walls_layer local space.
func _corner(cell: Vector2i, size: Vector2) -> Vector2:
	return walls_layer.map_to_local(cell) - size / 2

func _draw() -> void:
	if walls_layer == null:
		return
	var xf := get_global_transform().affine_inverse() * walls_layer.get_global_transform()
	for i in runs.size():
		var r := runs[i]
		if wall_texture == null:
			draw_set_transform_matrix(xf)
			draw_rect(r, Color("8a8f98"))
			continue
		if vertical[i]:
			draw_set_transform_matrix(xf)
			draw_texture_rect(wall_texture, r, true) # tiles the strip down its length
		else:
			# draw the vertical strip rotated 90 degrees so it runs horizontally
			var c := r.get_center()
			draw_set_transform_matrix(xf * Transform2D(PI / 2, c))
			var rotated := Rect2(-Vector2(r.size.y, r.size.x) / 2, Vector2(r.size.y, r.size.x))
			draw_texture_rect(wall_texture, rotated, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## One occluder per wall run, so shadows start right at the thin wall.
func _build_occluders() -> void:
	var xf := walls_layer.get_global_transform()
	for r in runs:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([
			xf * r.position, xf * Vector2(r.end.x, r.position.y),
			xf * r.end, xf * Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		add_child(occ)
		occ.global_transform = Transform2D.IDENTITY
