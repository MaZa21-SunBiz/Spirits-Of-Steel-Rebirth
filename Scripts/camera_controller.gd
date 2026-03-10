extends Node

@export var camera: Camera2D = get_parent()
@export var base_speed: float = 600.0

var is_dragging := false
const TOP_BAR_HEIGHT = 32
const MAP_HEIGHT = 625


func _process(delta: float) -> void:
	if Console.is_visible() or GameState.decision_menu_open:
		return
	_handle_keyboard_movement(delta)


func _is_mouse_over_ui() -> bool:
	var hovered = get_viewport().gui_get_hovered_control()
	return hovered != null


func _input(event: InputEvent) -> void:
	camera.position.y = clampf(camera.position.y, -TOP_BAR_HEIGHT / camera.zoom.y, - (MAP_HEIGHT + TOP_BAR_HEIGHT) / camera.zoom.y + MAP_HEIGHT)

	if Console.is_visible() or _is_mouse_over_ui():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_dragging = event.pressed
		get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and is_dragging:
		camera.position -= event.relative / camera.zoom.x

	if event is InputEventMouseButton and event.is_pressed():
		var zoom_dir = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_dir = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_dir = -1

		if zoom_dir != 0:
			_perform_zoom(zoom_dir)


func _handle_keyboard_movement(delta: float) -> void:
	camera.position += Input.get_vector("move_left", "move_right", "move_up", "move_down") * (base_speed / camera.zoom.x) * delta


func _perform_zoom(direction: int) -> void:
	var mouse_pos_before := camera.get_global_mouse_position()

	camera.zoom = (camera.zoom + Vector2.ONE * direction).clamp(Vector2.ONE, Vector2.ONE * 12)

	var mouse_pos_after := camera.get_global_mouse_position()
	camera.position += mouse_pos_before - mouse_pos_after


var auto_target := Vector2.ZERO
var auto_change_timer := 0.0

@export var auto_speed := 120.0
@export var auto_min_time := 3.0
@export var auto_max_time := 8.0


func move_map_around(delta: float) -> void:
	if not GameState.current_map:
		return

	var map_container = GameState.current_map
	var map_sprite = map_container.map_sprite
	if not map_sprite or not MapManager.id_map_image:
		return

	var map_width = MapManager.id_map_image.get_width()
	var map_height = MapManager.id_map_image.get_height()

	auto_change_timer -= delta

	# Pick new cinematic target
	if auto_change_timer <= 0.0:
		var center = map_sprite.position

		auto_target = Vector2(
			randf_range(center.x - map_width * 0.5, center.x + map_width * 0.5),
			randf_range(center.y - map_height * 0.5, center.y + map_height * 0.5)
		)

		auto_change_timer = randf_range(auto_min_time, auto_max_time)

		# Occasionally zoom
		if randi() % 3 == 0:
			var new_zoom = randf_range(2.0, 6.0)
			camera.zoom = Vector2.ONE * new_zoom

	# Smooth cinematic movement
	camera.position = camera.position.lerp(auto_target, delta * 0.5)

	# Horizontal wrap safe zone
	if camera.position.x > map_sprite.position.x + map_width:
		camera.position.x -= map_width
	elif camera.position.x < map_sprite.position.x - map_width:
		camera.position.x += map_width

	# Vertical clamp (no vertical wrapping)
	camera.position.y = clamp(
		camera.position.y,
		map_sprite.position.y - map_height * 0.5,
		map_sprite.position.y + map_height * 0.5
	)
