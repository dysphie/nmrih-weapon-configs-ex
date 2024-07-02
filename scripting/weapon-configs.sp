#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#include <dhooks>

// TODO: Handle bow projectile damage
// TODO: Dry-fire speed

#pragma semicolon 1
#pragma newdecls required

#define WEAPON_CONFIGS_VERSION "1.2.0"

public Plugin myinfo =
{
    name = "[NMRiH] Weapon Configs (Dysphie's Fork)",
    author = "Ryan.",
    description = "Customize weapon speeds and behavior.",
    version = WEAPON_CONFIGS_VERSION,
    url = "https://github.com/dysphie/nmrih-weapon-configs-ex"
};


#define CLASSNAME_MAX 128
#define WEAPON_MAX 128          // Max weapon types.
#define CAPACITY_MAX 254        // Max weapon magazine capacity.

#define KEYS_ONLY true
#define KEYS_AND_VALUES false

#define HITGROUP_HEAD 1
#define HITGROUP_BRAINSTEM 11

#define IGNORE_CURRENT_WEAPON (1 << 7)

// Sequence used by barricade hammer when placing a board.
#define SEQUENCE_BARRICADE_HAMMER_BARRICADE 16

// Sequences used during bow shot.
#define SEQUENCE_BOW_IDLE_TO_IRON 7
#define SEQUENCE_BOW_IRON_TO_IDLE 8
#define SEQUENCE_BOW_STRETCHED_RELAXED 11
#define SEQUENCE_BOW_STRETCHED_TENSE 12
#define SEQUENCE_BOW_FIRE 13
#define SEQUENCE_BOW_FIRE_LAST 14

// Symbolic names for DHook callback edge type.
#define DHOOK_POST true
#define DHOOK_PRE false

// SDK sizes.
#define SIZEOF_BOOL 1
#define SIZEOF_INT 4

static const char WEAPON_CONFIGS_TAG[] = "[weapon-configs]";

static const char MELEE_PREFIX[] = "me_";
static const char EXPLOSIVE_PREFIX[] = "exp_";

static const char PROJECTILE_TNT[] = "tnt_projectile";
static const char PROJECTILE_FRAG[] = "grenade_projectile";
static const char PROJECTILE_MOLOTOV[] = "molotov_projectile";

static const char ITEM_BANDAGES[] = "item_bandages";
static const char ITEM_PILLS[] = "item_pills";
static const char ITEM_FIRST_AID[] = "item_first_aid";
static const char ITEM_GENE_THERAPY[] = "item_gene_therapy";
static const char ITEM_MAGLITE[] = "item_maglite";
static const char TOOL_BARRICADE[] = "tool_barricade";
static const char WEAPON_BOW[] = "bow_deerhunter";
static const char WEAPON_BARRICADE[] = "tool_barricade";

// Customizable weapon attributes.
enum eWeaponOption:
{
    WEAPON_DAMAGE_LO,
    WEAPON_DAMAGE_HI,
    WEAPON_DAMAGE_HEADSHOT_LO,
    WEAPON_DAMAGE_HEADSHOT_HI,
    WEAPON_DAMAGE_SHOVE_LO,
    WEAPON_DAMAGE_SHOVE_HI,
    WEAPON_DAMAGE_SHOVE_HEADSHOT_LO,
    WEAPON_DAMAGE_SHOVE_HEADSHOT_HI,
    WEAPON_DAMAGE_THROWN_LO,
    WEAPON_DAMAGE_THROWN_HI,
    WEAPON_DAMAGE_THROWN_HEADSHOT_LO,
    WEAPON_DAMAGE_THROWN_HEADSHOT_HI,
    WEAPON_WEIGHT,
    WEAPON_CAPACITY,
    WEAPON_STAMINA_MELEE,
    WEAPON_STAMINA_SHOVE,
    WEAPON_CAN_SUICIDE,

    // Whether weapon can enter skillshot mode. Currently Linux only.
    WEAPON_CAN_SKILLSHOT,

    // Whether weapon has a unique draw animation on first draw.
    WEAPON_ACT_FIRST_DRAW,

    // Chance for melee to pushback zombie.
    WEAPON_PUSHBACK,
    WEAPON_PUSHBACK_CHARGED,

    // Seconds till next shove.
    WEAPON_SHOVE_COOLDOWN,

    // Grenade explosion radius.
    WEAPON_RADIUS,

    // Number of seconds a grenade's fuse lasts before it detonates.
    WEAPON_FUSE,

    // Quick melee attack.
    WEAPON_QUICK_SPEED,
    WEAPON_QUICK_DELAY,

    // Melee charge-up.
    WEAPON_CHARGE_SPEED,
    WEAPON_CHARGE_DELAY,

    // Melee charge release.
    WEAPON_RELEASE_SPEED,
    WEAPON_RELEASE_DELAY,

    // Firearm shoot.
    WEAPON_HIP_FIRE_SPEED,
    WEAPON_HIP_FIRE_DELAY,

    // Firearm shoot when empty.
    WEAPON_HIP_DRYFIRE_SPEED,
    WEAPON_HIP_DRYFIRE_DELAY,

    // Firearm shoot when ironsighted.
    WEAPON_SIGHT_FIRE_SPEED,
    WEAPON_SIGHT_FIRE_DELAY,

    // Firearm shoot when ironsighted and empty.
    WEAPON_SIGHT_DRYFIRE_SPEED,
    WEAPON_SIGHT_DRYFIRE_DELAY,

    // Firearm ironsight enter.
    WEAPON_SIGHT_SPEED,
    WEAPON_SIGHT_DELAY,

    // Firearm ironsight leave.
    WEAPON_UNSIGHT_SPEED,
    WEAPON_UNSIGHT_DELAY,

    // Shove.
    WEAPON_SHOVE_SPEED,
    WEAPON_SHOVE_DELAY,

    // Reload.
    WEAPON_RELOAD_SPEED,
    WEAPON_RELOAD_DELAY,

    // Reload from empty.
    WEAPON_RELOAD_EMPTY_SPEED,
    WEAPON_RELOAD_EMPTY_DELAY,

    // Check ammo.
    WEAPON_CHECK_AMMO_SPEED,
    WEAPON_CHECK_AMMO_DELAY,

    // Unload ammo.
    WEAPON_UNLOAD_SPEED,
    WEAPON_UNLOAD_DELAY,

    // Weapon's alt-attack (barricade hammer, chainsaw, e-tool).
    WEAPON_SECONDARY_SPEED,
    WEAPON_SECONDARY_DELAY,

    // Turning maglite on.
    WEAPON_MAGLITE_ON_SPEED,
    WEAPON_MAGLITE_ON_DELAY,

    // Turning maglite off.
    WEAPON_MAGLITE_OFF_SPEED,
    WEAPON_MAGLITE_OFF_DELAY,

    WEAPON_OPTIONS_TUPLE_SIZE,

    // Use default speed/delay.
    WEAPON_DEFAULT
};

enum eWeaponType
{
    WEAPON_TYPE_BARRICADE,
    WEAPON_TYPE_BOW,
    WEAPON_TYPE_FIREARM,
    WEAPON_TYPE_OTHER
};

bool g_plugin_loaded_late;
bool g_is_linux_server;

int g_sourcemod_major;
int g_sourcemod_minor;
int g_sourcemod_patch;
int g_sourcemod_build;

bool g_ignore_ent_spawn = false;            // Don't try to intercept/handle the next spawning ent.

float g_default_flare_gun_damage;

int g_weapon_id_tnt = -1;
int g_weapon_id_grenade = -1;
int g_weapon_id_molotov = -1;

float g_weapon_options[WEAPON_MAX][WEAPON_OPTIONS_TUPLE_SIZE];

int g_player_health_before[MAXPLAYERS + 1];     // Player's health before using a medical item.
bool g_player_maglite_on[MAXPLAYERS + 1];
eWeaponType g_player_weapon_type[MAXPLAYERS + 1] = { WEAPON_TYPE_OTHER, ... };
float g_player_stamina_pre_call[MAXPLAYERS + 1] = { 0.0, ... };

int g_offset_bow_release_time;              // Game time that bow's arrow can be shot. Offset into CNMRiH_BaseBow.    
int g_offset_takedamageinfo_inflictor;
int g_offset_takedamageinfo_attacker;
int g_offset_takedamageinfo_damage;
int g_offset_takedamageinfo_damage_type;
int g_offset_gametrace_hitgroup;            // Hitgroup member of CGameTrace.

Handle g_sdkcall_weapon_is_flashlight_on;
Handle g_sdkcall_player_has_flashlight;
Handle g_sdkcall_weapon_is_flashlight_allowed;
Handle g_sdkcall_get_weapon_id;

Handle g_dhook_heal_amount;                     // Change heal amount
Handle g_dhook_medical_speed;                   // Change animation speed of medical item use.
Handle g_dhook_player_take_damage;              // Change the amount of damage players take from firearms.
Handle g_dhook_zombie_take_damage;              // Change the amount of damage zombies take from weapons.
Handle g_dhook_melee_damage;                    // Damage of melee attack.
Handle g_dhook_melee_quick_speed;               // Change animation speed of quick melee attack.
Handle g_dhook_melee_charge_speed;              // Change animation speed of melee weapon charge-up.
Handle g_dhook_melee_charge_release_speed;      // Change animation speed of melee weapon charge attack release.
Handle g_dhook_melee_secondary_speed;           // Change animation speed of weapon's secondary function.
Handle g_dhook_barricade_speed;                 // Change animation speed of placing barricade.
Handle g_dhook_firearm_shoot_speed;             // Change animation speed of weapon fire.
Handle g_dhook_firearm_sight_speed;             // Change animation speed of ironsight raising.
Handle g_dhook_firearm_unsight_speed;           // Change animation speed of ironsight lowering.
Handle g_dhook_weapon_check_ammo_speed;         // Change animation speed of ammo check.
Handle g_dhook_maglite_speed;                   // Change animation speed of maglite on its own.
Handle g_dhook_bow_shoot_speed;                 // Change animation speed of bow attack.
Handle g_dhook_weapon_capacity;                 // Change amount of ammo the weapon can hold.
Handle g_dhook_weapon_maglite_speed;            // Change animation speed of maglite when used with another weapon.
Handle g_dhook_weapon_pre_maglite_toggle;       // Store state of player's flashlight immediately before it is toggled.
Handle g_dhook_weapon_shove_cooldown;           // Change delay between shoves.
Handle g_dhook_weapon_shove_cost;               // Change cost of shove.
Handle g_dhook_weapon_shove_damage;             // Change weapon shove damage.
Handle g_dhook_weapon_shove_speed;              // Change animation speed of shove.
Handle g_dhook_weapon_thrown_damage;            // Damage of throw.
Handle g_dhook_weapon_weight;                   // Change weapon's weight.
Handle g_dhook_grenade_start_throw_speed;       // Change animation speed of grenade priming.
Handle g_dhook_grenade_finish_throw_speed;      // Change animation speed of grenade throw.
Handle g_dhook_fists_stamina_cost;              // Change stamina cost of fists.


ConVar g_cvar_weapon_configs_enabled;           // Whether the plugin is active

