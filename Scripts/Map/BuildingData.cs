using Godot;
using System;
using GDictionary = Godot.Collections.Dictionary;

public partial class BuildingData : Node {
	public enum BuildingState {
		CONSTRUCTION,
		FUNCTIONAL,
		RUIN
	}
	public string type;
	public BuildingState state;
	public float durability;

	public static BuildingData FromValues(
			string a_type,
			BuildingState a_state,
			float a_durability = (float) 1.0
		) {
		BuildingData building = new BuildingData();
		building.type = a_type;
		building.state = a_state;
		building.durability = a_durability;
		return building;
	}

	public static BuildingData FromDict(GDictionary a_data) {
		BuildingData building = new BuildingData();

		building.type = (string) a_data["type"];
		building.state = a_data.TryGetValue("state", out Variant o_state) ? o_state.As<BuildingState>() : BuildingState.FUNCTIONAL;
		building.durability = (float) (a_data.TryGetValue("durability", out Variant o_durability) ? o_durability :  1.0);

		return building;
	}

	public GDictionary ToDict(){
		return new GDictionary {
			{"type", this.type},
			{"state", (int) this.state},
			{"durability", this.type},
		};
	}
}
