extends PanelContainer
class_name Tooltip

func _enter_tree() -> void:
	GameState.tooltip = self
	visible = false

@export var offset: Vector2 = Vector2.ZERO

@export var tabs: TabContainer
@export var resourceTemplate: HBoxContainer
@export var resourcesList: VBoxContainer
@export var provinceName: Label
@export var provinceDescription: RichTextLabel
@export var provinceInfrastructure: Label
@export var provinceConstructionIcon: TextureRect
@export var provinceOccupiedIcon: TextureRect
@export var provinceDestroyedIcon: TextureRect

var tooltipLatch: bool = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	set_position(get_global_mouse_position() + offset)
	position.x = clamp(position.x, 0, get_viewport_rect().size.x - size.x)
	position.y = clamp(position.y, 0, get_viewport_rect().size.y - size.y)

func SwitchTooltip(a_mode: int) -> void:
	match a_mode:
		-1:
			visible = false
		0:
			visible = true
			if !tooltipLatch:
				DeferredUpdate.call_deferred()
				tooltipLatch = true
			tabs.current_tab = 0
			for resource: HBoxContainer in resourcesList.get_children():
				resource.queue_free()
			var prov: Province = MapManager.province_objects[MapManager.current_hovered_pid]
			for resource: ResourceNode in prov.resources:
				var resourceBop: HBoxContainer = resourceTemplate.duplicate()
				resourceBop.get_node("TextureRect").texture = MapManager.GetResourceIcon(resource.type)
				resourceBop.get_node("Label").text = resource.type
				resourceBop.visible = true
				resourcesList.add_child(resourceBop)
		1:
			visible = true
			if !tooltipLatch:
				DeferredUpdate.call_deferred()
				tooltipLatch = true
			tabs.current_tab = 1
			var prov: Province = MapManager.province_objects[MapManager.current_hovered_pid]
			provinceName.text = prov.name
			provinceDescription.text = prov.city
			provinceInfrastructure.text = "%d/%d" % [prov.infrastructure, prov.maxInfrastructure]
			provinceConstructionIcon.visible = MapManager.current_hovered_pid in EconomyManager.construction_queue
			provinceOccupiedIcon.visible = !prov.occupier.is_empty()
			provinceDestroyedIcon.visible = false

func DeferredUpdate() -> void:
	reset_size()
	tooltipLatch = false
