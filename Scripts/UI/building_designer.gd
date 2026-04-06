extends PanelContainer

@export var functions_list: VBoxContainer
@export var functions_grid: GridContainer
@export var building_name: TextEdit
@export var feasibility_text: Label
@export var add_building: Button
@export var existing_design: VBoxContainer

var current_building_template: Dictionary = {}

var selected_functionalities: Array[String] = []

# Maps functionality names to their specific VBoxContainers containing their OptionButtons/Sliders
var func_ui_containers: Dictionary = {}

var active_tag_matcher: TagMatcher = TagMatcher.new({})
var editing_design_index: int = -1

func _ready() -> void:
	# var funcs_label = Label.new()
	# funcs_label.text = "--- Functionalities ---"
	# inputs_list_or_grid().add_child(funcs_label)
	# Add Checkboxes for all available building functions
	for function_name in EconomyManager.building_functions:
		var func_data = EconomyManager.building_functions[function_name]
		var cb = CheckButton.new()
		cb.text = function_name
		cb.toggled.connect(func(toggled_on: bool):
			if toggled_on:
				if not selected_functionalities.has(function_name):
					selected_functionalities.append(function_name)
					_spawn_func_ui(function_name, func_data)
			else:
				selected_functionalities.erase(function_name)
				_destroy_func_ui(function_name)
			_recalculate()
		)
		inputs_list_or_grid().add_child(cb)

	_refresh_existing_designs()

func inputs_list_or_grid() -> Container:
	if functions_list != null:
		return functions_list
	return functions_grid

func _spawn_func_ui(func_name: String, func_data: Dictionary):
	var vbox = VBoxContainer.new()
	
	if func_data.has("input"):
		var match_index = 0
		for i in range(func_data["input"].size()):
			active_tag_matcher.slotted_resources.append({})
		
		for inp in func_data["input"]:
			# 1. Match type (Card with Dropdown + Amount UI)
			if inp.has("match"):
				var card = PanelContainer.new()
				var card_vbox = VBoxContainer.new()
				
				# Top row: Dropdown
				var hbox_opt = HBoxContainer.new()
				var lbl = Label.new()
				lbl.text = "Input %d" % match_index
				var opt = OptionButton.new()
				opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				opt.add_item("...")
				opt.set_meta("match_expr", inp["match"])
				opt.set_meta("last_selected", "")
				opt.item_selected.connect(func(_idx): _recalculate())
				
				hbox_opt.add_child(lbl)
				hbox_opt.add_child(opt)
				card_vbox.add_child(hbox_opt)
				
				# Bottom row: Amount UI
				var amount_data = inp.get("amount", "0")
				_build_amount_ui(card_vbox, amount_data)
				
				card.add_child(card_vbox)
				vbox.add_child(card)
				match_index += 1
			
			# 2. Resource Tag type (Label + Amount UI)
			elif inp.has("resource_tag"):
				var r_tag = str(inp["resource_tag"])
				var hbox = HBoxContainer.new()
				var lbl = Label.new()
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				lbl.text = "Pool Req: " + r_tag
				hbox.add_child(lbl)
				
				var amount_data = inp.get("amount", "0")
				var amount_cnt = VBoxContainer.new()
				amount_cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				amount_cnt.set_meta("resource_tag", r_tag)
				
				_build_amount_ui(amount_cnt, amount_data)
				hbox.add_child(amount_cnt)
				vbox.add_child(hbox)
				
				match_index += 1

	func_ui_containers[func_name] = vbox
	
	# Find the checkbutton in the parent to insert this under it.
	for i in range(inputs_list_or_grid().get_child_count()):
		var c = inputs_list_or_grid().get_child(i)
		if c is CheckButton and c.text == func_name:
			inputs_list_or_grid().add_child(vbox)
			inputs_list_or_grid().move_child(vbox, i + 1)
			break

func _build_amount_ui(parent: Container, amount_data):
	if typeof(amount_data) == TYPE_DICTIONARY:
		var hsl = HSlider.new()
		hsl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hsl.step = 0.1
		hsl.set_meta("min_expr", amount_data.get("min", "0"))
		hsl.set_meta("max_expr", amount_data.get("max", "0"))
		
		var lbl = Label.new()
		lbl.text = "Amt: 0.0"
		hsl.value_changed.connect(func(v):
			lbl.text = "Amt: %.1f" % v
			_recalculate()
		)
		
		# Box them together
		var amt_hbox = HBoxContainer.new()
		amt_hbox.add_child(hsl)
		amt_hbox.add_child(lbl)
		
		parent.add_child(amt_hbox)
		parent.set_meta("amount_node", hsl)
	else:
		var sp = SpinBox.new()
		sp.editable = false
		sp.step = 0.1
		sp.min_value = 0.0
		sp.max_value = 999999.0
		sp.set_meta("fixed_expr", str(amount_data))
		
		var amt_hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "Fixed:"
		amt_hbox.add_child(lbl)
		amt_hbox.add_child(sp)
		
		parent.add_child(amt_hbox)
		parent.set_meta("amount_node", sp)

