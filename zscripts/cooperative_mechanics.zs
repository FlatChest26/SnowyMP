struct SnowyMP_Constants
{
	int LevelRestartTime; 						// How long it takes for the level to restart after all players are ready
	
	int ValidSafeSpotTics;						// Tics required for a spot to be considered "safe"
	int SpectateModeKeybindDisplayMaxTics;		// Tics the "Press P to change Spectating Mode" message will appear
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

	transient bool ReadyToRestart; 		// Whether this player is ready to restart the level

	int SafeTics;			// How many tics the player has been "safe" for
	vector3 SpawnPoint;		// The player's spawn point
	double SpawnAngle;		// Angle player was facing at their spawn

	vector3 SafeSpot;		// Last safe spot where a player can be warped
	double SafeAngle;		// Angle player was facing at the last safe spot

	transient int SpectateModeKeybindDisplayTics;	// How long the "Press P to change Spectating Mode" message has been displayed.

	int BleedOutTics;		// Time this player has spent bleeding out

	int ReviveCount;		// Number of times this player has been revived.
	int RespawnCount;		// Number of times this player has respawned.
	int SafeWarpCount;		// Number of times this player has warpped to a safe spot.

	int DownCount;			// Number of times this player has gone down.
	int BleedOutCount;		// Number of times this player has bled out.
}

class SnowyMPGameplayChanges : EventHandler
{
	// Variables 

	SnowyMP_Constants MP_Constants;
	private SnowyMP_PlayerInfo MP_Players[MAXPLAYERS];

	/* Game Over */
	bool InGameOver; // Whether the game has ended because all players have died
	string GameOverMusic;

	/* Level Restart */
	transient bool LevelRestarting; // Whether to restart the level
	transient int RestartingTics; // Time until restart

	transient int PreviousRespawnDelay;

	// Methods //

	void RandomizeGameOverMusic()
	{
		switch(Random(0, 8))
		{
		break; case 0: GameOverMusic = "Ascension - Game Over";
		break; case 1: GameOverMusic = "Der Riese - Game Over";
		break; case 2: GameOverMusic = "Verruckt - Game Over";
		break; case 3: GameOverMusic = "Shi No Numa - Game Over";
		break; case 4: GameOverMusic = "Nacht Der Untoten - Game Over"; 
		break; case 5: GameOverMusic = "Kino Der Toten - Game Over";
		break; case 6: GameOverMusic = "Shangri La - Game Over";
		break; case 7: GameOverMusic = "Die Rise - Game Over"; 
		break; case 8: GameOverMusic = "Moon - Game Over"; 
		}
	}

	/* Getters */
	clearscope SnowyMPHandler GetSnowyMPHandler() const { return SnowyMPHandler(StaticEventHandler.Find('SnowyMPHandler')); }

	clearscope bool IsRespawningAllowed() const  { return CVar.GetCVar('snowy_mp__delay_before_respawn', players[consoleplayer]).GetInt() != -1 && !MaxRespawnCount() == 0; }
	clearscope int GetRespawnDelay() const { return CVar.GetCVar('snowy_mp__delay_before_respawn', players[consoleplayer]).GetInt(); }

	clearscope bool IsRevivingAllowed() const { return CVar.GetCVar('snowy_mp__allow_reviving', players[consoleplayer]).GetBool() && !MaxReviveCount() == 0; }

	clearscope bool IsSpectatingAllowed() const { return CVar.GetCVar('snowy_mp__allow_death_spectating', players[consoleplayer]).GetBool(); }

	clearscope bool NeverIrrecoverableBodies() const { return CVar.GetCVar('snowy_mp__irrecoverable_bodies', players[consoleplayer]).GetInt() == 0; }
	clearscope bool OptionallyIrrecoverableBodies() const { return CVar.GetCVar('snowy_mp__irrecoverable_bodies', players[consoleplayer]).GetInt() == 1; }
	clearscope bool AlwaysIrrecoverableBodies() const { return CVar.GetCVar('snowy_mp__irrecoverable_bodies', players[consoleplayer]).GetInt() == 2; }
	
	clearscope bool IsBleedOutAllowed() const { return CVar.GetCVar('snowy_mp__bleed_out_timer', players[consoleplayer]).GetInt() != -1; }
	clearscope int GetBleedOutTime() const { return CVar.GetCVar('snowy_mp__bleed_out_timer', players[consoleplayer]).GetInt() * TICRATE; }

