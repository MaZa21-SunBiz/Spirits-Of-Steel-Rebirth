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

func _ready() -> void:
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
			if inp.has("match"):
				_build_match_ui(vbox, inp, "Input", match_index)
				match_index += 1
			elif inp.has("resource_tag"):
				_build_tag_ui(vbox, inp, "Input", match_index)
				match_index += 1

	if func_data.has("output"):
		var match_index = 0
		for out in func_data["output"]:
			if out.has("match"):
				# For output, we just build a match card but amount is non-editable
				_build_match_ui(vbox, out, "Output", match_index)
				match_index += 1

	func_ui_containers[func_name] = vbox
	
	for i in range(inputs_list_or_grid().get_child_count()):
		var c = inputs_list_or_grid().get_child(i)
		if c is CheckButton and c.text == func_name:
			inputs_list_or_grid().add_child(vbox)
			inputs_list_or_grid().move_child(vbox, i + 1)
			break

func _build_match_ui(vbox: Container, block: Dictionary, prefix: String, index: int):
	var card = PanelContainer.new()
	var card_vbox = VBoxContainer.new()
	card.set_meta("io_type", prefix)
	
	var hbox_opt = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "%s %d" % [prefix, index]
	var opt = OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("...")
	opt.set_meta("match_expr", block["match"])
	opt.set_meta("last_selected", "")
	opt.item_selected.connect(func(_idx): _recalculate())
	
	hbox_opt.add_child(lbl)
	hbox_opt.add_child(opt)
	card_vbox.add_child(hbox_opt)
	
	var amount_data = block.get("amount", "0")
	# If it's an output, it's evaluated, so we force it to basically be a spinbox
	if prefix == "Output":
		_build_amount_ui(card_vbox, amount_data, false)
	else:
		_build_amount_ui(card_vbox, amount_data, true)
	
	card.add_child(card_vbox)
	vbox.add_child(card)

func _build_tag_ui(vbox: Container, block: Dictionary, prefix: String, _index: int):
	var r_tag = str(block["resource_tag"])
	var hbox = HBoxContainer.new()
	hbox.set_meta("io_type", prefix)
	var lbl = Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = "Pool Req: " + r_tag
	hbox.add_child(lbl)
	
	var amount_data = block.get("amount", "0")
	var amount_cnt = VBoxContainer.new()
	amount_cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount_cnt.set_meta("resource_tag", r_tag)
	
	_build_amount_ui(amount_cnt, amount_data, prefix == "Input")
	hbox.add_child(amount_cnt)
	vbox.add_child(hbox)

func _build_amount_ui(parent: Container, amount_data, editable: bool):
	if typeof(amount_data) == TYPE_DICTIONARY and editable:
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
		
		var amt_hbox = HBoxContainer.new()
		amt_hbox.add_child(hsl)
		amt_hbox.add_child(lbl)
		
		parent.add_child(amt_hbox)
		parent.set_meta("amount_node", hsl)
	else:
		var sp = SpinBox.new()
		sp.editable = false
		sp.step = 0.1
		sp.min_value = -999999.0
		sp.max_value = 999999.0
		sp.set_meta("fixed_expr", str(amount_data))
		
		var amt_hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "Amt:"
		amt_hbox.add_child(lbl)
		amt_hbox.add_child(sp)
		
		parent.add_child(amt_hbox)
		parent.set_meta("amount_node", sp)

func _destroy_func_ui(func_name: String):
	if func_ui_containers.has(func_name):
		func_ui_containers[func_name].queue_free()
		func_ui_containers.erase(func_name)

# Gathers chosen values and resources mapping for evaluating dynamic data
func _gather_func_io() -> Dictionary:
	var mapping = {}
	for func_name in selected_functionalities:
		var io_arrays = {"inputs": [], "outputs": []}
		if func_ui_containers.has(func_name):
			var vbox = func_ui_containers[func_name]
			for ui_element in vbox.get_children():
				var slot_data = {"resource": null, "amount": 0.0, "resource_tag": ""}
				var target_arr = null
				
				if ui_element is PanelContainer:
					var prefix = ui_element.get_meta("io_type")
					target_arr = io_arrays["inputs"] if prefix == "Input" else io_arrays["outputs"]
					var card_vc = ui_element.get_child(0)
					var hbox_opt = card_vc.get_child(0)
					var opt = hbox_opt.get_child(1) as OptionButton
					if opt.item_count > 0 and opt.selected >= 0:
						var res_name = opt.get_item_text(opt.selected)
						if res_name != "..." and MapManager.resources.has(res_name):
							slot_data["resource"] = MapManager.resources[res_name]
					
					var amt_node = card_vc.get_meta("amount_node")
					slot_data["amount"] = amt_node.value if amt_node else 0.0
					
				elif ui_element is HBoxContainer:
					var prefix = ui_element.get_meta("io_type")
					target_arr = io_arrays["inputs"] if prefix == "Input" else io_arrays["outputs"]
					var amt_cnt = ui_element.get_child(1)
					slot_data["resource_tag"] = amt_cnt.get_meta("resource_tag")
					
					var amt_node = amt_cnt.get_meta("amount_node")
					slot_data["amount"] = amt_node.value if amt_node else 0.0
					
				if target_arr != null:
					target_arr.append(slot_data)
		mapping[func_name] = io_arrays
	return mapping

