unit httpserver;

interface

uses Classes, SysUtils, typinfo, blcksock, visualserverbase, inifiles, vstypedef, ExecCGI,
synacode, synautil, filectrl, mimemess;       

// USE AT YOUR OWN RISK //
// NOT TESTED FOR SECURITY ISSUES //
// NOT SUITABLE FOR PRODUCTION ENVIRONMENTS YET //

// License: Modified Artistic License



//implementation of a HTTP server.
//It just acts as a (partly implemented) HTTP/1.1 server
//But we loosely check commands to fulfill 0.9, 1.0 and 1.1 requests.
//Not fully qualified 1.1 commands (i.e. leaving the 'Host' parameter out of the header)
//is threated as 1.0 again.
//Response codes are HTTP/1.1. Server always responds 1.1

//Safety of CGI at your own risk.


//This unit uses dynamic arrays.. which makes data copying between component and thread some easier.

//blog
//busy again
//july 2004 - busy again with the server, in need for a http server so may finish this as well :)

//see rfc 2616
//http://www.w3.org/Protocols/rfc2616/rfc2616.html

const MAX_POST_DATA_SIZE=8192;

type

  TEnumHTTPProtocols = (hpHEAD, hpGET, hpPUT, hpDELETE, hpPOST, hpTRACE, hpOPTIONS, hpCONNECT);

  THTTPProtocols = set of TEnumHTTPProtocols;

  //cmGET is default
  //cmClose forces connection close
  //cmDone marks all client IO as done, but keeps connection open if enabled
  //cmConnect marks proxy
  TConnectionMode = (cmWait, cmGET, cmPOST, cmPUT, cmCONNECT, cmReadCGI, cmCLOSE, cmDONE);


  TCGIPath = class
    CGIName:String;
    ExePath:TFileName;
  end;

  TPreParser = class
    ExePath:String;
    Params: String;
  end;

  THTTPResponse = class (TResponse)
    procedure FixHeader; override;
  end;


  TVirtualDomain = class (TObject)
    FDefaultDocument:String;
    FDefaultDocuments:TStrings;
    FHostName:String;
//    FRootPath:TFileName;
    FVirtualPath: TStrings;
    FCGI: TStrings; //Array of TCGIPath;
    FPreParser: TStrings; //Array TPreParser;
    FManualURL: TStrings;
    FMimeTypes: TStrings;
    constructor Create;
    destructor Destroy; override;
  end;

  THTTPVars = record
    FDoVirtualHosts:Boolean;
    FDomain:TVirtualDomain;
    FPHPPath:TFileName;
    FCaseSensitive:Boolean;
    FServerName:String;
    FVirtualDomains: TList;
    FSupported: THTTPProtocols;
    FAutomated: THTTPProtocols;
    FErrorDocs: String;
  end;

  THTTPDocument = record
    Headers: String;
    Data: String;
  end;

  THTTPDoc = record
    Command: TEnumHTTPProtocols;
    Request,
    Response: THTTPDocument;
  end;

  THostInfo = record
    Host,
    Port: String;
  end;

//  THTTPCallBack = procedure (Sender: TObject; Request, Response: THTTPDoc; Info: THostInfo) of Object;

  TCallBack = record
    FOnHead,
    FOnGet,
    FOnPut,
    FOnPost,
    FOnTrace,
    FOnOptions: TOnRequest; //THTTPCallBack;
  end;


  //the component
  THTTPServer = class (TVisualServer)
  protected
    FVirtualServers:TList;
    FHTTPVars:THTTPVars;

    FCallBack: TCallBack;

    //creates a virtual domain if not exists:
    function GetVirtualDomain(Domain: String): TVirtualDomain;

  public
    class function ParseDomain(Domain: String): String; //cleans up a domain name
    constructor Create (AOwner:TComponent); override;
    procedure AddVirtualDomain (Domain:TVirtualDomain);
    procedure RegisterDir (PhysicalDir: TFileName; VirtualDir: String; Domain: String=''; Recursive: Boolean=True);
    procedure RegisterPreParser (Binary: TFileName; Extension: String; Domain: String=''; Params: String='"%s"');
    procedure RegisterPHP (Binary: TFileName; Extension: String=''; Domain: String='');
    procedure RegisterDefaultDoc (FileName: String; Domain: String='');
    procedure RegisterMimeType (Extension, MimeType: String; Domain: String='');
    procedure RegisterCGI (PhysicalDir: TFileName; VirtualDir: String='/cgi-bin'; Domain: String='');
    procedure RegisterManualURL (URL: String; Domain: String='');
    procedure ClearSettings;
//    procedure WriteSettings (Stream: TStream);
//    procedure ReadSettings (Stream: TStream);
    procedure SaveSettings (FileName: TFileName);
    procedure LoadSettings (FileName: TFileName);
  published
    property OnHead: TOnRequest read FCallBack.FOnHead write FCallBack.FOnHead;
    property OnGet: TOnRequest read FCallBack.FOnGet write FCallBack.FOnGet;
    property OnPost: TOnRequest read FCallBack.FOnPost write FCallBack.FOnPost;
    property OnPut: TOnRequest read FCallBack.FOnPut write FCallBack.FOnPut;

    property DoVirtualHosts:Boolean read FHTTPVars.FDoVirtualHosts write FHTTPVars.FDoVirtualHosts;

