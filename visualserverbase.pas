unit visualserverbase;

interface

uses windows, classes, sysutils, blcksock, syncobjs, vstypedef;

var ErrorCodes: Array[0..3] of String =
      ('',
       'No listen port specified',
       'Listen failed',
       'Port in use'
      );

type
  TServerHandler = class;
  TVisualListen = class;

  THandlerClass = class of TServerHandler;
  TThreadClass = class of TVisualListen;

  TRequest = class (TObject) //Universal object containing the commands
    RawRequest: String;
    Command:String;
    Parameter: String; //mostly one, else in customized format
    CommandLine:String; //The full command line
    Meta: String; //Meta data
    MimeType: String; //mime and encoding, in 'text/html ; charset=iso8990' format
    Header: TStrings;
    RawHeader: TStrings;
    Data: String;
    Domain: String;
    FileName: String;
    ProtoVersion: String;
    Args: TStrings;
    constructor Create;
    procedure Clear;
    destructor Destroy; override;
  end;

  TResponse = class (TObject)
    ResponseCode: Integer;
    ResponseText: String;
    Data:String;
    DataStream:TStream;
    MimeType:String;
    Header: TStrings;
    RawHeader: TStrings;
    procedure Clear; virtual;
    procedure FixHeader; virtual;
    constructor Create;
    destructor Destroy; override;
  end;


  (*
  //Request examples:
  //HTTP
  TRequest = record //Universal record containing the commands
               RawRequest: String; // GET /index.php HTTP/1.0
               Command:String; // GET
               Parameter: String; // /index.php
               Meta: String; // www.somehost.com
               ParamMeta: String // GET params (after ?), in form name=some%20data
               Header: String; //Accept-Encoding=gzip CRLF Host=www.somehost.com CRLF User-Agent=Mozilla 5.0
               Data: String; // POST or PUT data
             end;
  //SMTP
  TRequest = record //Universal record containing the commands
               RawRequest: String;
               Command:String;
               Parameter: String; //mostly one, else in customized format
               Meta: String; //Meta data
               Header: String; //In TStrings.Text format
               Data: String;
             end;
  *)

  TOnConnect = procedure (Sender: TObject; IPInfo:TIPInfo; var DoContinue:Boolean) of Object;
  TOnAuthenticate = procedure (Sender: TObject; User, Pass: String; IPInfo:TIPInfo) of Object;
  TOnMustAuthenticate = procedure (Sender: TObject; Request:TRequest; var MustAuthenticate:Boolean; IPInfo:TIPInfo) of Object;
  TOnRequest = procedure (Sender: TObject; Request:TRequest; var Response:TResponse; IPInfo:TIPInfo; var Handled: Boolean) of Object;
  TOnPut = procedure (Sender: TObject; Request:TRequest; var Accepted:Boolean; IPInfo:TIPInfo) of Object;
  TOnListen = procedure (Sender: TObject; IPInfo: TIPInfo) of Object;
  TOnError = procedure (Sender: TObject; Error: Integer; ErrorMsg: String; IPInfo:TIPInfo) of Object;

  TCallbacks = record
                 FOnConnect: TOnConnect;
                 FOnAuthenticate: TOnAuthenticate;
                 FOnMustAuthenticate: TOnMustAuthenticate;
                 FOnRequest: TOnRequest;
                 FOnPut: TOnPut;
                 FOnError: TOnError;
               end;

  TVSThread = class (TThread)
  public
    FSettings: TSettings;
    FIPInfo: TIPInfo;
    procedure Error (ErrorCode: Integer);
    procedure SyncError;
  end;


  TVisualListen = class (TVSThread)
  public
//    FSettings:TSettings;
    FCallBacks: TCallBacks;
    FSock: TTCPBlockSocket;
    FHandler:THandlerClass; //TClass; for hot creating specific class
    FNewHandler:TServerHandler;
    procedure Execute; override;
  end;

  TServerHandler = class (TVSThread)
  protected
    FProcToCall: TOnRequest;
    procedure CallBack(proc: TThreadMethod);
    procedure CallBackRequest (Proc: TOnRequest);
    procedure SyncCallBack;
  public
