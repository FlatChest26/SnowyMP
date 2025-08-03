class RevivingSyringe : Weapon
{
	class<Weapon> PreviousWeaponType;
	
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+FIXMAPTHINGPOS
		+INVISIBLE
		+NOTONAUTOMAP
	}
	
	States
	{
	Ready:
		TNT1 A 1 A_WeaponReady;
		Loop;
	Deselect:
		TNT1 A 1 A_Lower(12);
		Loop;
	Select:
		TNT1 A 1 A_Raise(12);
		Loop;
	Fire:
		Goto Ready;
	}
}