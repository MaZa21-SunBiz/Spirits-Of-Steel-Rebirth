extends Control

@onready var audio = $Audio
@onready var saves = $Saves
@onready var graphics = $Graphics
@onready var save_list = $Saves/VBoxContainer/savelist
@onready var line_edit = $Saves/VBoxContainer/HBoxContainer/TextEdit

enum Section { SAVE, AUDIO, SETTINGS, EXIT }

func _ready():
	_refresh_saves()

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


func _on_save_load_pressed():
	saves.visible = !saves.visible
	audio.visible = false
	graphics.visible = false

func _on_audio_pressed():
	audio.visible = !audio.visible
	saves.visible = false
	graphics.visible = false

func _on_graphics_pressed():
	graphics.visible = !graphics.visible
	saves.visible = false
	audio.visible = false

func _on_sfx_changed(value: float) -> void:
	MusicManager.set_sfx_volume(value)

func _on_music_changed(value: float) -> void:
	MusicManager.set_music_volume(value)

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
		# _switch_section(Section.SAVE) # Refresh
	)

	hbox.add_child(load_btn)
	hbox.add_child(del_btn)
	parent.add_child(hbox)

func _on_save_game_pressed():
	var file_name = line_edit.text.strip_edges()
	GameState.current_world.save_game(file_name)
	_refresh_saves()
	# _switch_section(Section.SAVE) # Refresh list
