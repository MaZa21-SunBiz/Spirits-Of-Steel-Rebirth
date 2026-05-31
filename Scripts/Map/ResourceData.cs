using Godot;
using System;
using System.Collections.Generic;

public partial class ResourceData : Node {
	string name;
	Color color;
	public string icon;
	int basePrice;
	Dictionary<string, float> tags = new Dictionary<string, float>();

	public static ResourceData FromDict(Godot.Collections.Dictionary a_data) {
		ResourceData resource = new ResourceData();

		resource.name												 = (string) a_data["name"];
		resource.color		 									 = new Color(a_data.TryGetValue("color", out Variant o_color) ? o_color.As<string>() : "#FFFFFF");
		resource.icon			 									 = a_data.TryGetValue("icon", out Variant o_icon) ? o_icon.As<string>() : "";
		resource.basePrice 									 = a_data.TryGetValue("base_price", out Variant o_basePrice) ? (int) o_basePrice : 100;
		Godot.Collections.Dictionary<string, float> gdTags = a_data.TryGetValue("tags", out Variant o_typedTags) ? o_typedTags.As<Godot.Collections.Dictionary<string, float>>() : new Godot.Collections.Dictionary<string, float>();
		foreach (var entry in gdTags) {
			resource.tags[entry.Key] = (float) entry.Value;
		}

		return resource;
	}

	public Godot.Collections.Dictionary<string, Variant> ToDict() {
		Godot.Collections.Dictionary<string, float> gdTags = new Godot.Collections.Dictionary<string, float>();
		foreach (var entry in this.tags) {
			gdTags[entry.Key] = (float) entry.Value;
		}
		return new(){
			{"name", this.name},
			{"color", "#" + this.color.ToHtml(false)},
			{"icon", this.icon},
			{"base_price", this.basePrice},
			{"tags", gdTags}
		};
	}
}
