extends Node2D

signal hour_changed(hour: int)
signal day_passed(day: int)
signal task_done(task_id: StringName)

## Every task in the game: id -> checklist text. Interactables reference these ids via task_id.
const TASKS := {
	&"fix_solar": "Fix the solar panels",
	&"water_garden": "Water the garden",
	&"window_selfie": "Take a sunset selfie",
	&"sleep": "Go to sleep",
}
## Tasks that only appear (in the HUD, with their "!" marker) once these are done.
## Requirements that aren't on today's list are ignored.
const TASK_REQUIRES := {
	&"fix_solar": [&"water_garden"], # power drops in the afternoon, after the watering
	&"window_selfie": [&"fix_solar"], # once the power's back, it's sunset
	&"sleep": [&"water_garden", &"fix_solar", &"window_selfie"],
}
## Tasks that only exist on certain days (missing = every day).
const TASK_DAYS := {
	&"fix_solar": [1],
	&"window_selfie": [1],
}
## Urgent tasks: shown in coral, and Orbi calls you over (TASK_INTROS) as soon as they appear.
const TASK_URGENT := [&"fix_solar"]
## Orbi dialogue played when a task first shows up on the list.
const TASK_INTROS := {
	&"fix_solar": &"fix_solar_intro",
	&"window_selfie": &"window_selfie_intro",
}
var completed_tasks := {} # task_id -> true
var _pending_intros: Array[StringName] = []
var _shown_tasks := {} # task_id -> true, already added to the HUD
var _interactables: Array[Interactable] = []
var _sleeping := false

@export_group("Sleep")
@export var wake_hour := 6.0
@export var sleep_fade_time := 1.2
@export var sleep_hold_time := 1.5 # seconds of black "night" before waking
@export_group("") # end of group, so the exports below stay ungrouped

var orbi_dialog: OrbiDialog

@export var hud: HUD
@export var mars_ambient: AudioStreamPlayer2D
@export var canvas_modulate: CanvasModulate
@export var player: Player
@export var grid: WorldGrid

@export_group("World Border")
## After a border touch, you have to step this many cells back in before the next
## touch counts (1st touch = Orbi's warning, 2nd = he takes you home).
@export var border_rearm_cells := 2
## Being taken home fades the screen and puts you back at base, this much later.
@export var border_time_skip_minutes := 3.0
@export var border_fade_time := 0.6
@export var orbi: OrbiCompanion
var _border_armed := true
var _border_warned := false # Orbi already warned once; the next touch sends you home
var _returning := false
var _base_spawn_cell: Vector2i
var _fade: ColorRect

@export_group("Outfits")
## Floor tile sources that count as "inside the base" (corridor + rooms). Walking from
## these onto anything else (the Mars ground) puts the spacesuit on, and back off again.
@export var indoor_sources: Array[int] = [4, 11]
@export var outfit_fade_time := 0.3 # each way: dim, swap, undim
@export var outfit_hold_time := 0.15 # how long it stays dim while he changes
@export_range(0.0, 1.0) var outfit_dim := 1.0 # 1 = full black
@export_group("")
var _player_inside := true
var _changing_outfit := false

@export_group("Day Night Cycle")
## The clock never runs on its own: it only moves when the story moves it
## (TASK_SETS_TIME, sleeping, skip_time).
@export var start_hour := 6.0
@export var time_change_duration := 3.0 # seconds the sky takes to move to a scripted hour
@export var day_gradient: Gradient # x=0 is midnight, x=1 is next midnight

@export_group("Base Lighting")
@export var base_day_color := Color(0.92, 0.96, 1.0) # ~6500K cool white, work hours
@export var base_night_color := Color(1.0, 0.72, 0.45) # ~2700K warm, evening/sleep
@export var base_day_energy := 0.2 # subtle: CanvasModulate is already bright by day
@export var base_night_energy := 0.9 # carries the room once it's dark outside
@export var lights_warm_start := 18.0 # warm transition begins (hour)
@export var lights_warm_end := 20.0 # fully warm by
@export var lights_cool_start := 5.0 # morning transition begins
@export var lights_cool_end := 7.0 # fully white by
@export var low_power_brightness := 0.45 # base light strength while the power is low

const HOURS_PER_DAY := 24.0

