extends CanvasLayer
class_name SystemMenuUI

# --- Theme ---
var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")

# Values for the sliders (0.0 to 1.0)
var master_music_mult: float = 1.0
var master_sfx_mult: float = 1.0

var content_area = $"Menu/PanelContainer2/VBoxContainer"

enum Section { SAVE, AUDIO, SETTINGS, EXIT }

func _ready() -> void:
	visible = false

func toggle_menu() -> void:
	visible = !visible
	if visible:
		# Center every time it opens just in case window resized
		main_panel.set_anchors_preset(Control.PRESET_CENTER)
		_switch_section(Section.SAVE)
		MusicManager.play_sfx(MusicManager.SFX.OPEN_MENU)

#region --- Helpers ---

func _switch_section(sec: Section) -> void:
	for c in content_area.get_children(): c.queue_free()
	
	match sec:
		Section.AUDIO: _draw_audio_menu()
		Section.SAVE: _draw_save_menu() # Updated
		Section.EXIT: _draw_exit_confirm()

func _add_map_slider_row(parent: Node, label: String, current_val: float, max_v: float, callback: Callable) -> void:
	var row_vbox = VBoxContainer.new()
	
	var lbl = Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.8, 0.8, 0.8)
	if custom_font: lbl.add_theme_font_override("font", custom_font)

	var hbox = HBoxContainer.new()
	var slider = HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.0
	slider.max_value = max_v # Allow going up to 200% volume for quiet files
	slider.step = 0.01
	slider.value = current_val
	
	var val_text = Label.new()
	val_text.custom_minimum_size = Vector2(40, 0)
	val_text.text = str(int((current_val / max_v) * 100)) + "%"
	
	slider.value_changed.connect(callback)
	slider.value_changed.connect(func(v): val_text.text = str(int((v / max_v) * 100)) + "%")
	
	hbox.add_child(slider)
	hbox.add_child(val_text)
	row_vbox.add_child(lbl)
	row_vbox.add_child(hbox)
	parent.add_child(row_vbox)

func _add_sub_header(parent: Node, txt: String) -> void:
	var l = Label.new()
	l.text = txt
	l.modulate = COLOR_ACCENT
	if custom_font: l.add_theme_font_override("font", custom_font)
	parent.add_child(l)
	
func _add_header(txt: String) -> void:
	var l = Label.new()
	l.text = txt
	if custom_font: l.add_theme_font_override("font", custom_font)
	l.add_theme_font_size_override("font_size", 24)
	l.modulate = COLOR_ACCENT
	content_area.add_child(l)

func _draw_exit_confirm() -> void:
	_add_header("Exit")
	var btn = Button.new()
	btn.text = "Exit the Game"
	btn.modulate = Color(1, 0.3, 0.3)
	btn.pressed.connect(get_tree().quit)
	content_area.add_child(btn)
#endregion

#region --- Save & Load Logic ---

func _draw_save_menu() -> void:
	_add_header("Save & Load Game")

	# --- 1. NEW SAVE SECTION ---
	var save_input_hbox = HBoxContainer.new()
	save_input_hbox.add_theme_constant_override("separation", 10)
	content_area.add_child(save_input_hbox)

	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Enter save name..."
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_input_hbox.add_child(line_edit)

	var save_btn = Button.new()
	save_btn.text = "Save New"
	save_btn.disabled = true # Start disabled
	save_input_hbox.add_child(save_btn)

	# Enable button only if text is not empty
	line_edit.text_changed.connect(
		func(new_text): 
			save_btn.disabled = new_text.strip_edges().is_empty()
	)

	save_btn.pressed.connect(
		func():
			GameState.current_world.save_game(line_edit.text.strip_edges())
			_switch_section(Section.SAVE) # Refresh list
	)

	content_area.add_child(HSeparator.new())

	# --- 2. LOAD SECTION ---
	_add_sub_header(content_area, "Existing Saves")
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(scroll)

	var save_list = VBoxContainer.new()
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(save_list)

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
		toggle_menu() 
	)
	
	var del_btn = Button.new()
	del_btn.text = "X"
	del_btn.modulate = Color(1, 0.4, 0.4)
	del_btn.pressed.connect(func():
		DirAccess.remove_absolute("res://saves/" + save_name + ".tres")
		_switch_section(Section.SAVE) # Refresh
	)

	hbox.add_child(load_btn)
	hbox.add_child(del_btn)
	parent.add_child(hbox)

#endregion
