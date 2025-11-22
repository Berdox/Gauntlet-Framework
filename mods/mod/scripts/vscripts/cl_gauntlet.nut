global function Gauntlet_NetworkRegistration
global function ScriptCallback_StartTimer
global function ScriptCallback_StopTimer
global function ScriptCallback_ResetTimer
global function Gauntlet_DestroyFinishedTimer

struct
{
    var timerRUI
    var speedRUI
    var finishedTimerRUI
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


#if CLIENT

// ======================================================================
// Start Timer Display
// ======================================================================
void function ScriptCallback_StartTimer()
{
    if ( IsValid( file.timerRUI ) )
        RuiDestroy( file.timerRUI )
    if ( IsValid( file.speedRUI ) )
        RuiDestroy( file.speedRUI )


    // Timer
    file.timerRUI = RuiCreate( $"ui/gauntlet_hud.rpak", clGlobal.topoCockpitHud, RUI_DRAW_COCKPIT, 0 )
    RuiSetGameTime( file.timerRUI, "startTime", Time() )

    // Track speed
    entity player = GetLocalViewPlayer()
    RuiTrackFloat3( file.timerRUI, "playerPos", player, RUI_TRACK_ABSORIGIN_FOLLOW )
    RuiSetBool( file.timerRUI, "useMetric", true )
    
    
    // Tracks the local player's position, which the RUI uses to calculate speed/velocity
   //RuiTrackFloat3(file.speedRUI, "playerPos", GetLocalViewPlayer(), RUI_TRACK_ABSORIGIN_FOLLOW)

}

// ======================================================================
// Stop Timer and Displays final time
// ======================================================================

void function ScriptCallback_StopTimer(float finalTime)
{
    float displayDuration = 2.0

    // Destroy speed hud
    if ( IsValid( file.timerRUI ) )
    {
        RuiDestroy( file.timerRUI )
        file.timerRUI = null
    }

    // Create final-time display (independent timer)
    file.finishedTimerRUI = RuiCreate($"ui/gauntlet_hud.rpak", clGlobal.topoCockpitHud, RUI_DRAW_COCKPIT, 0)
    RuiSetBool( file.finishedTimerRUI, "runFinished", true )
    RuiSetFloat( file.finishedTimerRUI, "finalTime", finalTime )

    thread Gauntlet_DestroyFinishedTimer(displayDuration)
}

void function Gauntlet_DestroyFinishedTimer(float delay)
{
    wait delay

    if ( IsValid( file.finishedTimerRUI ) )
        RuiDestroy( file.finishedTimerRUI )

    file.finishedTimerRUI = null
}

// ======================================================================
// Resets Timer
// ======================================================================
void function ScriptCallback_ResetTimer()
{
    // Destroy the active timer RUI
    if ( IsValid( file.timerRUI ) )
    {
        RuiDestroy( file.timerRUI )
        file.timerRUI = null
    }
    // Destroy the active speedometer RUI
    if ( IsValid( file.speedRUI ) )
    {
        RuiDestroy( file.speedRUI )
        file.speedRUI = null
    }
}

#endif