## Completing these tasks moves the clock to this hour (forward, wrapping to tomorrow).
const TASK_SETS_TIME := {
	&"water_garden": 14.0, # 06:00 morning watering -> 14:00
	&"fix_solar": 18.0, # 14:00 power restored -> 18:00 sunset
	&"window_selfie": 22.0, # 18:00 sunset selfie -> 22:00 bedtime
}

var game_hour := 0.0 # 0..24
var day := 1
var _last_hour_int := -1


func _ready() -> void:
	mars_ambient.play()

	game_hour = start_hour
	if day_gradient == null:
		day_gradient = _make_default_gradient()
	_update_modulate()
	orbi_dialog = OrbiDialog.new()
	add_child(orbi_dialog)
	_setup_tasks()
	_setup_camera_limits()
	_base_spawn_cell = grid.world_to_cell(player.global_position) # where the game starts = home
	_setup_fade()
	_set_inside(_is_indoors(), false)
	player.step_gate = _outfit_gate
	player.step_blocked.connect(_on_step_blocked)
	_game_start.call_deferred()


func _game_start() -> void:
	var intro := IntroCutscene.new()
	add_child(intro)
	# don't draw the world (lights, shadows, props) behind the full-screen video:
	# frees CPU/GPU for video decoding, which matters a lot in web builds
	visible = false
	# bring the world back as soon as the video ends, so it's already underneath while
	# the video fades out (otherwise the empty background shows through the fade)
	intro.ending.connect(func(): visible = true)
	await intro.play() # pauses the game while the video runs; returns at once if there's no video
	visible = true
	await show_clock_moment()
	await _play_pending_intros()


## Plays queued "go do this task!" dialogues (one after another).
func _play_pending_intros() -> void:
	while not _pending_intros.is_empty():
		await play_dialogue(_pending_intros.pop_front())


func _setup_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25 # above HUD, below Orbi's dialog
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


## Fade out, put the player back at base, skip some time, fade in, then Orbi comments.
func _return_to_base() -> void:
	_returning = true
	player.input_locked = true
	player.path.clear()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, border_fade_time)
	await t.finished

	player.teleport(_base_spawn_cell)
	_set_inside(true, false) # back home: casual clothes, no extra fade (already black)
	if orbi:
		orbi.snap_to_player()
	skip_time(border_time_skip_minutes / 60.0)
	_border_armed = true
	await get_tree().create_timer(0.4).timeout

	t = create_tween()
	t.tween_property(_fade, "color:a", 0.0, border_fade_time)
	await t.finished
	player.input_locked = false
	_returning = false
	play_dialogue(&"border_return")


func skip_time(hours: float) -> void:
	game_hour += hours
	_normalize_time() # handles wrapping into the next day + hour signals
	_update_modulate()
	hud.update_clock(get_clock_title(), get_time_string()) # keeps a visible clock ticking


## Safety net: the camera never scrolls past the painted ground, even at the border.
func _setup_camera_limits() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var tm := grid.tile_map
	var used := tm.get_used_rect()
	var tl := tm.to_global(tm.map_to_local(used.position) - Vector2(tm.tile_set.tile_size) / 2)
	var br := tm.to_global(tm.map_to_local(used.end) - Vector2(tm.tile_set.tile_size) / 2)
	cam.limit_left = int(tl.x)
	cam.limit_top = int(tl.y)
	cam.limit_right = int(br.x)
	cam.limit_bottom = int(br.y)


## Touching the border once: Orbi warns you and stops you. Touching it again after
## that (once you've stepped back in a little): he brings you home.
func _check_border() -> void:
	if _returning:
		return
	var d := grid.distance_to_border(grid.world_to_cell(player.global_position))
	if d <= 0 and _border_armed:
		_border_armed = false
		if _border_warned:
			_border_warned = false
			_return_to_base()
			return
		_border_warned = true
		# stop where you are (keep only the step already in progress)
		if player.path.size() > 1:
			player.path.resize(1)
		player.clear_pending()
		play_dialogue(&"border_warning")
	elif not _border_armed and d >= border_rearm_cells:
		_border_armed = true # stepped back in: the next touch counts again


