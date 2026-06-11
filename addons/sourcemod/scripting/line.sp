#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <clientprefs>
#include <shavit/core>
#include <shavit/replay-playback>
#include <closestpos>
#include <convar_class>

#define MAX_COLORS 32 // configs/line.cfg max colors

// ConVars
Convar gCV_DrawBackDefault = null;
Convar gCV_DrawAheadDefault = null;
Convar gCV_MaxDrawBack = null;
Convar gCV_MaxDrawAhead = null;
Convar gCV_UpdateTimer = null;
Convar gCV_BeamLife = null;
Convar gCV_MaxRenderDist = null;
Convar gCV_ZOffset = null;
Convar gCV_SkipFrames = null;
Convar gCV_ReinitAfterWR = null;
Convar gCV_MinFrameDistance = null;
Convar gCV_PartialDashLength = null;
Convar gCV_PartialGapLength = null;

// Logic
int gI_CycleFrame[MAXPLAYERS+1];
int gI_DrawBudget[MAXPLAYERS+1];
int gI_CurrentIndex[MAXPLAYERS+1];
int gI_EndIndex[MAXPLAYERS+1];
float gF_PrevPos[MAXPLAYERS+1][3];
int gI_PrevFlags[MAXPLAYERS+1];
float gF_LastLandPos[MAXPLAYERS+1][3];
bool g_bHasLastLand[MAXPLAYERS+1];
bool g_bFirstPoint[MAXPLAYERS+1];

// Z-Lerp
int gI_LerpStartFrame[MAXPLAYERS+1];
int gI_LerpEndFrame[MAXPLAYERS+1];
float gF_LerpStartZ[MAXPLAYERS+1];
float gF_LerpEndZ[MAXPLAYERS+1];

// Cache
float gF_ClientDrawPos[MAXPLAYERS+1][3];
int gI_ColorLine[MAXPLAYERS+1][4];
int gI_ColorLineGround[MAXPLAYERS+1][4];
int gI_ColorShapeDuck[MAXPLAYERS+1][4];
int gI_ColorShapeNoDuck[MAXPLAYERS+1][4];
int gI_Sprite[MAXPLAYERS+1];
int gI_PrestrafeIndex[MAXPLAYERS+1];
int gI_DrawStyle[MAXPLAYERS+1];
int gI_DrawTrack[MAXPLAYERS+1];

// Sprites
enum BeamSprite
{
    Default = 0,
    DefaultIgnoreZ = 1,
    Partial = 2,
    PartialIgnoreZ = 3,
    BEAM_SPRITE_MAX
};

int gI_BeamSprite[BEAM_SPRITE_MAX];

// Colors
enum struct color_t
{
    int RGBA[4];
    char Name[32];
}

int ColorsCount;
color_t ColorsTable[MAX_COLORS];

// Replay Data
int gI_ReplayPreFramesCount[STYLE_LIMIT][TRACKS_SIZE];
int gI_ReplayPrestrafeIndex[STYLE_LIMIT][TRACKS_SIZE];
ArrayList gA_ReplayFrames[STYLE_LIMIT][TRACKS_SIZE];
ArrayList gA_FrameDistances[STYLE_LIMIT][TRACKS_SIZE]; // Precomputed accumulated distances for stable partial path rendering
ClosestPos gH_Closestpos[STYLE_LIMIT][TRACKS_SIZE];

enum LineShape
{
    Shape_Circle = 0,
    Shape_Square = 1
};

enum LineMode
{
    Mode_2D = 0,
    Mode_3D = 1,
    Mode_ShapeOnly = 2
};

// Cookies
Cookie gC_LineCookieEnabled = null;
Cookie gC_LineCookieShapeType = null;
Cookie gC_LineCookieMode = null;
Cookie gC_LineCookieZLerp = null;
Cookie gC_LineCookePartial = null;
Cookie gC_LineCookieLine = null;
Cookie gC_LineCookieLineGround = null;
Cookie gC_LineCookieShape = null;
Cookie gC_LineCookieShapeDuck = null;
Cookie gC_LineCookieIgnorez = null;
Cookie gC_LineCookieDrawBack = null;
Cookie gC_LineCookieDrawAhead = null;

// Client Settings
bool gB_ClientLineEnabled[MAXPLAYERS+1];
int gI_ClientLineShape[MAXPLAYERS+1];
int gI_ClientLineMode[MAXPLAYERS+1];
bool gB_ClientLineZLerp[MAXPLAYERS+1];
bool gB_ClientPartialPath[MAXPLAYERS+1];
int gI_ClientLineStyle[MAXPLAYERS+1];
int gI_ClientLineTrack[MAXPLAYERS+1];
bool gB_ClientIgnorez[MAXPLAYERS+1];

// Per-player draw distances
int gI_ClientDrawBack[MAXPLAYERS+1];
int gI_ClientDrawAhead[MAXPLAYERS+1];

float gF_ClientLineWidth[MAXPLAYERS+1];
float gF_ClientLineGroundWidth[MAXPLAYERS+1];
int gI_ClientLineColorIdx[MAXPLAYERS+1];
int gI_ClientLineGroundColorIdx[MAXPLAYERS+1];
float gF_ClientShapeWidth[MAXPLAYERS+1];
int gI_ClientShapeColorIdx[MAXPLAYERS+1];
float gF_ClientShapeNoDuckWidth[MAXPLAYERS+1];
int gI_ClientShapeNoDuckColorIdx[MAXPLAYERS+1];

// TELimit Patch
enum OSType
{
    OSUnknown = 0,
    OSWindows = 1,
    OSLinux = 2
};

int gTELimitData;
OSType gOSType = OSUnknown;
Address gTELimitAddress = Address_Null;

// ******************************************************************************
//  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
//  * * * * * TOP REASONS YOUR RAM WILL LOVE THIS PLUGIN: * * * * * * * * * * * *
//  - bhop_desertbus scroll replay exists on your server.          
//  - Many styles on the server and many records on the random map (not strafe).  
//  - You have a lot of friends.                                   
//  - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
// ******************************************************************************

public Plugin myinfo =
{
    name = "[bhoptimer] line",
    author = "happydez",
    description = "✿˘✧.*☆*✲☆⋆❤˘━✧.*",
    version = "2.1.0",
    url = "https://github.com/happydez/line"
};

