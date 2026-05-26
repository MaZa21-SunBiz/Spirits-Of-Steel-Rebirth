using Godot;
using System;

public partial class BiomeData : Node {
	enum Temperature {
		HOT,
		NORMAL,
		COLD
	}
	string name;
	Color color;
	bool isForest;
	Temperature temperature;

	public static BiomeData FromDict(Godot.Collections.Dictionary a_data) {
		BiomeData biomeData		= new BiomeData();
		biomeData.name				= (string) a_data["name"];
		biomeData.color				= new Color(a_data.TryGetValue("color", out Variant o_color) ? o_color.As<string>() : "#FFFFFF");
		biomeData.isForest		= a_data.TryGetValue("forest", out Variant o_isForest) ? (bool) o_isForest : biomeData.name.ToLower().Contains("forest");
		biomeData.temperature = a_data.TryGetValue("temperature", out Variant o_temperature) ? o_temperature.As<Temperature>() : Temperature.NORMAL;

		return biomeData;
	}

	public Godot.Collections.Dictionary<string, Variant> ToDict() {
		return new Godot.Collections.Dictionary<string, Variant> {
			{"name", this.name},
			{"color", this.color.ToHtml(false).ToUpper()},
			{"forest", this.isForest},
			{"temperature", (int) this.temperature}
		};
	}
}
