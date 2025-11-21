untyped
global function Gauntlet_NetworkRegistration
global function Gauntlet_ServerStart
global function Gauntlet_StartRun
global function Gauntlet_StopRun
global function Gauntlet_ResetRun
global function ClCommand_ResetRun
global function Gauntlet_PlayerConnected
global function Gauntlet_PlayerDisconnected

struct PlayerRunData
{
    bool gauntletTimerActive = false
    float gauntletStartTime = -1.0
}

struct {
    entity gauntletStartTrigger
    entity gauntletEndTrigger

    table<entity, PlayerRunData> playerData
} file


// ======================================================================
// Setup Remote functions
// ======================================================================
void function Gauntlet_NetworkRegistration()
{
    AddCallback_OnRegisteringCustomNetworkVars( RegisterRemoteFunctions )
}

void function RegisterRemoteFunctions()
{
    Remote_RegisterFunction( "ScriptCallback_StartTimer" )
    Remote_RegisterFunction( "ScriptCallback_StopTimer" )
    Remote_RegisterFunction( "ScriptCallback_ResetTimer" )
}


// ======================================================================
// Main entry point
// ======================================================================
void function Gauntlet_ServerStart() {
    string mapName = GetMapName()
    if ( mapName.find("surf") != null )
    {
        thread Gauntlet_Server_Init()
    }
}


// ======================================================================
// Init Triggers and Callbacks
// ======================================================================
void function Gauntlet_Server_Init()
{   
    wait(3)
    //print("gauntlet init start ********************************")
    RegisterSignal( "trigStart_OnStartTouch" )
    RegisterSignal( "trigEnd_OnStartTouch" )
    RegisterSignal( "Gauntlet_ForceRestart" )

    // Register Client Command for manual reset
    //AddClientCommandCallback( "reset_run", ClCommand_ResetRun )

    
    file.gauntletStartTrigger = GetEntByScriptName( "trigger_start_line" )
    file.gauntletEndTrigger   = GetEntByScriptName( "trigger_finish_line" )


    if ( IsValid( file.gauntletStartTrigger ) )
    {
        thread Gauntlet_MonitorTrigger( file.gauntletStartTrigger, "trigStart_OnStartTouch" )
    }
    if ( IsValid( file.gauntletEndTrigger ) )
    {
        thread Gauntlet_MonitorTrigger( file.gauntletEndTrigger, "trigEnd_OnStartTouch" )
    }

    // Join and leaving logic
    AddCallback_OnClientConnected( Gauntlet_PlayerConnected )
    AddCallback_OnClientDisconnected( Gauntlet_PlayerDisconnected )

    // Gets player who joined before onConnected was added
    array<entity> players = GetConnectingAndConnectedPlayerArray() //GetPlayerArray() 
    foreach ( entity player in players )
    {
        Gauntlet_PlayerConnected( player )
    }
   // print("gauntlet init finish ********************************")
}

// ======================================================================
// Connecting and Disconnting logic
// ======================================================================
void function Gauntlet_PlayerConnected( entity player )
{
    //print("******************************gauntlet player connected ********************************")
    if ( IsValid( player ) ) {

        if ( !(player in file.playerData) ) {
            //print("adding player*******************")
            PlayerRunData playerData
            file.playerData[player] <- playerData
        }
        
        thread Gauntlet_RunLogic( player )
    }
}

void function Gauntlet_PlayerDisconnected( entity player )
{
    if ( player in file.playerData )
    {
        delete file.playerData[ player ]
    }
}


// ======================================================================
// Monitors Triggers
// ======================================================================
void function Gauntlet_MonitorTrigger( entity trigger, string signalName )
{
    trigger.EndSignal( "OnDestroy" )
    
    while ( 1 )
    {
        table result = WaitSignal( trigger, "OnStartTouch" )
        entity activator = expect entity( result.activator )

        // Validation (must be a valid player/pilot)
        if ( !IsValid( activator ) || !activator.IsPlayer() || activator.IsTitan() )
            continue
        
        // Signal the player entity
        Signal( activator, signalName )
    }
}


// ======================================================================
// Player Run Logic
// ======================================================================
void function Gauntlet_RunLogic( entity player )
{
    player.EndSignal( "OnDestroy" ) 

    while ( 1 )
    {
        //print("gauntlet logic ********************************")
        // 1. Wait for Start Trigger Signal
        player.WaitSignal( "trigStart_OnStartTouch" )

        // 2. Start the Run
        Gauntlet_StartRun( player )

        // 3. Wait for End Trigger Signal OR Reset/Death
        table result = player.WaitSignal( "trigEnd_OnStartTouch", "Gauntlet_ForceRestart", "OnDeath" )
        string signal = expect string( result.signal )
        
        // 4. Stop or Reset the Run
        if ( signal == "trigEnd_OnStartTouch" )
        {
            Gauntlet_StopRun( player )
        }
        else
        {
            // Manual reset or death
            Gauntlet_ResetRun( player )
        }

        // Delay to prevent immediate re-triggering
        wait 0.1
    }
}

// ======================================================================
// Run Controllers
// ======================================================================
void function Gauntlet_StartRun( entity player )
{
    PlayerRunData data = file.playerData[ player ]
    
    if ( data.gauntletTimerActive )
        return

    data.gauntletTimerActive = true
    data.gauntletStartTime = Time()
    file.playerData[ player ] = data 
    //print("start Run")

    Remote_CallFunction_Replay( player, "ScriptCallback_StartTimer" )
}

void function Gauntlet_StopRun( entity player )
{
    PlayerRunData data = file.playerData[ player ]
    
    if ( !data.gauntletTimerActive )
        return

    float finalTime = Time() - data.gauntletStartTime
    data.gauntletTimerActive = false
    file.playerData[ player ] = data 
    //print("stop Run")

    Remote_CallFunction_Replay( player, "ScriptCallback_StopTimer", finalTime )
}

void function Gauntlet_ResetRun( entity player )
{
    PlayerRunData data = file.playerData[ player ]

    data.gauntletTimerActive = false
    file.playerData[ player ] = data 
    //print("reset Run")

    Remote_CallFunction_Replay( player, "ScriptCallback_ResetTimer" )
}

// ======================================================================
// Client Commmand to Reset Run
// ======================================================================
bool function ClCommand_ResetRun( entity player, array<string> args )
{
    // Signal the run logic thread to break out of its wait state
    player.Signal( "Gauntlet_ForceRestart" )
    return true
}