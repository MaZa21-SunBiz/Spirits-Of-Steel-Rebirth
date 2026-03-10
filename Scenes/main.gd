extends Node2D
class_name Main
@onready var culture_sprite: Sprite2D = $MapContainer/CultureSprite
@export var clock: GameClock
@onready var camera_controller: Node = $Camera2D/CameraController


func _enter_tree() -> void:
	GameState.main = self
	GameState.camera = camera_controller


func _ready() -> void:
<<<<<<< HEAD
	GameState.main.clock.pause()
=======
	GameState.current_world.clock.pause()
	GameState.game_ui._update_flag()
	SceneSwitcher.switch_to(SceneSwitcher.Type.WORLD)
>>>>>>> origin/SoiSauce
