class_name OrbiCompanion
extends Node2D
## Orbi floating around the player. Free (non-tile) movement; the tile grid is only used
## to plan around walls:
##  - clear straight line to the goal -> fly straight at it
##  - otherwise -> A* over tiles, then "string-pull" (skip waypoints he can already see)
##    so the route looks smooth instead of tile-by-tile.
## Behaviour is a tiny state machine: FOLLOW -> IDLE -> (maybe) WANDER -> IDLE ...,
## with a leash that always yanks him back to FOLLOW if he drifts too far.

enum State { FOLLOW, IDLE, WANDER }

const MOODS := {
	"neutral": "res://Assets/Orbi/orbi.png",
	"happy": "res://Assets/Orbi/orbi_happy.png",
	"sad": "res://Assets/Orbi/orbi_sad.png",
	"anger": "res://Assets/Orbi/orbi_anger.png",
}

@export var player: Player
@export var world: WorldGrid

@export_group("Movement")
@export var speed := 110.0 # cruising px/s
@export var catch_up_speed := 220.0 # used when he's past the leash
@export var acceleration := 400.0 # px/s^2, lower = floatier turns
@export var body_radius := 12.0 # how wide he is for wall checks

@export_group("Behaviour")
@export var follow_distance := 80.0 # how far beside the player he likes to hover
@export var leash := 260.0 # beyond this from the player he drops everything and comes back
@export var wander_radius := 170.0 # how far from the player he'll go exploring
@export var wander_chance := 0.45 # chance, after idling, to go explore instead of idling again
@export var idle_time := Vector2(1.5, 3.5) # min/max seconds of hovering in place
@export var linger_time := Vector2(1.0, 2.5) # min/max seconds of "looking around" at a wander spot

@export_group("Look")
@export var hover_height := 34.0 # how high the sprite floats above his shadow/position
@export var bob_height := 5.0
@export var bob_speed := 2.4
@export var art_faces_left := false # flip this if he moves "backwards"

var state := State.FOLLOW
var goal := Vector2.ZERO
var waypoints: PackedVector2Array = []
var velocity := Vector2.ZERO
var state_timer := 0.0
var replan_timer := 0.0
var side := 1.0 # which side of the player he prefers (-1 left, 1 right)
var time := 0.0
var look_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
var shadow: GroundShadow

func _ready() -> void:
	shadow = GroundShadow.new()
	shadow.radius = 16.0
	add_child(shadow)
	move_child(shadow, 0) # under the sprite
	z_index = 10 # floats above the player and props
	side = [-1.0, 1.0].pick_random()
	if player:
		global_position = player.global_position + Vector2(side * follow_distance, -20)
	_enter(State.FOLLOW)

## Jump straight to the player (e.g. after a teleport) instead of flying across the map.
func snap_to_player() -> void:
	global_position = player.global_position + Vector2(side * follow_distance, -20)
	velocity = Vector2.ZERO
	waypoints = PackedVector2Array()
	_enter(State.IDLE)

func set_mood(mood: String) -> void:
	sprite.texture = load(MOODS.get(mood, MOODS.neutral))

# --- state machine ---

func _enter(new_state: State) -> void:
	state = new_state
	match state:
		State.FOLLOW:
			_set_goal(_follow_slot())
		State.IDLE:
			state_timer = randf_range(idle_time.x, idle_time.y)
		State.WANDER:
			_set_goal(_pick_wander_spot())
			state_timer = randf_range(linger_time.x, linger_time.y)

func _process(delta: float) -> void:
	if player == null or world == null:
		return
	time += delta

	var to_player := player.global_position - global_position
	if to_player.length() > leash and state != State.FOLLOW:
		_enter(State.FOLLOW)

	match state:
		State.FOLLOW:
			replan_timer -= delta
			if replan_timer <= 0.0:
				_set_goal(_follow_slot()) # player keeps moving, keep re-aiming
			if _arrived() and to_player.length() < follow_distance * 1.8:
				_enter(State.IDLE)
		State.IDLE:
			# drift along if the player walked off
			if to_player.length() > follow_distance * 2.5:
				_enter(State.FOLLOW)
			else:
				state_timer -= delta
				if state_timer <= 0.0:
					if randf() < wander_chance:
						_enter(State.WANDER)
					else:
						_enter(State.IDLE)
		State.WANDER:
			if _arrived():
				state_timer -= delta # lingering, "looking around"
				_look_around(delta)
				if state_timer <= 0.0:
					_enter(State.FOLLOW)

	_steer(delta)
	_animate()