	clearscope bool KeepWeaponWhileReviving() const { return CVar.GetCVar('snowy_mp__keep_weapon_while_reviving', players[consoleplayer]).GetBool(); }
	clearscope bool CanMoveWhileReviving() const { return CVar.GetCVar('snowy_mp__move_while_reviving', players[consoleplayer]).GetBool(); }

	clearscope bool InfiniteRevives() const { return CVar.GetCVar('snowy_mp__max_revive_count', players[consoleplayer]).GetInt() == -1; }
	clearscope int MaxReviveCount() const { return CVar.GetCVar('snowy_mp__max_revive_count', players[consoleplayer]).GetInt(); }

	clearscope bool AllowRespawnBeforeGameOver() const { return CVar.GetCVar('snowy_mp__allow_respawns_after_game_over', players[consoleplayer]).GetInt(); }

	clearscope bool InfiniteRespawns() const { return CVar.GetCVar('snowy_mp__max_respawn_count', players[consoleplayer]).GetInt() == -1; }
	clearscope int MaxRespawnCount() const { return CVar.GetCVar('snowy_mp__max_respawn_count', players[consoleplayer]).GetInt(); }

	clearscope bool RespawnInPlace() const { return CVar.GetCVar('snowy_mp__respawn_where_death_occured', players[consoleplayer]).GetBool(); }

	clearscope int RespawnedHealth() const { return CVar.GetCVar('snowy_mp__respawned_health', players[consoleplayer]).GetInt(); }

	clearscope int RevivedHealth() const { return CVar.GetCVar('snowy_mp__revived_health', players[consoleplayer]).GetInt(); }
	clearscope int ReviveTime() const { return CVar.GetCVar('snowy_mp__revive_delay', players[consoleplayer]).GetInt() * TICRATE; }
	clearscope int RevivingDistance() const { return CVar.GetCVar('snowy_mp__reviving_distance', players[consoleplayer]).GetInt(); }

	clearscope bool AllowMessages() const { return CVar.GetCVar('snowy_mp__allow_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowSpectatingMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__spectating_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowWarpingMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__warp_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowRespawningMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__respawn_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowRevivingMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__revive_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowDownedMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__downed_messages', players[consoleplayer]).GetBool(); }
	clearscope bool AllowBleedOutMessages() const { return AllowMessages() && CVar.GetCVar('snowy_mp__bleed_out_messages', players[consoleplayer]).GetBool(); }

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

	clearscope bool CanRespawnHappenAfterGameOver() const
	{
		if (!IsRespawningAllowed() || !AllowRespawnBeforeGameOver())
			return false;
		
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++) 
			if (IsPlayerActive(PlayerNumber) && (IsPlayerAlive(PlayerNumber) || PlayerHasRespawnsLeft(PlayerNumber)))
				return true;
			
