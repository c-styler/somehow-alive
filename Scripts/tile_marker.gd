extends Node2D

@export var world: WorldGrid
@export var player: Node # whatever your player type is
@export var color := Color(1, 1, 1, 0.9)

var tween: Tween

func _ready() -> void:
	visible = false

func _draw() -> void:
	var half := Vector2(world.astar.cell_size) / 2.0
	print(half)
	draw_rect(Rect2(-half, half * 2.0), color, false, 2.0)

func _on_astronaut_destination_set(cell: Vector2i) -> void:
	global_position = world.cell_to_world(cell)
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE * 1.2

	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.24) # quick "pop" inward
	tween.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.50)
	tween.tween_callback(hide)