func _destroy_func_ui(func_name: String):
	if func_ui_containers.has(func_name):
		func_ui_containers[func_name].queue_free()
		func_ui_containers.erase(func_name)

# Gathers chosen values and resources mapping
func _gather_func_inputs() -> Dictionary:
	var mapping = {}
	for func_name in selected_functionalities:
		var slot_array: Array[Dictionary] = []
		if func_ui_containers.has(func_name):
			var vbox = func_ui_containers[func_name]
			for ui_element in vbox.get_children():
				var slot_data = {"resource": null, "amount": 0.0, "resource_tag": ""}
				
				# If Card (Match input)
				if ui_element is PanelContainer:
					var card_vc = ui_element.get_child(0)
					var hbox_opt = card_vc.get_child(0)
					var opt = hbox_opt.get_child(1) as OptionButton
					if opt.item_count > 0 and opt.selected >= 0:
						var res_name = opt.get_item_text(opt.selected)
						if res_name != "..." and MapManager.resources.has(res_name):
							slot_data["resource"] = MapManager.resources[res_name]
					
					var amt_node = card_vc.get_meta("amount_node")
					slot_data["amount"] = amt_node.value if amt_node else 0.0
				
				# If HBox (Passive resource_tag input)
				elif ui_element is HBoxContainer:
					var amt_cnt = ui_element.get_child(1)
					slot_data["resource_tag"] = amt_cnt.get_meta("resource_tag")
					
					var amt_node = amt_cnt.get_meta("amount_node")
					slot_data["amount"] = amt_node.value if amt_node else 0.0
					
				slot_array.append(slot_data)
		mapping[func_name] = slot_array
	return mapping

