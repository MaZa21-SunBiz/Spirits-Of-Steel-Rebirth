extends CanvasLayer
class_name CountryManageUI

#region --- Theme Configuration ---
const COLOR_BG_GLASS = Color(0.08, 0.09, 0.11, 0.96)
const COLOR_PANEL_INNER = Color(0.15, 0.16, 0.19, 1.0)
const COLOR_ACCENT = Color(0.24, 0.65, 0.85)
const COLOR_TEXT_HEADER = Color(0.9, 0.9, 0.9)
const COLOR_TEXT_DIM = Color(0.6, 0.6, 0.6)
const COLOR_POSITIVE = Color(0.4, 0.8, 0.4)
const COLOR_NEGATIVE = Color(0.85, 0.3, 0.3)
const COLOR_WARNING = Color(0.9, 0.7, 0.2)
#endregion

#region --- Nodes ---
var main_container: MarginContainer
var category_hbox: HBoxContainer
var laws_grid: VBoxContainer  # Changed to VBox for a cleaner list feel

# Header & Stats
var header_label: Label
var flag_rect: TextureRect
var pp_label: Label
var money_display: Label
var manpower_display: Label

# Composition Labels
var comp_infantry: Label
var comp_tank: Label
var comp_artillery: Label
var income_breakdown_label: RichTextLabel

# Data
enum Category { MILITARY, ECONOMY, COUNTRY, RELEASABLES }
var current_category: Category = Category.MILITARY
var current_country: CountryData
var _update_timer: float = 0.0
#endregion


func _ready() -> void:
	visible = false
	#_build_ui()


func open_menu(country: CountryData) -> void:
	current_country = country
	_build_ui()
	_switch_category(Category.MILITARY)  # Default to Military
	_refresh_full_data()
	show()


func close_menu() -> void:
	hide()


func _process(delta: float) -> void:
	if not visible or not current_country:
		return
	money_display.text = "$%s" % _format_money(current_country.money)
	pp_label.text = "%.1f PP" % current_country.political_power

	_update_timer += delta
	if _update_timer > 1.0:
		_update_timer = 0.0
		_refresh_army_counts()


#region --- UI Construction ---


func _build_ui() -> void:
	main_container = MarginContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 40)
	main_container.add_theme_constant_override("margin_right", 40)
	main_container.add_theme_constant_override("margin_top", 40)
	main_container.add_theme_constant_override("margin_bottom", 40)
	add_child(main_container)

	var bg_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_GLASS
#	style.corner_radius_all(8)
#	style.border_width_all(2)
	style.border_color = Color(0.3, 0.35, 0.4)
	bg_panel.add_theme_stylebox_override("panel", style)
	main_container.add_child(bg_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_all", 20)
	content_margin.add_child(vbox)
	bg_panel.add_child(content_margin)

	_build_header(vbox)

	var split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 30)
	vbox.add_child(split)

	_build_left_column(split)
	_build_right_column(split)


func _build_header(parent: VBoxContainer) -> void:
	var header_hbox = HBoxContainer.new()
	flag_rect = TextureRect.new()
	flag_rect.custom_minimum_size = Vector2(100, 60)
	flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	flag_rect.texture = TroopManager.get_flag(current_country.country_name)

	var title_vbox = VBoxContainer.new()
	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 28)
	pp_label = Label.new()
	pp_label.add_theme_color_override("font_color", COLOR_WARNING)
	title_vbox.add_child(header_label)
	title_vbox.add_child(pp_label)

	var close_btn = Button.new()
	close_btn.text = " DISMISS "
	close_btn.pressed.connect(close_menu)

	header_hbox.add_child(flag_rect)
	header_hbox.add_child(VSeparator.new())
	header_hbox.add_child(title_vbox)
	header_hbox.add_spacer(false)
	header_hbox.add_child(close_btn)
	parent.add_child(header_hbox)
	parent.add_child(HSeparator.new())


