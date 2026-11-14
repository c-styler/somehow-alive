@tool
class_name GroundShadow
extends Node2D
## Soft flattened ellipse on the ground under a character.
## Place it before the sprite in the tree so it draws underneath.

@export var radius := 22.0:
	set(v):
		radius = v
		queue_redraw()
@export_range(0.1, 1.0) var squash := 0.4: # height / width of the ellipse
	set(v):
		squash = v
		queue_redraw()
@export var color := Color(0, 0, 0, 0.3):
	set(v):
		color = v
		queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, color)
