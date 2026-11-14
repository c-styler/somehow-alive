extends Interactable
## A solar panel outside the base. Only the one marked `is_repair_point` opens the repair
## minigame (the others are part of the array, just furniture that blocks movement).

@export var is_repair_point := false

@export var dust_fade_time := 1.5 # seconds for dust to appear/clear

var minigame: SolarMinigame
var dust := 0.0
var _dust_mat: ShaderMaterial

func _ready() -> void:
	if not is_repair_point:
		show_indicator = false
		if hitbox:
			hitbox.collision_layer = 0 # not hoverable/clickable
	super()
	_setup_dust()

func _setup_dust() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = randi() # each panel gets its own dust pattern
	noise.frequency = 0.15
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 48
	tex.height = 48
	tex.seamless = true
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = preload("res://Scripts/dusty.gdshader")
	_dust_mat.set_shader_parameter("noise_tex", tex)
	if sprite.texture:
		_dust_mat.set_shader_parameter("pixels", sprite.texture.get_size())
	sprite.material = _dust_mat

## Dusty while the repair is needed. The whole array follows the repair point,
## so all three panels get covered and cleaned together.
func _process(delta: float) -> void:
	if _dust_mat == null:
		return
	var target := 1.0 if _needs_cleaning() else 0.0
	dust = move_toward(dust, target, delta / dust_fade_time)
	_dust_mat.set_shader_parameter("dust", dust)

func _needs_cleaning() -> bool:
	if is_repair_point:
		return task_available
	for sibling in get_parent().get_children():
		if sibling != self and sibling is Interactable and sibling.get("is_repair_point"):
			return sibling.task_available
	return false

func interact(player: Player) -> void:
	if not is_repair_point or minigame:
		return
	if not task_available:
		dialogue_requested.emit(&"solar_ok") # nothing to fix today
		return
	player.input_locked = true
	set_indicator_visible(false)
	minigame = SolarMinigame.new()
	get_tree().root.add_child(minigame)
	minigame.finished.connect(_on_minigame_finished.bind(player))

func _on_minigame_finished(success: bool, player: Player) -> void:
	minigame = null
	player.input_locked = false
	if success:
		task_completed.emit(task_id)
	else:
		set_indicator_visible(true) # closed early, still needs doing
