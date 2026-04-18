extends FoldableContainer
signal changed

@export var block: VBoxContainer 
@export var case_edit: TextEdit 

func FromDict(data: Dictionary) -> void:
	var key = data.keys()[0]
	if case_edit: case_edit.text = str(key)
	var arr = data[key] if typeof(data[key]) == TYPE_ARRAY else [data[key]]
	for expr_data in arr:
		var expr = ExpressionBox.FromDict(expr_data, true)
		block.add_child(expr)
		expr.changed.connect(func(): changed.emit())
	changed.emit()
	
	if !case_edit.text_changed.is_connected(changed.emit):
		case_edit.text_changed.connect(func(): changed.emit())


func ToDict():
	return {
		case_edit.text: block.get_children().map(
			func(x): return x.ToDict()
			)
		}

func _on_add_function_pressed() -> ExpressionBox:
	var expr: ExpressionBox = load("res://Scenes/Expression.tscn").instantiate()
	expr.is_child = true
	block.add_child(expr)
	expr.changed.connect(func(): changed.emit())
	changed.emit()
	return expr


func _on_close_pressed() -> void:
	queue_free()


func _on_case_entry_text_changed() -> void:
	self.title = case_edit.text