func _recalculate():
	var func_inputs = _gather_func_inputs()
	var local_pool = {}
	
	var template_result = {
		"name": building_name.text,
		"functionalities": selected_functionalities.duplicate(),
		"assigned_inputs": {},
		"money_cost": 0.0,
		"power": 0.0,
		"water": 0.0,
		"sewage": 0.0,
		"population": 0.0,
		"produces": 0.0,
		"storage": 0.0,
		"heal_amount": 0.0,
		"supply_amount": 0.0,
		"tech_points": 0.0,
		"on_coast": false
	}
	
	# Save the assigned configurations for the template explicitly
	for fn in func_inputs.keys():
		template_result["assigned_inputs"][fn] = []
		for slot in func_inputs[fn]:
			var d_str = {"amount": slot["amount"]}
			if slot["resource"] != null: d_str["resource"] = slot["resource"].name
			if slot["resource_tag"] != "": d_str["resource_tag"] = slot["resource_tag"]
			template_result["assigned_inputs"][fn].append(d_str)
	
	var all_feasible = true
	var tag_matcher = TagMatcher.new(local_pool)
	
	# Pass 1: Setup Sliders, Dropdowns, Production, Build Cost
	for func_name in selected_functionalities:
		var func_data = EconomyManager.building_functions[func_name]
		var slotted = func_inputs[func_name]
		tag_matcher.set_context(slotted)
		
		# --- DYNAMIC OPTION POPULATING ---
		var vbox = func_ui_containers.get(func_name)
		if vbox and func_data.has("input"):
			var match_idx = 0
			for ui_element in vbox.get_children():
				if ui_element is PanelContainer:
					var card_vc = ui_element.get_child(0)
					var hbox_opt = card_vc.get_child(0)
					var opt = hbox_opt.get_child(1) as OptionButton
					var target_match = opt.get_meta("match_expr")
					var last_sel = opt.get_item_text(opt.selected) if opt.selected >= 0 else opt.get_meta("last_selected")
					opt.clear()
					opt.add_item("...")
					
					for resource in MapManager.resources.values():
						tag_matcher.set_eval_resource(resource)
						if tag_matcher.evaluate(target_match):
							opt.add_item(resource.name)
							
					# Restore selection if valid
					var did_reselect = false
					for i in range(opt.item_count):
						if opt.get_item_text(i) == last_sel:
							opt.select(i)
							did_reselect = true
							if last_sel != "...": slotted[match_idx]["resource"] = MapManager.resources.get(last_sel)
							break
					if not did_reselect and opt.item_count > 1:
						opt.select(1)
						slotted[match_idx]["resource"] = MapManager.resources.get(opt.get_item_text(1))
					opt.set_meta("last_selected", opt.get_item_text(opt.selected))
					
					# Update Amount limits
					var amt_node = card_vc.get_meta("amount_node")
					if amt_node is HSlider:
						amt_node.min_value = _eval_or_float(amt_node.get_meta("min_expr"), tag_matcher)
						amt_node.max_value = _eval_or_float(amt_node.get_meta("max_expr"), tag_matcher)
					elif amt_node is SpinBox:
						amt_node.value = _eval_or_float(amt_node.get_meta("fixed_expr"), tag_matcher)
						
					slotted[match_idx]["amount"] = amt_node.value
				
				# Passive UI update
				elif ui_element is HBoxContainer:
					var amt_cnt = ui_element.get_child(1)
					var amt_node = amt_cnt.get_meta("amount_node")
					if amt_node is HSlider:
						amt_node.min_value = _eval_or_float(amt_node.get_meta("min_expr"), tag_matcher)
						amt_node.max_value = _eval_or_float(amt_node.get_meta("max_expr"), tag_matcher)
					elif amt_node is SpinBox:
						amt_node.value = _eval_or_float(amt_node.get_meta("fixed_expr"), tag_matcher)
						
					slotted[match_idx]["amount"] = amt_node.value
				
				match_idx += 1
		# ---------------------------------
		
		tag_matcher.set_context(slotted)
		
		# Build Cost
		# if func_data.has("build_cost"):
		# 	var bc = func_data["build_cost"]
		# 	if bc.has("money"): template_result["money_cost"] += _eval_or_float(bc["money"], tag_matcher)
		# 	if bc.has("required_tags"):
		# 		print("build_cost's required tags: ", (str(bc["required_tags"])))
		# 		print("evaluates to: ", tag_matcher.evaluate(str(bc["required_tags"])))
		# 		if not tag_matcher.evaluate(str(bc["required_tags"])):
		# 			all_feasible = false
		
		# Production (Outputs)
		if func_data.has("output"):
			for out in func_data["output"]:
				var tag = out.get("tag", "")
				var amt = _eval_or_float(out.get("amount", "0"), tag_matcher)
				
				if template_result.has(tag):
					if typeof(template_result[tag]) == TYPE_BOOL: template_result[tag] = (amt > 0.0)
					else: template_result[tag] += amt
				
				if not local_pool.has(tag): local_pool[tag] = 0.0
				local_pool[tag] += amt

	# Pass 2: Requirements & Consumption
	for func_name in selected_functionalities:
		var func_data = EconomyManager.building_functions[func_name]
		var slotted = func_inputs[func_name]
		tag_matcher.set_context(slotted)
		
		if func_data.has("requirements"):
			print("requirements: ", str(func_data["requirements"]))
			print("evaluates to: ", tag_matcher.evaluate(str(func_data["requirements"])))
			if not tag_matcher.evaluate(str(func_data["requirements"])):
				all_feasible = false
				
		if func_data.has("input"):
			for match_index in range(func_data["input"].size()):
				var inp = func_data["input"][match_index]
				
				# Wait, for sliders/spinboxes, the `amount` property is the user's explicit allocation.
				# `TagMatcher` handles passing that through `input_amount(0)`.
				# In Pass 2, we just verify the resource natively has enough math limits, AND for passive tags, deduct from local_pool.
				
				var user_allocated_amt = 0.0
				var resource = null
				
				print("match index: ", match_index)
				print("slotted size: ", slotted.size())
				if match_index < slotted.size():
					user_allocated_amt = slotted[match_index]["amount"]
					resource = slotted[match_index]["resource"]
				else:
					all_feasible = false
					continue
				
				if inp.has("match"):
					print("resource: ", resource)
					if resource != null:
						tag_matcher.set_eval_resource(resource)
						print("match: ", str(inp["match"]))
						print("evaluates to: ", tag_matcher.evaluate(str(inp["match"])))
						if not tag_matcher.evaluate(str(inp["match"])):
							all_feasible = false
					else:
						all_feasible = false
				
				elif inp.has("resource_tag"):
					var c_tag = str(inp["resource_tag"])
					if not local_pool.has(c_tag): local_pool[c_tag] = 0.0
					
					# Subtract globally mapped capability logic rather than locally
					local_pool[c_tag] -= user_allocated_amt
					
					# Final drain output mapped back to the Template result dictionary for when built
					if template_result.has(c_tag) and typeof(template_result[c_tag]) != TYPE_BOOL:
						template_result[c_tag] -= user_allocated_amt

	print("selected_functionalities: ", selected_functionalities)
	print("feasable: ", all_feasible)
	print()
	if selected_functionalities.size() == 0 || building_name.text.is_empty():
		all_feasible = false
		
	var summary_text = "Feasible: %s\nCost: %s\n" % [str(all_feasible), str(template_result["money_cost"])]
	if template_result["power"] != 0: summary_text += "Power: %s\n" % str(template_result["power"])
	if template_result["tech_points"] != 0: summary_text += "Tech: %s\n" % str(template_result["tech_points"])
	if template_result["population"] != 0: summary_text += "Population: %s\n" % str(template_result["population"])
	if template_result["produces"] != 0: summary_text += "Produces: %s\n" % str(template_result["produces"])
	
	feasibility_text.text = summary_text
	add_building.disabled = not all_feasible
	current_building_template = template_result