func _build_left_column(parent: HBoxContainer) -> void:
	var left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 0.4
	parent.add_child(left_col)

	_create_section_header(left_col, "Economic Status")
	money_display = _create_stat_row(left_col, "Treasury", "$0.00")
	income_breakdown_label = RichTextLabel.new()
	income_breakdown_label.bbcode_enabled = true
	income_breakdown_label.fit_content = true
	left_col.add_child(income_breakdown_label)

	left_col.add_child(HSeparator.new())
	_create_section_header(left_col, "Army Logistics")
	manpower_display = _create_stat_row(left_col, "Active Personnel", "0")

	# Composition
	var comp_vbox = VBoxContainer.new()
	comp_vbox.add_theme_constant_override("separation", 4)
	comp_infantry = _create_simple_row(comp_vbox, "Infantry")
	comp_tank = _create_simple_row(comp_vbox, "Armor")
	comp_artillery = _create_simple_row(comp_vbox, "Artillery")
	left_col.add_child(comp_vbox)


func _build_right_column(parent: HBoxContainer) -> void:
	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 0.6
	parent.add_child(right_col)

	# Category Tabs
	category_hbox = HBoxContainer.new()
	category_hbox.add_theme_constant_override("separation", 5)
	right_col.add_child(category_hbox)

	_add_category_button("MILITARY", Category.MILITARY)
	_add_category_button("ECONOMY", Category.ECONOMY)
	_add_category_button("COUNTRY", Category.COUNTRY)
	_add_category_button("RELEASABLES", Category.RELEASABLES)

	right_col.add_child(HSeparator.new())

	# Laws Container with Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.add_child(scroll)

	laws_grid = VBoxContainer.new()
	laws_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	laws_grid.add_theme_constant_override("separation", 10)
	scroll.add_child(laws_grid)


#endregion

#region --- Category Management ---


func _add_category_button(label: String, cat: Category) -> void:
	var btn = Button.new()
	btn.text = "  %s  " % label
	btn.toggle_mode = true
	btn.pressed.connect(_switch_category.bind(cat))
	category_hbox.add_child(btn)


func _switch_category(cat: Category) -> void:
	current_category = cat

	# Update Button Visuals
	for i in category_hbox.get_child_count():
		category_hbox.get_child(i).button_pressed = (i == cat)

	# Clear Current List
	for child in laws_grid.get_children():
		child.queue_free()

	# Populate based on selection
	match current_category:
		Category.MILITARY:
			_populate_military()
		Category.ECONOMY:
			_populate_economy()
		Category.COUNTRY:
			_populate_country()
		Category.RELEASABLES:
			_populate_releasables(current_country.country_name)

	_update_law_buttons_visuals()


func _populate_military() -> void:
	_add_law_option("Volunteer Only", 0.005, 0.0, 0, "Professional army.")
	_add_law_option("Limited Conscription", 0.01, 0.05, 150, "Drafting young men.")
	_add_law_option("Extensive Conscription", 0.015, 0.15, 150, "Wide-scale mobilization.")
	_add_law_option("Service by Requirement", 0.02, 0.30, 150, "All eligible adults.")
	_add_law_option("All Adult Serve", 0.4, 0.50, 150, "Scraping the barrel.")


func _populate_economy() -> void:
	_add_economy_law_option("Civilian Economy", 0.30, 100, "Conscription limit penalty. Focus on consumer goods.")
	_add_economy_law_option("Early Mobilization", 0.15, 150, "Reduced economy penalty.")
	_add_economy_law_option("War Economy", 0.0, 150, "Optimal economy. Focus on weapon factories.")
	_add_economy_law_option("Total Mobilization", -0.10, 150, "Conscription capacity penalty. Income bonus +10%.")


func _populate_country() -> void:
	_add_decision_option("Political Propaganda", 50, 0, "+15% Stability", "propaganda_stability")
	_add_decision_option("War Propaganda", 50, 0, "+15% War Support", "propaganda_war_support")
	_add_decision_option("Industrial Effort", 100, 5000, "+1 Factory", "industrial_effort")
	_add_decision_option("Naval Infrastructure", 75, 3000, "+1 Port in coastal province", "naval_infrastructure")
	_add_decision_option("Military Maneuvers", 50, 0, "Level up army & +10% speed", "military_maneuvers")