func _setup_tasks() -> void:
	# listen to every interactable in the level, wherever it sits in the tree
	for node in find_children("*", "", true, false):
		if node is Interactable:
			_interactables.append(node)
			node.task_completed.connect(complete_task)
			node.dialogue_requested.connect(play_dialogue)
			node.action_requested.connect(_on_action_requested)
	day_passed.connect(hud.set_day)
	day_passed.connect(_reset_tasks)
	_refresh_tasks()


func is_task_today(task_id: StringName) -> bool:
	return not TASK_DAYS.has(task_id) or day in TASK_DAYS[task_id]


func is_task_unlocked(task_id: StringName) -> bool:
	if not is_task_today(task_id):
		return false
	for req in TASK_REQUIRES.get(task_id, []):
		if is_task_today(req) and not completed_tasks.has(req):
			return false
	return true


## Power is low on a day where the solar panels need fixing, until they're fixed.
## Power is low once the solar task is on the list, until it's fixed.
func is_power_low() -> bool:
	return is_task_unlocked(&"fix_solar") and not completed_tasks.has(&"fix_solar")


## Adds newly unlocked tasks to the HUD and shows/hides "!" markers to match.
func _refresh_tasks() -> void:
	for id in TASKS:
		if not _shown_tasks.has(id) and is_task_unlocked(id):
			_shown_tasks[id] = true
			hud.add_task(id, TASKS[id], id in TASK_URGENT)
			if TASK_INTROS.has(id):
				_pending_intros.append(TASK_INTROS[id])
	for node in _interactables:
		if node.task_id == &"":
			continue
		var open := is_task_unlocked(node.task_id) and not completed_tasks.has(node.task_id)
		node.task_available = open
		if node.show_indicator:
			node.set_indicator_visible(open)


func _on_action_requested(action: StringName, _source: Interactable) -> void:
	match action:
		&"sleep":
			_try_sleep()


func _try_sleep() -> void:
	if _sleeping or _returning:
		return
	if not is_task_unlocked(&"sleep"):
		# point at whatever is still missing today
		var missing := &"water_garden"
		for req in TASK_REQUIRES[&"sleep"]:
			if is_task_today(req) and not completed_tasks.has(req):
				missing = req
				break
		play_dialogue(&"sleep_locked" if missing == &"water_garden" else StringName("sleep_locked_" + missing))
		return
	_sleeping = true
	player.input_locked = true
	_mark_task_done(&"sleep") # checkmark ticks as the screen goes dark
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, sleep_fade_time)
	await t.finished

	# jump forward to the next wake_hour (tomorrow if it's already past it);
	# crossing midnight fires day_passed, which resets the task list in the dark
	var hours := fposmod(wake_hour - game_hour, HOURS_PER_DAY)
	if hours < 0.01:
		hours = HOURS_PER_DAY
	skip_time(hours)
	if orbi:
		orbi.snap_to_player()
	await get_tree().create_timer(sleep_hold_time).timeout

	t = create_tween()
	t.tween_property(_fade, "color:a", 0.0, sleep_fade_time)
	await t.finished
	player.input_locked = false
	_sleeping = false
	await _task_outro(&"sleep") # good morning + clock
	await _play_pending_intros() # e.g. Orbi's power alert on day 2


func complete_task(task_id: StringName) -> void:
	if not _mark_task_done(task_id):
		return
	# let the checkmark animate before the outro
	await get_tree().create_timer(0.8).timeout
	await _task_outro(task_id)
	await _play_pending_intros()


## Records + checks off a task. Returns false if unknown or already done.
func _mark_task_done(task_id: StringName) -> bool:
	if not TASKS.has(task_id):
		push_warning("unknown task id: %s" % task_id)
		return false
	if completed_tasks.has(task_id):
		return false
	completed_tasks[task_id] = true
	hud.set_task_done(task_id)
	task_done.emit(task_id)
	_refresh_tasks()
	return true


## Orbi talks, then the clock moment (with the timelapse if the task moves time).
func _task_outro(task_id: StringName) -> void:
	await play_dialogue(task_id)
	await show_clock_moment(TASK_SETS_TIME.get(task_id, -1.0))


## New day: every task is to-do again (daily routine).
func _reset_tasks(_day := 0) -> void:
	completed_tasks.clear()
	_shown_tasks.clear()
	hud.clear_tasks()
	_refresh_tasks()