public void OnPluginStart()
{
    // Cookies
    gC_LineCookieEnabled = new Cookie("line_enabled", "Line enabled", CookieAccess_Protected);
    gC_LineCookieShapeType = new Cookie("line_shape_type", "Shape type", CookieAccess_Protected);
    gC_LineCookieMode = new Cookie("line_mode", "Render Mode", CookieAccess_Protected);
    gC_LineCookieZLerp = new Cookie("line_zlerp", "Z-Lerp", CookieAccess_Protected);
    gC_LineCookePartial = new Cookie("line_partial", "Partial Path", CookieAccess_Protected);
    gC_LineCookieLine = new Cookie("line_line", "Line settings width;colorIndex", CookieAccess_Protected);
    gC_LineCookieLineGround = new Cookie("line_line_ground", "Ground line settings width;colorIndex", CookieAccess_Protected);
    gC_LineCookieShapeDuck = new Cookie("line_shape_duck", "Duck shape settings width;colorIndex", CookieAccess_Protected);
    gC_LineCookieShape = new Cookie("line_shape_noduck", "NoDuck shape settings width;colorIndex", CookieAccess_Protected);
    gC_LineCookieIgnorez = new Cookie("line_ignorez", "Ignorez", CookieAccess_Protected);
    gC_LineCookieDrawBack = new Cookie("line_draw_back", "Frames to draw backwards", CookieAccess_Protected);
    gC_LineCookieDrawAhead = new Cookie("line_draw_ahead", "Frames to draw forward", CookieAccess_Protected);

    // ConVars
    gCV_DrawBackDefault = new Convar("line_draw_back_default", "16", "Default number of frames rendered backwards", 0, true, 0.0);
    gCV_DrawAheadDefault = new Convar("line_draw_ahead_default", "128", "Default number of frames rendered forward", 0, true, 0.0);
    gCV_MaxDrawBack = new Convar("line_max_draw_back", "48", "Maximum frames clients can draw backwards", 0, true, 0.0);
    gCV_MaxDrawAhead = new Convar("line_max_draw_ahead", "256", "Maximum frames clients can draw forward", 0, true, 0.0);
    gCV_UpdateTimer = new Convar("line_update_timer", "0.8", "Render interval; the visible path is redrawn once per this interval, spread evenly across frames.", 0, true, 0.0);
    gCV_BeamLife = new Convar("line_beam_life", "0.9", "Beam life", 0, true, 0.0);
    gCV_MaxRenderDist = new Convar("line_max_render_dist", "4096", "Maximum render distance in units\n-1.0 to disable", 0, true, -1.0);
    gCV_ZOffset = new Convar("line_z_offset", "2.5", "Z-axis offset for Z-Lerp interpolation", 0, true, 0.0);
    gCV_SkipFrames = new Convar("line_skip_frames", "20", "The number of frames to skip when loading a replay data", 0, true, 1.0);
    gCV_ReinitAfterWR = new Convar("line_reinit_after_wr", "1", "Reinit or init replay data after new wr for specific style and track", 0, true, 0.0, true, 1.0);
    gCV_MinFrameDistance = new Convar("line_min_frame_distance", "4.0", "Minimum distance between frames to render (skip clustered frames)", 0, true, 0.0);
    gCV_PartialDashLength = new Convar("line_partial_dash_length", "10.0", "Length of visible dash segment in partial path mode", 0, true, 1.0);
    gCV_PartialGapLength = new Convar("line_partial_gap_length", "24.0", "Length of gap between dashes in partial path mode", 0, true, 0.0);

    gCV_SkipFrames.AddChangeHook(OnConVarChanged);
    Convar.AutoExecConfig();

    RegConsoleCmd("sm_line", Command_Line, "line");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            if (AreClientCookiesCached(i) && !IsFakeClient(i))
            {
                OnClientCookiesCached(i);
            }
        }
    }

    EngineVersion eng = GetEngineVersion();
    if (eng == Engine_CSS)
    {
        GameData gd = new GameData("line.games");
        PatchTELimit(gd);
        delete gd;
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == gCV_SkipFrames)
    {
        InitReplayData();
    }
}

public void OnPluginEnd()
{
    UnpatchTELimit();
}

static void PatchTELimit(GameData gd)
{
    if (gd == null)
    {
        SetFailState("GameData is null");
    }

    gOSType = view_as<OSType>(GameConfGetOffset(gd, "OSType"));
    gTELimitAddress = GameConfGetAddress(gd, "TELimit");
    if (gTELimitAddress == Address_Null)
    {
        SetFailState("Failed to get address of TELimit");
    }

    gTELimitData = LoadFromAddress(gTELimitAddress, NumberType_Int8);

    if (gOSType == OSWindows)
    {
        StoreToAddress(gTELimitAddress, 0xFF, NumberType_Int8);
    }
    else if (gOSType == OSLinux)
    {
        StoreToAddress(gTELimitAddress, 0x02, NumberType_Int8);
    }
    else
    {
        SetFailState("Unsupported OSType");
    }
}

void UnpatchTELimit()
{
    if (gTELimitAddress == Address_Null)
    {
        return;
    }

    StoreToAddress(gTELimitAddress, gTELimitData, NumberType_Int8);
    gTELimitAddress = Address_Null;
}

public Action Command_Line(int client, int args)
{
    if (IsValidClient(client))
    {
        OpenLineMainMenu(client);
    }

    return Plugin_Handled;
}

public void OnMapStart()
{
    ColorsCount = 0;
    LoadLineSettings();
}

public void OnClientDisconnect(int client)
{
    gB_ClientLineEnabled[client] = false;
    gI_CycleFrame[client] = 0;
}

public void OnClientPutInServer(int client)
{
    gI_LerpStartFrame[client] = -1;
    gI_LerpEndFrame[client] = -1;
    gI_CycleFrame[client] = 0;

    if (AreClientCookiesCached(client))
    {
        OnClientCookiesCached(client);
    }
    else
    {
        SetClientLineDefaults(client);
    }

    gI_ClientLineStyle[client] = NextStyleForLine(client, true);
}

public void Shavit_OnReplaysLoaded()
{
    InitReplayData();
}

public void Shavit_OnReplaySaved(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldtime, float perfs, float avgvel, float maxvel, int timestamp, bool isbestreplay, bool istoolong, ArrayList replaypaths, ArrayList frames, int preframes, int postframes, const char[] name)
{
    if (gCV_ReinitAfterWR.BoolValue && isbestreplay)
    {
        LoadReplayData(style, track, frames, preframes, postframes);
    }
}

void InitReplayData()
{
    for (int style = 0; style < STYLE_LIMIT; style++)
    {
        for (int track = 0; track < TRACKS_SIZE; track++)
        {
            LoadReplayData(style, track);
        }
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if ((gA_ReplayFrames[gI_ClientLineStyle[client]][gI_ClientLineTrack[client]] == null))
        {
            gI_ClientLineStyle[client] = NextStyleForLine(client, true);
        }
    }
}

void LoadReplayData(int style, int track, ArrayList frames = null, int preFrames = -1, int postFrames = -1)
{
    delete gA_ReplayFrames[style][track];
    delete gA_FrameDistances[style][track];
    delete gH_Closestpos[style][track];
    gI_ReplayPrestrafeIndex[style][track] = -1;

    ArrayList replayData = (frames == null) ? Shavit_GetReplayFrames(style, track, true) : frames;
    if (replayData == null)
    {
        return;
    }

    gA_ReplayFrames[style][track] = new ArrayList(sizeof(frame_t));
    gA_FrameDistances[style][track] = new ArrayList(1);
    gI_ReplayPreFramesCount[style][track] = (preFrames > 0) ? preFrames : Shavit_GetReplayPreFrames(style, track);
    if (postFrames < 0)
    {
        postFrames = Shavit_GetReplayPostFrames(style, track);
    }

    frame_t cF, nF;
    int originalPrestrafeIndex = -1;
    for (int i = 0; i < replayData.Length - 1 - postFrames; i++)
    {
        replayData.GetArray(i, cF, sizeof(frame_t));
        replayData.GetArray(i + 1, nF, sizeof(frame_t));
        if ((cF.flags & FL_ONGROUND) && !(nF.flags & FL_ONGROUND))
        {
            originalPrestrafeIndex = i;
            break;
        }
    }

    frame_t frame;
    int newIndexCounter = 0;
    bool prestrafeFoundInNewList = false;
    for (int i = 0; i < replayData.Length - postFrames; i++)
    {
        replayData.GetArray(i, frame, sizeof(frame));
        bool isPrestrafeFrame = (i == originalPrestrafeIndex);
        if ((frame.flags & FL_ONGROUND) || (i % gCV_SkipFrames.IntValue == 0) || isPrestrafeFrame)
        {
            gA_ReplayFrames[style][track].PushArray(frame);
            if (isPrestrafeFrame)
            {
                gI_ReplayPrestrafeIndex[style][track] = newIndexCounter;
                prestrafeFoundInNewList = true;
            }

            newIndexCounter++;
        }
    }

    if (!prestrafeFoundInNewList)
    {
        gI_ReplayPrestrafeIndex[style][track] = -1;
    }

    // Precompute accumulated distances for stable partial path rendering
    float accumulatedDistance = 0.0;
    gA_FrameDistances[style][track].Push(accumulatedDistance);

    frame_t prevFrame, currFrame;
    gA_ReplayFrames[style][track].GetArray(0, prevFrame, sizeof(frame_t));
    for (int i = 1; i < gA_ReplayFrames[style][track].Length; i++)
    {
        gA_ReplayFrames[style][track].GetArray(i, currFrame, sizeof(frame_t));
        float dist = GetVectorDistance(prevFrame.pos, currFrame.pos);
        accumulatedDistance += dist;
        gA_FrameDistances[style][track].Push(accumulatedDistance);
        prevFrame = currFrame;
    }

    gH_Closestpos[style][track] = new ClosestPos(gA_ReplayFrames[style][track], 0, 0, gA_ReplayFrames[style][track].Length);
    delete replayData;
}

