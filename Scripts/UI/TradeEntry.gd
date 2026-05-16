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
		# Use trade_settings for the user's defined trade volume
		exports.value = player.trade_settings.get(resource.name, 0)
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
		player.trade_settings[resource_data.name] = int(value)
		player.recalculate_stockpile_change()
		
		# Update the whole trade menu to reflect changes in other resources (e.g. if trade affects production indirectly)
		if GameState.game_ui:
			GameState.game_ui.update_trade_menu()
