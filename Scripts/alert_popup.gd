extends Control

@onready var flag_left: TextureRect = $Panel/flag_left
@onready var flag_right: TextureRect = $Panel/flag_right
@onready var description: Label = $Panel/description
@onready var button: Button = $Panel/Button

var data = {}
var is_built = false

func setup_alert(config: Dictionary):
	data = config


func _ready():
	button.pressed.connect(_on_ok)
	# Hide the default flat ColorRect panel colors to draw custom panels
	$Panel.color = Color.TRANSPARENT
	_build_ui()


func custom_reset_size():
	_build_ui()


func _build_ui():
	if is_built:
		return
	is_built = true

	var type = data.get("type", "default")
	var c1 = data.get("c1")
	var c2 = data.get("c2")
	var custom_text = data.get("text", "")
	var params = data.get("params", {})

	# Set description text first
	if custom_text != "":
		description.text = custom_text
	else:
		match type:
			"war":
				description.text = "%s has declared war on %s!" % [c1.country_name, c2.country_name]
			"capitulated":
				description.text = "%s has capitulated." % [c1.country_name]
			"game_over":
				description.text = "Game Over"
			_:
				description.text = "Event: " + type

	if params.has("color"):
		description.add_theme_color_override("font_color", params["color"])

	# Ensure the text wraps
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Reset anchors to top-left for manual layout positioning
	description.anchors_preset = Control.PRESET_TOP_LEFT
	description.anchor_left = 0.0
	description.anchor_right = 0.0
	description.anchor_top = 0.0
	description.anchor_bottom = 0.0

	var base_width = 400.0
	description.custom_minimum_size = Vector2(base_width - 50.0, 0)
	
	# Read the Godot calculated wrapped text height directly
	var text_height = max(50.0, description.get_minimum_size().y)
	
	var padding_y = 65.0 # space for flags/header and padding
	var final_panel_height = text_height + padding_y + 55.0 # room for button
	
	# Resize Panel
	var panel = $Panel
	panel.size = Vector2(base_width, final_panel_height)
	self.custom_minimum_size = panel.size
	self.size = panel.size

	# Determine theme colors based on event type
	var border_color = Color(0.85, 0.65, 0.2, 0.7) # Gold
	var title_text = "📰 WORLD NEWS"
	var border_width = 2
	
	match type:
		"war":
			border_color = Color(0.85, 0.15, 0.15, 0.8) # Crimson Red
			title_text = "⚠️ DECLARATION OF WAR"
			border_width = 3
		"capitulated":
			border_color = Color(0.8, 0.8, 0.8, 0.7) # Silver
			title_text = "🏳️ COUNTRY CAPITULATION"
			border_width = 2
		"game_over":
			border_color = Color(0.5, 0.0, 0.0, 0.9) # Dark Red
			title_text = "💀 GAME OVER"
			border_width = 4
		"warning":
			border_color = Color(0.95, 0.6, 0.1, 0.8) # Amber
			title_text = "⚠️ MILITARY WARNING"
			border_width = 2
		_:
			# Custom titles based on text keywords (e.g. Ottoman)
			if custom_text.to_lower().contains("ottoman") or custom_text.to_lower().contains("empire"):
				title_text = "👑 EMPIRE RESTORATION"
				border_color = Color(0.85, 0.65, 0.2, 0.8)
			elif custom_text.to_lower().contains("not enough") or custom_text.to_lower().contains("troop"):
				title_text = "⚠️ DISPATCH ERROR"
				border_color = Color(0.95, 0.6, 0.1, 0.8)
				border_width = 2

	# Create a beautiful background Panel programmatically
	var bg_panel = Panel.new()
	bg_panel.name = "BeautifulBG"
	bg_panel.size = panel.size
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg_panel)
	panel.move_child(bg_panel, 0) # Draw behind everything

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.11, 0.98) # Slate dark glass
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.set_corner_radius_all(10)
	style.shadow_size = 16
	style.shadow_color = Color(0, 0, 0, 0.6)
	bg_panel.add_theme_stylebox_override("panel", style)

	# Place header title
	var title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.text = title_text
	title_lbl.add_theme_color_override("font_color", border_color.lightened(0.2))
	title_lbl.size = Vector2(base_width, 25)
	title_lbl.position = Vector2(0, 15)
	panel.add_child(title_lbl)

	# Place elements
	flag_left.custom_minimum_size = Vector2(36, 24)
	flag_left.size = flag_left.custom_minimum_size
	flag_left.position = Vector2(20, 15)

	flag_right.custom_minimum_size = Vector2(36, 24)
	flag_right.size = flag_right.custom_minimum_size
	flag_right.position = Vector2(base_width - flag_right.custom_minimum_size.x - 20, 15)

	# Crossed swords for wars
	if type == "war":
		var vs_lbl = Label.new()
		vs_lbl.text = "⚔️"
		vs_lbl.add_theme_font_size_override("font_size", 15)
		vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		vs_lbl.size = Vector2(30, 25)
		vs_lbl.position = Vector2((base_width - 30) / 2.0, 15)
		panel.add_child(vs_lbl)

	# Outline frames behind flags
	if c1:
		flag_left.texture = _get_flag(c1.country_name)
		flag_left.show()
		_add_flag_frame(flag_left.position, flag_left.size)
	else:
		flag_left.hide()

	if c2:
		flag_right.texture = _get_flag(c2.country_name)
		flag_right.show()
		_add_flag_frame(flag_right.position, flag_right.size)
	else:
		flag_right.hide()

	# Position description label centered under the top header
	description.size = Vector2(base_width - 50.0, text_height)
	description.position = Vector2(25, 55)

	# Place OK button at the bottom
	button.position = Vector2((base_width - button.size.x) / 2.0, final_panel_height - button.size.y - 15.0)

	# Style the OK button
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.12, 0.15, 0.20, 0.8)
	btn_style_normal.border_width_left = 1
	btn_style_normal.border_width_top = 1
	btn_style_normal.border_width_right = 1
	btn_style_normal.border_width_bottom = 1
	btn_style_normal.border_color = border_color.darkened(0.2)
	btn_style_normal.set_corner_radius_all(4)

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.16, 0.20, 0.26, 0.9)
	btn_style_hover.border_width_left = 1
	btn_style_hover.border_width_top = 1
	btn_style_hover.border_width_right = 1
	btn_style_hover.border_width_bottom = 1
	btn_style_hover.border_color = border_color
	btn_style_hover.set_corner_radius_all(4)

	button.add_theme_stylebox_override("normal", btn_style_normal)
	button.add_theme_stylebox_override("hover", btn_style_hover)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", border_color.lightened(0.2))
	button.text = "Acknowledge"


func _add_flag_frame(pos: Vector2, size: Vector2) -> void:
	var frame = Panel.new()
	frame.size = size + Vector2(2, 2)
	frame.position = pos - Vector2(1, 1)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.0, 0.0, 0.8) # Subtle dark frame outline
	frame.add_theme_stylebox_override("panel", style)
	
	$Panel.add_child(frame)
	$Panel.move_child(frame, 1) # Put behind the flag texture


func _on_ok():
	# If we passed a callback function in params, run it!
	if data.get("params", {}).has("callback"):
		data["params"]["callback"].call()
	queue_free()


func _get_flag(country: String):
	var path = "res://assets/flags/%s_flag.png" % country.to_lower()
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	return null