//    property DefaultDocument:String read FHTTPVars.FDomain.FDefaultDocument write FHTTPVars.FDomain.FDefaultDocument;
    property PHPPath:TFileName read FHTTPVars.FPHPPath write FHTTPVars.FPHPPath;
    property CaseSensitive:Boolean read FHTTPVars.FCaseSensitive write FHTTPVars.FCaseSensitive;
    property SupportedProtocols:THTTPProtocols read FHTTPVars.FSupported write FHTTPVars.FSupported;
    property AutomatedProtocols:THTTPProtocols read FHTTPVars.FAutomated write FHTTPVars.FAutomated;
    property ErrorDocs: String read FHTTPVars.FErrorDocs write FHTTPVars.FErrorDocs;
  end;

  //the protocol handler
  THTTPHandler = class (TServerHandler)
  protected

    //Returns NIL on invalid domain:
    function GetVirtualDomain(Domain: String): TVirtualDomain;

    //support function
    function Compare (V1, V2: String): Boolean; //compares string based on CaseSensitive property

    //procedures to find back vars:
    function GetCGIPath(URL: String; Domain: String=''): String;
    function GetPreParser (URL: String; Domain: String=''): TPreParser;
    function IsManualURL (URL: String; Domain: String=''): Boolean;
    function MapVirtualDir (URL: String; Domain: String=''): TFileName;
    function GetDefaultDoc (Path: TFileName; Domain: String=''): String;

    procedure CreateFileHeaders (FileName: TFileName);


    //function to see if there are any parsers (pre-parsers, cgi)
    //if so, call them
    //if not, return false and do rest
    function CheckGetHeadPostParser (Domain: String=''): Boolean;

    procedure Report404; //speaks for itself..

  public
    Buf:String;
    FMode: TConnectionMode;
    FPSock: TTCPBlockSocket;

    //vars shared with component:
    FHTTPVars: THTTPVars;
    FCallBack: TCallBack;

    //internal use:
    FCurrentGetFile: TFileName;
    FRangeStart: Int64;
    FRangeEnd: Int64;
    FPostData: String;
    FCGIInfo: TCGIResult;

    FKeepAlive: Boolean;


    procedure Init; override;

    procedure CopyCustomVars; override;
    procedure Handler; override;
    procedure ProcessRequest (Header: String);

    function GetGetPath:TFileName; //returns path of file or cgi

    procedure ProcessGet;
    procedure ProcessHead;
    procedure ProcessPut;
    procedure ProcessPost;
    procedure ProcessConnect;
    procedure ProcessDelete;
    procedure ProcessTrace;
    procedure ProcessOptions;

    //Procedures to split url:
    function GetFile (URL: String): String;
    function GetPath (URL: String): String;
    function GetParams (URL: String): String;
    procedure ReadPostData;
    procedure MakeResponseHeaders;
    procedure MakeErrorDoc;
    procedure MakeArgs;
    function MergeURL (Path, FileName: String): String;
    procedure ProcessGetHeadPost(Method: TEnumHTTPProtocols);
    procedure CheckRanges;

  end;

  function HTTPCodeToMessage (Code:Integer):String;


implementation


//support function:
function HTTPCodeToMessage (Code:Integer):String;
//Code is expected to be >= 100 (3 digits);
var M:String;
begin
  if (code<100) or (code>999) then
    code := 500; //internal server error
  case Code of
    100: M:='Continue';
    101: M:='Switching Protocols';
    200: M:='Ok';
    201: M:='Created';
    202: M:='Accepted';
    203: M:='Non-Authoritive Information';
    204: M:='No Content';
    205: M:='Reset Content';
    206: M:='Partial Content';
    300: M:='Multiple Choices';
    301: M:='Moved Permanently';
    302: M:='Found';
    303: M:='See Other Method';
    304: M:='Not Modified';
    305: M:='Use Proxy';
    307: M:='Temporary Redirect';
    400: M:='Bad Request';
    401: M:='Unauthorized';
    402: M:='Payment required';
    403: M:='Forbidden';
    404: M:='Not Found';
    405: M:='Method Not Allowed';
    406: M:='Not Acceptable';
    407: M:='Proxy Authentication Required';
    408: M:='Request Timeout';
    409: M:='Conflict';
    410: M:='Gone';
    411: M:='Length Required';
    412: M:='Precondition Failed';
    413: M:='Request Entity Too Large';
    414: M:='Request-URI Too Long';
    415: M:='Unsupported Media Type';
    416: M:='Requested Range Not Satisfiable';
    417: M:='Expectation Failed';
    500: M:='Internal Error';
    501: M:='Not Implemented';
    502: M:='Bad Gateway';
    503: M:='Service Unavailable';
    504: M:='Gateway Timeout';
    505: M:='HTTP Version Not Supported';
  else
    M := 'Unknown';
  end;
  M:=IntToStr(Code)+' '+M;
  Result := M;
end;

function ListDirAsHTML(PhysicalDir, VirtualDir, Hostname:String):String;
//list a directory as HTML
var v,w: String;
    sr: TSearchRec;
    f: Integer;
begin
  v := 'Index of http://'+HostName+VirtualDir;
  Result := '<html><head><title>'+v+'</title></head>'+
            '<body><h2><i>'+v+'</i></h2><br>'#13#10'<table>'#13#10;
  f := FindFirst (PhysicalDir+'\*.*', faAnyFile, sr);
  while f = 0 do
    begin
      w := sr.Name;
      if (sr.Attr and faDirectory)<>0 then
        w := w + '/';
      Result := Result + Format ( '<tr><td><a href="%s">%s</a></td><td>%d</td><td>%s</td></tr>',
                                  [ 'http://'+HostName+VirtualDir+w,
                                    VirtualDir+w,
                                    sr.Size,
//                                    RFC822DateTime (FileDateToDateTime(sr.Time))
                                    DateTimeToStr (FileDateToDateTime(sr.Time))
                                   ]);
      f := FindNext (sr);
    end;
  Result := Result + '</table>'#13#10'<hr>Visual Synapse HTTP Server</body>'#13#10'</html>';
  FindClose (sr);
end;


{ THTTPServer }

procedure THTTPServer.AddVirtualDomain(Domain: TVirtualDomain);
begin
end;

procedure THTTPServer.ClearSettings;
var VD: TVirtualDomain;
    i: Integer;
begin
  //remove list of virtual domains:
  for i:=0 to FHTTPVars.FVirtualDomains.Count - 1 do
    TVirtualDomain(FHTTPVars.FVirtualDomains[i]).Free;
  FHTTPVars.FVirtualDomains.Clear;
  VD := TVirtualDomain.Create;
  VD.FHostName := '*';
  FHTTPVars.FVirtualDomains.Add (VD);
end;

constructor THTTPServer.Create(AOwner: TComponent);
var VD: TVirtualDomain;
begin
  inherited;
  FClientType := THTTPHandler;
  ListenPort := '80';
//  DefaultDocument := 'index.*';
  FSettings.FHasCustomVars := True;
  FHTTPVars.FSupported := [hpHEAD, hpGET,{ hpPUT, hpDELETE,} hpPOST, hpTRACE, hpOPTIONS{, hpCONNECT}];
  FHTTPVars.FAutomated := FHTTPVars.FSupported + [hpCONNECT];
  FHTTPVars.FCaseSensitive := True;
  FHTTPVars.FVirtualDomains := TList.Create;
  ClearSettings;
