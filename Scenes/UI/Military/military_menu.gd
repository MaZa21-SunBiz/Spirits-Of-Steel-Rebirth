extends Control

@onready var div_button = %DivisionType
@onready var templates = DivisionData.TEMPLATES
@onready var div_popup = %DivisionPopup

var current_division_amount: int = 1
var current_selected_type: String = "infantry"


func _ready() -> void:
	_setup_division_menu()
	div_button.pressed.connect(_show_popup)

	CountryManager.player_country.process_day_complete.connect(_refresh_ui)

	%DivisionInput.text_changed.connect(_on_division_input_changed)
	%MinusButton.pressed.connect(_on_adjust_amount.bind(-1))
	%PlusButton.pressed.connect(_on_adjust_amount.bind(1))

	_select_default_type("infantry")
	%DivisionInput.text = str(current_division_amount)

	%TrainButton.pressed.connect(_train_troops)
	%CloseButton.pressed.connect(
		func():
			if get_parent().has_method("_close_submenu"):
				get_parent()._close_submenu()
	)

	%InTrainingUI.hide()
	%ReadyUI.hide()


func _refresh_ui() -> void:
	var stats = templates[current_selected_type]
	_update_stats_display(stats)
	_refresh_training_queue()


func _setup_division_menu() -> void:
	div_popup.clear()
	for type_name in templates.keys():
		var icon_path = "res://assets/icons/hoi4/%s.png" % type_name
		if ResourceLoader.exists(icon_path):
			div_popup.add_icon_item(load(icon_path), type_name.capitalize())
		else:
			div_popup.add_item(type_name.capitalize())

	div_popup.index_pressed.connect(_on_division_selected)


func _show_popup() -> void:
	div_popup.position = div_button.global_position + Vector2(0, div_button.size.y)
	div_popup.popup()


func _on_division_selected(index: int) -> void:
	var selected_text = div_popup.get_item_text(index)
	div_button.text = selected_text
	div_button.icon = div_popup.get_item_icon(index)

	current_selected_type = selected_text.to_lower()
	_refresh_ui()


func _update_stats_display(stats: Dictionary):
	%hp_label.text = str(stats.hp)
	%attack_label.text = str(stats.attack)
	%defense_label.text = str(stats.defense)
	%speed_label.text = str(stats.speed)
	%cost_label.text = str(stats.cost * current_division_amount)
	%days_label.text = str(stats.days)


func _on_adjust_amount(delta: int):
	current_division_amount = clampi(current_division_amount + delta, 1, 99)
	%DivisionInput.text = str(current_division_amount)
	_refresh_ui()


func _on_division_input_changed(new_text: String):
	var filtered = ""
	for c in new_text:
		if c in "0123456789":
			filtered += c

	if filtered != new_text:
		%DivisionInput.text = filtered
		%DivisionInput.caret_column = filtered.length()

	current_division_amount = clampi(filtered.to_int(), 1, 99)
	_refresh_ui()


func _train_troops():
	var ok = CountryManager.player_country.train_troops(current_division_amount, current_selected_type)
	if ok:
		_refresh_ui()
	else:
		var stats = templates[current_selected_type]
		var total_manpower_needed = current_division_amount * stats["manpower"]
		var total_cost = current_division_amount * stats["cost"]
		var country = CountryManager.player_country
		
		var reason = ""
		if country.manpower < total_manpower_needed:
			reason = "Not enough manpower! (Needs %d, you have %d)" % [total_manpower_needed, country.manpower]
		elif country.money < total_cost:
			reason = "Not enough money! (Needs %d, you have %d)" % [total_cost, int(country.money)]
		else:
			reason = "Insufficient resources!"
			
		PopupManager.show_alert("alert", country, country, reason)
		# Trigger dialogue warning
		print("Training Failed: ", reason)


func _refresh_training_queue():
	for child in %QueueContainer.get_children():
		if child != %InTrainingUI and child != %ReadyUI:
			child.queue_free()

	var country = CountryManager.player_country

	for troop_batch in country.ready_troops:
		if troop_batch.stored_divisions.is_empty():
			continue

		var entry = %ReadyUI.duplicate()

		# Make style unique so not everything highlights when hovering over
		var unique_style = entry.get_theme_stylebox("panel").duplicate()
		entry.add_theme_stylebox_override("panel", unique_style)

		entry.show()

		entry.gui_input.connect(_on_deploy_input.bind(troop_batch))
		entry.mouse_entered.connect(_on_ready_hover.bind(entry, true))
		entry.mouse_exited.connect(_on_ready_hover.bind(entry, false))
		%QueueContainer.add_child(entry)

		# Get info from the first division in the batch
		var sample_div = troop_batch.stored_divisions[0]
		var count = troop_batch.stored_divisions.size()
		var type_name = sample_div.type

		# Setup UI
		var icon_rect = entry.get_node("HBoxContainer/TextureRect")
		var amount_label = entry.get_node("HBoxContainer/DivisionAmountLabel")

		amount_label.text = str(count) + " " + type_name.capitalize() + " Divisions"
		_set_entry_icon(icon_rect, type_name)

	for task in country.ongoing_training:
		var entry = %InTrainingUI.duplicate()
		entry.show()
		%QueueContainer.add_child(entry)

		# Setup UI
		var icon_rect = entry.get_node("HBoxContainer/TextureRect")
		var days_label = entry.get_node("HBoxContainer/VBoxContainer/DaysLeftLabel")
		var amount_label = entry.get_node("HBoxContainer/VBoxContainer/DivisionAmountLabel")

		days_label.text = str(task.days_left) + " days left"
		amount_label.text = str(task.divisions_count) + " " + task.division_type.capitalize()
		_set_entry_icon(icon_rect, task.division_type)


# Helper function to stop repeating icon code
func _set_entry_icon(rect: TextureRect, type: String):
	var path = "res://assets/icons/hoi4/%s.png" % type.to_lower()
	if ResourceLoader.exists(path):
		rect.texture = load(path)


func _on_deploy_input(event: InputEvent, troop_batch):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_deploy_troop(troop_batch)


func _deploy_troop(troop):
	CountryManager.player_country.deploy_ready_troop(troop)
	pass


func _select_default_type(target_name: String) -> void:
	for i in div_popup.item_count:
		if div_popup.get_item_text(i).to_lower() == target_name.to_lower():
			_on_division_selected(i)
			break


func _on_ready_hover(entry: PanelContainer, is_hovering: bool):
	var style = entry.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		return

	if is_hovering:
		style.border_color = Color.WHITE
		style.set_border_width_all(2)
		entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		style.border_color = Color(0, 0, 0, 0)
