using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class Province : Node {
	public enum ProvinceTypes {
		SEA,
		LAND
	}
	public enum BUILDINGS {
		NO_FACTORY = 0,
		NO_PORT = 0,
		FACTORY_BUILDING = 1,
		PORT_BUILDING = 1,
		FACTORY_BUILT = 2,
		PORT_BUILT = 2
	}
	ProvinceTypes type = ProvinceTypes.LAND;
	public int id;
	string name;
	string country;
	string occupier;
	string biome;
	ResourceNode[] resources;
	int resourceMultiplier;
	string city;
	BuildingData[] buildings;
	PopulationData[] populations;
	int gdp = 1_000;
	Vector2 center;
	string[] claims;
	int infrastructure;
	int maxInfrastructure;

	public Godot.Collections.Dictionary<string, Variant> ToDict(Godot.Collections.Array<Godot.Collections.Dictionary> troopsData = null) {
		return new Godot.Collections.Dictionary<string, Variant>() {
			{"type", (int) this.type},
			{"name", this.name},
			{"polity", this.country},
			{"occupier", this.occupier},
			{"biome", this.biome},
			{"resources", new Godot.Collections.Array<Godot.Collections.Dictionary>(resources.Select(resource => resource.ToDict()).ToArray())},
			{"resources_multiplier", this.resourceMultiplier},
			{"city", this.city},
			{"buildings", new Godot.Collections.Array<Godot.Collections.Dictionary>(buildings.Select(building => building.ToDict()).ToArray())},
			{"populations", new Godot.Collections.Array<Godot.Collections.Dictionary>(populations.Select(population => population.ToDict()).ToArray())},
			{"gdp", this.gdp},
			{"claims", (claims.Length == 1 && claims[0] == country) ? [] : this.claims},
			{"infrastructure", this.infrastructure},
			{"max_infrastructure", this.maxInfrastructure},
			{"troops", new Godot.Collections.Array<Godot.Collections.Dictionary>(troopsData == null ? [] : troopsData)}
		};
	}

	public static Province FromDict(Godot.Collections.Dictionary<string, Variant> a_data) {
		Province province = new Province();
		if (!a_data.TryGetValue("type", out Variant o_type) || o_type.As<ProvinceTypes>() == ProvinceTypes.SEA) {
			province.type								= ProvinceTypes.SEA;
			province.name								= "Sea";
			province.country						= "Sea";
			province.gdp								= 0;
			province.city								= "";
			province.occupier 					= "";
			province.biome							= a_data.TryGetValue("biome", out Variant o_biome) ? (string) o_biome : "Sea";
			province.resourceMultiplier = a_data.TryGetValue("resources_multiplier", out Variant o_resourceMultiplier) ? (int) o_resourceMultiplier : 1;
			province.infrastructure			= a_data.TryGetValue("infrastructure", out Variant o_infrastructure) ? (int) o_infrastructure : 0;
			province.maxInfrastructure	= a_data.TryGetValue("max_infrastructure", out Variant o_maxInfrastructure) ? (int) o_maxInfrastructure : 0;

			province.buildings					= [];
			province.populations				= [];
			if (a_data.TryGetValue("resources", out Variant o_resources)) {
				province.resources = o_resources.As<Godot.Collections.Array<Godot.Collections.Dictionary>>().Select(resource => ResourceNode.FromDict(resource)).ToArray();
			} else {
				province.resources = [];
			}
		} else {
			province.type								= ProvinceTypes.LAND;
			province.name		 						= (string) a_data["name"];
			province.country 						= (string) a_data["polity"];
			province.gdp		 						= 1_000;
			province.city								= a_data.TryGetValue("city", out Variant o_city) ? (string) o_city : "";
			province.occupier 					= a_data.TryGetValue("occupier", out Variant o_occupier) ? (string) o_occupier : "";
			province.biome							= a_data.TryGetValue("biome", out Variant o_biome) ? (string) o_biome : "Plains";
			province.resourceMultiplier = a_data.TryGetValue("resources_multiplier", out Variant o_resourceMultiplier) ? (int) o_resourceMultiplier : 1;
			province.infrastructure			= a_data.TryGetValue("infrastructure", out Variant o_infrastructure) ? (int) o_infrastructure : 0;
			province.maxInfrastructure	= a_data.TryGetValue("max_infrastructure", out Variant o_maxInfrastructure) ? (int) o_maxInfrastructure : 5;

			if (a_data.TryGetValue("buildings", out Variant o_buildings)) {
				province.buildings = o_buildings.As<Godot.Collections.Array<Godot.Collections.Dictionary>>().Select(building => BuildingData.FromDict(building)).ToArray();
			} else {
				province.buildings = [];
			}
			if (a_data.TryGetValue("populations", out Variant o_populations)) {
				province.populations = o_populations.As<Godot.Collections.Array<Godot.Collections.Dictionary>>().Select(population => PopulationData.FromDict(population)).ToArray();
			} else {
				province.populations = [];
			}
			if (a_data.TryGetValue("resources", out Variant o_resources)) {
				province.resources = o_resources.As<Godot.Collections.Array<Godot.Collections.Dictionary>>().Select(resource => ResourceNode.FromDict(resource)).ToArray();
			} else {
				province.resources = [];
			}
			province.claims = (a_data.TryGetValue("claims", out Variant o_claims) ? o_claims.As<string[]>() : [province.country]);
		}
		return province;
	}

	public int GetPopulation() {
		int totalPopulation = 0;
		foreach (PopulationData subPopulation in this.populations) {
			totalPopulation += subPopulation.amount;
		}
		return totalPopulation;
	}

	public int GetFactories() {
		int totalFactories = 0;
		foreach (BuildingData building in this.buildings) {
			if (building.state == BuildingData.BuildingState.FUNCTIONAL) {
				totalFactories += 1;
			}
		}
		return totalFactories;
	}

	public string GetFunctionalOwner() {
		return (this.occupier == "" ? country : occupier);
	}

	public string GetResources() {
		Dictionary<string, int> counts = new Dictionary<string, int>();
		foreach (ResourceNode resource in resources) {
			if (counts.ContainsKey(resource.type)) {
				counts[resource.type] += resource.amount;
			} else {
				counts[resource.type] = resource.amount;
			}
		}
		string list = "";
		foreach (string resourceType in counts.Keys) {
			if (list != "") {
				list += "\n";
			} 
			list += resourceType + ": " + counts[resourceType];
		}
		return list;
	}
}