## Big centered clock. With to_hour >= 0, the sky timelapses to that hour behind it
## while the digits run. Player input is locked for the duration.
func show_clock_moment(to_hour := -1.0) -> void:
	var was_locked := player.input_locked
	player.input_locked = true
	await hud.show_clock(get_clock_title(), get_time_string())
	if to_hour >= 0.0:
		await get_tree().create_timer(0.3).timeout
		var t := advance_to_hour(to_hour, time_change_duration)
		if t:
			await t.finished
		await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.6).timeout
	await hud.hide_clock()
	player.input_locked = was_locked


func get_clock_title() -> String:
	return "DAY %d" % day


## Shows one of Orbi's conversations from Dialogues.ALL (no-op if the id has none).
## Await it to continue once the conversation is closed.
func play_dialogue(id: StringName) -> void:
	var lines := Dialogues.get_lines(id)
	if lines.is_empty():
		return
	# fill {time} / {day} from the real clock (copies, so Dialogues.ALL stays untouched)
	var vars := {"time": get_spoken_time(), "day": str(day)}
	var filled: Array = []
	for line: Dictionary in lines:
		var l := line.duplicate()
		l["text"] = String(l.get("text", "")).format(vars)
		filled.append(l)
	orbi_dialog.play(filled)
	await orbi_dialog.finished


## Clock time the way Orbi says it (Arabic): "6:00 صباحًا", "10:30 مساءً".
func get_spoken_time() -> String:
	var h := int(game_hour)
	var m := int((game_hour - h) * 60.0)
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, "صباحًا" if h < 12 else "مساءً"]


func is_task_done(task_id: StringName) -> bool:
	return completed_tasks.has(task_id)


func _process(_delta: float) -> void:
	_check_border()
	_update_objective()


## Points the HUD arrow at the object for the task you should do next
## (urgent tasks first, then in list order). Hidden during dialogues/minigames.
func _update_objective() -> void:
	if player.input_locked or get_tree().paused:
		hud.set_objective(null)
		return
	var order: Array = TASK_URGENT.duplicate()
	for id in TASKS:
		if id not in order:
			order.append(id)
	for id in order:
		if not _shown_tasks.has(id) or completed_tasks.has(id) or not is_task_unlocked(id):
			continue
		for node in _interactables:
			if node.task_id == id:
				hud.set_objective(node.global_position, id in TASK_URGENT)
				return
	hud.set_objective(null)


func _cell_indoors(cell: Vector2i) -> bool:
	return grid.tile_map.get_cell_source_id(cell) in indoor_sources


func _is_indoors() -> bool:
	return _cell_indoors(grid.world_to_cell(player.global_position))


