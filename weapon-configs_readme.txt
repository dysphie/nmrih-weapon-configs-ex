[NMRiH] Weapon Configs (v1.0.5)
by Ryan.

https://forums.alliedmods.net/showthread.php?p=2628691


	Customize No More Room in Hell's weapon stats and animation speeds.

	It requires DHooks with Dynamic Detours: https://forums.alliedmods.net/showthread.php?p=2588686#post2588686

	This plugin re-creates a feature that use to be included in the Quality of Life plugin.

Thanks to:

	NMRiH dev team
	Sourcemod crew
	Driter and Peacemaker for DHooks
	rio for their suggestion on how to return a null CBaseEntity from DHooks
	overmase for spotting problem with qol.cfg overwriting other plugin's config
	Kevin for spotting issues with the bow and QOL config
	GEEEX221 for finding issue with custom firearm damage not working


Installation:

	1. Install Metamod Source: https://www.metamodsource.net/downloads.php

	2. Install Sourcemod: https://www.sourcemod.net/downloads.php

	3. Install DHooks with Dynamic Detours extension:
		3a. For Windows users that are running Sourcemod versions newer than 1.10.0.6225,
			you should download the DHooks-detours7 build from the plugin thread.
		3b. Otherwise use the normal download link:
			https://forums.alliedmods.net/showthread.php?p=2588686#post2588686

	4. Extract the contents of this archive into your nmrih directory.


Features

	Customize weapon behavior:

		- Damage (normal, headshot, shove and thrown)
		- Pushback chance (normal and headshot)
		- Stamina cost (shove and melee attack)
		- Shove cooldown time
		- Magazine capacity
		- Medical item heal amount
		- Explosion radius of grenades and flare gun
		- Whether weapon can be used to suicide (gimmicky due to missing animations)
		- Whether weapon can perform skillshot (Linux servers only)

	Customize weapon speeds:

		- Melee, shove and charged attack
		- Hip-fire and ironsight shooting
		- Reload, unload and ammo check
		- Maglite activation
		- Barricade speed, e-tool toggle

	Weapon damage and medical heal amounts can also be randomized.


Example config

	"weaponconfig"
	{
		// Revolver
		"fa_sw686"
		{
			// Super damage
			"damage" "500"

			// Randomized headshot damage (between 1000 and 2000)
			"damage_headshot" "1000-2000"

			"damage_shove" "25"

			// High capacity revolver
			"capacity" "12"

			// No cooldown between shots (shoot as fast as you can click)
			"hip_fire_delay" "0"

			// 2x faster ironsight shooting speed
			"sight_fire" "2"

			// 1.5x faster reload speed
			"reload" "1.5"

			// 4x faster ammo check speed
			"check_ammo" "4"
		}

		// Faster, more agile knife
		"me_kitknife"
		{
			// 6% faster charge-up and charge-release speed
			"charge" "1.06"
			"release" "1.06"

			// Time between attacks is 0.4 seconds
			"quick_delay" "0.4"
			"release_delay" "0.4"
			"shove_delay"	"0.4"

			// Charge attack can be unleashed after 0.1 seconds of charging
			"charge_delay" "0.1"

			// Throwing knife of death
			"damage_thrown" "1000"
		}
	}

	See 'addons/sourcemod/configs/weapon-configs-example.cfg' for more examples.


ConVars

	sm_weapon_config
		Name of active weapon configuration excluding the .cfg extension. Set to "" to disable weapon configs.

	Weapon configs are relative to your nmrih/addons/sourcemod/configs folder.


Changelog
	1.0.5 - 2020-04-11
		Added sm_weapon_configs_enabled to toggle plugin activeness (Thanks Holy Crap)
		Fixed custom firearm damage not working in PvP (Thanks Ulreth)

	1.0.4 - 2019-02-25
		Added support for weapon damage range
			Use the format <lo>-<hi> to allow a range of damage between lo and hi. E.g. "damage" "50-100"
		Added support for custom medical heal amounts. Use "damage" key to set heal amount. Supports random range.

	1.0.3 - 2019-02-22
		Fixed custom firearm damage not working (Thanks GEEEX221)
		Fixed bow using 2x speed in default config

	1.0.2 - 2018-12-29
		Added damage_thrown_headshot and damage_shove_headshot
		Added QOL's old bayonet changes to QOL config
		Fixed bow shooting too fast and removed 20-round revolver from QOL config (Thanks Kevin)

	1.0.1 - 2018-12-13
		Renamed qol.cfg so it doesn't overwrite QOL plugin's config (Thanks overmase)

	1.0.0 - 2018-12-12
		Re-release of original QOL system in separate plugin.
