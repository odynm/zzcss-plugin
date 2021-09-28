// Known issues:
// * doesn't reset score in restartgame
// * still has money on switch sides

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

ConVar mp_teamone;
ConVar mp_teamtwo;
ConVar mp_roundtime;
ConVar mp_freezetime;

bool g_swapped = false;
bool g_gameStarted = false;

int g_CtScore, g_TScore, g_roundCount;
int g_roundtime = -1;
int g_freezetime = -1;

public Plugin myinfo =
{
	name = "[CS:S] zz_plugin",
	author = "odynm",
	description = "",
	version = "1.0.0",
};

public void OnPluginStart()
{
	mp_teamone = CreateConVar("mp_teamone", "Team1", "Name of team one (CT at start).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	mp_teamtwo = CreateConVar("mp_teamtwo", "Team2", "Name of team two (T at start).", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	RegAdminCmd("sm_switchsides", Command_SwitchSides, ADMFLAG_RCON, "sm_switchsides");
	RegAdminCmd("sm_startmatch", Command_StartMatch, ADMFLAG_RCON, "sm_startmatch");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("game_start", Event_GameStart);
	HookEvent("player_death", Event_PlayerDeath);
}

public Action Event_GameStart(Handle event, const char[] name, bool dontBroadcast)
{
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	char teamone[50];
	char teamtwo[50];
	GetConVarString(mp_teamone, teamone, 50);
	GetConVarString(mp_teamtwo, teamtwo, 50);

	if (strcmp(teamone, "Team1") == 0)
	{
		GenerateTeamName(CS_TEAM_CT, mp_teamone);
	}

	if (strcmp(teamtwo, "Team2") == 0)
	{
		GenerateTeamName(CS_TEAM_T, mp_teamtwo);
	}

	if (!g_gameStarted)
	{
		if (g_roundtime == -1)
		{
			mp_roundtime = FindConVar("mp_roundtime");
			g_roundtime = GetConVarInt(mp_roundtime);
			SetConVarInt(mp_roundtime, 9999, true, true);
		}

		if (g_freezetime == -1)
		{
			mp_freezetime = FindConVar("mp_freezetime");
			g_freezetime = GetConVarInt(mp_freezetime);
			SetConVarInt(mp_freezetime, 0, true, true);
		}

		PrintToChatAll("===INICIANDO AQUECIMENTO===");
	}
	else
	{
		PrintScore();
	}
}

public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	int reason = GetEventInt(event, "reason");
	int winner = GetEventInt(event, "winner");

	if (reason == CSRoundEnd_GameStart) {
		g_CtScore = 0;
		g_TScore = 0;
		g_roundCount = 0;
		return;
	}

	if (winner == CS_TEAM_T)
		g_TScore++;
	if (winner == CS_TEAM_CT)
		g_CtScore++;

	SetTeamScore(CS_TEAM_T, g_TScore);
	SetTeamScore(CS_TEAM_CT, g_CtScore);

	g_roundCount = g_TScore + g_CtScore;
}

public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int userId = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userId);

	if (!g_gameStarted)
	{
		if (IsClientInGame(client) && GetClientTeam(client) > 1)
		{
			SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
			SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
			SetEntProp(client, Prop_Send, "m_iAccount", 16000);

			CreateTimer(1.0, Timer_Respawn, client);
		}
	}
}

public Action Command_StartMatch(int aClient, int args)
{
	g_gameStarted = true;
	SetConVarInt(mp_roundtime, g_roundtime, true, true);
	SetConVarInt(mp_freezetime, g_freezetime, true, true);
	g_CtScore = 0;
	g_TScore = 0;
	g_roundCount = 0;
	SetTeamScore(CS_TEAM_T, g_TScore);
	SetTeamScore(CS_TEAM_CT, g_CtScore);
	PrintToChatAll("========MATCH STARTED=========");
	PrintScore();

	int startmoney = GetConVarInt(FindConVar("mp_startmoney"));

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) > 1)
		{
			for (int weapon, i = 0; i < 5; i++)
			{
				while ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
				{
					if (i == 4)
						CS_DropWeapon(client, weapon, false, true);
					else
						RemovePlayerItem(client, weapon);
				}
			}

			SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
			SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
			SetEntProp(client, Prop_Send, "m_iAccount", startmoney);

			CS_RespawnPlayer(client);
		}
	}
}

public Action Command_SwitchSides(int aClient, int args)
{
	g_swapped = !g_swapped;
	int startmoney = GetConVarInt(FindConVar("mp_startmoney"));

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) > 1)
		{
			for (int weapon, i = 0; i < 5; i++)
			{
				while ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
				{
					if (i == 4)
						CS_DropWeapon(client, weapon, false, true);
					else
						RemovePlayerItem(client, weapon);
				}
			}

			SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
			SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
			SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
			SetEntProp(client, Prop_Send, "m_iAccount", startmoney);

			CS_SwitchTeam(client, (GetClientTeam(client) == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T);
			CS_RespawnPlayer(client);
		}
	}

	int tmp = g_TScore;
	g_TScore = g_CtScore;
	g_CtScore = tmp;

	SetTeamScore(CS_TEAM_T, g_TScore);
	SetTeamScore(CS_TEAM_CT, g_CtScore);

	PrintToChatAll("========HALFTIME=========");
	PrintScore();
}

public void PrintScore()
{
	char teamone[50];

	char teamtwo[50];
	GetConVarString(mp_teamone, teamone, 50);
	GetConVarString(mp_teamtwo, teamtwo, 50);

	PrintToChatAll(">>> ROUND %d <<<", (g_roundCount + 1));
	PrintToChatAll(">>> (%s) %s | %d x %d | %s (%s) <<<", g_swapped ? "TR" : "CT", teamone, g_swapped ? g_TScore : g_CtScore, g_swapped ? g_CtScore : g_TScore, teamtwo, g_swapped ? "CT" : "TR");
}

public void GenerateTeamName(int team, ConVar conTeam)
{
	char name[50];
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == team)
		{
			if (GetClientName(client, name, 45))
			{
				StrCat(name, 50, " Team");
				SetConVarString(conTeam, name);
				return;
			}
		}
	}
}

public Action Timer_Respawn(Handle event, int client)
{
	PrintToChatAll("--AQUECIMENTO--");
	CS_RespawnPlayer(client);
}
