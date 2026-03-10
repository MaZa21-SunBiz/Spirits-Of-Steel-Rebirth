extends CanvasLayer

const SAVE_DIR = "user://saves/"


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


func _process(delta: float) -> void:
	if GameState.camera:
		GameState.camera.move_map_around(delta)
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
	ConsoleManager.switch_scene("select")


func _on_load_game_pressed() -> void:
	print("Opening save browser...")


func _on_map_editor_pressed() -> void:
	ConsoleManager.switch_scene("editor")

func _on_start() -> void:
	if CountryManager.player_country:
		get_tree().change_scene_to_packed(preload("res://Scenes/main.tscn"))

func _on_settings_pressed() -> void:
	print("Opening Settings...")


func _on_exit_pressed() -> void:
	get_tree().quit()