void LoadLineSettings()
{
    if (!LoadLineCfg())
    {
        SetFailState("Cannot open configs/line.cfg");
    }
}

bool LoadLineCfg()
{
    char filePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, filePath, PLATFORM_MAX_PATH, "configs/line.cfg");
    KeyValues kv = new KeyValues("line");
    if (!kv.ImportFromFile(filePath))
    {
        delete kv;
        return false;
    }

    kv.JumpToKey("Sprites");
    char buff[PLATFORM_MAX_PATH];
    kv.GetString("beam", buff, PLATFORM_MAX_PATH);
    gI_BeamSprite[Default] = PrecacheModel(buff, true);
    kv.GetString("ignorez_beam", buff, PLATFORM_MAX_PATH);
    gI_BeamSprite[DefaultIgnoreZ] = PrecacheModel(buff, true);
    kv.GetString("pbeam", buff, PLATFORM_MAX_PATH);
    gI_BeamSprite[Partial] = PrecacheModel(buff, true);
    kv.GetString("ignorez_pbeam", buff, PLATFORM_MAX_PATH);
    gI_BeamSprite[PartialIgnoreZ] = PrecacheModel(buff, true);

    char downloads[PLATFORM_MAX_PATH * 8];
    kv.GetString("downloads", downloads, PLATFORM_MAX_PATH * 8);
    char downloadsExploded[PLATFORM_MAX_PATH][PLATFORM_MAX_PATH];
    int count = ExplodeString(downloads, ";", downloadsExploded, PLATFORM_MAX_PATH, PLATFORM_MAX_PATH, false);
    for (int i = 0; i < count; i++)
    {
        if (strlen(downloadsExploded[i]) > 0)
        {
            TrimString(downloadsExploded[i]);
            AddFileToDownloadsTable(downloadsExploded[i]);
        }
    }

    kv.GoBack();
    kv.JumpToKey("Colors");
    kv.GotoFirstSubKey();
    int i = 0;
    char colorName[32];
    do
    {
        if (kv.GetSectionName(colorName, sizeof(colorName)))
        {
            ColorsTable[i].RGBA[0] = kv.GetNum("red", 255);
            ColorsTable[i].RGBA[1] = kv.GetNum("green", 255);
            ColorsTable[i].RGBA[2] = kv.GetNum("blue", 255);
            ColorsTable[i].RGBA[3] = kv.GetNum("alpha", 255);
            Capitalize(colorName);
            strcopy(ColorsTable[i].Name, 32, colorName);
            i++;
        }
    } while (kv.GotoNextKey() && (i < MAX_COLORS));

    ColorsCount = i;

    delete kv;

    return true;
}

public void OnGameFrame()
{
    int framesPerCycle = RoundToCeil(gCV_UpdateTimer.FloatValue / GetTickInterval());
    if (framesPerCycle < 1)
    {
        framesPerCycle = 1;
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (!gB_ClientLineEnabled[client] || !IsValidClient(client))
        {
            continue;
        }

        if (gI_CycleFrame[client] <= 0)
        {
            gI_CycleFrame[client] = framesPerCycle;
            StartDrawCycle(client, framesPerCycle);
        }

        gI_CycleFrame[client]--;

        DrawBatch(client);
    }
}

void StartDrawCycle(int client, int framesPerCycle)
{
    gI_EndIndex[client] = 0;
    gI_CurrentIndex[client] = 0;

    int style = gI_ClientLineStyle[client];
    int track = gI_ClientLineTrack[client];
    ArrayList list = gA_ReplayFrames[style][track];
    if (list == null || list.Length == 0)
    {
        return;
    }

    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);

    gF_ClientDrawPos[client] = clientPos;
    gI_DrawStyle[client] = style;
    gI_DrawTrack[client] = track;

    int closestIndex = gH_Closestpos[style][track].Find(clientPos);
    int prestrafeIdx = gI_ReplayPrestrafeIndex[style][track];
    int renderCenterIndex = closestIndex;
    if (prestrafeIdx != -1 && closestIndex < prestrafeIdx)
    {
        renderCenterIndex = prestrafeIdx;
    }

    // Use per-client draw distances
    int drawBack = gI_ClientDrawBack[client];
    int drawAhead = gI_ClientDrawAhead[client];

    int startIndex = (renderCenterIndex > drawBack) ? renderCenterIndex - drawBack : 0;
    int endIndex = renderCenterIndex + drawAhead;
    if (endIndex > list.Length)
    {
        endIndex = list.Length;
    }

    int color[4];
    GetColorRGBAFromIndex(gI_ClientLineColorIdx[client], color);
    for (int j = 0; j < 4; j++)
    {
        gI_ColorLine[client][j] = color[j];
    }

    GetColorRGBAFromIndex(gI_ClientLineGroundColorIdx[client], color);
    for (int j = 0; j < 4; j++)
    {
        gI_ColorLineGround[client][j] = color[j];
    }

    GetColorRGBAFromIndex(gI_ClientShapeColorIdx[client], color);
    for (int j = 0; j < 4; j++)
    {
        gI_ColorShapeDuck[client][j] = color[j];
    }

    GetColorRGBAFromIndex(gI_ClientShapeNoDuckColorIdx[client], color);
    for (int j = 0; j < 4; j++)
    {
        gI_ColorShapeNoDuck[client][j] = color[j];
    }

    if (gB_ClientPartialPath[client])
    {
        gI_Sprite[client] = gB_ClientIgnorez[client] ? gI_BeamSprite[PartialIgnoreZ] : gI_BeamSprite[Partial];
    }
    else
    {
        gI_Sprite[client] = gB_ClientIgnorez[client] ? gI_BeamSprite[DefaultIgnoreZ] : gI_BeamSprite[Default];
    }

    gI_PrestrafeIndex[client] = prestrafeIdx;

    frame_t aFrame;
    list.GetArray(startIndex, aFrame, sizeof(frame_t));

    float startPos[3];
    startPos = aFrame.pos;
    startPos[2] += gCV_ZOffset.FloatValue;
    if (gI_ClientLineMode[client] == view_as<int>(Mode_3D) && gB_ClientLineZLerp[client])
    {
        if (!(aFrame.flags & FL_ONGROUND))
        {
            ZLerp(client, list, startIndex, startPos);
        }
    }

    gF_PrevPos[client] = startPos;
    gI_PrevFlags[client] = aFrame.flags;

    if (aFrame.flags & FL_ONGROUND)
    {
        gF_LastLandPos[client] = startPos;
        g_bHasLastLand[client] = true;
    }
    else
    {
        g_bHasLastLand[client] = false;
    }

    g_bFirstPoint[client] = true;
    gI_CurrentIndex[client] = startIndex + 1;
    gI_EndIndex[client] = endIndex;

    int windowSize = gI_EndIndex[client] - gI_CurrentIndex[client];
    int budget = (windowSize + framesPerCycle - 1) / framesPerCycle;
    if (budget < 1)
    {
        budget = 1;
    }

    gI_DrawBudget[client] = budget;
}

