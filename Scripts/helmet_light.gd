extends PointLight2D

@export var astronaut: Player
@export var circle_light: PointLight2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	enabled = false
	texture = make_cone_texture(512, 45.0, 4.0)

	var dir := Vector2(astronaut.facing)
	if dir != Vector2.ZERO:
		rotation = dir.angle() - PI / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("helmet_light"):
		enabled = !enabled
		circle_light.enabled = enabled

	var dir := Vector2(astronaut.facing)
	if dir != Vector2.ZERO:
		rotation = lerp_angle(rotation, dir.angle() - PI / 2, 12.0 * delta)

static func make_cone_texture(size: int, half_angle_deg: float, falloff: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	var center := Vector2(size, size) / 2.0
	var radius := size / 2.0
	var half := deg_to_rad(half_angle_deg)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var dist := p.length() / radius
			if dist >= 1.0:
				continue
			# 0 = pointing right, so rotation = facing.angle() with no offset
			var ang := absf(p.angle() - PI / 2)
			var angle_factor := 1.0 - smoothstep(half * 0.3, half, ang)
			var dist_factor := pow(1.0 - dist, falloff)
			var v := angle_factor * dist_factor
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)
