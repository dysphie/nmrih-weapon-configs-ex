# Weapon Configs: Ex
A fork of [Weapon Configs](https://forums.alliedmods.net/showthread.php?p=2628691) by [Ryan](https://forums.alliedmods.net/member.php?u=283719), made to work with the latest NMRiH updates.

## Brief
Customize No More Room in Hell's weapon stats and animation speeds. See below for all customizable properties.
This plugin re-creates a feature that used to be included in the Quality of Life plugin.

## Installation
- Install [Metamod Source](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install [Sourcemod](https://www.sourcemod.net/downloads.php?branch=stable) (1.11 or higher)
- Download `nmrih-weapon-configs-ex-X.X.X.zip` from [releases](https://github.com/dysphie/nmrih-weapon-configs-ex/releases) and extract it into `addons/sourcemod`


## Features
- Customize weapon behavior:
	- Damage (normal, headshot, shove and thrown)
	- Pushback chance (normal and headshot)
	Stamina cost (shove and melee attack)
	Shove cooldown time
	Magazine capacity
	Medical item heal amount
	Explosion radius of grenades and flare gun
	Whether weapon can be used to suicide (gimmicky due to missing animations)
	Whether weapon can perform skillshot (Linux servers only)

- Customize weapon speeds:
	- Melee, shove and charged attack
	- Hip-fire and ironsight shooting
	- Reload, unload and ammo check
	- Maglite activation
	- Barricade speed, e-tool toggle

Weapon damage and medical heal amounts can also be randomized.

See [configs/weapon-configs-example.cfg](https://github.com/dysphie/nmrih-weapon-configs-ex/blob/main/configs/weapon-configs-example.cfg) for examples.

## ConVars
- `sm_weapon_configs_enabled` - 1 = Plugin active. 0 = Plugin disabled.
- `sm_weapon_config` - Name of active weapon configuration excluding the .cfg extension. Set to `""` to disable weapon configs.

Weapon configs are relative to your `nmrih/addons/sourcemod/configs` folder.

## Credits
- NMRiH dev team
- Sourcemod crew
- Drifter and Peacemaker for DHooks extension
- rio for their suggestion on how to return a null CBaseEntity from DHooks
- overmase for spotting problem with qol.cfg overwriting other plugin's config
- Kevin for spotting issues with the bow and QOL config and suggesting random heal amount
- GEEEX221 for finding issue with custom firearm damage not working
- Holy Crap for suggesting cvar to toggle plugin activeness
