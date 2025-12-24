extends Control
class_name DecisionTree

@export var json_path: String = "res://decisions.json"
var button_theme: Theme = preload("res://button_theme.tres")


@onready var tree_content = $ScrollContainer/TreeContent

var json_data : Dictionary

func _ready():
	hide()

func open_tree():
	show()
	load_and_build_tree()

func load_and_build_tree():
	_clear_tree()

	json_data = _load_json(json_path)
	if json_data == null:
		return

	for category in json_data["categories"].keys():
		var nodes = json_data["categories"][category]
		_create_category_label(category, nodes)

		for node_data in nodes:
			_create_decision_button(node_data)

func _clear_tree():
	for child in tree_content.get_children():
		child.queue_free()

func _load_json(path: String) -> Dictionary:
	var text = FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)

func _create_category_label(name: String, nodes: Array):
	if nodes.is_empty():
		return

	var label := Label.new()
	label.text = name.to_upper()
	label.position = Vector2(nodes[0]["pos"][0], nodes[0]["pos"][1] - 40)
	label.add_theme_font_size_override("font_size", 18)
	tree_content.add_child(label)

func _create_decision_button(node_data: Dictionary):
	var btn := Button.new()
	btn.text = node_data["title"]
	btn.position = Vector2(node_data["pos"][0], node_data["pos"][1])
	btn.custom_minimum_size = Vector2(160, 50)

	if button_theme:
		btn.theme = button_theme

	tree_content.add_child(btn)
	
	
	btn.set_meta("node_data", node_data)

	# if already clicked
	if node_data.get("clicked", false):
		_lock_button(btn)
	else:
		btn.pressed.connect(_on_node_clicked.bind(btn))

func _on_node_clicked(btn: Button):
	var node_data : Dictionary = btn.get_meta("node_data")

	if node_data.get("clicked", false):
		return

	if node_data.has("action"):
		_execute_action(node_data["action"])

	node_data["clicked"] = true
	_lock_button(btn)

func _lock_button(btn: Button):
	btn.disabled = true

	# Force hovered look permanently
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override(
		"disabled",
		btn.get_theme_stylebox("hover")
	)

func _execute_action(action: Dictionary):
	match action.get("type", ""):
		"increase_daily_money":
			CountryManager.player_country.daily_money_income += action.get("amount", 0)
			
		"increase_manpower":
			CountryManager.player_country.manpower += action.get("amount", 0)
		
		"increase_daily_pp":
			CountryManager.player_country.daily_pp_gain += action.get("amount", 0)

		"unlock_modifier":
			print(action)
		_:
			push_warning("Unknown action: " + str(action))


func _on_exit_button_button_up() -> void:
	hide()
	GameState.decision_tree_open = false
	MainClock.resume()
	pass # Replace with function body.
