extends CanvasLayer

@export var map_sprite: Sprite2D

var selectedCountry: String = ""
var selectedFaction: String = ""
var selected_pid: int = -1
var hovered_pid: int = -1
var original_pid_color: Color

var multiSelectPID: PackedInt32Array = []

enum Tool {
	NONE             = 0,
	PAINT_OCCUPATION = 1,
	PAINT_OWNER      = 2,
	PAINT_FACTION    = 3,
	MULTI_SELECT     = 4,
}

enum Mode {
	PROVINCE = 0,
	FACTION  = 1,
	POLITY   = 2,
}

var currentTool: Tool = Tool.NONE
var currentMode: Mode = Mode.PROVINCE

@export var leftSidebar: TabContainer

# UI References (Ensure these match your .tscn node names)
@export var status_label: Label
@export var provinceName: LineEdit
@export var input_country: LineEdit
@export var inputOccupier: LineEdit
@export var input_city: LineEdit
@export var input_gdp: SpinBox
@export var input_claims: TextEdit
@export var provincePopulationList: VBoxContainer
@export var provincePopulationTemplate: PanelContainer
@export var provinceResourcesList: VBoxContainer
@export var provinceResourcesTemplate: PanelContainer

@export var factionsItemList: ItemList
@export var factionName: LineEdit
@export var factionColor: ColorPickerButton
@export var factionMemberList: VBoxContainer
@export var factionMemberTemplate: PanelContainer

@export var politiesItemList: ItemList
@export var polityPuppet: CheckBox
@export var polityOwner: LineEdit
@export var polityInExile: CheckBox
@export var polityHost: LineEdit
@export var polityName: LineEdit
@export var polityColor: ColorPickerButton
@export var polityMoney: SpinBox
@export var polityPoliticalPower: SpinBox
@export var polityWarSupport: SpinBox
@export var polityStability: SpinBox
@export var polityPuppetList: VBoxContainer
@export var polityPuppetTemplate: PanelContainer
@export var polityFactionList: VBoxContainer
@export var polityFactionTemplate: PanelContainer

func _ready() -> void:
	SetupFactionList()
	SetupPolitiesList()
	
	if map_sprite == null:
		map_sprite = get_node_or_null("../../MapContainer/CultureSprite")

func _unhandled_input(event: InputEvent) -> void:
	if MapManager._is_mouse_over_ui() || Console.is_visible():
		_clear_hover()
		return

	if event is InputEventMouseMotion:
		_handle_hover(event.position)

	if event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_LEFT && event.pressed:
		_handle_click(event.position)

func _handle_hover(screen_pos: Vector2) -> void:
	if map_sprite == null:
		return
	var world_pos = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var pid = MapManager.get_province_with_radius(world_pos, map_sprite, 5)

	if pid == hovered_pid:
		return
	_clear_hover()

	if pid > 1:
		hovered_pid = pid
		if hovered_pid not in multiSelectPID:
			original_pid_color = MapManager.state_color_image.get_pixel(pid, 0)
			MapManager.state_color_image.set_pixel(pid, 0, original_pid_color.lightened(0.4))
			MapManager.state_color_texture.update(MapManager.state_color_image)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _clear_hover() -> void:
	if hovered_pid > 1:
		if hovered_pid not in multiSelectPID:
			MapManager.state_color_image.set_pixel(hovered_pid, 0, original_pid_color)
			MapManager.state_color_texture.update(MapManager.state_color_image)
		hovered_pid = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_click(_screenPos: Vector2) -> void:
	get_viewport().gui_release_focus()
	
	if hovered_pid > 1:
		match currentMode:
			Mode.PROVINCE:
				select_province(hovered_pid)
			Mode.FACTION:
				match currentTool:
					Tool.NONE:
						select_province(hovered_pid)
					Tool.PAINT_FACTION:
						if MapManager.province_objects[hovered_pid].country != "Sea" && selectedFaction in FactionManager.factions:
							pass
			Mode.POLITY:
				match currentTool:
					Tool.NONE:
						select_province(hovered_pid)
					Tool.PAINT_OWNER:
						if MapManager.province_objects[hovered_pid].country != "Sea" && selectedCountry in CountryManager.countries:
							MapManager.transfer_ownership(hovered_pid, selectedCountry)
					Tool.PAINT_OCCUPATION:
						if MapManager.province_objects[hovered_pid].country != "Sea" && selectedCountry in CountryManager.countries:
							if MapManager.province_objects[hovered_pid].country != selectedCountry:
								MapManager.OccupyProvince(hovered_pid, selectedCountry)
							else:
								MapManager.DeoccupyProvince(hovered_pid)
					Tool.MULTI_SELECT:
						if MapManager.province_objects[hovered_pid].country != "Sea":
							if hovered_pid in multiSelectPID:
								multiSelectPID.erase(hovered_pid)
								MapManager.ResetProvinceColor(hovered_pid)
							else:
								multiSelectPID.push_back(hovered_pid)
								MapManager.SetProvinceColor(hovered_pid, Color.CORNSILK)

