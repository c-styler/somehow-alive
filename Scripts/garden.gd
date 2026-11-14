extends Interactable

const MINIGAME_OFFSET := Vector2(0, -90) # above the plants, relative to Garden origin

var minigame: WaterMinigame
var minigame_layer: CanvasLayer

func interact(player: Player) -> void:
	if minigame:
		return
	player.input_locked = true
	set_indicator_visible(false) # the gauge sits where the indicator is

	# Own canvas layer that follows the camera: it sits in world space above the garden,
	# but lights and the day/night CanvasModulate only affect the main canvas, so the
	# gauge keeps its real colors. Layer 2 = above the world, below the HUD (3).
	minigame_layer = CanvasLayer.new()
	minigame_layer.layer = 2
	minigame_layer.follow_viewport_enabled = true
	add_child(minigame_layer)

	minigame = WaterMinigame.new()
	minigame_layer.add_child(minigame)
	# center the gauge horizontally, bottom edge at the offset (in world coordinates)
	minigame.position = to_global(MINIGAME_OFFSET) - Vector2(minigame.size.x / 2, minigame.size.y)
	minigame.finished.connect(_on_minigame_finished.bind(player))

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