func _populate_releasables(player_country: String) -> void:
	for child in laws_grid.get_children():
		child.queue_free()

	var releasables = MapManager.get_all_releasables(player_country)

	if releasables.is_empty():
		var lbl = Label.new()
		lbl.text = "No nations to release."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # COLOR_TEXT_DIM
		laws_grid.add_child(lbl)
		return

	for country_id in releasables:
		_add_releasable_option(country_id)


#endregion


func _add_releasable_option(country_id: String) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 55)  # Slimmer height for HBox layout

	# 1. Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn_panel.add_theme_stylebox_override("panel", style)

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


#region --- Logic & Data Refresh ---
func _refresh_full_data() -> void:
	if not current_country:
		return
	header_label.text = current_country.country_name.to_upper()

	# Attempt to load specific flag, fallback to grey placeholder
	var flag_path = "res://flags/%s.png" % current_country.country_name
	if ResourceLoader.exists(flag_path):
		flag_rect.texture = load(flag_path)

	_refresh_army_counts()
	_update_law_buttons_visuals()


func _refresh_army_counts() -> void:
	# Recalculate army composition
	var counts = {"infantry": 0, "tank": 0, "artillery": 0}

	# Assuming TroopManager has this function as per your previous code
	var troops = TroopManager.get_troops_for_country(current_country.country_name)
	var total_divs = 0

	for troop in troops:
		for div in troop.stored_divisions:
			total_divs += 1
			# Assuming 'type' is a string key
			if counts.has(div.type):
				counts[div.type] += 1
			else:
				# Handle types we didn't hardcode
				counts[div.type] = 1

	comp_infantry.text = str(counts.get("infantry", 0))
	comp_tank.text = str(counts.get("tank", 0))
	comp_artillery.text = str(counts.get("artillery", 0))

	# Detailed Manpower String
	var max_man = int(current_country.total_population * current_country.military_size_ratio)
	manpower_display.text = (
		"%s / %s" % [_format_number(current_country.manpower), _format_number(max_man)]
	)

	# Detailed Income String using BBCode
	var txt = ""
	txt += (
		"[color=#cccccc]Income:[/color] [color=#88ff88]+$%.1f[/color]\n"
		% (current_country.income)
	)
	txt += (
		"[color=#cccccc]Factories:[/color] [color=#88ff88]+$%.1f[/color]\n"
		% (current_country.factories_amount * current_country.factory_income)
	)

	if current_country.economy_law_penalty > 0:
		var pen_pct = current_country.economy_law_penalty * 100.0
		txt += (
			"[color=#ff8888]Law Penalty (-%.0f%%):[/color] [color=#ff5555]-$%.1f[/color]\n"
			% [pen_pct, current_country.hourly_money_income * current_country.economy_law_penalty]
		)

	txt += (
		"[color=#cccccc]Army Upkeep:[/color] [color=#ff5555]-$%.1f[/color]"
		% current_country.army_cost
	)

	income_breakdown_label.text = txt


func _update_law_buttons_visuals() -> void:
	for btn in laws_grid.get_children():
		if not btn is PanelContainer:
			continue
		if not btn.has_meta("cost"):
			continue

		var cost = btn.get_meta("cost")
		var is_active = false
		var can_afford = false

		var law_type = btn.get_meta("law_type") if btn.has_meta("law_type") else "military"

		if law_type == "military":
			var ratio = btn.get_meta("ratio")
			is_active = is_equal_approx(current_country.military_size_ratio, ratio)
			can_afford = current_country.political_power >= cost
		elif law_type == "economy":
			var penalty = btn.get_meta("penalty")
			is_active = is_equal_approx(current_country.economy_law_penalty, penalty)
			can_afford = current_country.political_power >= cost
		elif law_type == "decision":
			is_active = false
			var cost_money = btn.get_meta("cost_money") if btn.has_meta("cost_money") else 0.0
			can_afford = current_country.political_power >= cost and current_country.money >= cost_money

		var hbox = btn.get_child(0).get_child(0)  # Panel -> MarginContainer -> HBox
		var title_lbl = hbox.get_node("Title")
		var status_lbl = hbox.get_node("Status")
		var cost_lbl = hbox.get_node("Cost")

		var style = btn.get_theme_stylebox("panel").duplicate()

		if is_active:
			style.bg_color = Color(0.2, 0.4, 0.2, 0.9)  # Dark Green
			style.border_color = COLOR_POSITIVE
			status_lbl.text = " ACTIVE"
			status_lbl.add_theme_color_override("font_color", COLOR_POSITIVE)
			cost_lbl.visible = false
			btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			style.bg_color = COLOR_PANEL_INNER
			style.border_color = Color(0.3, 0.3, 0.3)
			status_lbl.text = ""
			cost_lbl.visible = true

			if can_afford:
				cost_lbl.add_theme_color_override("font_color", COLOR_WARNING)
				btn.modulate = Color(1, 1, 1, 1)
				btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				cost_lbl.add_theme_color_override("font_color", COLOR_NEGATIVE)
				btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
				btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN

		btn.add_theme_stylebox_override("panel", style)