end;

function THTTPHandler.GetVirtualDomain(Domain: String): TVirtualDomain;
var i: Integer;
begin
  Domain := THTTPServer.ParseDomain(Domain);
  Result := nil;
  for i:=0 to FHTTPVars.FVirtualDomains.Count - 1 do
    if TVirtualDomain (FHTTPVars.FVirtualDomains[i]).FHostName = Domain then
      begin
        Result := TVirtualDomain (FHTTPVars.FVirtualDomains[i]);
        break;
      end;
  {
  if (not Assigned (Result)) and CreateIfNotExists then
    begin //add one
      Result := TVirtualDomain.Create;
      FHTTPVars.FVirtualDomains.Add (Result);
      Result.FHostName := Domain;
    end;
  }
end;

class function THTTPServer.ParseDomain(Domain: String): String;
begin
  Result := lowercase (Domain);
  if Result='' then
    Result := '*';
end;


procedure THTTPServer.RegisterCGI(PhysicalDir: TFileName; VirtualDir,
  Domain: String);
var VD: TVirtualDomain;
begin
  PhysicalDir := ExpandUNCFileName(PhysicalDir);
  VD := GetVirtualDomain (Domain);
  VD.FCGI.AddObject (VirtualDir, StrToObj(PhysicalDir));
end;

procedure THTTPServer.RegisterDefaultDoc(FileName, Domain: String);
var VD: TVirtualDomain;
begin
  VD := GetVirtualDomain (Domain);
  if VD.FDefaultDocuments.IndexOf (FileName)<0 then
    VD.FDefaultDocuments.Add (FileName);
end;

procedure THTTPServer.RegisterDir(PhysicalDir: TFileName; VirtualDir,
  Domain: String; Recursive: Boolean);
var VD: TVirtualDomain;
    SR: TSearchRec;
    f: Integer;
begin
  //todo?
  //check virtualdir for beginning slash
  PhysicalDir := ExpandUNCFileName(PhysicalDir);
  VD := GetVirtualDomain (Domain);
  if VD.FVirtualPath.IndexOf (VirtualDir) < 0 then
    VD.FVirtualPath.AddObject (VirtualDir, StrToObj(PhysicalDir));
  if Recursive then
    begin
      f := FindFirst (PhysicalDir+'\*.*', faDirectory, SR);
      while f = 0 do
        begin
          if ((SR.Attr and faDirectory)<>0) and
             (SR.Name<>'.') and (SR.Name<>'..') then //call self recursively
            RegisterDir (PhysicalDir+PathSep+SR.Name, VirtualDir+SR.Name+'/', Domain, True);
          f := FindNext (SR);
        end;
      FindClose (SR);
    end;
end;

procedure THTTPServer.RegisterManualURL(URL, Domain: String);
var VD: TVirtualDomain;
begin
  VD := GetVirtualDomain (Domain);
  if VD.FManualURL.IndexOf(URL)<0 then
    VD.FManualURL.Add (URL);
end;

procedure THTTPServer.RegisterMimeType(Extension, MimeType: String; Domain: String='');
var VD: TVirtualDomain;
    i: Integer;
begin
  VD := GetVirtualDomain (Domain);
  i := VD.FMimeTypes.IndexOf(Extension);
  if i>=0 then
    VD.FMimeTypes.Delete(i);
  VD.FMimeTypes.AddObject (Extension, StrToObj (MimeType));
end;

procedure THTTPServer.RegisterPreParser(Binary: TFileName; Extension: String;
  Domain: String=''; Params: String='"%s"');
var VD: TVirtualDomain;
    i: Integer;
    PreParser: TPreParser;
begin
  VD := GetVirtualDomain (Domain);
  i := VD.FPreParser.IndexOf(Extension);
  if i>=0 then
    begin
      VD.FPreParser.Objects[i].Free;
      VD.FPreParser.Delete(i);
    end;
  PreParser := TPreParser.Create;
  PreParser.ExePath := Binary;
  PreParser.Params := Params;
  VD.FPreParser.AddObject (Extension, PreParser);
end;

procedure THTTPServer.LoadSettings(FileName: TFileName);
var FI: TIniFile;
begin
  if ExtractFilePath (FileName)='' then
    FileName := ExpandFileName (FileName);
  FI := TIniFile.Create (FileName);
  ClearSettings;
end;

procedure THTTPServer.SaveSettings(FileName: TFileName);
var FI: TIniFile;
    i: Integer;
    VD: TVirtualDomain;
begin
  //we want fully qualified path:
  if ExtractFilePath (FileName)='' then
    FileName := ExpandFileName (FileName);

  //create backup of filename
  i := 1;
  while (fileexists (Filename+'.'+IntToStr(i))) and (i < 10000) do
    inc (i);
  RenameFile (FileName, FileName+'.'+IntToStr(i));

  //Write settings:
  FI := TIniFile.Create (FileName);
  for i := 0 to FHTTPVars.FVirtualDomains.Count - 1 do
    begin
      //save settings...
    end;
end;


procedure THTTPServer.RegisterPHP (Binary: TFileName; Extension: String=''; Domain: String='');
begin
  Binary := ExpandUNCFileName(Binary);
  if Extension='' then
    Extension := '.php';
  RegisterPreParser (Binary, Extension, Domain, '-f "%s"');
end;

function THTTPHandler.GetFile(URL: String): String;
var i: Integer;
begin
  i := pos ('?', URL);
  if i>0 then
    Result := Copy (URL, 1, i-1)
  else
    Result := URL;
end;

function THTTPHandler.GetParams(URL: String): String;
var i: Integer;
begin
  i := pos ('?', URL);
  if i>0 then
    Result := Copy (URL, i+1, maxint)
  else
    Result := '';
end;

function THTTPHandler.GetPreParser(URL, Domain: String): TPreParser;
var Ext: String;
    i: Integer;
    VD: TVirtualDomain;
begin
  Result := nil;
  Ext := ExtractFileExt (GetFile (URL));
//  Compare
  VD := GetVirtualDomain (Domain);
  if Assigned (VD) then
    i := VD.FPreParser.IndexOf (Ext) //we ignore case.. fix.
  else
    i := -1; //domain does not exist.
  if i>=0 then
    Result := TPreParser(VD.FPreParser.Objects[i])
  else //not found
    if Domain<>'' then //avoid endless lookups on empty (default) domain
      Result := GetPreParser (URL); //fetch parser of default (''no'') domain.