func _eval_or_float(val, tag_matcher: TagMatcher) -> float:
	if typeof(val) == TYPE_STRING:
		var result = tag_matcher.evaluate(val)
		if typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
			return float(result)
		return 0.0
	elif typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val)
	return 0.0

func _on_add_building_pressed() -> void:
	if not EconomyManager.building_designs.has(CountryManager.player_country.country_name):
		EconomyManager.building_designs[CountryManager.player_country.country_name] = []

	var bt = BuildingTemplate.FromDict(current_building_template)
	if editing_design_index >= 0 and editing_design_index < EconomyManager.building_designs[CountryManager.player_country.country_name].size():
		EconomyManager.building_designs[CountryManager.player_country.country_name][editing_design_index] = bt
	else:
		EconomyManager.building_designs[CountryManager.player_country.country_name].append(bt)
		editing_design_index = EconomyManager.building_designs[CountryManager.player_country.country_name].size() - 1

	_refresh_existing_designs()
	GameState.game_ui._refresh_industry_building_options()


func _on_building_name_changed() -> void:
	if building_name.text not in EconomyManager.building_designs.get(CountryManager.player_country.country_name, []):
		editing_design_index = -1
	_recalculate()

func _refresh_existing_designs() -> void:
	for child in existing_design.get_children():
		child.free()

	if not CountryManager.player_country:
		return

	var designs: Array = EconomyManager.building_designs.get(CountryManager.player_country.country_name, [])
	for i in range(designs.size()):
		var design = designs[i]
		if not (design is BuildingTemplate):
			continue
		var btn = Button.new()
		var marker = " [editing]" if i == editing_design_index else ""
		btn.text = "%s%s" % [design.name, marker]
		btn.pressed.connect(func(): _load_design_for_edit(i))
		existing_design.add_child(btn)

func _load_design_for_edit(index: int) -> void:
	if index == editing_design_index: return
	if not CountryManager.player_country:
		return
	var designs: Array = EconomyManager.building_designs.get(CountryManager.player_country.country_name, [])
	if index < 0 or index >= designs.size():
		return
	var design = designs[index]
	if not (design is BuildingTemplate):
		return

	editing_design_index = index
	var data = (design as BuildingTemplate).ToDict()
	building_name.text = str(data.get("name", ""))

	# Clear all selected functionalities/UI first.
	selected_functionalities.clear()
	for func_name in func_ui_containers.keys():
		_destroy_func_ui(func_name)
	func_ui_containers.clear()
	active_tag_matcher.slotted_resources.clear()

	# Re-check relevant functionality toggles and rebuild their UI sections.
	for child in inputs_list_or_grid().get_children():
		if child is CheckButton:
			var checked = data.get("functionalities", []).has(child.text)
			child.button_pressed = checked
			if checked:
				selected_functionalities.append(child.text)
				var func_data = EconomyManager.building_functions.get(child.text, {})
				_spawn_func_ui(child.text, func_data)

	# Recalculate to populate dropdown options/sliders with valid bounds.
	_recalculate()

	# Apply saved slot assignments after options are populated.
	var assigned: Dictionary = data.get("assigned_inputs", {})
	for func_name in assigned.keys():
		if not func_ui_containers.has(func_name):
			continue
		var slots: Array = assigned[func_name]
		var vbox = func_ui_containers[func_name]
		var slot_idx = 0
		for ui_element in vbox.get_children():
			if slot_idx >= slots.size():
				break
			var slot_data: Dictionary = slots[slot_idx]
			if ui_element is PanelContainer:
				var card_vc = ui_element.get_child(0)
				var hbox_opt = card_vc.get_child(0)
				var opt = hbox_opt.get_child(1) as OptionButton
				var selected_res = str(slot_data.get("resource", ""))
				if not selected_res.is_empty():
					for item_idx in range(opt.item_count):
						if opt.get_item_text(item_idx) == selected_res:
							opt.select(item_idx)
							opt.set_meta("last_selected", selected_res)
							break
				var amt_node = card_vc.get_meta("amount_node")
				if amt_node:
					amt_node.value = float(slot_data.get("amount", amt_node.value))
			elif ui_element is HBoxContainer:
				var amt_cnt = ui_element.get_child(1)
				var amt_node = amt_cnt.get_meta("amount_node")
				if amt_node:
					amt_node.value = float(slot_data.get("amount", amt_node.value))
			slot_idx += 1

	_recalculate()
	_refresh_existing_designs()