void DrawBatch(int client)
{
    int style = gI_DrawStyle[client];
    int track = gI_DrawTrack[client];
    ArrayList list = gA_ReplayFrames[style][track];
    if (list == null)
    {
        return;
    }

    int len = list.Length;
    if (len <= 0)
    {
        return;
    }

    if (gI_EndIndex[client] > len)
    {
        gI_EndIndex[client] = len;
    }

    if (gI_CurrentIndex[client] < 0)
    {
        gI_CurrentIndex[client] = 0;
    }

    if (gI_CurrentIndex[client] >= gI_EndIndex[client] || gI_CurrentIndex[client] >= len)
    {
        return;
    }

    frame_t aFrame;
    float currentPos[3];
    float prevPos[3]; prevPos = gF_PrevPos[client];
    int prevFlags = gI_PrevFlags[client];
    float lastLandPos[3]; lastLandPos = gF_LastLandPos[client];
    bool hasLastLand = g_bHasLastLand[client];
    float clientPos[3]; clientPos = gF_ClientDrawPos[client];

    int prestrafeIndex = gI_PrestrafeIndex[client];
    int sprite = gI_Sprite[client];
    int mode = gI_ClientLineMode[client];
    float lineWidthAir = gF_ClientLineWidth[client];
    float lineWidthGround = gF_ClientLineGroundWidth[client];
    bool zlerp = gB_ClientLineZLerp[client];
    float minFrameDist = gCV_MinFrameDistance.FloatValue;

    int i = gI_CurrentIndex[client];
    int batchEnd = i + gI_DrawBudget[client];
    if (batchEnd > gI_EndIndex[client])
    {
        batchEnd = gI_EndIndex[client];
    }
    if (batchEnd > len)
    {
        batchEnd = len;
    }

    for (; i < batchEnd; i++)
    {
        if (i < 0 || i >= len)
        {
            break;
        }

        list.GetArray(i, aFrame, sizeof(frame_t));

        currentPos = aFrame.pos;
        currentPos[2] += gCV_ZOffset.FloatValue;
        if (mode == view_as<int>(Mode_3D) && zlerp)
        {
            if (!(aFrame.flags & FL_ONGROUND))
            {
                ZLerp(client, list, i, currentPos);
            }
        }

        if (prestrafeIndex != -1 && i < prestrafeIndex)
        {
            prevPos = currentPos;
            prevFlags = aFrame.flags;
            continue;
        }

        if ((gCV_MaxRenderDist.FloatValue > 0.0) && (GetVectorDistance(clientPos, currentPos) > gCV_MaxRenderDist.FloatValue))
        {
            prevPos = currentPos;
            prevFlags = aFrame.flags;
            if ((aFrame.flags & FL_ONGROUND) && !(prevFlags & FL_ONGROUND))
            {
                lastLandPos = currentPos;
                hasLastLand = true;
            }

            continue;
        }

        bool isPrestrafe = (prestrafeIndex != -1 && i == prestrafeIndex);

        // Skip frames that are too close together (but never skip prestrafe or landings)
        float frameDist = GetVectorDistance(prevPos, currentPos);
        bool isLandingFrame = (aFrame.flags & FL_ONGROUND) && !(prevFlags & FL_ONGROUND);
        if (minFrameDist > 0.0 && frameDist < minFrameDist && !isPrestrafe && !isLandingFrame)
        {
            prevFlags = aFrame.flags;
            continue;
        }

        if (isLandingFrame || isPrestrafe)
        {
            int finalColor[4];
            float finalWidth;
            if (aFrame.flags & FL_DUCKING)
            {
                for (int j = 0; j < 4; j++)
                {
                    finalColor[j] = gI_ColorShapeDuck[client][j];
                }

                finalWidth = gF_ClientShapeWidth[client];
            }
            else
            {
                for (int j = 0; j < 4; j++)
                {
                    finalColor[j] = gI_ColorShapeNoDuck[client][j];
                }

                finalWidth = gF_ClientShapeNoDuckWidth[client];
            }

            if (gI_ClientLineShape[client] == view_as<int>(Shape_Square))
            {
                DrawSquareShape(client, currentPos, finalColor, finalWidth, (gB_ClientIgnorez[client] ? gI_BeamSprite[DefaultIgnoreZ] : gI_BeamSprite[Default]));
            }
            else
            {
                DrawCircle(client, currentPos, finalColor, finalWidth, (gB_ClientIgnorez[client] ? gI_BeamSprite[DefaultIgnoreZ] : gI_BeamSprite[Default]));
            }

            if (mode == view_as<int>(Mode_2D) && hasLastLand && !isPrestrafe)
            {
                int color[4];
                for (int j = 0; j < 4; j++)
                {
                    color[j] = gI_ColorLineGround[client][j];
                }

                DrawBeamPoints(client, lastLandPos, currentPos, gCV_BeamLife.FloatValue, lineWidthGround, lineWidthGround, color, sprite);
            }

            lastLandPos = currentPos;
            hasLastLand = true;
        }

        if (mode == view_as<int>(Mode_3D))
        {
            if (!isPrestrafe)
            {
                int color[4];
                bool isOnGround = (aFrame.flags & FL_ONGROUND) != 0;
                float lineWidth;

                if (isOnGround)
                {
                    for (int j = 0; j < 4; j++)
                    {
                        color[j] = gI_ColorLineGround[client][j];
                    }
                    lineWidth = lineWidthGround;
                }
                else
                {
                    for (int j = 0; j < 4; j++)
                    {
                        color[j] = gI_ColorLine[client][j];
                    }

                    lineWidth = lineWidthAir;
                }

                if (gB_ClientPartialPath[client])
                {
                    int defaultSprite = gB_ClientIgnorez[client] ? gI_BeamSprite[DefaultIgnoreZ] : gI_BeamSprite[Default];
                    DrawDashedSegment(client, style, track, i - 1, i, prevPos, currentPos, color, lineWidth, defaultSprite);
                }
                else
                {
                    DrawBeamPoints(client, prevPos, currentPos, gCV_BeamLife.FloatValue, lineWidth, lineWidth, color, sprite);
                }
            }
        }

        prevPos = currentPos;
        prevFlags = aFrame.flags;
    }

    gF_PrevPos[client] = prevPos;
    gI_PrevFlags[client] = prevFlags;
    gF_LastLandPos[client] = lastLandPos;
    g_bHasLastLand[client] = hasLastLand;
    gI_CurrentIndex[client] = i;
}