// The name of the weapon config to use.
ConVar g_cvar_weapon_config;

ConVar g_sv_flare_gun_explode_damage;           // Flare gun damage is implemented via existing cvar.
ConVar g_sv_skillshot_damage_modifier;          // Damage multiplier when in skillshot mode.
ConVar g_sv_max_charge_length;                  // Maximum time melee attacks can be charged for.
ConVar g_sv_melee_dmg_per_sec;                  // Multiple of base melee damage to do per second of charge

/**
 * Check if the plugin is loading late.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_plugin_loaded_late = late;
    return APLRes_Success;
}

/**
 * Prepare plugin.
 */
public void OnPluginStart()
{
    GetSourcemodVersion();

    // Game data is necesary for our DHooks/SDKCalls.
    GameData gameconf = new GameData("weapon-configs.games");
    if (!gameconf)
        SetFailState("Failed to load game data.");

    g_is_linux_server = GameConfGetOffsetOrFail(gameconf, "IsLinux") != 0;
    g_offset_bow_release_time = GameConfGetOffsetOrFail(gameconf, "CNMRiH_BaseBow::m_flMinFireTime");
    g_offset_takedamageinfo_inflictor = GameConfGetOffsetOrFail(gameconf, "CTakeDamageInfo::m_hInflictor");
    g_offset_takedamageinfo_attacker = GameConfGetOffsetOrFail(gameconf, "CTakeDamageInfo::m_hAttacker");
    g_offset_takedamageinfo_damage = GameConfGetOffsetOrFail(gameconf, "CTakeDamageInfo::m_flDamage");
    g_offset_takedamageinfo_damage_type = GameConfGetOffsetOrFail(gameconf, "CTakeDamageInfo::m_bitsDamageType");
    g_offset_gametrace_hitgroup = GameConfGetOffsetOrFail(gameconf, "CGameTrace::hitgroup");

    LoadSDKCalls(gameconf);
    LoadDHooks(gameconf);
    LoadDetours(gameconf);
    CloseHandle(gameconf);

    g_sv_flare_gun_explode_damage = FindConVar("sv_flare_gun_explode_damage");
    g_default_flare_gun_damage = g_sv_flare_gun_explode_damage.FloatValue;

    g_sv_skillshot_damage_modifier = FindConVar("sv_skillshot_damage_modifier");
    g_sv_max_charge_length = FindConVar("sv_max_charge_length");
    g_sv_melee_dmg_per_sec = FindConVar("sv_melee_dmg_per_sec");

    g_cvar_weapon_configs_enabled = CreateConVar("sm_weapon_configs_enabled", "1",
        "1 = Enable plugin. 0 = Disable plugin.");
    g_cvar_weapon_configs_enabled.AddChangeHook(ConVar_OnWeaponConfigsEnabledChange);

    g_cvar_weapon_config = CreateConVar("sm_weapon_config", "weapon-configs",
        "Name of config file in sourcemod/configs to read for weapon settings. Use empty (\"\") for normal weapon behaviour.");
    g_cvar_weapon_config.AddChangeHook(ConVar_OnWeaponConfigChange);

    CreateConVar("sm_weapon_config_version", WEAPON_CONFIGS_VERSION,
        "Weapon Configs plugin. By Ryan.",
        FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_REPLICATED);

    RegAdminCmd("sm_reload_weapon_configs", ConCommand_ReloadConfigs, ADMFLAG_GENERIC);
}

/**
 * Clean up plugin.
 */
public void OnPluginEnd()
{
    // Restore original flare gun damage.
    SetFlareGunDamage(g_default_flare_gun_damage);
}

/**
 * Refresh weapon options on demand.
 */
Action ConCommand_ReloadConfigs(int client, int args)
{
    char map[2];
    if (!GetCurrentMap(map, sizeof(map)))
    {
        ReplyToCommand(client, "Cannot reload weapon configs when no map is running");
        return Plugin_Handled;
    }

    LoadWeaponOptions(true);
    return Plugin_Handled;
}

/**
 * Refresh weapon options every map.
 */
public void OnMapStart()
{
    LoadWeaponOptions(false);

    if (g_plugin_loaded_late)
    {
        g_plugin_loaded_late = false;

        char classname[CLASSNAME_MAX];
        int max_entity_count = GetMaxEntities();
        for (int i = MaxClients; i < max_entity_count; ++i)
        {
            if (IsValidEdict(i))
            {
                GetEdictClassname(i, classname, sizeof(classname));
                HandleNewEntity(i, classname);
            }
        }

        // Hook existing players.
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientAuthorized(i) && IsClientInGame(i))
            {
                OnClientPostAdminCheck(i);
            }
        }
    }
}

/**
 * Hook newly spawned entities.
 */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (!g_ignore_ent_spawn)
    {
        HandleNewEntity(entity, classname);
    }
}

/**
 * Setup player weapon hooks.
 */
public void OnClientPostAdminCheck(int client)
{
    SDKHook(client, SDKHook_WeaponSwitch, Hook_PlayerWeaponSwitch);

    // Forcibly call WeaponSwitch for current weapon.
    int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    Hook_PlayerWeaponSwitch(IGNORE_CURRENT_WEAPON | client, active_weapon);

    // Hook player's damage
    DHookEntity(g_dhook_player_take_damage, DHOOK_PRE, client, INVALID_FUNCTION, DHook_ChangeFirearmDamage);
}

/**
 * Parse a new weapon config.
 */
void ConVar_OnWeaponConfigChange(ConVar convar, const char[] old, const char[] now)
{
    LoadWeaponOptions();
}

void ConVar_OnWeaponConfigsEnabledChange(ConVar convar, const char[] old, const char[] now)
{
    // TODO: Restore original flare gun's damage
}

/**
 * Changes an explosive to match the currently loaded weapon config.
 *
 * Need to wait 1 frame after the grenade spawns before we can set its
 * values.
 */
void OnFrame_ChangeExplosive(DataPack data)
{
    data.Reset();

    int explosive = EntRefToEntIndex(data.ReadCell());
    if (explosive != INVALID_ENT_REFERENCE && g_cvar_weapon_configs_enabled.BoolValue)
    {
        int weapon_id = data.ReadCell();

        // Change blast radius.
        float radius = g_weapon_options[weapon_id][WEAPON_RADIUS];
        if (radius >= 0.0)
        {
            SetEntPropFloat(explosive, Prop_Send, "m_DmgRadius", radius);
        }

        // Change damage.
        float damage = GetWeaponDamage(weapon_id, WEAPON_DAMAGE_LO);
        if (damage >= 0.0)
        {
            SetEntPropFloat(explosive, Prop_Send, "m_flDamage", damage);
        }

        // Change fuse length.
        float fuse = g_weapon_options[weapon_id][WEAPON_FUSE];
        if (fuse >= 0.0)
        {
            SetEntPropFloat(explosive, Prop_Data, "m_flDetonateTime", GetGameTime() + fuse);
        }
    }

    delete data;
}

/**
 * Adjust the bow's animation speed.
 *
 * The bow is different than other weapons:
 * 1) It has several stages to its fire animation
 * 2) It ignores its time fields (m_flNextAttackTime, m_flTimeWeaponIdle, etc)
 *
 * Therefore we watch the bow every frame to update its speed manually.
 *
 * @param user_id       User ID of player using bow.
 */
void OnFrame_BowShootSpeed(int user_id)
{
    int client = GetClientOfUserId(user_id);

    if (g_cvar_weapon_configs_enabled.BoolValue &&
        client != 0 &&
        IsPlayerAlive(client) &&
        g_player_weapon_type[client] == WEAPON_TYPE_BOW)
    {
        int bow = GetClientActiveWeapon(client);
        int id = GetWeaponID(bow);
        if (bow != -1 && id >= 0 && id < WEAPON_MAX)
        {
            bool check_again = true;

            int sequence = GetEntSequence(bow);
            int last_sequence = GetEntPreviousSequence(bow);

            eWeaponOption speed = WEAPON_OPTIONS_TUPLE_SIZE;
            eWeaponOption delay;
            bool start_of_attack = false;

            if (sequence == SEQUENCE_BOW_IDLE_TO_IRON)
            {
                if (last_sequence != sequence)
                {
                    speed = WEAPON_SIGHT_SPEED;
                    delay = WEAPON_SIGHT_DELAY;
                }
            }
            else if (sequence == SEQUENCE_BOW_IRON_TO_IDLE)
            {
                if (last_sequence != sequence)
                {
                    speed = WEAPON_UNSIGHT_SPEED;
                    delay = WEAPON_UNSIGHT_DELAY;

                    check_again = false;
                }
            }
            else if (sequence == SEQUENCE_BOW_FIRE ||
                sequence == SEQUENCE_BOW_FIRE_LAST)
            {
                if (last_sequence != sequence)
                {
                    speed = WEAPON_SIGHT_FIRE_SPEED;
                    delay = WEAPON_SIGHT_FIRE_DELAY;
                }
            }
            else if (sequence == SEQUENCE_BOW_STRETCHED_RELAXED ||
                sequence == SEQUENCE_BOW_STRETCHED_TENSE)
            {
                if (last_sequence != sequence)
                {
                    speed = WEAPON_SIGHT_FIRE_SPEED;
                    delay = WEAPON_SIGHT_FIRE_DELAY;

                    if (sequence == SEQUENCE_BOW_STRETCHED_RELAXED)
                    {
                        start_of_attack = true;
                    }
                }
            }
            else
            {
                check_again = false;
            }

            if (speed != WEAPON_OPTIONS_TUPLE_SIZE)
            {
                SetEntProp(bow, Prop_Send, "m_iPreviousSequence", sequence);
                ChangeBowSpeed(client, bow, g_weapon_options[id][speed], g_weapon_options[id][delay], start_of_attack);
            }

            if (check_again)
            {
                RequestFrame(OnFrame_BowShootSpeed, user_id);
            }
        }
    }
}

/**
 * Reapply the weapon's custom playback speed when it switches from idle
 * to the "medical use" sequence.
 */
void OnFrame_ChangeMedicalSpeed(DataPack data)
{
    data.Reset();

    int client = GetClientOfUserId(data.ReadCell());
    int medicine = EntRefToEntIndex(data.ReadCell());
    float old_shove_time = data.ReadFloat();

    DataPackPos last_sequence_pos = data.Position;
    int last_sequence = data.ReadCell();

    if (g_cvar_weapon_configs_enabled.BoolValue &&
        client != 0 &&
        IsPlayerAlive(client) &&
        medicine != INVALID_ENT_REFERENCE &&
        GetClientActiveWeapon(client) == medicine &&
        old_shove_time >= GetWeaponNextShoveTime(medicine))
    {
        int current_sequence = GetEntSequence(medicine);

        if (current_sequence != last_sequence)
        {
            // Reapply the weapon's custom speed.
            ChangeWeaponSpeed(medicine, WEAPON_HIP_FIRE_SPEED, WEAPON_DEFAULT);

            data.Position = last_sequence_pos;
            data.WriteCell(current_sequence);
        }

        RequestFrame(OnFrame_ChangeMedicalSpeed, data);
    }
    else
    {
        delete data;
    }
}

