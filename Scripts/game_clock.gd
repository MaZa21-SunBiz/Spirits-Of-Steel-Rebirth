extends Node
class_name GameClock

signal hour_passed(total_ticks)
signal day_passed(date_string)
signal speed_changed

@export_group("Starting Settings")
@export var start_year := 2010
@export var start_month := 1
@export var start_day := 1
@export var start_hour := 0

# HOI4-Style Speed levels (Seconds to wait between hourly ticks)
# Speed 5 is 0.0, meaning it runs as fast as your CPU/Frame-rate allows.
const SPEEDS = {0: -1.0, 1: 1.0, 2: 0.5, 3: 0.1, 4: 0.02, 5: 0.0}  # Paused  # Very Slow (1 tick per second)  # Slow  # Normal  # Fast  # Unlocked (As fast as possible)

# --- State Variables -
var time_scale: float = 0.0  # to not break existing code
var current_speed_level := 0:
	set(val):
		current_speed_level = clamp(val, 0, 5)
		paused = (current_speed_level == 0)

var total_ticks := 0  # Core Simulation Truth (1 Tick = 1 Hour)
var total_game_seconds := 0.0  # Visual/Rendering Truth (Smooth float)
var unix_start_time := 0  # The "Anchor" for all calendar math
var tick_timer := 0.0
var paused := true


func _ready() -> void:
	# Convert your export variables into a starting Unix timestamp
	var start_dict = {
		"year": start_year,
		"month": start_month,
		"day": start_day,
		"hour": start_hour,
		"minute": 0,
		"second": 0
	}
	unix_start_time = Time.get_unix_time_from_datetime_dict(start_dict)

	# Start paused by default or set a speed
	_perform_tick()
	set_speed(0)


func _process(delta: float) -> void:
	if paused or current_speed_level == 0:
		return

	# 1. Update visual clock (for your CustomRenderer)
	# This stays smooth even if the simulation ticks are slow.
	total_game_seconds += delta * _get_visual_multiplier()

	# 2. Update simulation ticks
	if current_speed_level == 5:
		# Speed 5: Run exactly one tick every frame
		_perform_tick()
	else:
		tick_timer += delta
		var wait_time = SPEEDS[current_speed_level]
		while tick_timer >= wait_time:
			tick_timer -= wait_time
			_perform_tick()


func _perform_tick() -> void:
	var old_date = get_date_string()

	total_ticks += 1
	hour_passed.emit(total_ticks)

	# If the date string changes after this hour, a day has passed
	var new_date = get_date_string()
	if new_date != old_date:
		day_passed.emit(new_date)


# --- Helper Functions ---


func get_date_string() -> String:
	# Calculate date based ONLY on total_ticks (No drift!)
	var current_unix = unix_start_time + (total_ticks * 3600)
	var d = Time.get_date_dict_from_unix_time(current_unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func get_future_date_string(days_from_now: int) -> String:
	var seconds_to_add = days_from_now * 86400
	var future_unix = (unix_start_time + (total_ticks * 3600)) + seconds_to_add
	var d = Time.get_date_dict_from_unix_time(future_unix)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func get_time_string() -> String:
	var current_unix = unix_start_time + (total_ticks * 3600)
	var d = Time.get_datetime_dict_from_unix_time(current_unix)
	return "%02d:00" % d.hour


func get_datetime_string() -> String:
	var current_unix = unix_start_time + (total_ticks * 3600)
	var d = Time.get_datetime_dict_from_unix_time(current_unix)
	return "%04d-%02d-%02d %02d:00" % [d.year, d.month, d.day, d.hour]


func _get_visual_multiplier() -> float:
	# Helps total_game_seconds scale roughly with game speed for animations
	match current_speed_level:
		1:
			return 1.0
		2:
			return 2.0
		3:
			return 10.0
		4:
			return 50.0
		5:
			return 100.0
		_:
			return 0.0


# --- Controls ---


func set_speed(level: int) -> void:
	current_speed_level = clamp(level, 0, 5)
	paused = (current_speed_level == 0)

	# Map the Speed Level to a float "time_scale" for your movement logic
	# Level 1 = 1x, Level 2 = 2x, etc.
	# Adjust these numbers to match how fast you want units to move!
	match current_speed_level:
		0:
			time_scale = 0.0
		1:
			time_scale = 1.0
		2:
			time_scale = 5.0
		3:
			time_scale = 20.0
		4:
			time_scale = 50.0
		5:
			time_scale = 100.0

	speed_changed.emit()


func increase_speed() -> void:
	set_speed(current_speed_level + 1)


func decrease_speed() -> void:
	set_speed(current_speed_level - 1)


func pause():
	paused = true


func toggle_pause() -> void:
	paused = !paused