//    FSettings: TSettings;
    FCallBacks: TCallBacks;
    FSock: TTCPBlockSocket;

    //vars to communicate with callback functions:
    FDoContinue: Boolean;
    FRequest: TRequest;
    FResponse: TResponse;

    //Indicates if callback event has properly handled the request
    RequestHandled: Boolean;

    //Authentication vars:
    FMustAuthenticate: Boolean;
    FAccepted: Boolean;
    FUser: String;
    FPass: String;

    //Send queue outside events:
    FSendQueue: TStrings;
    FSendCS: TCriticalSection;

    //common procedures
    procedure Init; virtual; //register thread, connect callback
    procedure Final; virtual; //unregister thread
    procedure CallBackThreadMethod (proc: TThreadMethod);
    procedure CheckToSend;

    //override this in implementations to copy component variables to the
    //client thread
    procedure CopyCustomVars; virtual;

    //callback procedures
    procedure OnConnect;
    procedure OnAuthenticate;
    procedure OnMustAuthenticate;
    procedure OnRequest;
    procedure OnPut;

    //override Handler (or Execute if you like but make sure to call Init and Final)
    //in your protocol handler
    procedure Handler; virtual;
    procedure Execute; override;
  end;

  TVisualServer = class (TComponent)
  protected
    FActive:Boolean;
    FMakeActive:Boolean;
    FSettings:TSettings;
    FCallBacks: TCallBacks;
    FListenThread:TVisualListen;
    FServerType: TThreadClass;
    FClientType: THandlerClass;
    procedure Loaded; override;
  public
    procedure SetActive(Value:Boolean);
    constructor Create (AOwner:TComponent); override;
    destructor Destroy; override;
    procedure DropClient (ConnectionHandle: Integer);
    procedure SendData (ConnectionHandle: Integer; Data:String);
    procedure SendStream (ConnectionHandle: Integer; Data:TStream);
  published
    //properties
    property Active:Boolean read FActive write SetActive;
    property BaseDir:String read FSettings.FBaseDir write FSettings.FBaseDir;
    property ListenIP:String read FSettings.FListenIP write FSettings.FListenIP;
    property ListenPort:String read FSettings.FListenPort write FSettings.FListenPort;
    property ServerName:String read FSettings.FServerName write FSettings.FServerName;
    property ThreadSafe:Boolean read FSettings.FThreadSafe write FSettings.FThreadSafe;
    //events
    property OnConnect: TOnConnect read FCallBacks.FOnConnect write FCallBacks.FOnConnect;
    property OnAuthenticate: TOnAuthenticate read FCallBacks.FOnAuthenticate write FCallBacks.FOnAuthenticate;
    property OnMustAuthenticate: TOnMustAuthenticate read FCallBacks.FOnMustAuthenticate write FCallBacks.FOnMustAuthenticate;
    property OnRequest: TOnRequest read FCallBacks.FOnRequest write FCallBacks.FOnRequest;
    property OnPut: TOnPut read FCallBacks.FOnPut write FCallBacks.FOnPut;
    property OnError: TOnError read FCallBacks.FOnError write FCallBacks.FOnError;
  end;

  //Global procedure that creates unique auto-increment integers:
  function GetConnectionHandle: Integer;

implementation

var ConnectionIndex:Integer=0;
    ConnectionCS:TCriticalSection;

function GetConnectionHandle: Integer;
begin
  ConnectionCS.Enter;
  inc (ConnectionIndex);
  Result := ConnectionIndex;
  ConnectionCS.Leave;
end;