/**
 * Hook medical item use so their speed can be adjusted.
 *
 * Native signature:
 * bool CNMRiH_BaseMedicalItem::ShouldUseMedicalItem(void) const
 */
MRESReturn DHook_ChangeMedicalSpeed(int medicine, Handle return_handle)
{
    int owner = GetEntOwner(medicine);

    if (medicine == GetClientActiveWeapon(owner) && DHookGetReturn(return_handle))
    {
        ChangeMedicalSpeed(owner, medicine);
    }

    return MRES_Ignored;
}

/**
 * Store the amount of health a player has the moment before they use a medical
 * item. This allows us to heal the player by a custom amount after the
 * function returns.
 *
 * Native signature:
 * void CNMRiH_BaseMedicalItem::ApplyMedicalItem_Internal(void)
 */
MRESReturn DHook_ChangeMedicalHealAmountPre(int medicine)
{
    int player = GetEntOwner(medicine);
    if (player > 0 && player <= MaxClients && IsClientInGame(player))
    {
        g_player_health_before[player] = GetClientHealth(player);
    }

    return MRES_Ignored;
}

/**
 * Heal the player by a custom amount.
 *
 * Native signature:
 * void CNMRiH_BaseMedicalItem::ApplyMedicalItem_Internal(void)
 */
MRESReturn DHook_ChangeMedicalHealAmountPost(int medicine)
{
    int player = GetEntOwner(medicine);
    if (g_cvar_weapon_configs_enabled.BoolValue &&
        player > 0 &&
        player <= MaxClients &&
        IsClientInGame(player))
    {
        int weapon_id = GetWeaponID(medicine);
        float heal_amount = GetWeaponDamage(weapon_id, WEAPON_DAMAGE_LO);

        if (heal_amount >= 0.0)
        {
            int new_health = g_player_health_before[player] + RoundToNearest(heal_amount);

            int max_health = GetEntMaxHealth(player);
            if (new_health > max_health)
            {
                new_health = max_health;
            }

            SetEntityHealth(player, new_health);
        }
    }

    return MRES_Ignored;
}

/**
 * Change the damage dealt by a firearm.
 *
 * We modify a const argument.
 *
 * Native signature:
 * void CBaseEntity::TraceAttack(const CTakeDamageInfo &, const Vector &, CGameTrace *, CDmgAccumulator *)
 */
MRESReturn DHook_ChangeFirearmDamage(int victim, Handle params)
{
    const int PARAM_TAKEDAMAGEINFO = 1;
    int inflictor = DHookGetParamObjectPtrVar(params, PARAM_TAKEDAMAGEINFO,
        g_offset_takedamageinfo_inflictor, ObjectValueType_Ehandle);
    int attacker = DHookGetParamObjectPtrVar(params, PARAM_TAKEDAMAGEINFO,
        g_offset_takedamageinfo_attacker, ObjectValueType_Ehandle);
    int damage_type = DHookGetParamObjectPtrVar(params, PARAM_TAKEDAMAGEINFO,
        g_offset_takedamageinfo_damage_type, ObjectValueType_Float);

    const int PARAM_GAMETRACE = 3;
    int hitgroup = DHookGetParamObjectPtrVar(params, PARAM_GAMETRACE,
        g_offset_gametrace_hitgroup, ObjectValueType_Int);

    if (g_cvar_weapon_configs_enabled.BoolValue &&
        inflictor > MaxClients &&
        IsValidEdict(inflictor) &&
        IsBaseCombatWeapon(inflictor) &&
        attacker > 0 &&
        attacker <= MaxClients &&
        g_player_weapon_type[attacker] == WEAPON_TYPE_FIREARM &&
        (damage_type & DMG_CLUB) == 0)
    {
        int id = GetWeaponID(inflictor);
        if (id >= 0 && id < WEAPON_MAX)
        {
            float damage = GetWeaponDamageForHitgroup(id, hitgroup,
                WEAPON_DAMAGE_LO, WEAPON_DAMAGE_HEADSHOT_LO);

            if (damage >= 0.0)
            {
                // Multiply skillshot damage.
                if (HasEntProp(inflictor, Prop_Send, "_skillshotActive") &&
                    GetEntProp(inflictor, Prop_Send, "_skillshotActive") != 0)
                {
                    damage *= g_sv_skillshot_damage_modifier.FloatValue;
                }

                DHookSetParamObjectPtrVar(params, PARAM_TAKEDAMAGEINFO,
                    g_offset_takedamageinfo_damage, ObjectValueType_Float, damage);
            }
        }
    }
    return MRES_Ignored;
}

/**
 * Change a weapon's inventory weight. This also changes its select priority.
 *
 * Native signature:
 * int CBaseCombatWeapon::GetWeight() const
 */
MRESReturn DHook_ChangeWeaponWeight(int weapon, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    if (g_cvar_weapon_configs_enabled.BoolValue)
    {
        int id = GetWeaponID(weapon);
        if (id >= 0 && id < WEAPON_MAX)
        {
            float weight = g_weapon_options[id][WEAPON_WEIGHT];
            if (weight >= 0.0)
            {
                DHookSetReturn(return_handle, RoundToNearest(weight));
                result = MRES_Override;
            }
        }
    }

    return result;
}

/**
 * Change the magazine capacity of a weapon.
 *
 * Native signature:
 * int CBaseCombatWeapon::GetMaxClip1() const
 */
MRESReturn DHook_ChangeWeaponCapacity(int weapon, Handle return_handle)
{
    MRESReturn result;

    if (g_cvar_weapon_configs_enabled.BoolValue)
    {
        int id = GetWeaponID(weapon);
        if (id >= 0 && id < WEAPON_MAX && DHookGetReturn(return_handle) != -1)
        {
            float capacity = g_weapon_options[id][WEAPON_CAPACITY];
            if (capacity >= 0.0)
            {
                DHookSetReturn(return_handle, RoundToNearest(capacity));
                result = MRES_Override;
            }
        }
    }

    return result;
}

/**
 * Change melee weapon's damage.
 *
 * Native signature:
 * float CNMRiH_MeleeBase::GetMeleeDamage(CBaseEntity *, int)
 */
MRESReturn DHook_MeleeDamage(int melee, Handle return_handle, Handle params)
{
    MRESReturn result = MRES_Ignored;
    
    int id = GetWeaponID(melee);
    if (id >= 0 && id < WEAPON_MAX)
    {
        const int PARAM_HITGROUP = 2;

        int hitgroup = DHookGetParam(params, PARAM_HITGROUP);

        result = ChangeDamageUsingHitGroup(id, return_handle, hitgroup,
            WEAPON_DAMAGE_LO, WEAPON_DAMAGE_HEADSHOT_LO, melee);
    }

    return result;
}

/**
 * Adjust melee weapon's damage based on charge length.
 */
void ScaleMeleeDamage(int melee, float& damage)
{
    float chargeLength = GetEntPropFloat(melee, Prop_Send, "m_flLastChargeLength");
    if (chargeLength <= 0.0)
    {
        return;
    }

    float maxChargeLength = g_sv_max_charge_length.FloatValue;
    if (chargeLength > maxChargeLength)
    {
        chargeLength = maxChargeLength;
    }

    damage = g_sv_melee_dmg_per_sec.FloatValue * damage * chargeLength + damage;
}

/**
 * Change weapon's shove damage.
 *
 * Native signature:
 * int CNMRiH_MeleeBase::GetShoveDamage(const CGameTrace &)
 */
MRESReturn DHook_ShoveDamage(int melee, Handle return_handle, Handle params)
{
    const int PARAM_GAMETRACE = 1;
    return ChangeDamageUsingGameTrace(melee, return_handle, params,
        PARAM_GAMETRACE, WEAPON_DAMAGE_SHOVE_LO, WEAPON_DAMAGE_SHOVE_HEADSHOT_LO);
}

/**
 * Change weapon throw damage.
 *
 * Native signature:
 * int CNMRiH_WeaponBase::GetThrownDamage(const CGameTrace &)
 */
MRESReturn DHook_WeaponThrowDamage(int weapon, Handle return_handle, Handle params)
{
    const int PARAM_GAMETRACE = 1;
    return ChangeDamageUsingGameTrace(weapon, return_handle, params,
        PARAM_GAMETRACE, WEAPON_DAMAGE_THROWN_LO, WEAPON_DAMAGE_THROWN_HEADSHOT_LO);
}

/**
 * Change speed of quick melee attack.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::QuickAttack()
 */
MRESReturn DHook_MeleeQuickSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_QUICK_SPEED, WEAPON_QUICK_DELAY);
    return MRES_Ignored;
}

/**
 * Change melee weapon charge speed.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::ChargeBash()
 */
MRESReturn DHook_MeleeChargeSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_CHARGE_SPEED, WEAPON_CHARGE_DELAY);
    return MRES_Ignored;
}

/**
 * Change melee weapon charge attack speed.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::FinishBash(bool)
 */
MRESReturn DHook_MeleeChargeReleaseSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_RELEASE_SPEED, WEAPON_RELEASE_DELAY);
    return MRES_Ignored;
}

/**
 * Change animation speed of melee secondary attack.
 *
 * Native signature:
 * void CBaseCombatWeapon::SecondaryAttack()
 */
MRESReturn DHook_MeleeSecondarySpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_SECONDARY_SPEED, WEAPON_SECONDARY_DELAY);
    return MRES_Ignored;
}

/**
 * Change animation speed of placing barricade.
 *
 * Native signature:
 * void CBaseCombatWeapon::PrimaryAttack()
 */
MRESReturn DHook_BarricadeSpeed(int hammer)
{
    ChangeWeaponSpeed(hammer, WEAPON_HIP_FIRE_SPEED, WEAPON_HIP_FIRE_DELAY);
    return MRES_Ignored;
}

/**
 * Change animation speed of checking ammo.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::CheckAmmo()
 */
MRESReturn DHook_FirearmCheckAmmo(int firearm)
{
    ChangeWeaponSpeed(firearm, WEAPON_CHECK_AMMO_SPEED, WEAPON_CHECK_AMMO_DELAY);
    return MRES_Ignored;
}

/**
 * Start monitoring the bow so its draw and fire animations playback
 * rate can be adjusted.
 *
 * Native signature:
 * void CBaseCombatWeapon::PrimaryAttack()
 */
MRESReturn DHook_BowShootSpeed(int bow)
{
    int player = GetEntOwner(bow);
    int user_id = GetClientUserId(player);
    int weapon_id = GetWeaponID(bow);

    if (g_cvar_weapon_configs_enabled.BoolValue &&
        weapon_id >= 0 &&
        weapon_id < WEAPON_MAX && GetEntSequence(bow) == SEQUENCE_BOW_IDLE_TO_IRON)
    {
        ChangeBowSpeed(player, bow, g_weapon_options[weapon_id][WEAPON_SIGHT_SPEED],
            g_weapon_options[weapon_id][WEAPON_SIGHT_DELAY], true);
        OnFrame_BowShootSpeed(user_id);
    }
    
    return MRES_Ignored;
}


/**
 * Change delay between shoves.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::SetBashActionTime(float, bool)
 */
