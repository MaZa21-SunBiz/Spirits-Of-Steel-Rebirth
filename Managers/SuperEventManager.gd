extends Node

var events: Array = []

const SUPER_EVENT_SCENE = preload("res://Scenes/SuperEvent.tscn")

var canvas_layer: CanvasLayer = CanvasLayer.new()

func _ready():
	# Create a high-layer canvas to ensure it's on top of map/other UI
	canvas_layer.layer = 101 # A bit higher than standard UI (100)
	add_child(canvas_layer)
	_load_events("res://superevents.json")


func load_events_from_path(path: String):
	_load_events(path)


func _load_events(path: String):
	events.clear()
	var file = FileAccess.get_file_as_string(path)
	if file:
		var json = JSON.parse_string(file)
		if json:
			for eventData in json.get("events", []):
				if eventData.has("cause") and not eventData["cause"].is_empty():
					events.append(eventData)

func check_events():
	var remove: PackedInt32Array = []
	var indexCur: int = 0
	for event in events:
		if InterpreterManager.get_function(event.get("cause", {})):
			_trigger_event(event)
			remove.append(indexCur)
		indexCur += 1
	remove.reverse()
	for index in remove:
		events.remove_at(index)


func _trigger_event(data: Dictionary):
	var popup = SUPER_EVENT_SCENE.instantiate()
	canvas_layer.add_child(popup)
	
	# Center on screen
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# Call setup
	popup.setup(data)
	popup.position -= Vector2(210, 126)
	
	# Optional: Play music from JSON
	if data.has("music"):
		# Try extensions (mp3/ogg)
		var base_path = "res://assets/music/superevents/" + data["music"]
		if FileAccess.file_exists(base_path + ".mp3"):
			MusicManager.play_custom_file(base_path + ".mp3")
		elif FileAccess.file_exists(base_path + ".ogg"):
			MusicManager.play_custom_file(base_path + ".ogg")
		else:
			push_warning("SuperEvent: Music file not found for " + data["music"])
	else:
		# Fallback to SFX if no specific music
		MusicManager.play_sfx(MusicManager.SFX.POPUP)