end;

function THTTPHandler.GetCGIPath(URL, Domain: String): String;
var Path: String;
    VD: TVirtualDomain;
    i: Integer;
begin
  Path := GetPath (URL); //S _should_ (?) be in form /path/ or /full/path/name/
  VD := GetVirtualDomain (Domain);
  if Assigned (VD) then
    i := VD.FCGI.IndexOf (Path) //we ignore case.. fix.
  else
    i := -1; //domain does not exist.
  if i>=0 then
    Result := TString(VD.FCGI.Objects[i]).Value+PathSep+Copy (GetFile(URL), Length(Path)+1, maxint)
  else
    if Domain <> '' then
      Result := GetCGIPath (URL, '');
end;

function THTTPHandler.IsManualURL(URL, Domain: String): Boolean;
var VD: TVirtualDomain;
    i: Integer;
begin
  VD := GetVirtualDomain (Domain);
  if Assigned (VD) then
    i := VD.FManualURL.IndexOf (GetFile(URL)) //yeah.. case insensitive again.. fix.
  else
    i := -1;
  if (i < 0) and (Domain <> '') then
    Result := IsManualURL (URL)
  else
    Result := i >= 0;
end;

function THTTPHandler.Compare(V1, V2: String): Boolean;
begin
  if FHTTPVars.FCaseSensitive then
    Result := V1 = V2
  else
    Result := AnsiStrComp (PChar(V1), PChar(V2))=0;
end;

function THTTPHandler.GetPath(URL: String): String;
var s: String;
    i: Integer;
begin
  s := GetFile (URL);
  i := length (s);
  while i>1 do
    if s[i]='/' then
      break
    else
      dec(i);
  if i>1 then //i holds position of last slash
    Result := copy (URL, 1, i)
  else
    Result := '/';
end;

function THTTPServer.GetVirtualDomain(Domain: String): TVirtualDomain;
var i: Integer;
begin
  Domain := ParseDomain(Domain);
  Result := nil;
  for i:=0 to FHTTPVars.FVirtualDomains.Count - 1 do
    if TVirtualDomain (FHTTPVars.FVirtualDomains[i]).FHostName = Domain then
      begin
        Result := TVirtualDomain (FHTTPVars.FVirtualDomains[i]);
        break;
      end;
  //Add one if not yet exist:
  if (not Assigned (Result)) then
    begin //add one
      Result := TVirtualDomain.Create;
      FHTTPVars.FVirtualDomains.Add (Result);
      Result.FHostName := Domain;
    end;
end;

{ THTTPHandler }

procedure THTTPHandler.CopyCustomVars;
begin
  FHTTPVars := THTTPServer(FSettings.Owner).FHTTPVars;
  FCallBack := THTTPServer(FSettings.Owner).FCallBack;
end;

function THTTPHandler.GetGetPath: TFileName;
begin
  //See if handler fits in some virtual domain

end;

procedure THTTPHandler.Handler; //= Thread.Execute
//some local vars not shared with procedures:
var FS: TFileStream;
    i: Integer;

begin
  FMode := cmWait;
  while not Terminated do
    begin
      //Read an HTTP header
      case FMode of
        cmWait: //this is not limited to GET
               //but it porcesses the header
               //if necessary, like PUT, POST or CONNECT it will change the mode
          begin
            Buf := FSock.RecvTerminated (FSettings.FTimeOut{30000}, CRLF+CRLF);

            //for the time being, don't support keep-alive (fix this)
            //fix: if connection keep-alive mode = get
            //Unless otherwise set, we close the connection after processing.
            FMode := cmClose;

            if Buf<>'' then
              begin
                FResponse.ResponseCode := 0;
                ProcessRequest (Buf);
                if FResponse.ResponseCode = 0 then
                  FResponse.ResponseCode := 400; //Unknown request
                if (FResponse.ResponseCode >= 400) and
                   (FResponse.Data='') then //generate error doc
                  MakeErrorDoc;


                FKeepAlive := (FMode=cmDone) and
                              (FResponse.ResponseCode >= 200) and
                              (FResponse.ResponseCode < 500) and
//                              (FRequest.ProtoVersion = 'HTTP/1.1') and
                              (lowercase(FRequest.Header.Values['Connection']) = 'keep-alive');

                FKeepAlive := False; //sorry, there are bugs currently.
                              
                //keep alive conditionals:
                //the client must request it
                //it must not be a parsed PHP script
                //since there is no content-length available.              

                if (FResponse.ResponseCode <> 0) then
                  begin //We send data ourselves:
                    MakeResponseHeaders;
                    FResponse.FixHeader;
                    FSock.SendString ('HTTP/1.1 '+
                                      HTTPCodeToMessage (FResponse.ResponseCode)+CRLF+
                                      FResponse.RawHeader.Text+CRLF);
                    if FResponse.Data<>'' then
                      FSock.SendString (FResponse.Data);
