using Godot;
using System;
using GDictionary = Godot.Collections.Dictionary;

public partial class ResourceNode : Node {
	public string type;
	public int amount;
	public float quality;

	public static ResourceNode FromDict(GDictionary a_data) {
		ResourceNode resource = new ResourceNode();
		// string o_type;
		resource.type = (string) a_data["type"];
		resource.amount  = (int) (a_data.TryGetValue("amount", out Variant o_amount) ? o_amount : 1);
		resource.quality = (float) (a_data.TryGetValue("quality", out Variant o_quality) ? o_quality : 1.0);

		return resource;
	}

	public GDictionary ToDict() {
		return new GDictionary {
			{"type", this.type},
			{"amount", this.amount},
			{"quality", this.quality},
		};
	}
}