func _follow_slot() -> Vector2:
	# hover beside and slightly above the player; switch sides if that spot is in a wall
	var slot := player.global_position + Vector2(side * follow_distance, -20)
	if world.is_solid(world.world_to_cell(slot)):
		side = -side
		slot = player.global_position + Vector2(side * follow_distance, -20)
		if world.is_solid(world.world_to_cell(slot)):
			slot = player.global_position + Vector2(0, -20)
	return slot

func _pick_wander_spot() -> Vector2:
	for i in 12:
		var p := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(wander_radius * 0.4, wander_radius)
		if not world.is_solid(world.world_to_cell(p)):
			return p
	return _follow_slot()

func _look_around(delta: float) -> void:
	# flip which way he faces now and then, like he's checking things out
	look_timer -= delta
	if look_timer <= 0.0:
		look_timer = randf_range(0.5, 1.2)
		sprite.flip_h = not sprite.flip_h

# --- pathing ---

func _set_goal(p: Vector2) -> void:
	goal = p
	replan_timer = 0.4
	if _clear_line(global_position, goal):
		waypoints = PackedVector2Array([goal])
		return
	var start := _nearest_free_cell(world.world_to_cell(global_position))
	var end := _nearest_free_cell(world.world_to_cell(goal))
	var cells := world.get_path_cells(start, end)
	if cells.is_empty():
		waypoints = PackedVector2Array() # unreachable: just hover where he is
		return
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(world.cell_to_world(c))
	pts[pts.size() - 1] = goal if not world.is_solid(world.world_to_cell(goal)) else pts[pts.size() - 1]
	waypoints = _string_pull(pts)

## Drops waypoints that can be skipped with a clear straight line, so he cuts corners
## smoothly instead of zig-zagging through tile centers.
func _string_pull(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var from := global_position
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not _clear_line(from, pts[j]):
			j -= 1
		out.append(pts[j])
		from = pts[j]
		i = j + 1
	return out

## True if a body of body_radius can fly from a to b without touching a solid tile.
func _clear_line(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var length := d.length()
	if length < 1.0:
		return true
	var normal := d.orthogonal().normalized() * body_radius
	var steps := int(ceil(length / 8.0))
	for s in steps + 1:
		var p := a + d * (float(s) / steps)
		for o in [Vector2.ZERO, normal, -normal]:
			if world.is_solid(world.world_to_cell(p + o)):
				return false
	return true

func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	if not world.is_solid(cell):
		return cell
	for r in range(1, 4):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var c := cell + Vector2i(x, y)
				if not world.is_solid(c):
					return c
	return cell

func _arrived() -> bool:
	return waypoints.is_empty()

func _steer(delta: float) -> void:
	var desired := Vector2.ZERO
	if not waypoints.is_empty():
		var target := waypoints[0]
		var to := target - global_position
		var last := waypoints.size() == 1
		if to.length() < (6.0 if last else 20.0):
			waypoints.remove_at(0)
		else:
			var max_speed := catch_up_speed if (player.global_position - global_position).length() > leash * 0.8 else speed
			# ease in on the final point so he settles instead of overshooting
			var arrive := clampf(to.length() / 60.0, 0.2, 1.0) if last else 1.0
			desired = to.normalized() * max_speed * arrive
	velocity = velocity.move_toward(desired, acceleration * delta)

	# never enter a solid tile; slide along walls if a step would
	var next := global_position + velocity * delta
	if world.is_solid(world.world_to_cell(next)):
		var slide_x := global_position + Vector2(velocity.x * delta, 0)
		var slide_y := global_position + Vector2(0, velocity.y * delta)
		if not world.is_solid(world.world_to_cell(slide_x)):
			next = slide_x
			velocity.y = 0
		elif not world.is_solid(world.world_to_cell(slide_y)):
			next = slide_y
			velocity.x = 0
		else:
			next = global_position
			velocity = Vector2.ZERO
	global_position = next

func _animate() -> void:
	# hover above his shadow; rounded to whole pixels so the pixel art doesn't shimmer
	sprite.position.y = roundf(-hover_height + sin(time * bob_speed) * bob_height)
	sprite.rotation = clampf(velocity.x / speed, -1.0, 1.0) * 0.12 # lean into movement
	shadow.scale = Vector2.ONE * (1.0 - sin(time * bob_speed) * 0.12) # shadow breathes with the bob
	if not _arrived() and absf(velocity.x) > 15.0:
		_face(velocity.x < 0)
	elif state == State.IDLE:
		_face(player.global_position.x < global_position.x) # idle: look at the player
	# lingering at a wander spot: _look_around() flips him back and forth

func _face(left: bool) -> void:
	sprite.flip_h = left != art_faces_left
