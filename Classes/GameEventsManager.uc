class GameEventsManager extends Actor;

var GameEventsConfig Config;
var class<GameEventsPublisherHelper> Helper;
var GameEventsPublisherSubmitter Submitter;
var MatchStartTimedTrigger StartMatchTrigger;

struct PlayerTracker {
    var int PlayerID;
    var int TeamKills;
};

var PlayerTracker TrackedPlayers[32];

function Setup(GameEventsConfig configuration) {
    Config = configuration;
    Helper = class'GameEventsPublisherHelper';
    Submitter = Level.Spawn(class'GameEventsPublisherSubmitter');
    StartMatchTrigger = Level.Spawn(class'MatchStartTimedTrigger', Self, 'MatchStart');
    InitializeTracking();
}

function InitializeTracking() {
    local int i;
    
    for (i = 0; i < ArrayCount(TrackedPlayers); i++) {
        TrackedPlayers[i].PlayerID = -1;
        TrackedPlayers[i].TeamKills = 0;
    }
}

function int GetPlayerSlot(int PlayerID) {
    local int i;
    
    for (i = 0; i < ArrayCount(TrackedPlayers); i++) {
        if (TrackedPlayers[i].PlayerID == PlayerID) {
            return i;
        }
    }
    
    for (i = 0; i < ArrayCount(TrackedPlayers); i++) {
        if (TrackedPlayers[i].PlayerID == -1) {
            TrackedPlayers[i].PlayerID = PlayerID;
            return i;
        }
    }
    
    LogInternal("WARNING: No free slot for PlayerID "$PlayerID);
    return -1;
}

function IncrementTeamKills(int PlayerID) {
    local int slot;
    
    slot = GetPlayerSlot(PlayerID);
    if (slot >= 0) {
        TrackedPlayers[slot].TeamKills++;
        LogInternal("Player "$PlayerID$" now has "$TrackedPlayers[slot].TeamKills$" team kills");
    }
}

function int GetTeamKills(int PlayerID) {
    local int i;
    
    for (i = 0; i < ArrayCount(TrackedPlayers); i++) {
        if (TrackedPlayers[i].PlayerID == PlayerID) {
            return TrackedPlayers[i].TeamKills;
        }
    }
    
    return 0;
}

function StartMatch() {
    GotoState('MatchStarted');
}

function FlagCapture(PlayerReplicationInfo scorerPRI, CTFFlag flag) {
    Publish('FlagCapture', scorerPRI.PlayerId);
}

function Trigger(Actor Other, Pawn EventInstigator) {
    if (Other == Level.Game) {
        if (EventInstigator != None)
            LogInternal(Self$"(Other.Name="$Other.Name$") by "$EventInstigator.Name);
        else
            LogInternal(Self$"(Other.Name="$Other.Name$") by None");

        GotoState('MatchEnded');
    }
    else {
        LogInternal(Self@"Got Trigger of: "$Other.Name@"by"@EventInstigator.Name);
    }
    super.Trigger(Other, EventInstigator);
}

function LogInternal(String text) {
    Log("++ [GameEventsPublisher]"@text, 'GameEventsManager');
}

function Publish(Name eventName, int instigatorId) {
    local GameEventArgs arg;

    LogInternal("GameEventsManager.Publish(eventName="$eventName$")");
    arg = class'GameEventArgs'.static.Create(Level, eventName, instigatorId);
    class'GameEventArgs'.static.PrintPlayers(arg);
    Submitter.OpenAndSend(Config.Host, Config.Port, Config.Path, Config.PasswordHeaderName, Config.Password, arg.ConvertToJson(Config.TeamInfoJson, Config.PlayerInfoJson), Config.Debug, eventName);
}

// function Timer() {
//     PrintCurrentInformation();
// }

// States
auto state WaitingPlayers {

    function Timer() {
        if (Level.TimeSeconds < Config.WaitingPlayersIntervalInSecsExpired)
        {
            Publish(GetStateName(), -1);
        }
        else
        {
            Publish('WaitingPlayersEnd', -1);
            LogInternal("GameEventsManager.WaitingPlayersExpired("$Config.WaitingPlayersIntervalInSecsExpired$")");
            Disable('Timer');
        }
    }

Begin:
    Publish(GetStateName(), -1);
    // SetTimer(Config.WaitingPlayersDuration, false);
    SetTimer(Config.WaitingPlayersIntervalInSecs, true);
}

state MatchStarted {

    function Timer() {
        local DeathMatchPlus DMP;

        DMP = DeathMatchPlus(Level.Game);
        if (DMP != None
            && DMP.TimeLimit > 0
            && Config.SuppressMatchUpdatesLastSeconds > 0
            && DMP.RemainingTime >= 0
            && DMP.RemainingTime <= Config.SuppressMatchUpdatesLastSeconds)
        {
            return;
        }

        Publish('MatchStartedUpdate', -1);
        LogInternal("GameEventsManager.MatchStartedUpdate("$Config.MatchStartedIntervalInSecs$")");
    }

Begin:
    InitializeTracking();
    Publish('MatchStarted', -1);
    SetTimer(Config.MatchStartedIntervalInSecs, true);
}

state MatchEnded {

Begin:
    Publish('MatchEnded', -1);
}
// EOF States

// Debug
function PrintCurrentInformation() {
    local int i;
    local GameEventArgs arg;

    arg = class'GameEventArgs'.static.Create(Level, GetStateName(), -1);
    Log("GlobalTimer => NetWait: "$(DeathMatchPlus(Level.Game).NetWait));
    Log("GlobalTimer => ElapsedTime: "$DeathMatchPlus(Level.Game).ElapsedTime);
    Log("GlobalTimer => TimeSeconds: "$Level.TimeSeconds);
    Log("GlobalTimer => CountDown: "$DeathMatchPlus(Level.Game).CountDown);
    Log("GlobalTimer => CountDown(default): "$DeathMatchPlus(Level.Game).default.CountDown);
    Log("GlobalTimer => bStartMatch: "$(DeathMatchPlus(Level.Game).bStartMatch));
    Log("GlobalTimer => bRequireReady: "$(DeathMatchPlus(Level.Game).bRequireReady));
    Log("GlobalTimer => bNetReady: "$(DeathMatchPlus(Level.Game).bNetReady));
    Log("GlobalTimer => RemainingTime: "$(DeathMatchPlus(Level.Game).RemainingTime));
    Log("GlobalTimer => StartTime: "$(DeathMatchPlus(Level.Game).StartTime));
    if (arg.NumPlayers > 0)
    {
        for (i = 0; i < arg.NumPlayers; i++) {
            Log("Player["$i$"] Name="$arg.GetPlayer(i).Name$"|Ready:"$arg.GetPlayer(i).Ready);
        }
    }
    else {
        Log("NO PLAYERS!");
    }
}
// EOF Debug
