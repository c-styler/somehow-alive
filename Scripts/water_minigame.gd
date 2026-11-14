class_name WaterMinigame
extends Control
## Pour gauge: drag the knob up/down the cylinder to set the pour rate.
## Higher pour = faster watering, but above the sweet spot you overpour
## and the overflow meter fills. Fill progress to win, fill overflow to fail.

## reason: &"watered", &"overflow" or &"too_slow"
signal finished(success: bool, reason: StringName)

# --- tuning ---
@export var sweet_center := 0.6 # pour value (0..1) the sweet spot drifts around
@export var sweet_size := 0.2 # height of the sweet spot
@export var zone_drift := 0.12 # how far the sweet spot wanders from its center
@export var zone_drift_speed := 0.6 # how fast it wanders
@export var fill_speed := 0.35 # progress per second at pour = 1
@export var overflow_speed := 0.9 # overflow per second at max overpour
@export var overflow_decay := 0.4 # overflow drained per second when not overpouring
@export var time_limit := 7.0 # seconds; progress must fill before this runs out

# --- resistance: the knob is a bouncy physics body, the mouse pulls it via a loose spring ---
# The spring is deliberately UNDERDAMPED: point straight at the green and the knob
# overshoots into the red. To settle it you must counter-steer (pull the mouse back
# against the knob's motion before it arrives), and keep doing it as wobble pumps energy in.
# Critical damping is 2*sqrt(grip); the further damping is below that, the bouncier.
@export var gravity := 1.0 # constant downward pull; with the spring this means aim a bit above where you want it
@export var grip := 14.0 # spring strength toward the mouse while dragging
@export var damping := 0.8 # velocity loss per second (critical at grip 14 is ~7.5)
@export var wobble_strength := 2.5 # amplitude of the shifting push/pull
@export var wobble_speed := 1.0 # how fast the disturbance changes direction
@export var surge_chance := 0.35 # per second chance of a sudden kick
@export var surge_strength := 1.6 # velocity kick of a surge

# --- layout ---
const BAR_SIZE := Vector2(22, 120)
const KNOB_RADIUS := 13.0
const PROGRESS_WIDTH := 6.0
const GAP := 8.0

# --- palette ---
const CERULEAN := Color("0081A7")
const TEAL := Color("00AFB9")
const CREAM := Color("FDFCDC") # "Light Yellow"
const APRICOT := Color("FED9B7")
const CORAL := Color("F07167") # the Mars one
# additions:
const SKY := Color("8ECAE6") # light blue for the water itself, reads as "water" to kids
const DEEP := Color("0B3C5D") # darkened cerulean for outlines and the cylinder interior;
                              # chunky dark outlines read cartoony and keep the pale colors visible on Mars red
const TIMER_HEIGHT := 5.0
const RESULT_TIME := 1.2 # how long the win/lose banner shows before closing

var pour := 0.0 # 0 = bottom (no water), 1 = top (full blast)
var progress := 0.0
var overflow := 0.0
var dragging := false
var done := false
var time_left := 0.0
var result_text := ""
var result_color := Color.WHITE
var result_age := 0.0 # seconds since the result was decided, drives the banner pop

var target := 0.0 # where the mouse wants the knob
var velocity := 0.0
var time := 0.0
var phases := [randf() * TAU, randf() * TAU, randf() * TAU, randf() * TAU] # so each attempt differs
var sweet_min := 0.0 # current sweet spot, recomputed every frame as it drifts
var sweet_max := 0.0

func _ready() -> void:
	size = Vector2(BAR_SIZE.x + GAP + PROGRESS_WIDTH + KNOB_RADIUS * 2, BAR_SIZE.y + KNOB_RADIUS * 2 + GAP + TIMER_HEIGHT)
	time_left = time_limit
	_update_zone()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100 # lives in the world (child of the Garden), so draw above the player and props
	z_as_relative = false

func _bar_rect() -> Rect2:
	return Rect2(Vector2(KNOB_RADIUS, KNOB_RADIUS), BAR_SIZE)

func _value_to_y(v: float) -> float:
	var r := _bar_rect()
	return r.end.y - v * r.size.y

