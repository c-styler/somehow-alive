class_name HUD
extends CanvasLayer

@export var location: Label
@export var time_text: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_location_text(text: String, color: Color) -> void:
	location.text = text
	location.modulate = color

func set_time_text(time: String) -> void:
	time_text.text = "HOUR " + str(time)
