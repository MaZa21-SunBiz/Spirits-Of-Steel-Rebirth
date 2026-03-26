extends PanelContainer

@export var functions_list: VBoxContainer 
@export var functions_grid: GridContainer 
@export var building_name: TextEdit 
@export var feasibility_text: Label
@export var add_building: Button

var current_building_template: Dictionary = {}
var feasability: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for function_name in EconomyManager.building_functions:
		var function_btn
		var reqs = EconomyManager.building_functions[function_name]["reqs_effects"]
		match typeof(reqs["val"]):
			TYPE_FLOAT:
				var text = Label.new()
				text.text = function_name
				text.use_parent_material = true
				text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				functions_list.add_child(text)

				var slider = HSlider.new()
				slider.max_value = reqs["val"]
				slider.min_value = -reqs["val"]
				slider.use_parent_material = true
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.value_changed.connect(
					func(goob: float):
						current_building_template[reqs["type"]] = goob
						print(current_building_template)
				)
				functions_list.add_child(slider)

			TYPE_DICTIONARY:
				var header: Label = Label.new()
				header.text = function_name 
				functions_list.add_child(header)
				functions_list.add_child(HSeparator.new())

				for key in reqs["val"]:
					var text = Label.new()
					text.text = key
					text.use_parent_material = true
					text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					functions_list.add_child(text)

					var spinbox = SpinBox.new()
					spinbox.max_value = reqs["val"][key]
					spinbox.min_value = -reqs["val"][key]
					spinbox.use_parent_material = true
					spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					spinbox.value_changed.connect(
						func(goob: float):
							if !current_building_template.has(reqs["type"]):
								current_building_template[reqs["type"]] = {}
							current_building_template[reqs["type"]][key] = goob
							_set_feasible(reqs["type"])
							print(current_building_template)
					)
					functions_list.add_child(spinbox)
				pass
			TYPE_BOOL:
				function_btn = CheckButton.new()
				function_btn.text = function_name
				function_btn.use_parent_material = true
				function_btn.toggled.connect(
					func(goob: bool):
						current_building_template[reqs["type"]] = goob
						print(current_building_template)
				)

		functions_list.add_child(function_btn)
		# functions_list.add_child(HSeparator.new())

func _set_feasible(resource):
	feasability = current_building_template[resource].values().reduce(func(a, b): return a+b, 0) == 0
	add_building.disabled = feasability
	feasibility_text.text = "Feasible: %s" % str(feasability)

func _on_add_building_pressed () -> void :
	if !EconomyManager.building_designs.has(CountryManager.player_country.country_name):
		EconomyManager.building_designs[CountryManager.player_country.country_name] = []

	print(current_building_template)
	EconomyManager.building_designs[CountryManager.player_country.country_name].append(
		BuildingTemplate.FromDict(current_building_template)
	)
	print(EconomyManager.building_designs)


func _on_building_name_changed() -> void:
	current_building_template["name"] = building_name.text
