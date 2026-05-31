using Godot;
using System;

public partial class GameUI : CanvasLayer {
	// Dictionary statsLabels = new();
	enum Context  {PLAYER, ENEMY, NEUTRAL, PUPPET, ALLY, SELECT}
	enum Category {GENERAL, ECONOMY, MILITARY}

	[Export] PanelContainer settings;

	[ExportGroup("Top Bar")]
		[Export] HBoxContainer  topBar;
		[Export] TextureRect	  nationFlag;
		[Export] Label				  labelDate;
		[Export] PanelContainer	radiosPanel;

		[ExportSubgroup("Stats Labels")]
			[Export] Label labelPP;
			[Export] Label labelManpower;
			[Export] Label labelMoney;
			[Export] Label labelIndustry;
			[Export] Label labelStability;
			[Export] Label labelWarSupport;
			[Export] Label labelWorldTension;

		[ExportSubgroup("Speed Controls")]
			[Export] Button			 plus;
			[Export] Button			 minus;
			[Export] ProgressBar progressBar;

	[ExportGroup("Side Bar")]
		[Export] Control sidemenu;
		[Export] Label				 sidemenuCountryLabel;
		[Export] Label				 militaryAccessLabel;
		[Export] TextureRect	 sidemenuLeaderPortrait;
		[Export] TextureRect	 flag1;
		[Export] TextureRect 	 flag2;
		[Export] TextureRect 	 owner1;
		[Export] TextureRect 	 owner2;
		[Export] HBoxContainer relationsBox;
		[Export] Label				 relation1;
		[Export] Label 				 relation2;
		[Export] Button				 playBtn;

		[Export] TabContainer	 sidemenuContext;
		[Export] VBoxContainer sidemenuTroopList;
		[Export] VBoxContainer sidemenuBuildings;
		[Export] OptionButton buildingDropDown;
		[Export] Container tradeEntries;
		[Export] Container productionEntries;

		[Export] VBoxContainer	factionBox;
		[Export] PanelContainer factionPrompt;

		[Export] VBoxContainer acceptedCultures;
		[Export] VBoxContainer unacceptedCultures;
		[Export] VBoxContainer SelectPlayerStat;

		[Export] PackedScene actionScene;


}
