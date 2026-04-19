extends SceneTree

func _init():
	var file = FileAccess.open("res://starts/ModernDay/decisions/Russia.json", FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	var russia = json.get_data()
	
	for cat in russia.get("category", []):
		if cat.get("title") == "Unify with Former Soviet Countries":
			for action in cat.get("action", []):
				if action.has("in"):
					var expr_script = load("res://Scripts/UI/Elements/ExpressionBox.gd")
					var box = expr_script.FromDict(action, false)
					print(box.ToDict())
	quit()
