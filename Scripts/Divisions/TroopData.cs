using Godot;
using System.Linq;
using GDicionary = Godot.Collections.Dictionary<string, Godot.Variant>;

public partial class TroopData : Node {
	string				 countryName;
	CountryData 	 countryData;
	int						 provinceID;
	Vector2				 position;
	public DivisionData[] storedDivisions = [];

	// int divisionCount = 0;
	// NOTE(soi): pol doesn't like this.

	bool isMoving = false;
	int[] path = [];

	Vector2 targetPosition = Vector2.Zero;
	float progress = 0f;

	public TroopData(
			string p_countryName,
			int p_provinceID,
			int p_divisions,
			Vector2 p_position,
			Texture2D _p_position
			) {
		countryName = p_countryName;
		provinceID = p_provinceID;
		position = p_position;
		countryData = CountryManager.Instance.countries[p_countryName];

		for (int i = 0; i < p_divisions; i++) {
			DivisionData divisionData = new();
			divisionData.name = $"Division {i}";
			storedDivisions.Append<DivisionData>(divisionData);
		}
	}

	public GDicionary ToDict() {
		return new GDicionary{
			{"country_name", countryName},
			{"divisions", Variant.From(storedDivisions.Select(division => division.ToDict()).ToArray())},
			{"is_moving", isMoving},
			{"path", path},
			{"target_position", Variant.From<float[]>([targetPosition.X, targetPosition.Y])},
			{"progress", progress}
		};
	}
}