//                    if Assigned (FResponse.DataStream) then
//                      FSock.SendStream (FResponse.DataStream);
                  end;
                if FResponse.ResponseCode >= 500 then //disconnect
                  FMode := cmClose;
              end
            else
              Terminate; //we're done here, 30s timeout.
          end;

        cmGet:
          begin
            //Send current file:
            FMode := cmClose;
            if (FCurrentGetFile <> '') then
              try
                FS := TFileStream.Create (FCurrentGetFile, fmOpenRead or fmShareDenyNone);
                FS.Seek (FRangeStart, soFromBeginning);
                while (FS.Position < FRangeEnd{FS.Size}) and (FSock.LastError=0) do
                  begin
                    SetLength (Buf, 8192);
                    if (FRangeEnd - FS.Position) < 8192 then
                      SetLength (Buf, FRangeEnd - FS.Position);
                    i := FS.Read (Buf[1], length (Buf));
                    SetLength (Buf, i);
                    if i>0 then
                      //todo: add bandwidth throttle
                      FSock.SendString (Buf);
                  end;
                FS.Free;
                FMode := cmDone;
              except end;
          end;

        cmPost, cmPut:
          begin
            //read data into buffer
            //until max size.
          end;

        cmConnect:
          begin
            //Play proxy
            while Assigned (FSock) and Assigned (FPSock) and
                  (FSock.LastError=0) and (FPSock.LastError = 0) and
                  not Terminated do
              begin
                //quick and dirty, there are nicer ways to play 2-way proxy but
                //at the moment this is sufficient because it is functional :)
                if (FSock.CanRead (50)) then
                  begin
                    if (FSock.WaitingData > 0) then
                      begin
                        Buf := FSock.RecvPacket (0);
                        if Buf <> '' then
                          FPSock.SendString (Buf);
                      end
                    else
                      //Connection has terminated
                      break;
                  end;
                if (FPSock.CanRead (50)) then
                  begin
                    if (FPSock.WaitingData > 0) then
                      begin
                        Buf := FPSock.RecvPacket (0);
                        if Buf <> '' then
                          FSock.SendString (Buf);
                      end
                    else
                      break;
                  end;
              end;
            FPSock.Free;
            FMode := cmClose;
          end;

        cmReadCGI:
          begin
            CGISendResultsToSock (FCGIInfo, FSock);
            FMode := cmDone;
          end;

        cmDone:
          begin
            //clear all info
            //wait again for connection
            FCurrentGetFile := '';
            FPostData := '';
            FRequest.Clear;
            FResponse.Clear;

            if FKeepAlive then
              FMode := cmWait
            else
              FMode := cmClose;
          end;

        cmClose:
          begin
            //close connection
            //and end.
            FSock.CloseSocket;
            Terminate;
          end;

      end; //case
    end;
end;

procedure THTTPHandler.ProcessRequest (Header: String);
var Buf,s,proto:String;
    Meta:TStrings;
    i:Integer;
    CMD:TEnumHTTPProtocols;
begin
  FRequest.Clear;
  FResponse.Clear;

  Meta := TStringList.Create;

  //May be valid HTTP header, process:
  Buf := Header;
  FRequest.RawHeader.Text := Buf;
  FRequest.RawRequest := Buf; //as is


  //convert header to name-value pairs:
  for i:=1 to FRequest.RawHeader.Count - 1 do
    FRequest.Header.Add (StringReplace (FRequest.RawHeader[i], ': ', '=', []));
  if FRequest.RawHeader.Count > 0 then
    begin
      S:=Trim (FRequest.RawHeader[0]);
      FRequest.RawRequest := S;

      FRequest.Command:=UpperCase(copy (S, 1, pos(' ',s)-1));

      s:=trim(copy(s,pos(' ',s)+1, maxint));
      proto :=trim (copy (s,pos(' ',s)+1, maxint)); //protocol

      Meta.Add ('PROTOCOL_VERSION='+proto);
      FRequest.ProtoVersion := proto;

      FRequest.Parameter := trim (copy (s,1,pos(' ',s)-1));

      s:= FRequest.Command;

//      FResponse.ResponseCode := 504; //if anything fails, send back not implemented

      FResponse.ResponseCode := 400; //Malformed request

      FRequest.Meta := Meta.Text;

      for CMD:=low (TEnumHTTPProtocols) to high(TEnumHTTPProtocols) do
        begin
          if (S = UpperCase ( copy (getEnumName(TypeInfo(TEnumHTTPProtocols), Integer(CMD)), 3, 9))) and
  //      if ((S='GET') or (S='HEAD') or (S='POST') or (S='PUT') or (S='TRACE') or (S='OPTIONS') or (S='CONNECT')) and
             (copy (proto,1,5)='HTTP/') and
             (FRequest.Parameter <>'') then //looks like valid HTTP request
            begin
              //at least request is not malformed.
              FResponse.ResponseCode := 501; //not implemented

              //See if it is supported at all:
              if not (CMD in FHTTPVars.FSupported) then
                begin
                  FResponse.ResponseCode := 405; //not allowed
                  break;
                end;

//              if (CMD in [hpPUT, hpPOST]) and
//                 (FRequest.Header


              if (CMD in FHTTPVars.FAutomated) then
                begin
                  case CMD of
                    hpGET: ProcessGet;
                    hpHEAD: ProcessHead;
                    hpPOST: ProcessPost;
//                    hpPUT: ProcessPut;
                    hpDelete: ProcessDelete;
                    hpConnect: ProcessConnect;
                    hpOptions: ProcessOptions;
                  else
                    FResponse.ResponseCode := 501;
                  end;
                end
              else
                begin
                  CallBack (OnRequest);
                end;
              break; //found one
            end;
        end;

    end;
  Meta.Free;

end;

procedure THTTPHandler.ProcessTrace;
begin
  FResponse.ResponseCode := 200; //Ok, we'll trace
  FResponse.Data := FRequest.RawRequest;
  //that's all folks!
end;

procedure THTTPHandler.ProcessConnect;
var v:String;
begin
  //kindly perform a connect
  if pos (':', FRequest.Parameter) > 0 then //sounds valid
    begin
      v:=FRequest.Parameter;
      FPSock := TTCPBlockSocket.Create;
      FPSock.Connect (copy(v,1,pos (':', v)-1), copy (v, pos(':',v)+1, Maxint));
      if FPSock.LastError = 0 then
        begin
          FResponse.ResponseCode := 200; //ok, connection accepted
          FMode := cmCONNECT;
        end
      else
        begin
          FPSock.Free;
          FMode := cmClose;
          FResponse.ResponseCode := 410; //not sure about this one. 4xx or 5xx seems ok.
        end;
    end
  else
    FResponse.ResponseCode := 400; //Bad request
end;

procedure THTTPHandler.ProcessDelete;
begin
  //Not implemented yet
  //Forbidden
  FResponse.ResponseCode := 403;
end;

procedure THTTPHandler.ProcessGet;
begin
  ProcessGetHeadPost (hpGET);
end;

procedure THTTPHandler.ProcessHead;
begin
  ProcessGetHeadPost (hpHead);

end;

procedure THTTPHandler.ProcessOptions;

  function ListOptions: String;
  var i: TEnumHTTPProtocols;
  begin
    for i:=low(TEnumHTTPProtocols) to high(TEnumHTTPProtocols) do
      if i in FHTTPVars.FSupported then
        Result := Result + Copy (GetEnumName(TypeInfo(TEnumHTTPProtocols), integer(i)), 3, maxint)+', '; //typinfo.name
    if Result <> '' then
      begin
        Result := 'Allow: ' + Result;
        Delete (Result, length(Result)-1, 2);
      end;
  end;

