using Godot;
using System;

public class Battle {
	public int attackerPID;
	public int defenderPID;

	public string attackerString;
	public string defenderString;

	public CountryData attackerData;
	public CountryData defenderData;

	float attackProgress = 0.0f;

	float attackerMorale;
	float defenderMorale;
	float initialDefenderMorale;

	float currentDefenerHP = 0.0f;
	float totalStartingHP  = 0.0f;

	float timer  = 0.0f;
	Vector2 position;

	public _Init(int attackerPID, int defenderPID, string attackerCountry, string defenderCountry, Vector2 position, WarManager warManager, CountryManager countryManager) {
		// WarManager warManager = a_warManager;

		this.attackerPID = attackerPID;
		this.defenderPID = defenderPID;

		attackerString = attackerCountry;
		defenderString = defenderCountry;

		attackerData = countryManager.countries[attackerCountry];
		defenderData = countryManager.countries[defenderCountry];

		attackerMorale				= attackerData == null ? 80.0f : attackerData.GetMaxMorale();
		initialDefenderMorale = (defenderData == null ? 80.0f : defenderData.GetMaxMorale()) + WarManager.MORALE_BOOST_DEFENDER;
		defenderMorale				= initialDefenderMorale;

		_UpdateHPTotals();
		totalStartingHP = currentDefenerHP;
	}

	private void _UpdateHPTotals() {
		float total = 0.0f;
		foreach (
			TroopData troop in 
			TroopManager.Instance.GetTroopsInProvince(defenderPID)
				.filter( troop => troop.country_name = defender_country)
		) {
			foreach (DivisionData division in troop.storedDivisions) {
				total += division.HP;
			    
			}
		}

	}


}
