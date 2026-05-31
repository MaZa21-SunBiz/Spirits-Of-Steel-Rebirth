using Godot;
using System;
using System.Collections.Generic;

public partial class MapData : Resource {
	public Image idMapImage;
	public Dictionary<int, Vector2> provinceCenters;
	public // Dictionary<int, int[]> adjacencyList;
	Dictionary<string, int[]> countryToProvinces;
	public int maxProvinceId;
	public Dictionary<int, Province> provinceObjects;
}
