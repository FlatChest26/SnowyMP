class SnowyMPNameTagHandler : EventHandler
{
	clearscope SnowyMPGameplayChanges GetSnowyMPGameplayChanges() const { return SnowyMPGameplayChanges(EventHandler.Find('SnowyMPGameplayChanges')); }
	clearscope bool NameTagsEnabled() const { return CVar.GetCVar("snowy_mp__display_player_names", players[consoleplayer]).GetBool(); }

	override void RenderOverlay(RenderEvent e)
	{
		DrawNameTags(e);
	}

	ui void DrawNameTags(RenderEvent e)
	{
		let mp_gameplay = GetSnowyMPGameplayChanges();
		if (!mp_gameplay) return;

		// Make sure the automap is inactive
		if (automapactive) return;

		// Check if name tags are enabled
		if (!NameTagsEnabled()) return;

		// Check for the console player
		PlayerInfo player_info = players[consoleplayer];
		if (!player_info || !player_info.mo) return;
		PlayerPawn player = player_info.mo;

		if (!mp_gameplay.IsPlayerAlive(consoleplayer)) return;

		StatusBar.BeginHUD();
		HUDFont hud_font = HUDFont.Create(smallfont);

		ThinkerIterator player_iterator = ThinkerIterator.Create('PlayerPawn', Thinker.STAT_PLAYER);
		PlayerPawn other = PlayerPawn(player_iterator.Next());
		
		while (other != null)
		{
			if (other != player)
				DrawNameTag(other, player, hud_font, other.player.GetUserName(), 'white', 2000);
			
			other = PlayerPawn(player_iterator.Next());
		}
	}

	ui void DrawNameTag(Actor entity, PlayerPawn player, HUDFont hud_font, String NameTagName, Name NameTagColor,  double MaxNameTagDistance = 320)
	{
		PlayerInfo player_info = player.player;
		if (!player_info) return;

		// Check if the name tag would even be on screen
		double angle_between = player.DeltaAngle(player.Angle, player.AngleTo(entity));
		double pitch_between = player.DeltaAngle(player.Pitch, player.PitchTo(entity));
		double angle_max = player_info.FOV / 6;
		double pitch_max = player_info.FOV / 6;

		if (abs(angle_between) > angle_max || abs(pitch_between) > pitch_max) return;

		// Make sure the name tag is close enough to be viewed
		double distance_to = Level.Vec3Offset(player.Pos, entity.Pos).Length();
		if (distance_to > MaxNameTagDistance) return;

		vector2 screen_pos = (0.0, 0.01); 
		vector2 scale = (1.0, 1.0); 
		
		screen_pos.x *= Screen.GetWidth();
		screen_pos.y *= Screen.GetHeight();

		StatusBar.DrawString(
			hud_font, NameTagName, screen_pos, 
			StatusBar.DI_SCREEN_CENTER | StatusBar.DI_TEXT_ALIGN_CENTER,
			translation: Font.FindFontColor(NameTagColor),
			scale: scale
		);
	}
}