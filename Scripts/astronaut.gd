class_name Player
extends CharacterBody2D

@export var tile_map: TileMapLayer
@export var world: WorldGrid
@export var speed := 120.0 # pixels per second

var tween: Tween

var current_tile: Vector2i
var facing: Vector2i

var is_moving: bool:
	get: return not path.is_empty()

var path: Array[Vector2i] = []

func _ready() -> void:
	current_tile = world.world_to_cell(global_position)
	global_position = world.cell_to_world(current_tile)
	facing = Vector2.DOWN

func update_animation() -> void:
	var state := "walk" if is_moving else "idle"
	$AnimatedSprite2D.play(state + "_" + get_dir_name(facing))

# func _unhandled_input(event: InputEvent) -> void:
# 	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
# 		var target := tile_map.local_to_map(tile_map.get_local_mouse_position())
# 		var start := tile_map.local_to_map(tile_map.to_local(global_position))

# 		if not world.is_solid(target):
# 			follow_path(world.get_path_cells(current_tile, target));

# func follow_path(new_path: Array[Vector2i]) -> void:
# 	path = new_path.slice(1) # skip the tile we're on

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := world.world_to_cell(get_global_mouse_position())
		if not world.is_solid(target):
			follow_path(target)

func follow_path(target: Vector2i) -> void:
	# If mid-step, the new route starts from the tile we're already heading into
	var start := current_tile if path.is_empty() else path[0]

	var new_path := world.get_path_cells(start, target)
	if new_path.is_empty():
		return # unreachable, keep doing whatever we were doing

	if path.size() > 1:
		path.resize(1) # keep only the step in progress, drop the rest of the old route

	# new_path[0] is `start`, so skip it. If idle, path is empty and this becomes the whole route.
	path.append_array(new_path.slice(1))

func _physics_process(delta: float) -> void:
	if path.is_empty():
		update_animation()
		return

	var target_tile := path[0]
	var target := tile_map.to_global(tile_map.map_to_local(target_tile))

	var to_target := target - global_position
	if to_target != Vector2.ZERO:
		if absf(to_target.x) > absf(to_target.y):
			facing = Vector2i(int(signf(to_target.x)), 0)
		else:
			facing = Vector2i(0, int(signf(to_target.y)))

	global_position = global_position.move_toward(target, speed * delta)

	if global_position == target:
		current_tile = target_tile
		path.remove_at(0)

	update_animation()

func get_dir_name(dir: Vector2i) -> String:
	match dir:
		Vector2i.UP: return "forward"
		Vector2i.DOWN: return "back"
		Vector2i.LEFT: return "left"
		_: return "right"