procedure TVisualListen.Execute;
begin
  //some vars
  with FSettings do
    begin
      if FListenIP='' then
        FListenIP := '0.0.0.0';
      if FListenPort='' then
        begin
          FListenPort := '0';
          FLastErrorCode := -1;
          FLastError := 'No listen port specified';
          synchronize (syncError);
          //break here?
          //sync onerror ('no listen port')
          exit;
        end;
      if FServerName = '' then
        FServerName := 'localhost';
    end;


  FSock := TTCPBlockSocket.Create;
  FSock.Bind (FSettings.FListenIP, FSettings.FListenPort);
  if FSock.LastError = 0 then
    FSock.Listen;
  if FSock.LastError = 0 then
    while not Terminated do
      begin
        if FSock.CanRead (2000) then
          begin //spawn new thread
            if Assigned (FHandler) {and (FClient = TServerHandler)} then
              begin
                FNewHandler := FHandler.Create (True);
                FNewHandler.FSock := TTCPBlockSocket.Create;
                FNewHandler.FSock.Socket := FSock.Accept;
                FNewHandler.FSettings := FSettings;
                FNewHandler.FreeOnTerminate := True;
                if FSettings.FHasCustomVars then
//                  synchronize (FNewHandler.CopyCustomVars);
                  //yes, we have some threading issue here
                  //if component settings gets changed while server is running.
                  //fix.
                  FNewHandler.CopyCustomVars;
                FNewHandler.Resume;
              end;
          end
        else
          sleep(20);
      end;
end;


// TVisualServer  component

constructor TVisualServer.Create(AOwner: TComponent);
begin
  inherited;
  ThreadSafe := True;
  FSettings.FClients := TThreadList.Create;
  FSettings.Owner := Self;
  FSettings.FTimeOut := 30000;
end;

destructor TVisualServer.Destroy;
begin
  Active := False;
  FreeAndNil (FSettings.FClients);
end;

procedure TVisualServer.DropClient(ConnectionHandle: Integer);
var i:Integer;
begin
  with FSettings.FClients.LockList do
    try
      for i:=0 to Count - 1 do
        if TServerHandler(Items[i]).FIPInfo.ConnectionHandle = ConnectionHandle then
          begin
            TServerHandler(Items[i]).Terminate;
            break;
          end;
    finally
      FSettings.FClients.UnlockList;
    end;  
end;

procedure TVisualServer.Loaded;
begin
  if FMakeActive then
    begin
      //beware of Loaded called multiple times
      FMakeActive := False;
      SetActive (True);
    end;
end;

procedure TVisualServer.SendData(ConnectionHandle: Integer; Data: String);
//This can send data to any specific client.
var i:Integer;
begin
  //Add data to queue
  with FSettings.FClients.LockList do
    try
      for i:=0 to Count - 1 do
        if TServerHandler (Items[i]).FIPInfo.ConnectionHandle = ConnectionHandle then
          begin
            with TServerHandler (Items[i]) do
              try
                FSendCS.Enter;
                FSendQueue.Add (Data);
              finally
                FSendCS.Leave;
              end;
            break;
          end;
    finally
      FSettings.FClients.UnlockList;
    end;
end;

procedure TVisualServer.SendStream(ConnectionHandle: Integer;
  Data: TStream);
var i:Integer;
begin
  //Find proper connection
  with FSettings.FClients.LockList do
    try
      for i:=0 to Count - 1 do
        if TServerHandler (Items[i]).FIPInfo.ConnectionHandle = ConnectionHandle then
          begin
            with TServerHandler (Items[i]) do
              try
                FSendCS.Enter;
                FSendQueue.AddObject('', Data);
              finally
                FSendCS.Leave;
              end;
            break;
          end;
    finally
      FSettings.FClients.UnlockList;
    end;
end;

