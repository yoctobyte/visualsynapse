unit sqlsmtpserver;

interface

uses Classes, visualserverbase;

type

  TSqlSMTPServer = class (TVisualServer)
  public
    constructor Create (AOwner:TComponent); override;
  end;

  TSqlSMTPHandler = class (TServerHandler)
  public
    procedure Init; override;
    procedure CopyCustomVars; override;
    procedure Handler; override;
  end;


implementation

{ TSqlSMTPServer }

constructor TSqlSMTPServer.Create(AOwner: TComponent);
begin
  inherited;
  FClientType := TsqlSMTPHandler;
  ListenPort := '25';
end;

{ TSqlSMTPHandler }

procedure TSqlSMTPHandler.CopyCustomVars;
begin
  inherited;

end;

procedure TSqlSMTPHandler.Handler;
begin
  inherited;

end;

procedure TSqlSMTPHandler.Init;
begin
  inherited;

end;

end.
