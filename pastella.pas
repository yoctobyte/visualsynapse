unit pastella;

//p2p class
//idea from the 'gnutella' network,
//but slightly adjusted.

//don't know for sure weather to inherit from visualserverbase or not..
//client implementation is a bit special in this case

(*

  * ListenThread
  * ConnectRemoteThread
  * ClientHandleAfterConnect thread, base for following two threads:
  * Clientconnectremote thread //call inherited execute after connecting?
  * Clientacceptremote



*)

interface

uses Windows, Classes, SysUtils, blcksock, syncobjs;


type
  TP2PPacket = record
    Packet: String;
    Checksum: String;
  end;

  TP2PSettings = record
    ListenPort: String;
    ListenIP: String;
    DoListen: Boolean;
    MinConnections: Integer;
    MaxConnections: Integer;
    NumConnections: Integer;
    CS: TCriticalSection; //use this this share resources among threads
  end;

  TPastella = class (TComponent)
  protected
    FSettings: TP2PSettings;
  published
    property ListenPort: String read FSettings.ListenPort write FSettings.ListenPort;
  end;

  TListener = class (TThread)
    LSock: TTCPBlockSocket;
    procedure Execute; override;
  end;

  TConnecter = class (TThread)
    CSock: TTCPBlockSocket;
    procedure Execute; override;
  end;

  TP2PConnection = class (TThread)
    procedure Execute; override;
  end;

  TP2PConnect = class (TP2PConnection)
    procedure Execute; override;
  end;

  TP2PAccept = class (TP2PConnection)
    procedure Execute; override;
  end;

implementation

{ TListener }

procedure TListener.Execute;
begin
  //listening socket
  //waits for incoming connections
  //launches a handler
  
end;

end.
