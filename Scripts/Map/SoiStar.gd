extends AStar2D
class_name SoiStar
# NOTE(soi): I AM A SUPERSTAR

func _filter_neighbor(from_id: int, to_id: int) -> bool:
	# print("from id: ", MapManager.province_objects[from_id].country)
	# print("to id: ", MapManager.province_objects[to_id].country)
	# print("allowed countries: ", MapManager.province_objects[to_id].country)
	var from_country: String = MapManager.province_objects[from_id].country
	var to_country: String = MapManager.province_objects[to_id].country
	return !(
		from_country == "Sea"
		|| to_country == "Sea"
		|| to_country == MapManager.province_objects[from_id].country
		|| to_country in CountryManager.countries[from_country].allowedCountries
		|| MapManager.province_objects[from_id].country in CountryManager.countries[to_country].allowedCountries
		)
