class_name ExpressionBox extends PanelContainer

enum ExpressionTypes {Variable, List, Function, Loop, Match, Element, Close}
enum ElementTypes {Paragraph, Button, Image, Header}
signal changed

var expression_instance: PackedScene = preload("res://Scenes/Expression.tscn")
var case_instance: PackedScene = preload("res://Scenes/Case.tscn")
var expression_type: ExpressionTypes
@export var expression_tabs: TabContainer
var is_child: bool = false

@export_group("Variable")
@export var value_edit: TextEdit
var value_expression = Expression.new()

@export_group("Array")
@export var items_box: VBoxContainer

@export_group("Function")
@export var func_options: OptionButton
@export var args_box: VBoxContainer

@export_group("Loop")
@export var for_edit: TextEdit
@export var iter_element_box: VBoxContainer
@export var do_box: VBoxContainer

@export_group("Match")
@export var match_expression: Container
@export var cases: VBoxContainer

@export_group("Element")
@export var element_tabs: TabContainer

@export_subgroup("Paragraph")
@export var paragraph_text: Container

@export_subgroup("Button")
@export var button_text: Container
@export var button_condition: Container
@export var button_finished: Container

@export_subgroup("Image")
@export var image_path: Container

@export_subgroup("Header")
@export var country1_name: Container
@export var country2_name: Container

func ToDict():
	match expression_tabs.current_tab:
		ExpressionTypes.Variable:
			var error = value_expression.parse(value_edit.text)
			if error != OK:
				return value_edit.text
			
			var result = value_expression.execute([], self)
			if value_expression.has_execute_failed():
				return value_edit.text
			return result

		ExpressionTypes.List:
			return items_box.get_children().map(func(x): return x.ToDict())

		ExpressionTypes.Function:
			return {
				"func": func_options.text,
				"args": args_box.get_children().map(func(x): return x.ToDict())
				}

		ExpressionTypes.Loop:
			return {
				"for": for_edit.text,
				"in": iter_element_box.get_children().map(func(x): return x.ToDict()),
				"do": do_box.get_children().map(func(x): return x.ToDict()),
				}

		ExpressionTypes.Match:
			var fish = {}
			if match_expression.get_child_count() > 0:
				fish["match"] = match_expression.get_child(0).ToDict()
			
			for case in cases.get_children():
				fish.merge(case.ToDict())
			return fish

		ExpressionTypes.Element:
			match element_tabs.current_tab:
				ElementTypes.Paragraph:
					return {
						"type": "paragraph",
						"text": paragraph_text.get_child(0).ToDict(),
						}

				ElementTypes.Button:
					return {
						"type": "button",
						"text": button_text.get_child(0).ToDict(),
						"condition": button_condition.get_child(0).ToDict(),
						"finished": button_finished.get_child(0).ToDict(),
						}

				ElementTypes.Image:
					return {
						"type": "image",
						"text": image_path.get_child(0).ToDict(),
						}

				ElementTypes.Header:
					return {
						"type": "country_header",
						"country1": country1_name.get_child(0).ToDict(),
						"country2": country2_name.get_child(0).ToDict(),
						}

func FromDict(data):
	if typeof(data) == TYPE_ARRAY:
		expression_tabs.current_tab = ExpressionTypes.List
		for item in data:
			add_expression(items_box).FromDict(item)
		return

	if typeof(data) != TYPE_DICTIONARY:
		expression_tabs.current_tab = ExpressionTypes.Variable
		if value_edit: value_edit.text = str(data)
		return

	if data.has("func"):
		expression_tabs.current_tab = ExpressionTypes.Function
		var idx = -1
		for i in func_options.item_count:
			if func_options.get_item_text(i) == data["func"]:
				idx = i
				break
		if idx != -1:
			func_options.select(idx)
		
		for arg in data["args"]:
			add_expression(args_box).FromDict(arg)
	elif data.has("for"):
		expression_tabs.current_tab = ExpressionTypes.Loop
		if for_edit: for_edit.text = data["for"]
		for item in data["in"]:
			add_expression(iter_element_box).FromDict(item)
		for item in data["do"]:
			add_expression(do_box).FromDict(item)
	elif data.has("match"):
		expression_tabs.current_tab = ExpressionTypes.Match
		add_expression(match_expression).FromDict(data["match"])
		for key in data.keys():
			if key == "match": continue
			_on_add_case_pressed().FromDict({key: data[key]})
	elif data.has("type"):
		expression_tabs.current_tab = ExpressionTypes.Element
		_on_expression_type_tab_selected(ExpressionTypes.Element)
		match data["type"]:
			"paragraph":
				element_tabs.current_tab = ElementTypes.Paragraph
				paragraph_text.get_child(0).FromDict(data["text"])
			"button":
				element_tabs.current_tab = ElementTypes.Button
				button_text.get_child(0).FromDict(data["text"])
				button_condition.get_child(0).FromDict(data["condition"])
				button_finished.get_child(0).FromDict(data["finished"])
			"image":
				element_tabs.current_tab = ElementTypes.Image
				image_path.get_child(0).FromDict(data["text"])
			"country_header":
				element_tabs.current_tab = ElementTypes.Header
				country1_name.get_child(0).FromDict(data["country1"])
				country2_name.get_child(0).FromDict(data["country2"])


func _ready() -> void:
	expression_tabs.set_tab_hidden(ExpressionTypes.Close, !is_child)
	for function in InterpreterManager.functions:
		func_options.add_item(function)
	
	# Connect change signals
	expression_tabs.tab_selected.connect(func(_tab): changed.emit())
	func_options.item_selected.connect(func(_idx): changed.emit())
	if value_edit: value_edit.text_changed.connect(func(): changed.emit())
	if for_edit: for_edit.text_changed.connect(func(): changed.emit())

func _add_inital_expression(box: Container):
	if !box.get_children():
		var expr: ExpressionBox = expression_instance.instantiate()
		expr.expression_tabs.current_tab = ExpressionTypes.Variable
		expr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		expr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(expr)


func _on_expression_type_tab_selected(tab: int) -> void:
	match tab:
		ExpressionTypes.Close:
			queue_free()
		ExpressionTypes.Loop:
			_add_inital_expression(iter_element_box)
			_add_inital_expression(do_box)
		ExpressionTypes.Match:
			_add_inital_expression(match_expression)
		ExpressionTypes.Element:
			_add_inital_expression(paragraph_text)
			_add_inital_expression(button_text)
			_add_inital_expression(button_condition)
			_add_inital_expression(button_finished)
			_add_inital_expression(country1_name)
			_add_inital_expression(country2_name)
			_add_inital_expression(image_path)
		_:
			expression_type = tab as ExpressionTypes
	changed.emit()
	

func add_expression(container: Node) -> ExpressionBox:
	var expr: ExpressionBox = expression_instance.instantiate()
	expr.is_child = true
	container.add_child(expr)
	expr.changed.connect(func(): changed.emit())
	changed.emit()
	return expr


func _on_add_args_button_pressed() -> void:
	add_expression(args_box)


func _on_add_match_pressed() -> void:
	add_expression(match_expression)


func _on_add_iter_element_button_pressed() -> void:
	add_expression(iter_element_box)


func _on_add_do_button_pressed() -> void:
	add_expression(do_box)


func _on_add_case_pressed() -> Node:
	var case = case_instance.instantiate()
	cases.add_child(case)
	case.changed.connect(func(): changed.emit())
	changed.emit()
	return case


func _on_add_item_button_pressed() -> void:
	add_expression(items_box)
