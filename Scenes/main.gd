extends Node2D
class_name Main


func _ready() -> void:
	SceneSwitcher.switch_to(SceneSwitcher.Type.MENU)