procedure TVisualServer.SetActive(Value: Boolean);
var i:Integer;
begin
  if Value = FActive then
    //do nothing
    exit;
  if csLoading in ComponentState then
    FMakeActive := Value
  else
    begin
      if csDesigning in ComponentState then
        FActive := Value
      else
        begin

          if not Value and Assigned (FListenThread) then
            //inactivate
            begin
              FListenThread.Terminate;
              //signal client threads to terminate:
              with FSettings.FClients.LockList do
                begin
                  for i:=0 to Count -1 do
                    try
                      TThread(Items[i]).Terminate;
                    except end;
                  Clear; //remove all items
                end;
              FSettings.FClients.UnlockList;
              FListenThread.WaitFor;

              FreeAndNil(FListenThread);

              FActive := False;
            end;

          if Value then
            //activate
            begin
              if not Assigned (FServerType) then
                //Set handler type to default
                //TVisualListen is not polymorphic but sufficient for most tcp/ip servers
                //Override if you like in the create handler of inherited component.
                FServerType := TVisualListen;
              //create listener thread:
              FListenThread := FServerType.Create (True);
              //copy common settings:
              FListenThread.FSettings := FSettings;
              //FClientType should point to correct handler type
              FListenThread.FHandler := FClientType;
              //launch thread
              FListenThread.Resume;
              FActive := True;
            end;
        end;
    end;
end;


{ TServerHandler }
procedure TServerHandler.Init;
begin
  with FSettings.FClients.LockList do
    Add (Self);
  FSettings.FClients.UnlockList;
  FIPInfo.RemoteIP := FSock.GetRemoteSinIP;
  FIPInfo.RemotePort := IntToStr(FSock.GetRemoteSinPort);
  FIPInfo.ConnectionHandle := GetConnectionHandle;
  FSendCS := TCriticalSection.Create;
  FSendQueue := TStringList.Create;

  //Allow inheritents to create customized request/response instantces:
  if FRequest = nil then
    FRequest := TRequest.Create;
  if FResponse = nil then
    FResponse := TResponse.Create;

  CallBackThreadMethod (OnConnect);
end;

procedure TServerHandler.Final;
var i:Integer;
begin
  //close socket:
  FSock.CloseSocket;

  //remove self from shared list:
  if Assigned (FSettings.FClients) then
    begin
      with FSettings.FClients.LockList do
        begin
          if IndexOf (Self)>=0 then
            Delete (IndexOf(Self));
        end;
      FSettings.FClients.UnlockList;
    end;
  //empty send queue if any:
  FSendCS.Enter; //not really necessary here, we left the client list already.
  try
    for i:=0 to FSendQueue.Count -1 do
      if Assigned (FSendQueue.Objects[i]) then
        try
          FSendQueue.Objects[i].Free;
        except end;
  except end;
  FSendCS.Leave;
  //Free variables
  FSendCS.Free;
  FSendQueue.Free;
  FSock.Free;
  FRequest.Free;
  FResponse.Free;
  //Free self:
  FreeOnTerminate := True;
end;

procedure TServerHandler.CallBack(proc: TThreadMethod);
begin
  if Assigned (Proc) then
    try
      if FSettings.FThreadSafe then
        Synchronize (proc)
      else
        proc;
    except end;
end;

procedure TServerHandler.OnAuthenticate;
begin
  if Assigned (FCallBacks.FOnAuthenticate) then
    FCallBacks.FOnAuthenticate (FSettings.Owner, FUser, FPass, FIPInfo);
end;

procedure TServerHandler.OnConnect;
begin
  FDoContinue := True;
  if Assigned (FCallBacks.FOnConnect) then
    FCallBacks.FOnConnect (FSettings.Owner, FIPInfo, FDoContinue);
  if not FDoContinue then
    Terminate; //is this safe here?
end;

procedure TServerHandler.OnMustAuthenticate;
begin
  FMustAuthenticate := False;
  if Assigned (FCallBacks.FOnMustAuthenticate) then
    FCallBacks.FOnMustAuthenticate(FSettings.Owner, FRequest, FMustAuthenticate, FIPInfo);
end;

procedure TServerHandler.OnPut;
begin
  FAccepted := False;
  if Assigned (FCallBacks.FOnPut) then
    FCallBacks.FOnPut (FSettings.Owner, FRequest, FAccepted, FIPInfo);
end;