begin
  if not (hpOptions in FHTTPVars.FSupported) then
    begin
      FResponse.ResponseCode := 405; //method not allowed
      exit;
    end;

  RequestHandled := False;

  if not (hpOptions in FHTTPVars.FAutomated) then
    CallBackRequest (FCallBack.FOnOptions)
  else
    //Server handled
    begin
      //Ignore the parameter. Any request will return the same info as
      //OPTIONS * HTTP/1.1
      //Also, ignore HTTP version.
      FResponse.Header.Add (ListOptions);
      RequestHandled := True;
      FResponse.MimeType := 'text/html';
      FResponse.Data := '<html><head></head><body>'+
                        ListOptions+
                        '</body></html>'; //human readable form
      FResponse.ResponseCode := 200;
    end;
end;

procedure THTTPHandler.ProcessPost;
begin
  ProcessGetHeadPost (hpPOST);
end;

procedure THTTPHandler.ProcessPut;
begin
  //Sorry, not implemented (need authentication support first anyhow)
  FResponse.ResponseCode := 403;
end;


function THTTPHandler.CheckGetHeadPostParser (Domain: String): Boolean;
var Manual, CGI, FN: String;
    PreParser: TPreParser;
begin
  //test for cgi scripts or preparser or manual handled URL.
  //test manual URL first, prioritize above everything.

  //if found, call them.
  Result := False;

  if IsManualURL (FRequest.Parameter) then
    begin
      Result := True;
      //Call OnGet/OnPost/On
      if FRequest.Command = 'GET' then
        CallBackRequest (FCallBack.FOnGet)
      else
        if FRequest.Command = 'HEAD' then
          CallBackRequest (FCallBack.FOnHead)
        else
          if FRequest.Command = 'POST' then
            CallBackRequest (FCallBack.FOnPost)
          else
            begin
              FResponse.ResponseCode := 503; //Service unavailable
              exit;
            end;
    end
  else
    begin
      //Check CGI:
      PreParser := nil;
      CGI := GetCGIPath (FRequest.Parameter, Domain);
      if CGI = '' then
        begin
          FN := MapVirtualDir (FRequest.Parameter, Domain);
          if (FN<>'') and FileExists (FN) then
            PreParser := GetPreParser (FRequest.Parameter, Domain);
        end;
      if ( (CGI<>'') or (Assigned (PreParser)) ) and
         (FRequest.Command = 'POST') then
        begin
          //Read in POST data

//          ReadPostData; //this is done before...
        end;
      if CGI<>'' then
        begin
          //DoCGI
          Result := True; //prevent any further parsing
          if not FileExists (CGI) then  //todo: check case sensivity
            FResponse.ResponseCode := 403 //forbidden, also for browsing
          else
            begin
//              FResponse.Data := ExecuteCGI (CGI, FRequest.Command, GetParams(FRequest.Parameter), FRequest.RawHeader.Text+#13#10+FPostData, FSettings, nil{FSock});
              FCGIInfo := ExecuteCGI (CGI, '', FN, FRequest.Command, GetParams(FRequest.Parameter), FRequest.RawHeader.Text,
                                      FPostData, FIPInfo, FRequest, FSettings, cmCGI);

              if FCGIInfo.HasResult then
                begin
                  //trust CGI headers as sent (fix...)
                  FResponse.RawHeader.Text := FCGIInfo.Header;
                  FResponse.ResponseCode := 200;
                  FMode := cmReadCGI;
                end
              else
                begin
                  FResponse.ResponseCode := 404;
                  FMode := cmDone;
                end;
            end;
        end;

        if Assigned (PreParser) then
          begin
            Result := True;
            FCGIInfo := ExecuteCGI (PreParser.ExePath, PreParser.Params, FN, FRequest.Command, GetParams(FRequest.Parameter), FRequest.RawHeader.Text, FPostData, FIPInfo, FRequest, FSettings, cmPP);
              if FCGIInfo.HasResult then
                begin
                  //trust CGI headers as sent (fix...)
                  FResponse.RawHeader.Text := FCGIInfo.Header;
                  FResponse.ResponseCode := 200;
                  FMode := cmReadCGI;
                end
              else
                begin
                  FResponse.ResponseCode := 503; //Service unavailable
                  FMode := cmDone;
                end;
            
          end;

    end;
end;

procedure THTTPHandler.Report404;
begin
  //return error document.
  FResponse.ResponseCode := 404;
end;

procedure THTTPHandler.Init;
begin
  FResponse := THTTPResponse.Create;
  inherited;
end;

function THTTPHandler.MapVirtualDir(URL, Domain: String): TFileName;
var Path: String;
    VD: TVirtualDomain;
    i: Integer;
begin
  Path := GetPath (URL);
  VD := GetVirtualDomain (Domain);
  if Assigned (VD) then
    begin
      for i:=0 to VD.FVirtualPath.Count - 1 do
        if Compare (Path, VD.FVirtualPath[i]) then //found
          begin
            Result := TString(VD.FVirtualPath.Objects[i]).Value+PathSep+Copy(GetFile(URL), Length(Path)+1, maxint);
            break;
          end;
    end;
  if (Result='') and (Domain<>'') then //try default (empty) domain:
    Result := MapVirtualDir (URL);
end;

procedure THTTPHandler.CreateFileHeaders(FileName: TFileName);
var sr: TSearchRec;
    f: Integer;
    timestamp, mimetype: String;
