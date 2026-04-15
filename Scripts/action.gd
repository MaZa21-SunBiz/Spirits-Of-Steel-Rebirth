extends HBoxContainer
class_name ActionRow

@onready var button: Button = $Button

var data: Dictionary = {}
var base_text: String = ""
var _callback: Callable
var source_object: Variant = null

signal training_finished
signal pressed


func _ready() -> void:
	button.pressed.connect(func(): pressed.emit())
	pressed.connect(_on_button_pressed)
	# Assuming GameState is a global singleton
	if GameState.current_world and GameState.current_world.clock:
		GameState.current_world.clock.day_passed.connect(refresh_ui)


# 1. Standard Setup
func setup(item_data: Dictionary, on_click: Callable) -> void:
	data = item_data
	_callback = on_click
	source_object = null
	base_text = data.get("text", "Unknown Action")
	_init_ui()


# 2. Training Setup
func setup_training(training_obj) -> void:
	source_object = training_obj
	data = {"is_status": true}
	_callback = Callable()

	# CHANGED: Use .divisions_count (the integer)
	base_text = "Training %d Divs" % training_obj.divisions_count

	if !is_node_ready():
		await ready
	button.disabled = true
	button.modulate = Color.GOLD
	refresh_ui()


# 3. Ready Setup
func setup_ready(ready_troop_obj: CountryData.ReadyTroop, on_click: Callable) -> void:
	data = {"is_deploy": true}
	_callback = on_click

	base_text = "Deploy %d Divisions" % ready_troop_obj.count

	if not is_node_ready():
		await ready
	button.disabled = false
	button.modulate = Color.SPRING_GREEN
	refresh_ui()


func _init_ui():
	if not is_node_ready():
		await ready
	refresh_ui()


func refresh_ui() -> void:
	var player = CountryManager.player_country
	if not player:
		return

	# Special Logic: Troop Training
	if source_object != null and data.get("is_status", false):
		# Assuming 'troop' has property days_left
		if "days_left" in source_object:
			if source_object.days_left <= 0:
				training_finished.emit()
				return
			button.text = "%s (%d Days)" % [base_text, source_object.days_left]
		return

	# Special Logic: Ready Troop
	if source_object != null and data.get("is_deploy", false):
		button.text = base_text
		return

	# Standard Logic
	_update_standard_text_and_cost(player)


func _update_standard_text_and_cost(player) -> void:
	var cost_pp = data.get("cost", 0)
	var cost_mp = data.get("manpower", 0)
	var suffix := ""

	if cost_pp > 0:
		suffix = " (%d PP)" % cost_pp
	elif cost_mp > 0:
		suffix = " (%sk MP)" % str(cost_mp * 0.001)

	button.text = base_text + suffix

	var can_afford = player.political_power >= cost_pp and player.manpower >= cost_mp
	button.disabled = !can_afford
	button.modulate = Color.WHITE if can_afford else Color(1, 0.5, 0.5)


func _on_button_pressed() -> void:
	CountryManager.player_country.political_power -= data.get("cost", 0)
	if _callback.is_valid():
		_callback.call()
