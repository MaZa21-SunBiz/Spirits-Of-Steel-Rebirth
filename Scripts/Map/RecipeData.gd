extends Resource
class_name RecipeData

@export var produced_resource: String
@export var resources_required: Array[String]

static func FromDict(a_data: Dictionary) -> RecipeData:
	var recipe: RecipeData = RecipeData.new()
	recipe.produced_resource = a_data.get("produced_resource", "")
	
	var typed_reqs: Array[String] = []
	for req in a_data.get("resources_required", []):
		typed_reqs.append(str(req))
	recipe.resources_required = typed_reqs
	
	return recipe

func ToDict() -> Dictionary:
	return {
		"produced_resource": self.produced_resource,
		"resources_required": self.resources_required,
	}
