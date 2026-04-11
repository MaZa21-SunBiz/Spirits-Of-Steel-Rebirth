extends Node

const SETTINGS_FILE = "res://settings.json"

var settings = {
	"radios": MusicManager.radios,
	"sfx_volume": 0.1,
	"music_volume": 1.0,
	"scanlines": 0.0,
	"vignette_lower": 0.0,
	"vignette_upper": 0.0,
	"map_effects": 1.0,
	"provinceBorderThickness": 0.5,
	"province_borders": 0.8,
	"ui_upper": 0.8,
	"ui_lower": 0.8,
	"ui_dirt": 0.8,
	"daynight_contrast": 0.01,
	"daynight_smoothness": 0.01,
	"clouds": 0.01,
	"clouds_edgeness": 0.01,
	"debug_mode": false
}

func _ready():
	load_settings()

func load_settings():
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.data
			if typeof(data) == TYPE_DICTIONARY:
				# Merge loaded settings with defaults to ensure all keys exist
				for key in data.keys():
					settings[key] = data[key]
				apply_settings()
		else:
			print("JSON Parse Error: ", json.get_error_message(),
				" at line ", json.get_error_line())
	else:
		# If file doesn't exist, create it with defaults
		save_settings()

func save_settings():
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	var json_string = JSON.stringify(settings, "  ")
	file.store_string(json_string)
	file.close()

func apply_settings():
	# Audio
	MusicManager.set_sfx_volume(settings.sfx_volume)
	MusicManager.set_music_volume(settings.music_volume)
	MusicManager.radios = settings.radios
	InterpreterManager.debug = settings.debug_mode
	DecisionManager.debug = settings.debug_mode
	
	# Graphics (These require GameState.current_world to be set)
	if GameState.current_world and GameState.current_world.map_sprite:
		var mat = GameState.current_world.map_sprite.material
		mat.set_shader_parameter("scanlines", settings.scanlines)
		mat.set_shader_parameter("upper", settings.vignette_upper)
		mat.set_shader_parameter("lower", settings.vignette_lower)
		mat.set_shader_parameter("toggle", settings.map_effects)
		mat.set_shader_parameter("contrast", settings.daynight_contrast)
		mat.set_shader_parameter("smoothness", settings.daynight_smoothness)
		mat.set_shader_parameter("clouds", settings.clouds)
		mat.set_shader_parameter("edgeness", settings.clouds_edgeness)
		mat.set_shader_parameter("BorderThickness", settings.provinceBorderThickness)
		mat.set_shader_parameter("internal_border_darkness", settings.province_borders)
	
	# UI Effects (Wait for idfkanymore if it's in Settings menu, 
	# but these are actually for the whole UI if managed globally)
	# For now, we apply them when the settings menu is open/ready