## The player asks before every step; stepping between indoors and outdoors stops him
## on the last tile before the exit so he can change (see _on_step_blocked).
func _outfit_gate(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	return not _returning and not _sleeping and _cell_indoors(from_cell) != _cell_indoors(to_cell)


## Fade to black on this side, change, come back already standing on the other side.
func _on_step_blocked(_from_cell: Vector2i, to_cell: Vector2i) -> void:
	player.input_locked = true
	_changing_outfit = true
	_player_inside = _cell_indoors(to_cell)
	var t := create_tween()
	t.tween_property(_fade, "color:a", outfit_dim, outfit_fade_time)
	await t.finished
	player.skin = Player.Outfit.GINGER if _player_inside else Player.Outfit.SPACESUIT
	player.skip_step() # now on the first tile past the threshold
	if orbi:
		orbi.snap_to_player()
	await get_tree().create_timer(outfit_hold_time).timeout
	player.hold_movement = false # carry on with the rest of the walk as the screen clears
	t = create_tween()
	t.tween_property(_fade, "color:a", 0.0, outfit_fade_time)
	await t.finished
	player.input_locked = false
	_changing_outfit = false


func _set_inside(inside: bool, fade: bool) -> void:
	_player_inside = inside
	var outfit := Player.Outfit.GINGER if inside else Player.Outfit.SPACESUIT
	if not fade or player.skin == outfit:
		player.skin = outfit
		return
	# he's standing still: dim -> change -> undim
	_changing_outfit = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", outfit_dim, outfit_fade_time)
	await t.finished
	player.skin = outfit
	await get_tree().create_timer(outfit_hold_time).timeout
	t = create_tween()
	t.tween_property(_fade, "color:a", 0.0, outfit_fade_time)
	await t.finished
	_changing_outfit = false
	if is_power_low():
		_update_base_lights() # every frame, for the flicker


## Moves the clock forward to the next time it's `hour` (tomorrow if already past),
## animating the sky over `duration` seconds (0 = instant). Keeps going while paused,
## so it plays under Orbi's dialogue.
func advance_to_hour(hour: float, duration := 0.0) -> Tween:
	var hours := fposmod(hour - game_hour, HOURS_PER_DAY)
	if hours < 0.001:
		return null
	if duration <= 0.0:
		skip_time(hours)
		return null
	var done := [0.0] # array: lambdas capture locals by value, but share the array
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_method(func(x: float):
		skip_time(x - done[0])
		done[0] = x, 0.0, hours, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return t


func _normalize_time() -> void:
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
	_update_base_lights()


## 0 = work-hours white, 1 = night warm, with smooth ramps morning and evening.
func _base_warmth() -> float:
	var h := game_hour
	if h >= lights_warm_start:
		return smoothstep(lights_warm_start, lights_warm_end, h)
	if h < lights_cool_end:
		return 1.0 - smoothstep(lights_cool_start, lights_cool_end, h)
	return 0.0


func _update_base_lights() -> void:
	# color follows the clock (crew schedule: white for work, warm for evening)...
	var w := _base_warmth()
	var c := base_day_color.lerp(base_night_color, w)
	# ...but brightness follows how dark it actually is outside, so the lights only
	# fill in what the sky is missing. Otherwise a bright dawn + full night-strength
	# lights stack up and blow out the base.
	var night_lum := day_gradient.sample(0.0).get_luminance()
	var k := clampf(inverse_lerp(night_lum, 1.0, canvas_modulate.color.get_luminance()), 0.0, 1.0)
	var e := lerpf(base_night_energy, base_day_energy, k)
	if is_power_low():
		# brownout: dimmer, with a nervous flicker and the odd dropout
		var t := Time.get_ticks_msec() / 1000.0
		var flicker := 0.85 + 0.15 * sin(t * 23.0) * sin(t * 7.3)
		if fmod(t, 4.3) < 0.12:
			flicker = 0.25
		e = maxf(e, base_night_energy * 0.5) * low_power_brightness * flicker
	get_tree().call_group("base_lights", "set_lighting", c, e)


func get_time_string() -> String:
	var h := int(game_hour)
	var m := int((game_hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func is_night() -> bool:
	return game_hour < 6.0 or game_hour >= 19.0


## Mars-ish sky: dust high in the atmosphere scatters light long before sunrise and after
## sunset, so twilight lasts ~2 hours, and it glows BLUE near the sun (the opposite of
## Earth). So 6 AM is a dim blue dawn, not pitch black.
func _make_default_gradient() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 4.5 / 24, 6.0 / 24, 7.5 / 24, 12.0 / 24, 17.5 / 24, 19.0 / 24, 20.5 / 24, 1.0])
	g.colors = PackedColorArray([
		Color(0.10, 0.12, 0.25), # 00:00 night
		Color(0.10, 0.12, 0.25), # 04:30 twilight starts
		Color(0.60, 0.66, 0.88), # 06:00 blue Mars dawn
		Color(1.0, 0.90, 0.82), # 07:30 warm morning
		Color(1.0, 1.0, 1.0), # 12:00 midday
		Color(1.0, 0.88, 0.78), # 17:30 warm afternoon
		Color(0.55, 0.60, 0.85), # 19:00 blue Mars dusk
		Color(0.10, 0.12, 0.25), # 20:30 night
		Color(0.10, 0.12, 0.25), # 24:00 night
	])
	return g


func _on_base_area_body_entered(body: Node2D) -> void:
	if body is Player:
		hud.set_location_text("BASE", Color.LIGHT_BLUE)


func _on_base_area_body_exited(body: Node2D) -> void:
	if body is Player:
		hud.set_location_text("OUTSIDE", Color("#c1440e"))
