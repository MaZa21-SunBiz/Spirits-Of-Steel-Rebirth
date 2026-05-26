using Godot;
using System;
using GDictionary = Godot.Collections.Dictionary;

public partial class PopulationData : Node {
	public string ethnicity;
	public int amount;

	public static PopulationData FromDict(GDictionary a_data) {
		PopulationData population = new PopulationData();

		population.ethnicity = (string) a_data["ethnicity"];
		population.amount = (int) a_data["amount"];

		return population;
	}
	public GDictionary ToDict() {
		return new GDictionary {
			{"ethnicity", this.ethnicity},
			{"amount", this.amount}
		};
	}
}
