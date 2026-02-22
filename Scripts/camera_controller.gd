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

	camera.position += mouse_pos_before - camera.get_global_mouse_position()
