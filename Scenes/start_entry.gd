extends Node2D

@onready var background_rect: TextureRect = $"PanelContainer/VBoxContainer/background"
# @onready var heading_label: Label = $"PanelContainer/VBoxContainer/description"
@onready var button: Button = $"PanelContainer/VBoxContainer/background/Button"

func _ready():
	button.pressed.connect(_on_button_pressed)

func setup(text: String, background: String):
	# Data format: { "background": "ww3", "desc": "...", "button": "..." }
	
	# if data.has("desc"):
	# 	desc_label.text = data["desc"]
	
	if button:
		button.text = text
		
	if background:
		if FileAccess.file_exists(background) or ResourceLoader.exists(background):
			background_rect.texture = load(background)
		else:
			push_warning("StartEntry: Background image not found at %s" % background)

func _on_button_pressed():
	queue_free()