void ZLerp(int client, ArrayList list, int index, float pos[3])
{
    if (index <= gI_LerpStartFrame[client] || index >= gI_LerpEndFrame[client])
    {
        int start = -1;
        int end = -1;
        for (int k = index - 1; k >= 0; k--)
        {
            frame_t f; list.GetArray(k, f, sizeof(frame_t));
            if (f.flags & FL_ONGROUND)
            {
                start = k;
                gF_LerpStartZ[client] = f.pos[2] + gCV_ZOffset.FloatValue;
                break;
            }
        }

        for (int k = index + 1; k < list.Length; k++)
        {
            frame_t f; list.GetArray(k, f, sizeof(frame_t));
            if (f.flags & FL_ONGROUND)
            {
                end = k;
                gF_LerpEndZ[client] = f.pos[2] + gCV_ZOffset.FloatValue;
                break;
            }
        }

        if (start != -1 && end != -1)
        {
            gI_LerpStartFrame[client] = start;
            gI_LerpEndFrame[client] = end;
        }
        else
        {
            return;
        }
    }

    int duration = gI_LerpEndFrame[client] - gI_LerpStartFrame[client];
    if (duration > 0)
    {
        float progress = float(index - gI_LerpStartFrame[client]) / float(duration);
        pos[2] = gF_LerpStartZ[client] + (gF_LerpEndZ[client] - gF_LerpStartZ[client]) * progress;
    }
}

