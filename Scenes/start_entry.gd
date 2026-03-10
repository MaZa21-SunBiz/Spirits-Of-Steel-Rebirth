extends Node2D

@onready var background_rect: TextureRect = $"PanelContainer/VBoxContainer/background"
# @onready var heading_label: Label = $"PanelContainer/VBoxContainer/description"
@onready var button: Button = $"PanelContainer/VBoxContainer/Button"

func _ready():
	pass

func setup(text: String, background: String, mapdata_path: String):
	# Data format: { "background": "ww3", "desc": "...", "button": "..." }
	# if data.has("desc"):
	# 	desc_label.text = data["desc"]
	if button:
		button.text = text
		var json_data = JSON.parse_string(FileAccess.open(mapdata_path, FileAccess.READ).get_as_text())
		var mapData: Dictionary = json_data if json_data is Dictionary else {}
		var load_map_data = func():
				# Derive start folder path from mapdata_path (e.g., res://starts/ModernDay/map_data.json)
				var start_folder = mapdata_path.get_base_dir() + "/"
				
				# Load start-specific assets
				DecisionManager.load_decisions_from_path(start_folder + "decisions/")
				SuperEventManager.load_events_from_path(start_folder + "superevents.json")
				TroopManager.set_custom_flag_path(start_folder + "flags/")
				
				# Initialize managers with map data
				IdeologyManager.Initialize(mapData["ideologies"] as Dictionary)
				MapManager.load_country_data(mapData["provinces"] as Dictionary)
				CountryManager.initialize_countries(mapData["polities"] as Array[Dictionary])
				MapManager.build_lookup_texture()
				FactionManager.Initialize(mapData["factions"])
				
				# Change scene to Main which contains World
				get_tree().change_scene_to_packed(preload("res://Scenes/main.tscn"))
		button.connect("pressed", load_map_data)
		
	if background:
		if FileAccess.file_exists(background) or ResourceLoader.exists(background):
			background_rect.texture = load(background)
		else:
			push_warning("StartEntry: Background image not found at %s" % background)

# func _on_button_pressed():
	# queue_free()
