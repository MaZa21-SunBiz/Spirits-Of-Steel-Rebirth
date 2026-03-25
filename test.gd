extends SceneTree

func _init():
	print("Checking Audio Server...")
	var layout = ProjectSettings.get_setting("audio/buses/default_bus_layout")
	print("Layout from settings: ", layout)
	print("Music exist: ", AudioServer.get_bus_index("Music"))
	print("SFX exist: ", AudioServer.get_bus_index("SFX"))
	
	if AudioServer.get_bus_index("Music") >= 0:
		print("Music Bus Vol: ", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	quit()
