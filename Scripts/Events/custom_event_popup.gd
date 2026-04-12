extends Control

@onready var content_list: VBoxContainer = $PanelContainer/VBoxContainer

var data: Dictionary = {}
var manually_positioned = false
var dragging = false
var drag_offset = Vector2.ZERO

func setup(p_data: Dictionary):
	data = p_data
	# Refresh UI
	for child in content_list.get_children():
		child.queue_free()
	
	if data.has("contents") and data["contents"] is Array:
		for element in data["contents"]:
			var count_before = content_list.get_child_count()
			InterpreterManager.get_element(element, content_list, CountryManager.player_country)
			var count_after = content_list.get_child_count()
			
			if count_after > count_before:
				var new_node = content_list.get_child(count_after - 1)
				if new_node is Button:
					new_node.pressed.connect(queue_free)
	
	# Wait one frame for the layout to update, then shrink root to fit
	await get_tree().process_frame
	size = $PanelContainer.size

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	$PanelContainer.mouse_filter = Control.MOUSE_FILTER_PASS
	# Use standard OK behavior if no custom buttons?
	# Or maybe custom events have their own buttons in contents.

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				manually_positioned = true
			else:
				dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			queue_free()
	
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset
