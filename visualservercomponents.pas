unit visualservercomponents;
/////////////////////////////////////////////
//
//  This unit is maintained by:
//  rene tegel rene@dubaron.com
//
//  Initially created by:
//  rene@dubaron.com
//
//
//  This file is released as 'Open Source' and to the 'Public Domain'
//  As those terms have no legal status, this file is licensed under
//  a number of OSI-approved licenses.
//
//  You can use this unit as long as you meet the conditions of
//  at least one(1) of the following licenses:
//
//  MPL - Mozilla Public Lisence - http://www.mozilla.org/MPL/
//  GPL - General Public License - Any version http://www.gnu.org/copyleft/gpl.html
//  LGPL - Lesser General Public License - Any version http://www.gnu.org/copyleft/lgpl.html
//
//
//  Usage of this code is entirely at own risk.
//
/////////////////////////////////////////////

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}


interface

uses Classes, visualserver, tcpserver, httpserver, ftpserver, authentication, pastella{, smtpserver};

//registers the components

procedure Register;

implementation

{$R visualserver.dcr}

procedure Register;
begin
  RegisterComponents ('visualsynapse', [TvsHTTPServer, TvsFTPServer, TAuthentication{, TPastella}{, TSMTPServer}]);
end;

end.
