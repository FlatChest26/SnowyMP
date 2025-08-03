# Snowy MP

A small mod for GZDoom that adds some co-op mechanics to multiplayer to incentivize teamwork!

Features:
- Reviving downed players.
- Improved respawn rules.
- Spectating others while waiting to be revived.
- Health bars on the HUD
- Highly customizable settings and rules.
- Silly COD Zombies game over MIDI's that play when each player is dead. (MIDI covers by me)
- ~~Friendly player nametags~~ (not implemented yet)

Snowy MP is a mod I created to make experiencing new WAD's with my friends more enjoyable. The mechanics are somewhat inspired by Call of Duty Zombies and The Outlast Trials.

I am open to feature recommendations and suggestions. Please report any bugs you to me if you can.

## How to use

Some of the mod's mechanics only work when in a network game, so you must distribute the pk3 to other players and add it as a command-line parameter before hosting or joining!!!

Example:

```
gzdoom mods/SnowyMP.pk3 -iwad doom2.wad -host 1 -warp 01
```

When a game starts, do be sure to go to the SnowyMP options menu and make sure everything is to your liking. 

Some settings are tied to GZDoom's compatability rules and will be reset after starting a new game. 
