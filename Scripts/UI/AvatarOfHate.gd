extends Control


@export var USSR: Array[Texture]
@export var AvatarImage: TextureRect

func OnTimerTimeout() -> void:
	AvatarImage.texture = USSR.pick_random()