public MRESReturn DHook_ChangeWeaponShoveCooldown(int weapon, Handle params)
{
    // Change shove cooldown.
    if (g_cvar_weapon_configs_enabled.BoolValue &&
        IsValidEdict(weapon) &&
        IsBaseCombatWeapon(weapon))
    {
        int id = GetWeaponID(weapon);
        if (id >= 0 && id < WEAPON_MAX)
        {
            float cooldown = g_weapon_options[id][WEAPON_SHOVE_COOLDOWN];
            if (cooldown >= 0.0)
            {
                float now = GetGameTime();
                SetWeaponNextShoveTime(weapon, now + cooldown);
            }
        }
    }

    return MRES_Ignored;
}

/**
 * Store the player's current stamina amount.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::DoShove(void)
 */
MRESReturn DHook_ChangeWeaponShoveCostPre(int weapon)
{
    StoreCurrentStamina(weapon);
    return MRES_Ignored;
}

/**
 * Change the amount of stamina drained by shove.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::DoShove(void)
 */
MRESReturn DHook_ChangeWeaponShoveCostPost(int weapon)
{
    ChangeStaminaCost(weapon, WEAPON_STAMINA_SHOVE);
    return MRES_Ignored;
}

/**
 * Change animation speed of shove.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::StartShove()
 */
MRESReturn DHook_WeaponShoveSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_SHOVE_SPEED, WEAPON_SHOVE_DELAY);

    return MRES_Ignored;
}

/**
 * Change grenade's priming animation speed to use "charge" rate.
 *
 * Native signature:
 * void CBaseCombatWeapon::PrimaryAttack()
 */
MRESReturn DHook_GrenadeStartThrowSpeed(int grenade)
{
    ChangeWeaponSpeed(grenade, WEAPON_CHARGE_SPEED, WEAPON_CHARGE_DELAY);
    return MRES_Ignored;
}

/**
 * Change grenade's throw animation speed to use "release" rate.
 *
 * Native signature:
 * void CWeaponGrenade::EmitGrenade(Vector *,QAngle *,Vector *,Vector *,CBasePlayer *,CWeaponSDKBase *)
 */
MRESReturn DHook_GrenadeFinishThrowSpeed(int grenade)
{
    if (g_cvar_weapon_configs_enabled.BoolValue)
    {
        // Delay playback change by 1 frame.
        RequestFrame(OnFrame_GrenadeFinishThrowSpeed, EntIndexToEntRef(grenade));
    }
    return MRES_Ignored;
}

/**
 * Store the player's stamina before a punch.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::DoMeleeSwing(int)
 */
MRESReturn DHook_ChangeFistsStaminaPre(int fists)
{
    StoreCurrentStamina(fists);
    return MRES_Ignored;
}

/**
 * Change the stamina cost of fists on Windows. Linux is already handled via
 * our detour.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::DoMeleeSwing(int)
 */
MRESReturn DHook_ChangeFistsStaminaPost(int fists)
{
    ChangeStaminaCost(fists, WEAPON_STAMINA_MELEE);
    return MRES_Ignored;
}

/**
 * Change pushback chance of melee attack.
 *
 * Native signature:
 * bool CNMRiH_MeleeBase::ShouldMeleePushback()
 */
MRESReturn Detour_MeleePushbackPost(int melee, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    int id = GetWeaponID(melee);
    if (id >= 0 && id < WEAPON_MAX)
    {
        int weapon_option = WEAPON_PUSHBACK;
        if (GetEntPropFloat(melee, Prop_Send, "m_flLastBeginCharge") != -1.0)
        {
            weapon_option = WEAPON_PUSHBACK_CHARGED;
        }

        char classname[CLASSNAME_MAX];
        GetEdictClassname(melee, classname, sizeof(classname));

        float pushback = g_weapon_options[id][weapon_option];
        if (pushback >= 0.0)
        {
            DHookSetReturn(return_handle, pushback > (GetURandomFloat() * 100.0));
            result = MRES_Override;
        }
    }

    return result;
}


/**
 * Store player's stamina before melee drain.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::DrainMeleeSwingStamina(void)
 */
MRESReturn Detour_MeleeStaminaPre(int weapon)
{
    StoreCurrentStamina(weapon);
    return MRES_Ignored;
}

/**
 * Use custom melee stamina cost.
 *
 * Native signature:
 * void CNMRiH_MeleeBase::DrainMeleeSwingStamina(void)
 */
MRESReturn Detour_MeleeStaminaPost(int weapon)
{
    ChangeStaminaCost(weapon, WEAPON_STAMINA_MELEE);
    return MRES_Ignored;
}

/**
 * Change firearm's unload animation speed.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::Unload()
 */
MRESReturn Detour_FirearmUnloadSpeedPost(int firearm)
{
    ChangeWeaponSpeed(firearm, WEAPON_UNLOAD_SPEED, WEAPON_UNLOAD_DELAY);
    return MRES_Ignored;
}

/**
 * Set whether a weapon can enter skillshot mode.
 *
 * Native signature:
 * bool CNMRiH_WeaponBase::AllowsSuicide()
 */
