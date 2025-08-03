struct SnowyMP_Constants
{
	int LevelRestartTime; 		// How long it takes for the level to restart after all players are ready
	int ReviveTime;				// How long to revive a teammate
	int RevivedHealth;			// The health that a revived player will begin at
	double RevivingDistance;	// Max distance to start reviving
}

struct SnowyMP_PlayerInfo
{
	enum ESpectatingModes
	{
		SM_FirstPerson = 0,
		SM_ThirdPerson = 1
	}

	bool IsActive;			// Whether a player is in the game
	bool IsAlive; 			// Whether player is dead
	bool OnGameOverScreen; 	// Whether a player is seeing the game over screen
	bool IsFrozen;			// Whether player is frozen
	bool WeaponLowered; 	// Whether the player's weapon is lowered

	int RevivingTarget; 	// Player number of the player being revived
	int RevivingTimer; 		// How long until the target is revived
	int RespawnDelayTimer;	// How long until the player can try to respawn

	int SpectatingMode;		// The player's spectating mode.
	int SpectatingTarget;	// The player being spectated.
	Actor SpectatingCamera; // The actor which acts as the spectating camera
	vector3 SpectatingOffset;

	transient bool ReadyToRestart; // Whether this player is ready to restart the level
	vector3 SpawnPoint;
	vector3 SafeSpot;
}

class SnowyMPGameplayChanges : EventHandler
{
	// Variables 

	SnowyMP_Constants MP_Constants;
	private SnowyMP_PlayerInfo MP_Players[MAXPLAYERS];

	/* Game Over */
	bool InGameOver; // Whether the game has ended because all players have died
	string GameOverMusic;

	int GameOverCount;

	/* Level Restart */
	transient bool LevelRestarting; // Whether to restart the level
	transient int RestartingTics; // Time until restart

	transient int PreviousRespawnDelay;

	// Methods //

	/* Getters */
	clearscope bool IsRespawningAllowed() const  { return CVar.GetCVar('snowy_mp__delay_before_respawn', players[consoleplayer]).GetInt() != -1; }
	clearscope int GetRespawnDelay() const { return CVar.GetCVar('snowy_mp__delay_before_respawn', players[consoleplayer]).GetInt(); }
	
	clearscope SnowyMPHandler GetSnowyMPHandler() const { return SnowyMPHandler(StaticEventHandler.Find('SnowyMPHandler')); }

	clearscope int ActivePlayerCount() const
	{
		int count = 0;
		for (int i = 0; i < MAXPLAYERS; i++) if (MP_Players[i].IsActive) count++;
		return count;
	}

	clearscope int LivingPlayerCount() const
	{
		int count = 0;
		for (int i = 0; i < MAXPLAYERS; i++) if (MP_Players[i].IsAlive) count++;
		return count;
	}

	clearscope int PlayersReadyToRestartCount() const
	{
		int count = 0;
		for (int i = 0; i < MAXPLAYERS; i++) if (MP_Players[i].ReadyToRestart) count++;
		return count;
	}

	clearscope bool IsPlayerActive(int PlayerNumber) const { return MP_Players[PlayerNumber].IsActive; }
	clearscope bool IsPlayerAlive(int PlayerNumber) const { return MP_Players[PlayerNumber].IsAlive; }
	clearscope bool IsPlayerOnGameOver(int PlayerNumber) const { return MP_Players[PlayerNumber].OnGameOverScreen; }
	clearscope bool IsPlayerFrozen(int PlayerNumber) const { return MP_Players[PlayerNumber].IsFrozen; }
	clearscope bool IsPlayerWeaponLowered(int PlayerNumber) const { return MP_Players[PlayerNumber].WeaponLowered; }

	clearscope int GetPlayerRevivingThisPlayer(int PlayerNumber) const 
	{
		for(int RevivingPlayer = 0; RevivingPlayer < MAXPLAYERS; RevivingPlayer++)
			if (GetPlayerRevivingTarget(RevivingPlayer) == PlayerNumber) return RevivingPlayer;
		return -1; 
	}

	clearscope bool IsPlayerReviving(int PlayerNumber) const { return MP_Players[PlayerNumber].RevivingTarget != -1; }
	clearscope bool IsPlayerBeingRevived(int PlayerNumber) const { return GetPlayerRevivingThisPlayer(PlayerNumber) != -1; }

	clearscope int GetPlayerRevivingTarget(int PlayerNumber) const { return MP_Players[PlayerNumber].RevivingTarget; }
	clearscope int GetPlayerRevivingTimer(int PlayerNumber) const { return MP_Players[PlayerNumber].RevivingTimer; }

	clearscope bool IsPlayerAllowedToRespawn(int PlayerNumber) const { return MP_Players[PlayerNumber].RespawnDelayTimer == 0; }
	clearscope bool IsPlayerRespawning(int PlayerNumber) const { return MP_Players[PlayerNumber].RespawnDelayTimer != -1; }
	clearscope int GetPlayerRespawnTimer(int PlayerNumber) const { return MP_Players[PlayerNumber].RespawnDelayTimer; }
	
