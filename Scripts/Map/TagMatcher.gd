class_name TagMatcher
extends RefCounted

var expression := Expression.new()

var local_pool: Dictionary = {}

var slotted_resources: Array = []
var evaluated_resource: ResourceData = null # Used for evaluating a single resource's validity

func _init(local: Dictionary):
	self.local_pool = local

func set_context(resources: Array):
	self.slotted_resources = resources

func set_eval_resource(res: ResourceData):
	self.evaluated_resource = res

# -----------------
# For validating an OptionButton choice:
func has_tag(tag_name: String) -> bool:
	if evaluated_resource != null:
		return evaluated_resource.tags.has(tag_name)
	return false

func tag_val(tag_name: String) -> float:
	if evaluated_resource != null and evaluated_resource.tags.has(tag_name):
		return evaluated_resource.tags[tag_name]
	return 0.0
# -----------------

# -----------------
# For evaluating the functionality math formulas:
func input_amount(index: int) -> float:
	if index >= 0 and index < slotted_resources.size():
		return slotted_resources[index].get("amount", 0.0)
	return 0.0

func input_has_tag(index: int, tag_name: String) -> bool:
	if index >= 0 and index < slotted_resources.size():
		var r = slotted_resources[index].get("resource")
		if r != null:
			return r.tags.has(tag_name)
	return false

func input_tag_val(index: int, tag_name: String) -> float:
	if index >= 0 and index < slotted_resources.size():
		var r = slotted_resources[index].get("resource")
		if r != null and r.tags.has(tag_name):
			return r.tags[tag_name]
	return 0.0

func local_pool_amount(tag_name: String) -> float:
	return local_pool.get(tag_name, 0.0)
# -----------------

func evaluate(expr_string: String):
	if expr_string == "" or expr_string == "true": return true
	var error = expression.parse(expr_string)
	if error != OK:
		push_error("TagMatcher Parse Error: " + expression.get_error_text())
		return false
	var result = expression.execute([], self)
	if expression.has_execute_failed():
		push_error("TagMatcher Execute Error in: " + expr_string)
		return false
	return result
