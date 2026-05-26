using Godot;
using System;
using GDictionary = Godot.Collections.Dictionary;

[GlobalClass] public partial class RecipeData : Node {
	[Export] string   produced_resouce;
	[Export] string[] resouces_required;

	public static RecipeData FromDict(GDictionary a_data) {
		RecipeData recipe = new RecipeData();
		recipe.produced_resouce  = (string) (a_data.TryGetValue("produced_resouce", out Variant o_produced_resouce) ? o_produced_resouce : "");
		recipe.resouces_required = a_data.TryGetValue("resouces_required", out Variant o_resouces_required) ? o_resouces_required.As<string[]>() : [];
		return recipe;
	}

	public GDictionary ToDict() {
		return new GDictionary(){
			{"produced_resouce", produced_resouce},
			{"resouces_required", resouces_required},
		};
	}
}
