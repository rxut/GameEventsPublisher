class GameEventsPublisherSubmitter extends UBrowserBufferedTCPLink;

var bool      bIsConnected;

var String    sHost;
var int       iHostPort;
var IpAddr    ipAddrServerIpAddr;
var String    sPasswordHeaderName;
var String    sPassword;
var String    sPath;
var String    sData;
var bool      Debug;

var GameEventsConfig Config;

var bool      bInFlight;
var bool      bHasPending;
var Name      PendingEventName;
var String    PendingHost;
var int       PendingPort;
var String    PendingPath;
var String    PendingPasswordHeaderName;
var String    PendingPassword;
var String    PendingData;
var bool      PendingDebug;

function PostBeginPlay()
{
  Super.PostBeginPlay();
  Disable('Tick');
}

function OpenAndSend(String host, int port, String path, String passwordHeaderName, String password, String data, optional bool debug, optional Name eventName)
{
  if (bInFlight)
  {
    if (bHasPending && PendingEventName == 'MatchEnded' && eventName != 'MatchEnded')
      return;

    bHasPending = true;
    PendingEventName = eventName;
    PendingHost = host;
    PendingPort = port;
    PendingPath = path;
    PendingPasswordHeaderName = passwordHeaderName;
    PendingPassword = password;
    PendingData = data;
    PendingDebug = debug;
    Log("++ [GameEventsPublisher] Queued pending event:"@eventName);
    return;
  }

  bInFlight = true;

  sHost = host;
  iHostPort = port;
  sPath = path;
  sPasswordHeaderName = passwordHeaderName;
  sPassword = password;
  sData = data;
  Debug = debug;

  ResetBuffer();
  Resolve(host);
}

function FlushPending()
{
  local String host;
  local int port;
  local String path;
  local String headerName;
  local String password;
  local String data;
  local bool debug;
  local Name eventName;

  bInFlight = false;

  if (bHasPending)
  {
    host = PendingHost;
    port = PendingPort;
    path = PendingPath;
    headerName = PendingPasswordHeaderName;
    password = PendingPassword;
    data = PendingData;
    debug = PendingDebug;
    eventName = PendingEventName;

    bHasPending = false;

    Log("++ [GameEventsPublisher] Sending queued event:"@eventName);
    OpenAndSend(host, port, path, headerName, password, data, debug, eventName);
  }
}

function Resolved(IpAddr Addr)
{
  ipAddrServerIpAddr.Addr = Addr.Addr;
  ipAddrServerIpAddr.Port = iHostPort;

  Log("++ [GameEventsPublisher] Successfully resolved Server IP Address["$ipAddrServerIpAddr.Addr$"]");

  if (BindPort() == 0)
  {
    Log("++ [GameEventsPublisher] Failed to resolve port:"$ipAddrServerIpAddr.Port);
    FlushPending();
    return;
  }
  Open(ipAddrServerIpAddr);
}

function ResolveFailed()
{
  Log("++ [GameEventsPublisher] Failed to resolve ip address:"$sHost);
  FlushPending();
}

function Disconnect()
{
  bIsConnected = false;
  Close();
}

event Opened()
{
  Log("++ [GameEventsPublisher] Link is open.");
  GotoState('Submitting');
}

event Closed()
{
  Log("++ [GameEventsPublisher] Connection closed.");
  bIsConnected = false;
  FlushPending();
}

function ProcessInput(string Line)
{
  if (Debug) {
    Log("[Debug]" @ Line, Class.Name);
  }
}

function Tick(float DeltaTime)
{
  local string Line;

  DoBufferQueueIO();

  if (ReadBufferedLine(Line))
    ProcessInput(Line);
}


// States
auto state Created
{

Begin:

}

state Submitting
{
  function ProcessInput(string Line)
  {
    local bool IsError;
    local String ErrorMessage;

    if (InStr(Line, "200") > 0)
    {
      IsError = false;
    }
    else
    {
      IsError = true;
      if (InStr(Line, "500") > 0)
      {
        ErrorMessage = "Server Error";
      }
      else if (InStr(Line, "401") > 0)
      {
        ErrorMessage = "Unauthorized";
      }
      else
      {
        ErrorMessage = Line;
      }
    }

    if (IsError)
    {
      Log("++ [GameEventsPublisher] Error! " $ ErrorMessage);
      Close();
      return;
    }
    else
    {
      GotoState('Submitted');
    }

    Global.ProcessInput(Line);
  }

Begin:
    Log("++ [GameEventsPublisher] Submitting:"@sData);
    SendBufferedData("POST /"$sPath$" HTTP/1.0" $ CR$LF);
    SendBufferedData("User-Agent: Unreal" $ CR$LF);
    SendBufferedData("Host:" @ sHost$":"$iHostPort$CR$LF);
    SendBufferedData("Connection: close"$CR$LF);
    SendBufferedData("Content-Type: application/json" $ CR$LF);
    SendBufferedData("Content-Length:" @ Len(sData) $CR$LF);

    if (Len(sPassword) > 0)
    {
      SendBufferedData(sPasswordHeaderName$":" @ sPassword $CR$LF);
    }
    SendBufferedData(CR$LF);
    SendBufferedData(sData);
}

state Submitted
{
  function ProcessInput(string Line)
  {
    Global.ProcessInput(Line);
  }

Begin:
    bIsConnected = true;
    Log("++ [GameEventsPublisher] Successfully sent data to server.", Class.Name);
    Close();
}
// EOF States
