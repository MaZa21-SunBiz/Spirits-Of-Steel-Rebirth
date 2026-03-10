extends Control

@onready var save_list = $TabContainer/Saves/VBoxContainer/ScrollContainer/savelist
@onready var line_edit = $TabContainer/Saves/VBoxContainer/HBoxContainer/TextEdit

enum Section {SAVE, AUDIO, SETTINGS, EXIT}
var settings = {}
@onready var idfkanymore = $TabContainer/Graphics
@onready var audio_path = $TabContainer/Audio/HBoxContainer/VBoxContainer
@onready var graphics_path = $TabContainer/Graphics/ScrollContainer/HBoxContainer/VBoxContainer2

@onready var sfx_slider = audio_path.get_node("PanelContainer/HBoxContainer/HSlider")
@onready var music_slider = audio_path.get_node("PanelContainer2/HBoxContainer/HSlider")
@onready var scanlines_slider = graphics_path.get_node("HSlider2")
@onready var vignette_lower_slider = graphics_path.get_node("HSlider")
@onready var vignette_upper_slider = graphics_path.get_node("HSlider3")
@onready var map_effects_slider = graphics_path.get_node("HSlider10")
@onready var province_borders_slider = graphics_path.get_node("HSlider5")
@onready var ui_upper_slider = graphics_path.get_node("HSlider6")
@onready var ui_lower_slider = graphics_path.get_node("HSlider7")
@onready var ui_dirt_slider = graphics_path.get_node("HSlider8")
@onready var daynight_contrast_slider = graphics_path.get_node("HSlider9")
@onready var daynight_smoothness_slider = graphics_path.get_node("HSlider4")

func _ready():
	_refresh_saves()
	_initialize_ui_values()

func _initialize_ui_values():
	var s = SettingsManager.settings
	sfx_slider.value = s.sfx_volume
	music_slider.value = s.music_volume
	scanlines_slider.value = s.scanlines
	vignette_lower_slider.value = s.vignette_lower
	vignette_upper_slider.value = s.vignette_upper
	map_effects_slider.value = s.map_effects
	province_borders_slider.value = s.province_borders
	ui_upper_slider.value = s.ui_upper
	ui_lower_slider.value = s.ui_lower
	ui_dirt_slider.value = s.ui_dirt
	daynight_contrast_slider.value = s.daynight_contrast
	daynight_smoothness_slider.value = s.daynight_smoothness

func save_settings() -> void:
	SettingsManager.save_settings()

func _refresh_saves():
	for n in save_list.get_children(): n.queue_free()
	# Scan res://saves/ for files
	var path = "res://saves/"
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var found_any = false

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				found_any = true
				_add_save_row(save_list, file_name.replace(".tres", ""))
			file_name = dir.get_next()
		
		if not found_any:
			var lbl = Label.new()
			lbl.text = "No save files found."
			lbl.modulate = Color(0.5, 0.5, 0.5)
			save_list.add_child(lbl)

func _on_sfx_changed(value: float) -> void:
	SettingsManager.settings.sfx_volume = value
	SettingsManager.apply_settings()

func _on_music_changed(value: float) -> void:
	SettingsManager.settings.music_volume = value
	SettingsManager.apply_settings()

func _add_save_row(parent: Node, save_name: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var lbl = Label.new()
	lbl.text = save_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size.x = 80
	load_btn.pressed.connect(func():
		GameState.current_world.load_game(save_name)
	)
	
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.modulate = Color(1, 0.4, 0.4)
	del_btn.pressed.connect(func():
		DirAccess.remove_absolute("res://saves/" + save_name + ".tres")
		_refresh_saves()
	)

	hbox.add_child(load_btn)
	hbox.add_child(del_btn)
	parent.add_child(hbox)

func _on_save_game_pressed():
	GameState.current_world.save_game(line_edit.text.strip_edges())
	_refresh_saves()

func _on_scanlines_changed(value: float) -> void:
	SettingsManager.settings.scanlines = value
	SettingsManager.apply_settings()
	
func _on_vignette_upper_changed(value: float) -> void:
	SettingsManager.settings.vignette_upper = value
	SettingsManager.apply_settings()

func _on_vignette_lower_changed(value: float) -> void:
	SettingsManager.settings.vignette_lower = value
	SettingsManager.apply_settings()

func _on_map_effects_changed(value: float) -> void:
	SettingsManager.settings.map_effects = value
	SettingsManager.apply_settings()

func _on_province_borders_changed(value: float) -> void:
	SettingsManager.settings.province_borders = value
	SettingsManager.apply_settings()

func _on_ui_upper_changed(value: float) -> void:
	SettingsManager.settings.ui_upper = value
	idfkanymore.material.set_shader_parameter("upper", value)

func _on_ui_lower_changed(value: float) -> void:
	SettingsManager.settings.ui_lower = value
	idfkanymore.material.set_shader_parameter("lower", value)

func _on_ui_dirt_changed(value: float) -> void:
	SettingsManager.settings.ui_dirt = value
	idfkanymore.material.set_shader_parameter("dirt", value)

func _on_daynight_contrast_changed(value: float) -> void:
	SettingsManager.settings.daynight_contrast = value
	SettingsManager.apply_settings()

func _on_daynight_smoothness_changed(value: float) -> void:
	SettingsManager.settings.daynight_smoothness = value
	SettingsManager.apply_settings()
