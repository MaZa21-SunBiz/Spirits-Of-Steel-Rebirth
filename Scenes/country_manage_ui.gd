extends CanvasLayer
class_name CountryManageUI

#region --- Nodes ---
var main_container: MarginContainer
var category_hbox: HBoxContainer
var laws_grid: VBoxContainer # Changed to VBox for a cleaner list feel

# Header & Stats
var header_label: Label
var flag_rect: TextureRect

# Data
enum Category {MILITARY, ECONOMY, COUNTRY, RELEASABLES}
var current_category: Category = Category.MILITARY
var current_country: CountryData
var _update_timer: float = 0.0

const LOGISTICS_SCENE = preload("res://Scenes/logistics.tscn")
var economic_status_val: Label
var army_logistics_val: Label
#endregion

func _ready() -> void:
	visible = false
	#_build_ui()

func open_menu(country: CountryData) -> void:
	current_country = country
	_build_ui()
	_switch_category(Category.MILITARY) # Default to Military
	_refresh_full_data()
	show()

func close_menu() -> void:
	hide()

func _process(delta: float) -> void:
	if not visible or not current_country: return
	
	_update_timer += delta
	if _update_timer > 1.0:
		_update_timer = 0.0
		_refresh_army_counts()

#region --- UI Construction ---

func _build_ui() -> void:
	# Reference shorthand - main_vbox is relative to 'self' (the CanvasLayer)
	var main_vbox = get_node("PanelContainer/VBoxContainer")
	
	# Mapping Node References
	flag_rect = main_vbox.get_node("HBoxContainer/nation_flag")
	header_label = main_vbox.get_node("HBoxContainer/Label")
	
	# Data Labels
	var eco_hbox = main_vbox.get_node("HBoxContainer2/VBoxContainer/VBoxContainer2/HBoxContainer")
	economic_status_val = eco_hbox.get_node("Values")
	
	var army_hbox = main_vbox.get_node("HBoxContainer2/VBoxContainer/VBoxContainer/HBoxContainer2")
	army_logistics_val = army_hbox.get_node("Value")
	
	# Dismiss Button
	var dismiss_btn = main_vbox.get_node("HBoxContainer/Button")
	dismiss_btn.pressed.connect(close_menu)
	
	# Category Tabs
	var tabs_hbox = main_vbox.get_node("HBoxContainer2/VBoxContainer2/HBoxContainer")
	laws_grid = main_vbox.get_node("HBoxContainer2/VBoxContainer2/ScrollContainer/VBoxContainer")
	
	# Connect existing category buttons in the scene
	var btn_mil = tabs_hbox.get_node("MilitaryTab")
	btn_mil.pressed.connect(_switch_category.bind(Category.MILITARY))
	
	var btn_eco = tabs_hbox.get_node("EconomicTab")
	btn_eco.pressed.connect(_switch_category.bind(Category.ECONOMY))
	
	var btn_cnt = tabs_hbox.get_node("CountryTab")
	btn_cnt.pressed.connect(_switch_category.bind(Category.COUNTRY))
	
	var btn_rel = tabs_hbox.get_node("ReleasableTab")
	btn_rel.pressed.connect(_switch_category.bind(Category.RELEASABLES))

#endregion

#region --- Category Management ---

func _switch_category(cat: Category) -> void:
	current_category = cat
	
	# Update Button Visuals (Scene buttons are standard Buttons, not naturally toggle grouped here)
	# We'll just modulate or use styles if needed, but for now let's just switch
	
	# Clear Current List
	for child in laws_grid.get_children():
		child.queue_free()

	# Populate based on selection
	match current_category:
		Category.MILITARY: _populate_military()
		Category.ECONOMY: _populate_economy()
		Category.COUNTRY: _populate_country()
		Category.RELEASABLES: _populate_releasables(current_country.country_name)
	
	_update_law_buttons_visuals()

