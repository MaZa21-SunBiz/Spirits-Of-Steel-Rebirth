using Godot;
using System;
using System.Linq;

// [GlobalClass]
public partial class SoiStar : AStar2D {
	string[] contextAllowedCountries = [];

	public float computeCost(int fromId, int toId) {
		if (NeighborFilterEnabled && FilterNeighbour(fromId, toId)) {
			return int.MaxValue;
		}
		return GetPointPosition(fromId).DistanceTo(GetPointPosition(toId));
	}

	private bool FilterNeighbour(int fromId, int toId) {
		Province fromProv = MapManager.provinceObjects[fromId];
		Province toProv   = MapManager.provinceObjects[toId];

		if (!(fromProv != null && toProv != null)) {
			return true;
		}

		string fromOwner = fromProv.GetFunctionalOwner();
		string toOwner	 = toProv.GetFunctionalOwner();

		if (contextAllowedCountries.Length == 0) {
			if (contextAllowedCountries.Contains(toOwner) || !contextAllowedCountries.Contains(fromOwner)) {
				return false;
			}
			// return true;
		}
		return true;
	}
}
