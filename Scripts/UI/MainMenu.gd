extends CanvasLayer

const SAVE_DIR = "user://saves/"
@onready var camera = $"../../Camera2D/CameraController"


func _ready() -> void:
	if SceneSwitcher.has_active_world():
		%Continue.visible = true
		%Continue.pressed.connect(_on_continue_pressed)
	else:
		%Continue.visible = false

	# 2. Connect other signals
	%NewGame.pressed.connect(_on_new_game_pressed)
	%LoadGame.pressed.connect(_on_load_game_pressed)
	%MapEditor.pressed.connect(_on_map_editor_pressed)
	%Settings.pressed.connect(_on_settings_pressed)
	%Exit.pressed.connect(_on_exit_pressed)

	_check_for_saves()

<<<<<<< HEAD:Scripts/main_menu.gd

func _process(delta: float) -> void:
	camera.move_map_around(delta)
	return


func _on_continue_pressed() -> void:
	SceneSwitcher.switch_to(SceneSwitcher.Type.WORLD)


func _check_for_saves() -> void:
	var dir = DirAccess.open("user://")

	# Create directory if it doesn't exist
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var save_path = DirAccess.open(SAVE_DIR)
	var has_saves = false

	if save_path:
		save_path.list_dir_begin()
		var file_name = save_path.get_next()
		while file_name != "":
			if not save_path.current_is_dir() and file_name.ends_with(".dat"):
				has_saves = true
				break
			file_name = save_path.get_next()

	%LoadGame.disabled = not has_saves


# Button Logic
func _on_new_game_pressed() -> void:
	MapManager.show_countries_map()
	ConsoleManager.switch_scene("select")


func _on_load_game_pressed() -> void:
	print("Opening save browser...")


func _on_map_editor_pressed() -> void:
	ConsoleManager.switch_scene("editor")
=======
func _on_sfx_changed(value: float) -> void:
	MusicManager.set_sfx_volume(value)

func _on_music_changed(value: float) -> void:
	MusicManager.set_music_volume(value)

func _on_new_game_pressed() -> void:
	# get_tree().change_scene_to_packed(preload("res://Scenes/world.tscn"))
	$"/root/MainMenu/Starts".visible = !$"/root/MainMenu/Starts".visible
>>>>>>> origin/SoiSauce:Scripts/UI/MainMenu.gd

func _on_start() -> void:
	if CountryManager.player_country:
		get_tree().change_scene_to_packed(preload("res://Scenes/main.tscn"))

func _on_settings_pressed() -> void:
<<<<<<< HEAD:Scripts/main_menu.gd
	print("Opening Settings...")


func _on_exit_pressed() -> void:
	get_tree().quit()
=======
	$"/root/MainMenu/Settings".visible = !$"/root/MainMenu/Settings".visible

func _on_exit_settings_pressed() -> void:
	$"/root/MainMenu/Settings".visible = false

func _on_credits_pressed() -> void:
	$"/root/MainMenu/Credits".visible = true

func _on_exit_credits_pressed() -> void:
	$"/root/MainMenu/Credits".visible = false
>>>>>>> origin/SoiSauce:Scripts/UI/MainMenu.gd
