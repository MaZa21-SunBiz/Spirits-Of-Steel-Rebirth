extends Control

@onready var background_rect: TextureRect = $"VBoxContainer/background"
# @onready var heading_label: Label = $"PanelContainer/VBoxContainer/description"
@onready var button: Button = $"VBoxContainer/Button"

func _ready():
	pass

func setup(a_text: String, a_background: String, mapdata_path: String):
	# Data format: { "background": "ww3", "desc": "...", "button": "..." }
	# if data.has("desc"):
	# 	desc_label.text = data["desc"]
	if button:
		button.text = a_text
		var json_file = FileAccess.open(mapdata_path, FileAccess.READ)
		var json_text = json_file.get_as_text() if json_file else "{}"
		var json_data = JSON.parse_string(json_text)
		var map_data: Dictionary = json_data if json_data is Dictionary else {}
		
		var load_map_data = func():
			var start_folder = mapdata_path.get_base_dir() + "/"
			SceneSwitcher.switch_to(SceneSwitcher.Type.WORLD, func(a_percent: Array):
				GameState.current_start = a_text
				a_percent[0] = 0
				PlansManager.load_plans_from_path(start_folder + "plans.json")
				a_percent[0] = 0.06
				DecisionManager.load_decisions_from_path(start_folder + "decisions/")
				a_percent[0] = 0.12
				EventManager.load_super_events(start_folder + "superevents.json")
				a_percent[0] = 0.18
				TroopManager.set_custom_flag_path(start_folder + "flags/")
				a_percent[0] = 0.2
				
				IdeologyManager.Initialize(map_data.get("ideologies", {}) as Dictionary)
				a_percent[0] = 0.3
				MapManager.load_country_data(load(start_folder + "regions.png"), map_data.get("provinces", {}) as Dictionary)
				a_percent[0] = 0.6
				CountryManager.initialize_countries(map_data.get("polities", []) as Array)
				a_percent[0] = 0.75
				MapManager.build_lookup_texture()
				a_percent[0] = 0.85
				FactionManager.Initialize(map_data.get("factions", []))
				a_percent[0] = 0.9

				Console.add_command_autocomplete_list("play_as", CountryManager.countryNames)
				a_percent[0] = 1.0
			)
		button.pressed.connect(load_map_data)
		
	if a_background:
		if FileAccess.file_exists(a_background) or ResourceLoader.exists(a_background):
			background_rect.texture = load(a_background)
		else:
			push_warning("StartEntry: Background image not found at %s" % a_background)

# func _on_button_pressed():
	# queue_free()
