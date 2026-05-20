extends HBoxContainer

@export var icon: TextureRect
@export var resource_name: Label
@export var resource_stock: RichTextLabel
@export var exports: SpinBox

var resource_data: ResourceData

func setup(resource: ResourceData) -> void:
	resource_data = resource
	resource_name.text = resource.name.capitalize()
	icon.texture = MapManager.GetResourceIcon(resource.name)
	icon.modulate = resource.color
	
	var player = CountryManager.player_country
	if player:
		# Use trade_settings for the user's defined trade volume
		exports.value = player.trade_settings.get(resource.name, 0)
		update_stock_label()

func update_stock_label() -> void:
	var player = CountryManager.player_country
	if player:
		var price = EconomyManager.get_resource_price(resource_data.name)
		var volume = player.trade_settings.get(resource_data.name, 0)
		var daily_profit_loss = - (volume * 24 * price)
		var net_change = player.stockpile_change.get(resource_data.name, 0)
		
		var net_color = "#ff4d4d" if net_change < 0 else ("#4dff4d" if net_change > 0 else "#ffffff")
		var income_color = "#ff4d4d" if daily_profit_loss < 0 else ("#4dff4d" if daily_profit_loss > 0 else "#ffffff")
		
		resource_stock.text = (
			"Price: $" + str(price)
			+"\nIn Stock: " + str(player.stockpile.get(resource_data.name, 0))
			+"\nNet Change: [color=" + net_color + "]" + str(net_change) + "[/color]"
			+"\nDaily Income: [color=" + income_color + "]$" + GameState.game_ui.format_number(daily_profit_loss) + "[/color]"
		)

func _on_exports_value_changed(value: float) -> void:
	var player = CountryManager.player_country
	if player:
		var initial_stock: int = player.trade_settings.get_or_add(resource_data.name, 0)
		player.trade_settings[resource_data.name] = int(value)
		if !EconomyManager.world_stockpile.has(resource_data.name): EconomyManager.world_stockpile[resource_data.name] = 0
		EconomyManager.world_stockpile[resource_data.name] += value - initial_stock
		player.recalculate_stockpile_change()
		print(EconomyManager.world_stockpile)
		
		# Update the whole trade menu to reflect changes in other resources (e.g. if trade affects production indirectly)
		if GameState.game_ui:
			GameState.game_ui.update_trade_menu()
