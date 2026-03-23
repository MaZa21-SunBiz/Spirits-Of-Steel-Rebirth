extends Node

var active_popups: Array = []

const ALERT_POPUP_SCENE = preload("res://Scenes/AlertPopup.tscn")
const SUPER_EVENT_SCENE = preload("res://Scenes/SuperEvent.tscn")
const CUSTOM_EVENT_SCENE = preload("res://Scenes/CustomEventPopup.tscn")

var ui_layer: CanvasLayer = CanvasLayer.new()
var super_events: Array = []


func _ready():
	ui_layer.layer = 100
	add_child(ui_layer)
	load_super_events("res://superevents.json")


# UNIFIED ENTRY POINT
func show_alert(
	type_or_data: Variant,
	c1: Variant = null,
	c2: Variant = null,
	custom_text: String = "",
	extra_params: Dictionary = {}
):
	var type: String = ""
	var data: Dictionary = {}

	if type_or_data is Dictionary:
		data = type_or_data
		type = data.get("event", "event")
		c1 = data.get("c1", c1)
		c2 = data.get("c2", c2)
		custom_text = data.get("text", custom_text)
		extra_params = data
		
		# Handle string to CountryData conversion
		if c1 is String:
			c1 = CountryManager.get_country(c1)
		if c2 is String:
			c2 = CountryManager.get_country(c2)
	else:
		type = str(type_or_data)
		data = extra_params

	# Delegate based on type
	match type:
		"super":
			_trigger_super_event(data)
		"custom":
			_trigger_custom_event(data)
		_:
			_show_standard_alert.call_deferred(type, c1, c2, custom_text, extra_params)


func _show_standard_alert(
	type: String,
	c1: CountryData,
	c2: CountryData,
	text: String,
	params: Dictionary
):
	var popup = ALERT_POPUP_SCENE.instantiate()
	popup.setup_alert(
		{"type": type, "c1": c1, "c2": c2, "text": text, "params": params}
	)
	_add_popup_to_ui(popup)


func _trigger_super_event(data: Dictionary):
	var popup = SUPER_EVENT_SCENE.instantiate()
	_add_popup_to_ui(popup)
	
	# Center and setup (migrated logic)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.setup(data)
	popup.position -= Vector2(210, 126)
	
	if data.has("music"):
		var base_path = "res://assets/music/superevents/" + data["music"]
		if FileAccess.file_exists(base_path + ".mp3"):
			MusicManager.play_custom_file(base_path + ".mp3")
		elif FileAccess.file_exists(base_path + ".ogg"):
			MusicManager.play_custom_file(base_path + ".ogg")
	else:
		MusicManager.play_sfx(MusicManager.SFX.POPUP)


func _trigger_custom_event(data: Dictionary):
	var popup = CUSTOM_EVENT_SCENE.instantiate()
	_add_popup_to_ui(popup)
	popup.setup(data)


func _add_popup_to_ui(popup: Control):
	ui_layer.add_child(popup)
	active_popups.append(popup)

	if popup.has_method("reset_size"):
		popup.call_deferred("reset_size")
		
	call_deferred("_restack_popups")

	popup.tree_exited.connect(
		func():
			active_popups.erase(popup)
			_restack_popups()
	)


func show_custom_popup(popup: Control) -> void:
	_add_popup_to_ui(popup)


func _restack_popups():
	var viewport = get_viewport()
	if not viewport:
		return
		
	var viewport_size = viewport.get_visible_rect().size
	var center_y = viewport_size.y * 0.5
	var center_x = viewport_size.x * 0.5
	var spacing = 25

	for i in range(active_popups.size()):
		var popup = active_popups[i]
		if popup.get("manually_positioned") == true:
			continue
			
		var pos_x = center_x - (popup.size.x * 0.5)
		var pos_y = center_y + (i * (popup.size.y + spacing)) - (popup.size.y * 0.5)
		popup.position = Vector2(pos_x, pos_y)


# SUPER EVENT MIGRATED LOGIC
func load_super_events(path: String):
	super_events.clear()
	var file = FileAccess.get_file_as_string(path)
	if file:
		var json: Dictionary = JSON.parse_string(file)
		if json:
			for event_data in json.get("events", []):
				if event_data.has("cause") and not event_data["cause"].is_empty():
					super_events.append(event_data)


func check_super_events():
	var remove: PackedInt32Array = []
	var index_cur: int = 0
	for event in super_events:
		if InterpreterManager.get_function(event.get("cause", {})):
			_trigger_super_event(event)
			remove.append(index_cur)
		index_cur += 1
	remove.reverse()
	for index in remove:
		super_events.remove_at(index)
