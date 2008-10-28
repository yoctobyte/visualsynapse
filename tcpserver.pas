unit tcpserver;
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

uses Classes, SysUtils, visualserverbase;

type
  TTCPServer = class (TVisualServer) //basic TCP server
    constructor Create (AOwner: TComponent); override;
  end;

  TTCPHandler = class (TServerHandler)
    procedure Handler; override;
  end;

implementation

{ TTCPServer }

constructor TTCPServer.Create(AOwner: TComponent);
begin
  inherited;
  FClientType := TTCPHandler;
end;

{ TTCPHandler }

procedure TTCPHandler.Handler;
var Buf:String;
begin
  //basic server example
  while not Terminated and (FSock.LastError <> 0) do
    begin
      if FSock.WaitingData > 0 then
        begin
          SetLength (Buf, FSock.WaitingData);
          FSock.RecvBuffer (Pointer(Buf), Length(Buf));
          FRequest.RawRequest := Buf;
          CallBack (OnRequest);
          if FResponse.ResponseText <> '' then
            FSock.SendString (FResponse.ResponseText);
          if FResponse.Data<>'' then
            FSock.SendString (FResponse.Data);
          if Assigned (FResponse.DataStream) then
            try
              FSock.SendStream (FResponse.DataStream);
              FreeAndNil (FResponse.DataStream);
            except end;
        end;
    end;
end;



end.
