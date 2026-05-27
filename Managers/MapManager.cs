using Godot;
using System;
using System.Collections.Generic;

public partial class MapManager : Node
{
	const string MAP_DATA_PATH = "res://map_data/MapData.tres";
	public const Color SEA_MAIN   = new Color("#7e8e9e");
	public const Color SEA_RASTER = new Color("#697684");

	bool DEBUG_MODE = false;

	public static MapManager Instance { get; private set; }
	// [Signal] public delegate void ProvinceHovered(int province_id, string country_name);
	// [Signal] public delegate void CountryClicked(string country_name);
	// [Signal] public delegate void ProvinceOwnershipChanged(int pid, string old_owner, string new_owner);
	// [Signal] public delegate void close_sidemenu();
	
	string hoveredCountry		= "Sea";

	Image idMapimage;
	Image stateColorImage;
	ImageTexture stateColorTexture;
	int maxProvinceId;

	Dictionary<string, Color> ethnicNameToColor						 = new Dictionary<string, Color>();
	Dictionary<string, int[]> countryToProvinces					 = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToOwnedProvinces		 	 = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToOccupiedProvinces 	 = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToCities						 	 = new Dictionary<string, int[]>();
	public Dictionary<int, Province> provinceObjects		 	 = new Dictionary<int, Province>();
	Dictionary<string, BiomeData> biomes								 	 = new Dictionary<string, BiomeData>();
	Dictionary<string, ResourceData> resources					 	 = new Dictionary<string, ResourceData>();
	Dictionary<string, RecipeData> recipes							 	 = new Dictionary<string, RecipeData>();
	Dictionary<int, Vector2> provinceCenters						 	 = new Dictionary<int, Vector2>();
	Dictionary<int, int> uniqueRegions			 						 	 = new Dictionary<int, int>();
	Dictionary<string, int[]> globalClaimsRegistry			 	 = new Dictionary<string, int[]>();
	Dictionary<string, ImportantFigure> significantFigures = new Dictionary<string, ImportantFigure>(); // this has @onready in gdscript
	Dictionary<string, int> allowedPids										 = new Dictionary<string, int>();
	Dictionary<string, Variant>[] allCities								 = [];

	int currentHoveredPid	 = -1;
	int lastHoveredPid		 = -1;
	int originalHoverColor = -1;
	float worldTension		 = 0.1f;

	SoiStar provinceGraph = new SoiStar();

	[Export] Texture2D regionTexture;
	[Export] Texture2D cultureTexture;
	[Export] Texture2D populationTexture;
	[Export] Texture2D cityTexture;
	[Export] Texture2D gdpTexture;
	[Export] Texture2D ethnicityTexture;
	[Export] Texture2D claimsTexture;

	[Export] int MAP_WIDTH  = 0;
	[Export] int MAP_HEIGHT = 625;

	// Dictionary<,> iconCache = new(); // i think ai made this?

	public override void _Ready() {
		Instance = this;
	}
}
