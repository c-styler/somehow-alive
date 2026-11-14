class_name Player
extends CharacterBody2D

signal destination_set(cell: Vector2i)

@export var tile_map: TileMapLayer
@export var world: WorldGrid
@export var speed := 120.0 # pixels per second
@export var run_multiplier := 1.6 # speed boost while holding right mouse button

enum Outfit { SPACESUIT, GINGER }
## Which character art to use. SPACESUIT = the frames set up in astronaut.tscn,
## GINGER = ginger_frames (Assets/Astronaut/ginger_frames.tres).
@export var skin := Outfit.GINGER:
	set(v):
		skin = v
		if is_node_ready():
			_apply_skin()

## Edit FPS/frames by opening this resource in the SpriteFrames editor.
@export var ginger_frames: SpriteFrames = preload("res://Assets/Astronaut/ginger_frames.tres")
var _spacesuit_frames: SpriteFrames

## Hold right mouse to hurry (ignored while a task/dialogue has the input).
var is_running: bool:
	get: return not input_locked and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

const INTERACT_MASK := 1 << 2 # physics layer 3
var hovered: Interactable
var input_locked := false # set while a task/minigame owns the mouse

var tween: Tween

var current_tile: Vector2i
var facing: Vector2i

var is_moving: bool:
	get: return not path.is_empty()

var path: Array[Vector2i] = []

var pending: Interactable
var pending_footprint: Array[Vector2i] = []

func _ready() -> void:
	current_tile = world.world_to_cell(global_position)
	global_position = world.cell_to_world(current_tile)
	facing = Vector2.DOWN
	_apply_skin()

## Instantly moves to a cell, dropping any walk or pending interaction.
func teleport(cell: Vector2i) -> void:
	path.clear()
	clear_pending()
	current_tile = cell
	global_position = world.cell_to_world(cell)
	facing = Vector2i.DOWN

func _apply_skin() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	if _spacesuit_frames == null:
		_spacesuit_frames = sprite.sprite_frames # whatever the scene was set up with
	if skin == Outfit.GINGER and ginger_frames:
		sprite.sprite_frames = ginger_frames
	else:
		sprite.sprite_frames = _spacesuit_frames
	update_animation()

func update_animation() -> void:
	var state := "walk" if is_moving else "idle"
	$AnimatedSprite2D.play(state + "_" + get_dir_name(facing))
	# legs keep up with the faster pace
	$AnimatedSprite2D.speed_scale = run_multiplier if is_moving and is_running else 1.0

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_instance_valid(hovered):
			start_interaction(hovered)
			return
		var target := world.world_to_cell(get_global_mouse_position())
		if not world.is_solid(target):
			var candidates: Array[Vector2i] = [target]
			if move_to_closest(candidates):
				clear_pending()

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

	# destination is set in stone, emit for the marker node
	destination_set.emit(target)


## Paths to whichever candidate is closest (by path length) and commits to it.
## Returns false if none are reachable, leaving the current movement untouched.
func move_to_closest(candidates: Array[Vector2i]) -> bool:
	# If mid-step, the new route starts from the tile we're already heading into
	var start := current_tile if path.is_empty() else path[0]

	var best: Array[Vector2i] = []
	for cell in candidates:
		var p := world.get_path_cells(start, cell)
		if p.is_empty():
			continue
		if best.is_empty() or p.size() < best.size():
			best = p
	if best.is_empty():
		return false

	if path.size() > 1:
		path.resize(1) # keep only the step in progress
	path.append_array(best.slice(1)) # best[0] is `start`

	# destination is set in stone, emit for the marker node
	destination_set.emit(best[-1])

	return true

func _physics_process(delta: float) -> void:
	update_hover()

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

	var current_speed := speed * (run_multiplier if is_running else 1.0)
	global_position = global_position.move_toward(target, current_speed * delta)

	if global_position == target:
		current_tile = target_tile
		path.remove_at(0)
		if path.is_empty():
			_on_arrived()

	update_animation()

func get_dir_name(dir: Vector2i) -> String:
	match dir:
		Vector2i.UP: return "forward"
		Vector2i.DOWN: return "back"
		Vector2i.LEFT: return "left"
		_: return "right"

func update_hover() -> void:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = INTERACT_MASK

	var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
	var found: Interactable = null
	if not hits.is_empty() and not input_locked:
		# the Area2D is a child of the Interactable root
		found = hits[0].collider.get_parent() as Interactable

	if found == hovered:
		return
	if is_instance_valid(hovered):
		hovered.set_highlighted(false)
	hovered = found
	if hovered:
		hovered.set_highlighted(true)

func start_interaction(target: Interactable) -> void:
	var footprint := world.get_shape_cells(target.footprint)
	var approach := world.get_perimeter_cells(footprint)
	if not move_to_closest(approach):
		return # no reachable side; keep doing whatever we were doing

	pending = target
	pending_footprint = footprint
	if path.is_empty():
		_on_arrived() # already adjacent, nothing to walk

func clear_pending() -> void:
	pending = null
	pending_footprint = []

func _on_arrived() -> void:
	if pending == null:
		return
	var target := pending
	var footprint := pending_footprint
	clear_pending() # clear first so interact() can start new movement
	face_footprint(footprint)
	if is_instance_valid(target):
		target.interact(self)

func face_footprint(footprint: Array[Vector2i]) -> void:
	for dir in WorldGrid.DIRS:
		if footprint.has(current_tile + dir):
			facing = dir
			return