MRESReturn Detour_CanSuicidePost(int weapon, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    int id = GetWeaponID(weapon);
    if (id >= 0 && id < WEAPON_MAX)
    {
        float suicide = g_weapon_options[id][WEAPON_CAN_SUICIDE];
        if (suicide >= 0.0)
        {
            DHookSetReturn(return_handle, suicide > 0.0);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * This callback is necessary to create a post-detour.
 *
 * Native signature:
 * bool CNMRiH_WeaponBase::IsSkillshotModeAvailable()
 */
public MRESReturn Detour_CanSkillshotPre(int weapon, Handle return_handle)
{
    return MRES_Ignored;
}

/**
 * Set whether a weapon can enter skillshot mode.
 *
 * Native signature:
 * bool CNMRiH_WeaponBase::IsSkillshotModeAvailable()
 */
public MRESReturn Detour_CanSkillshotPost(int weapon, Handle return_handle)
{
    MRESReturn result = MRES_Ignored;

    int id = GetWeaponID(weapon);
    if (id >= 0 && id < WEAPON_MAX)
    {
        float skillshot = g_weapon_options[id][WEAPON_CAN_SKILLSHOT];
        if (skillshot >= 0.0)
        {
            DHookSetReturn(return_handle, skillshot > 0.0);
            result = MRES_Override;
        }
    }

    return result;
}

/**
 * Change grenade's throw animation speed.
 */
void OnFrame_GrenadeFinishThrowSpeed(int grenade_ref)
{
    int grenade = EntRefToEntIndex(grenade_ref);
    if (grenade != INVALID_ENT_REFERENCE)
    {
        ChangeWeaponSpeed(grenade, WEAPON_RELEASE_SPEED, WEAPON_RELEASE_DELAY);
    }
}

/**
 * Cache the type of weapon equipped by each player. One string compare here
 * is faster than repeated string comparisons later.
 *
 * @param client        Client that switched weapons.
 * @param weapon        Edict of weapon the player switched to.
 */
Action Hook_PlayerWeaponSwitch(int client, int weapon)
{
    static const char FIREARM_PREFIX[] = "fa_";

    bool ignore_current_weapon = (client & IGNORE_CURRENT_WEAPON) != 0;
    client &= ~IGNORE_CURRENT_WEAPON;

    int active_weapon = GetClientActiveWeapon(client);
    if (IsValidEdict(weapon) && (ignore_current_weapon || weapon != active_weapon))
    {
        char weapon_name[CLASSNAME_MAX];
        if (IsClassnameEqual(weapon, weapon_name, sizeof(weapon_name), WEAPON_BARRICADE))
        {
            g_player_weapon_type[client] = WEAPON_TYPE_BARRICADE;
        }
        else if (StrEqual(weapon_name, WEAPON_BOW))
        {
            g_player_weapon_type[client] = WEAPON_TYPE_BOW;
        }
        else if (!strncmp(weapon_name, FIREARM_PREFIX, sizeof(FIREARM_PREFIX) - 1))
        {
            g_player_weapon_type[client] = WEAPON_TYPE_FIREARM;
        }
        else
        {
            g_player_weapon_type[client] = WEAPON_TYPE_OTHER;
        }
    }
    else if (weapon != active_weapon)
    {
        g_player_weapon_type[client] = WEAPON_TYPE_OTHER;
    }

    OverrideFirstDrawActivity(weapon);

    return Plugin_Continue;
}

void OverrideFirstDrawActivity(int weapon)
{
    if (!g_cvar_weapon_configs_enabled.BoolValue)
    {
        return;
    } 

    // Override first draw activity
    int id = GetWeaponID(weapon);
    if (id >= 0 && id < WEAPON_MAX && g_weapon_options[id][WEAPON_ACT_FIRST_DRAW] == 0)
    {
        SetEntProp(weapon, Prop_Send, "m_bDeployedOnce", true);
    }
}

/**
 * Change the explosive properties of TNT.
 */
Action Hook_ChangeTNT(int tnt)
{
    if (IsValidEdict(tnt))
    {
        ChangeExplosive(tnt, g_weapon_id_tnt, "exp_tnt");
    }
    return Plugin_Continue;
}

/**
 * Change the explosive properties of frag grenades.
 */
Action Hook_ChangeFragGrenade(int grenade)
{
    if (IsValidEdict(grenade))
    {
        ChangeExplosive(grenade, g_weapon_id_grenade, "exp_grenade");
    }
    return Plugin_Continue;
}

/**
 * Change molotov properties.
 */
Action Hook_ChangeMolotov(int molotov)
{
    if (IsValidEdict(molotov))
    {
        ChangeExplosive(molotov, g_weapon_id_molotov, "exp_molotov");
    }
    return Plugin_Continue;
}

/**
 * Change reload speed of firearm.
 */
Action Hook_ChangeReloadSpeed(int firearm)
{
    if (!g_cvar_weapon_configs_enabled.BoolValue)
    {
        return Plugin_Continue;
    }

    int player = GetEntOwner(firearm);
    int id = GetWeaponID(firearm);

    if (player != -1 && id >= 0 && id < WEAPON_MAX)
    {
        int clip = GetEntProp(firearm, Prop_Send, "m_iClip1");
        float rate = g_weapon_options[id][clip == 0 ? WEAPON_RELOAD_EMPTY_SPEED : WEAPON_RELOAD_SPEED];
        float delay = g_weapon_options[id][clip == 0 ? WEAPON_RELOAD_EMPTY_DELAY : WEAPON_RELOAD_DELAY];
        float now = GetGameTime();

        if (rate > 0.0)
        {
            // Change animation speed.
            SetEntPropFloat(firearm, Prop_Send, "m_flPlaybackRate", rate);
            int view_model = GetEntPropEnt(player, Prop_Send, "m_hViewModel");
            if (view_model != -1)
            {
                SetEntPropFloat(view_model, Prop_Send, "m_flPlaybackRate", rate);
            }
        }
        else
        {
            rate = 1.0;
        }

        float new_attack = -1.0;
        if (delay >= 0.0)
        {
            // Use fixed time offset for next attack.
            new_attack = now + delay;
        }
        else if (rate != 1.0)
        {
            // Scale next attack time according to playback rate.
            float normal_attack = GetEntPropFloat(firearm, Prop_Send, "m_flNextPrimaryAttack");
            new_attack = now + ((normal_attack - now) / rate);
        }

        if (new_attack != -1.0)
        {
            // Change weapon's time till next attack.
            SetEntPropFloat(firearm, Prop_Send, "m_flNextPrimaryAttack", new_attack + 0.1);
            SetEntPropFloat(firearm, Prop_Send, "m_flNextSecondaryAttack", new_attack + 0.1);
            SetEntPropFloat(firearm, Prop_Send, "m_flTimeWeaponIdle", new_attack + 0.1);

            // Change player's time till next attack.
            SetEntPropFloat(player, Prop_Send, "m_flNextAttack", new_attack);
        }
    }

    return Plugin_Continue;
}

/**
 * Change animation speed of firearm attack.
 *
 * Native signature:
 * void CBaseCombatWeapon::PrimaryAttack()
 */
MRESReturn DHook_FirearmShootSpeed(int weapon)
{
    int player = GetEntOwner(weapon);

    if (player != -1)
    {
        eWeaponOption speed;
        eWeaponOption delay;

        if (GetEntProp(weapon, Prop_Send, "m_bIsInIronsights"))
        {
            speed = WEAPON_SIGHT_FIRE_SPEED;
            delay = WEAPON_SIGHT_FIRE_DELAY;
        }
        else
        {
            speed = WEAPON_HIP_FIRE_SPEED;
            delay = WEAPON_HIP_FIRE_DELAY;
        }

        ChangeWeaponSpeed(weapon, speed, delay);
    }

    return MRES_Ignored;
}

/**
 * Change animation speed of ironsight raising.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::TurnOnIronsights()
 */
MRESReturn DHook_FirearmSightSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_SIGHT_SPEED, WEAPON_SIGHT_DELAY);
    return MRES_Ignored;
}

/**
 * Change animation speed of ironsight lowering.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::TurnOffIronsights()
 */
MRESReturn DHook_FirearmUnsightSpeed(int weapon)
{
    ChangeWeaponSpeed(weapon, WEAPON_UNSIGHT_SPEED, WEAPON_UNSIGHT_DELAY);
    return MRES_Ignored;
}

/**
 * Change animation speed of maglite's secondary attack.
 *
 * Native signature:
 * void CBaseCombatWeapon::SecondaryAttack()
 */
MRESReturn DHook_MagliteSpeed(int maglite)
{
    ChangeMagliteSpeed(maglite, SDKCall(g_sdkcall_weapon_is_flashlight_on, maglite));
    return MRES_Ignored;
}

/**
 * Store flashlight state.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::ToggleFlashlight()
 */
MRESReturn DHook_WeaponPreMagliteToggle(int weapon)
{
    int owner = GetEntOwner(weapon);
    if (owner != -1)
    {
        g_player_maglite_on[owner] = SDKCall(g_sdkcall_weapon_is_flashlight_on, weapon);
    }
    return MRES_Ignored;
}

/**
 * Change animation speed of maglite on/off when used with another weapon.
 *
 * Native signature:
 * void CNMRiH_WeaponBase::ToggleFlashlight()
 */
MRESReturn DHook_WeaponMagliteSpeed(int weapon)
{
    int owner = GetEntOwner(weapon);

    // Player must have maglite.
    if (owner != -1 &&
        SDKCall(g_sdkcall_player_has_flashlight, owner) &&
        SDKCall(g_sdkcall_weapon_is_flashlight_allowed, weapon))
    {
        ChangeMagliteSpeed(weapon, g_player_maglite_on[owner]);
    }

    return MRES_Ignored;
}

/**
 * Override the returned damage value based on whether the CGameTrace argument
 * hit an enemy's head.
 *
 * @param weapon            Ent index of player's weapon.
 * @param return_handle     DHook return handle whose returned value will be changed.
 * @param params            DHooked function's parameter handle.
 * @param gametrace_arg     Index of CGameTrace argument in params (1-based).
 * @param normal_damage     Weapon option to use if trace was not a headshot.
 * @param headshot_damage   Weapon option to use if trace was a headshot.
 */
MRESReturn ChangeDamageUsingGameTrace(int weapon, Handle return_handle, Handle params,
    int gametrace_arg, eWeaponOption normal_damage, eWeaponOption headshot_damage)
{
    MRESReturn result = MRES_Ignored;

    if (g_cvar_weapon_configs_enabled.BoolValue)
    {
        int id = GetWeaponID(weapon);
        if (id >= 0 && id < WEAPON_MAX)
        {
            int hitgroup = DHookGetParamObjectPtrVar(params, gametrace_arg,
            g_offset_gametrace_hitgroup, ObjectValueType_Int);

            result = ChangeDamageUsingHitGroup(id, return_handle, hitgroup,
                normal_damage, headshot_damage);
        }
    }

    return result;
}

/**
 * Change the amount of damage dealt according to the hitgroup hit.
 */
MRESReturn ChangeDamageUsingHitGroup(int weapon_id, Handle return_handle,
    int hitgroup, eWeaponOption normal_damage, eWeaponOption headshot_damage, int melee_idx = -1)
{
    float damage = GetWeaponDamageForHitgroup(weapon_id, hitgroup,
        normal_damage, headshot_damage);

    if (damage < 0.0)
    {
        return MRES_Ignored;
    }

    if (melee_idx != -1)
    {
        ScaleMeleeDamage(melee_idx, damage);
    }

    DHookSetReturn(return_handle, damage);
    return MRES_Override;
}

/**
 * Get the amount of damage a weapon should deal based on which hitgroup
 * it hit.
 */
float GetWeaponDamageForHitgroup(int weapon_id, int hitgroup,
    eWeaponOption normal_damage, eWeaponOption headshot_damage)
{
    eWeaponOption weapon_option = normal_damage;
    if (hitgroup == HITGROUP_HEAD || hitgroup == HITGROUP_BRAINSTEM)
    {
        weapon_option = headshot_damage;
    }

    float damage = GetWeaponDamage(weapon_id, weapon_option);

    // If the weapon doesn't have headshot damage defined, fallback to its
    // normal damage.
    if (damage < 0.0 && weapon_option == headshot_damage)
    {
        damage = GetWeaponDamage(weapon_id, normal_damage);
    }

    return damage;
}

/**
 * Change an explosive projectile's properties.
 */
void ChangeExplosive(int explosive, int &weapon_id, const char[] classname)
{
    if (!g_cvar_weapon_configs_enabled.BoolValue)
    {
        return;
    }

    if (weapon_id == -1)
    {
        weapon_id = GetWeaponIDFromClassname(classname);
    }

    if (weapon_id >= 0 && weapon_id < WEAPON_MAX)
    {
        DataPack data = CreateDataPack();

        data.WriteCell(EntIndexToEntRef(explosive));
        data.WriteCell(weapon_id);

        RequestFrame(OnFrame_ChangeExplosive, data);
    }
}

/**
 * Change bow's attack speed.
 */
void ChangeBowSpeed(int client, int bow, float rate, float delay, bool start_of_attack)
{
    if (!g_cvar_weapon_configs_enabled.BoolValue)
    {
        return;
    }

    float now = GetGameTime();

    if (rate <= 0.0)
    {
        rate = 1.0;
    }

    // Change animation speed.
    SetEntPropFloat(bow, Prop_Send, "m_flPlaybackRate", rate);
    int view_model = GetEntPropEnt(client, Prop_Send, "m_hViewModel");
    if (view_model != -1)
    {
        SetEntPropFloat(view_model, Prop_Send, "m_flPlaybackRate", rate);
    }

    if (start_of_attack)
    {
        float normal_release = GetEntDataFloat(bow, g_offset_bow_release_time);
        float new_release = normal_release;

        if (delay >= 0.0)
        {
            new_release = now + delay;
        }
        else if (rate != 1.0)
        {
            // Sync arrow's release time to animation.
            new_release = now + ((normal_release - now) / rate);
        }

        SetEntDataFloat(bow, g_offset_bow_release_time, new_release);
    }

    int seq = GetEntSequence(bow);
    if (seq == SEQUENCE_BOW_FIRE || seq == SEQUENCE_BOW_FIRE_LAST)
    {
        // Change weapon's time till next attack.
        float normal_attack = GetEntPropFloat(bow, Prop_Send, "m_flNextPrimaryAttack");
        float new_attack = normal_attack;

        if (delay >= 0.0)
        {
            new_attack = now + delay;
        }
        else if (rate != 1.0)
        {
            new_attack = now + ((normal_attack - now) / rate);
        }

        SetEntPropFloat(bow, Prop_Send, "m_flNextPrimaryAttack", new_attack);
        SetEntPropFloat(bow, Prop_Send, "m_flNextSecondaryAttack", new_attack);
    }

    // Change weapon's next idle time.
    float normal_idle = GetEntPropFloat(bow, Prop_Send, "m_flTimeWeaponIdle");
    float new_idle = normal_idle;

    if (delay >= 0.0)
    {
        new_idle = now + delay;
    }
    else
    {
        new_idle = now + ((normal_idle - now) / rate);
    }

    SetEntPropFloat(bow, Prop_Send, "m_flTimeWeaponIdle", new_idle);
}

/**
 * Change animation speed of maglite on/off.
 *
 * @param weapon    Weapon whose speed will be changed.
 * @param is_on     True if the maglite is on and should turn off.
 */
void ChangeMagliteSpeed(int weapon, bool is_on)
{
    eWeaponOption speed = WEAPON_MAGLITE_ON_SPEED;
    eWeaponOption delay = WEAPON_MAGLITE_ON_DELAY;

    if (is_on)
    {
        speed = WEAPON_MAGLITE_OFF_SPEED;
        delay = WEAPON_MAGLITE_OFF_DELAY;
    }

    ChangeWeaponSpeed(weapon, speed, delay);
}

/**
 * Begin watching the medical weapon to reapply the customized playback rate
 * as it is otherwise reset whenever its sequence changes.
 */
void ChangeMedicalSpeed(int client, int medicine)
{
    if (g_cvar_weapon_configs_enabled.BoolValue)
    {
        DataPack data = CreateDataPack();
        data.WriteCell(GetClientUserId(client));
        data.WriteCell(EntIndexToEntRef(medicine));
        data.WriteFloat(GetWeaponNextShoveTime(medicine));
        data.WriteCell(GetEntSequence(medicine));

        OnFrame_ChangeMedicalSpeed(data);
    }
}

/**
 * Change weapon animation speed.
 */
void ChangeWeaponSpeed(int weapon, eWeaponOption speed, eWeaponOption speed_delay)
{
    if (!g_cvar_weapon_configs_enabled.BoolValue)
    {
        return;
    }

    int player = GetEntOwner(weapon);
    int id = GetWeaponID(weapon);

    if (player != -1 && id >= 0 && id < WEAPON_MAX)
    {
        float rate = speed < WEAPON_OPTIONS_TUPLE_SIZE ? g_weapon_options[id][speed] : -1.0;
        float delay = speed_delay < WEAPON_OPTIONS_TUPLE_SIZE ? g_weapon_options[id][speed_delay] : -1.0;
        float now = GetGameTime();

        char classname[CLASSNAME_MAX];
        GetEdictClassname(weapon, classname, sizeof(classname));

        // Change animation rate.
        if (rate > 0.0)
        {
            SetEntPropFloat(weapon, Prop_Send, "m_flPlaybackRate", rate);
            int view_model = GetEntPropEnt(player, Prop_Send, "m_hViewModel");
            if (view_model != -1)
            {
                SetEntPropFloat(view_model, Prop_Send, "m_flPlaybackRate", rate);
            }
        }
        else
        {
            rate = 1.0;
        }

        if (delay >= 0.0)
        {
            // Make weapon ready for another attack at specific time.
            float next_time = now + delay;

            if (HasEntProp(weapon, Prop_Send, "m_flLastBeginCharge") &&
                GetEntPropFloat(weapon, Prop_Send, "m_flLastBeginCharge") != -1.0)
            {
                SetEntPropFloat(weapon, Prop_Send, "m_flLastBeginCharge", next_time);
            }

            SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", next_time);
            SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", next_time);

            SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", next_time);
        }
        else if (rate != 1.0)
        {
            // Adjust weapon's ready time according to rate of animation change.

            // Change weapon's time till next charge attack.
            if (HasEntProp(weapon, Prop_Send, "m_flLastBeginCharge"))
            {
                float normal_charge = GetEntPropFloat(weapon, Prop_Send, "m_flLastBeginCharge");
                if (normal_charge != -1.0)
                {
                    float new_charge = now + ((normal_charge - now) / rate);
                    SetEntPropFloat(weapon, Prop_Send, "m_flLastBeginCharge", new_charge);
                }
            }

            // Change weapon's time till next attack.
            float normal_attack = GetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack");
            float new_attack = now + ((normal_attack - now) / rate);
            SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", new_attack);
            SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", new_attack);

            // Change weapon's next idle time.
            float normal_idle = GetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle");
            float new_idle = now + ((normal_idle - now) / rate);
            SetEntPropFloat(weapon, Prop_Send, "m_flTimeWeaponIdle", new_idle);
        }
    }
}

/**
 * Store a player's current stamina amount. This is used to adjust the amount
 * of stamina drained by melee attacks and shoves.
 */
void StoreCurrentStamina(int weapon)
{
    if (IsValidEdict(weapon))
    {
        int player = GetEntOwner(weapon);
        if (player > 0 && player <= MaxClients)
        {
            g_player_stamina_pre_call[player] = GetPlayerStamina(player);
        }
    }
}

/**
 * Reduce the player's stamina by a custom amount.
 */
void ChangeStaminaCost(int weapon, eWeaponOption cost)
{
    if (g_cvar_weapon_configs_enabled.BoolValue && IsValidEdict(weapon))
    {
        int player = GetEntOwner(weapon);
        if (player > 0 && player <= MaxClients)
        {
            int id = GetWeaponID(weapon);
            if (id >= 0 && id < WEAPON_MAX)
            {
                float current_stamina = GetPlayerStamina(player);
                float previous_stamina = g_player_stamina_pre_call[player];
                float stamina_cost = g_weapon_options[id][view_as<int>(cost)];

                if (stamina_cost >= 0.0 &&
                    current_stamina < previous_stamina)
                {
                    float new_stamina = previous_stamina - stamina_cost;
                    SetPlayerStamina(player, new_stamina);
                }
            }
        }
    }
}

/**
 * Return true if an entity is a weapon/item.
 */
bool IsBaseCombatWeapon(int entity)
{
    return HasEntProp(entity, Prop_Send, "m_flNextPrimaryAttack");
}

/**
 * Retrieve weapon's ID. It's faster to compare IDs than strings.
 */
int GetWeaponID(int weapon)
{
    return SDKCall(g_sdkcall_get_weapon_id, weapon);
}

/**
 * Spawn a temporary weapon by classname and retrieve its weapon ID.
 */
int GetWeaponIDFromClassname(const char[] classname)
{
    int id = -1;

    int weapon = CreateEntityByNameWithoutHooks(classname);
    if (weapon != -1)
    {
        if (IsBaseCombatWeapon(weapon))
        {
            id = GetWeaponID(weapon);
        }
        else
        {
            LogError("%s Warning: Invalid weapon '%s'", WEAPON_CONFIGS_TAG, classname);
        }

        RemoveEdict(weapon);
    }
    else
    {
        LogError("%s Warning: Unknown weapon '%s'", WEAPON_CONFIGS_TAG, classname);
    }

    return id;
}

/**
 * Return true if classname is a medical item.
 */
bool IsMedicalWeaponClassname(const char[] classname)
{
    return StrEqual(classname, ITEM_BANDAGES) ||
        StrEqual(classname, ITEM_PILLS) ||
        StrEqual(classname, ITEM_FIRST_AID) ||
        StrEqual(classname, ITEM_GENE_THERAPY);
}

/**
 * Return true if classname is a melee weapon.
 */
bool IsMeleeWeaponClassname(const char[] classname)
{
    static const char TOOL_PREFIX[] = "tool_";

    return StrEqual(classname, ITEM_MAGLITE) ||
        !strncmp(classname, MELEE_PREFIX, sizeof(MELEE_PREFIX) - 1) ||
        (!strncmp(classname, TOOL_PREFIX, sizeof(TOOL_PREFIX) - 1) && !StrEqual(classname[sizeof(TOOL_PREFIX) - 1], "flare_gun"));
}

/**
 * Spawn an entity without modifying it any way. This is useful when we
 * want to check the default values of an entity (e.g. a weapon's firemode).
 */
int CreateEntityByNameWithoutHooks(const char[] classname)
{
    g_ignore_ent_spawn = true;

    int ent = CreateEntityByName(classname);

    g_ignore_ent_spawn = false;

    return ent;
}

/**
 * Setup the hooks used to modify weapon behaviour.
 */
void HandleNewEntity(int entity, const char[] classname)
{
    static const char NPC_PREFIX[] = "npc_nmrih_";
    static const DHookRemovalCB N = INVALID_FUNCTION;

    if (!strncmp(classname, NPC_PREFIX, sizeof(NPC_PREFIX) - 1))
    {
        DHookEntity(g_dhook_zombie_take_damage, DHOOK_PRE, entity, N, DHook_ChangeFirearmDamage);
    }
    else if (StrEqual(classname, TOOL_BARRICADE))
    {
        DHookEntity(g_dhook_barricade_speed, DHOOK_POST, entity, N, DHook_BarricadeSpeed);
    }
    else if (IsMedicalWeaponClassname(classname))
    {
        DHookEntity(g_dhook_medical_speed, DHOOK_POST, entity, N, DHook_ChangeMedicalSpeed);

        DHookEntity(g_dhook_heal_amount, DHOOK_PRE, entity, N, DHook_ChangeMedicalHealAmountPre);
        DHookEntity(g_dhook_heal_amount, DHOOK_POST, entity, N, DHook_ChangeMedicalHealAmountPost);
    }
    else if (StrEqual(classname, PROJECTILE_TNT))
    {
        SDKHook(entity, SDKHook_SpawnPost, Hook_ChangeTNT);
    }
    else if (StrEqual(classname, PROJECTILE_FRAG))
    {
        SDKHook(entity, SDKHook_SpawnPost, Hook_ChangeFragGrenade);
    }
    else if (StrEqual(classname, PROJECTILE_MOLOTOV))
    {
        SDKHook(entity, SDKHook_SpawnPost, Hook_ChangeMolotov);
    }

    if (IsBaseCombatWeapon(entity))
    {
        bool maglite = false;

        if (IsMeleeWeaponClassname(classname))
        {
            DHookEntity(g_dhook_melee_damage, DHOOK_POST, entity, N, DHook_MeleeDamage);

            DHookEntity(g_dhook_melee_quick_speed, DHOOK_POST, entity, N, DHook_MeleeQuickSpeed);
            DHookEntity(g_dhook_melee_charge_speed, DHOOK_POST, entity, N, DHook_MeleeChargeSpeed);
            DHookEntity(g_dhook_melee_charge_release_speed, DHOOK_POST, entity, N, DHook_MeleeChargeReleaseSpeed);
            DHookEntity(g_dhook_melee_secondary_speed, DHOOK_POST, entity, N, DHook_MeleeSecondarySpeed);

            // Handle fist stamina cost on Windows.
            if (!g_is_linux_server && StrEqual(classname, "me_fists"))
            {
                DHookEntity(g_dhook_fists_stamina_cost, DHOOK_PRE, entity, N, DHook_ChangeFistsStaminaPre);
                DHookEntity(g_dhook_fists_stamina_cost, DHOOK_POST, entity, N, DHook_ChangeFistsStaminaPost);
            }

            maglite = StrEqual(classname, ITEM_MAGLITE);
        }
        else if (!strncmp(classname, EXPLOSIVE_PREFIX, sizeof(EXPLOSIVE_PREFIX) - 1))
        {
            DHookEntity(g_dhook_grenade_start_throw_speed, DHOOK_POST, entity, N, DHook_GrenadeStartThrowSpeed);
            DHookEntity(g_dhook_grenade_finish_throw_speed, DHOOK_POST, entity, N, DHook_GrenadeFinishThrowSpeed);
        }
        else if (StrEqual(classname, WEAPON_BOW))
        {
            DHookEntity(g_dhook_bow_shoot_speed, DHOOK_POST, entity, N, DHook_BowShootSpeed);
        }
        else
        {
            SDKHook(entity, SDKHook_ReloadPost, Hook_ChangeReloadSpeed);
            DHookEntity(g_dhook_firearm_shoot_speed, DHOOK_POST, entity, N, DHook_FirearmShootSpeed);
            DHookEntity(g_dhook_firearm_sight_speed, DHOOK_POST, entity, N, DHook_FirearmSightSpeed);
            DHookEntity(g_dhook_firearm_unsight_speed, DHOOK_POST, entity, N, DHook_FirearmUnsightSpeed);
        }

        // Change weapon damage.
        DHookEntity(g_dhook_weapon_shove_damage, DHOOK_POST, entity, N, DHook_ShoveDamage);
        DHookEntity(g_dhook_weapon_thrown_damage, DHOOK_POST, entity, N, DHook_WeaponThrowDamage);

        DHookEntity(g_dhook_weapon_capacity, DHOOK_POST, entity, N, DHook_ChangeWeaponCapacity);
        DHookEntity(g_dhook_weapon_shove_cooldown, DHOOK_POST, entity, N, DHook_ChangeWeaponShoveCooldown);
        DHookEntity(g_dhook_weapon_shove_cost, DHOOK_PRE, entity, N, DHook_ChangeWeaponShoveCostPre);
        DHookEntity(g_dhook_weapon_shove_cost, DHOOK_POST, entity, N, DHook_ChangeWeaponShoveCostPost);
        DHookEntity(g_dhook_weapon_shove_speed, DHOOK_POST, entity, N, DHook_WeaponShoveSpeed);
        DHookEntity(g_dhook_weapon_weight, DHOOK_POST, entity, N, DHook_ChangeWeaponWeight);

        // Change ammo check speed. Some melee weapons have ammo (barricade hammer, chainsaws).
        DHookEntity(g_dhook_weapon_check_ammo_speed, DHOOK_POST, entity, N, DHook_FirearmCheckAmmo);

        if (maglite)
        {
            DHookEntity(g_dhook_maglite_speed, DHOOK_POST, entity, N, DHook_MagliteSpeed);
        }
        else
        {
            DHookEntity(g_dhook_weapon_pre_maglite_toggle, DHOOK_PRE, entity, N, DHook_WeaponPreMagliteToggle);
            DHookEntity(g_dhook_weapon_maglite_speed, DHOOK_POST, entity, N, DHook_WeaponMagliteSpeed);
        }
    }
}

/**
 * Reset weapon options so that weapons behave normally.
 */
void ResetWeaponOptions()
{
    int tuple_size = view_as<int>(WEAPON_OPTIONS_TUPLE_SIZE);
    for (int i = 0; i < WEAPON_MAX; ++i)
    {
        for (int j = 0; j < tuple_size; ++j)
        {
            g_weapon_options[i][j] = -1.0;
        }
    }
}

/**
 * Read custom weapon options from key-values.
 */
void LoadWeaponOptions(bool log = true)
{
    ResetWeaponOptions();

    char config_name[64];
    g_cvar_weapon_config.GetString(config_name, sizeof(config_name));

    KeyValues kv = new KeyValues("weaponconfig");
    if (ImportConfigKeyValues(kv, config_name))
    {
        ParseWeaponKeyValues(kv);
        if (log)
        {
            PrintToServer("%s Loaded weapon config %s.cfg", WEAPON_CONFIGS_TAG, config_name);
        }
    }
    else if (config_name[0] != '\0')
    {
        PrintToServer("%s Weapon config not found %s.cfg", WEAPON_CONFIGS_TAG, config_name);
    }
}

/**
 * Extract options from weapon config KeyValues.
 */
void ParseWeaponKeyValues(KeyValues kv)
{
    if (kv.GotoFirstSubKey(KEYS_ONLY))
    {
        char weapon_name[CLASSNAME_MAX];

        do
        {
            kv.GetSectionName(weapon_name, sizeof(weapon_name));

            // Attempt to temporarily spawn this entity to check if it is a
            // real weapon/item.
            int id = GetWeaponIDFromClassname(weapon_name);
            if (id < 0 || id > WEAPON_MAX)
            {
                LogError("%s Warning: Weapon ID for '%s' is out of bounds: %d",
                    WEAPON_CONFIGS_TAG, weapon_name, id);
            }
            else
            {
                ParseWeaponDamage(kv, id, "damage", WEAPON_DAMAGE_LO,
                    WEAPON_DAMAGE_HI);

                ParseWeaponDamage(kv, id, "damage_headshot",
                    WEAPON_DAMAGE_HEADSHOT_LO, WEAPON_DAMAGE_HEADSHOT_HI);

                ParseWeaponDamage(kv, id, "damage_shove",
                    WEAPON_DAMAGE_SHOVE_LO,
                    WEAPON_DAMAGE_SHOVE_HI);

                ParseWeaponDamage(kv, id, "damage_shove_headshot",
                    WEAPON_DAMAGE_SHOVE_HEADSHOT_LO,
                    WEAPON_DAMAGE_SHOVE_HEADSHOT_HI);

                ParseWeaponDamage(kv, id, "damage_thrown",
                    WEAPON_DAMAGE_THROWN_LO,
                    WEAPON_DAMAGE_THROWN_HI);

                ParseWeaponDamage(kv, id, "damage_thrown_headshot",
                    WEAPON_DAMAGE_THROWN_LO, WEAPON_DAMAGE_THROWN_HEADSHOT_HI);

                g_weapon_options[id][WEAPON_WEIGHT]             = GetOption(kv, "weight");
                g_weapon_options[id][WEAPON_CAPACITY]           = GetOption(kv, "capacity");
                g_weapon_options[id][WEAPON_STAMINA_MELEE]      = GetOption(kv, "stamina_melee");
                g_weapon_options[id][WEAPON_STAMINA_SHOVE]      = GetOption(kv, "stamina_shove");
                g_weapon_options[id][WEAPON_CAN_SUICIDE]        = GetOption(kv, "can_suicide");
                g_weapon_options[id][WEAPON_CAN_SKILLSHOT]      = GetOption(kv, "can_skillshot");
                g_weapon_options[id][WEAPON_PUSHBACK]           = GetOption(kv, "pushback");
                g_weapon_options[id][WEAPON_PUSHBACK_CHARGED]   = GetOption(kv, "pushback_charged");
                g_weapon_options[id][WEAPON_SHOVE_COOLDOWN]     = GetOption(kv, "shove_cooldown");
                g_weapon_options[id][WEAPON_RADIUS]             = GetOption(kv, "radius");
                g_weapon_options[id][WEAPON_FUSE]               = GetOption(kv, "fuse");
                g_weapon_options[id][WEAPON_ACT_FIRST_DRAW]     = GetOption(kv, "first_draw_animation");

                if (StrEqual(weapon_name, "tool_flare_gun"))
                {
                    float damage = g_weapon_options[id][WEAPON_DAMAGE_LO];
                    if (damage < 0.0)
                    {
                        damage = g_default_flare_gun_damage;
                    }
                    SetFlareGunDamage(damage);
                }

                if (g_weapon_options[id][WEAPON_CAPACITY] > CAPACITY_MAX)
                {
                    LogError("%s Warning: The magazine capacity for %s is more than %d and may not work as intended.",
                        WEAPON_CONFIGS_TAG, weapon_name, CAPACITY_MAX);
                }

                // Weapon animation speeds.
                g_weapon_options[id][WEAPON_QUICK_SPEED]        = GetOption(kv, "quick");
                g_weapon_options[id][WEAPON_CHARGE_SPEED]       = GetOption(kv, "charge");
                g_weapon_options[id][WEAPON_RELEASE_SPEED]      = GetOption(kv, "release");
                g_weapon_options[id][WEAPON_HIP_FIRE_SPEED]     = GetOption(kv, "hip_fire");
                g_weapon_options[id][WEAPON_SIGHT_FIRE_SPEED]   = GetOption(kv, "sight_fire");
                g_weapon_options[id][WEAPON_SIGHT_SPEED]        = GetOption(kv, "sight");
                g_weapon_options[id][WEAPON_UNSIGHT_SPEED]      = GetOption(kv, "unsight");
                g_weapon_options[id][WEAPON_SHOVE_SPEED]        = GetOption(kv, "shove");
                g_weapon_options[id][WEAPON_RELOAD_SPEED]       = GetOption(kv, "reload");
                g_weapon_options[id][WEAPON_RELOAD_EMPTY_SPEED] = GetOption(kv, "reload_empty");
                g_weapon_options[id][WEAPON_CHECK_AMMO_SPEED]   = GetOption(kv, "check_ammo");
                g_weapon_options[id][WEAPON_UNLOAD_SPEED]       = GetOption(kv, "unload");
                g_weapon_options[id][WEAPON_SECONDARY_SPEED]    = GetOption(kv, "secondary");
                g_weapon_options[id][WEAPON_MAGLITE_ON_SPEED]   = GetOption(kv, "maglite_on");
                g_weapon_options[id][WEAPON_MAGLITE_OFF_SPEED]  = GetOption(kv, "maglite_off");

                // How many seconds after an action that the weapon is ready to attack again.
                g_weapon_options[id][WEAPON_QUICK_DELAY]        = GetOption(kv, "quick_delay");
                g_weapon_options[id][WEAPON_CHARGE_DELAY]       = GetOption(kv, "charge_delay");
                g_weapon_options[id][WEAPON_RELEASE_DELAY]      = GetOption(kv, "release_delay");
                g_weapon_options[id][WEAPON_HIP_FIRE_DELAY]     = GetOption(kv, "hip_fire_delay");
                g_weapon_options[id][WEAPON_SIGHT_FIRE_DELAY]   = GetOption(kv, "sight_fire_delay");
                g_weapon_options[id][WEAPON_SIGHT_DELAY]        = GetOption(kv, "sight_delay");
                g_weapon_options[id][WEAPON_UNSIGHT_DELAY]      = GetOption(kv, "unsight_delay");
                g_weapon_options[id][WEAPON_SHOVE_DELAY]        = GetOption(kv, "shove_delay");
                g_weapon_options[id][WEAPON_RELOAD_DELAY]       = GetOption(kv, "reload_delay");
                g_weapon_options[id][WEAPON_RELOAD_EMPTY_DELAY] = GetOption(kv, "reload_empty_delay");
                g_weapon_options[id][WEAPON_CHECK_AMMO_DELAY]   = GetOption(kv, "check_ammo_delay");
                g_weapon_options[id][WEAPON_UNLOAD_DELAY]       = GetOption(kv, "unload_delay");
                g_weapon_options[id][WEAPON_SECONDARY_DELAY]    = GetOption(kv, "secondary_delay");
                g_weapon_options[id][WEAPON_MAGLITE_ON_DELAY]   = GetOption(kv, "maglite_on_delay");
                g_weapon_options[id][WEAPON_MAGLITE_OFF_DELAY]  = GetOption(kv, "maglite_off_delay");
            }
        } while (kv.GotoNextKey(KEYS_ONLY));
    }
}

/**
 * Parse a damage key/value which may be a single value or a range (e.g. 20-40)
 */
void ParseWeaponDamage(KeyValues kv, int weapon_id, const char[] key, eWeaponOption lo, eWeaponOption hi)
{
    char value[64];

    kv.GetString(key, value, sizeof(value), "-1");

    int hypen_index = StrContains(value, "-");
    if (hypen_index > 0)
    {
        float damage_lo = -1.0;
        float damage_hi = -1.0;

        if (StringToFloatEx(value, damage_lo) > 0 &&
            damage_lo >= 0.0 &&
            StringToFloatEx(value[hypen_index + 1], damage_hi) > 0 &&
            damage_hi >= 0.0)
        {
            // Swap values if second if smaller than first
            if (damage_hi < damage_lo)
            {
                float temp = damage_lo;
                damage_lo = damage_hi;
                damage_hi = temp;
            }
        }
        else
        {
            damage_lo = -1.0;
            damage_hi = -1.0;

        }

        g_weapon_options[weapon_id][lo] = damage_lo;
        g_weapon_options[weapon_id][hi] = damage_hi;
    }
    else
    {
        float damage = -1.0;
        if (StringToFloatEx(value, damage) > 0)
        {
            g_weapon_options[weapon_id][lo] = damage;
            g_weapon_options[weapon_id][hi] = damage;
        }
    }
}

void LoadSDKCalls(Handle gameconf)
{
    int offset;

    // Check if a weapon has ammo or doesn't need ammo.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_WeaponBase::IsFlashlightOn");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_weapon_is_flashlight_on = EndPrepSDKCall();

    // Retrieve item's inventory weight and auto-switch priority.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_WeaponBase::IsFlashlightAllowed");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_weapon_is_flashlight_allowed = EndPrepSDKCall();

    // Cause a player to attempt respawn.
    offset = GameConfGetOffsetOrFail(gameconf, "CNMRiH_Player::HasFlashlight");
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    g_sdkcall_player_has_flashlight = EndPrepSDKCall();

    // Get weapon ID.
    offset = GameConfGetOffsetOrFail(gameconf, "CBaseCombatWeapon::GetWeaponID");
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetVirtual(offset);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_sdkcall_get_weapon_id = EndPrepSDKCall();
}

void LoadDHooks(GameData gameconf)
{
    // Change speed of medical item use.
    g_dhook_medical_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_BaseMedicalItem::ShouldUseMedicalItem");

    // Change amount of health restored by medical items.
    g_dhook_heal_amount = DHookCreateFromConfOrFail(gameconf, "CNMRiH_BaseMedicalItem::ApplyMedicalItem_Internal");

    // Change damage dealt by weapons.
    g_dhook_player_take_damage = DHookCreateFromConfOrFail(gameconf, "CBaseEntity::TraceAttack");
    g_dhook_zombie_take_damage = DHookCreateFromConfOrFail(gameconf, "CBaseEntity::TraceAttack");

    // Change weapon's magazine capacity.
    g_dhook_weapon_capacity = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::GetMaxClip1");

    // Change weapon's weight.
    g_dhook_weapon_weight = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::GetWeight");

    // Change melee damage.
    g_dhook_melee_damage = DHookCreateFromConf(gameconf, "CNMRiH_MeleeBase::GetMeleeDamage");

    // Change throw damage.
    g_dhook_weapon_thrown_damage = DHookCreateFromConfOrFail(gameconf, "CNMRiH_MeleeBase::GetThrownDamage");

    // Change animation speed of melee quick-attack.
    g_dhook_melee_quick_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_MeleeBase::QuickAttack");

    // Change animation speed of melee charge-up.
    g_dhook_melee_charge_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_MeleeBase::ChargeBash");

    // Change animation speed of released charge attack.
    g_dhook_melee_charge_release_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_MeleeBase::FinishBash");

    // Change animation speed of weapon's secondary attack.
    g_dhook_melee_secondary_speed = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::SecondaryAttack");

    // Change animation speed of shove.
    g_dhook_weapon_shove_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::StartShove");

    // Change delay between shoves.
    g_dhook_weapon_shove_cooldown = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::DoShove");

    // Change stamina cost of weapon shoves.
    g_dhook_weapon_shove_cost = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::DoShove");

    // Change weapon shove damage.
    g_dhook_weapon_shove_damage = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::GetShoveDamage");

    // Change animation speed of firearm shot.
    g_dhook_barricade_speed             = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::PrimaryAttack");
    g_dhook_firearm_shoot_speed         = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::PrimaryAttack");
    g_dhook_bow_shoot_speed             = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::PrimaryAttack");
    g_dhook_grenade_start_throw_speed   = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::PrimaryAttack");

    // Change grenade's throw animation speed.
    g_dhook_grenade_finish_throw_speed = DHookCreateFromConfOrFail(gameconf, "CBaseSDKGrenade::EmitGrenade");

    // Change animation speed of iron-sighting.
    g_dhook_firearm_sight_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::TurnOnIronsights");

    // Change animation speed of un-sighting.
    g_dhook_firearm_unsight_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::TurnOffIronsights");

    // Change animation speed of ammo check.
    g_dhook_weapon_check_ammo_speed = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::CheckAmmo");

    // Change animation speed of maglite toggle on its own.
    g_dhook_maglite_speed = DHookCreateFromConfOrFail(gameconf, "CBaseCombatWeapon::SecondaryAttack");

    // Change animation speed of maglite toggled with another weapon.
    g_dhook_weapon_pre_maglite_toggle   = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::ToggleFlashlight");
    g_dhook_weapon_maglite_speed        = DHookCreateFromConfOrFail(gameconf, "CNMRiH_WeaponBase::ToggleFlashlight");

    // Change stamina cost of the fists (only necessary on Windows).
    if (!g_is_linux_server)
    {
        g_dhook_fists_stamina_cost = DHookCreateFromConfOrFail(gameconf, "CNMRiH_MeleeBase::DoMeleeBash");
    }
}

/**
 * Create dynamic detours.
 */
void LoadDetours(GameData gameconf)
{
    RegDetour(gameconf, "CNMRiH_MeleeBase::ShouldMeleePushback", .post = Detour_MeleePushbackPost);
    RegDetour(gameconf, "CNMRiH_MeleeBase::DrainMeleeSwingStamina", Detour_MeleeStaminaPre, Detour_MeleeStaminaPost);
    RegDetour(gameconf, "CNMRiH_WeaponBase::Unload", .post = Detour_FirearmUnloadSpeedPost);
    RegDetour(gameconf, "CNMRiH_WeaponBase::AllowsSuicide", .post = Detour_CanSuicidePost);
    RegDetour(gameconf, "CNMRiH_WeaponBase::IsSkillshotModeAvailable", Detour_CanSkillshotPre);

    if (g_is_linux_server)
    {
        RegDetour(gameconf, "CNMRiH_WeaponBase::IsSkillshotModeAvailable", 
            Detour_CanSkillshotPre, Detour_CanSkillshotPost);
    }
}

/**
 * Create a dynamic detour. 
 *
 * @param gameconf      Handle to gamedata.
 * @param key           Name of hook as found in gamedata's Functions.
 * @param pre_callback  Pre-detour callback (optional).
 * @param post_callback Post-detour callback (optional).
 */
void RegDetour(GameData conf, 
    const char[] name, 
    DHookCallback pre = INVALID_FUNCTION, 
    DHookCallback post = INVALID_FUNCTION)
{
    DynamicDetour detour = DynamicDetour.FromConf(conf, name);
    if (!detour)
        SetFailState("Failed to setup detour for %s", name);
    
    if (pre != INVALID_FUNCTION && !detour.Enable(Hook_Pre, pre))
        SetFailState("Failed to enable pre detour for %s", name);

    if (post != INVALID_FUNCTION && !detour.Enable(Hook_Pre, post))
        SetFailState("Failed to enable post detour for %s", name);

    delete detour;
}

/**
 * Try to import KeyValues from a config file.
 */
bool ImportConfigKeyValues(KeyValues kv, const char[] file)
{
    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), "configs/%s.cfg", file);

    return kv.ImportFromFile(file_path);
}

