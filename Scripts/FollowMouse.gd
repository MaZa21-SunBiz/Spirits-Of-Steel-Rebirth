extends PanelContainer

func _enter_tree() -> void:
	GameState.tooltip = self

@export var offset: Vector2 = Vector2.ZERO
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_position(get_global_mouse_position() + offset)
	position.x = clamp(position.x, 0, get_viewport_rect().size.x - size.x)
	position.y = clamp(position.y, 0, get_viewport_rect().size.y - size.y)
