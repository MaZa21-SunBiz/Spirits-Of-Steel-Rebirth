extends Control

signal clicked(card_node, associated_data)

@onready var color_rect: ColorRect = $ColorRect
@onready var texture_rect: TextureRect = $ColorRect/VBoxContainer/HBoxContainer2/TextureRect
@onready var progress_bar: ProgressBar = $ColorRect/VBoxContainer/HBoxContainer/ProgressBar
@onready var label_division: Label = $ColorRect/VBoxContainer/HBoxContainer2/label_division
@onready var label_attack: Label = $ColorRect/VBoxContainer/HBoxContainer2/label_attack
@onready var label_defense: Label = $ColorRect/VBoxContainer/HBoxContainer/label_defense
@onready var label_experience: Label = $ColorRect/VBoxContainer/HBoxContainer/label_experience

var data_payload  # Can be DivisionData OR Array[DivisionData]
var is_selected: bool = false

const COLOR_NORMAL = Color(0.1, 0.1, 0.1, 0.7)
const COLOR_SELECTED = Color(0.1, 0.4, 0.6, 0.9)
const COLOR_HOVER = Color(0.2, 0.2, 0.2, 0.8)


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in color_rect.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Setup for the new Grouped View
func setup_grouped(type: String, divisions: Array, currently_selected: bool) -> void:
	data_payload = divisions
	is_selected = currently_selected

	var count = divisions.size()
	label_division.text = "%dx %s" % [count, type.capitalize()]

	# Calculate Group Averages
	var total_atk = 0.0
	var total_def = 0.0
	var total_hp = 0.0
	var total_exp = 0.0

	for d in divisions:
		total_atk += d.get_attack_power()
		total_def += d.get_defense_power()
		total_hp += d.hp
		total_exp += d.experience

	label_attack.text = str(int(total_atk / count))
	label_defense.text = str(int(total_def / count))
	label_experience.text = "%d%%" % int((total_exp / count) * 100)
	progress_bar.value = total_hp / count

	var icon_path = "res://assets/icons/hoi4/%s.png" % type.to_lower()
	if ResourceLoader.exists(icon_path):
		texture_rect.texture = load(icon_path)

	update_visuals()


func update_visuals():
	color_rect.color = COLOR_SELECTED if is_selected else COLOR_NORMAL


func _on_mouse_entered():
	if !is_selected:
		color_rect.color = COLOR_HOVER


func _on_mouse_exited():
	update_visuals()


func _gui_input(event):
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self, data_payload)
			get_viewport().set_input_as_handled()
