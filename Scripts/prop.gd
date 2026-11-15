class_name Prop
extends Sprite2D
## A piece of furniture/decoration. With `blocks` on, WorldGrid marks every cell whose
## center lies under the sprite as solid when the level loads (so beds, desks, lockers
## block movement), while small stuff on top of things (lamps, monitors, rugs) can
## leave it off.

@export var blocks := true
## How far (px) the blocking area reaches past the sprite's edges. Default -6 means a
## sprite that only just touches a cell doesn't block it; raise it for small props that
## sit on a tile without covering its center.
@export var block_grow := -6.0

func _enter_tree() -> void:
	add_to_group("furniture") # LockedRoom hides furniture inside sealed rooms
	if blocks:
		add_to_group("props") # read by WorldGrid._ready

## The sprite's rectangle in global space, shrunk a little so a sprite that just
## touches a neighbouring cell doesn't block it.
func get_block_rect() -> Rect2:
	return (global_transform * get_rect()).grow(block_grow)
