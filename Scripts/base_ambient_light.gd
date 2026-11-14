class_name BaseAmbientLight
extends Node2D
## Lights the whole interior of the base evenly, shaped exactly like the base outline,
## so nothing leaks onto the Mars ground outside. It builds a mask texture from a
## polygon (the BaseArea's CollisionPolygon2D) and uses it as a PointLight2D texture.
## World tints it via the "base_lights" group, same as the LED fixtures.

@export var area: CollisionPolygon2D # the base outline
@export var resolution := 8.0 # world px per mask px; lower = sharper edge, bigger texture
@export var energy_scale := 1.0 # multiplies the energy World sends
@export var edge_softness := 1 # mask px of feathering at the edge (0 = hard)

var light: PointLight2D

func _ready() -> void:
	add_to_group("base_lights")
	if area == null:
		push_warning("BaseAmbientLight: no area polygon set")
		return
	light = PointLight2D.new()
	light.shadow_enabled = false # walls are inside the mask anyway
	add_child(light)
	_build()

func set_lighting(c: Color, energy: float) -> void:
	if light:
		light.color = c
		light.energy = energy * energy_scale

func _build() -> void:
	# polygon in global space
	var xf := area.global_transform
	var poly := PackedVector2Array()
	for p in area.polygon:
		poly.append(xf * p)
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bounds = bounds.expand(p)
	bounds = bounds.grow(resolution * 2) # room for the soft edge

	var w := int(ceil(bounds.size.x / resolution))
	var h := int(ceil(bounds.size.y / resolution))
	var img := Image.create(w, h, false, Image.FORMAT_LA8)
	for y in h:
		for x in w:
			var world_p := bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * resolution
			if Geometry2D.is_point_in_polygon(world_p, poly):
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	# cheap feather: shrink then grow back with bilinear filtering
	for i in edge_softness:
		img.resize(maxi(1, w / 2), maxi(1, h / 2), Image.INTERPOLATE_BILINEAR)
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)

	light.texture = ImageTexture.create_from_image(img)
	light.texture_scale = resolution
	light.global_position = bounds.get_center()