void OpenLineMainMenu(int client, int displayAt = 0)
{
    Menu menu = new Menu(LineMainMenu_Handler);
    menu.SetTitle("Line Menu\n \n");
    menu.AddItem("e", gB_ClientLineEnabled[client] ? "Enabled: [+]\n \nMain Settings\n \n" : "Enabled: [-]\n \nMain Settings\n \n");

    char buff[64];
    Shavit_GetStyleStrings(gI_ClientLineStyle[client], sStyleName, buff, sizeof(buff));
    Format(buff, sizeof(buff), "Style: [%s]", buff);
    menu.AddItem("s", buff);
    menu.AddItem("m", (gI_ClientLineShape[client] == view_as<int>(Shape_Square)) ? "Shape: [Square]" : "Shape: [Circle]");

    if (gI_ClientLineMode[client] == view_as<int>(Mode_2D))
    {
        menu.AddItem("p", "Line Mode: [2D]");
    }
    else if (gI_ClientLineMode[client] == view_as<int>(Mode_3D))
    {
        menu.AddItem("p", "Line Mode: [3D]");
    }
    else
    {
        menu.AddItem("p", "Line Mode: [Shape Only]");
    }

    menu.AddItem("d", gB_ClientPartialPath[client] ? "Partial Path: [+]" : "Partial Path: [-]");
    menu.AddItem("z", gB_ClientLineZLerp[client] ? "Z-Lerp: [+]" : "Z-Lerp: [-]", (gI_ClientLineMode[client] == view_as<int>(Mode_3D)) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

    if (gB_ClientIgnorez[client])
    {
        menu.AddItem("w", "Render through wall: [+]");
    }
    else
    {
        menu.AddItem("w", "Render through wall: [-]");
    }

    menu.AddItem("fr", "Frame Range Settings");
    menu.AddItem("cl", "Line Settings");
    menu.AddItem("cs", "Shape Settings");
    menu.AddItem("r", "Reset");

    menu.ExitButton = true;
    menu.DisplayAt(client, displayAt, MENU_TIME_FOREVER);
}

public int LineMainMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[4];
            menu.GetItem(item, info, sizeof(info));

            bool reopen = true;
            if (StrEqual(info, "e"))
            {
                gB_ClientLineEnabled[client] = !gB_ClientLineEnabled[client];
            }
            else if (StrEqual(info, "s"))
            {
                OpenStyleMenu(client);
                reopen = false;
            }
            else if (StrEqual(info, "m"))
            {
                gI_ClientLineShape[client] = !gI_ClientLineShape[client];
            }
            else if (StrEqual(info, "d"))
            {
                gB_ClientPartialPath[client] = !gB_ClientPartialPath[client];
            }
            else if (StrEqual(info, "p"))
            {
                gI_ClientLineMode[client] = (gI_ClientLineMode[client] + 1) % 3;
            }
            else if (StrEqual(info, "z"))
            {
                gB_ClientLineZLerp[client] = !gB_ClientLineZLerp[client];
            }
            else if (StrEqual(info, "w"))
            {
                gB_ClientIgnorez[client] = !gB_ClientIgnorez[client];
            }
            else if (StrEqual(info, "fr"))
            {
                reopen = false;
                OpenFrameRangeMenu(client);
            }
            else if (StrEqual(info, "cl"))
            {
                reopen = false;
                OpenLineColorTypeMenu(client);
            }
            else if (StrEqual(info, "cs"))
            {
                reopen = false;
                OpenShapeTypeMenu(client);
            }
            else if (StrEqual(info, "r"))
            {
                OpenResetWarningMenu(client);
                reopen = false;
            }

            if (reopen)
            {
                SaveClientLineCookies(client);
                OpenLineMainMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenFrameRangeMenu(int client)
{
    Menu menu = new Menu(FrameRangeMenu_Handler);

    char title[128];
    FormatEx(title, sizeof(title), "Frame Range Settings\nAhead: %d | Back: %d\n \n", gI_ClientDrawAhead[client], gI_ClientDrawBack[client]);
    menu.SetTitle(title);

    menu.AddItem("a+", "Ahead +4");
    menu.AddItem("a-", "Ahead -4\n \n");
    menu.AddItem("b+", "Back +4");
    menu.AddItem("b-", "Back -4");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int FrameRangeMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[4];
            menu.GetItem(item, info, sizeof(info));

            if (StrEqual(info, "b+"))
            {
                gI_ClientDrawBack[client] = ClampFrameRangeBack(gI_ClientDrawBack[client] + 4);
            }
            else if (StrEqual(info, "b-"))
            {
                gI_ClientDrawBack[client] = ClampFrameRangeBack(gI_ClientDrawBack[client] - 4);
            }
            else if (StrEqual(info, "a+"))
            {
                gI_ClientDrawAhead[client] = ClampFrameRangeAhead(gI_ClientDrawAhead[client] + 4);
            }
            else if (StrEqual(info, "a-"))
            {
                gI_ClientDrawAhead[client] = ClampFrameRangeAhead(gI_ClientDrawAhead[client] - 4);
            }

            SaveClientLineCookies(client);
            OpenFrameRangeMenu(client);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineMainMenu(client, 7);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

int ClampFrameRangeBack(int value)
{
    return (value < 0) ? 0 : ((value > gCV_MaxDrawBack.IntValue) ? gCV_MaxDrawBack.IntValue : value);
}

int ClampFrameRangeAhead(int value)
{
    return (value < 0) ? 0 : ((value > gCV_MaxDrawAhead.IntValue) ? gCV_MaxDrawAhead.IntValue : value);
}

void OpenStyleMenu(int client, int displayAt = 0)
{
    Menu menu = new Menu(StyleMenu_Handler);
    menu.SetTitle("Choose style for line\n \n");

    char buff[64], indx[4];
    for (int i = 0; i < Shavit_GetStyleCount(); i++)
    {
        if ((gA_ReplayFrames[i][gI_ClientLineTrack[client]] != null) && (gA_ReplayFrames[i][gI_ClientLineTrack[client]].Length > 0))
        {
            Format(indx, sizeof(indx), "%d", i);
            Shavit_GetStyleStrings(i, sStyleName, buff, sizeof(buff));
            menu.AddItem(indx, buff, (gI_ClientLineStyle[client] == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        }
    }

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, displayAt, MENU_TIME_FOREVER);
}

public int StyleMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(item, info, sizeof(info));

            int style = StringToInt(info);
            gI_ClientLineStyle[client] = style;

            OpenStyleMenu(client, (gI_ClientLineStyle[client] / 7) * 7);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineMainMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenResetWarningMenu(int client)
{
    Menu menu = new Menu(ResetWarningMenu_Handler);
    menu.SetTitle("Reset line settings?\n \n");

    menu.AddItem("y", "Yes");
    menu.AddItem("n", "No");

    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ResetWarningMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[4];
            menu.GetItem(item, info, sizeof(info));
            if (StrEqual(info, "y"))
            {
                SetClientLineDefaults(client);
                SaveClientLineCookies(client);
            }

            OpenLineMainMenu(client);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineMainMenu(client, 7);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenLineColorTypeMenu(int client)
{
    Menu menu = new Menu(LineColorTypeMenu_Handler);
    menu.SetTitle("Line Color Settings\n \n");

    menu.AddItem("air", "Air Color");
    menu.AddItem("ground", "Ground Color");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int LineColorTypeMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[8];
            menu.GetItem(item, info, sizeof(info));

            if (StrEqual(info, "air"))
            {
                OpenLineSettingsMenu(client, false, 0);
            }
            else
            {
                OpenLineSettingsMenu(client, true, 0);
            }
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineMainMenu(client, 7);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenLineSettingsMenu(int client, bool isGround, int displayAt = 0)
{
    Menu menu = new Menu(LineSettingsMenu_Handler);

    float width = FloatSnapToStep(isGround ? gF_ClientLineGroundWidth[client] : gF_ClientLineWidth[client], 0.1);
    int colorIdx = isGround ? gI_ClientLineGroundColorIdx[client] : gI_ClientLineColorIdx[client];

    char buff[128];
    if (isGround)
    {
        Format(buff, sizeof(buff), "Line Settings (Ground)\nWidth: %.2f\n \n", width);
    }
    else
    {
        Format(buff, sizeof(buff), "Line Settings (Air)\nWidth: %.2f\n \n", width);
    }
    menu.SetTitle(buff);

    char prefix[4];
    prefix = isGround ? "g" : "a";

    char item[16];
    FormatEx(item, sizeof(item), "%s_i1", prefix);
    menu.AddItem(item, "Width +1.0");

    FormatEx(item, sizeof(item), "%s_d1", prefix);
    menu.AddItem(item, "Width -1.0\n \n");

    FormatEx(item, sizeof(item), "%s_i2", prefix);
    menu.AddItem(item, "Width +0.1");

    FormatEx(item, sizeof(item), "%s_d2", prefix);
    menu.AddItem(item, "Width -0.1\n \nColor:");

    char colorItem[32], index[8];
    for (int i = 0; i < ColorsCount; i++)
    {
        FormatEx(colorItem, sizeof(colorItem), "%s", ColorsTable[i].Name);
        FormatEx(index, sizeof(index), "%s_%d", prefix, i);
        menu.AddItem(index, colorItem, (colorIdx == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    menu.Pagination = 7;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, displayAt, MENU_TIME_FOREVER);
}

public int LineSettingsMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[16];
            menu.GetItem(item, info, sizeof(info));

            int displayAt = 0;
            bool isGround = (info[0] == 'g');

            if (StrContains(info, "_i1") != -1)
            {
                if (isGround)
                {
                    gF_ClientLineGroundWidth[client] = ClampWidth(gF_ClientLineGroundWidth[client] + 1.0);
                }
                else
                {
                    gF_ClientLineWidth[client] = ClampWidth(gF_ClientLineWidth[client] + 1.0);
                }
            }
            else if (StrContains(info, "_d1") != -1)
            {
                if (isGround)
                {
                    gF_ClientLineGroundWidth[client] = ClampWidth(gF_ClientLineGroundWidth[client] - 1.0);
                }
                else
                {
                    gF_ClientLineWidth[client] = ClampWidth(gF_ClientLineWidth[client] - 1.0);
                }
            }
            else if (StrContains(info, "_i2") != -1)
            {
                if (isGround)
                {
                    gF_ClientLineGroundWidth[client] = ClampWidth(gF_ClientLineGroundWidth[client] + 0.1);
                }
                else
                {
                    gF_ClientLineWidth[client] = ClampWidth(gF_ClientLineWidth[client] + 0.1);
                }
            }
            else if (StrContains(info, "_d2") != -1)
            {
                if (isGround)
                {
                    gF_ClientLineGroundWidth[client] = ClampWidth(gF_ClientLineGroundWidth[client] - 0.1);
                }
                else
                {
                    gF_ClientLineWidth[client] = ClampWidth(gF_ClientLineWidth[client] - 0.1);
                }
            }
            else
            {
                int underscore = FindCharInString(info, '_');
                int idx = StringToInt(info[underscore + 1]);
                idx = ClampColorIndex(idx);

                if (isGround)
                {
                    gI_ClientLineGroundColorIdx[client] = idx;
                }
                else
                {
                    gI_ClientLineColorIdx[client] = idx;
                }

                displayAt = ((isGround ? gI_ClientLineGroundColorIdx[client] : gI_ClientLineColorIdx[client]) + 4) / 7 * 7;
            }

            SaveClientLineCookies(client);
            OpenLineSettingsMenu(client, isGround, displayAt);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineColorTypeMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenShapeTypeMenu(int client)
{
    Menu menu = new Menu(ShapeTypeMenu_Handler);
    menu.SetTitle("Shape Type Menu\n \n");

    menu.AddItem("n", "No Duck");
    menu.AddItem("d", "Duck");

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ShapeTypeMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[4];
            menu.GetItem(item, info, sizeof(info));
            OpenShapeSettingsMenu(client, StrEqual(info, "n"), 0);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenLineMainMenu(client, 7);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void OpenShapeSettingsMenu(int client, bool noduck, int displayAt = 0)
{
    Menu menu = new Menu(LineShapeMenu_Handler);
    float width = FloatSnapToStep(noduck ? gF_ClientShapeNoDuckWidth[client] : gF_ClientShapeWidth[client], 0.1);
    int colorIdx = noduck ? gI_ClientShapeNoDuckColorIdx[client] : gI_ClientShapeColorIdx[client];

    char title[160];
    FormatEx(title, sizeof(title), noduck ? "Shape (No Duck)\nWidth: %.2f\n \n" : "Shape (Duck)\nWidth: %.2f\n \n", width);
    menu.SetTitle(title);

    char p[4];
    p = noduck ? "n" : "d";

    char buffer[16];
    Format(buffer, sizeof(buffer), "%s_i1", p);
    menu.AddItem(buffer, "Width +1.0");

    Format(buffer, sizeof(buffer), "%s_d1", p);
    menu.AddItem(buffer, "Width -1.0\n \n");

    Format(buffer, sizeof(buffer), "%s_i2", p);
    menu.AddItem(buffer, "Width +0.1");

    Format(buffer, sizeof(buffer), "%s_d2", p);
    menu.AddItem(buffer, "Width -0.1\n \nColor:");

    char item[32], index[8];
    for (int i = 0; i < ColorsCount; i++)
    {
        FormatEx(item, sizeof(item), "%s", ColorsTable[i].Name);
        FormatEx(index, sizeof(index), "%s_%d", p, i);
        menu.AddItem(index, item, (colorIdx == i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    menu.Pagination = 7;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, displayAt, MENU_TIME_FOREVER);
}

public int LineShapeMenu_Handler(Menu menu, MenuAction action, int client, int item)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[16];
            menu.GetItem(item, info, sizeof(info));

            int displayAt = 0;
            bool noduck = (info[0] == 'n');

            if (StrContains(info, "_i1") != -1)
            {
                UpdateShapeWidth(client, noduck, 1.0);
            }
            else if (StrContains(info, "_d1") != -1)
            {
                UpdateShapeWidth(client, noduck, -1.0);
            }
            else if (StrContains(info, "_i2") != -1)
            {
                UpdateShapeWidth(client, noduck, 0.1);
            }
            else if (StrContains(info, "_d2") != -1)
            {
                UpdateShapeWidth(client, noduck, -0.1);
            }
            else
            {
                int underscore = FindCharInString(info, '_');
                int idx = StringToInt(info[underscore + 1]);
                idx = ClampColorIndex(idx);

                if (noduck)
                {
                    gI_ClientShapeNoDuckColorIdx[client] = idx;
                }
                else
                {
                    gI_ClientShapeColorIdx[client] = idx;
                }

                displayAt = (((noduck ? gI_ClientShapeNoDuckColorIdx[client] : gI_ClientShapeColorIdx[client]) + 4) / 7) * 7;
            }

            SaveClientLineCookies(client);
            OpenShapeSettingsMenu(client, noduck, displayAt);
        }
        case MenuAction_Cancel:
        {
            if (item == MenuCancel_ExitBack)
            {
                OpenShapeTypeMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }

    return 0;
}

void UpdateShapeWidth(int client, bool noduck, float amount)
{
    if (noduck)
    {
        gF_ClientShapeNoDuckWidth[client] = ClampWidth(gF_ClientShapeNoDuckWidth[client] + amount);
    }
    else
    {
        gF_ClientShapeWidth[client] = ClampWidth(gF_ClientShapeWidth[client] + amount);
    }
}

public void OnClientCookiesCached(int client)
{
    if (client < 1 || client > MaxClients || !IsClientConnected(client) || IsFakeClient(client))
    {
        return;
    }

    SetClientLineDefaults(client);

    if (CookieIsEmpty(client, gC_LineCookieEnabled))
    {
        SaveClientLineCookies(client);
        return;
    }

    char buff[32];
    gC_LineCookieEnabled.Get(client, buff, sizeof(buff));
    gB_ClientLineEnabled[client] = (StringToInt(buff) != 0);

    gC_LineCookieShapeType.Get(client, buff, sizeof(buff));
    gI_ClientLineShape[client] = StringToInt(buff);

    gC_LineCookieMode.Get(client, buff, sizeof(buff));
    gI_ClientLineMode[client] = StringToInt(buff);

    gC_LineCookieZLerp.Get(client, buff, sizeof(buff));
    gB_ClientLineZLerp[client] = (StringToInt(buff) != 0);

    gC_LineCookePartial.Get(client, buff, sizeof(buff));
    gB_ClientPartialPath[client] = (StringToInt(buff) != 0);

    gC_LineCookieIgnorez.Get(client, buff, sizeof(buff));
    gB_ClientIgnorez[client] = (StringToInt(buff) != 0);

    gC_LineCookieLine.Get(client, buff, sizeof(buff));
    ParseWidthColor(buff, gF_ClientLineWidth[client], gI_ClientLineColorIdx[client]);

    gC_LineCookieLineGround.Get(client, buff, sizeof(buff));
    if (buff[0] != '\0')
    {
        ParseWidthColor(buff, gF_ClientLineGroundWidth[client], gI_ClientLineGroundColorIdx[client]);
    }

    gC_LineCookieShapeDuck.Get(client, buff, sizeof(buff));
    ParseWidthColor(buff, gF_ClientShapeWidth[client], gI_ClientShapeColorIdx[client]);

    gC_LineCookieShape.Get(client, buff, sizeof(buff));
    ParseWidthColor(buff, gF_ClientShapeNoDuckWidth[client], gI_ClientShapeNoDuckColorIdx[client]);

    gC_LineCookieDrawBack.Get(client, buff, sizeof(buff));
    if (buff[0] != '\0')
    {
        gI_ClientDrawBack[client] = ClampFrameRangeBack(StringToInt(buff));
    }

    gC_LineCookieDrawAhead.Get(client, buff, sizeof(buff));
    if (buff[0] != '\0')
    {
        gI_ClientDrawAhead[client] = ClampFrameRangeAhead(StringToInt(buff));
    }
}

void SetClientLineDefaults(int client)
{
    gB_ClientLineEnabled[client] = true;
    gI_ClientLineShape[client] = view_as<int>(Shape_Circle);
    gI_ClientLineMode[client] = view_as<int>(Mode_3D);
    gB_ClientLineZLerp[client] = false;
    gB_ClientIgnorez[client] = false;
    gB_ClientPartialPath[client] = true;
    gI_ClientLineStyle[client] = NextStyleForLine(client, true);
    gI_ClientLineTrack[client] = 0;
    gF_ClientLineWidth[client] = 0.4;
    gF_ClientLineGroundWidth[client] = 0.4;
    gF_ClientShapeWidth[client] = 0.4;
    gF_ClientShapeNoDuckWidth[client] = 0.4;
    gI_ClientLineColorIdx[client] = ClampColorIndex(5);
    gI_ClientLineGroundColorIdx[client] = ClampColorIndex(2);
    gI_ClientShapeColorIdx[client] = ClampColorIndex(4);
    gI_ClientShapeNoDuckColorIdx[client] = ClampColorIndex(0);
    gI_ClientDrawBack[client] = gCV_DrawBackDefault.IntValue;
    gI_ClientDrawAhead[client] = gCV_DrawAheadDefault.IntValue;
}

void SaveClientLineCookies(int client)
{
    char buff[32];
    IntToString(gB_ClientLineEnabled[client], buff, sizeof(buff));
    gC_LineCookieEnabled.Set(client, buff);

    IntToString(gI_ClientLineShape[client], buff, sizeof(buff));
    gC_LineCookieShapeType.Set(client, buff);

    IntToString(gI_ClientLineMode[client], buff, sizeof(buff));
    gC_LineCookieMode.Set(client, buff);

    IntToString(gB_ClientPartialPath[client], buff, sizeof(buff));
    gC_LineCookePartial.Set(client, buff);

    IntToString(gB_ClientLineZLerp[client], buff, sizeof(buff));
    gC_LineCookieZLerp.Set(client, buff);

    IntToString(gB_ClientIgnorez[client], buff, sizeof(buff));
    gC_LineCookieIgnorez.Set(client, buff);

    FormatEx(buff, sizeof(buff), "%.2f;%d", gF_ClientLineWidth[client], gI_ClientLineColorIdx[client]);
    gC_LineCookieLine.Set(client, buff);

    FormatEx(buff, sizeof(buff), "%.2f;%d", gF_ClientLineGroundWidth[client], gI_ClientLineGroundColorIdx[client]);
    gC_LineCookieLineGround.Set(client, buff);

    FormatEx(buff, sizeof(buff), "%.2f;%d", gF_ClientShapeWidth[client], gI_ClientShapeColorIdx[client]);
    gC_LineCookieShapeDuck.Set(client, buff);

    FormatEx(buff, sizeof(buff), "%.2f;%d", gF_ClientShapeNoDuckWidth[client], gI_ClientShapeNoDuckColorIdx[client]);
    gC_LineCookieShape.Set(client, buff);

    IntToString(gI_ClientDrawBack[client], buff, sizeof(buff));
    gC_LineCookieDrawBack.Set(client, buff);

    IntToString(gI_ClientDrawAhead[client], buff, sizeof(buff));
    gC_LineCookieDrawAhead.Set(client, buff);
}

void GetColorRGBAFromIndex(int idx, int outRGBA[4])
{
    idx = ClampColorIndex(idx);
    if (ColorsCount <= 0)
    {
        outRGBA = {255, 255, 255, 255};
        return;
    }

    outRGBA = ColorsTable[idx].RGBA;
}

void DrawBeamPoints(int client, const float start[3], const float end[3], float life, float width, float endWidth, const int color[4], int sprite)
{
    TE_SetupBeamPoints(start, end, sprite, 0, 0, 0, life, width, endWidth, 0, 0.0, color, 0);
    TE_SendToClient(client);
}

void DrawDashedSegment(int client, int style, int track, int prevIndex, int currIndex, const float start[3], const float end[3], const int color[4], float width, int sprite)
{
    float dashLen = gCV_PartialDashLength.FloatValue;
    float gapLen = gCV_PartialGapLength.FloatValue;
    float cycleLen = dashLen + gapLen;

    if (cycleLen <= 0.0 || gapLen <= 0.0)
    {
        DrawBeamPoints(client, start, end, gCV_BeamLife.FloatValue, width, width, color, sprite);
        return;
    }

    float segmentDist = GetVectorDistance(start, end);
    if (segmentDist <= 0.0)
    {
        return;
    }

    // Get precomputed distances for stable rendering
    ArrayList distances = gA_FrameDistances[style][track];
    if (distances == null || prevIndex < 0 || currIndex >= distances.Length)
    {
        DrawBeamPoints(client, start, end, gCV_BeamLife.FloatValue, width, width, color, sprite);
        return;
    }

    float startDist = distances.Get(prevIndex);

    // Direction vector
    float dir[3];
    SubtractVectors(end, start, dir);
    ScaleVector(dir, 1.0 / segmentDist);

    float traveled = 0.0;
    while (traveled < segmentDist)
    {
        // Current absolute distance along path
        float currentAbsDist = startDist + traveled;
        // Current position in dash/gap cycle
        float cyclePos = FloatM(currentAbsDist, cycleLen);
        bool inDash = (cyclePos < dashLen);

        if (inDash)
        {
            // Calculate how much dash remains
            float dashRemaining = dashLen - cyclePos;
            float canDraw = segmentDist - traveled;
            float drawLen = (canDraw < dashRemaining) ? canDraw : dashRemaining;

            float dashStart[3], dashEnd[3];
            for (int j = 0; j < 3; j++)
            {
                dashStart[j] = start[j] + dir[j] * traveled;
                dashEnd[j] = start[j] + dir[j] * (traveled + drawLen);
            }

            DrawBeamPoints(client, dashStart, dashEnd, gCV_BeamLife.FloatValue, width, width, color, sprite);
            traveled += drawLen;
        }
        else
        {
            // In gap, skip to next dash
            float gapRemaining = cycleLen - cyclePos;
            float canSkip = segmentDist - traveled;
            float skipLen = (canSkip < gapRemaining) ? canSkip : gapRemaining;
            traveled += skipLen;
        }
    }
}

float FloatM(float a, float b)
{
    return a - b * RoundToFloor(a / b);
}

void DrawSquareShape(int client, const float center[3], const int color[4], float width, int sprite)
{
    float p[4][3], half = 12.0;
    p[0][0] = center[0] - half;
    p[0][1] = center[1] - half;
    p[0][2] = center[2];

    p[1][0] = center[0] + half;
    p[1][1] = center[1] - half;
    p[1][2] = center[2];

    p[2][0] = center[0] + half;
    p[2][1] = center[1] + half;
    p[2][2] = center[2];

    p[3][0] = center[0] - half;
    p[3][1] = center[1] + half;
    p[3][2] = center[2];

    DrawBeamPoints(client, p[0], p[1], gCV_BeamLife.FloatValue, width, width, color, sprite);
    DrawBeamPoints(client, p[1], p[2], gCV_BeamLife.FloatValue, width, width, color, sprite);
    DrawBeamPoints(client, p[2], p[3], gCV_BeamLife.FloatValue, width, width, color, sprite);
    DrawBeamPoints(client, p[3], p[0], gCV_BeamLife.FloatValue, width, width, color, sprite);
}

void DrawCircle(int client, const float center[3], const int color[4], float width, int sprite)
{
    float radius = 12.0;
    const int sides = 11;

    float prev[3]; float cur[3];
    prev[0] = center[0] + radius;
    prev[1] = center[1];
    prev[2] = center[2];

    for (int i = 1; i <= sides; i++)
    {
        float ang = 6.283185 * (float(i) / float(sides));
        cur[0] = center[0] + Cosine(ang) * radius;
        cur[1] = center[1] + Sine(ang) * radius;
        cur[2] = center[2];

        DrawBeamPoints(client, prev, cur, gCV_BeamLife.FloatValue, width, width, color, sprite);

        prev = cur;
    }
}

int ClampColorIndex(int idx)
{
    if (ColorsCount <= 0 || idx < 0)
    {
        return 0;
    }

    if (idx >= ColorsCount)
    {
        return ColorsCount - 1;
    }

    return idx;
}

float ClampWidth(float w)
{
    return (w < 0.1) ? 0.1 : (w > 10.0) ? 10.0 : w;
}

bool ParseWidthColor(const char[] s, float &width, int &colorIdx)
{
    if (s[0] == '\0')
    {
        return false;
    }

    char parts[2][32];
    if (ExplodeString(s, ";", parts, 2, 32, false) < 2)
    {
        return false;
    }

    width = ClampWidth(StringToFloat(parts[0]));
    colorIdx = ClampColorIndex(StringToInt(parts[1]));

    return true;
}

bool CookieIsEmpty(int client, Cookie c)
{
    char buff[8];
    c.Get(client, buff, sizeof(buff));
    return (buff[0] == '\0');
}

int NextStyleForLine(int client, bool init = false)
{
    for (int i = (init ? 0 : gI_ClientLineStyle[client] + 1); i < STYLE_LIMIT; i++)
    {
        if ((gA_ReplayFrames[i][gI_ClientLineTrack[client]] != null) && (gA_ReplayFrames[i][gI_ClientLineTrack[client]].Length > 0))
        {
            return i;
        }
    }

    return 0;
}

stock void Capitalize(char[] str, bool toLower = false)
{
    if (str[0] == '\0')
    {
        return;
    }

    if (toLower)
    {
        int i = 0;
        while (str[i] != '\0')
        {
            str[i] = CharToLower(str[i]);
            i++;
        }
    }

    if (str[0] >= 'a' && str[0] <= 'z')
    {
        str[0] -= 32;
    }
}

stock float FloatSnapToStep(float v, float step)
{
    if (step <= 0.0)
    {
        return v;
    }

    return float(RoundFloat(v / step)) * step;
}
