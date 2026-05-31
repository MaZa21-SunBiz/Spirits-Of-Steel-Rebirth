using Godot;
using System;

public partial class GameState : Node {
	public static GameState Instance { get; private set; }

	enum IndustryType {
		DEFAULT,
		FACTORY,
		PORT,
		INFRASTRUCTURE,
		LUMBER,
		QUARRY,
	}

	GameUI gameUi;
	IndustryType industryBuilding = IndustryType.DEFAULT;
	Tooltip tooltip;
	World  currentWorld;

	bool choosingDeployCity = false;
	bool instaBuild					= false;
	bool decisionMenuOpen		= false;
	bool inPeaceProcess			= false;
	bool lostTerritory			= false;
	bool selectingCountry		= false;
	bool showingTooltip			= false;
	bool isLoadingGame			= false;

	string currentStart;
	string pendingLoadSave = "";

	public void ResetIndustryBuilding() {
		industryBuilding = IndustryType.DEFAULT;
		MapManager.Instance.ShowCountriesMap();
	}

	public override void _Ready() {
		Instance = this;
	}
}