func _populate_military() -> void:
	_add_law_option("Volunteer Only", 0.005, 0.0, 0, "Professional army.")
	_add_law_option("Limited Conscription", 0.01, 0.05, 150, "Drafting young men.")
	_add_law_option("Extensive Conscription", 0.015, 0.15, 150, "Wide-scale mobilization.")
	_add_law_option("Service by Requirement", 0.02, 0.30, 150, "All eligible adults.")
	_add_law_option("All Adult Serve", 0.4, 0.50, 150, "Scraping the barrel.")

func _populate_economy() -> void:
	var lbl = Label.new()
	lbl.text = "Economy laws coming soon..."
	laws_grid.add_child(lbl)

func _populate_country() -> void:
	var lbl = Label.new()
	lbl.text = "Country decisions coming soon..."
	laws_grid.add_child(lbl)

func _populate_releasables(player_country: String) -> void:
	for child in laws_grid.get_children():
		child.queue_free()

	var releasables = MapManager.get_all_releasables(player_country)

	if releasables.is_empty():
		var lbl = Label.new()
		lbl.text = "No nations to release."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		laws_grid.add_child(lbl)
	else:
		for releasable_data in releasables:
			_add_releasable_option(releasable_data)
#endregion

#region --- Logic & Data Refresh ---
func _refresh_full_data() -> void:
	if not current_country:
		return
	header_label.text = current_country.country_name.to_upper()

	# Attempt to load specific flag, fallback to grey placeholder
	var flag_path = "res://assets/flags/%s_flag.png" % current_country.country_name
	if ResourceLoader.exists(flag_path):
		flag_rect.texture = load(flag_path)

	_refresh_army_counts()
	_update_law_buttons_visuals()


func _refresh_army_counts() -> void:
	# 1. Economic Status
	var eco_txt = ""
	eco_txt += "$%s\n" % _format_money(current_country.money)
	eco_txt += "%.1f\n" % current_country.political_power
	eco_txt += "+$%.1f\n" % (current_country.gdp / 8760.0 * 0.2)
	eco_txt += "+$%.1f\n" % (current_country.factories_amount * current_country.factory_income)
	eco_txt += "-$%.1f" % current_country.army_cost
	
	if economic_status_val:
		economic_status_val.text = eco_txt

	# 2. Army Logistics
	var counts = {"infantry": 0, "tank": 0, "artillery": 0}
	var troops = TroopManager.get_troops_for_country(current_country.country_name)

	for troop in troops:
		for div in troop.stored_divisions:
			if counts.has(div.type):
				counts[div.type] += 1
			else:
				counts[div.type] = 1

	var max_man = int(current_country.total_population * current_country.military_size_ratio)
	var army_txt = ""
	army_txt += "%s / %s\n" % [_format_number(current_country.manpower), _format_number(max_man)]
	army_txt += "%d\n" % counts.get("infantry", 0)
	army_txt += "%d\n" % counts.get("tank", 0)
	army_txt += "%d" % counts.get("artillery", 0)
	
	if army_logistics_val:
		army_logistics_val.text = army_txt


