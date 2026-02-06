extends CanvasLayer

var sidebar_panel: PanelContainer
var summary_label: Label
var stats_label: Label
var loser_label: Label

var current_winner: CountryData
var current_loser: CountryData
var provinces_to_take: Array = []
var hovered_pid: int = -1

# Color Palette
const COLOR_BG = Color(0.1, 0.1, 0.12, 0.98)
const COLOR_GOLD = Color(0.85, 0.65, 0.2)
const COLOR_SELECT = Color(0.0, 1.0, 0.8)  # Cyan/Teal for treaty selection
const COLOR_DANGER = Color(0.7, 0.2, 0.2)


func _ready() -> void:
	_setup_ui_elements()
	self.hide()


func _input(event: InputEvent) -> void:
	if not self.visible:
		return

	# 1. Ignore input if clicking on the sidebar itself
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.x < sidebar_panel.size.x:
		return

	# 2. Convert Screen position to Map/World position
	# We use the World's camera to get the correct global coordinates
	var world = GameState.current_world
	if not world:
		return

	var map_pos = world.get_global_mouse_position()

	# 3. Handle Hover/Click using the world-mapped coordinates
	if event is InputEventMouseMotion:
		_process_hover(map_pos)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_process_click(map_pos)


func _process_hover(map_pos: Vector2):
	# 1. Get the PID using your radius logic
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)

	if pid != hovered_pid:
		# 2. Reset the visual of the PREVIOUS hovered province
		if hovered_pid > 1:
			_reset_province_visual(hovered_pid)

		hovered_pid = pid

		# 3. Apply NEW hover visual (if it's a valid land province belonging to the loser)
		if hovered_pid > 1:
			var owner = MapManager.province_to_country.get(hovered_pid, "")
			if owner == current_loser.country_name:
				_update_map_visual(hovered_pid, Color(1.5, 1.5, 1.5))
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process_click(map_pos: Vector2):
	var pid = get_province_with_radius(map_pos, GameState.current_world.map_sprite, 5)
	if pid <= 1:
		return

	var owner_name = MapManager.province_to_country.get(pid, "")
	if owner_name != current_loser.country_name:
		return

	if provinces_to_take.has(pid):
		provinces_to_take.erase(pid)
		# On deselect, return to hover state or normal state
		_update_map_visual(pid, Color(1.5, 1.5, 1.5))
	else:
		provinces_to_take.append(pid)
		# On select, make it a distinct color (e.g., Cyan or the Player's color)
		_update_map_visual(pid, Color(0.0, 1.0, 1.0))

	_update_summary()


func _setup_ui_elements():
	# Sidebar Setup
	sidebar_panel = PanelContainer.new()
	sidebar_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	var screen_width = get_viewport().get_visible_rect().size.x
	sidebar_panel.custom_minimum_size.x = screen_width * 0.22  # Slightly slimmer

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_width_right = 4
	style.border_color = COLOR_GOLD
	style.shadow_size = 10
	sidebar_panel.add_theme_stylebox_override("panel", style)
	add_child(sidebar_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	sidebar_panel.add_child(margin)

	var v_box = VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 25)
	margin.add_child(v_box)

	# --- Header ---
	var title = Label.new()
	title.text = "PEACE TREATY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	v_box.add_child(title)

	var h_sep = ColorRect.new()
	h_sep.custom_minimum_size.y = 2
	h_sep.color = COLOR_GOLD
	v_box.add_child(h_sep)

	loser_label = Label.new()
	loser_label.add_theme_font_size_override("font_size", 18)
	loser_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v_box.add_child(loser_label)

	# --- Stats Panel ---
	var stats_bg = PanelContainer.new()
	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color(0, 0, 0, 0.3)
	s_style.set_corner_radius_all(5)
	stats_bg.add_theme_stylebox_override("panel", s_style)
	v_box.add_child(stats_bg)

	var stats_margin = MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_all", 15)
	stats_bg.add_child(stats_margin)

	var stats_vbox = VBoxContainer.new()
	stats_margin.add_child(stats_vbox)

	summary_label = Label.new()
	summary_label.text = "Provinces Selected: 0"
	stats_vbox.add_child(summary_label)

	stats_label = Label.new()
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stats_vbox.add_child(stats_label)

	# --- Buttons ---
	v_box.add_spacer(false)  # Pushes buttons to bottom

	var annex_btn = _create_styled_button("ANNEX ALL", Color(0.3, 0.5, 0.3))
	annex_btn.pressed.connect(_on_annex_all_pressed)
	v_box.add_child(annex_btn)

	var puppet_btn = _create_styled_button("PUPPET COUNTRY", Color(0.5, 0.3, 0.3))
	puppet_btn.pressed.connect(_on_puppet_pressed)
	v_box.add_child(puppet_btn)

	var clear_btn = _create_styled_button("RESET SELECTION", Color(0.4, 0.4, 0.4))
	clear_btn.pressed.connect(_on_clear_selection_pressed)
	v_box.add_child(clear_btn)

	var confirm_btn = _create_styled_button("SIGN TREATY", COLOR_GOLD)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	v_box.add_child(confirm_btn)


