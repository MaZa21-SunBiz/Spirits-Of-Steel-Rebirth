# CameraController.gd
extends Node

@onready var camera: Camera2D = get_parent().get_node("Camera2D") as Camera2D

@export var base_speed: float = 500.0
@export var zoom_speed: float = 0.6
@export var min_zoom: float = 0.6
@export var max_zoom: float = 15

func _process(delta: float) -> void:
	if GameState.decision_tree_open: return
	
	var velocity := Vector2.ZERO
	if Input.is_action_pressed("move_right"):  velocity.x += 1  # Speed is done with base_speed variable
	if Input.is_action_pressed("move_left"):   velocity.x -= 1
	if Input.is_action_pressed("move_down"):   velocity.y += 1
	if Input.is_action_pressed("move_up"):     velocity.y -= 1
	
	if velocity != Vector2.ZERO:
		velocity = velocity.normalized()
		var zoom_factor := camera.zoom.x
		camera.position += velocity * (base_speed / zoom_factor) * delta


func _input(event: InputEvent) -> void:
	if GameState.decision_tree_open: return

	
	if event is InputEventMouseButton and event.is_pressed():
		var mouse_world_before = camera.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom - Vector2(zoom_speed, zoom_speed)).clamp(
				Vector2(min_zoom, min_zoom),
				Vector2(max_zoom, max_zoom)
			)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom + Vector2(zoom_speed, zoom_speed)).clamp(
				Vector2(min_zoom, min_zoom),
				Vector2(max_zoom, max_zoom)
			)
		
		var mouse_world_after = camera.get_global_mouse_position()
		camera.position += mouse_world_before - mouse_world_after
