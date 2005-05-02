unit visualserver;

interface

uses Classes, visualserverbase, tcpserver, httpserver, smtpserver;

//registers the components

procedure Register;

implementation

procedure Register;
begin
  //RegisterComponents ('VisualSynapse', [TTCPServer, TvsHTTPServer, TSMTPServer]);
end;

end.
