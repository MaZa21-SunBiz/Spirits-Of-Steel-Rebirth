extends CanvasLayer

@onready var map_sprite: Sprite2D = $"../../MapContainer/CultureSprite"

var hovered_country: String = ""
var selected_country: String = ""
var selection_locked := false


func _ready() -> void:
	MapManager.show_countries_map()
	%PlayButton.pressed.connect(on_play_pressed)


func on_play_pressed():
	if selected_country != "" and CountryManager.countries.has(selected_country):
		CountryManager.set_player_country(selected_country)
		ConsoleManager.switch_scene("world")


func _input(event: InputEvent) -> void:
	# Hover only works if nothing is selected
	if event is InputEventMouseMotion and not selection_locked:
		_handle_hover(event.position)

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_unlock_selection()


# ================================
# Hover
# ================================


func _handle_hover(screen_pos: Vector2) -> void:
	if MapManager._is_mouse_over_ui() or Console.is_visible():
		_clear_hover()
		return

	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos

	var pid = MapManager.get_province_with_radius(world_pos, map_sprite, 5)

	if pid <= 1:
		_clear_hover()
		return

	var country = MapManager.province_objects[pid].country

	if country != hovered_country:
		_clear_hover()
		MapManager.highlight_country(country)
		hovered_country = country
		updateCountryDetails()

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _clear_hover() -> void:
	# Don't remove highlight if it's selected
	if hovered_country != "" and hovered_country != selected_country:
		MapManager.restore_country_color(hovered_country)

	hovered_country = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


# ================================
# Click / Selection
# ================================


func _handle_click() -> void:
	if hovered_country == "":
		return

	selected_country = hovered_country
	selection_locked = true

	print("Selected:", selected_country)

	# Keep highlight, stop hover updates
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _unlock_selection() -> void:
	if selected_country != "":
		MapManager.restore_country_color(selected_country)

	selected_country = ""
	selection_locked = false
	_clear_hover()


# ================================
# UI Update
# ================================


func updateCountryDetails() -> void:
	var country: CountryData = CountryManager.countries.get(hovered_country, null)
	if country == null:
		return

	%FlagRect.texture = TroopManager.get_flag(hovered_country)
	%ValueManpower.text = GameState.format_number(country.manpower)
	%ValueGDP.text = GameState.format_number(country.gdp)
	%ValueFactories.text = str(country.factories_amount)
