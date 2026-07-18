extends Node

signal player_country_changed
signal message_received(msg: Dictionary)
signal messages_updated

var countries: Dictionary[String, CountryData] = {}
var player_country: CountryData

const HISTORICAL_RESOURCES = {
	"germany": {"base_steel": 14.0, "base_oil": 1.0, "starting_steel": 200.0, "starting_oil": 40.0},
	"usa": {"base_steel": 28.0, "base_oil": 35.0, "starting_steel": 400.0, "starting_oil": 500.0},
	"ussr": {"base_steel": 20.0, "base_oil": 18.0, "starting_steel": 250.0, "starting_oil": 300.0},
	"russia": {"base_steel": 20.0, "base_oil": 18.0, "starting_steel": 250.0, "starting_oil": 300.0},
	"united_kingdom": {"base_steel": 15.0, "base_oil": 4.0, "starting_steel": 150.0, "starting_oil": 90.0},
	"japan": {"base_steel": 6.0, "base_oil": 0.5, "starting_steel": 70.0, "starting_oil": 25.0},
	"france": {"base_steel": 11.0, "base_oil": 1.5, "starting_steel": 100.0, "starting_oil": 50.0},
	"italy": {"base_steel": 7.0, "base_oil": 1.0, "starting_steel": 80.0, "starting_oil": 35.0},
	"brazil": {"base_steel": 16.0, "base_oil": 2.0, "starting_steel": 120.0, "starting_oil": 50.0},
	"romania": {"base_steel": 2.5, "base_oil": 12.0, "starting_steel": 40.0, "starting_oil": 150.0},
	"saudi_arabia": {"base_steel": 1.0, "base_oil": 40.0, "starting_steel": 20.0, "starting_oil": 600.0},
	"venezuela": {"base_steel": 1.0, "base_oil": 30.0, "starting_steel": 15.0, "starting_oil": 400.0}
}

# --- GLOBAL MARKET ---
var market_steel_price: float = 20.0
var market_oil_price: float = 30.0
var market_steel_pool: float = 1000.0
var market_oil_pool: float = 500.0

# --- MESSAGING & TRADE ---
var active_messages: Array = []
var trade_agreement_counter: int = 0

var _hour_process_index: int = 0
@export var clock: GameClock
@export var hours_per_full_country_tick: int = 5


func _on_hour_passed(_ticks) -> void:
	if GameState.is_loading_game:
		return

	var country_keys := countries.keys()
	var total := country_keys.size()
	if total == 0:
		return

	# 1. Staggered hourly country updates
	var countries_per_hour := int(ceil(float(total) / hours_per_full_country_tick))

	var processed := 0
	while processed < countries_per_hour and _hour_process_index < total:
		var c_name: String = country_keys[_hour_process_index]
		var country_obj: CountryData = countries[c_name]

		country_obj.process_hour()

		_hour_process_index += 1
		processed += 1

	if _hour_process_index >= total:
		_hour_process_index = 0

	# 2. Staggered daily country updates (process_day)
	var current_hour := int(_ticks) % 24
	for c_name in countries:
		var country_obj: CountryData = countries[c_name]
		if country_obj.daily_process_hour == current_hour:
			country_obj.process_day()


func _on_day_passed(_date) -> void:
	# 1. Fluctuating global market prices
	var steel_change = randf_range(-1.5, 1.5)
	var oil_change = randf_range(-2.0, 2.0)
	market_steel_price = clamp(market_steel_price + steel_change, 8.0, 60.0)
	market_oil_price = clamp(market_oil_price + oil_change, 12.0, 90.0)
	
	# 2. Process AI communication and trade checks
	_process_ai_diplomacy()


func initialize_countries() -> void:
	if GameState.is_loading_game:
		print("CountryManager: Skipping initialization (loading save)")
		return
	countries.clear()

	var detected_countries = MapManager.country_to_provinces.keys()
	if detected_countries.is_empty():
		detected_countries = MapManager.country_colors.keys()

	for country_name in detected_countries:
		add_country(country_name)

	print("CountryManager: Initialized %d countries." % countries.size())


func get_country(c_name: String) -> CountryData:
	c_name = c_name.to_lower()
	if c_name == "sea":
		return null
	if countries.has(c_name):
		return countries[c_name]
	push_warning("CountryManager: Requested non-existent country '%s'" % c_name)
	return null


func set_player_country(country_name: String) -> void:
	var country := countries.get(country_name.to_lower()) as CountryData
	if !country:
		push_error("CountryManager: Requested non-existent country '%s'" % country_name)
		return

	if player_country:
		player_country.is_player = false

	player_country = country
	player_country.is_player = true

	print("Player is now playing as: ", country_name)
	emit_signal("player_country_changed")