	clearscope bool IsPlayerReadyToRestart(int PlayerNumber) const { return MP_Players[PlayerNumber].ReadyToRestart; }
	
	clearscope bool IsPlayerSpectating(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingTarget != PlayerNumber; }
	clearscope bool IsPlayerSpectatingFirstPerson(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingMode == SnowyMP_PlayerInfo.SM_FirstPerson; }
	clearscope bool IsPlayerSpectatingThirdPerson(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingMode == SnowyMP_PlayerInfo.SM_ThirdPerson; }
	clearscope int GetPlayerSpectatingTarget(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingTarget; }
	
	/* Setters & Player Behavior */

	void ReadyToRestart(int PlayerNumber) { MP_Players[PlayerNumber].ReadyToRestart = true; }

	bool CanPlayerSpectateOther(int PlayerNumber, int ObservedPlayerNumber)
	{
		if (!IsPlayerActive(ObservedPlayerNumber))
			return false;
		
		if (PlayerNumber == ObservedPlayerNumber)
		{
			// Can spectate self if dead
			if (IsPlayerAlive(PlayerNumber)) return false;
		}
		else
		{
			// Can spectate others if they are alive
			if (!IsPlayerAlive(ObservedPlayerNumber)) return false;
		}

		return true;
	}

	void PlayerStopSpectating(int PlayerNumber)
	{
		if (!IsPlayerSpectating(PlayerNumber)) return;
		MP_Players[PlayerNumber].SpectatingTarget = PlayerNumber;
		if (MP_Players[PlayerNumber].SpectatingCamera) MP_Players[PlayerNumber].SpectatingCamera.Destroy();
	}


