extends CanvasLayer

@export var map_sprite: Sprite2D

var selected_pid: int = -1
var hovered_pid: int = -1
var original_pid_color: Color

enum MODE {
	PROVINCE,
	FACTION,
	COUNTRY,
	CLAIMS,
	ETHNICITY,
	CITY,
}

# UI References (Ensure these match your .tscn node names)
@onready 
var status_label = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/StatusLabel
@onready
var input_country = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputCountry
@onready
var input_country_color = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputCountryColor
@onready
var input_city = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputCity
@onready
var input_pop = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputPop
@onready
var input_gdp = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputGDP
@onready
var input_eth_name = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputEthName
@onready
var input_eth_color = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/GridContainer/InputEthColor
@onready 
var input_claims = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/InputClaims

@onready var btn_apply = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/BtnApply
@onready var btn_export = $PanelContainer/MarginContainer/ScrollContainer/VBoxContainer/BtnExport


func _ready() -> void:
	btn_apply.pressed.connect(_on_apply_pressed)
	btn_export.pressed.connect(_on_export_pressed)

	if map_sprite == null:
		map_sprite = get_node_or_null("../../MapContainer/CultureSprite")


func _unhandled_input(event: InputEvent) -> void:
	if MapManager._is_mouse_over_ui() or Console.is_visible():
		_clear_hover()
		return

	if event is InputEventMouseMotion:
		_handle_hover(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)


func _handle_hover(screen_pos: Vector2) -> void:
	if map_sprite == null:
		return
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var pid = MapManager.get_province_with_radius(world_pos, map_sprite, 5)

	if pid == hovered_pid:
		return
	_clear_hover()

	if pid > 1:
		hovered_pid = pid
		original_pid_color = MapManager.state_color_image.get_pixel(pid, 0)
		MapManager.state_color_image.set_pixel(pid, 0, original_pid_color.lightened(0.4))
		MapManager.state_color_texture.update(MapManager.state_color_image)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _clear_hover() -> void:
	if hovered_pid > 1:
		MapManager.state_color_image.set_pixel(hovered_pid, 0, original_pid_color)
		MapManager.state_color_texture.update(MapManager.state_color_image)
		hovered_pid = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _handle_click(screen_pos: Vector2) -> void:
	if hovered_pid > 1:
		select_province(hovered_pid)


func select_province(pid: int) -> void:
	selected_pid = pid
	var prov = MapManager.province_objects.get(pid)
	if not prov:
		return

	var color_str = _color_to_rgb_string(prov.r_color) if prov.r_color else "Unknown"
	status_label.text = "Selected PID: %d\nR_Color: %s" % [pid, color_str]

	# Set Fields
	input_country.text = prov.country
	input_city.text = prov.city
	input_pop.value = prov.population
	input_gdp.value = prov.gdp

	# Set Country Color Picker
	input_country_color.color = MapManager.country_colors.get(prov.country, Color.GRAY)

	if prov.ethnicity.has("name"):
		input_eth_name.text = prov.ethnicity["name"]
	if prov.ethnicity.has("color"):
		input_eth_color.text = prov.ethnicity["color"]
	input_claims.text = ", ".join(prov.claims)


func _on_apply_pressed() -> void:
	if selected_pid <= 1:
		return
	var prov = MapManager.province_objects.get(selected_pid)
	if not prov:
		return

	var old_country = prov.country
	var new_country = input_country.text.strip_edges()
	var new_color = input_country_color.color

	# 1. Update MapManager global data
	MapManager.country_colors[new_country] = new_color

	# 2. Update Province Object
	prov.country = new_country
	prov.city = input_city.text.strip_edges()
	prov.population = int(input_pop.value)
	prov.gdp = float(input_gdp.value)
	prov.ethnicity = {
		"name": input_eth_name.text.strip_edges(), "color": input_eth_color.text.strip_edges()
	}

	var raw_claims = input_claims.text.split(",")
	var final_claims = []
	for c in raw_claims:
		var clean = c.strip_edges()
		if clean != "":
			final_claims.append(clean)
	prov.claims = final_claims

	# 3. Cleanup Dictionaries
	if old_country != new_country:
		if MapManager.country_to_provinces.has(old_country):
			MapManager.country_to_provinces[old_country].erase(selected_pid)
		if not MapManager.country_to_provinces.has(new_country):
			MapManager.country_to_provinces[new_country] = []
		MapManager.country_to_provinces[new_country].append(selected_pid)

	# 4. Global Map Refresh for this Country
	# We loop through all provinces of this country and update their color in the lookup texture
	var country_pids = MapManager.country_to_provinces.get(new_country, [])
	for p_id in country_pids:
		if p_id == hovered_pid:
			original_pid_color = new_color
			MapManager.state_color_image.set_pixel(p_id, 0, new_color.lightened(0.4))
		else:
			MapManager.state_color_image.set_pixel(p_id, 0, new_color)

	MapManager.state_color_texture.update(MapManager.state_color_image)
	print("MapEditor: Applied changes and updated colors for ", new_country)


func _on_export_pressed() -> void:
	# Export Province Data
	var prov_export = {}
	for pid in MapManager.province_objects.keys():
		if pid <= 1:
			continue
		var p = MapManager.province_objects[pid]
		if p.r_color == null:
			continue
		var key = _color_to_rgb_string(p.r_color)
		prov_export[key] = {
			"city": p.city,
			"claims": p.claims,
			"ethnicity": p.ethnicity,
			"gdp": p.gdp,
			"population": p.population
		}

	# Export Country Colors
	var country_export = {}
	for c_name in MapManager.country_colors.keys():
		var col = MapManager.country_colors[c_name]
		country_export[c_name] = {"color": [int(col.r8), int(col.g8), int(col.b8)]}

	_save_json("user://exported_map_data.json", prov_export)
	_save_json("user://exported_countries.json", country_export)
	OS.shell_open(ProjectSettings.globalize_path("user://"))


func _save_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func _color_to_rgb_string(c: Color) -> String:
	return (
		"(%d, %d, %d)" % [int(round(c.r * 255.0)), int(round(c.g * 255.0)), int(round(c.b * 255.0))]
	)