procedure TServerHandler.OnRequest;
begin
  RequestHandled := True;
  if Assigned (FCallBacks.FOnRequest) then
    FCallBacks.FOnRequest (FSettings.Owner, FRequest, FResponse, FIPInfo, RequestHandled);
end;

procedure TServerHandler.CheckToSend;
var D:String;
    S:TStream;
begin
  //See if there is data to send
  S:=nil;
  D:='';
  FSendCS.Enter;
  try
    if FSendQueue.Count > 0 then //time to send
      begin
        S:=TStream(FSendQueue.Objects[0]);
        D:=FSendQueue[0];
        FSendQueue.Delete (0);
      end;
  except end;
  FSendCS.Leave;
  if D<>'' then
    FSock.SendString (D);
  if Assigned (S) then
    try
      FSock.SendStream (S);
      S.Free;
    except end;
end;

procedure TServerHandler.Execute;
begin
  Init; //calls OnConnect
  if not Terminated then
    try
      Handler;
    except end;
  Final;
end;

procedure TServerHandler.Handler;
begin
  //Virtual dummy proc, we're finished here.
end;


procedure TServerHandler.CopyCustomVars;
begin
  //called thread-safe by the listen thread
end;

procedure TServerHandler.CallBackThreadMethod(proc: TThreadMethod);
begin

end;

procedure TServerHandler.CallBackRequest(Proc: TOnRequest);
begin
  FProcToCall := Proc;
  RequestHandled := False;
  if Assigned (FProcToCall) then
    begin
      if FSettings.FThreadSafe then
        Synchronize (SyncCallBack)
      else
        SyncCallBack;
    end;
end;

procedure TServerHandler.SyncCallBack;
begin
  try
    RequestHandled := True;
    FProcToCall (FSettings.Owner, FRequest, FResponse, FIPInfo, RequestHandled);
  except
    //if logging then log..
    RequestHandled := False;
  end;
end;

{ TRequest }

procedure TRequest.Clear;
begin
  RawRequest := '';
  Command := '';
  Parameter := '';
  Meta := '';
  ProtoVersion := '';
  Header.Clear;
  RawHeader.Clear;
end;

constructor TRequest.Create;
begin
  inherited;
  Header := TStringList.Create;
  RawHeader := TStringList.Create;
  Args := TStringList.Create;
end;

destructor TRequest.Destroy;
begin
  Header.Free;
  RawHeader.Free;
  inherited;
end;

{ TResponse }

procedure TResponse.Clear;
begin
  ResponseCode := 0;
  ResponseText := '';
  Data := '';
  DataStream := nil;
  MimeType := '';
  Header.Clear;
  RawHeader.Clear;
end;

constructor TResponse.Create;
begin
  inherited;
  Header := TStringList.Create;
  RawHeader := TStringList.Create;
end;

destructor TResponse.Destroy;
begin
  Header.Free;
  RawHeader.Free;
  inherited;
end;

procedure TResponse.FixHeader;
begin
  //Nothing to do here..
end;

{ TVSThread }

procedure TVSThread.Error(ErrorCode: Integer);
begin
  FSettings.FLastErrorCode := ErrorCode;
  if (ErrorCode >= 0) and (ErrorCode <= high (ErrorCodes)) then
    FSettings.FLastError := ErrorCodes[ErrorCode]
  else
    FSettings.FLastError := 'Unknown error';
  //FIPInfo is supposed to be filled with latest info, optionally zerod.
  if Assigned (FSettings.Owner) then
    Synchronize (SyncError);
  //else waiste of synchronize action.
end;

procedure TVSThread.SyncError;
begin
  if Assigned (FSettings.Owner) then
    try
      if Assigned (TVisualServer(FSettings.Owner).OnError) then
        TVisualServer(FSettings.Owner).OnError (
          FSettings.Owner, FSettings.FLastErrorCode, FSettings.FLastError, FIPInfo);
    except end;
end;

initialization
  ConnectionCS := TCriticalSection.Create;
finalization
  ConnectionCS.Free;
end.
