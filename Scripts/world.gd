extends Node2D

signal hour_changed(hour: int)
signal day_passed(day: int)

@export var hud: HUD
@export var mars_ambient: AudioStreamPlayer2D
@export var canvas_modulate: CanvasModulate

@export_group("Day Night Cycle")
@export var start_hour := 5.0
@export var time_scale := 30.0 # set to ~30 to debug a full day quickly
@export var day_gradient: Gradient # x=0 is midnight, x=1 is next midnight

# 1 game hour = 30 real seconds -> 24h day = 720s
const REAL_SECONDS_PER_GAME_HOUR := 30.0
const HOURS_PER_DAY := 24.0

var game_hour := 0.0 # 0..24
var day := 1
var _last_hour_int := -1


func _ready() -> void:
	mars_ambient.play()

	game_hour = start_hour
	if day_gradient == null:
		day_gradient = _make_default_gradient()
	_update_modulate()


func _process(delta: float) -> void:
	_advance_time(delta)
	_update_modulate()

	hud.set_time_text(get_time_string())
	game_hour = start_hour


func _advance_time(delta: float) -> void:
	game_hour += (delta * time_scale) / REAL_SECONDS_PER_GAME_HOUR

	if game_hour >= HOURS_PER_DAY:
		game_hour = fmod(game_hour, HOURS_PER_DAY)
		day += 1
		day_passed.emit(day)

	var h := int(game_hour)
	if h != _last_hour_int:
		_last_hour_int = h
		hour_changed.emit(h)


func _update_modulate() -> void:
	canvas_modulate.color = day_gradient.sample(game_hour / HOURS_PER_DAY)


func get_time_string() -> String:
	var h := int(game_hour)
	var m := int((game_hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func is_night() -> bool:
	return game_hour < 6.0 or game_hour >= 19.0


func _make_default_gradient() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.30, 0.5, 0.75, 0.80, 1.0])
	g.colors = PackedColorArray([
		Color(0.10, 0.12, 0.25), # 00:00 night
		Color(0.10, 0.12, 0.25), # 06:00 still night
		Color(1.0, 0.85, 0.75), # 07:12 dawn
		Color(1.0, 1.0, 1.0), # 12:00 midday
		Color(1.0, 0.85, 0.75), # 18:00 dusk
		Color(0.10, 0.12, 0.25), # 19:12 night
		Color(0.10, 0.12, 0.25), # 24:00 night
	])
	return g


func _on_base_area_body_entered(body: Node2D) -> void:
	if body is Player:
		hud.set_location_text("BASE", Color.LIGHT_BLUE)


func _on_base_area_body_exited(body: Node2D) -> void:
	if body is Player:
		hud.set_location_text("OUTSIDE", Color("#c1440e"))
