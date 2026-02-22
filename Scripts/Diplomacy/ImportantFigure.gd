extends Resource
class_name ImportantFigure

@export var name: String

static func FromValues(a_name: String) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_name
	
	return figure

static func FromDict(a_data: Dictionary) -> ImportantFigure:
	var figure: ImportantFigure = ImportantFigure.new()
	
	figure.name = a_data["name"]
	
	return figure

func ToDict() -> Dictionary:
	return {
		"name": self.name
	}