func _update_law_buttons_visuals() -> void:
	if not laws_grid: return
	for btn in laws_grid.get_children():
		# Safety check: make sure this child has the metadata we expect
		if not btn.has_meta("ratio") and not btn.has_meta("country_id"):
			continue

		# Handle Military Laws
		if btn.has_meta("ratio"):
			var law_ratio = btn.get_meta("ratio")
			var cost = btn.get_meta("cost")
			var is_active = is_equal_approx(current_country.military_size_ratio, law_ratio)

			var hbox = btn.get_child(0).get_child(0) # Panel -> MarginContainer -> HBox

			var _title_lbl = hbox.get_node("Title")
			var status_lbl = hbox.get_node("Status")
			var cost_lbl = hbox.get_node("Cost")

			# Reset Style
			var style = btn.get_theme_stylebox("panel").duplicate()

			# NOTE(soi): dear god fix this
			if is_active:
				style.bg_color = Color(0.2, 0.4, 0.2, 0.9) # Dark Green
				style.border_color = Color(0.4, 0.8, 0.4) # COLOR_POSITIVE
				status_lbl.text = " ACTIVE"
				status_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
				cost_lbl.visible = false
				btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
			else:
				status_lbl.text = ""
				cost_lbl.visible = true

				if current_country.political_power >= cost:
					cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2)) # COLOR_WARNING
					btn.modulate = Color(1, 1, 1, 1)
					btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				else:
					cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3)) # COLOR_NEGATIVE
					btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
					btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			btn.add_theme_stylebox_override("panel", style)
		# Handle Releasable Nations
		elif btn.has_meta("country_id"):
			var cost = btn.get_meta("cost")
			var hbox = btn.get_child(0).get_child(0) # Panel -> MarginContainer -> HBox
			var cost_lbl = hbox.get_node("Cost")

			var style = btn.get_theme_stylebox("panel").duplicate()

			if current_country.political_power >= cost:
				style.bg_color = Color(0.15, 0.16, 0.19, 1.0) # COLOR_PANEL_INNER
				style.border_color = Color(0.3, 0.3, 0.3)
				cost_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2)) # COLOR_WARNING
				btn.modulate = Color(1, 1, 1, 1)
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				style.bg_color = Color(0.15, 0.16, 0.19, 1.0) # COLOR_PANEL_INNER
				style.border_color = Color(0.3, 0.3, 0.3)
				cost_lbl.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3)) # COLOR_NEGATIVE
				btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
				btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			btn.add_theme_stylebox_override("panel", style)

#endregion

func _add_releasable_option(country_id: String) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 55) # Slimmer height for HBox layout
	
	# 1. Styling
	# var style = StyleBoxFlat.new()
	# style.bg_color = Color(0.12, 0.12, 0.14)
	# style.border_color = Color(0.25, 0.25, 0.3)
	# style.set_border_width_all(1)
	# style.set_corner_radius_all(4)
	# btn_panel.add_theme_stylebox_override("panel", style)

	# 2. Main Layout
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	btn_panel.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	m.add_child(hbox)

	# 3. Flag
	var flag = TextureRect.new()
	flag.custom_minimum_size = Vector2(40, 26)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.texture = TroopManager.get_flag(country_id)
	hbox.add_child(flag)

	# 4. Text Info (Expand to push buttons to the right)
	var v_text = VBoxContainer.new()
	v_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(v_text)

	var title = Label.new()
	title.text = country_id.capitalize().replace("_", " ")
	title.add_theme_font_size_override("font_size", 14)
	v_text.add_child(title)

	# PP Cost Label
	var cost_lbl = Label.new()
	cost_lbl.text = "Cost: 50 PP"
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
	v_text.add_child(cost_lbl)

	# 5. Buttons HBox (The Action Area)
	var h_btns = HBoxContainer.new()
	h_btns.add_theme_constant_override("separation", 8)
	h_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(h_btns)

	# --- Button: Release ---
	var btn_release = Button.new()
	btn_release.text = "Release"
	btn_release.custom_minimum_size = Vector2(80, 30)
	btn_release.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_release.pressed.connect(_on_release_pressed.bind(country_id))
	h_btns.add_child(btn_release)

	# --- Button: Play As (Distinct style) ---
	var btn_play = Button.new()
	btn_play.text = "Play As"
	btn_play.custom_minimum_size = Vector2(80, 30)
	btn_play.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Optional: Give 'Play As' a slightly blue-ish tint to distinguish it
	btn_play.add_theme_color_override("font_hover_color", Color(0.5, 0.8, 1.0))
	
	btn_play.pressed.connect(_on_release_and_play_pressed.bind(country_id))
	h_btns.add_child(btn_play)

	laws_grid.add_child(btn_panel)

func _on_release_pressed(country_id: String) -> void:
	if current_country.political_power >= 50:
		current_country.political_power -= 50
		MapManager.release_country(country_id)
		# Refresh UI
		_populate_releasables(current_country.country_name)
	else:
		Console.print_error("Not enough Political Power!")