func add_country(country_name: String) -> CountryData:
	if country_name == "" or country_name.to_lower() == "sea":
		return null
		
	var c_name_lower = country_name.to_lower()

	# 1. Check if it already exists
	if countries.has(c_name_lower):
		return countries[c_name_lower]

	# 2. Check if the flag exists
	var flag = TroopManager.get_flag(c_name_lower)
	if flag == null:
		push_error("CountryManager: No flag for '%s'. Skipping." % country_name)
		return null

	# 3. Create the instance
	var new_country = CountryData.new(country_name)
	new_country.daily_process_hour = countries.size() % 24
	
	# 4. Initialize Relations Safely
	# We add to the dictionary BEFORE setting relations to prevent lookup errors
	countries[c_name_lower] = new_country

	for existing_name in countries.keys():
		if existing_name == c_name_lower: 
			continue # Don't set relations with yourself
			
		var other_country = countries[existing_name]
		if is_instance_valid(other_country):
			var start_rel = randi_range(0, 100)
			new_country.set_relation_with(existing_name, start_rel)
			other_country.set_relation_with(c_name_lower, start_rel)

	# 5. Geography Setup (Use safety checks for methods)
	if has_method("get_border_provinces_country"):
		new_country.border_provinces = get_border_provinces_country(c_name_lower)
	
	if has_method("get_neighbor_border_provinces"):
		new_country.enemy_border_provinces = get_neighbor_border_provinces(c_name_lower)
		
	if has_method("get_neighboring_countries"):
		new_country.neighbor_countries = get_neighboring_countries(c_name_lower)
		
	return new_country

# HELPER FUNCTIONS ==========================================
func get_border_provinces_country(country) -> Array[Province]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []
	var border_provinces: Array[Province] = []
	for province in MapManager.country_to_provinces_obj[country]:
		if province.neighbors_obj.any(func(neighbor): return neighbor.country != country):
			border_provinces.append(province)
	return border_provinces


func get_neighbor_border_provinces(country) -> Array[Province]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []

	var neighbor_provinces := {}

	for province in MapManager.country_to_provinces_obj[country]:
		for neighbor in province.neighbors_obj:
			if neighbor.country != country:
				neighbor_provinces[neighbor] = true

	var result: Array[Province] = []
	for p in neighbor_provinces.keys():
		result.append(p)

	return result


func get_neighboring_countries(country) -> Array[String]:
	if !MapManager.country_to_provinces_obj.has(country):
		return []

	var result: Array[String] = []

	for province in MapManager.country_to_provinces_obj[country]:
		for neighbor in province.neighbors_obj:
			if neighbor.country != country and neighbor.country not in result:
				result.append(neighbor.country)

	return result


func update_province_border_status(province: Province) -> void:
	var country = CountryManager.countries.get(province.country, null)
	if country == null:
		return

	var is_border := false
	var enemy_neighbors_to_add := []

	# Check neighbors
	for neighbor in province.neighbors_obj:
		if neighbor.country != province.country:  # province.country is string
			is_border = true
			if neighbor not in country.enemy_border_provinces:
				enemy_neighbors_to_add.append(neighbor)

	# --- Border provinces ---
	if is_border:
		if province not in country.border_provinces:
			country.border_provinces.append(province)
	else:
		country.border_provinces.erase(province)

	# --- Enemy border provinces ---
	for n in enemy_neighbors_to_add:
		country.enemy_border_provinces.append(n)

	# Remove old enemy neighbors that no longer border this country
# Remove old enemy neighbors that no longer border this country
	country.enemy_border_provinces = country.enemy_border_provinces.filter(
		func(p):
			# Determine the country name property safely
			var c_name = country.country_name if "country_name" in country else country.country

			# p is a Province object, compare its owner string
			return p.country != c_name
	)
	# --- Neighboring countries ---
	var neighbor_countries_set := {}
	for border_prov in country.border_provinces:
		for neighbor in border_prov.neighbors_obj:
			if neighbor.country != province.country:  # compare to province.country string
				neighbor_countries_set[neighbor.country] = true

	country.neighbor_countries = neighbor_countries_set.keys()


func get_country_population(country_name: String) -> int:
	if not MapManager.country_to_provinces.has(country_name):
		return 0
	var total_pop: int = 0
	var pids = MapManager.country_to_provinces[country_name]
	for pid in pids:
		if MapManager.province_objects.has(pid):
			total_pop += MapManager.province_objects[pid].population
	return total_pop

func get_factories_amount(country_name: String) -> int:
	var provinces = MapManager.country_to_provinces.get(country_name, [])
	var count = 0
	for pid in provinces:
		if MapManager.province_objects[pid].factory == Province.FACTORY_BUILT:
			count += 1
	return count