func _recalculate():
	var func_io = _gather_func_io()
	var local_pool = {}
	var resource_net = {}
	
	var template_result = {
		"name": building_name.text,
		"functionalities": selected_functionalities.duplicate(),
		"assigned_inputs": {},
		"assigned_outputs": {},
		"money_cost": 0.0
	}
	
	for fn in func_io.keys():
		template_result["assigned_inputs"][fn] = []
		template_result["assigned_outputs"][fn] = []
		for slot in func_io[fn]["inputs"]:
			var d_str = {"amount": slot["amount"]}
			if slot["resource"] != null: d_str["resource"] = slot["resource"].name
			if slot["resource_tag"] != "": d_str["resource_tag"] = slot["resource_tag"]
			template_result["assigned_inputs"][fn].append(d_str)
		for slot in func_io[fn]["outputs"]:
			var d_str = {"amount": slot["amount"]}
			if slot["resource"] != null: d_str["resource"] = slot["resource"].name
			template_result["assigned_outputs"][fn].append(d_str)
	
	var all_feasible = true
	var tag_matcher = TagMatcher.new(local_pool)
	
	# Pass 1: Setup Input Sliders, Dropdowns
	for func_name in selected_functionalities:
		#var func_data = EconomyManager.building_functions[func_name]
		var slotted_inputs = func_io[func_name]["inputs"]
		var slotted_outputs = func_io[func_name]["outputs"]
		
		tag_matcher.set_context(slotted_inputs)
		
		# Process UI dropdown dynamic loading
		var vbox = func_ui_containers.get(func_name)
		if vbox:
			var match_idx_in = 0
			var match_idx_out = 0
			for ui_element in vbox.get_children():
				if ui_element is PanelContainer:
					var prefix = ui_element.get_meta("io_type")
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
							
					var did_reselect = false
					for i in range(opt.item_count):
						if opt.get_item_text(i) == last_sel:
							opt.select(i)
							did_reselect = true
							if last_sel != "...":
								if prefix == "Input": slotted_inputs[match_idx_in]["resource"] = MapManager.resources.get(last_sel)
								else: slotted_outputs[match_idx_out]["resource"] = MapManager.resources.get(last_sel)
							break
					if not did_reselect and opt.item_count > 1:
						opt.select(1)
						if prefix == "Input": slotted_inputs[match_idx_in]["resource"] = MapManager.resources.get(opt.get_item_text(1))
						else: slotted_outputs[match_idx_out]["resource"] = MapManager.resources.get(opt.get_item_text(1))
					opt.set_meta("last_selected", opt.get_item_text(opt.selected))
					
					# Build limit setting for INPUT
					if prefix == "Input":
						var amt_node = card_vc.get_meta("amount_node")
						if amt_node is HSlider:
							amt_node.min_value = _eval_or_float(amt_node.get_meta("min_expr"), tag_matcher)
							amt_node.max_value = _eval_or_float(amt_node.get_meta("max_expr"), tag_matcher)
						elif amt_node is SpinBox:
							amt_node.value = _eval_or_float(amt_node.get_meta("fixed_expr"), tag_matcher)
						slotted_inputs[match_idx_in]["amount"] = amt_node.value
						
						# Output nodes evaluated in pass 2, but we update index
						match_idx_in += 1
					else:
						match_idx_out += 1
				
				elif ui_element is HBoxContainer:
					#var prefix = ui_element.get_meta("io_type")
					var amt_cnt = ui_element.get_child(1)
					var amt_node = amt_cnt.get_meta("amount_node")
					if amt_node is HSlider:
						amt_node.min_value = _eval_or_float(amt_node.get_meta("min_expr"), tag_matcher)
						amt_node.max_value = _eval_or_float(amt_node.get_meta("max_expr"), tag_matcher)
					elif amt_node is SpinBox:
						amt_node.value = _eval_or_float(amt_node.get_meta("fixed_expr"), tag_matcher)
					slotted_inputs[match_idx_in]["amount"] = amt_node.value
					match_idx_in += 1

	# Pass 2: Calculate outputs (Passive and Resource Net)
	for func_name in selected_functionalities:
		var func_data = EconomyManager.building_functions[func_name]
		var slotted_inputs = func_io[func_name]["inputs"]
		var slotted_outputs = func_io[func_name]["outputs"]
		tag_matcher.set_context(slotted_inputs)
		
		# Evaluate Output amounts onto UI
		if func_data.has("output"):
			var vbox = func_ui_containers.get(func_name)
			var match_idx_out = 0
			var c_index = 0
			for out_cfg in func_data["output"]:
				var amt = _eval_or_float(out_cfg.get("amount", "0"), tag_matcher)
				
				# Update UI Element
				if vbox:
					for ui_element in vbox.get_children():
						if ui_element is PanelContainer and ui_element.get_meta("io_type") == "Output":
							if c_index == match_idx_out:
								var card_vc = ui_element.get_child(0)
								var amt_node = card_vc.get_meta("amount_node")
								if amt_node is SpinBox:
									amt_node.value = amt
								slotted_outputs[match_idx_out]["amount"] = amt
								break
							c_index += 1
				
				# Track Yield Natively
				if out_cfg.has("match"):
					var res = slotted_outputs[match_idx_out]["resource"] if match_idx_out < slotted_outputs.size() else null
					if res:
						if not resource_net.has(res.name): resource_net[res.name] = 0.0
						resource_net[res.name] += amt
					match_idx_out += 1
				elif out_cfg.has("tag"):
					var tag = out_cfg["tag"]
					if not template_result.has(tag): template_result[tag] = 0.0
					if typeof(template_result[tag]) == TYPE_BOOL: template_result[tag] = (amt > 0.0)
					else: template_result[tag] += amt
					if not local_pool.has(tag): local_pool[tag] = 0.0
					local_pool[tag] += amt
					
		# Cost processing
		if func_data.has("build_cost"):
			var bc = func_data["build_cost"]
			if bc.has("money"): template_result["money_cost"] += _eval_or_float(bc["money"], tag_matcher)

	# Pass 3: Process inputs footprint globally
	for func_name in selected_functionalities:
		var func_data = EconomyManager.building_functions[func_name]
		var slotted = func_io[func_name]["inputs"]
		tag_matcher.set_context(slotted)

		if func_data.has("input"):
			for match_index in range(func_data["input"].size()):
				var inp = func_data["input"][match_index]
				
				var user_allocated_amt = 0.0
				var res = null
				
				if match_index < slotted.size():
					user_allocated_amt = slotted[match_index]["amount"]
					res = slotted[match_index]["resource"]
				else:
					all_feasible = false
					continue
				
				if inp.has("match"):
					if res != null:
						tag_matcher.set_eval_resource(res)
						if not tag_matcher.evaluate(str(inp["match"])):
							all_feasible = false
						else:
							if not resource_net.has(res.name): resource_net[res.name] = 0.0
							resource_net[res.name] -= user_allocated_amt
					else:
						all_feasible = false 
				
				elif inp.has("resource_tag"):
					var c_tag = str(inp["resource_tag"])
					if not local_pool.has(c_tag): local_pool[c_tag] = 0.0
					local_pool[c_tag] -= user_allocated_amt
					
					if not template_result.has(c_tag): template_result[c_tag] = 0.0
					if typeof(template_result[c_tag]) != TYPE_BOOL:
						template_result[c_tag] -= user_allocated_amt

	if selected_functionalities.size() == 0 || building_name.text.is_empty():
		all_feasible = false
		
	var summary_text = "Feasible: %s\nCost: %s\n" % [str(all_feasible), str(template_result["money_cost"])]
	
	# Dynamically populate passive states that have changed
	for key in template_result.keys():
		if key in ["name", "functionalities", "assigned_inputs", "assigned_outputs", "money_cost"]: continue
		var val = template_result[key]
		if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
			if float(val) != 0.0: summary_text += "%s: %.1f\n" % [key.capitalize(), val]
		elif typeof(val) == TYPE_BOOL:
			if val: summary_text += "%s: True\n" % key.capitalize()
			
	if resource_net.size() > 0:
		summary_text += "\nResources Net:\n"
		for r_name in resource_net.keys():
			summary_text += "- %s: %s%.1f\n" % [r_name, "+" if resource_net[r_name] >= 0 else "", resource_net[r_name]]
	
	template_result["resource_net"] = resource_net
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
		EconomyManager.building_designs[CountryManager.player_country.country_name] = {}

	var bt = BuildingTemplate.FromDict(current_building_template)
	EconomyManager.building_designs[CountryManager.player_country.country_name][bt.name] = bt

	for child in existing_design.get_children():
		child.free()

	for design: BuildingTemplate in EconomyManager.building_designs[CountryManager.player_country.country_name].values():
		var btn = Button.new()
		btn.text = design.name
		existing_design.add_child(btn)
		btn.pressed.connect(func(): pass)

func _on_building_name_changed() -> void:
	_recalculate()
