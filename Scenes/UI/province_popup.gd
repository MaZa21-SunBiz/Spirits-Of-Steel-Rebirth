extends Control

# UI Nodes
var panel: PanelContainer
var vbox: VBoxContainer
var lbl_country: Label
var flag_rect: TextureRect
var lbl_city: Label
var lbl_pop: Label
var lbl_gdp: Label
var lbl_infra: Label
var lbl_troops: Label

# Row containers
var row_pop: HBoxContainer
var row_gdp: HBoxContainer
var row_infra: HBoxContainer
var row_troops: HBoxContainer

# Hover/Fade State
var target_province = null
var is_shown: bool = false
var hover_delay_timer: float = 0.0
var fade_tween: Tween = null

const HOVER_DELAY_THRESHOLD := 0.22  # seconds of hover before showing
const FADE_IN_DURATION := 0.15       # seconds to fade in
const FADE_OUT_DURATION := 0.10      # seconds to fade out

func _ready() -> void:
	# Clear children of ProvincePopup to rebuild programmatically
	for child in get_children():
		child.queue_free()

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

	# 1. Main Panel (Minimal Tooltip Style)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 0) # Compact width, dynamic height
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# Sleek dark translucent glass style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.65, 0.2, 0.5) # Gold accent border
	style.set_corner_radius_all(6)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	panel.add_theme_stylebox_override("panel", style)

	# 2. Margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	# 3. Main vbox layout
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# 4. Header (Flag + Country)
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)

	flag_rect = TextureRect.new()
	flag_rect.custom_minimum_size = Vector2(20, 13)
	flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_rect.stretch_mode = TextureRect.STRETCH_SCALE
	header_hbox.add_child(flag_rect)

	lbl_country = Label.new()
	lbl_country.add_theme_font_size_override("font_size", 12)
	header_hbox.add_child(lbl_country)

	# City name
	lbl_city = Label.new()
	lbl_city.add_theme_font_size_override("font_size", 10)
	lbl_city.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl_city)

	# Thin divider
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.24, 0.28, 0.35, 0.4)
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# 5. Stats Rows (Inline, dynamic)
	var pop_data = _create_inline_row("👥 Pop:")
	row_pop = pop_data.row
	vbox.add_child(row_pop)
	lbl_pop = pop_data.value_label

	var gdp_data = _create_inline_row("💰 GDP:")
	row_gdp = gdp_data.row
	vbox.add_child(row_gdp)
	lbl_gdp = gdp_data.value_label

	var infra_data = _create_inline_row("🏭 Industry:")
	row_infra = infra_data.row
	vbox.add_child(row_infra)
	lbl_infra = infra_data.value_label

	var troops_data = _create_inline_row("🛡️ Garrison:")
	row_troops = troops_data.row
	vbox.add_child(row_troops)
	lbl_troops = troops_data.value_label


func _create_inline_row(icon_and_label: String) -> Dictionary:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl_title = Label.new()
	lbl_title.text = icon_and_label
	lbl_title.add_theme_font_size_override("font_size", 10)
	lbl_title.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
	hbox.add_child(lbl_title)
	
	# Spacer to push value to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var lbl_val = Label.new()
	lbl_val.add_theme_font_size_override("font_size", 10)
	lbl_val.add_theme_color_override("font_color", Color.WHITE)
	hbox.add_child(lbl_val)
	
	return {"row": hbox, "value_label": lbl_val}


func show_popup(province) -> void:
	if target_province == province:
		return
	target_province = province
	hover_delay_timer = 0.0
	is_shown = false


func hide_popup() -> void:
	target_province = null


