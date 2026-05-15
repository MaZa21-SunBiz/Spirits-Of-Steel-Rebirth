extends Control


@export var USSR: Array[Texture]
@export var AvatarImage: TextureRect
@export_dir var directory_path: String

func _ready() -> void:
	if directory_path != "":
		_load_images_from_dir(directory_path)

func _load_images_from_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext in ["png", "jpg", "jpeg", "webp", "svg"]:
					var full_path = path.path_join(file_name)
					var tex = load(full_path)
					if tex is Texture:
						USSR.append(tex)
			file_name = dir.get_next()
	else:
		printerr("AvatarOfHate: Failed to open directory: ", path)

func OnTimerTimeout() -> void:
	AvatarImage.texture = USSR.pick_random()
