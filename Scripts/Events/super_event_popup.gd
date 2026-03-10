extends Control

@onready var background_rect: TextureRect = $"Panel/background"
@onready var desc_label: Label = $"Panel/description"
@onready var button: Button = $"Button"

func _ready():
	button.pressed.connect(_on_button_pressed)

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