func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		if dragging:
			_set_pour_from(event.position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_set_pour_from(event.position)
		accept_event()

func _set_pour_from(local_pos: Vector2) -> void:
	var r := _bar_rect()
	target = clampf((r.end.y - local_pos.y) / r.size.y, 0.0, 1.0)

## Smooth pseudo-random push in -1..1: a few out-of-sync sines, so it drifts
## one way for a while, then the other, never quite repeating.
func _wobble() -> float:
	var t := time * wobble_speed
	return (sin(t * 1.3 + phases[0]) * 0.5
		+ sin(t * 2.9 + phases[1]) * 0.3
		+ sin(t * 5.7 + phases[2]) * 0.2)

## Sweet spot slowly wanders, so you can't park the mouse and hold still.
func _update_zone() -> void:
	var t := time * zone_drift_speed
	var offset := (sin(t * 1.1 + phases[3]) * 0.7 + sin(t * 2.3 + phases[0]) * 0.3) * zone_drift
	var center := clampf(sweet_center + offset, sweet_size / 2, 1.0 - sweet_size / 2 - 0.05)
	sweet_min = center - sweet_size / 2
	sweet_max = center + sweet_size / 2

func _update_knob(delta: float) -> void:
	time += delta
	_update_zone()
	var accel := -gravity + _wobble() * wobble_strength
	if dragging:
		accel += (target - pour) * grip
	velocity += accel * delta
	if randf() < surge_chance * delta:
		velocity += randf_range(-1.0, 1.0) * surge_strength
	velocity *= exp(-damping * delta)
	pour += velocity * delta
	# hit the ends of the cylinder
	if pour <= 0.0 or pour >= 1.0:
		pour = clampf(pour, 0.0, 1.0)
		velocity = 0.0

func _process(delta: float) -> void:
	if done:
		result_age += delta
		queue_redraw()
		return

	_update_knob(delta)
	time_left -= delta

	progress += pour * fill_speed * delta

	if pour > sweet_max:
		var over := (pour - sweet_max) / (1.0 - sweet_max) # 0..1 how hard we overpour
		overflow += over * overflow_speed * delta
	else:
		overflow = maxf(0.0, overflow - overflow_decay * delta)

	if overflow >= 1.0:
		_finish(false, &"overflow", "OVERFLOWED!")
	elif progress >= 1.0:
		_finish(true, &"watered", "WATERED!")
	elif time_left <= 0.0:
		_finish(false, &"too_slow", "TOO SLOW!")

	queue_redraw()

func _finish(success: bool, reason: StringName, text: String) -> void:
	done = true
	dragging = false
	progress = minf(progress, 1.0)
	overflow = minf(overflow, 1.0)
	time_left = maxf(time_left, 0.0)
	result_text = text
	result_color = TEAL if success else CORAL
	queue_redraw()
	# let the banner play, then report; the owner frees us on this signal
	await get_tree().create_timer(RESULT_TIME).timeout
	finished.emit(success, reason)

func _draw() -> void:
	var r := _bar_rect()

	var cx := r.get_center().x
	var cap := r.size.x / 2

	# cylinder body (dark interior so the zones pop)
	draw_circle(Vector2(cx, r.position.y), cap + 2, DEEP)
	draw_circle(Vector2(cx, r.end.y), cap + 2, DEEP)
	draw_rect(r.grow(2), DEEP)
	draw_rect(r, CERULEAN.darkened(0.35))
	# zones: overpour (top) and sweet spot, as solid bright bands
	var red_top := _value_to_y(1.0)
	var sweet_top := _value_to_y(sweet_max)
	var sweet_bot := _value_to_y(sweet_min)
	draw_rect(Rect2(r.position.x, red_top, r.size.x, sweet_top - red_top), CORAL)
	draw_circle(Vector2(cx, r.position.y), cap, CORAL) # top cap belongs to the danger zone
	draw_rect(Rect2(r.position.x, sweet_top, r.size.x, sweet_bot - sweet_top), TEAL)
	draw_circle(Vector2(cx, r.end.y), cap, CERULEAN.darkened(0.35))
	# glass shine down the left side
	draw_line(Vector2(r.position.x + 4, r.position.y + 2), Vector2(r.position.x + 4, r.end.y - 2), Color(CREAM, 0.35), 3.0)

	# marker where the mouse is pulling, so the lag is readable
	if dragging:
		var ty := _value_to_y(target)
		draw_line(Vector2(r.position.x - 5, ty), Vector2(r.end.x + 5, ty), Color(CREAM, 0.6), 3.0)

	# knob: cream, warming to apricot then coral as overflow builds
	var knob_color := CREAM.lerp(APRICOT, clampf(overflow * 2.0, 0.0, 1.0)).lerp(CORAL, clampf(overflow * 2.0 - 1.0, 0.0, 1.0))
	var knob_pos := Vector2(cx, _value_to_y(pour))
	draw_circle(knob_pos, KNOB_RADIUS, knob_color)
	draw_circle(knob_pos + Vector2(-4, -4), KNOB_RADIUS * 0.3, Color.WHITE) # highlight dot
	draw_circle(knob_pos, KNOB_RADIUS, DEEP, false, 3.0)

	# progress meter: sky-blue water filling a tube
	var p := Rect2(r.end.x + GAP + KNOB_RADIUS, r.position.y, PROGRESS_WIDTH, r.size.y)
	draw_rect(p.grow(2), DEEP)
	draw_rect(p, CERULEAN.darkened(0.35))
	var fill_h := p.size.y * progress
	draw_rect(Rect2(p.position.x, p.end.y - fill_h, p.size.x, fill_h), SKY)

	# time bar: apricot, turning coral in the last half
	var t := Rect2(0, size.y - TIMER_HEIGHT, size.x, TIMER_HEIGHT)
	var frac := clampf(time_left / time_limit, 0.0, 1.0)
	var time_color := CORAL.lerp(APRICOT, clampf(frac * 2.0, 0.0, 1.0))
	draw_rect(t.grow(2), DEEP)
	draw_rect(t, CERULEAN.darkened(0.35))
	draw_rect(Rect2(t.position, Vector2(t.size.x * frac, t.size.y)), time_color)

	if result_text != "":
		_draw_result()

func _draw_result() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 22
	# pop: overshoot scale on appear, then settle
	var pop := 1.0 + 0.5 * exp(-result_age * 8.0) * cos(result_age * 20.0)
	var text_size := font.get_string_size(result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var center := Vector2(size.x / 2, -18 - result_age * 10.0) # drifts up a bit
	draw_set_transform(center, 0.0, Vector2(pop, pop))
	var origin := Vector2(-text_size.x / 2, text_size.y / 4)
	draw_string_outline(font, origin, result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, DEEP)
	draw_string(font, origin, result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, result_color)
	draw_set_transform(Vector2.ZERO)
