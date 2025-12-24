extends Button

@export var decision_tree: DecisionTree


func _on_button_up() -> void:
	decision_tree.open_tree()
	MainClock.pause()
	GameState.decision_tree_open = true