/**
 * Retrieve a weapon option from KeyValues or return -1.0.
 */
float GetOption(KeyValues kv, const char[] key)
{
    return kv.GetFloat(key, -1.0);
}

/**
 * Retrieve an offset from a game conf or abort the plugin.
 */
int GameConfGetOffsetOrFail(Handle gameconf, const char[] key)
{
    int offset = GameConfGetOffset(gameconf, key);
    if (offset == -1)
    {
        CloseHandle(gameconf);
        SetFailState("Failed to read gamedata offset of %s", key);
    }
    return offset;
}

/**
 * Create a DHook from a game conf or abort the plugin.
 */
Handle DHookCreateFromConfOrFail(GameData gameconf, const char[] key)
{
    Handle result = DHookCreateFromConf(gameconf, key);
    if (!result)
    {
        CloseHandle(gameconf);
        SetFailState("Failed to create DHook for %s", key);
    }
    return result;
}

/**
 * Change blast damage of flare gun.
 */
void SetFlareGunDamage(float damage)
{
    g_sv_flare_gun_explode_damage.FloatValue = damage;
}

/**
 * Calculate a weapon's custom damage.
 */
float GetWeaponDamage(int weapon_id, eWeaponOption lo)
{
    eWeaponOption hi = view_as<eWeaponOption>(view_as<int>(lo) + 1);
    float low = g_weapon_options[weapon_id][lo];
    float high = g_weapon_options[weapon_id][hi];

    return GetRandomFloat(low, high);
}

