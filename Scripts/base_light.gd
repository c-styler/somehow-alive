@tool
class_name BaseLight
extends Node2D
## Wall-mounted LED strip: the visible "source" of the base lighting. The room itself is
## lit by BaseAmbientLight; this adds the fixture plus a small local glow around it.
## World drives color/energy for every light in the "base_lights" group from the clock,
## so day = cool white, night = warm. Place the node on a wall face; the light itself
## sits a little in front of it (light_offset) so the wall's occluder doesn't swallow it.

@export var strip_length := 44.0:
	set(v):
		strip_length = v
		queue_redraw()
@export var vertical := false: # true for strips on left/right walls
	set(v):
		vertical = v
		queue_redraw()
@export var light_offset := Vector2(0, 12) # from the fixture into the room
@export var light_range := 0.9 # PointLight2D texture_scale; 1.0 ~ 256px across
@export var cast_shadows := false # on a wall face, shadows would mostly black it out
@export var energy_scale := 0.8 # multiplies the energy World sends

@export_group("Special Fixtures")
## Off = a fixed-color fixture (e.g. a grow light) that ignores the day/night cycle.
@export var follow_world := true
@export var fixed_color := Color(0.75, 0.2, 1.0):
	set(v):
		fixed_color = v
		if not follow_world:
			color = v
		queue_redraw()
## Draws alternating red/blue diodes, like real plant grow lights.
@export var grow_diodes := false:
	set(v):
		grow_diodes = v
		queue_redraw()
## Off = fixture only, for when a separate light (like GardenLight) does the lighting.
@export var emit_light := true

var color := Color(0.92, 0.96, 1.0) # set by World
var light: PointLight2D

func _ready() -> void:
	if follow_world:
		add_to_group("base_lights")
	else:
		color = fixed_color
	if Engine.is_editor_hint() or not emit_light:
		return
	light = PointLight2D.new()
	light.texture = _radial_texture()
	light.texture_scale = light_range
	light.position = light_offset
	light.shadow_enabled = cast_shadows
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 2.0
	add_child(light)
	set_lighting(color, 1.0)

## Called by World every frame via call_group.
func set_lighting(c: Color, energy: float) -> void:
	color = c
	if light:
		light.color = c
		light.energy = energy * energy_scale
	queue_redraw()

func _draw() -> void:
	var half := Vector2(strip_length / 2, 3) if not vertical else Vector2(3, strip_length / 2)
	var body := Rect2(-half - Vector2(3, 3), (half + Vector2(3, 3)) * 2)
	# soft glow halo
	for i in 3:
		var g := body.grow(4 + i * 4)
		draw_rect(g, Color(color, 0.12 - i * 0.03))
	# housing, then the bright diode strip
	draw_rect(body, Color("2a3440"))
	draw_rect(Rect2(-half, half * 2), color.lightened(0.35))
	# individual LED dots for a bit of texture
	var count := int(strip_length / 8)
	for i in count:
		var t := (i + 0.5) / count
		var p := Vector2(lerpf(-half.x, half.x, t), 0) if not vertical else Vector2(0, lerpf(-half.y, half.y, t))
		var dot := Color.WHITE
		if grow_diodes:
			dot = Color("ff3a6a") if i % 2 == 0 else Color("4a6bff")
		draw_circle(p, 1.5, dot)

func _radial_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t
