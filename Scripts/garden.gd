extends Interactable

const MINIGAME_GAP := 24.0 # px between the racks and the gauge
const SCREEN_MARGIN := 16.0 # keep the gauge at least this far inside the screen edge

var minigame: WaterMinigame
var minigame_layer: CanvasLayer

func interact(player: Player) -> void:
	if minigame:
		return
	player.input_locked = true
	set_indicator_visible(false)

	# Own canvas layer that follows the camera: it sits in world space above the garden,
	# but lights and the day/night CanvasModulate only affect the main canvas, so the
	# gauge keeps its real colors. Layer 2 = above the world, below the HUD (3).
	minigame_layer = CanvasLayer.new()
	minigame_layer.layer = 2
	minigame_layer.follow_viewport_enabled = true
	add_child(minigame_layer)

	minigame = WaterMinigame.new()
	minigame_layer.add_child(minigame)
	minigame.finished.connect(_on_minigame_finished.bind(player))
	_place_minigame()

func _process(_delta: float) -> void:
	if minigame:
		_place_minigame() # camera zoom can still be easing, keep it on screen

## Beside the racks (on the side away from the player), vertically centered on them,
## then nudged so the whole gauge stays inside the screen at any zoom.
func _place_minigame() -> void:
	var half := Vector2(115, 92) # half the racks' size
	if footprint and footprint.shape is RectangleShape2D:
		half = footprint.shape.size / 2 * footprint.global_scale
	var player_left := get_viewport().get_camera_2d() != null and get_viewport().get_camera_2d().global_position.x < global_position.x
	var side := 1.0 if player_left else -1.0
	var size := minigame.size
	var pos := global_position + Vector2(side * (half.x + MINIGAME_GAP) + (0.0 if side > 0 else -size.x), -size.y / 2)
	# clamp in screen space
	var xf := get_viewport().get_canvas_transform()
	var screen := get_viewport().get_visible_rect().size
	var tl := xf * pos
	var br := xf * (pos + size)
	var shift := Vector2.ZERO
	if tl.x < SCREEN_MARGIN: shift.x = SCREEN_MARGIN - tl.x
	elif br.x > screen.x - SCREEN_MARGIN: shift.x = screen.x - SCREEN_MARGIN - br.x
	if tl.y < SCREEN_MARGIN: shift.y = SCREEN_MARGIN - tl.y
	elif br.y > screen.y - SCREEN_MARGIN: shift.y = screen.y - SCREEN_MARGIN - br.y
	minigame.position = pos + shift / xf.get_scale()

func _on_minigame_finished(success: bool, reason: StringName, player: Player) -> void:
	player.input_locked = false
	if success:
		if task_id != &"":
			task_completed.emit(task_id)
	else:
		set_indicator_visible(true) # still needs doing
		# Orbi reacts to how it went wrong: water_garden_overflow / water_garden_too_slow
		dialogue_requested.emit(StringName("%s_%s" % [task_id, reason]))
	# the minigame already held its win/lose banner before emitting
	minigame_layer.queue_free() # frees the gauge with it
	minigame_layer = null
	minigame = null
