class_name ZoomCamera
extends Camera2D
## Zooms based on the floor tile under the player: wide in the corridor (base_floor),
## close in rooms (base_floor2), in between outside. Lerps smoothly between them.
## Since it reads the tile source, repainting floors in the editor is all it takes
## to change where the camera zooms.

@export var tile_map: TileMapLayer
@export var target: Node2D # whose position decides the zoom (the astronaut)

@export var corridor_sources: Array[int] = [4] # base_floor.png
@export var room_sources: Array[int] = [11] # base_floor2.png

@export var corridor_zoom := 0.55 # smaller = more zoomed out
@export var room_zoom := 0.85
@export var default_zoom := 0.7 # outside / anything else
@export var zoom_speed := 3.0 # higher = snappier transitions

var _target_zoom := 0.7

func _ready() -> void:
	if target == null:
		target = get_parent() as Node2D
	_target_zoom = _zoom_for_current_tile()
	zoom = Vector2.ONE * _target_zoom

func _process(delta: float) -> void:
	_target_zoom = _zoom_for_current_tile()
	var z := lerpf(zoom.x, _target_zoom, 1.0 - exp(-zoom_speed * delta))
	zoom = Vector2(z, z)

func _zoom_for_current_tile() -> float:
	if tile_map == null or target == null:
		return default_zoom
	var cell := tile_map.local_to_map(tile_map.to_local(target.global_position))
	var source := tile_map.get_cell_source_id(cell)
	if source in corridor_sources:
		return corridor_zoom
	if source in room_sources:
		return room_zoom
	return default_zoom
