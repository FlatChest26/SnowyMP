class SnowyMPHandler : StaticEventHandler
{
	enum EMultiplayerGameMode
	{
		MGM_None = 0,
		MGM_Deathmatch = 1,
		MGM_TeamDeathmatch = 2,
		MGM_Cooperative = 3
	}

	// Methods //

	// Checks 

	clearscope bool IsMultiplayerGame() const { return multiplayer; }

	clearscope bool IsDeathmatchGame() const { return multiplayer && deathmatch; }
	clearscope bool IsTeamDeathmatchGame() const { return multiplayer && teamplay; }
	clearscope bool IsCooperativeGame() const { return multiplayer && !deathmatch && !teamplay; }

	clearscope int GetMultiplayerGameMode() const
	{
		if (IsDeathmatchGame())
			return MGM_Deathmatch;
		else if (IsTeamDeathmatchGame())
			return MGM_TeamDeathmatch;
		else if (IsCooperativeGame())
			return MGM_Cooperative;
		else 
			return MGM_None;
	}
}