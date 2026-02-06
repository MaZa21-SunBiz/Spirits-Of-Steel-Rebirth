extends Node

var AlertPopupScene = preload("res://Scenes/AlertPopup.tscn")
var active_popups: Array = []
var ui_layer: CanvasLayer = CanvasLayer.new()


func _ready():
	ui_layer.layer = 100
	add_child(ui_layer)


# ENHANCED: Added custom_text and extra_params
func show_alert(
	type: String,
	c1: CountryData = null,
	c2: CountryData = null,
	custom_text: String = "",
	extra_params: Dictionary = {}
):
	var popup = AlertPopupScene.instantiate()

	# We pass everything into the popup in one go
	popup.setup_alert(
		{"type": type, "c1": c1, "c2": c2, "text": custom_text, "params": extra_params}
	)

	ui_layer.add_child(popup)
	active_popups.append(popup)

	popup.call_deferred("reset_size")
	call_deferred("_restack_popups")

	popup.tree_exited.connect(
		func():
			active_popups.erase(popup)
			_restack_popups()
	)



func show_custom_popup(popup: Control) -> void:
	ui_layer.add_child(popup)
	active_popups.append(popup)

	# Assume the popup has a 'reset_size' method or similar, but for safety we just restack.
	# If the popup needs layout updates, it should handle its own _ready logic.
	# But we can try to call reset_size if it exists.
	if popup.has_method("reset_size"):
		popup.call_deferred("reset_size")
		
	call_deferred("_restack_popups")

	popup.tree_exited.connect(
		func():
			active_popups.erase(popup)
			_restack_popups()
	)


func _restack_popups():
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = viewport_size.x / 2
	var center_y = viewport_size.y / 2
	var spacing = 25  # Increased spacing slightly for better visual separation

	for i in range(active_popups.size()):
		var popup = active_popups[i]
		var pos_x = center_x - (popup.size.x / 2)
		# Stack them vertically
		var pos_y = center_y + (i * (popup.size.y + spacing)) - (popup.size.y / 2)
		popup.position = Vector2(pos_x, pos_y)
