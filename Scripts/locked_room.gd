@tool
class_name LockedRoom
extends Node2D
## A sealed room that reads as "lights off, nobody lives here yet":
##  - the floor is dimmed (drawn UNDER the thin walls, so the walls hide the seams),
##  - the doorway is closed with a strip of the same wall art + a small red lock light,
##  - furniture inside stays visible but dimmed, so you can tell someone lived here,
##  - every cell is solid, so nobody can path inside.
## Keep this node between the TileMapLayer and ThinWalls in the tree.
## Flip `unlocked` (e.g. from a story beat) to open it.

@export var tile_map: TileMapLayer:
	set(v):
		tile_map = v
		queue_redraw()
@export var grid: WorldGrid
## The room's cells (inclusive rect, in tile coordinates).
@export var cells := Rect2i(0, 0, 5, 7):
	set(v):
		cells = v
		queue_redraw()
@export var door_from := 1 # first door cell, counted from the room's left edge
@export var door_width := 2
@export_enum("top", "bottom") var door_side := "bottom":
	set(v):
		door_side = v
		queue_redraw()
@export var dim := Color(0.03, 0.05, 0.09, 0.82): # lights-off tint over the floor
	set(v):
		dim = v
		queue_redraw()
## Tint for the furniture inside while locked (dark, like the lights are off).
@export var furniture_tint := Color(0.32, 0.35, 0.45)
@export var door_texture: Texture2D = preload("res://Assets/thin_wall.png")
@export var door_thickness := 19.0
@export var unlocked := false:
	set(v):
		unlocked = v
		queue_redraw()
		if _icon:
			_icon.queue_redraw()
		if is_node_ready() and not Engine.is_editor_hint():
			_apply()

const LOCK_RED := Color("F07167")

## Big padlock over the middle of the room. Lives on its own child node with a higher
## z_index, so it draws above the (dimmed) furniture.
@export var center_padlock_px := 6.0 # art pixel size; 9x10 art -> 54x60 on screen
var _icon: Node2D

func _ready() -> void:
	_icon = Node2D.new()
	_icon.z_index = 1
	_icon.draw.connect(_draw_center_icon)
	add_child(_icon, false, Node.INTERNAL_MODE_FRONT)
	if not Engine.is_editor_hint():
		_apply.call_deferred() # after WorldGrid has built its grid and furniture has loaded

func _apply() -> void:
	if grid:
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				grid.set_solid(Vector2i(x, y), not unlocked)
	var area := _room_rect_global()
	for prop in get_tree().get_nodes_in_group("furniture"):
		if area.has_point(prop.global_position):
			prop.modulate = Color.WHITE if unlocked else furniture_tint

func _process(_delta: float) -> void:
	if not unlocked and not Engine.is_editor_hint():
		queue_redraw() # lock light pulse
		if _icon:
			_icon.queue_redraw()

func _room_rect() -> Rect2:
	var size := Vector2(tile_map.tile_set.tile_size)
	var tl := tile_map.map_to_local(cells.position) - size / 2
	return Rect2(tl, Vector2(cells.size) * size)

func _room_rect_global() -> Rect2:
	var r := _room_rect()
	return tile_map.get_global_transform() * r

func _draw() -> void:
	if tile_map == null or unlocked:
		return
	var xf := get_global_transform().affine_inverse() * tile_map.get_global_transform()
	draw_set_transform_matrix(xf)
	var size := Vector2(tile_map.tile_set.tile_size)
	var room := _room_rect()
	draw_rect(room, dim) # full room: the thin walls drawn later cover the edges

	# close the doorway with the wall strip, slightly darker, plus a lock light
	var y := room.position.y if door_side == "top" else room.end.y
	var x0 := room.position.x + door_from * size.x
	var door := Rect2(x0, y - door_thickness / 2, door_width * size.x, door_thickness)
	if door_texture:
		var c := door.get_center()
		draw_set_transform_matrix(xf * Transform2D(PI / 2, c))
		var rotated := Rect2(-Vector2(door.size.y, door.size.x) / 2, Vector2(door.size.y, door.size.x))
		draw_texture_rect(door_texture, rotated, true, Color(0.8, 0.8, 0.85))
		draw_set_transform_matrix(xf)
	else:
		draw_rect(door, Color("6b7480"))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 450.0)
	draw_circle(door.get_center(), 16.0, Color(LOCK_RED, 0.22 * pulse)) # soft red glow
	_draw_padlock(door.get_center())

func _draw_center_icon() -> void:
	if tile_map == null or unlocked:
		return
	_icon.draw_set_transform_matrix(get_global_transform().affine_inverse() * tile_map.get_global_transform())
	var c := _room_rect().get_center()
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 450.0)
	_icon.draw_circle(c, 46.0, Color(LOCK_RED, 0.12 * pulse))
	_icon.draw_circle(c, 30.0, Color(LOCK_RED, 0.12 * pulse))
	_draw_padlock(c, center_padlock_px, _icon)

## Pixel-art padlock, centered on `c`, drawn onto `canvas` (self by default).
const PADLOCK := [
	"..XXXXX..",
	".XX...XX.",
	".X.....X.",
	".X.....X.",
	"XXXXXXXXX",
	"XBBBBBBBX",
	"XBBBKBBBX",
	"XBBBKBBBX",
	"XBBBBBBBX",
	"XXXXXXXXX",
]
const PADLOCK_OUTLINE := Color("0B3C5D")
const PADLOCK_BODY := Color("F07167")
const PADLOCK_KEYHOLE := Color("3a1a18")

func _draw_padlock(c: Vector2, px := 2.0, canvas: CanvasItem = null) -> void:
	if canvas == null:
		canvas = self
	var size := Vector2(PADLOCK[0].length(), PADLOCK.size()) * px
	var origin := (c - size / 2).round()
	for y in PADLOCK.size():
		var row: String = PADLOCK[y]
		for x in row.length():
			var col: Color
			match row[x]:
				"X": col = PADLOCK_OUTLINE
				"B": col = PADLOCK_BODY
				"K": col = PADLOCK_KEYHOLE
				_: continue
			canvas.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), col)