static func _get_manpower_from_template(type: String) -> int:
	var stats = DivisionData.TEMPLATES.get(type, DivisionData.TEMPLATES["infantry"])
	return stats["manpower"]


func _cleanup_empty_countries() -> void:
	var to_remove: Array[String] = []

	for c_name in countries.keys():
		var provinces = MapManager.country_to_provinces.get(countries[c_name].country_name, [])
		if provinces.is_empty():
			to_remove.append(c_name)

	for c_name in to_remove:
		print("CountryManager: Removing '%s' (No provinces found)." % c_name)
		countries.erase(c_name)


# --- DIPLOMATIC DYNAMICS & COMMUNICATION ---

func _process_ai_diplomacy() -> void:
	for c_name in countries:
		var country_obj = countries[c_name]
		if country_obj.is_player:
			continue
		
		# Limit frequency: 10% chance per day to make a diplomatic check
		if randf() > 0.10:
			continue
			
		var neighbors = country_obj.neighbor_countries
		if neighbors.is_empty():
			continue
			
		# Pick a target country (can be neighbor or player)
		var target_name = neighbors.pick_random()
		if randf() < 0.35 and player_country != null:
			target_name = player_country.country_name
			
		var target_country = get_country(target_name)
		if not target_country or target_country == country_obj:
			continue
			
		var rel = country_obj.get_relation_with(target_name)
		var at_war = WarManager.is_at_war(country_obj, target_country)
		
		if at_war:
			continue
			
		# Offer trade if AI needs resources
		var offered = false
		if country_obj.steel < 15.0 or country_obj.steel_consumption > country_obj.steel_production:
			# Needs Steel: request to buy steel
			if target_country.steel > 35.0 and target_country.steel_production > target_country.steel_consumption:
				var amount = 4.0
				var price_per_day = round(market_steel_price * amount * (1.0 - (rel - 50.0)/200.0))
				send_diplomatic_message(
					c_name, 
					target_name, 
					"TRADE_OFFER", 
					"Steel Trade Offer", 
					"%s wants to buy %.1f Steel per day from us for $%d per day." % [c_name.capitalize(), amount, price_per_day],
					{"resource": "steel", "amount": amount, "price": price_per_day, "is_buying": true}
				)
				offered = true
				
		if not offered and (country_obj.oil < 10.0 or country_obj.oil_consumption > country_obj.oil_production):
			# Needs Oil
			if target_country.oil > 25.0 and target_country.oil_production > target_country.oil_consumption:
				var amount = 4.0
				var price_per_day = round(market_oil_price * amount * (1.0 - (rel - 50.0)/200.0))
				send_diplomatic_message(
					c_name, 
					target_name, 
					"TRADE_OFFER", 
					"Oil Trade Offer", 
					"%s wants to buy %.1f Oil per day from us for $%d per day." % [c_name.capitalize(), amount, price_per_day],
					{"resource": "oil", "amount": amount, "price": price_per_day, "is_buying": true}
				)
				offered = true
				
		# Or offer Non-Aggression Pact
		if not offered and rel > 55 and randf() < 0.20:
			send_diplomatic_message(
				c_name,
				target_name,
				"NON_AGGRESSION",
				"Non-Aggression Pact Offer",
				"%s proposes a Non-Aggression Pact to guarantee peace between our nations." % [c_name.capitalize()],
				{}
			)
			offered = true


func send_diplomatic_message(sender: String, recipient: String, type: String, title: String, content: String, data: Dictionary) -> void:
	# Avoid duplicate message of same type from same sender to same recipient
	for m in active_messages:
		if m.sender == sender.to_lower() and m.recipient == recipient.to_lower() and m.type == type:
			return
			
	var msg_id = "msg_" + str(randi())
	var msg = {
		"id": msg_id,
		"sender": sender.to_lower(),
		"recipient": recipient.to_lower(),
		"type": type,
		"title": title,
		"content": content,
		"data": data,
		"date": clock.get_date_string() if clock else "2010-01-01",
		"accepted": null
	}
	
	var rec_country = get_country(recipient)
	if rec_country:
		if rec_country.is_player:
			active_messages.append(msg)
			message_received.emit(msg)
			messages_updated.emit()
			if is_instance_valid(MusicManager):
				MusicManager.play_sfx(MusicManager.SFX.POPUP)
		else:
			# AI recipient: process immediately
			process_ai_message(msg)