func _display_info(province) -> void:
	if not province:
		return

	# Dynamic border coloring based on province owner
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		if province.country == "sea":
			style.border_color = Color(0.18, 0.50, 0.75, 0.6) # Sea Blue
		else:
			var country_color = MapManager.country_colors.get(province.country.to_lower(), Color(0.85, 0.65, 0.2))
			style.border_color = country_color.lightened(0.2)
			style.border_color.a = 0.6

	# Country Header & Row Visibilities
	if province.country == "sea":
		flag_rect.hide()
		lbl_country.text = "INTERNATIONAL WATERS"
		lbl_country.add_theme_color_override("font_color", Color(0.24, 0.65, 0.85))
		
		# Hide land-only stats entirely
		row_pop.hide()
		row_gdp.hide()
		row_infra.hide()
		
		lbl_city.text = "Ocean Sector"
		lbl_city.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	else:
		# Show base land stats
		row_pop.show()
		row_gdp.show()
		
		# Populate Pop & GDP
		lbl_pop.text = GameState.format_number(province.population)
		lbl_gdp.text = "$" + GameState.format_number(province.gdp)
		lbl_gdp.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44)) # Emerald Green

		# Country Flag
		flag_rect.show()
		var flag_tex = TroopManager.get_flag(province.country)
		if flag_tex:
			flag_rect.texture = flag_tex
		else:
			flag_rect.hide()
			
		lbl_country.text = province.country.capitalize().replace("_", " ")
		var country_color = MapManager.country_colors.get(province.country.to_lower(), Color(0.85, 0.65, 0.2))
		lbl_country.add_theme_color_override("font_color", country_color.lightened(0.3))

		# City Header
		if province.city != "":
			lbl_city.text = province.city.capitalize().replace("_", " ")
			lbl_city.add_theme_color_override("font_color", Color.WHITE)
		else:
			lbl_city.text = "Rural Province"
			lbl_city.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))

		# Dynamic Infrastructure / Port Display
		var infra_status = "None"
		var infra_color = Color(0.55, 0.60, 0.68)
		var has_infra = false
		
		if province.factory == Province.FACTORY_BUILT:
			infra_status = "Factory"
			infra_color = Color(0.16, 0.73, 0.86) # Cyan
			has_infra = true
		elif province.factory == Province.FACTORY_BUILDING:
			infra_status = "Building Factory"
			infra_color = Color(0.95, 0.6, 0.1) # Orange
			has_infra = true

		if province.port == Province.PORT_BUILT:
			infra_status = "Port"
			infra_color = Color(0.24, 0.65, 0.85) # Blue
			has_infra = true
		elif province.port == Province.PORT_BUILDING:
			infra_status = "Building Port"
			infra_color = Color(0.95, 0.6, 0.1) # Orange
			has_infra = true

		if has_infra:
			row_infra.show()
			lbl_infra.text = infra_status
			lbl_infra.add_theme_color_override("font_color", infra_color)
		else:
			# Hide industry row entirely if there is none!
			row_infra.hide()

	# Dynamic Garrison Display
	var total_divs = 0
	for troop in province.troops_here:
		if is_instance_valid(troop):
			total_divs += troop.divisions_count
			
	if total_divs > 0:
		row_troops.show()
		lbl_troops.text = "%d Divs" % total_divs
		lbl_troops.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3)) # Crimson
	else:
		# Hide garrison row entirely if empty!
		row_troops.hide()


func _process(delta: float) -> void:
	# Calculate coordinates to follow mouse smoothly and clamp within viewport bounds
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	var popup_size = panel.size if panel else Vector2(180, 80)
	
	var target_pos = mouse_pos + Vector2(20, 20)
	
	# Horizontal clamping (flip left if too close to right edge)
	if target_pos.x + popup_size.x > viewport_size.x:
		target_pos.x = mouse_pos.x - popup_size.x - 20
		
	# Vertical clamping (slide up if too close to bottom edge)
	if target_pos.y + popup_size.y > viewport_size.y:
		target_pos.y = mouse_pos.y - popup_size.y - 10
		
	# Ensure it never goes off-screen top/left
	target_pos.x = max(10, target_pos.x)
	target_pos.y = max(10, target_pos.y)
	
	global_position = target_pos

	# Zoom visibility check: fade out when zoomed far out
	var camera = get_viewport().get_camera_2d()
	if camera and camera.zoom.x < 1.0:
		target_province = null
		is_shown = false
		hover_delay_timer = 0.0
		modulate.a = 0.0
		hide()
		return

	if target_province != null:
		if not is_shown:
			hover_delay_timer += delta
			if hover_delay_timer >= HOVER_DELAY_THRESHOLD:
				_display_info(target_province)
				is_shown = true
				if fade_tween:
					fade_tween.kill()
				fade_tween = create_tween()
				fade_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				show()
	else:
		if is_shown:
			is_shown = false
			hover_delay_timer = 0.0
			if fade_tween:
				fade_tween.kill()
			fade_tween = create_tween()
			fade_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fade_tween.tween_callback(hide)
		elif modulate.a > 0.0 and (fade_tween == null or not fade_tween.is_running()):
			modulate.a = 0.0
			hide()
