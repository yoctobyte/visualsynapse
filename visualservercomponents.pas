unit visualservercomponents;

interface

uses Classes, visualserver, tcpserver, httpserver, smtpserver;

//registers the components

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents ('visualsynapse', [TTCPServer, THTTPServer, TSMTPServer]);
end;

end.