		return false;
	}

	clearscope bool DropItemsOnDeath() const { return CVar.GetCVar('snowy_mp__drop_items_on_death', players[consoleplayer]).GetBool(); }
	clearscope bool DropItemsOnDeathAfterGameOver() const { return CVar.GetCVar('snowy_mp__drop_items_during_game_over', players[consoleplayer]).GetBool(); }
	clearscope bool DropWeaponsOnDeath() const { return DropItemsOnDeath() && CVar.GetCVar('snowy_mp__death_drop_weapons', players[consoleplayer]).GetBool(); }
	clearscope bool DropAmmoOnDeath() const { return DropItemsOnDeath() && CVar.GetCVar('snowy_mp__death_drop_ammo', players[consoleplayer]).GetBool(); }
	clearscope bool DropKeyItemsOnDeath() const { return DropItemsOnDeath() && CVar.GetCVar('snowy_mp__death_drop_keys', players[consoleplayer]).GetBool(); }

	/* Player Getters */

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
	
	clearscope bool PlayerHasRespawnsLeft(int PlayerNumber) const { return InfiniteRespawns() || GetPlayerRespawnCount(PlayerNumber) < MaxRespawnCount(); }
	clearscope bool PlayerHasRevivesLeft(int PlayerNumber) const { return InfiniteRevives() || GetPlayerReviveCount(PlayerNumber) < MaxReviveCount(); }

	clearscope bool IsPlayerReadyToRestart(int PlayerNumber) const { return MP_Players[PlayerNumber].ReadyToRestart; }
	
	clearscope bool IsPlayerSpectating(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingTarget != PlayerNumber; }
	clearscope bool IsPlayerSpectatingFirstPerson(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingMode == SnowyMP_PlayerInfo.SM_FirstPerson; }
	clearscope bool IsPlayerSpectatingThirdPerson(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingMode == SnowyMP_PlayerInfo.SM_ThirdPerson; }
	clearscope int GetPlayerSpectatingTarget(int PlayerNumber) const { return MP_Players[PlayerNumber].SpectatingTarget; }
	
	clearscope bool HasPlayerBledOut(int PlayerNumber) const { return MP_Players[PlayerNumber].BleedOutTics >= GetBleedOutTime(); }
	clearscope bool HasPlayerJustBledOut(int PlayerNumber) const { return MP_Players[PlayerNumber].BleedOutTics == GetBleedOutTime(); }

	clearscope int GetPlayerReviveCount(int PlayerNumber) const { return MP_Players[PlayerNumber].ReviveCount; }
	clearscope int GetPlayerRespawnCount(int PlayerNumber) const { return MP_Players[PlayerNumber].RespawnCount; }
	clearscope int GetPlayerDownCount(int PlayerNumber) const { return MP_Players[PlayerNumber].DownCount; }
	clearscope int GetPlayerBleedOutCount(int PlayerNumber) const { return MP_Players[PlayerNumber].BleedOutCount; }
	

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

	clearscope bool IsPlayerInCrusher(int PlayerNumber)
	{
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return false;
		
		if (player.mo.CurSector.ceilingdata)
			return true;

		if (player.mo.CurSector.floordata)
			return true;
		
		let [ceiling_height, ceiling_sec] = player.mo.CurSector.HighestCeilingAt(player.mo.Pos.XY);
		let [floor_height, floor_sec] = player.mo.CurSector.LowestFloorAt(player.mo.Pos.XY);

		if (ceiling_height - floor_height <= player.mo.Height)
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

	clearscope bool IsPlayerInSafeSpot(int PlayerNumber)
	{
		return !IsPlayerOnDamagingFloor(PlayerNumber) && !IsPlayerInCrusher(PlayerNumber);
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
		MP_Constants.ValidSafeSpotTics = 1 * TICRATE;
		MP_Constants.SpectateModeKeybindDisplayMaxTics = 4 * TICRATE;
	}

	override void PlayerEntered(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsActive = true; 
		MP_Players[e.PlayerNumber].IsAlive = true; 
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer  = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;

		MP_Players[e.PlayerNumber].SpawnPoint = players[e.PlayerNumber].mo.Pos;
		MP_Players[e.PlayerNumber].SpawnAngle = players[e.PlayerNumber].mo.Angle;
		MP_Players[e.PlayerNumber].SafeSpot = players[e.PlayerNumber].mo.Pos;
		MP_Players[e.PlayerNumber].SafeAngle = players[e.PlayerNumber].mo.Angle;

		MP_Players[e.PlayerNumber].ReviveCount = 0; 
		MP_Players[e.PlayerNumber].RespawnCount = 0; 
		MP_Players[e.PlayerNumber].DownCount = 0; 
		MP_Players[e.PlayerNumber].BleedOutCount = 0; 
		CheckGameOver();
	}

	override void PlayerDisconnected(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsActive = false; 
		MP_Players[e.PlayerNumber].IsAlive = false;
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;
		MP_Players[e.PlayerNumber].ReviveCount = 0; 
		MP_Players[e.PlayerNumber].RespawnCount = 0; 
		MP_Players[e.PlayerNumber].DownCount = 0; 
		MP_Players[e.PlayerNumber].BleedOutCount = 0; 
		CheckGameOver();
	}

	override void PlayerRespawned(PlayerEvent e) 
	{
		MP_Players[e.PlayerNumber].IsAlive = true; 
		MP_Players[e.PlayerNumber].SpawnPoint = players[e.PlayerNumber].mo.Pos;
		MP_Players[e.PlayerNumber].SpawnAngle = players[e.PlayerNumber].mo.Angle;
		CheckGameOver();
	}

	override void PlayerDied(PlayerEvent e)
	{
		MP_Players[e.PlayerNumber].IsAlive = false;
		MP_Players[e.PlayerNumber].RevivingTarget = -1;
		MP_Players[e.PlayerNumber].RevivingTimer = 0;
		MP_Players[e.PlayerNumber].RespawnDelayTimer = -1;
		MP_Players[e.PlayerNumber].DownCount++;

		CheckGameOver();

		if (e.PlayerNumber != consoleplayer && IsRevivingAllowed())
		{
			if (AllowDownedMessages()) 
				Console.PrintfEx(PRINT_HIGH, "\cg%s is down.\c-", players[e.PlayerNumber].GetUserName());
		}

		if (InGameOver && !DropItemsOnDeathAfterGameOver()) 
			return;
		
		DropPlayerItemsOnDeath(e.PlayerNumber);
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
		CheckBleedOut();
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
				if (KeepWeaponWhileReviving())
				{
					RaisePlayerWeapon(PlayerNumber);
				}
				else
				{
					if (player.PendingWeapon != WP_NOCHANGE || !(player.PendingWeapon is 'RevivingSyringe'))
					{
						if (player.ReadyWeapon is 'RevivingSyringe') player.PendingWeapon = WP_NOCHANGE;
						else player.PendingWeapon = Weapon(player_pawn.FindInventory('RevivingSyringe', true));
					}
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
		{
			if (IsPlayerFrozen(PlayerNumber))
			{
				if (CanMoveWhileReviving())
					UnfreezePlayer(PlayerNumber);
				else
					players[PlayerNumber].mo.Vel.XY *= 0.8; 
			}
		}
	}

	void CheckGameOver()
	{
		if (ActivePlayerCount() < 1 || LevelRestarting) return;
		
		if (!InGameOver && LivingPlayerCount() < 1 && !CanRespawnHappenAfterGameOver())
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
			if (!respawn_allowed || !PlayerHasRespawnsLeft(PlayerNumber))
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
		bool reviving_allowed = IsRevivingAllowed();
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
				if (GetPlayerRevivingTimer(PlayerNumber) < ReviveTime()) MP_Players[PlayerNumber].RevivingTimer++;
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
		bool spectating_allowed = IsSpectatingAllowed();
		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (IsPlayerActive(PlayerNumber) && IsPlayerSpectating(PlayerNumber))
				MP_Players[PlayerNumber].SpectateModeKeybindDisplayTics++;
			else 
				MP_Players[PlayerNumber].SpectateModeKeybindDisplayTics = 0;

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
			
			if (IsPlayerAlive(PlayerNumber) && !IsPlayerFalling(PlayerNumber) && IsPlayerInSafeSpot(PlayerNumber))
			{
				MP_Players[PlayerNumber].SafeTics++;
				if (MP_Players[PlayerNumber].SafeTics >= MP_Constants.ValidSafeSpotTics)
				{
					MP_Players[PlayerNumber].SafeSpot = players[PlayerNumber].mo.Pos;
					MP_Players[PlayerNumber].SafeAngle = players[PlayerNumber].mo.Angle;
					MP_Players[PlayerNumber].SafeTics = 0;
				}
			}
			else
			{
				MP_Players[PlayerNumber].SafeTics = 0;
			}

			if (NeverIrrecoverableBodies() && !IsPlayerAlive(PlayerNumber) && !IsPlayerInSafeSpot(PlayerNumber))
			{
				WarpPlayerToSafeSpot(PlayerNumber);
			}
		}
	}


	void CheckBleedOut()
	{
		if (InGameOver) return;

		bool bleed_out_allowed = IsBleedOutAllowed();
		bool reviving_allowed = IsRevivingAllowed();

		for(int PlayerNumber = 0; PlayerNumber < MAXPLAYERS; PlayerNumber++)
		{
			if (!bleed_out_allowed || !reviving_allowed)
			{
				MP_Players[PlayerNumber].BleedOutTics = 0;
				continue;
			}

			if (!IsPlayerActive(PlayerNumber)) continue;

			if (!IsPlayerAlive(PlayerNumber) && !IsPlayerBeingRevived(PlayerNumber))
			{
				MP_Players[PlayerNumber].BleedOutTics++;

				if (HasPlayerJustBledOut(PlayerNumber))
					PlayerBleedOut(PlayerNumber);
			}
			else
			{
				MP_Players[PlayerNumber].BleedOutTics = 0;
			}
		}
	}


	override bool InputProcess(InputEvent e)
	{
		let binding = Bindings.GetBinding(e.KeyScan);
		bool key_down = e.Type == InputEvent.Type_KeyDown;
		bool key_up = e.Type == InputEvent.Type_KeyUp;

		if (IsSpectatingAllowed() && !IsPlayerAlive(consoleplayer))
		{
			if (binding ~== "changeSpectatingMode")
			{
				if (key_down) SendNetworkEvent("SnowyMP_ChangeSpectatingMode");
				return true;
			}
			if (binding ~== "spectatePreviousPlayer")
			{
				if (key_down) SendNetworkEvent("SnowyMP_SpectatePreviousPlayer");
				return true;
			}
			if (binding ~== "spectateNextPlayer")
			{
				if (key_down) SendNetworkEvent("SnowyMP_SpectateNextPlayer");
				return true;
			}
		}

		if (binding ~== "+use")
		{
			if (InGameOver && key_down)
			{
				SendNetworkEvent("SnowyMP_ReadyToRestart");
				return true;
			}

			if (!IsPlayerAlive(consoleplayer))
			{
				if (PlayerCanRespawn(consoleplayer) && key_down)
				{
					SendNetworkEvent("SnowyMP_RespawnPlayer");
					return true;
				}
				
				if (
					key_down && 
					OptionallyIrrecoverableBodies() && !IsPlayerRespawning(consoleplayer) && !PlayerHasRespawnsLeft(consoleplayer) && 
					!IsPlayerFalling(consoleplayer) && !IsPlayerInSafeSpot(consoleplayer)
				)
				{
					SendNetworkEvent("SnowyMP_TeleportPlayerToStart");
					return true;
				}
				
				return true;
			}

			if (IsRevivingAllowed())
			{
				if (CanReviveNearby(consoleplayer) && key_down)
				{
					SendNetworkEvent("SnowyMP_ReviveStart"); 
					return true;
				}

				if (IsPlayerReviving(consoleplayer) && key_up)
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
			WarpPlayerToSafeSpot(e.Player);
		}
	}

	// Player Inputs

	void WarpPlayerToSpawnPoint(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;

		player.mo.Teleport(MP_Players[PlayerNumber].SpawnPoint, MP_Players[PlayerNumber].SpawnAngle, TF_TELEFRAG);
	}

	void WarpPlayerToSafeSpot(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber)) return;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		
		vector3 current_pos = player.mo.Pos;
		player.mo.SetOrigin(MP_Players[PlayerNumber].SafeSpot, true);
		
		if (!IsPlayerInSafeSpot(PlayerNumber))
			WarpPlayerToSpawnPoint(PlayerNumber);
		else
			player.mo.Teleport(MP_Players[PlayerNumber].SafeSpot, MP_Players[PlayerNumber].SafeAngle, TF_TELEFRAG);
		
		
		if (AllowWarpingMessages()) Console.Printf("%s has warped to a safe spot", players[PlayerNumber].GetUserName());
	}

	/* Drop Items On Death */

	void DropPlayerItemsOnDeath(int PlayerNumber)
	{
		if (!DropItemsOnDeath()) return;

		if (DropWeaponsOnDeath())
		{
			PlayerDropAllOfItemType(PlayerNumber, 'Weapon');
		}

		if (DropAmmoOnDeath())
		{
			PlayerDropAllOfItemType(PlayerNumber, 'Ammo');
		}

		if (DropKeyItemsOnDeath())
		{
			PlayerDropAllOfItemType(PlayerNumber, 'Key');
		}
	}

	void PlayerDropAllOfItemType(int PlayerNumber, class<Inventory> ItemType)
	{
		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return;
		PlayerPawn player_pawn = player.mo;

		ThinkerIterator item_iterator = ThinkerIterator.Create(ItemType, Thinker.STAT_INVENTORY);
		Inventory item;
		while (item = Inventory(item_iterator.Next()))
		{
			if (item.owner != player_pawn) continue;
			let dropped_item = player_pawn.DropInventory(item);
			if (dropped_item) dropped_item.TossItem();
		}
	}

	/* Spectating */

	void PlayerChangeSpectatingMode(int PlayerNumber)
	{
		if (!IsPlayerActive(PlayerNumber) || IsPlayerAlive(PlayerNumber)) return;
		MP_Players[PlayerNumber].SpectatingMode = (MP_Players[PlayerNumber].SpectatingMode + 1) % 2;
		MP_Players[PlayerNumber].SpectateModeKeybindDisplayTics = MP_Constants.SpectateModeKeybindDisplayMaxTics;
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
		if (!AllowSpectatingMessages()) return;

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

			Console.Printf("%s is now spectating %s.", players[PlayerNumber].GetUserName(), pronoun);
		}
		else if (players[PlayerNumber].GetUserName() == players[OtherPlayerNumber].GetUserName())
		{
			Console.Printf("%s is now spectating the other %s.", players[PlayerNumber].GetUserName(), players[OtherPlayerNumber].GetUserName());
		} 
		else
		{
			Console.Printf("%s is now spectating %s.", players[PlayerNumber].GetUserName(), players[OtherPlayerNumber].GetUserName());
		}
	}

	/* Respawning */

	clearscope bool PlayerCanRespawn(int PlayerNumber)
	{
		if (!IsPlayerAllowedToRespawn(PlayerNumber))
			return false; // Respawn timer is not finished
		
		if (!IsRespawningAllowed())
			return false; // Respawns are not allowed
		
		if (IsPlayerAlive(PlayerNumber))
			return false; // Player is alive
		
		if (!PlayerHasRespawnsLeft(PlayerNumber))
			return false; // Player used too many respawns
		
		return true;
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

		if (RespawnInPlace())
		{
			if (!AlwaysIrrecoverableBodies() && !IsPlayerInSafeSpot(PlayerNumber)) 
				WarpPlayerToSafeSpot(PlayerNumber);
		}
		else
		{
			WarpPlayerToSpawnPoint(PlayerNumber);
		}
		
		MP_Players[PlayerNumber].RespawnCount++;
		player.Resurrect();
		player_pawn.A_SetHealth(RespawnedHealth());
		
		let reviving_player = GetPlayerRevivingThisPlayer(PlayerNumber);
		if (reviving_player != -1) 
		{
			MP_Players[reviving_player].RevivingTarget = -1;
			MP_Players[reviving_player].RevivingTimer = 0;
			
			UnfreezePlayer(reviving_player);
			RaisePlayerWeapon(reviving_player);
			PlayerStopSpectating(reviving_player);
		}
		
		if (AllowRespawningMessages()) Console.PrintfEx(PRINT_LOW, "%s has respawned.", player.GetUserName());
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
		downed_player.mo.A_SetHealth(RevivedHealth());
		
		MP_Players[RevivingPlayerNumber].RevivingTarget = -1;
		MP_Players[RevivingPlayerNumber].RevivingTimer = 0;
		
		MP_Players[DownedPlayerNumber].ReviveCount++;

		UnfreezePlayer(RevivingPlayerNumber);
		RaisePlayerWeapon(RevivingPlayerNumber);
		PlayerStopSpectating(DownedPlayerNumber);

		if (!AllowRevivingMessages()) return;

		if (reviving_player.GetUserName() == downed_player.GetUserName())
		{
			Console.PrintfEx(PRINT_MEDIUM, "%s has revived the other %s.", reviving_player.GetUserName(), downed_player.GetUserName());
		} 
		else
		{
			Console.PrintfEx(PRINT_MEDIUM, "%s has revived %s.", reviving_player.GetUserName(), downed_player.GetUserName());
		}
	}

	clearscope int FindNearbyDownedPlayer(int PlayerNumber) const
	{
		if (!IsPlayerActive(PlayerNumber) || !IsPlayerAlive(PlayerNumber)) return -1;

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) return -1;

		for (int OtherPlayerNumber = 0; OtherPlayerNumber < MAXPLAYERS; OtherPlayerNumber++)
		{
			if (IsPlayerRevivableBy(PlayerNumber, OtherPlayerNumber))
				return OtherPlayerNumber;
		}

		return -1;
	}

	clearscope bool IsPlayerRevivableBy(int PlayerNumber, int OtherPlayerNumber) const
	{
		if (!IsRevivingAllowed())
			return false; // Revives are not allowed

		if (!IsPlayerActive(PlayerNumber) || !IsPlayerActive(OtherPlayerNumber))
			return false; // One of the players is not in the game

		PlayerInfo player = players[PlayerNumber];
		if (!player || !player.mo) 
			return false; // Player doesn't exist (probably)

		if (PlayerNumber == OtherPlayerNumber) 
			return false; // Can't revive self
		
		if (IsPlayerAlive(OtherPlayerNumber)) 
			return false; // The other player is alive duh

		PlayerInfo other_player = players[OtherPlayerNumber];
		if (!other_player || !other_player.mo) 
			return false; // Other player doesn't exist (probably)

		if (!player.mo.IsTeammate(other_player.mo))
			return false; // Not a teammate

		double distance_to = Level.Vec3Diff(player.mo.Pos, other_player.mo.Pos).Length();
		if (distance_to > RevivingDistance()) 
			return false; // Too far away

		if (IsBleedOutAllowed() && HasPlayerBledOut(OtherPlayerNumber))
			return false; // Other player has bled out already
		
		if (!InfiniteRevives() && GetPlayerReviveCount(OtherPlayerNumber) >= MaxReviveCount())
			return false; // Other player has no more revives

		return true;
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

		MP_Players[RevivingPlayerNumber].RevivingTarget = DownedPlayerNumber;
		MP_Players[RevivingPlayerNumber].RevivingTimer = 0;

		if (!CanMoveWhileReviving()) FreezePlayer(RevivingPlayerNumber);
		if (!KeepWeaponWhileReviving()) LowerPlayerWeapon(RevivingPlayerNumber);

		PlayerStopSpectating(DownedPlayerNumber);

		if (!AllowRevivingMessages()) return;
		
		if (downed_player.GetUserName() == reviving_player.GetUserName())
		{
			Console.PrintfEx(PRINT_MEDIUM, "%s is reviving the other %s.", reviving_player.GetUserName(), downed_player.GetUserName());
		} 
		else
		{
			Console.PrintfEx(PRINT_MEDIUM, "%s is reviving %s.", reviving_player.GetUserName(), downed_player.GetUserName());
		}
	}

	void PlayerStopReviving(int PlayerNumber)
	{
		if (!IsPlayerReviving(PlayerNumber)) return;

		PlayerInfo player = Players[PlayerNumber];
		if (!player || !player.mo) return;

		MP_Players[PlayerNumber].RevivingTarget = -1;
		MP_Players[PlayerNumber].RevivingTimer = 0;
		
		UnfreezePlayer(PlayerNumber);
		RaisePlayerWeapon(PlayerNumber);

		if (!AllowRevivingMessages()) return;

		PlayerInfo downed_player = players[GetPlayerRevivingTarget(PlayerNumber)];

		if (downed_player)
		{
			if (downed_player.GetUserName() == player.GetUserName())
			{
				Console.PrintfEx(PRINT_MEDIUM, "%s doesn't finish reviving the other %s.", player.GetUserName(), downed_player.GetUserName());
			} 
			else
			{
				Console.PrintfEx(PRINT_MEDIUM, "%s doesn't finish reviving %s.", player.GetUserName(), downed_player.GetUserName());
			}
		}
		else Console.PrintfEx(PRINT_MEDIUM, "%s doesn't finish reviving.", player.GetUserName()); 
	}

	/* Bleeding Out */

	void PlayerBleedOut(int PlayerNumber)
	{
		if (IsPlayerAlive(PlayerNumber)) return;
		if (!IsBleedOutAllowed()) return;

		PlayerInfo player = Players[PlayerNumber];
		if (!player || !player.mo) return;

		MP_Players[PlayerNumber].BleedOutCount++;

		if (AllowBleedOutMessages()) Console.PrintfEx(PRINT_MEDIUM, "%s has bled out.", player.GetUserName()); 
	}


	/* Game Overs */

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
			if (IsRevivingAllowed())
			{
				if (IsPlayerReviving(consoleplayer))
				{
					double CurrentReviveTime = MP_Players[consoleplayer].RevivingTimer;
					double MaxReviveTime = ReviveTime();

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
					double MaxReviveTime = ReviveTime();

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
				else
				{
					let downed_player = FindNearbyDownedPlayer(consoleplayer);

					if (downed_player != -1)
					{
						StatusBar.DrawString(
							small_hud_font, 
							String.Format("Press %s to revive %s.", use_keybind, players[downed_player].GetUserName()), 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Red")
						);

						y_offset_center += small_hud_font.mFont.GetHeight();

						// Display revives left
						if (!InfiniteRevives()) 
						{
							String revives_left_string = "";
							int revives_left = MaxReviveCount() - GetPlayerReviveCount(downed_player);
							if (revives_left == 1) revives_left_string = "(1 revive left)";
							else revives_left_string = String.Format("(%i revives left)", revives_left);

							StatusBar.DrawString(
								small_hud_font, 
								revives_left_string, 
								(0, y_offset_center), 
								StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
								translation: Font.FindFontColor("Dark Red")
							);

							y_offset_center += small_hud_font.mFont.GetHeight();
						}

						y_offset_center += small_hud_font.mFont.GetHeight();
					}
				}
			}

			//Render respawning text
			if (IsPlayerRespawning(consoleplayer))
			{
				if (PlayerHasRespawnsLeft(consoleplayer))
				{
					int respawn_delay = GetPlayerRespawnTimer(consoleplayer);
					if (respawn_delay > 0)
					{
						StatusBar.DrawString(
							small_hud_font, 
							String.Format("You can respawn in %i seconds", int(double(respawn_delay) / TICRATE)), 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Yellow")
						);
					}
					else
					{
						StatusBar.DrawString(
							small_hud_font, 
							String.Format("Press %s to respawn.", use_keybind), 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Yellow")
						);
					}
					
					if (!InfiniteRespawns()) 
					{
						String respawns_left_string = "";
						y_offset_center += small_hud_font.mFont.GetHeight();

						int respawns_left =  MaxRespawnCount() - GetPlayerRespawnCount(consoleplayer);
						if (respawns_left == 1) respawns_left_string = " (1 respawn left)";
						else respawns_left_string = String.Format(" (%i respawns left)", respawns_left);
							StatusBar.DrawString(
							small_hud_font, 
							respawns_left_string, 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Dark Red")
						);
					}
				}
				else
				{
					StatusBar.DrawString(
						small_hud_font, 
						"No respawns left.", 
						(0, y_offset_center), 
						StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
						translation: Font.FindFontColor("Red")
					);
				}

				y_offset_center += small_hud_font.mFont.GetHeight();
			}
			else if (!IsPlayerAlive(consoleplayer) && !IsPlayerSpectating(consoleplayer))
			{
				// Display "You are dead."

				StatusBar.DrawString(
					small_hud_font, 
					"You are dead.", 
					(0, y_offset_center), 
					StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
					translation: Font.FindFontColor("Red")
				);

				y_offset_center += small_hud_font.mFont.GetHeight();

				if (IsRevivingAllowed() && ActivePlayerCount() > 1)
				{	
					// Display revives left
					if (!InfiniteRevives()) 
					{
						String revives_left_string = "";
						int revives_left = MaxReviveCount() - GetPlayerReviveCount(consoleplayer);
						if (revives_left == 1) revives_left_string = "(1 revive left)";
						else revives_left_string = String.Format("(%i revives left)", revives_left);

						StatusBar.DrawString(
							small_hud_font, 
							revives_left_string, 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Dark Red")
						);

						y_offset_center += small_hud_font.mFont.GetHeight();
					}

					// Display bleeding out text
					if (IsBleedOutAllowed() && !HasPlayerBledOut(consoleplayer))
					{
						StatusBar.DrawString(
							small_hud_font, 
							String.Format("Bleeding out...", use_keybind), 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Red")
						);
						y_offset_center += small_hud_font.mFont.GetHeight();
					}
				}
				
			}

			// Show warp to safe spot text
			if (
				OptionallyIrrecoverableBodies() && !IsPlayerRespawning(consoleplayer) && !PlayerHasRespawnsLeft(consoleplayer) &&
				!IsPlayerAlive(consoleplayer) && !IsPlayerFalling(consoleplayer) && !IsPlayerInSafeSpot(consoleplayer)
			)
			{
				StatusBar.DrawString(
					small_hud_font, 
					String.Format("Press %s to warp to safe spot.", use_keybind), 
					(0, y_offset_center), 
					StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
					translation: Font.FindFontColor("Yellow")
				);
				y_offset_center += small_hud_font.mFont.GetHeight() * 2;
			}

			//Render spectating text
			if (IsSpectatingAllowed() && LivingPlayerCount() > 1)
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
					
					if (MP_Players[consoleplayer].SpectateModeKeybindDisplayTics < MP_Constants.SpectateModeKeybindDisplayMaxTics)
					{
						y_offset_center += small_hud_font.mFont.GetHeight();

						StatusBar.DrawString(
							small_hud_font, 
							String.Format("Press %s to change spectating mode.", spectate_mode_keybind), 
							(0, y_offset_center), 
							StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
							translation: Font.FindFontColor("Dark Gray")
						);
					}

					y_offset_center += small_hud_font.mFont.GetHeight() * 2;
				}
				else if (!IsPlayerAlive(consoleplayer) && ActivePlayerCount() > 0)
				{
					StatusBar.DrawString(
						small_hud_font, 
						String.Format("Press %s or %s to spectate others.", spectate_next_keybind, spectate_prev_keybind), 
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