func _create_styled_button(btn_text: String, accent_color: Color) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size.y = 45
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = accent_color * 0.6
	style_normal.border_width_bottom = 4
	style_normal.border_color = accent_color * 0.4
	style_normal.set_corner_radius_all(3)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = accent_color * 0.8

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn


func _on_annex_all_pressed():
	provinces_to_take.clear()
	# Iterate through MapManager to find all provinces belonging to loser
	for pid in MapManager.province_to_country.keys():
		if MapManager.province_to_country[pid] == current_loser.country_name:
			provinces_to_take.append(pid)
			_update_map_visual(pid, COLOR_SELECT)
	_update_summary()


func _on_puppet_pressed():
	current_winner.allowedCountries.append(current_loser.country_name)
	current_winner.puppets.append(current_loser.country_name)
	print(current_winner.puppets)
	_update_summary()

func _on_clear_selection_pressed():
	for pid in provinces_to_take:
		_reset_province_visual_immediate(pid)
	provinces_to_take.clear()
	_update_summary()

func _reset_province_visual_immediate(pid: int):
	var owner = MapManager.province_to_country[pid]
	var original_color = MapManager.country_colors.get(owner, Color.WHITE)
	_update_map_visual(pid, original_color)


# --- Logic & Integration ---


func open_menu(winner: CountryData, loser: CountryData):
	self.show()
	current_winner = winner
	current_loser = loser
	provinces_to_take.clear()
	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = false
	GameState.current_world.clock.pause()
	loser_label.text = "Negotations: %s" % loser.country_name
	GameState.in_peace_process = true
	_update_summary()


func _update_summary():
	summary_label.text = "Provinces Selected: %d" % provinces_to_take.size()

	# Calculate percentage for flavor
	var total_loser_provinces = 0
	for p in MapManager.province_to_country.values():
		if p == current_loser.country_name:
			total_loser_provinces += 1

	if total_loser_provinces > 0:
		var percent = (float(provinces_to_take.size()) / total_loser_provinces) * 100
		stats_label.text = "Total Country Loss: %d%%" % int(percent)


func _on_confirm_pressed():
	for pid in provinces_to_take:
		MapManager.transfer_ownership(pid, current_winner.country_name)

	var game_ui = get_tree().root.find_child("ui_game", true, false)
	if game_ui:
		game_ui.visible = true
	GameState.in_peace_process = false
	GameState.current_world.clock.resume()

	self.hide()


# Your existing logic function
func get_province_with_radius(global_pos: Vector2, map_sprite: Sprite2D, radius: int) -> int:
	# This uses the code logic you already have in MapManager
	return MapManager.get_province_with_radius(global_pos, map_sprite, radius)


func _update_map_visual(pid: int, color: Color):
	# We call MapManager's lookup update to refresh the shader texture
	if MapManager.has_method("_update_lookup"):
		MapManager._update_lookup(pid, color)


func _reset_province_visual(pid: int):
	# If it's currently selected, keep the selected color
	if provinces_to_take.has(pid):
		_update_map_visual(pid, Color(0.0, 1.0, 1.0))
	else:
		# Otherwise, revert to the original country color
		var country = MapManager.province_to_country[pid]
		if country != "sea":
			var original_color = MapManager.country_colors[country]
			_update_map_visual(pid, original_color)
