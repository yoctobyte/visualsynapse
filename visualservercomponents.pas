unit visualservercomponents;

interface

uses Classes, visualserver, tcpserver, httpserver, ftpserver, authentication, pastella{, smtpserver};

//registers the components

procedure Register;

implementation

{$R visualserver.dcr}

procedure Register;
begin
  RegisterComponents ('visualsynapse', [TvsHTTPServer, TvsFTPServer, TAuthentication, TPastella{, TSMTPServer}]);
end;

end.