func IndexOfText(a_itemList: ItemList, a_text: String) -> int:
	for i in range(a_itemList.item_count):
		if a_itemList.get_item_text(i) == a_text:
			return i
	return -1

func select_province(pid: int) -> void:
	selected_pid = pid
	var prov = MapManager.province_objects.get(pid)
	if not prov:
		return

	#var color_str = _color_to_rgb_string(prov.r_color) if prov.r_color else "Unknown"
	status_label.text = "Selected PID: %d" % [pid]

	# Set Fields
	provinceName.text = prov.name
	input_country.text = prov.country
	inputOccupier.text = prov.occupier
	input_city.text = prov.city
	input_gdp.value = prov.gdp
	input_claims.text = ", ".join(prov.claims)
	
	for child in provincePopulationList.get_children():
		child.queue_free()
	for population: PopulationData in prov.populations:
		var populationEntry: PanelContainer = provincePopulationTemplate.duplicate()
		populationEntry.visible = true
		populationEntry.get_node("MarginContainer/HBoxContainer/Button").pressed.connect(func (): 
			prov.populations.erase(population)
			populationEntry.queue_free()
		)
		populationEntry.get_node("MarginContainer/HBoxContainer/InputEthName").text = population.ethnicity
		populationEntry.get_node("MarginContainer/HBoxContainer/InputEthName").text_submitted.connect(func (a_ethnicity: String): population.ethnicity = a_ethnicity)
		populationEntry.get_node("MarginContainer/HBoxContainer/InputPop").value = population.amount
		populationEntry.get_node("MarginContainer/HBoxContainer/InputPop").value_changed.connect(func (a_amount: float): population.amount = a_amount)
		provincePopulationList.add_child(populationEntry)
		
	for child in provinceResourcesList.get_children():
		child.queue_free()
	for resource: ResourceNode in prov.resources:
		var resourceEntry: PanelContainer = provinceResourcesTemplate.duplicate()
		resourceEntry.visible = true
		resourceEntry.get_node("MarginContainer/HBoxContainer/Button").pressed.connect(func (): 
			prov.resources.erase(resource)
			resourceEntry.queue_free()
		)
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputResource").text = resource.type
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputResource").text_submitted.connect(func (a_type: String): resource.type = a_type)
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputAmount").value = resource.amount
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputAmount").value_changed.connect(func (a_amount: float): resource.amount = a_amount)
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputQuality").value = resource.amount
		resourceEntry.get_node("MarginContainer/HBoxContainer/InputQuality").value_changed.connect(func (a_quality: float): resource.quality = a_quality)
		provinceResourcesList.add_child(resourceEntry)
	
	if currentMode == Mode.POLITY:
		if prov.country != "Sea":
			var itemIndex: int = IndexOfText(politiesItemList, prov.country)
			politiesItemList.select(itemIndex)
			politiesItemList.item_selected.emit(itemIndex)