/**
 * Parse the Sourcemod version from a cvar.
 *
 * Handles version patterns in the form of:
 *
 *  "1.10.0.6335" or "1.6.1-dev+4527"
 */
void GetSourcemodVersion()
{
    ConVar version = FindConVar("sourcemod_version");

    if (version != null)
    {
        char buffer[64];
        version.GetString(buffer, sizeof(buffer));

        int offset = 0;
        int consumed = 0;

        consumed = StringToIntEx(buffer[offset], g_sourcemod_major);
        if (consumed <= 0)
        {
            LogError("%s Failed to parse Sourcemod major version", WEAPON_CONFIGS_TAG);
            return;
        }
        offset += consumed + 1;

        consumed = StringToIntEx(buffer[offset], g_sourcemod_minor);
        if (consumed <= 0)
        {
            LogError("%s Failed to parse Sourcemod minor version", WEAPON_CONFIGS_TAG);
            return;
        }
        offset += consumed + 1;

        consumed = StringToIntEx(buffer[offset], g_sourcemod_patch);
        if (consumed <= 0)
        {
            LogError("%s Failed to parse Sourcemod patch version", WEAPON_CONFIGS_TAG);
            return;
        }
        offset += consumed + 1;

        if (buffer[offset - 1] == '-')
        {
            // Offset past any "dev+" marker.
            int build_offset = StrContains(buffer[offset], "+");
            if (build_offset != -1)
            {
                offset += build_offset + 1;
            }
        }

        consumed = StringToIntEx(buffer[offset], g_sourcemod_build);
        if (consumed <= 0)
        {
            LogError("%s Failed to parse Sourcemod build version", WEAPON_CONFIGS_TAG);
            return;
        }
    }
}

