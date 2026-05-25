using Godot;
using System;

[GlobalClass] public partial class RecipeData : Node
{
	[Export] string produced_resouce;
	[Export] string[] resouces_required;

	public static RecipeData FromDict(Godot.Collections.Dictionary<string, Godot.Variant> a_data) {
		RecipeData recipe = new RecipeData();
		recipe.produced_resouce  = (string)a_data["produced_resouce"];  //, out "");
		recipe.resouces_required = (string[])a_data["resouces_required"];//, out new string[] );
		return recipe;
	}

	public Godot.Collections.Dictionary<string, Godot.Variant> ToDict() {
		return new Godot.Collections.Dictionary<string, Godot.Variant>(){
			{"produced_resouce", produced_resouce},
			{"resouces_required", resouces_required},
		};
	}

	// Called when the node enters the scene tree for the first time.
	// public override void _Ready()
	// {
	// }
	//
	// Called every frame. 'delta' is the elapsed time since the previous frame.
	// public override void _Process(double delta)
	// {
	// }
}
