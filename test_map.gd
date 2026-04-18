extends SceneTree
func _init():
	var node = Node.new()
	var child1 = Node.new()
	var child2 = Node.new()
	node.add_child(child1)
	node.add_child(child2)
	var arr = node.get_children().map(func(x): return {"hello": "world"})
	print("MAPPED: ", arr)
	print("JSON: ", JSON.stringify(arr))
	quit()
