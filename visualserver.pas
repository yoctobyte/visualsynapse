unit visualserver;

interface

uses Classes, visualserverbase, tcpserver, httpserver, smtpserver;

//registers the components

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents ('VisualSynapse', [TTCPServer, THTTPServer, TSMTPServer]);
end;

end.
