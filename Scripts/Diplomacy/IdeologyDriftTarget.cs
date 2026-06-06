using Godot;
using System;
using ExportDicitonary = Godot.Collections.Dictionary<string, Variant>;

public partial class IdeologyDriftTarget : Node {
	Vector2 finalPosition = new Vector2{0, 0}; 
	float driftAmount = 0;

	public static IdeologyDriftTarget FromDict(ExportDicitonary a_data) {
		IdeologyDriftTarget ideologyDriftTarget = new IdeologyDriftTarget(); 
		ideologyDriftTarget.finalPosition = Vector2(a_data["final_position"][0], a_data["final_position"][1]);
		ideologyDriftTarget.driftAmount = a_data["drift_amount"];
	}

	public ExportDicitonary FromDict() {
		return new ExportDicitonary{
			{"final_position", [ this.finalPosition.x, this.finalPosition.y ]},
			{"drift_amount", this.driftAmount},
		};
	}
}