func process_ai_message(msg: Dictionary) -> void:
	var sender = msg.sender
	var recipient = msg.recipient
	var type = msg.type
	var data = msg.data
	
	var rec_country = get_country(recipient)
	var sen_country = get_country(sender)
	if not rec_country or not sen_country:
		return
		
	var rel = rec_country.get_relation_with(sender)
	var accepted = false
	
	match type:
		"TRADE_OFFER":
			var resource = data.get("resource", "")
			var amount = data.get("amount", 0.0)
			var price = data.get("price", 0.0)
			var is_buying = data.get("is_buying", true)
			
			if is_buying:
				var surplus = 0.0
				if resource == "steel":
					surplus = rec_country.steel_production - rec_country.steel_consumption
				elif resource == "oil":
					surplus = rec_country.oil_production - rec_country.oil_consumption
					
				if surplus >= amount and rel > 35:
					accepted = true
			else:
				var shortage = false
				if resource == "steel":
					shortage = rec_country.steel < 15.0 or rec_country.steel_consumption > rec_country.steel_production
				elif resource == "oil":
					shortage = rec_country.oil < 10.0 or rec_country.oil_consumption > rec_country.oil_production
					
				if shortage and rec_country.money > price * 15.0 and rel > 30:
					accepted = true
					
		"NON_AGGRESSION":
			if rel > 45 and not WarManager.is_at_war(rec_country, sen_country):
				accepted = true
				
		"MILITARY_ACCESS":
			if rel > 65:
				accepted = true
				
		"GIFT":
			accepted = true
			
	if accepted:
		msg.accepted = true
		execute_message_effect(msg)


func accept_message(msg_id: String) -> void:
	var msg_index = -1
	for i in range(active_messages.size()):
		if active_messages[i].id == msg_id:
			msg_index = i
			break
			
	if msg_index != -1:
		var msg = active_messages[msg_index]
		msg.accepted = true
		execute_message_effect(msg)
		active_messages.remove_at(msg_index)
		messages_updated.emit()
		if is_instance_valid(MusicManager):
			MusicManager.play_sfx(MusicManager.SFX.UPGRADE)


func decline_message(msg_id: String) -> void:
	var msg_index = -1
	for i in range(active_messages.size()):
		if active_messages[i].id == msg_id:
			msg_index = i
			break
			
	if msg_index != -1:
		active_messages.remove_at(msg_index)
		messages_updated.emit()


func execute_message_effect(msg: Dictionary) -> void:
	var sender = msg.sender
	var recipient = msg.recipient
	var type = msg.type
	var data = msg.data
	
	var sen_country = get_country(sender)
	var rec_country = get_country(recipient)
	if not sen_country or not rec_country:
		return
		
	match type:
		"TRADE_OFFER":
			trade_agreement_counter += 1
			var deal_id = "deal_" + str(trade_agreement_counter)
			var deal = {
				"id": deal_id,
				"sender": sender.to_lower(),
				"recipient": recipient.to_lower(),
				"resource": data.resource,
				"amount": data.amount,
				"price": data.price
			}
			sen_country.trade_deals[deal_id] = deal
			rec_country.trade_deals[deal_id] = deal
			
			var current_rel = rec_country.get_relation_with(sender)
			rec_country.set_relation_with(sender, current_rel + 10)
			
		"NON_AGGRESSION":
			var current_rel = rec_country.get_relation_with(sender)
			rec_country.set_relation_with(sender, current_rel + 15)
			rec_country.relations[sender + "_nap"] = true
			sen_country.relations[recipient + "_nap"] = true
			
		"MILITARY_ACCESS":
			if not rec_country.allowedCountries.has(sender):
				rec_country.allowedCountries.append(sender)
			if not sen_country.allowedCountries.has(recipient):
				sen_country.allowedCountries.append(recipient)
				
		"GIFT":
			var gift_type = data.get("gift_type", "money")
			var gift_amount = data.get("gift_amount", 0.0)
			if gift_type == "money":
				sen_country.money -= gift_amount
				rec_country.money += gift_amount
			elif gift_type == "steel":
				sen_country.steel -= gift_amount
				rec_country.steel += gift_amount
			elif gift_type == "oil":
				sen_country.oil -= gift_amount
				rec_country.oil += gift_amount
				
			var current_rel = rec_country.get_relation_with(sender)
			rec_country.set_relation_with(sender, current_rel + 20)


func cancel_trade_deal(country: CountryData, deal_id: String) -> void:
	if country.trade_deals.has(deal_id):
		var deal = country.trade_deals[deal_id]
		var other_name = deal.recipient if deal.sender == country.country_name.to_lower() else deal.sender
		var other_country = get_country(other_name)
		
		country.trade_deals.erase(deal_id)
		if other_country:
			other_country.trade_deals.erase(deal_id)
			
		if other_country:
			var current_rel = other_country.get_relation_with(country.country_name)
			other_country.set_relation_with(country.country_name, current_rel - 5)