	void FreezePlayer(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;
		if (IsPlayerFrozen(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player) return;

		player.cheats |= CF_FROZEN;
		MP_Players[PlayerNumber].IsFrozen = true;
	}

	void UnfreezePlayer(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;
		if (!IsPlayerFrozen(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player) return;

		player.cheats &= ~CF_FROZEN;
		MP_Players[PlayerNumber].IsFrozen = false;
	}

	void LowerPlayerWeapon(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;
		if (IsPlayerWeaponLowered(PlayerNumber)) return;
		
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		
		Weapon held_weapon = player.ReadyWeapon;
		if (!held_weapon) return;
		if (held_weapon is 'RevivingSyringe') return;

		if (player.PendingWeapon != WP_NOCHANGE) held_weapon = player.PendingWeapon;

		let dummy_weapon = RevivingSyringe(player.mo.FindInventory('RevivingSyringe', true));
		if (!dummy_weapon) dummy_weapon = RevivingSyringe(player.mo.GiveInventoryType('RevivingSyringe'));
		if (!dummy_weapon) return;

		dummy_weapon.PreviousWeaponType = held_weapon.GetClassName();
		player.mo.A_SelectWeapon('RevivingSyringe');
		MP_Players[PlayerNumber].WeaponLowered = true;
	}

	void RaisePlayerWeapon(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;
		if (!IsPlayerWeaponLowered(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		
		if (player.PendingWeapon is 'RevivingSyringe') player.PendingWeapon = player.ReadyWeapon;

		let dummy_weapon = RevivingSyringe(player.mo.FindInventory('RevivingSyringe', true));
		if (!dummy_weapon) return;

		player.mo.A_SelectWeapon(dummy_weapon.PreviousWeaponType);
		MP_Players[PlayerNumber].WeaponLowered = false;
	}

	clearscope bool IsPlayerOnDamagingFloor(int PlayerNumber)
	{
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return false;
		
		if (player.mo.CurSector.damageamount > 0)
			return true;

		return false;
	}

	clearscope bool IsPlayerFalling(int PlayerNumber)
	{
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return false;

		if (player.mo.Pos.Z > player.mo.FloorZ)
			return true;
		
		if (abs(player.mo.Vel.Z) > 0)
			return true;

		return false;
	}

	/* Initialization */

	override void WorldLoaded(WorldEvent e)
	{
		Initialize();
	}

	void Initialize()
	{
		RandomizeGameOverMusic();

		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			MP_Players[PlayerNumber].RespawnDelayTimer = -1;
			MP_Players[PlayerNumber].RevivingTarget = -1;

			MP_Players[PlayerNumber].SpectatingTarget = PlayerNumber;
			MP_Players[PlayerNumber].SpectatingMode = SnowyMP_PlayerInfo.SM_FirstPerson;

			MP_Players[PlayerNumber].SpectatingOffset.X = 0;
			MP_Players[PlayerNumber].SpectatingOffset.Y = 12;
			MP_Players[PlayerNumber].SpectatingOffset.Z = 0;
		}

		MP_Constants.LevelRestartTime = 2 * TICRATE;
		MP_Constants.ReviveTime = 4 * TICRATE;
		MP_Constants.RevivedHealth = 25;
		MP_Constants.RevivingDistance = 48;
	}

	void RandomizeGameOverMusic()
	{
		switch(Random(0, 7))
		{
		break; case 0: GameOverMusic = "Ascension - Game Over";
		break; case 1: GameOverMusic = "Der Riese - Game Over";
		break; case 2: GameOverMusic = "Verruckt - Game Over";
		break; case 3: GameOverMusic = "Shi No Numa - Game Over";
		break; case 4: GameOverMusic = "Nacht Der Untoten - Game Over"; 
		break; case 5: GameOverMusic = "Kino Der Toten - Game Over";
		break; case 6: GameOverMusic = "Shangri La - Game Over";
		break; case 7: GameOverMusic = "Die Rise - Game Over"; 
		}
	}

	override void PlayerEntered(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsActive = true; 
		MP_Players[e.PlayerNumber].IsAlive = true; 
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer  = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;
		MP_Players[e.PlayerNumber].SpawnPoint = players[e.PlayerNumber].mo.Pos;
		CheckGameOver();
	}

	override void PlayerDisconnected(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsActive = false; 
		MP_Players[e.PlayerNumber].IsAlive = false;
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;
		CheckGameOver();
	}

	override void PlayerRespawned(PlayerEvent e) 
	{
		MP_Players[e.PlayerNumber].IsAlive = true; 
		MP_Players[e.PlayerNumber].SpawnPoint = players[e.PlayerNumber].mo.Pos;
		CheckGameOver();
	}

	override void PlayerDied(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsAlive = false;
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;

		CheckGameOver();

		if (!InGameOver)
		{
			if (e.PlayerNumber != consoleplayer && CVar.GetCVar('snowy_mp__allow_reviving', players[consoleplayer]).GetBool())
			{
				Console.PrintfEx(PRINT_HIGH, "\cg%s is down.\c-", players[e.PlayerNumber].GetUserName());
			}
		}

		if (CVar.GetCVar('snowy_mp__drop_items_on_death', players[e.PlayerNumber]).GetBool())
		{
			PlayerInfo player = players[e.PlayerNumber];
			if (!player || !player.mo) return;
			PlayerPawn player_pawn = player.mo;
	
			bool drop_weapons = CVar.GetCVar('snowy_mp__death_drop_weapons', players[e.PlayerNumber]).GetBool();
			bool drop_ammo = CVar.GetCVar('snowy_mp__death_drop_ammo', players[e.PlayerNumber]).GetBool();
			bool drop_keys = CVar.GetCVar('snowy_mp__death_drop_keys', players[e.PlayerNumber]).GetBool();

			if (drop_weapons)
			{
				let item = player_pawn.FindInventory('Weapon', true);
				if (item) player_pawn.DropInventory(item);
			}
			if (drop_ammo)
			{
				let item = player_pawn.FindInventory('Ammo', true);
				if (item) player_pawn.DropInventory(item);
			}
			if (drop_keys)
			{
				let item = player_pawn.FindInventory('Key', true);
				if (item) player_pawn.DropInventory(item);
			}
		}
	}

	/* Tick */

	override void WorldTick()
	{
		CheckLevelRestart();
		CheckPlayerDeaths();
		CheckLoweredWeaponPlayers();
		CheckReviving();
		CheckSpectating();
		CheckRespawnDelays();
		CheckSafeSpots();
	}
	
	void CheckPlayerDeaths()
	{
		if (InGameOver) return;
		int respawn_delay_seconds = GetRespawnDelay();

		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (IsPlayerAlive(PlayerNumber)) continue;
			if (IsRespawningAllowed())
			{
				if (MP_Players[PlayerNumber].RespawnDelayTimer == -1 || PreviousRespawnDelay != respawn_delay_seconds)
					MP_Players[PlayerNumber].RespawnDelayTimer = respawn_delay_seconds * TICRATE;
			}
		}
		
		PreviousRespawnDelay = respawn_delay_seconds;
	}

	void CheckLoweredWeaponPlayers()
	{
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			PlayerInfo player = players[PlayerNumber];
			if (!player || !player.mo) continue;
			PlayerPawn player_pawn = player.mo;

			if (IsPlayerWeaponLowered(PlayerNumber))
			{
				if (player.PendingWeapon != WP_NOCHANGE || !(player.PendingWeapon is 'RevivingSyringe'))
				{
					if (player.ReadyWeapon is 'RevivingSyringe') player.PendingWeapon = WP_NOCHANGE;
					else player.PendingWeapon = Weapon(player_pawn.FindInventory('RevivingSyringe', true));
				}
			}
			else
			{
				if (!(player.ReadyWeapon is 'RevivingSyringe') && player_pawn.FindInventory('RevivingSyringe',  true))
					player_pawn.TakeInventory('RevivingSyringe', 999);
			}
		}
	}

	void CheckFrozenPlayers()
	{
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++) 
			if (IsPlayerFrozen(PlayerNumber)) players[PlayerNumber].mo.Vel.XY *= 0.8;
	}

