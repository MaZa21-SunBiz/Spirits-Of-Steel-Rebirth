extends PopupPanel

enum CreationMode {
	CREATE_FACTION  = 0,
	CREATE_POLITY   = 1,
	CREATE_MEMBER   = 2,
	CREATE_BIOME    = 3,
	CREATE_RESOURCE = 4,
}

@export var mapEditor: CanvasLayer
@export var tabs: TabContainer

@export var factionName: LineEdit
@export var factionColor: ColorPickerButton
@export var factionFounder: OptionButton


@export var polityName: LineEdit
@export var polityOwner: OptionButton
@export var polityColor: ColorPickerButton
@export var polityMoney: SpinBox
@export var polityPoliticalPower: SpinBox
@export var polityWarSupport: SpinBox
@export var polityStability: SpinBox
@export var polityType: TabContainer
@export var polityHost: OptionButton
@export var polityClaims: TextEdit

@export var memberPolity: OptionButton
@export var memberStatus: OptionButton

@export var biomeName: LineEdit
@export var biomeColor: ColorPickerButton

@export var resourceName: LineEdit
@export var resourceColor: ColorPickerButton
@export var resourceIcon: LineEdit

func m_OpenScreen(a_mode: CreationMode) -> void:
	match a_mode:
		CreationMode.CREATE_FACTION:
			tabs.current_tab = a_mode as int
			factionFounder.clear()
			for country in CountryManager.countries.keys():
				factionFounder.add_item(country)
		CreationMode.CREATE_POLITY:
			tabs.current_tab = a_mode as int
			polityOwner.clear()
			polityOwner.add_item("None")
			polityHost.clear()
			for country in CountryManager.countries.keys():
				polityOwner.add_item(country)
				polityHost.add_item(country)
		CreationMode.CREATE_MEMBER:
			tabs.current_tab = a_mode as int
			memberPolity.clear()
			var faction: FactionData = FactionManager.factions[mapEditor.selectedFaction]
			for country in CountryManager.countries.keys():
				if !faction.members.any(func (a_member: FactionMember): return a_member.polity == country):
					memberPolity.add_item(country)
		CreationMode.CREATE_BIOME:
			tabs.current_tab = a_mode as int
		CreationMode.CREATE_RESOURCE:
			tabs.current_tab = a_mode as int
	visible = true

func m_CreateFaction() -> void:
	if factionName.text in FactionManager.factions:
		return
	FactionManager.create_faction(factionFounder.get_item_text(factionFounder.selected), factionName.text, factionColor.color)
	mapEditor.SetupFactionList()
	visible = false

func m_CreatePolity() -> void:
	if polityName.text in CountryManager.countries:
		return
		
	var countryData: Dictionary = {
		"name": polityName.text,
		"color": polityColor.color.to_html(),
		"money": polityMoney.value,
		#"ideology": [],
		"political_power": polityPoliticalPower.value,
		"stability": polityStability.value,
		"war_support": polityWarSupport.value,
	}
	match polityType.current_tab:
		0:
			CountryManager.add_country(countryData)
			CountryManager.MakeHost(CountryManager.countries[polityHost.text], CountryManager.countries[polityName.text])
		1:
			if mapEditor.currentTool != 4 || mapEditor.multiSelectPID.size() <= 0:
				return
			MapManager.InstantiateCountryFromProvinces(countryData, mapEditor.multiSelectPID)
		2:
			var tempClaims: PackedInt32Array = []
			for entry: String in polityClaims.text.split(",", false):
				tempClaims.push_back(entry.to_int())
			MapManager.InstantiateCountryFromProvinces(countryData, tempClaims)
	if polityOwner.text != "None":
		CountryManager.make_puppet(CountryManager.countries[polityOwner.text], CountryManager.countries[polityName.text])
	mapEditor.SetupPolitiesList()
	visible = false


func m_CreateMember() -> void:
	FactionManager.factions[mapEditor.selectedFaction].members.append(FactionMember.FromValues(memberPolity.text, memberStatus.text))
	mapEditor.AddedFactionMember()
	visible = false


func m_CreateBiome() -> void:
	if biomeName.text in MapManager.biomes:
		return
	MapManager.biomes[biomeName.text] = BiomeData.FromValues(biomeName.text, biomeColor.color)
	mapEditor.SetupBiomesList()
	visible = false

func m_CreateResource() -> void:
	if resourceName.text in MapManager.resources:
		return
	MapManager.resources[resourceName.text] = ResourceData.FromValues(resourceName.text, resourceColor.color, resourceIcon.text)
	mapEditor.SetupResourcesList()
	visible = false