begin
  //Create file headers based on FileName:
  //maybe see if we have access rights? (time consuming to test rights..)

  if FileName='' then
    begin
      FResponse.ResponseCode := 500; //Internal error:
      exit;
    end;

  if not FileExists (FileName) then
    begin
      //Maybe this is a directory, if so, redirect:
      if DirectoryExists (FileName) then
        begin
          FResponse.ResponseCode := 301; //Redirect
          FResponse.Header.Values['Location'] := FRequest.Parameter + '/';
          exit;
        end
      else
        begin
          FResponse.ResponseCode := 404; //Not found
          exit;
        end;
    end;

  f := FindFirst (FileName, faAnyFile, sr);

  if f<>0 then //oops, error:
    begin
      FResponse.ResponseCode := 503; //Service unavailable
      exit;
    end;

  {  //try: open file
     //if not openened, not enough rights or file locked
     //return forbidden
     // ???
  }

  timestamp := RFC822DateTime (FileDateToDateTime(sr.Time));

  with FResponse.Header do
    begin
      Values ['Content-Length'] := IntToStr(sr.Size);
      Values ['Last-Modified'] := timestamp;
      mimetype := MimeTypeFromExtension (ExtractFileExt(FileName));
      if mimetype = '' then
        mimetype := 'application/octet-stream';
      Values ['Content-Type'] := mimetype;

      //range support:
      Values ['Accept-Ranges'] := 'bytes';
      FRangeStart := 0;
      FRangeEnd := sr.Size-1;
    end;

  findclose (sr);

  //see if there is a modified tag
  if FRequest.Header.Values['If-Modified-Since'] = TimeStamp then //exact match
    FResponse.ResponseCode := 304 //Not modified
  else
    FResponse.ResponseCode := 200;

end;

function THTTPHandler.GetDefaultDoc(Path: TFileName;
  Domain: String): String;
var VD: TVirtualDomain;
    i,j: Integer;
    v: String;
begin
  //loop default documents of domain
  //until found on disc
  VD := GetVirtualDomain (Domain);
  if Assigned (VD) then
    begin
      for i := 0 to VD.FDefaultDocuments.Count - 1 do
        begin //check manually mapped files:
          for j := 0 to VD.FManualURL.Count - 1 do
            if VD.FManualURL[j] = VD.FDefaultDocuments[i] then
              begin
                Result := VD.FDefaultDocuments[i];
                break;
              end;
          if Result='' then //check physical file locations
            begin
              v := Path+PathSep+VD.FDefaultDocuments[i];
              if FileExists (v) then
                begin
                  Result := VD.FDefaultDocuments[i];
                  break;
                end;
            end;
        end;
    end;
  if (Result='') and (Domain<>'') then
    Result := GetDefaultDoc(Path);
end;

procedure THTTPHandler.ReadPostData;

var j, l: Integer;
    b: String;
begin
  //Read in postdata:
  FPostData := '';
  l := StrToIntDef (FRequest.Header.Values['Content-Length'], 0);
  if (l<=0) or (l>MAX_POST_DATA_SIZE) then
    begin
      FMode := cmClose;
      exit;
    end;
  while (length (FPostData) < l) and (FSock.LastError = 0) do
    begin
      j := l - length (FPostData);
      if j>2048 then
        j := 2048;
      b := FSock.RecvBufferStr (j, 30000);
      if b='' then //sorry, taken too long, aborting
        begin
          FPostData := '';
          break;
        end
      else
        FPostData := FPostData + b;
    end;
end;

procedure THTTPHandler.MakeResponseHeaders;
var connection: String;
begin
  with FResponse.Header do
    begin
      Values ['Date'] := RFC822DateTime (now);
      Values ['Server'] := FHTTPVars.FServerName;

      if FKeepAlive then
        Connection := 'Keep-Alive'
      else
        Connection := 'Close';
      Values ['Connection'] := Connection;

//      if Values ['Content-Type']='' then //some error doc. file transfer should set mimetype
//        Values ['Content-Type'] := 'text/html';
//      Values ['Accept-Ranges'] := 'bytes';
    end;
end;

procedure THTTPHandler.MakeErrorDoc;
var FN: String;
    S: TStrings;
    ErrMsg: String;
    ServerName: String;
begin
  FResponse.Data := '';
  if (FHTTPVars.FErrorDocs<>'') then
    begin
      FN := FHTTPVars.FErrorDocs+PathSep+IntToStr(FResponse.ResponseCode)+'.html';
      if FileExists (FN) then
        begin
          S := TStringList.Create;
          try
            S.LoadFromFile (FN);
            FResponse.Data := S.Text;
          except
          end;
          S.Free;
        end;
    end;

  if FResponse.Data='' then //Create one:
    begin
      ErrMsg := HTTPCodeToMessage (FResponse.ResponseCode);
      if ErrMsg='' then
        ErrMsg := 'Unknown error';
      if FHTTPVars.FServerName<>'' then
        ServerName := FHTTPVars.FServerName
      else
        ServerName := 'Visual Synapse HTTP Server';
      if FRequest.Header.Values['Host'] <> '' then
        ServerName := ServerName + ' at ' + FRequest.Header.Values['Host'] + ':' + FSettings.FListenPort;
      FResponse.Data := Format ( '<html><head><title>%d - %s</title></head>'#10+
                                 '<body><h1>Error %d</h1>   <h2>%s</h2>'#10+
                                 'There was an error while processing '+FRequest.Parameter+
                                 '<hr><i>'+ServerName+'</i>'#10+
                                 '<hr><font size=-1>Visual Synapse 2004</font>'#10+
                                 '</body></html>',
                                 [FResponse.ResponseCode, ErrMsg, FResponse.ResponseCode, ErrMsg]
                               );
    end;
  FResponse.MimeType := 'text/html';
end;

procedure THTTPHandler.MakeArgs;
var s: String;
    i: Integer;