func _on_apply_pressed() -> void:
	return
	if selected_pid <= 1:
		return
	var prov = MapManager.province_objects.get(selected_pid)
	if not prov:
		return

	var old_country = prov.country
	var new_country = input_country.text.strip_edges()

	# 1. Update MapManager global data

	# 2. Update Province Object

	var raw_claims = input_claims.text.split(",")
	var final_claims = []
	for c in raw_claims:
		var clean = c.strip_edges()
		if clean != "":
			final_claims.append(clean)
	prov.claims = final_claims

	# 3. Cleanup Dictionaries
	if old_country != new_country:
		if MapManager.country_to_provinces.has(old_country):
			MapManager.country_to_provinces[old_country].erase(selected_pid)
		if not MapManager.country_to_provinces.has(new_country):
			MapManager.country_to_provinces[new_country] = []
		MapManager.country_to_provinces[new_country].append(selected_pid)

	MapManager.state_color_texture.update(MapManager.state_color_image)
	print("MapEditor: Applied changes and updated colors for ", new_country)

func _on_export_pressed() -> void:
	# Export Province Data
	var export = {"provinces": {}, "polities": [], "ideologies": IdeologyManager.ideologies, "factions": []}
	for index in MapManager.unique_regions:
		var next_id = MapManager.unique_regions[index]
		var province = MapManager.province_objects[next_id]
		export["provinces"][index] = province.ToDict()

	for country in CountryManager.countries.values():
		export["polities"].append(country.ToDict())
	
	for faction in FactionManager.factions:
		export["factions"].append(FactionManager.factions[faction].ToDict())

	# print(JSON.stringify(export, " "))
	# print(JSON.stringify(export["polities"], " "))
	print(JSON.stringify(export["factions"], "\t"))

	var file = FileAccess.open("user://exported_map_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export, "\t"))
		file.close()

func m_OnTabContainerTabChanged(tab: int) -> void:
	m_NoneTool()
	currentMode = tab as Mode
	leftSidebar.current_tab = tab

func SetupFactionList() -> void:
	factionsItemList.clear()
	for faction in FactionManager.factions.keys():
		factionsItemList.add_item(faction)

func SetupPolitiesList() -> void:
	politiesItemList.clear()
	for polity in CountryManager.countries.keys():
		politiesItemList.add_item(polity)

func m_OnFactionSelected(index: int) -> void:
	selectedFaction = factionsItemList.get_item_text(index)
	var faction: FactionData = FactionManager.factions[selectedFaction]
	factionName.text = faction.name
	factionColor.color = faction.color
	for child in factionMemberList.get_children():
		child.queue_free()
	for member: FactionMember in faction.members:
		var memberEntry: PanelContainer = factionMemberTemplate.duplicate()
		memberEntry.visible = true
		memberEntry.get_node("HBoxContainer/Button").pressed.connect(func (): 
			FactionManager.factions[selectedFaction].KickMember(member.polity)
			memberEntry.queue_free()
		)
		memberEntry.get_node("HBoxContainer/LineEdit").text = member.polity
		memberEntry.get_node("HBoxContainer/OptionButton").select(FactionMember.GetIndex(member.status))
		memberEntry.get_node("HBoxContainer/OptionButton").item_selected.connect(func (a_index: int): FactionManager.factions[selectedFaction].UpdateMemberStatus(member.polity, a_index))
		factionMemberList.add_child(memberEntry)
	
func m_OnPolitySelected(index: int) -> void:
	selectedCountry = politiesItemList.get_item_text(index)
	var polity: CountryData = CountryManager.countries[selectedCountry]
	polityPuppet.set_pressed_no_signal(polity.is_puppet)
	polityOwner.text = polity.owner
	polityInExile.set_pressed_no_signal(polity.is_exiled)
	polityHost.text = polity.host
	polityName.text = polity.country_name
	polityColor.color = polity.country_color
	polityMoney.set_value_no_signal(polity.money)
	polityPoliticalPower.set_value_no_signal(polity.political_power)
	polityWarSupport.set_value_no_signal(polity.war_support)
	polityStability.set_value_no_signal(polity.stability)
	for child in polityPuppetList.get_children():
		child.queue_free()
	for puppet in polity.puppets:
		var puppetEntry: PanelContainer = polityPuppetTemplate.duplicate()
		puppetEntry.visible = true
		puppetEntry.get_node("HBoxContainer/Label").text = puppet
		polityPuppetList.add_child(puppetEntry)
	for child in polityFactionList.get_children():
		child.queue_free()
	for faction in polity.factions:
		var factionEntry: PanelContainer = polityFactionTemplate.duplicate()
		factionEntry.visible = true
		factionEntry.get_node("HBoxContainer/LineEdit").text = faction
		factionEntry.get_node("HBoxContainer/OptionButton").select(FactionMember.GetIndex(FactionManager.factions[faction].members[FactionManager.factions[faction].members.find_custom(func (a): return a.member == polity.country_name)].status))
		polityFactionList.add_child(factionEntry)

func m_OnCitySubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects:
		MapManager.province_objects[selected_pid].city = new_text

func m_OnProvinceGDPChanged(value: float) -> void:
	if selected_pid in MapManager.province_objects:
		MapManager.province_objects[selected_pid].gdp = value

func m_OnColorChanged(color: Color) -> void:
	if selectedCountry in CountryManager.countries:
		MapManager.set_country_color(selectedCountry, color)

func m_OnFactionColorChanged(color: Color) -> void:
	if selectedFaction in FactionManager.factions:
		FactionManager.factions[selectedFaction].color = color

func m_OnProvinceNameSubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects:
		#if (new_text == MapManager.province_objects[selected_pid].occupier):
		MapManager.province_objects[selected_pid].name = new_text

func m_OnProvinceOwnerSubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects && CountryManager.countries.has(new_text):
		#if (new_text == MapManager.province_objects[selected_pid].occupier):
		MapManager.transfer_ownership(selected_pid, new_text)

func m_OnProvinceOccupierSubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects:
		if new_text.is_empty():
			MapManager.DeoccupyProvince(selected_pid)
		else:
			MapManager.OccupyProvince(selected_pid, new_text)

func m_OnPolityNameSubmitted(new_text: String) -> void:
	if selectedCountry in CountryManager.countries:
		CountryManager.RenameCountry(selectedCountry, new_text)
		selectedCountry = new_text

func m_OnPolityOwnerSubmitted(new_text: String) -> void:
	if selectedCountry in MapManager.countries:
		if (CountryManager.countries[selectedCountry].owner in CountryManager.countries):
			CountryManager.release_puppet(CountryManager.countries[selectedCountry], CountryManager.countries[CountryManager.countries[selectedCountry].owner])
		if (new_text in MapManager.countries):
			CountryManager.MakePuppet(CountryManager.countries[selectedCountry], CountryManager.countries[new_text])

func m_OnPolityMoneyChanged(value: float) -> void:
	if selectedCountry in CountryManager.countries:
		CountryManager.countries[selectedCountry].money = value

func m_OnPolityPoliticalPowerChanged(value: float) -> void:
	if selectedCountry in CountryManager.countries:
		CountryManager.countries[selectedCountry].political_power = value

func m_OnPolityWarSupportChanged(value: float) -> void:
	if selectedCountry in CountryManager.countries:
		CountryManager.countries[selectedCountry].war_support = value

func m_OnPolityStabilityChanged(value: float) -> void:
	if selectedCountry in CountryManager.countries:
		CountryManager.countries[selectedCountry].stability = value

func m_NoneTool() -> void:
	match currentTool:
		Tool.MULTI_SELECT:
			for pid: int in multiSelectPID:
				MapManager.ResetProvinceColor(pid)
			multiSelectPID = []
	currentTool = Tool.NONE

func m_PaintOwnerTool() -> void:
	match currentTool:
		Tool.MULTI_SELECT:
			for pid: int in multiSelectPID:
				MapManager.ResetProvinceColor(pid)
			multiSelectPID = []
	currentTool = Tool.PAINT_OWNER
	
func m_PaintOccupationTool() -> void:
	match currentTool:
		Tool.MULTI_SELECT:
			for pid: int in multiSelectPID:
				MapManager.ResetProvinceColor(pid)
			multiSelectPID = []
	currentTool = Tool.PAINT_OCCUPATION
	
func m_PaintFactionTool() -> void:
	match currentTool:
		Tool.MULTI_SELECT:
			for pid: int in multiSelectPID:
				MapManager.ResetProvinceColor(pid)
			multiSelectPID = []
	currentTool = Tool.PAINT_FACTION

func m_MultiSelectTool() -> void:
	currentTool = Tool.MULTI_SELECT

func AddedFactionMember() -> void:
	var member: FactionMember = FactionManager.factions[selectedFaction].members.back()
	var memberEntry: PanelContainer = factionMemberTemplate.duplicate()
	memberEntry.visible = true
	memberEntry.get_node("HBoxContainer/Button").pressed.connect(func (): 
		FactionManager.factions[selectedFaction].KickMember(member.polity)
		memberEntry.queue_free()
	)
	memberEntry.get_node("HBoxContainer/LineEdit").text = member.polity
	memberEntry.get_node("HBoxContainer/OptionButton").select(FactionMember.GetIndex(member.status))
	memberEntry.get_node("HBoxContainer/OptionButton").item_selected.connect(func (a_index: int): FactionManager.factions[selectedFaction].UpdateMemberStatus(member.polity, a_index))
	factionMemberList.add_child(memberEntry)

func AddProvincePopulation() -> void:
	var prov: Province = MapManager.province_objects[selected_pid]
	prov.populations.push_back(PopulationData.FromDict({
		"ethnicity": "Unknown",
		"amount": 1
	}))
	var population: PopulationData = prov.populations.back()
	var populationEntry: PanelContainer = provincePopulationTemplate.duplicate()
	populationEntry.visible = true
	populationEntry.get_node("MarginContainer/HBoxContainer/Button").pressed.connect(func (): 
		prov.populations.erase(population)
		populationEntry.queue_free()
	)
	populationEntry.get_node("MarginContainer/HBoxContainer/InputEthName").text = population.ethnicity
	populationEntry.get_node("MarginContainer/HBoxContainer/InputEthName").text_submitted.connect(func (a_ethnicity: String): population.ethnicity = a_ethnicity)
	populationEntry.get_node("MarginContainer/HBoxContainer/InputPop").value = population.amount
	populationEntry.get_node("MarginContainer/HBoxContainer/InputPop").value_changed.connect(func (a_amount: float): population.amount = a_amount)
	provincePopulationList.add_child(populationEntry)

func AddProvinceResource() -> void:
	var prov: Province = MapManager.province_objects[selected_pid]
	prov.resources.push_back(ResourceNode.FromDict({
		"type": "Unknown"
	}))
	var resource: ResourceNode = prov.resources.back()
	var resourceEntry: PanelContainer = provinceResourcesTemplate.duplicate()
	resourceEntry.visible = true
	resourceEntry.get_node("MarginContainer/HBoxContainer/Button").pressed.connect(func (): 
		prov.resources.erase(resource)
		resourceEntry.queue_free()
	)
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputResource").text = resource.type
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputResource").text_submitted.connect(func (a_type: String): resource.type = a_type)
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputAmount").value = resource.amount
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputAmount").value_changed.connect(func (a_amount: float): resource.amount = a_amount)
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputQuality").value = resource.amount
	resourceEntry.get_node("MarginContainer/HBoxContainer/InputQuality").value_changed.connect(func (a_quality: float): resource.quality = a_quality)
	provinceResourcesList.add_child(resourceEntry)
