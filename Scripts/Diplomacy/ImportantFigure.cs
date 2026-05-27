using Godot;
using System;
using System.Collections.Generic;

public partial class ImportantFigure : Node {
	enum Status {
		ALIVE,
		WOUNDED,
		DEAD
	}

	string name;
	Dictionary<string, float> skills;
	// this isnt implemented yet so idk the array type
	// [] traits;
	Godot.Vector2I ideology;


}
