extends Node2D
class_name Main


func _ready() -> void:
	for i in range(100):
		print("%3d) %s" % [i + 1, NameGenerator.GenerateName(i % 2 == 0, randi_range(3, 15)).capitalize()])
	SceneSwitcher.switch_to(SceneSwitcher.Type.MENU)