	void CheckGameOver()
	{
		if (ActivePlayerCount() <= 0 || LevelRestarting) return;

		if (GetSnowyMPHandler().IsCooperativeGame())
		{
			if (!InGameOver && LivingPlayerCount() <= 0)
			{
				InGameOver = true;
				SendNetworkEvent("SnowyMP_GameOver");
			}
			else if (InGameOver && LivingPlayerCount() > 0)
			{
				InGameOver = false;
				SendNetworkEvent("SnowyMP_ResetGameOver");
				RandomizeGameOverMusic();
			}
		}
	}

	void CheckLevelRestart()
	{
		if (LevelRestarting)
		{
			if (RestartingTics > 0) RestartingTics--;
			else
			{
				int level_flags = CHANGELEVEL_NOINTERMISSION;
				if (sv_pistolstart) level_flags |= CHANGELEVEL_RESETINVENTORY;

				Level.ChangeLevel(Level.MapName, 0, level_flags, Skill);
			}
		}

		if (!LevelRestarting && PlayersReadyToRestartCount() >= ActivePlayerCount())
		{
			LevelRestarting = true;
			RestartingTics = MP_Constants.LevelRestartTime;
		}
	}

	void CheckRespawnDelays()
	{
		if (InGameOver) return;
		bool respawn_allowed = IsRespawningAllowed();

		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (!respawn_allowed)
			{
				CancelPlayerRespawnDelay(PlayerNumber);
				continue;
			}

			if (!IsPlayerActive(PlayerNumber) || !IsPlayerRespawning(PlayerNumber)) continue;

			if (IsPlayerAlive(PlayerNumber))
			{
				MP_Players[PlayerNumber].RespawnDelayTimer = -1;
				continue;	
			}

			if (GetPlayerRespawnTimer(PlayerNumber) > 0)
			{
				MP_Players[PlayerNumber].RespawnDelayTimer--;
			}
			
		}
	}

	void CheckReviving()
	{
		if (InGameOver) return;
		bool reviving_allowed = CVar.GetCVar('snowy_mp__allow_reviving', players[consoleplayer]).GetBool();
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (!reviving_allowed)
			{
				PlayerStopReviving(PlayerNumber);
				continue;
			}

			if (!IsPlayerActive(PlayerNumber)) continue;

			if (IsPlayerReviving(PlayerNumber))
			{
				if (GetPlayerRevivingTimer(PlayerNumber) < MP_Constants.ReviveTime) MP_Players[PlayerNumber].RevivingTimer++;
				else
				{
					SendNetworkEvent("SnowyMP_RevivePlayer", PlayerNumber, GetPlayerRevivingTarget(PlayerNumber));
				}
			}
		}
	}

	void CheckSpectating()
	{
		if (InGameOver) return;
		bool spectating_allowed = CVar.GetCVar('snowy_mp__allow_death_spectating', players[consoleplayer]).GetBool();
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (!spectating_allowed)
			{
				PlayerStopSpectating(PlayerNumber);
				continue;
			}

			if (!IsPlayerActive(PlayerNumber)) continue;
			PlayerInfo player = players[PlayerNumber];
			if (!player || !player.mo) continue;
			PlayerPawn player_pawn = player.mo;

			if (!IsPlayerSpectating(PlayerNumber))
			{
				player_pawn.SetCamera(player_pawn);
			}
			else
			{
				PlayerInfo observed_player = players[GetPlayerSpectatingTarget(PlayerNumber)];
				if (!observed_player || !observed_player.mo) continue;
				PlayerPawn observed_player_pawn = observed_player.mo;

				if (!MP_Players[PlayerNumber].SpectatingCamera) MP_Players[PlayerNumber].SpectatingCamera = Actor.Spawn('SpectatingCamera', player_pawn.Pos); 
				let spectating_camera = MP_Players[PlayerNumber].SpectatingCamera;
				if (!spectating_camera) continue;

				if (IsPlayerSpectatingFirstPerson(PlayerNumber))
				{
					player_pawn.SetCamera(observed_player_pawn);
				}
				else if (IsPlayerSpectatingThirdPerson(PlayerNumber))
				{
					vector2 rotated_vel = Actor.RotateVector(observed_player_pawn.Vel.XY, observed_player_pawn.Angle);

					if (rotated_vel.Y < 0) MP_Players[PlayerNumber].SpectatingOffset.Y += 1;
					else MP_Players[PlayerNumber].SpectatingOffset.Y -= 1;

					if (rotated_vel.X > 0) MP_Players[PlayerNumber].SpectatingOffset.X  += 1;
					else MP_Players[PlayerNumber].SpectatingOffset.X -= 1;

					if (observed_player_pawn.Vel.Z < 0) MP_Players[PlayerNumber].SpectatingOffset.Z  += 1;
					else MP_Players[PlayerNumber].SpectatingOffset.Z -= 1;
					
					MP_Players[PlayerNumber].SpectatingOffset.X = clamp(MP_Players[PlayerNumber].SpectatingOffset.X, -12, 12);
					MP_Players[PlayerNumber].SpectatingOffset.Y = clamp(MP_Players[PlayerNumber].SpectatingOffset.Y, -12, 12);
					MP_Players[PlayerNumber].SpectatingOffset.Z = clamp(MP_Players[PlayerNumber].SpectatingOffset.Z, 0, 12);

					player_pawn.SetCamera(spectating_camera);
					spectating_camera.Warp(
						observed_player_pawn,
						(-80 * cos(observed_player_pawn.Pitch)) + MP_Players[PlayerNumber].SpectatingOffset.X,
						MP_Players[PlayerNumber].SpectatingOffset.Y,
						((observed_player_pawn.Height * 0.75) + 80 * sin(observed_player_pawn.Pitch)) + MP_Players[PlayerNumber].SpectatingOffset.Z,
						0,
						WARPF_NOCHECKPOSITION | WARPF_COPYPITCH | WARPF_INTERPOLATE
					);
				}
			}
		}
		
	}

	void CheckSafeSpots()
	{
		if (InGameOver) return;

		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (!IsPlayerActive(PlayerNumber)) continue;

			if (!IsPlayerFalling(PlayerNumber) && !IsPlayerOnDamagingFloor(PlayerNumber))
			{
				MP_Players[PlayerNumber].SafeSpot = players[PlayerNumber].mo.Pos;
			}
		}
	}


	override bool InputProcess(InputEvent e)
	{
		/*
		if (!GetSnowyMPHandler().IsMultiplayerGame())
			return false;
 		*/
		let binding = Bindings.GetBinding(e.KeyScan);

		if (CVar.GetCVar('snowy_mp__allow_death_spectating', players[consoleplayer]).GetBool() && !IsPlayerAlive(consoleplayer))
		{
			if (binding ~== "changeSpectatingMode")
			{
				if (e.Type == InputEvent.Type_KeyDown) SendNetworkEvent("SnowyMP_ChangeSpectatingMode");
				return true;
			}
			if (binding ~== "spectatePreviousPlayer")
			{
				if (e.Type == InputEvent.Type_KeyDown) SendNetworkEvent("SnowyMP_SpectatePreviousPlayer");
				return true;
			}
			if (binding ~== "spectateNextPlayer")
			{
				if (e.Type == InputEvent.Type_KeyDown) SendNetworkEvent("SnowyMP_SpectateNextPlayer");
				return true;
			}
		}

		if (binding ~== "+use")
		{
			if (InGameOver && e.Type == InputEvent.Type_KeyDown && binding ~== "+use")
			{
				SendNetworkEvent("SnowyMP_ReadyToRestart");
				return true;
			}

			if (!IsPlayerAlive(consoleplayer))
			{
				if (IsPlayerAllowedToRespawn(consoleplayer) && e.Type == InputEvent.Type_KeyDown)
				{
					SendNetworkEvent("SnowyMP_RespawnPlayer");
					return true;
				}
				
				if (
					e.Type == InputEvent.Type_KeyDown && 
					!IsPlayerFalling(consoleplayer) && IsPlayerOnDamagingFloor(consoleplayer) && 
					CVar.GetCVar('snowy_mp__allow_return_to_spawn_after_damaging_floor_death', players[consoleplayer]).GetBool()
				)
				{
					SendNetworkEvent("SnowyMP_TeleportPlayerToStart");
					return true;
				}
				
				return true;
			}

			if (CVar.GetCVar('snowy_mp__allow_reviving', players[consoleplayer]).GetBool())
			{
				if (CanReviveNearby(consoleplayer) && e.Type == InputEvent.Type_KeyDown)
				{
					SendNetworkEvent("SnowyMP_ReviveStart"); 
					return true;
				}

				if (IsPlayerReviving(consoleplayer) && e.Type == InputEvent.Type_KeyUp)
				{
					SendNetworkEvent("SnowyMP_ReviveStop");
					return true;
				}
			}
		}

		if (IsPlayerReviving(consoleplayer))
		{
			// Absorb the input
			if (binding ~== "+attack" || binding ~== "+altattack")
				return true;
		}

		return false;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name ~== "SnowyMP_ReadyToRestart")
		{
			ReadyToRestart(e.Player);
		}
		else if (e.Name ~== "SnowyMP_GameOver")
		{
			DoGameOver(e.Player);
		}
		else if (e.Name ~== "SnowyMP_ResetGameOver")
		{
			ResetGameOver(e.Player);
		}
		else if (e.Name ~== "SnowyMP_ReviveStart")
		{
			PlayerTryReviveNearestPlayer(e.Player);
		}
		else if (e.Name ~== "SnowyMP_ReviveStop")
		{
			PlayerStopReviving(e.Player);
		}
		else if (e.Name ~== "SnowyMP_RevivePlayer")
		{
			RevivePlayer(e.Args[0], e.Args[1]);
		}
		else if (e.Name ~== "SnowyMP_ChangeSpectatingMode")
		{
			PlayerChangeSpectatingMode(e.Player);
		}
		else if (e.Name ~== "SnowyMP_SpectatePreviousPlayer")
		{
			PlayerSpectatePreviousPlayer(e.Player);
		}
		else if (e.Name ~== "SnowyMP_SpectateNextPlayer")
		{
			PlayerSpectateNextPlayer(e.Player);
		}
		else if (e.Name ~== "SnowyMP_RespawnPlayer")
		{
			RespawnPlayer(e.Player);
		}
		else if (e.Name ~== "SnowyMP_TeleportPlayerToStart")
		{
			TeleportToPlayerStart(e.Player);
		}
	}

	// Player Inputs

	void TeleportToPlayerStart(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;

		player.mo.SetOrigin(MP_Players[PlayerNumber].SafeSpot, true);

		Console.PrintF("ass");
	}

	/* Spectating */

	void PlayerChangeSpectatingMode(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || IsPlayerAlive(PlayerNumber)) return;
		MP_Players[PlayerNumber].SpectatingMode = (MP_Players[PlayerNumber].SpectatingMode + 1) % 2;
	}

	void PlayerSpectateNextPlayer(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || IsPlayerAlive(PlayerNumber)) return;

		int OtherPlayerNumber = GetPlayerSpectatingTarget(PlayerNumber);
		do
		{
			OtherPlayerNumber = (OtherPlayerNumber + 1) % MAXPLAYERS;
			if (CanPlayerSpectateOther(PlayerNumber, OtherPlayerNumber))
			{
				PlayerSpectateOther(PlayerNumber, OtherPlayerNumber);
				return;
			}
		}
		while(OtherPlayerNumber != GetPlayerSpectatingTarget(PlayerNumber))
	}

	void PlayerSpectatePreviousPlayer(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || IsPlayerAlive(PlayerNumber)) return;

		int OtherPlayerNumber = GetPlayerSpectatingTarget(PlayerNumber);
		do
		{
			OtherPlayerNumber--;
			if (OtherPlayerNumber < 0) OtherPlayerNumber = MAXPLAYERS - 1;

			if (CanPlayerSpectateOther(PlayerNumber, OtherPlayerNumber))
			{
				PlayerSpectateOther(PlayerNumber, OtherPlayerNumber);
				return;
			}
		}
		while(OtherPlayerNumber != GetPlayerSpectatingTarget(PlayerNumber))
	}


	void PlayerSpectateOther(int PlayerNumber, int OtherPlayerNumber)
	{
		MP_Players[PlayerNumber].SpectatingTarget = OtherPlayerNumber;
		if (!MP_Players[PlayerNumber].SpectatingCamera) MP_Players[PlayerNumber].SpectatingCamera = Actor.Spawn('SpectatingCamera');
		
		if (PlayerNumber != consoleplayer) return;

		if (OtherPlayerNumber == PlayerNumber) 
		{
			string pronoun;
			switch(players[PlayerNumber].GetGender())
			{
			break;case 0: pronoun = "himself";
			break;case 1: pronoun = "herself";
			break;case 2: pronoun = "themself";
			break;case 3: pronoun = "itself";
			}

			Console.Printf("%s is now spectating %s", players[PlayerNumber].GetUserName(), pronoun);
		}
		else Console.Printf("%s is now spectating %s", players[PlayerNumber].GetUserName(), players[OtherPlayerNumber].GetUserName());
	}

	/* Reviving */

	void RevivePlayer(int RevivingPlayerNumber, int DownedPlayerNumber)
	{
		if (!IsPlayerActive(RevivingPlayerNumber) || !IsPlayerReviving(RevivingPlayerNumber)) return;
		if (!IsPlayerActive(DownedPlayerNumber) || IsPlayerAlive(DownedPlayerNumber))
		{
			PlayerStopReviving(RevivingPlayerNumber);
			return;
		}

		PlayerInfo reviving_player = players[RevivingPlayerNumber];
		if (!reviving_player) return;
		
		PlayerInfo downed_player = players[DownedPlayerNumber];
		if (!downed_player)
		{
			PlayerStopReviving(RevivingPlayerNumber);
			return;
		}

		downed_player.Resurrect();
		downed_player.mo.A_Pain();
		downed_player.mo.A_SetHealth(MP_Constants.RevivedHealth);
		
		MP_Players[RevivingPlayerNumber].RevivingTarget = -1;
		MP_Players[RevivingPlayerNumber].RevivingTimer = 0;
		
		UnfreezePlayer(RevivingPlayerNumber);
		RaisePlayerWeapon(RevivingPlayerNumber);
		PlayerStopSpectating(DownedPlayerNumber);

		Console.PrintfEx(PRINT_MEDIUM, "%s has revived %s.", reviving_player.GetUserName(), downed_player.GetUserName());
	}

	void CancelPlayerRespawnDelay(int PlayerNumber)
	{
		MP_Players[PlayerNumber].RespawnDelayTimer = -1;
	}

	void RespawnPlayer(int PlayerNumber)
	{
		if (IsPlayerAlive(PlayerNumber)) return;
		
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		PlayerPawn player_pawn = player.mo;

		PlayerStopSpectating(PlayerNumber);
		CancelPlayerRespawnDelay(PlayerNumber);

		Console.PrintfEx(PRINT_LOW, "%s has respawned.", player.GetUserName());

		player.Resurrect();
		player_pawn.A_Pain();
		player_pawn.A_SetHealth(MP_Constants.RevivedHealth);

		let reviving_player = GetPlayerRevivingThisPlayer(PlayerNumber);
		if (reviving_player != -1) 
		{
			MP_Players[reviving_player].RevivingTarget = -1;
			MP_Players[reviving_player].RevivingTimer = 0;
			
			UnfreezePlayer(reviving_player);
			RaisePlayerWeapon(reviving_player);
			PlayerStopSpectating(reviving_player);
		}
	}

	clearscope int FindNearbyDownedPlayer(int PlayerNumber) const
	{
		if (!IsPlayerActive(PlayerNumber) || !IsPlayerAlive(PlayerNumber)) return -1;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return -1;

		for (int OtherPlayerNumber = 0; OtherPlayerNumber < MAXPLAYERS; OtherPlayerNumber++)
		{
			if (PlayerNumber == OtherPlayerNumber) continue;
			if (!IsPlayerActive(OtherPlayerNumber) || IsPlayerAlive(OtherPlayerNumber)) continue;

			PlayerInfo other_player = players[OtherPlayerNumber];
			if (!other_player || !other_player.mo) continue;

			//if (!GetSnowyMPHandler().IsCooperativeGame() && !player.mo.IsTeammate(other_player.mo)) continue;
			if (!player.mo.IsTeammate(other_player.mo)) continue;

			double distance_to = Level.Vec3Diff(player.mo.Pos, other_player.mo.Pos).Length();
			if (distance_to > MP_Constants.RevivingDistance) continue; // Too far away

			return OtherPlayerNumber;
		}

		return -1;
	}
	
	clearscope bool CanReviveNearby(int PlayerNumber) const
	{
		return FindNearbyDownedPlayer(PlayerNumber) != -1;
	}

	void PlayerTryReviveNearestPlayer(int PlayerNumber)
	{
		int DownedPlayerNumber = FindNearbyDownedPlayer(PlayerNumber);
		if (DownedPlayerNumber != -1) PlayerStartRevivingPlayer(PlayerNumber, DownedPlayerNumber);
	}
	
	void PlayerStartRevivingPlayer(int RevivingPlayerNumber, int DownedPlayerNumber)
	{
		PlayerInfo reviving_player = players[RevivingPlayerNumber];
		PlayerInfo downed_player = players[DownedPlayerNumber];

		Console.PrintfEx(PRINT_MEDIUM, "%s is reviving %s.", reviving_player.GetUserName(), downed_player.GetUserName());

		MP_Players[RevivingPlayerNumber].RevivingTarget = DownedPlayerNumber;
		MP_Players[RevivingPlayerNumber].RevivingTimer = 0;

		FreezePlayer(RevivingPlayerNumber);
		LowerPlayerWeapon(RevivingPlayerNumber);
		PlayerStopSpectating(DownedPlayerNumber);
	}

	void PlayerStopReviving(int PlayerNumber)
	{
		if (!IsPlayerReviving(PlayerNumber)) return;

		PlayerInfo player = Players[PlayerNumber];
		if (!player || !player.mo) return;

		PlayerInfo downed_player = players[GetPlayerRevivingTarget(PlayerNumber)];

		if (downed_player) Console.PrintfEx(PRINT_MEDIUM, "%s doesn't finish reviving %s.", player.GetUserName(), downed_player.GetUserName());
		else Console.PrintfEx(PRINT_MEDIUM, "%s doesn't finish reviving.", player.GetUserName()); 

		MP_Players[PlayerNumber].RevivingTarget = -1;
		MP_Players[PlayerNumber].RevivingTimer = 0;

		UnfreezePlayer(PlayerNumber);
		RaisePlayerWeapon(PlayerNumber);
	}

	void DoGameOver(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || IsPlayerOnGameOver(PlayerNumber)) return;
		MP_Players[PlayerNumber].OnGameOverScreen = true;
		PlayerStopSpectating(PlayerNumber);
		CancelPlayerRespawnDelay(PlayerNumber);
		PlayerStopReviving(PlayerNumber);

		// Play game over music
		if (!PlayerNumber == consoleplayer) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		PlayerPawn player_pawn = player.mo;

		if (CVar.GetCVar('snowy_mp__cod_zombies_game_overs', player).GetBool())
		{
			player_pawn.S_ChangeMusic(GameOverMusic);
		}
	}

	void ResetGameOver(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || !IsPlayerOnGameOver(PlayerNumber)) return;
		MP_Players[PlayerNumber].OnGameOverScreen = false;
	}

	clearscope string GetKeyBindsString(string cmd) const
	{
		string keybind_string;
		array<int> key_inputs;
		bindings.GetAllKeysForCommand(key_inputs, cmd);
		keybind_string = bindings.NameAllKeys(key_inputs);
		return keybind_string;
	}

	override void RenderOverlay(RenderEvent e)
	{
		string use_keybind =  GetKeyBindsString("+use");
		string spectate_mode_keybind = GetKeyBindsString("changeSpectatingMode");
		string spectate_prev_keybind = GetKeyBindsString("spectatePreviousPlayer");
		string spectate_next_keybind = GetKeyBindsString("spectateNextPlayer");

		StatusBar.BeginHUD();
		HUDFont big_hud_font = HUDFont.Create(bigfont);
		HUDFont small_hud_font = HUDFont.Create(smallfont);

		double y_offset_center = 12;

		// Render game over text
		if (IsPlayerOnGameOver(consoleplayer))
		{
			StatusBar.DrawString(
				big_hud_font, "Game Over", (0, -72), 
				StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
				translation: Font.FindFontColor("Red")
			);

			// Render players ready to restart
			for (int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
			{
				if (IsPlayerReadyToRestart(PlayerNumber))
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("%s is ready to restart.", players[PlayerNumber].GetUserName()), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);

					y_offset_center += small_hud_font.mFont.GetHeight();
				}
			}

			if (LevelRestarting)
			{
				StatusBar.DrawString(
					small_hud_font, 
					"Restarting...", 
					(0, y_offset_center + small_hud_font.mFont.GetHeight()), 
					StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
					translation: Font.FindFontColor("Red")
				);
			}
		}
		else
		{
			// Render reviving text
			if (CVar.GetCVar('snowy_mp__allow_reviving', players[consoleplayer]).GetBool())
			{
				if (IsPlayerReviving(consoleplayer))
				{
					double CurrentReviveTime = MP_Players[consoleplayer].RevivingTimer;
					double MaxReviveTime = MP_Constants.ReviveTime;

					double countdown_timer = double(MaxReviveTime - CurrentReviveTime) / double(TICRATE);

					StatusBar.DrawString(
						small_hud_font, 
						String.Format(
							"Reviving %s", 
							players[GetPlayerRevivingTarget(consoleplayer)].GetUserName()
						), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);

					y_offset_center += small_hud_font.mFont.GetHeight();

					StatusBar.DrawBar(
						"graphics/hp_bar_fg.png",
						"graphics/hp_bar_bg.png",
						CurrentReviveTime, MaxReviveTime, 
						(0, y_offset_center), 0, 
						StatusBar.SHADER_HORZ, 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_ITEM_CENTER | StatusBar.DI_ITEM_TOP,
						0.8
					);

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
				else if (IsPlayerBeingRevived(consoleplayer))
				{
					double CurrentReviveTime = MP_Players[GetPlayerRevivingThisPlayer(consoleplayer)].RevivingTimer;
					double MaxReviveTime = MP_Constants.ReviveTime;

					double countdown_timer = double(MaxReviveTime - CurrentReviveTime) / double(TICRATE);

					StatusBar.DrawString(
						small_hud_font, 
						String.Format(
							"Being revived by %s", 
							players[GetPlayerRevivingThisPlayer(consoleplayer)].GetUserName()
						), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);

					y_offset_center += small_hud_font.mFont.GetHeight();

					StatusBar.DrawBar(
						"graphics/hp_bar_fg.png",
						"graphics/hp_bar_bg.png",
						CurrentReviveTime, MaxReviveTime, 
						(0, y_offset_center), 0, 
						StatusBar.SHADER_HORZ, 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_ITEM_CENTER | StatusBar.DI_ITEM_TOP,
						0.8
					);

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
				else if (CanReviveNearby(consoleplayer))
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("Press %s to revive.", use_keybind), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
			}

			//Render respawning text
			if (IsPlayerRespawning(consoleplayer))
			{
				int respawn_delay = GetPlayerRespawnTimer(consoleplayer);
				if (respawn_delay > 0)
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("You can respawn in %i seconds.", int(double(respawn_delay) / TICRATE)), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);
				}
				else
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("Press %s to respawn.", use_keybind), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);
				}

				y_offset_center += small_hud_font.mFont.GetHeight();
			}
			else if (!IsPlayerAlive(consoleplayer) && !IsPlayerSpectating(consoleplayer))
			{
				StatusBar.DrawString(
					small_hud_font, 
					String.Format("You are dead.", use_keybind), 
					(0, y_offset_center), 
					StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
					translation: Font.FindFontColor("Red")
				);
				y_offset_center += small_hud_font.mFont.GetHeight();
			}

			//Render spectating text
			if (CVar.GetCVar('snowy_mp__allow_death_spectating', players[consoleplayer]).GetBool())
			{
				if (IsPlayerSpectating(consoleplayer))
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format(
							"Spectating %s", 
							players[GetPlayerSpectatingTarget(consoleplayer)].GetUserName()
						), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("White")
					);

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
				else if (!IsPlayerAlive(consoleplayer) && ActivePlayerCount() > 0)
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("Press \"%s\" or \"%s\" to spectate others.", spectate_next_keybind, spectate_prev_keybind), 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("White")
					);

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
			}
		}
	}
}