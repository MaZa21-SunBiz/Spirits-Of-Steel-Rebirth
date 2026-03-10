extends CanvasLayer

@export var map_sprite: Sprite2D

var selectedCountry: String = ""
var selected_pid: int = -1
var hovered_pid: int = -1
var original_pid_color: Color

enum Tool {
	NONE             = 0,
	PAINT_OCCUPATION = 1,
	PAINT_OWNER      = 2,
	PAINT_FACTION    = 3,
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
@export var input_country: LineEdit
@export var inputOccupier: LineEdit
@export var input_city: LineEdit
@export var input_gdp: SpinBox
@export var input_claims: TextEdit

@export var factionsItemList: ItemList
@export var factionName: LineEdit
@export var factionColor: ColorPickerButton

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
	if MapManager._is_mouse_over_ui() or Console.is_visible():
		_clear_hover()
		return

	if event is InputEventMouseMotion:
		_handle_hover(event.position)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
		original_pid_color = MapManager.state_color_image.get_pixel(pid, 0)
		MapManager.state_color_image.set_pixel(pid, 0, original_pid_color.lightened(0.4))
		MapManager.state_color_texture.update(MapManager.state_color_image)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _clear_hover() -> void:
	if hovered_pid > 1:
		MapManager.state_color_image.set_pixel(hovered_pid, 0, original_pid_color)
		MapManager.state_color_texture.update(MapManager.state_color_image)
		hovered_pid = -1
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_click(screen_pos: Vector2) -> void:
	if hovered_pid > 1:
		match currentMode:
			Mode.PROVINCE:
				select_province(hovered_pid)
			Mode.FACTION:
				match currentTool:
					Tool.NONE:
						select_province(hovered_pid)
					Tool.PAINT_FACTION:
						if MapManager.province_objects[hovered_pid].country != "Sea" and selectedCountry in CountryManager.countries:
							pass
			Mode.POLITY:
				match currentTool:
					Tool.NONE:
						select_province(hovered_pid)
					Tool.PAINT_OWNER:
						if MapManager.province_objects[hovered_pid].country != "Sea" and selectedCountry in CountryManager.countries:
							MapManager.transfer_ownership(hovered_pid, selectedCountry)
					Tool.PAINT_OCCUPATION:
						if MapManager.province_objects[hovered_pid].country != "Sea" and selectedCountry in CountryManager.countries:
							if MapManager.province_objects[hovered_pid].country != selectedCountry:
								MapManager.OccupyProvince(hovered_pid, selectedCountry)
							else:
								MapManager.DeoccupyProvince(hovered_pid)

func select_province(pid: int) -> void:
	selected_pid = pid
	var prov = MapManager.province_objects.get(pid)
	if not prov:
		return

	#var color_str = _color_to_rgb_string(prov.r_color) if prov.r_color else "Unknown"
	#status_label.text = "Selected PID: %d\nR_Color: %s" % [pid, color_str]

	# Set Fields
	input_country.text = prov.country
	inputOccupier.text = prov.occupier
	input_city.text = prov.city
	input_gdp.value = prov.gdp
	input_claims.text = ", ".join(prov.claims)

func _on_apply_pressed() -> void:
	if selected_pid <= 1:
		return
	var prov = MapManager.province_objects.get(selected_pid)
	if not prov:
		return

	var old_country = prov.country
	var new_country = input_country.text.strip_edges()

	# 1. Update MapManager global data

	# 2. Update Province Object
	prov.country = new_country
	prov.occupier = inputOccupier.text.strip_edges()
	prov.city = input_city.text.strip_edges()
	prov.gdp = float(input_gdp.value)

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
	var prov_export = {}
	for pid in MapManager.province_objects.keys():
		if pid <= 1:
			continue
		var p = MapManager.province_objects[pid]
		prov_export["%d" % p.id] = p.ToDict()

	# Export Country Colors
	var country_export = {}
	for c_name in MapManager.country_colors.keys():
		var col = MapManager.country_colors[c_name]
		country_export[c_name] = {"color": [int(col.r8), int(col.g8), int(col.b8)]}

	_save_json("user://exported_map_data.json", prov_export)
	_save_json("user://exported_countries.json", country_export)
	OS.shell_open(ProjectSettings.globalize_path("user://"))

func _save_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func m_OnTabContainerTabChanged(tab: int) -> void:
	currentTool = Tool.NONE
	currentMode = tab
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
	var faction: FactionData = FactionManager.factions[factionsItemList.get_item_text(index)]
	factionName.text = faction.name
	factionColor.color = faction.color
	
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
		var puppetEntry: PanelContainer = polityPuppetTemplate.clone()
		puppetEntry.visible = true
		puppetEntry.get_node("HBoxContainer/Label").text = puppet
		polityPuppetList.add_child(puppetEntry)
	for child in polityFactionList.get_children():
		child.queue_free()
	for faction in polity.factions:
		var factionEntry: PanelContainer = polityFactionTemplate.clone()
		factionEntry.visible = true
		factionEntry.get_node("HBoxContainer/LineEdit").text = faction
		factionEntry.get_node("HBoxContainer/OptionButton").select(FactionMember.GetIndex(FactionManager.factions[faction].members[FactionManager.factions[faction].members.find_custom(func (a): return a.member == polity.country_name)].status))
		polityFactionList.add_child(factionEntry)
	pass # Replace with function body.

func m_OnCitySubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects:
		MapManager.province_objects[selected_pid].city = new_text

func m_OnProvinceGDPChanged(value: float) -> void:
	if selected_pid in MapManager.province_objects:
		MapManager.province_objects[selected_pid].gdp = value

func m_OnColorChanged(color: Color) -> void:
	MapManager.set_country_color(selectedCountry, color)

func m_OnProvinceOccupierSubmitted(new_text: String) -> void:
	if selected_pid in MapManager.province_objects:
		if new_text.is_empty():
			MapManager.DeoccupyProvince(selected_pid)
		else:
			MapManager.OccupyProvince(selected_pid, new_text)

func m_NoneTool() -> void:
	currentTool = Tool.NONE

func m_PaintOwnerTool() -> void:
	currentTool = Tool.PAINT_OWNER
	
func m_PaintOccupationTool() -> void:
	currentTool = Tool.PAINT_OCCUPATION
	
func m_PaintFactionTool() -> void:
	currentTool = Tool.PAINT_FACTION