#endregion


#region --- Helper Builders ---
func _create_section_header(parent: Node, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COLOR_ACCENT)
	parent.add_child(lbl)


func _create_stat_row(parent: Node, title: String, start_val: String) -> Label:
	var hbox = HBoxContainer.new()
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	var v = Label.new()
	v.text = start_val
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 18)

	hbox.add_child(t)
	hbox.add_child(v)
	parent.add_child(hbox)
	return v


func _create_simple_row(parent: Node, title: String) -> Label:
	var hbox = HBoxContainer.new()
	var t = Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COLOR_TEXT_DIM)

	var v = Label.new()
	v.text = "0"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	hbox.add_child(t)
	hbox.add_child(v)
	parent.add_child(hbox)
	return v


func _add_law_option(
	name: String, ratio: float, eco_penalty: float, cost: int, tooltip: String
) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 50)

	# Metadata storage for logic
	btn_panel.set_meta("law_type", "military")
	btn_panel.set_meta("ratio", ratio)
	btn_panel.set_meta("penalty", eco_penalty)
	btn_panel.set_meta("cost", cost)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	btn_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	btn_panel.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	m.add_child(hbox)

	var title = Label.new()
	title.name = "Title"
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Effect info (small text)
	var effect_lbl = Label.new()
	effect_lbl.text = "Pop: %.2f%% | Eco: -%.0f%%" % [ratio * 100.0, eco_penalty * 100.0]
	effect_lbl.add_theme_font_size_override("font_size", 12)
	effect_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)

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
		var cost = btn.get_meta("cost")

		# Can we afford it?
		if current_country.political_power >= cost:
			var law_type = btn.get_meta("law_type") if btn.has_meta("law_type") else "military"
			
			if law_type == "military":
				var ratio = btn.get_meta("ratio")
				var penalty = btn.get_meta("penalty")
				if is_equal_approx(current_country.military_size_ratio, ratio):
					return  # Do nothing
				current_country.political_power -= cost
				current_country.military_size_ratio = ratio
				current_country.economy_law_penalty = penalty
				current_country.update_manpower_pool()
			elif law_type == "economy":
				var penalty = btn.get_meta("penalty")
				if is_equal_approx(current_country.economy_law_penalty, penalty):
					return  # Do nothing
				current_country.political_power -= cost
				current_country.economy_law_penalty = penalty
				# Total Mobilization penalty
				if penalty == -0.10:
					current_country.military_size_ratio = max(0.005, current_country.military_size_ratio - 0.03)
					current_country.update_manpower_pool()

			# Refresh UI
			_update_law_buttons_visuals()
			_refresh_full_data()
			MusicManager.play_sfx(MusicManager.SFX.TROOP_SELECTED)
		else:
			print("Not enough Political Power!")


