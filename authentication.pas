unit authentication;

//this unit is not thread-safe yet..

interface

{$IFDEF FPC}
  {$IFDEF WIN32}
    {$DEFINE WINDOWS}
  {$ELSE}
    {$DEFINE UNIX}
  {$ENDIF}
{$ELSE}
  {$IFDEF LINUX} //Kylix
    {$DEFINE UNIX}
  {$ELSE}
    {$DEFINE WINDOWS}
  {$ENDIF}
{$ENDIF}

//hopefully windows authentication works on win 9x as well.
//Please see manual before using windows authentication
//when application is not run as service
//you will need to set extra parameters on NT4 and W2K systems
//for the user that runs the application
//XP should work "out-of-the-box"

//todo:
//it would bve really cool to have the option of
//in case of system validation
//let the current thread run with this user's privilegs
//telnet, ftp and maybe other protocols can benefit from it
//since it allows setting advanced file permissions.
//this of course has the drawback of security
//and there may be loads of practical issues.

//using windows' ImpersonateLoggedOnUser api
//a thread can effectively use these users' rights.
//a call to LogonUser is sufficient.


uses Classes, SysUtils, IniFiles, SynaCode,
     {$IFDEF WINDOWS}
     Windows,
     {$ENDIF}
     vstypedef;

type
  TAuthEncoding = (aePlain, aeBase64, aeMD5);
  TAuthMethod = (amDenyAll, amAcceptAll, amAnonymous, amInifile, amSystem, amCallback{, amModAuth, amMySQL});

  TOnAuthenticate = procedure (Sender: TComponent; User, Pass: String; IPInfo: TIPInfo; var Authenticated: Boolean) of Object;

  TAuthentication = class (TComponent)
  private
    FCaseSensitive: Boolean;
    FPasswordFile: String;
    FEncoding: TAuthEncoding;
    FMethod: TAuthMethod;
    FIPInfo: TIPInfo;
  protected
    FPassDecoded: String;
    FPassEncoded: String;
    FDummyBool: Boolean;
    FUser: String;
    FPass: String;
    FOnAuthenticate: TOnAuthenticate;
    FIni: TIniFile;
    procedure EncodeDecodePass; //decode using appropiate method (=base64)
    function AuthenticateAnonymous: Boolean;
    function AuthenticateWin32: Boolean;
    function AuthenticateUnix: Boolean;
    function AuthenticateSystem: Boolean;
    function AuthenticateIniFile: Boolean;
    function AuthenticateCallBack: Boolean;
  public
    function Authenticate (User, Pass: String; Encoding: TAuthEncoding=aePlain): Boolean;
    function GetAuthenticated: Boolean;
    function AddUser (User, Pass: String): Boolean;
//    procedure ModifyUser - identical to AddUser
    property IPInfo: TIPInfo read FIPInfo write FIPInfo;
  published
    property Encoding: TAuthEncoding read FEncoding write FEncoding;
    property Method: TAuthMethod read FMethod write FMethod;
    property User: String read FUser write FUser;
    property Pass: String read FPass write FPass;
    property PasswordFile: String read FPasswordFile write FPasswordFile;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive;
    property IsAuthenticated: Boolean read GetAuthenticated write FDummyBool;
    property OnAuthenticate: TOnAuthenticate read FOnAuthenticate write FOnAuthenticate;
  end;

implementation

{ TAuthentication }

function TAuthentication.AddUser(User, Pass: String): Boolean;
begin
  try
    try
      FIni := TIniFile.Create (FPasswordFile);
      FIni.WriteString ('Authenticate', User, EncodeBase64(MD5(Pass)));
    finally
      FIni.Free;
    end;
  except
    Result := False;
  end;
end;

function TAuthentication.Authenticate(User, Pass: String;
  Encoding: TAuthEncoding): Boolean;
begin
  FUser := User;
  FPass := Pass;
  FEncoding := Encoding;
  EncodeDecodePass;
  case Method of
    amDenyAll: Result := False;
    amAcceptAll: Result := True;
    amAnonymous: Result := AuthenticateAnonymous;
    amIniFile: Result := AuthenticateIniFile;
    amSystem: Result := AuthenticateSystem;
  else
    Result := False;
  end;
end;

function TAuthentication.AuthenticateAnonymous: Boolean;
var U: String;
begin
  if FCaseSensitive then
    U := FUser
  else
    U := lowercase (FUser);
  Result := (U = 'anonymous');
end;

function TAuthentication.AuthenticateCallBack: Boolean;
var a: Boolean;
begin
  Result := False;
  if Assigned (FOnAuthenticate) then
    try
      a := False;
      FOnAuthenticate (Self, FUser, FPass, FIPInfo, a);
      Result := a;
    except
      Result := False;
    end;
end;

function TAuthentication.AuthenticateIniFile: Boolean;
begin
  try
    try
      FIni := TIniFile.Create (FPasswordFile);
      Result := EncodeBase64(FPassEncoded) = FIni.ReadString ('Authenticate', User, '');
    finally
      FIni.Free;
    end;
  except
    Result := False;
  end;
end;

function TAuthentication.AuthenticateSystem: Boolean;
begin
{$IFDEF WINDOWS}
  Result := AuthenticateWin32;
{$ELSE}
  Result := AuthenticateUnix;
{$ENDIF}
end;

function TAuthentication.AuthenticateUnix: Boolean;
begin
{$IFNDEF UNIX}
  Result := False;
{$ELSE}
  //Match against password file in /etc
  (* //see http://www.experts-exchange.com/Programming/Programming_Languages/Cplusplus/Q_21104620.html#11897622
 You either want to authenticate them using PAM; or if you want to make assumptions
about the authentication method, use the shadow functions

getspnam(user)  to read their entry from the shadow file
then compare it using crypt.

For details about using pam

See the Linux-Pam Application Developer's Guide, section 2
 http://www.krasline.ru/Library/pam-doc/pam_appl-2.html

And the example code: http://www.krasline.ru/Library/pam-doc/pam_appl-6.html
  *)
{$ENDIF}
end;

function TAuthentication.AuthenticateWin32: Boolean;
var Token: THandle;
begin
{$IFNDEF WINDOWS}
  Result := False;
{$ELSE}
  Result := LogonUser ( PChar(User),
                        nil, //PChar('.'), //nil, //domain
                        PChar(Pass),
                        LOGON32_LOGON_INTERACTIVE,  //NETWORK, //BATCH, //
                        LOGON32_PROVIDER_DEFAULT,
                        Token
                      );
  //Release token:
  CloseHandle (Token);
{$ENDIF}
end;

procedure TAuthentication.EncodeDecodePass;
begin
  case FEncoding of
    aePlain: FPassDecoded := FPass;
    aeBase64: FPassDecoded := DecodeBase64(FPass);
    aeMD5: FPassDecoded := FPass; //athentication routine should check
  end;
  case FEncoding of
    aePlain, aeBase64: FPassEncoded := MD5(FPassDecoded); //beware, this is not hexadecimal!
    aeMD5: FPassEncoded := FPassDecoded;
  end;
end;

function TAuthentication.GetAuthenticated: Boolean;
begin
  Result := Authenticate (FUser, FPass, Encoding);
end;

end.
