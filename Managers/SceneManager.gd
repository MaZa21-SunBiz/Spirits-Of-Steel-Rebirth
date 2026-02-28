extends Node

enum Type { MENU, WORLD, EDITOR, SELECT_COUNTRY }

const SCENE_MAP = {
	Type.MENU: "res://Scenes/main_menu.tscn",
	Type.WORLD: "res://Scenes/world.tscn",
	Type.EDITOR: "res://Scenes/map_editor.tscn",
	Type.SELECT_COUNTRY: "res://Scenes/select_country.tscn"
}



var _world_cache: Node = null # We only care about saving this one
var _current_type: int = -1

func has_active_world() -> bool:
	return is_instance_valid(_world_cache)
	
func is_world_active() -> bool:
	return _current_type == Type.WORLD

func switch_to(scene_type: Type) -> void:
	if scene_type == _current_type: return
		
	var main := get_tree().current_scene
	var container := main.get_node("CurrentScene")
	
	# 1. Handle the scene we are LEAVING
	if container.get_child_count() > 0:
		var old_scene = container.get_child(0)
		if _current_type == Type.WORLD:
			# If it's the world, just detach it so we keep the data
			container.remove_child(old_scene)
		else:
			# If it's a menu/editor, delete it to save memory
			old_scene.queue_free()

	# 2. Handle the scene we are ENTERING
	var next_scene: Node
	
	if scene_type == Type.WORLD:
		if _world_cache:
			next_scene = _world_cache
		else:
			next_scene = _instantiate_by_type(scene_type)
			_world_cache = next_scene
	else:
		# Always a fresh copy for menus/editors
		next_scene = _instantiate_by_type(scene_type)

	# 3. Add to tree
	if next_scene:
		container.add_child(next_scene)
		_current_type = scene_type

func _instantiate_by_type(type: Type) -> Node:
	var path = SCENE_MAP.get(type)
	var packed_scene = load(path)
	return packed_scene.instantiate() if packed_scene else null
