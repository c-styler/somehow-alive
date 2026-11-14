class_name Interactable
extends Node2D

## Emitted when this interactable finishes the task named by task_id.
## World listens to every Interactable, so these never need to know about World.
signal task_completed(task_id: StringName)
## Ask World to play one of Orbi's conversations (an id in Dialogues.ALL).
signal dialogue_requested(dialogue_id: StringName)
## Ask World to do something game-wide (e.g. &"sleep"), since that's World's business.
signal action_requested(action: StringName, source: Interactable)

@export var hitbox: Area2D
@export var footprint: CollisionShape2D
@export var task_id: StringName # must match a key in World.TASKS; empty = not a task

@export_group("Indicator")
@export var show_indicator := true
@export var indicator_offset := Vector2.ZERO # nudge from the auto position (top of the footprint)

const highlight_color := Color(1.3, 1.4, 1.6)

var indicator: InteractIndicator

func _ready() -> void:
	indicator = InteractIndicator.new()
	add_child(indicator)
	indicator.position = _indicator_anchor() + indicator_offset
	indicator.visible = show_indicator
	# a finished task no longer needs calling out
	task_completed.connect(func(_id): set_indicator_visible(false))

func set_highlighted(on: bool) -> void:
	modulate = highlight_color if on else Color.WHITE
	if indicator:
		indicator.hovered = on

## Subclasses hide this while busy (e.g. a minigame is open) and show it again after.
func set_indicator_visible(on: bool) -> void:
	if indicator:
		indicator.visible = on and show_indicator

func interact(player: Player) -> void:
	print("interacted with ", name)

## Just above the top edge of the footprint shape, centered on it.
func _indicator_anchor() -> Vector2:
	if footprint == null or not footprint.shape is RectangleShape2D:
		return Vector2(0, -40)
	var top_center := footprint.global_position - Vector2(0, footprint.shape.size.y / 2 * footprint.global_scale.y)
	return to_local(top_center) + Vector2(0, -22)


## Floating speech-bubble "!" that bobs above an interactable; grows when hovered.
class InteractIndicator extends Node2D:
	const TEAL := Color("00AFB9")
	const CREAM := Color("FDFCDC")
	const DEEP := Color("0B3C5D")
	const RADIUS := 11.0

	var hovered := false
	var time := randf() * TAU # desync multiple indicators
	var current_scale := 1.0

	func _ready() -> void:
		z_index = 50 # above world sprites
		# ignore lights so it doesn't vanish in the dark
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		time += delta
		var target := 1.3 if hovered else 1.0
		current_scale = lerpf(current_scale, target, 1.0 - exp(-12.0 * delta))
		queue_redraw()

	func _draw() -> void:
		var bob := sin(time * 3.0) * 3.0
		var pulse := 1.0 + sin(time * 6.0) * 0.04 # gentle "breathing"
		draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE * current_scale * pulse)

		# outline first (slightly larger), then fill: bubble + little tail pointing down
		var tail := PackedVector2Array([Vector2(-5, RADIUS - 3), Vector2(5, RADIUS - 3), Vector2(0, RADIUS + 7)])
		var tail_outline := PackedVector2Array([Vector2(-7.5, RADIUS - 3), Vector2(7.5, RADIUS - 3), Vector2(0, RADIUS + 10)])
		draw_colored_polygon(tail_outline, DEEP)
		draw_circle(Vector2.ZERO, RADIUS + 2.5, DEEP)
		draw_colored_polygon(tail, TEAL)
		draw_circle(Vector2.ZERO, RADIUS, TEAL)

		# "!" drawn as shapes so it doesn't depend on a font
		draw_line(Vector2(0, -6), Vector2(0, 2), CREAM, 3.5, true)
		draw_circle(Vector2(0, 6), 2.0, CREAM)

		draw_set_transform(Vector2.ZERO)
