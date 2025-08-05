class SnowyMPGroupUIHandler : EventHandler
{
	clearscope SnowyMPGameplayChanges GetSnowyMPGameplayChanges() const { return SnowyMPGameplayChanges(EventHandler.Find('SnowyMPGameplayChanges')); }

	ui void DrawImageToBox(TextureID tex, int x, int y, int width, int height, double alpha = 0.75, bool animate = false)
	{
		if (!tex) return;

		double scale1 = 1.0;
		double scale2 = 1.0;

		let texsize = TexMan.GetScaledSize(tex);

		if (width < texsize.X) 
			scale1 = width / texsize.X;

		if (height < texsize.Y)
			scale2 = height / texsize.Y;

		scale1 = min(scale1, scale2);

		x += width >> 1;
		y += height;

		width = int(texsize.X * scale1);
		height = int(texsize.Y * scale1);

		screen.DrawTexture(
			tex, animate, x, y,
			DTA_KeepRatio, true,
			DTA_Alpha, alpha, 
			DTA_DestWidth, width, 
			DTA_DestHeight, height, 
			DTA_CenterBottomOffset, 1
		);
	}

	ui int DrawStatLine(int x, in out int y, String prefix, String text, int prefix_color, int stat_color, double alpha = 1.0)
	{
		y += SmallFont.GetHeight();

		Screen.DrawText(
			SmallFont, prefix_color, x, y, prefix, 
			DTA_KeepRatio, true,
			DTA_Alpha, alpha
		);

		Screen.DrawText(
			SmallFont, stat_color, x + SmallFont.StringWidth(prefix .. " "), y, text,
			DTA_KeepRatio, true,
			DTA_Alpha, alpha
		);


		return x + SmallFont.StringWidth(prefix .. " " .. text);
	}

	ui bool DrawOneKey(int xo, int x, int y, double alpha, in out int c, Key inv)
	{
		TextureID icon;
		
		if (!inv) return false;
		
		TextureID AltIcon = inv.AltHUDIcon;
		if (!AltIcon.Exists()) return false;	// Setting a non-existent AltIcon hides this key.

		if (AltIcon.isValid()) 
		{
			icon = AltIcon;
		}
		else if (inv.SpawnState && inv.SpawnState.sprite!=0)
		{
			let state = inv.SpawnState;
			if (state != null) icon = state.GetSpriteTexture(0);
			else icon.SetNull();
		}
		// missing sprites map to TNT1A0. So if that gets encountered, use the default icon instead.
		if (icon.isNull() || icon == TexMan.CheckForTexture("TNT1A0", TexMan.Type_Sprite)) icon = inv.Icon; 

		if (icon.isValid())
		{
			DrawImageToBox(icon, x, y, 8, 10, alpha);
			return true;
		}
		return false;
	}


	override void RenderOverlay(RenderEvent e)
	{
		DrawGroupInfoUI(e);
	}

	ui void DrawGroupInfoUI(RenderEvent e)
	{
		let multiplayer_handler = SnowyMPHandler(StaticEventHandler.Find('SnowyMPHandler'));
		if (!multiplayer_handler) return;

		// Don't show unless in co op
		if (!multiplayer_handler.IsCooperativeGame()) return;

		// Make sure the automap is inactive
		if (automapactive) return;

		// Check if name tags are enabled
		if (!CVar.GetCVar("snowy_mp__display_group_info_ui", players[consoleplayer]).GetBool()) return;

		// Check for the console player
		PlayerInfo player_info = players[consoleplayer];
		if (!player_info || !player_info.mo) return;
		PlayerPawn player = player_info.mo;

		ThinkerIterator iterator = ThinkerIterator.Create('PlayerPawn', Thinker.STAT_PLAYER);
		PlayerPawn other = PlayerPawn(iterator.Next());

		int x = 2;
		int y = 2;
		double alpha = 1.0;

		let transformation = new("Shape2DTransform");
		transformation.Scale((2.0, 2.0));
		Screen.SetTransform(transformation);

		while (other != null)
		{
			if (other.player && other != player)
			{
				int width = StatusBar.HorizontalResolution / 2;
				int height = DrawStatus(other.player, x, y, alpha);

				y += height + 4;
			}
			
			other = PlayerPawn(iterator.Next());
		}

		Screen.ClearTransform();
	}

	ui int DrawStatus(PlayerInfo CPlayer, int x, int y, double alpha = 1.0)
	{
		int starting_y = y;
		string player_state_text = "";
		
		switch (CPlayer.PlayerState)
		{
			//break; case PST_LIVE: player_state_text = "Alive";
			break; case PST_DEAD: player_state_text = " - \cgDOWN\c-";
			//break; case PST_REBORN: player_state_text = "Reborn";
			//break; case PST_ENTER: player_state_text = "Entered";
			//break; case PST_GONE: player_state_text = "Disconnected";
		}
		
		let mp_gameplay = GetSnowyMPGameplayChanges();
		if (mp_gameplay.IsPlayerFullyDead(CPlayer.mo.PlayerNumber()))
			player_state_text = " - \cgDEAD\c-";

		string title = String.Format("%s%s", CPlayer.GetUserName(), player_state_text);

		Screen.DrawText(
			SmallFont, Font.CR_WHITE, x, y, title, 
			DTA_KeepRatio, true
		);
		
		let mo = CPlayer.mo;

		DrawStatLine(x, y, "  HP:", String.Format("%d", max(mo.Health, 0)), Font.CR_RED, Font.CR_GREEN, alpha);
		y = DrawKeys(CPlayer, x, y + SmallFont.GetHeight(), alpha);

		int height = starting_y - (y + SmallFont.GetHeight());
		return height;
	}

	ui int DrawKeys(PlayerInfo CPlayer, int x, int y, double alpha = 1.0)
	{
		int yo = y;
		int xo = x;
		int i;
		int c = 0;
		Key inv;

		if (!deathmatch)
		{
			int count = Key.GetKeyTypeCount();
			
			// Go through the key in reverse order of definition, because we start at the right.
			for(int i = 0; i < count; i++)
			{
				if ((inv = Key(CPlayer.mo.FindInventory(Key.GetKeyType(i)))))
				{
					if (DrawOneKey(xo, x + 9, y, alpha, c, inv))
					{
						x += 9;
						if (++c >= 10)
						{
							x = xo;
							y -= 11;
							c = 0;
						}
					}
				}
			}
		}
		
		if (x == xo && y != yo) y += 11;	// undo the last wrap if the current line is empty.
		return y - 11;
	}
}
