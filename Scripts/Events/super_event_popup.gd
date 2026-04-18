extends Control

@export var background_rect: TextureRect
@export var desc_label: Label
@export var button: Button

var manually_positioned = false
var dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_button_pressed)

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
			_on_button_pressed()
	
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func setup(data: Dictionary):
	# Data format: { "background": "ww3", "desc": "...", "button": "..." }
	
	if data.has("desc"):
		desc_label.text = data["desc"]
	
	if data.has("button"):
		button.text = data["button"]
		
	if data.has("background"):
		var path = "res://assets/superevents/" + data["background"] + ".png"
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			background_rect.texture = load(path)
		else:
			push_warning("SuperEvent: Background image not found at %s" % path)

func _on_button_pressed():
	queue_free()
