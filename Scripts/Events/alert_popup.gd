extends Control

@onready var flag_left: TextureRect = $PanelContainer/VBoxContainer/HBoxContainer/flag_left
@onready var flag_right: TextureRect = $PanelContainer/VBoxContainer/HBoxContainer/flag_right
@onready var description: Label = $PanelContainer/VBoxContainer/description
@onready var button: Button =  $PanelContainer/VBoxContainer/Button

var data = {}


var manually_positioned = false
var dragging = false
var drag_offset = Vector2.ZERO


func setup_alert(config: Dictionary):
	data = config


func _ready():
	button.pressed.connect(queue_free)
	mouse_entered.connect(_on_mouse_entered)
	_build_ui()


func _on_mouse_entered():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		queue_free()


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


func _build_ui():
	var c1 = data.get("c1")
	var c2 = data.get("c2")
	var custom_text = data.get("text", "")

	# 1. Handle Flags (Hide them if null)
	if c1:
		flag_left.texture = _get_flag(c1.country_name, c1.ideology_name)
		flag_left.show()
	else:
		flag_left.hide()

	if c2:
		flag_right.texture = _get_flag(c2.country_name, c2.ideology_name)
		flag_right.show()
	else:
		flag_right.hide()

	# 2. Set Text logic
	if custom_text != "":
		# Use custom text if provided
		description.text = custom_text
	else:
		# Fallback to standard types for backward compatibility
		match data.get("event", "event"):
			"war":
				description.text = "%s has declared war on %s!" % [
					c1.country_name.capitalize(), 
					c2.country_name.capitalize()
				]
			"capitulated":
				description.text = "%s has capitulated." % [c1.country_name.capitalize()]
			"game_over":
				description.text = "Game Over"
			var type:
				description.text = type


func _get_flag(country: String, ideology: String = ""):
	return TroopManager.get_flag(country, ideology)
