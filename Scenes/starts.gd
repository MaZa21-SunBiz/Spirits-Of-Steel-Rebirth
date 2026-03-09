extends Control
var starts_folder
const START_ENTRY_SCENE = preload("res://Scenes/Start.tscn")
@onready var start_entry = $PanelContainer2/ScrollContainer/GridContainer

func _ready() -> void:
	if OS.has_feature("standalone"):
		var exe_dir = OS.get_executable_path().get_base_dir()
		starts_folder = exe_dir + "starts"
	else:
		starts_folder = "res://starts/"
	print(starts_folder)
	var starts_dir = DirAccess.open(starts_folder)
	for start in starts_dir.get_directories():
		var entry = START_ENTRY_SCENE.instantiate()
		start_entry.add_child(entry)
		entry.setup(start, starts_folder + start + "/thumbnail.png", starts_folder + start + "/map_data.json")
		print(start)

func _process(delta: float) -> void:
	pass