func _add_economy_law_option(name: String, eco_penalty: float, cost: int, tooltip: String) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 50)

	btn_panel.set_meta("law_type", "economy")
	btn_panel.set_meta("penalty", eco_penalty)
	btn_panel.set_meta("cost", cost)
	btn_panel.set_meta("ratio", 0.0)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	btn_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	btn_panel.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	m.add_child(hbox)

	var title = Label.new()
	title.name = "Title"
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var effect_lbl = Label.new()
	if eco_penalty < 0:
		effect_lbl.text = "Eco Bonus: +%.0f%%" % [abs(eco_penalty) * 100.0]
	else:
		effect_lbl.text = "Eco Penalty: -%.0f%%" % [eco_penalty * 100.0]
	effect_lbl.add_theme_font_size_override("font_size", 12)
	effect_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)

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

	btn_panel.gui_input.connect(_on_law_gui_input.bind(btn_panel))

	laws_grid.add_child(btn_panel)


func _add_decision_option(
	name: String, cost_pp: int, cost_money: float, effect_desc: String, action_id: String
) -> void:
	var btn_panel = PanelContainer.new()
	btn_panel.custom_minimum_size = Vector2(0, 50)

	btn_panel.set_meta("law_type", "decision")
	btn_panel.set_meta("cost", cost_pp)
	btn_panel.set_meta("cost_money", cost_money)
	btn_panel.set_meta("action_id", action_id)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	btn_panel.add_theme_stylebox_override("panel", style)

	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 15)
	m.add_theme_constant_override("margin_right", 15)
	btn_panel.add_child(m)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	m.add_child(hbox)

	var title = Label.new()
	title.name = "Title"
	title.text = name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var effect_lbl = Label.new()
	effect_lbl.text = effect_desc
	effect_lbl.add_theme_font_size_override("font_size", 12)
	effect_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)

	var cost_lbl = Label.new()
	cost_lbl.name = "Cost"
	if cost_money > 0:
		cost_lbl.text = "%d PP | $%d" % [cost_pp, int(cost_money)]
	else:
		cost_lbl.text = "%d PP" % cost_pp

	var status_lbl = Label.new()
	status_lbl.name = "Status"
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 12)

	hbox.add_child(title)
	hbox.add_child(effect_lbl)
	hbox.add_child(VSeparator.new())
	hbox.add_child(cost_lbl)
	hbox.add_child(status_lbl)

	btn_panel.gui_input.connect(_on_decision_gui_input.bind(btn_panel))

	laws_grid.add_child(btn_panel)


func _on_decision_gui_input(event: InputEvent, btn: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cost_pp = btn.get_meta("cost")
		var cost_money = btn.get_meta("cost_money")
		var action_id = btn.get_meta("action_id")

		if current_country.political_power >= cost_pp and current_country.money >= cost_money:
			current_country.political_power -= cost_pp
			current_country.money -= cost_money

			_execute_decision_action(action_id)

			# Refresh UI
			_update_law_buttons_visuals()
			_refresh_full_data()
			MusicManager.play_sfx(MusicManager.SFX.DECLARE_WAR)
		else:
			print("Cannot afford decision!")


func _execute_decision_action(action_id: String) -> void:
	match action_id:
		"propaganda_stability":
			current_country.stability = min(1.0, current_country.stability + 0.15)
		"propaganda_war_support":
			current_country.war_support = min(1.0, current_country.war_support + 0.15)
		"industrial_effort":
			current_country.factories_amount += 1
			current_country.factories_available += 1
		"naval_infrastructure":
			var coastal_pids = MapManager.get_provinces_near_sea(current_country.country_name)
			if not coastal_pids.is_empty():
				var target_pid = coastal_pids.pick_random()
				var province = MapManager.province_objects.get(target_pid)
				if province:
					province.port = Province.PORT_BUILT
			else:
				current_country.political_power += 75
				current_country.money += 3000
				print("No coastal provinces! Refunded.")
		"military_maneuvers":
			current_country.army_level += 1
			current_country.troop_speed_modifier += 0.1


# Utils
func _format_money(amount: float) -> String:
	if amount >= 1000000:
		return "%.2fM" % (amount / 1000000.0)
	elif amount >= 1000:
		return "%.2fK" % (amount / 1000.0)
	return "%.2f" % amount


func _format_number(amount: int) -> String:
	if amount >= 1000000:
		return "%.1fM" % (amount / 1000000.0)
	elif amount >= 1000:
		return "%.1fK" % (amount / 1000.0)
	return str(amount)
#endregion
