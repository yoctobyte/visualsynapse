unit visualservercomponents;

interface

uses Classes, visualserver, tcpserver, httpserver, ftpserver{, smtpserver};

//registers the components

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents ('visualsynapse', [TvsTCPServer, TvsHTTPServer, TvsFTPServer{, TSMTPServer}]);
end;

end.
