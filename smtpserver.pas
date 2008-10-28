unit smtpserver;
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

uses Classes, visualserverbase, blcksock;

type

  TSMTPServer = class (TVisualServer)
  public
    constructor Create (AOwner:TComponent); override;
  end;

  TSMTPHandler = class (TServerHandler)
    procedure Handler; override;
  end;


implementation

{ TSMTPServer }

constructor TSMTPServer.Create(AOwner: TComponent);
begin
  inherited;
  FClientType := TSMTPHandler;
  ListenPort := '25';
end;

//SMTP Handler
procedure TSMTPHandler.Handler;
var FData:String;
begin
  //Handle a smtp transfer
  FSock.SendString ('220+'+FSettings.FServerName+' SMTP'+CRLF);
  FSock.SendString ('220 Be welcome '+FIPInfo.RemoteIP+CRLF);

  //example loop, smtp not implemented yet.
  FData := '';
  while not Terminated and (FSock.LastError=0) do
    begin
      FSock.RecvString (60000);
      if FSock.LastError = 0 then
        begin

        end
      else
        begin
          FSock.SendString ('000 TimeOut, terminating connection');
          FSock.CloseSocket;
          Break;
        end;

    end;
end;


end.
