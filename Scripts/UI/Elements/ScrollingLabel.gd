extends ScrollContainer

@export var scrollPixels: int = 5
@export var child: Control

func Ignite() -> void:
	if child.size.x - self.scroll_horizontal <= size.x:
		self.scroll_horizontal = 0
	else:
		self.scroll_horizontal += scrollPixels
