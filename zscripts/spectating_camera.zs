class SpectatingCamera : Actor
{
	Default
	{
		+NOGRAVITY; 
		+NOBLOCKMAP;
		+NOCLIP;
		+INVULNERABLE;

		-SOLID;
		-SHOOTABLE;
		-PICKUP;
		-WINDTHRUST;
		-TELESTOMP;
		+NOTELESTOMP;
	}
}

class SpectatingCamera2 : PlayerPawn
{
	enum CenterCameraModes
	{
		CM_ThirdPerson = 0,
		CM_FirstPerson = 1,
	}

	// Variables //

	private double saved_view_height;

	/* Center */

	Actor Center; // Entity being tracked by this observer
	int CenterCameraMode;
	vector3 CenterOffset;

	// Properties //

	Default
	{
		Height 16;

		Player.DisplayName "Spectating Camera";
		Player.ViewBob 0;
		Player.ForwardMove 0.4, 0.4;
		Player.SideMove 0.4, 0.4;

		+NOGRAVITY; 
		+NOBLOCKMAP;
		+NOCLIP;
		+INVULNERABLE;

		-SOLID;
		-SHOOTABLE;
		-PICKUP;
		-WINDTHRUST;
		-TELESTOMP;
		+NOTELESTOMP;
		+CAMFOLLOWSPLAYER;
	}


	// Methods //
	
	/* Getters & Setters */

	/* Checks */

	clearscope bool InFreeCam() const { return Center == null; }
	clearscope bool HasCenter() const { return Center != null; }

	clearscope bool InFirstPersonMode() const { return CenterCameraMode == CM_FirstPerson; }
	clearscope bool InThirdPersonMode() const { return CenterCameraMode == CM_ThirdPerson; }

	/* Inputs */

	void ChangeCameraMode()
	{
		CenterCameraMode = (CenterCameraMode + 1) % 2;
		switch(CenterCameraMode)
		{
		case CM_FirstPerson:
		{
			Console.PrintF("Switched to First Person");
			break;
		}
		case CM_ThirdPerson:
		{
			Console.PrintF("Switched to Third Person");
			break;
		}
		}
		ClearInterpolation();
	}

	/* Utility */

	bool TryObserve(Actor targ)
	{
		if (!targ) return false;

		Observe(targ);
		return true;
	}

	void Observe(Actor targ)
	{
		if (!targ) return;

		Center = targ;
		ClearInterpolation();
		Center.player = self.player;
	}
	
	void StopObservingCenter()
	{
		if (!Center) return;
		
		ClearInterpolation();
		if (InFirstPersonMode())
		{
			SetOrigin(Center.Pos + (0, 0, Center.Height / 2), false);
			Angle = Center.Angle;
			Pitch = Center.Pitch;
			Roll = Center.Roll;
		}

		if (Center.player == self.player) Center.player = null;

		Center = null;
	}

	/* Misc */
	
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		saved_view_height = ViewHeight;
		CenterOffset = (-64, 0, 64);
	}

	override void Tick()
	{
		Super.Tick();
		HandleObserverMode();
	}
	
	void HandleObserverMode()
	{
		SetCamera(self);

		if (HasCenter())
		{

			switch(CenterCameraMode)
			{
			case CM_FirstPerson:
			{
				SetCamera(Center);
				SetOrigin(Center.Pos, true);
				Center.Pitch = Pitch;
				break;
			}
			case CM_ThirdPerson:
			{
				Warp(
					Center,
					CenterOffset.X * cos(Pitch),
					CenterOffset.Y,
					CenterOffset.Z * sin(Pitch),
					Angle - Center.Angle,
					WARPF_NOCHECKPOSITION 
				);

				break;
			}
			}
		}
		else
		{
			Vel *= 0.8;
		}
	}
}
