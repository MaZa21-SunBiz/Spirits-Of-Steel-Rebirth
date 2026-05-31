using Godot;
using System;

[GlobalClass] public partial class RecipeData : Node {
	[Export] public string   producedResource;
	[Export] string[] resourcesRequired;

	public static RecipeData FromDict(Godot.Collections.Dictionary a_data) {
		RecipeData recipe = new RecipeData();
		recipe.producedResource  = (string) (a_data.TryGetValue("produced_resouce", out Variant o_producedResource) ? o_producedResource : "");
		recipe.resourcesRequired = a_data.TryGetValue("resouces_required", out Variant o_resourcesRequired) ? o_resourcesRequired.As<string[]>() : [];
		return recipe;
	}

	public Godot.Collections.Dictionary<string, Variant> ToDict() {
		return new Godot.Collections.Dictionary<string, Variant>(){
			{"produced_resouce", producedResource},
			{"resouces_required", resourcesRequired},
		};
	}
}
