extends Control


@export var USSR: Array[Texture]
@export var SupremeSoviet: int = 0
@export var AvatarImage: TextureRect

func OnTimerTimeout() -> void:
	SupremeSoviet = (SupremeSoviet + 1) % USSR.size()
	AvatarImage.texture = USSR[SupremeSoviet]
