using Godot;
using System;

public partial class  : HBoxContainer {
	[Export] Button button;
	// Dictionary<,> data = new();
	string baseText = "";
	Callable _callback;
	Variant sourceObject;

	// [Signal] TrainingFinished;
	// [Signal] Pressed;
	
	// public override void _Ready() {}

	public void _OnButtonPressed() {
		CountryManager.Instance.playerCountry.politicalPower -= data.TryGetValue("cost", out float politicalPower) ? politicalPower : 0;
	}

	public void SetupTraining(trainingObj)


}
