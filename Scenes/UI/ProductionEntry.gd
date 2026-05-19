extends PanelContainer

@export var resource_name: String
@export var resource_label: Label
@export var resource_icon: TextureRect
@export var allocated_factories: HSlider
@export var reqs_box: Container
@export var stockpile_value: Label
@export var produced_value: Label

func setup(recipe: RecipeData) -> void:
	resource_name = recipe.produced_resource
	resource_label.text = resource_name
	
	var resource = MapManager.resources.get(resource_name)
	if resource:
		resource_icon.texture = MapManager.GetResourceIcon(resource_name)
		resource_icon.modulate = resource.color
	
	var player = CountryManager.player_country
	if player:
		# Initial value must be set BEFORE connecting signal to avoid recursive updates
		allocated_factories.value = player.factory_allocation.get(resource_name, 0)
		update_limit()
		
		if !allocated_factories.value_changed.is_connected(_on_allocated_factories_value_changed):
			allocated_factories.value_changed.connect(_on_allocated_factories_value_changed)
	
	for child in reqs_box.get_children():
		child.queue_free()
	
	for req in recipe.resources_required:
		var rect = TextureRect.new()
		rect.texture = MapManager.GetResourceIcon(req)
		rect.modulate = MapManager.resources[req].color
		rect.tooltip_text = req
		rect.use_parent_material = true
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(32, 32)
		reqs_box.add_child(rect)

func update_limit() -> void:
	var player = CountryManager.player_country
	if !player: return
	
	stockpile_value.text = str(player.stockpile.get(resource_name, 0))
	var change = player.stockpile_change.get(resource_name, 0)
	produced_value.text  = str(change)
	if change > 0:
		produced_value.add_theme_color_override("font_color", Color("#4dff4d"))
	elif change < 0:
		produced_value.add_theme_color_override("font_color", Color("#ff4d4d"))
	else:
		produced_value.remove_theme_color_override("font_color")
	var current_total = player.get_total_allocated_factories()
	var current_val = player.factory_allocation.get(resource_name, 0)
	var available = player.factories_amount - current_total
	
	# Safety check: available should never be negative, but let's be sure
	var max_val = max(current_val, current_val + available)
	
	allocated_factories.max_value = max_val
	allocated_factories.tick_count = max_val+1
	# Update the label to show current allocation
	resource_label.text = "%s, Factories: (%d/%d)" % [resource_name, current_val, max_val]

func _on_allocated_factories_value_changed(value: float) -> void:
	var player = CountryManager.player_country
	if !player: return
	
	player.factory_allocation[resource_name] = int(value)
	player.recalculate_stockpile_change()
	
	# Update all sliders and trade labels in the UI
	if GameState.game_ui:
		GameState.game_ui.update_production_menu()
		GameState.game_ui.update_trade_menu()
