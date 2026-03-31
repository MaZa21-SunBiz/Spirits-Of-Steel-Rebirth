extends Control

@export var save_list: VBoxContainer
@export var line_edit: TextEdit

enum Section {SAVE, AUDIO, SETTINGS, EXIT}
var settings = {}

@export var tab_container: TabContainer
@export var graphics_path: GridContainer

@export_group("Audio")
@export var sfx_slider: HSlider
@export var music_slider: HSlider


@export_group("UI")
@export var ui_upper_slider: HSlider
@export var ui_lower_slider: HSlider
@export var ui_dirt_slider: HSlider

@export_group("Map Effects")
@export var scanlines_slider: HSlider
@export var vignette_lower_slider: HSlider
@export var vignette_upper_slider: HSlider
@export var province_borders_slider: HSlider
@export var daynight_contrast_slider: HSlider
@export var daynight_smoothness_slider: HSlider
@export var clouds_slider: HSlider
@export var edgeness_slider: HSlider

@export var map_effects_btn: CheckButton
@export var debug_mode_btn: CheckButton

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
	map_effects_btn.button_pressed = s.map_effects
	province_borders_slider.value = s.province_borders
	ui_upper_slider.value = s.ui_upper
	ui_lower_slider.value = s.ui_lower
	ui_dirt_slider.value = s.ui_dirt
	daynight_contrast_slider.value = s.daynight_contrast
	daynight_smoothness_slider.value = s.daynight_smoothness
	clouds_slider.value = s.clouds
	edgeness_slider.value = s.clouds_edgeness
	debug_mode_btn.button_pressed = s.debug_mode


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


func _on_map_effects_pressed() -> void:
	SettingsManager.settings.map_effects = !SettingsManager.settings.map_effects
	graphics_path.visible = !graphics_path.visible
	SettingsManager.apply_settings()


func _on_province_borders_changed(value: float) -> void:
	SettingsManager.settings.province_borders = value
	SettingsManager.apply_settings()


func _on_ui_upper_changed(value: float) -> void:
	SettingsManager.settings.ui_upper = value
	tab_container.material.set_shader_parameter("upper", value)


func _on_ui_lower_changed(value: float) -> void:
	SettingsManager.settings.ui_lower = value
	tab_container.material.set_shader_parameter("lower", value)


func _on_ui_dirt_changed(value: float) -> void:
	SettingsManager.settings.ui_dirt = value
	tab_container.material.set_shader_parameter("dirt", value)


func _on_daynight_contrast_changed(value: float) -> void:
	SettingsManager.settings.daynight_contrast = value
	SettingsManager.apply_settings()


func _on_daynight_smoothness_changed(value: float) -> void:
	SettingsManager.settings.daynight_smoothness = value
	SettingsManager.apply_settings()


func _on_clouds_changed(value: float) -> void:
	SettingsManager.settings.clouds = value
	SettingsManager.apply_settings()


func _on_edgeness_slider_changed(value: float) -> void:
	SettingsManager.settings.edgeness_slider = value
	SettingsManager.apply_settings()


func _on_debug_mode_pressed() -> void:
	SettingsManager.settings.debug_mode = !SettingsManager.settings.debug_mode
	SettingsManager.apply_settings()
