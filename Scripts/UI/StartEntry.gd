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
			SceneSwitcher.switch_to(SceneSwitcher.Type.WORLD, func():
				GameState.current_start = a_text
				PlansManager.load_plans_from_path(start_folder + "plans.json")
				DecisionManager.load_decisions_from_path(start_folder + "decisions/")
				EventManager.load_super_events(start_folder + "superevents.json")
				TroopManager.set_custom_flag_path(start_folder + "flags/")
				
				IdeologyManager.Initialize(map_data.get("ideologies", {}) as Dictionary)
				MapManager.load_country_data(load(start_folder + "regions.png"), map_data.get("provinces", {}) as Dictionary)
				CountryManager.initialize_countries(map_data.get("polities", []) as Array)
				MapManager.build_lookup_texture()
				FactionManager.Initialize(map_data.get("factions", []))

				Console.add_command_autocomplete_list("play_as", CountryManager.countries.keys())
			)
		button.pressed.connect(load_map_data)
		
	if a_background:
		if FileAccess.file_exists(a_background) or ResourceLoader.exists(a_background):
			background_rect.texture = load(a_background)
		else:
			push_warning("StartEntry: Background image not found at %s" % a_background)

# func _on_button_pressed():
	# queue_free()