func _on_release_and_play_pressed(country_id: String) -> void:
	if current_country.political_power >= 50:
		# 1. Release the land
		MapManager.release_country(country_id)
		CountryManager.set_player_country(country_id)
		Console.print_info("Switched playing as: " + country_id)
		
		_populate_releasables(country_id)
	else:
		Console.print_error("Not enough Political Power!")

func _add_law_option(
	_name: String, ratio: float, eco_penalty: float, cost: int, _tooltip: String
) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 50)

	# Metadata storage for logic
	btn_panel.set_meta("ratio", ratio)
	btn_panel.set_meta("penalty", eco_penalty)
	btn_panel.set_meta("cost", cost)

	# var style = StyleBoxFlat.new()
	# style.corner_radius_top_left = 6
	# style.corner_radius_top_right = 6
	# style.corner_radius_bottom_right = 6
	# style.corner_radius_bottom_left = 6
	# style.border_width_left = 1
	# style.border_width_top = 1
	# style.border_width_right = 1
	# style.border_width_bottom = 1
	# btn_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 5)
	m.add_theme_constant_override("margin_right", 5)
	btn_panel.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	m.add_child(hbox)

	var title = Label.new()
	title.name = "Title"
	title.text = _name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Effect info (small text)
	var effect_lbl = Label.new()
	effect_lbl.text = "Pop: %.2f%% | Eco: -%.0f%%" % [ratio * 100.0, eco_penalty * 100.0]
	effect_lbl.add_theme_font_size_override("font_size", 12)

	var cost_lbl = Label.new()
	cost_lbl.name = "Cost"
	cost_lbl.text = "%d PP" % cost

	var status_lbl = Label.new()
	status_lbl.name = "Status"
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 12)

	hbox.add_child(title)
	hbox.add_child(effect_lbl)
	hbox.add_child(VSeparator.new())
	hbox.add_child(cost_lbl)
	hbox.add_child(status_lbl)

	# Make it clickable
	btn_panel.gui_input.connect(_on_law_gui_input.bind(btn_panel))

	laws_grid.add_child(btn_panel)


#endregion


#region --- Interactions ---

func _on_releasable_gui_input(event: InputEvent, panel: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var country_id = panel.get_meta("country_id")
		var cost = panel.get_meta("cost")
		
		# Assuming you have a global 'PlayerData' or similar for Political Power
		if current_country.political_power >= cost:
			current_country.political_power -= cost
			MapManager.release_country(country_id)
			
			# Refresh the UI since the list might change after a release
			_populate_releasables(current_country.country_name)
			
			print("Successfully released ", country_id)
		else:
			print("Not enough Political Power!")
			# Optional: Play a "buzz" error sound or shake the panel

func _on_law_gui_input(event: InputEvent, btn: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ratio = btn.get_meta("ratio")
		var penalty = btn.get_meta("penalty")
		var cost = btn.get_meta("cost")

		# 1. Is this already active?
		if is_equal_approx(current_country.military_size_ratio, ratio):
			return # Do nothing

		# 2. Can we afford it?
		if current_country.political_power >= cost:
			# Execute Change
			current_country.political_power -= cost
			current_country.military_size_ratio = ratio
			current_country.economy_law_penalty = penalty

			current_country.update_manpower_pool() # Recalc based on new ratio

			# Refresh UI
			_update_law_buttons_visuals()
			_refresh_full_data()
			print("Law enacted: ", ratio)
		else:
			# Optional: Shake animation or error sound
			print("Not enough Political Power!")


# Utils
func _format_money(amount: float) -> String:
	if amount >= 1000000:
		return "%.2fM" % (amount / 1000000.0)
	if amount >= 1000:
		return "%.2fK" % (amount / 1000.0)
	return "%.2f" % amount


func _format_number(amount: int) -> String:
	if amount >= 1000000:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 1000:
		return "%.1fK" % (amount / 1000.0)
	return str(amount)
#endregion
