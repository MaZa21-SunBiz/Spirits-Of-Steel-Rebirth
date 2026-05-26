using Godot;
using System;
using System.Collections.Generic;

public partial class MapManager : Node
{
	bool DEBUG_MODE = false;
	// [Signal] public delegate void ProvinceHovered(int province_id, string country_name);
	// [Signal] public delegate void CountryClicked(string country_name);
	// [Signal] public delegate void ProvinceOwnershipChanged(int pid, string old_owner, string new_owner);
	// [Signal] public delegate void close_sidemenu();
	
	public Color SEA_MAIN   = new Color("#7e8e9e");
	public Color SEA_RASTER = new Color("#697684");
	string hoveredCountry = "Sea";

	Image idMapimage;
	Image stateColorImage;
	ImageTexture stateColorTexture;
	int maxProvinceId;

	Dictionary<string, Color> ethnicNameToColor = new Dictionary<string, Color>();

	Dictionary<string, int[]> countryToProvinces				 = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToOwnedProvinces		 = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToOccupiedProvinces = new Dictionary<string, int[]>();
	Dictionary<string, int[]> countryToCities						 = new Dictionary<string, int[]>();
	public Dictionary<int, Province> provinceObjects		 = new Dictionary<int, Province>();
	Dictionary<string, BiomeData> biomes								 = new Dictionary<string, BiomeData>();
	Dictionary<string, ResourceData> resources					 = new Dictionary<string, ResourceData>();
	Dictionary<string, RecipeData> recipes							 = new Dictionary<string, RecipeData>();

	int currentHoveredPid = -1;
	int lastHoveredPid = -1;
	int originalHoverColor = -1;
	Dictionary<int, Vector2> provinceCenters = new Dictionary<int, Vector2>();
	Dictionary<int, int> uniqueRegions = new Dictionary<int, int>();
	SoiStar provinceGraph = new SoiStar();
	

}
