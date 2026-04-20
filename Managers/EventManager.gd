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
func show_alert(data: Dictionary):
	var popup: Node
	# Delegate based on type
	match data.get("event", "default"):
		"super":
			popup = _trigger_super_event(data)
		"custom":
			popup = _trigger_custom_event(data)
		_:
			popup = _trigger_default_alert(data)
	_add_popup_to_ui(popup)


func _trigger_default_alert(data: Dictionary) -> Node:
	var popup = ALERT_POPUP_SCENE.instantiate()
	popup.setup_alert(data)
	return popup


func _trigger_super_event(data: Dictionary) -> Node:
	var popup = SUPER_EVENT_SCENE.instantiate()
	
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
	return popup


func _trigger_custom_event(data: Dictionary) -> Node:
	var popup = CUSTOM_EVENT_SCENE.instantiate()
	popup.setup(data)
	return popup


var restackLatch: bool = false

func _add_popup_to_ui(popup: Control):
	ui_layer.add_child(popup)
	active_popups.append(popup)

	popup.reset_size()
	
	if !restackLatch:
		restackLatch = true
		_restack_popups.call_deferred()

	if popup.has_signal("setup_finished"):
		popup.setup_finished.connect(
			func():
				if !restackLatch:
					restackLatch = true
					_restack_popups.call_deferred()
		)

	popup.tree_exited.connect(
		func():
			active_popups.erase(popup)
			if !restackLatch:
				restackLatch = true
				_restack_popups.call_deferred()
	)


func _restack_popups():
	var viewport = get_viewport()
	if not viewport:
		return
		
	var viewport_size = viewport.get_visible_rect().size
	var center_y = viewport_size.y * 0.2
	var center_x = viewport_size.x * 0.5
	var spacing = 25

	for i in range(active_popups.size()):
		var popup = active_popups[i]
		if popup.get("manually_positioned") == true:
			continue
			
		var pos_x = center_x - (popup.size.x * 0.5)
		var pos_y = center_y + ((active_popups.size() - 1 - i) * (popup.size.y + spacing)) - (popup.size.y * 0.5)
		popup.position = Vector2(pos_x, pos_y)
	restackLatch = false

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
			_add_popup_to_ui(_trigger_super_event(event))
			remove.append(index_cur)
		index_cur += 1
	remove.reverse()
	for index in remove:
		super_events.remove_at(index)
