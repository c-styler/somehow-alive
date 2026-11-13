class_name Interactable
extends Node2D

@export var hitbox: Area2D
@export var footprint: CollisionShape2D

const highlight_color := Color(1.3, 1.4, 1.6)

func set_highlighted(on: bool) -> void:
	modulate = highlight_color if on else Color.WHITE

func interact(player: Player) -> void:
	print("interacted with ", name)