/**
 * Retrieve edict's classname and compare it to a string.
 */
bool IsClassnameEqual(int entity, char[] classname, int classname_size, const char[] compare_to)
{
    GetEdictClassname(entity, classname, classname_size);
    return StrEqual(classname, compare_to);
}

/**
 * Retrieve an entity's owner.
 */
int GetEntOwner(int entity)
{
    return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

/**
 * Retrieve id of player's current weapon.
 */
int GetClientActiveWeapon(int client)
{
    return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

/**
 * Retrieve an entity's max health.
 *
 * @param entity            Entity to query.
 *
 * @return                  Entity's max health.
 */
int GetEntMaxHealth(int entity)
{
    return GetEntProp(entity, Prop_Data, "m_iMaxHealth");
}

/**
 * Retrieve entity's current sequence.
 */
int GetEntSequence(int entity)
{
    return GetEntProp(entity, Prop_Send, "m_nSequence");
}

/**
 * Retrieve entity's previous sequence.
 */
int GetEntPreviousSequence(int entity)
{
    return GetEntProp(entity, Prop_Send, "m_iPreviousSequence");
}

/**
 * Retrieve minimum game time when weapon can shove again.
 */
float GetWeaponNextShoveTime(int weapon)
{
    return GetEntPropFloat(weapon, Prop_Send, "m_flNextBashAttack");
}

/**
 * Set minimum game time when weapon can shove again.
 */
void SetWeaponNextShoveTime(int weapon, float time)
{
    SetEntPropFloat(weapon, Prop_Send, "m_flNextBashAttack", time);
}


/**
 * Change player's stamina.
 */
void SetPlayerStamina(int player, float stamina)
{
    SetEntPropFloat(player, Prop_Send, "m_flStamina", stamina);
}

/**
 * Retrieve player's current stamina.
 */
float GetPlayerStamina(int player)
{
    return GetEntPropFloat(player, Prop_Send, "m_flStamina");
}
