extends HBoxContainer

@onready var icon: TextureRect = $Icon
@onready var resource_name: Label = %ResourceName
@onready var resource_stock: Label = %ResourceStock
@onready var exports: SpinBox = $Exports

var resource_data: ResourceData

func setup(resource: ResourceData) -> void:
	resource_data = resource
	resource_name.text = resource.name
	icon.texture = MapManager.GetResourceIcon(resource.name)
	
	var player = CountryManager.player_country
	if player:
		exports.value = player.stockpile_change.get(resource.name, 0)
		update_stock_label()

func update_stock_label() -> void:
	var player = CountryManager.player_country
	if player:
		resource_stock.text = (
			"In Stock: " + str(player.stockpile.get(resource_data.name, 0)) 
			+ ", Net Change: " + str(player.stockpile_change.get(resource_data.name, 0))
		)

func _on_exports_value_changed(value: float) -> void:
	var player = CountryManager.player_country
	if player:
		player.stockpile_change[resource_data.name] = int(value)
		update_stock_label()
		# print(player.stockpile_change)
