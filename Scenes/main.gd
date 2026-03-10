extends Node2D
class_name Main
@onready var culture_sprite: Sprite2D = $MapContainer/CultureSprite
@export var clock: GameClock
@onready var camera_controller: Node = $Camera2D/CameraController


func _enter_tree() -> void:
	GameState.main = self


func _ready() -> void:
	GameState.camera = camera_controller
	GameState.main.clock.pause()
