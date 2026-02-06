extends Node

var events: Dictionary = {}
var triggered_events: Dictionary = {} # { "WW3": true }

const SUPER_EVENT_SCENE = preload("res://Scenes/SuperEvent.tscn")

var canvas_layer: CanvasLayer = CanvasLayer.new()

func _ready():
	# Create a high-layer canvas to ensure it's on top of map/other UI
	canvas_layer.layer = 101 # A bit higher than standard UI (100)
	add_child(canvas_layer)
	_load_events()

func _load_events():
	var file = FileAccess.get_file_as_string("res://superevents.json")
	if file:
		var json = JSON.parse_string(file)
		if json:
			events = json

func check_events():
	if events.is_empty():
		return
		
	for event_id in events.keys():
		 # Skip if already happened
		if triggered_events.has(event_id):
			continue
			
		var event_data = events[event_id]
		if _check_condition(event_data.get("cause", {})):
			_trigger_event(event_id, event_data)

func _check_condition(cause: Dictionary) -> bool:
	if cause.is_empty():
		return false
		
	return InterpreterManager.get_function(cause)

func _trigger_event(event_id: String, data: Dictionary):
	triggered_events[event_id] = true
	
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
