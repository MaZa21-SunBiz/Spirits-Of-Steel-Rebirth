extends CanvasLayer
# class_name GameUI

@onready var nation_flag: TextureRect = $Control/Topbar/nation_flag


# func _enter_tree() -> void:
# 	GameState.game_ui = self
#
#
# func _ready() -> void:
# 	GameState.game_ui = self
#
# 	CountryManager.player_country_changed.connect(_on_player_change)
# 	var clock = GameState.main.clock
# 	clock.hour_passed.connect(_on_time_passed)
# 	clock.speed_changed.connect(updateProgressBar)
# 	%Plus.pressed.connect(clock.increase_speed)
# 	%Minus.pressed.connect(clock.decrease_speed)
#
# 	_on_time_passed(0)
# 	updateProgressBar()

func _on_player_change() -> void:
	_update_flag()
	update_topbar_stats()


var custom_font = load("res://font/Google_Sans/GoogleSans-VariableFont_GRAD,opsz,wght.ttf")


func _get_simple_flag(c_name: String) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = TroopManager.get_flag(c_name)
	tr.custom_minimum_size = Vector2(42, 26)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func update_topbar_stats() -> void:
	if !CountryManager.player_country:
		return
	%label_politicalpower.text = str(floori(CountryManager.player_country.political_power))
	%label_stability.text = str(round(CountryManager.player_country.stability * 100)) + "%"
	%label_manpower.text = format_number(CountryManager.player_country.manpower)
	%label_money.text = format_number(CountryManager.player_country.money)
	%label_industry.text = str(CountryManager.player_country.factories_amount)


func _on_hour_passed(_total_ticks) -> void:
	update_topbar_stats()


func format_number(value: float) -> String:
	var abs_val = abs(value)
	var sign_str = "-" if value < 0 else ""
	if abs_val >= 1_000_000_000:
		return sign_str + "%.2fB" % (abs_val / 1_000_000_000.0)
	elif abs_val >= 1_000_000:
		return sign_str + "%.2fM" % (abs_val / 1_000_000.0)
	elif abs_val >= 1_000:
		return sign_str + "%.1fK" % (abs_val / 1_000.0)
	return sign_str + str(floori(abs_val))


func _on_time_passed(x) -> void:
	%label_date.text = GameState.main.clock.get_datetime_string()
	update_topbar_stats()


func updateProgressBar():
	var clock = GameState.main.clock

	%ProgressBar.value = clock.current_speed_level
	var bg_style = %ProgressBar.get_theme_stylebox("background")
	if clock.paused:
		bg_style.border_color = Color.DARK_RED
		%label_date.add_theme_color_override("font_color", Color.RED)
	else:
		bg_style.border_color = Color.DARK_CYAN
		%label_date.add_theme_color_override("font_color", Color.WHITE)


func _update_flag() -> void:
	if !CountryManager.player_country:
		return
	var path = (
		"res://assets/flags/%s_flag.png" % CountryManager.player_country.country_name.to_lower()
	)
	if ResourceLoader.exists(path):
		nation_flag.texture = load(path)
