unit thttpserver;

interface

uses Classes, SysUtils, visualserverbase;

type
  THTTPPServer = class (TVisualServer) //basic TCP server
    constructor Create (AOwner: TComponent); override;
  end;

  THTTPHandler = class (TServerHandler)
    procedure Handler; override;
  end;

implementation

{ THTTPPServer }

constructor THTTPPServer.Create(AOwner: TComponent);
begin
  inherited;
  FClientType := THTTPHandler;
end;

{ THTTPHandler }

procedure THTTPHandler.Handler;
begin
  //this is where the magic starts
  FSock.

end;

end.