begin
  //split up Request.Parameter
  //into Request.FileName and Request.Args
  FRequest.FileName := GetFile (FRequest.Parameter);
  s := copy (FRequest.Parameter, length (FRequest.FileName)+2, maxint);
  FRequest.Args.Clear;
  if s<>'' then
    begin
      s := StringReplace (s, '&amp;', '&', [rfReplaceAll, rfIgnoreCase]);
      FRequest.Args.Text := StringReplace (s, '&', #13#10, [rfReplaceAll]);
      for i := 0 to FRequest.Args.Count - 1 do
        FRequest.Args[i] := StringReplace (DecodeURL (FRequest.Args[i]), '+', ' ', [rfReplaceAll]);
    end;
  //now Args contains a nice name/value pair if all went ok :)
end;

function THTTPHandler.MergeURL(Path, FileName: String): String;
begin
  if Path = '' then
    Path := '/';
  if Path [length(Path)]<>'/' then
    Path := Path + '/';
  if (FileName<>'') and (FileName[1]='/') then
    Delete (FileName, 1, 1);
  Result := Path + FileName;
end;

procedure THTTPHandler.ProcessGetHeadPost(Method: TEnumHTTPProtocols);
var GetFileName,
    DefDoc,
    Domain: String;
begin
  //if Autonome
  //Check for manual url
  //if not, check Preparser
  //and/or CGI

  //Is GET allowed in the first place?
  if not (Method in FHTTPVars.FSupported) then
    begin
      FResponse.ResponseCode := 405; //method not allowed
      exit;
    end;

  if (FRequest.Parameter='') or (FRequest.Parameter[1]<>'/') then
    begin
      FResponse.ResponseCode := 400; //Bad request
      exit;
    end;

  //from here, a callback to client app is possible

  if Method = hpPOST then
    ReadPostData;

  MakeArgs;

  //todo: make args on postdata

  //Is GET automated:
  if not (Method in FHTTPVars.FAutomated) then
    begin
      //Manual.. no server action at all:
      case Method of
        hpGet: CallBackRequest (FCallBack.FOnGet);
        hpHead: CallBackRequest (FCallBack.FOnHead);
        hpPost: CallBackRequest (FCallBack.FOnPost);
      end;
    end

  else

    begin //process action:

      //see if this is CGI or PreParser:
      Domain := FRequest.Header.Values['Host'];

      if not CheckGetHeadPostParser(Domain) then
        begin //try to find the file:
          //Map virtual dir:

          GetFileName := MapVirtualDir ( FRequest.Parameter,
                                         Domain);
          if GetFileName='' then //sorry, not found
            begin
              FResponse.ResponseCode := 404;
              exit;
            end;

          //Check if this is a directory, if so, redirect

          if FRequest.Parameter[Length(FRequest.Parameter)]='/' then
             //directory request:

             //default document needed
             begin
               DefDoc := GetDefaultDoc (GetFileName, Domain);
               if DefDoc<>'' then
                 begin //generate redirect
//                   GetFileName := DefDoc
                   FResponse.ResponseCode := 301; //Redirect
                   FResponse.Header.Values['Location'] := MergeURL (FRequest.Parameter, DefDoc);
                   exit;
                 end
               else
                 begin
                   //else directory listing
                   if true {FHTTPVars.FDirListing} then
                     begin
                       FResponse.ResponseCode := 200;
                       if Method in [hpGet, hpPost] then //don't delived listing on HEAD
                         FResponse.Data := ListDirAsHTML (GetFileName, GetFile(FRequest.Parameter), Domain);
                       FResponse.MimeType := 'text/html';
                       exit;
                     end
                   else
                     begin
                       //else forbidden
                       FResponse.ResponseCode := 403; //forbidden
                       exit;
                     end;
                 end
             end
          else
            begin

            end;


          CreateFileHeaders (GetFileName); //will generate 404 or appropiate header

          //if file exists (assume readable by server)
          if ( (FResponse.ResponseCode = 200))// or
//               (FResponse.ResponseCode = 206 {Partial content}))
              and (Method in [hpGet, hpPost]) then
            begin
              //settings for file stream
              FMode := cmGet;
              FCurrentGetFile := GetFileName;

              CheckRanges;

            end
          else
            FMode := cmDone;

        end;
    end;
end;

procedure THTTPHandler.CheckRanges;
var Range,
    srstart,
    srend: String;
    RStart,
    REnd: Int64;
begin
  //see if client request range:
  Range := FRequest.Header.Values['Range'];
  //Valid according to rfc 2616 is also:
  //Range: bytes=1-2,3-4,5-6
  //we don't support that currently...
  //Range: bytes=2-3 is supported.
  if Range<>'' then
    begin
      if (lowercase(copy(Range,1,6))<>'bytes=') or
         (pos (',', Range)>0) then
        begin
          FResponse.ResponseCode := 501; //Not implemented
          exit; //sorry...
        end;
      Range := copy (range,7,maxint);
      srStart := copy (Range, 1, pos ('-', Range)-1);
      srEnd := copy (Range, pos ('-', Range)+1, maxint);
      rStart := StrToIntDef (srStart, -1);
      rEnd := StrToIntDef (srEnd, -1);
      if ((srStart<>'') and (rStart=-1))
         or
         ((srEnd<>'') and (rEnd=-1))
         or
         ((srEnd<>'') and (rEnd < rStart)) then
        begin
          FResponse.ResponseCode := 400; //Malformed request
          exit;
        end;
      if rStart < FRangeStart then
        rStart := FRangeStart;
      if (rEnd=-1) or (rEnd > FRangeEnd) then
        rEnd := FRangeEnd;
      FRangeStart := rStart;
      FRangeEnd := rEnd;
      FResponse.ResponseCode := 206;
    end;

  if FResponse.ResponseCode = 206 then
    begin
      FResponse.Header.Values['Content-Range'] :=
        Format ('%d-%d/%s',
         [FRangeStart, FRangeEnd,
          FResponse.Header.Values['Content-Length']]);
      FResponse.Header.Values ['Content-Length'] :=
        IntToStr (1+FRangeEnd-FRangeStart);
    end;
end;

{ TVirtualDomain }

constructor TVirtualDomain.Create;
begin
  FDefaultDocument := '';
  FDefaultDocuments := TStringList.Create;
  FHostName := '';
  FVirtualPath := TStringList.Create;
  FCGI := TStringList.Create;
  FPreParser := TStringList.Create;
  FManualURL := TStringList.Create;
  FMimeTypes := TStringList.Create;
end;

destructor TVirtualDomain.Destroy;

  procedure FreeWithObj (S: TStrings);
  var i: Integer;
  begin
    for i:= 0 to S.Count - 1 do
      if Assigned (S.Objects[i]) then
        S.Objects[i].Free;
    S.Free;
  end;

begin
  FDefaultDocuments.Free;
  FreeWithObj (FVirtualPath);
  FreeWithObj (FCGI);
  FreeWithObj (FPreParser);
  FreeWithObj (FManualURL);
  FreeWithObj (FMimeTypes);
end;

{ THTTPResponse }

procedure THTTPResponse.FixHeader;
var i: Integer;
begin
  if MimeType <> '' then
    Header.Values['Content-Type'] := MimeType;
  if Data <> '' then
    Header.Values['Content-Length'] := IntToStr (Length(Data));
  for i := 0 to Header.Count - 1 do
    RawHeader.Add (StringReplace(Header[i], '=', ': ', []));
  for i := RawHeader.Count-1 downto 0 do
    if RawHeader[i]='' then
      RawHeader.Delete(i);  
end;

end.
