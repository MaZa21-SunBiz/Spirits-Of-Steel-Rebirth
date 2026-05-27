using Godot;
using System;
using System.Linq;
using System.Collections.Generic;

// [GlobalClass]
public partial class SoiStar : AStar2D {
	string[] contextAllowedCountries = [];

	public float _ComputeCost(int fromId, int toId) {
		if (NeighborFilterEnabled && _FilterNeighbour(fromId, toId)) {
			return int.MaxValue;
		}
		return GetPointPosition(fromId).DistanceTo(GetPointPosition(toId));
	}

	private bool _FilterNeighbour(int fromId, int toId) {
		Province fromProv = MapManager.Instance.provinceObjects[fromId];
		Province toProv   = MapManager.Instance.provinceObjects[toId];

		if (fromProv == null || toProv == null) {
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
