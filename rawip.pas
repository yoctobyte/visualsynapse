unit rawIP;
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

{ Version 0.1a
  This unit is explitely designed for windows. Sending raw sockets may succeed on linux.
  The sniffing socket is solely for windows 2000/XP and needs administrator rights to run.

  Based on synapse blocking sockets are two decsendants:

  *TSniffingSocket for receiving all network packets
  *TRawUDPSocket example of sending raw IP headers, this implementation can spoof the sender.
  //FRemoteSin as declared in blcksock.pas must be moved from private to
  //protected in order for TRawUDPSocket unit to use it.

  Also, there is a
  *TSniffer object, that encapsulates a sniffer thread.

  for system information from ip helper api, there is:
  *TIPHelper

  see docs on synapse.wiki.dubaron.com for how to use.

  Author:
    Rene Tegel rene@dubaron.com
    release 0.1 augustus 17-19 2003.
}


interface
uses Windows, classes, Sysutils, {winsock,}synautil,
     blcksock, synsock, dialogs;

{
Usefull links:

Sending raw sockets:
http://msdn.microsoft.com/library/en-us/winsock/winsock/tcp_ip_raw_sockets_2.asp
Socket options:
http://msdn.microsoft.com/library/en-us/winsock/winsock/tcp_ip_socket_options_2.asp
changes between wsock32.dll and ws2_32.dll:
http://support.microsoft.com/default.aspx?scid=http://support.microsoft.com:80/support/kb/articles/Q257/4/60.ASP&NoWebContent=1

sniffing:
http://msdn.microsoft.com/library/default.asp?url=/library/en-us/winsock/winsock/wsaioctl_2.asp
http://www.securityfriday.com/Topics/caputure_packet.html
}



{relevant RFC's:
  IP: RFC 791 IP
          950 subnetting
          919 broadcasting
          922 broadcastinf and subnets
          792 ICMP
          1112 Multicasting

  UDP: RFC 768
  TCP: RFC 793

  IP, ARP and FDDI: RFC 1390
  ARP and Ethernet: RFC 826
  IP and Ethernet: RFC 894
  IP and IEEE 802: RFC 1042
  PPP: RFC 1661 Point-to-Point protocol
       RFC 1662 PPP and HDLC framing
}


//winsock 2 declarations
const SIO_RCVALL = $98000001;

//raw IP packet related constants:
const //Ethernet header flags:
      EthernetType2 = $0800;
      EthernetTypeARP = $0806;

      //IP header flages
      TCP_Flag_Unused = 1 shl 15;
      TCP_Flag_Dont_Fragment = 1 shl 14;
      TCP_Flag_More = 1 shl 13;

      //ICMP predefined protocol constants:
      ICMP_Echo_Reply = 0;
      ICMP_Dest_Unreachable = 3;
      ICMP_Source_Quench = 4;
      ICMP_Redirect = 5;
      ICMP_Echo_Request = 8;
      ICMP_Router_Advertisement=9;
      ICMP_Router_Sollicitation = 10;
      ICMP_Time_Exceeded = 11;
      ICMP_Parameter_Problem = 12;
      ICMP_Timestamp_Request = 13;
      ICMP_Timestamp_Reply = 14;
      ICMP_Information_Request = 15;
      ICMP_Information_Reply = 16;
      ICMP_Address_Mask_Request = 17;
      ICMP_Address_Mask_Reply = 18;
      ICMP_TraceRoute = 30;

      //TCP header flags:
      TCP_FIN = 1;  //Connection control
      TCP_SYN = 2;  //Synchronize, connection control, syncing sequence numbers
      TCP_RST = 4;  //RESET, end of connection
      TCP_PSH = 8;  //PUSH
      TCP_ACK = 16; //Acknowledgement number is valid
      TCP_URG = 32; //Urgent pointer is valid

      //TCP OPTION FIELD VALUES
      TCPOPT_END_OF_OPTIONS = 0;
      TCPOPT_NO_OPERATION = 1;
      TCPOPT_MAX_SEQMENT_SIZE = 2;
      TCPOPT_WINDOW_SCALE = 3;
      TCPOPT_SELECTIVE_ACK = 4;
      TCPOPT_TIMESPAMP = 8;

      //IP HEADER OPTION VALUES
      IPOPT_END_OF_OPTIONS = 0;
      IPOPT_NO_OPERATION = 1;
      IPOPT_RECORD_ROUTE = 7;
      IPOPT_TIMESTAMP = 68;
      IPOPT_LOOSE_SOURCE_ROUTE = 131;
      IPOPT_STRICT_SOURCE_ROUTE = 137;



// IP / TCP / UDP / ICMP / ARP header structures:
//only IP and UDP headers are tested.
//for other structures i cannot guarantee they are correct.

type  Byte6 = array[0..5] of byte;
      Byte3 = array[0..2] of byte;

      TIPHeader = packed record
        case Integer of
          0: (
              VerLen: Byte;
              TOS: Byte;
              TotalLen: Word;
              Identifier: Word;
              FragOffsets: Word;
              TTL: Byte;
              Protocol: Byte;
              CheckSum: Word;
              SourceIp: DWORD;
              DestIp: DWORD;
    //          Options: DWORD; //no options by default, header size 5 DWords
              );
          1: (Raw: Array[0..9] of Word);
      end;
      PIPHeader = ^TIPHeader;

      TArpHeader = packed record
        //Ethernet type typically $0806
        Hardware: Word;
        Protocol: Word;
        HardwareAddressLength:byte;
        ProtocolLength: byte;
        Operation:Word;
        SenderHWAddress:Byte6;
        SenderIPAddress:DWord;
        TargetHWAddress:Byte6;
        TargetIPAddress:DWord;
      end;

     TEthernetHeader = packed record
       DestMacAddress:Byte6; //leave $FF FFFF for broadcasts
       SourceMacAddress:Byte6;
       ProtocolType:Word; //mostly is EthernetType2
     end;
{   An EthernetPacket typically looks as follows:
      * TEthernetHeader
      * TIPHeader
      * TCP or UDP header
      * User data (TCP/UDP)
      * CRC checksum, DWord. wrapped by the ethernet protocol.
    so there is no real use for checksumming inside the user data.
}
     TICMPHeader = packed record
       ICMPtype:byte;
       code:byte;
       Checksum:Word;
     end;
     PICMPHeader = ^TICMPHeader;

     TIPICMPHeader = packed record
       IPHeader:TIPHeader;
       ICMPHeader:TICMPHeader;
     end;
     PIPICMPHeader = ^TIPICMPHeader;

     TICMPPacket = packed record //??
       IPHeader:TIPHeader;
       ICMPHeader:TICMPHeader;
       Data:Array[0..1499] of byte;
     end;

     TTCPHeader = packed record
       SourcePort:Word;
       DestPort:Word;
       SequenceNumber:DWord;
       AcknowledgementNumber:DWord;
       Offset:Byte; //only left 4 bits. Header length in 32-bit segments
       Flags:Byte;
       Window:Word;
       Checksum:Word;  //includes speudo header instead of TCP header.
       UrgentPointer:Word;
       {Optionally:
       Options:byte3; //MSS (Maximum Segment Size) at connection startup
       Padding:byte;
       }
     end;
     TIPTCPHeader = packed record
       IP:TIPHeader;
       TCP:TTCPHeader;
     end;
     PIPTCPHeader = ^ TIPTCPHeader;
     
     TTCPPacket = packed record
       IPHeader:TIPHeader;
       TCPHeader:TTCPHeader;
       Data:Array[0..32767] of byte;
     end;

     TUDPHeader = packed record
       case Integer of
       0: (
         SourcePort,
         DestPort : Word; //why why why a Dword ???
         Length,
         Checksum:word;
           );
       1: (
         Raw:Array[0..3] of Word;
          );
     end;
     PUDPHeader = ^TUDPHeader;
     TIPUDPHeader = packed record
       IP:TIPHeader;
       UDP:TUDPHeader;
     end;



// Helper functions from the ip helper api (iphlpapi.dll)

// Next types extracted from whirwater:
// http://www.whirlwater.com/frames.php?http://www.whirlwater.com/information/2001/windows2000/usingtheiphelperapi.html
// thanx for coverting type definitions fellows
const
  MAX_HOSTNAME_LEN               = 128; { from IPTYPES.H }
  MAX_DOMAIN_NAME_LEN            = 128;
  MAX_SCOPE_ID_LEN               = 256;
  MAX_ADAPTER_NAME_LENGTH        = 256;
  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;
  MAX_ADAPTER_ADDRESS_LENGTH     = 8;

type
  TIPAddressString = Array[0..4*4-1] of Char;

  PIPAddrString = ^TIPAddrString;
  TIPAddrString = Record
    Next      : PIPAddrString;
    IPAddress : TIPAddressString;
    IPMask    : TIPAddressString;
    Context   : Integer;
  End;

  PFixedInfo = ^TFixedInfo;
  TFixedInfo = Record { FIXED_INFO }
    case integer of
    0: (
    HostName         : Array[0..MAX_HOSTNAME_LEN+3] of Char;
    DomainName       : Array[0..MAX_DOMAIN_NAME_LEN+3] of Char;
    CurrentDNSServer : PIPAddrString;
    DNSServerList    : TIPAddrString;
    NodeType         : Integer;
    ScopeId          : Array[0..MAX_SCOPE_ID_LEN+3] of Char;
    EnableRouting    : Integer;
    EnableProxy      : Integer;
    EnableDNS        : Integer;
    );
    1: (A:Array[0..2047] of byte);
  End;

  PIPAdapterInfo = ^TIPAdapterInfo;
  TIPAdapterInfo = Record { IP_ADAPTER_INFO }
    Next                : PIPAdapterInfo;
    ComboIndex          : Integer;
    AdapterName         : Array[0..MAX_ADAPTER_NAME_LENGTH+3] of Char;
    Description         : Array[0..MAX_ADAPTER_DESCRIPTION_LENGTH+3] of Char;
    AddressLength       : Integer;
    Address             : Array[1..MAX_ADAPTER_ADDRESS_LENGTH] of Byte;
    Index               : Integer;
    _Type               : Integer;
    DHCPEnabled         : Integer;
    CurrentIPAddress    : PIPAddrString;
    IPAddressList       : TIPAddrString;
    GatewayList         : TIPAddrString;
    DHCPServer          : TIPAddrString;
    HaveWINS            : Bool;
    PrimaryWINSServer   : TIPAddrString;
    SecondaryWINSServer : TIPAddrString;
    LeaseObtained       : Integer;
    LeaseExpires        : Integer;
  End;



//some support functions:

//get primary IP of each adapter on the system:
function GetAdapters(Strings:TStrings):Boolean;

//calculate IP, TCP and UDP checksums
function IPChecksum(Data:Pointer; Size:Integer):Word;

//Classes that implement protocols on top of raw IP:
type
    TRawIPSocket = class (TBlockSocket)
      public
      procedure CreateSocket;
      function SendBuffer(Buffer: Pointer; Length: Integer): Integer; override;
    end;

    TRawUDPBlockSocket = class (TBlockSocket)
    public
      IPHeader:TIPHeader;
      UDPHeader:TUDPHeader;
      FRemoteSin: TVarSin;
      Data:Array[0..2047] of byte;
      procedure CreateSocket;
      procedure CalcUDPChecksum;
      procedure Connect(IP, Port: string); override;
      procedure SetFrom(IP, Port: string);
      function SendBuffer(Buffer: Pointer; Length: Integer): Integer; override;
    end;

    TSniffingSocket = class (TBlockSocket)
    public
      FAdapterIP:String;
      procedure CreateSocket;
    end;

    TOnPacketSniffed = procedure (Sender:TObject; Data:String) of Object;

    TSnifferThread = class (TThread)
      FData:String;
      FOwner:TObject;
      FSocket:TSniffingSocket;
      procedure SyncPacket;
      procedure Execute; override;
    end;

    TSniffer = class (TComponent) //make it component if you like
    private
      FOnPacket:TOnPacketSniffed;
    protected
      FActive:Boolean;
    public
      FSniffer:TSnifferThread;
      FAdapter:String;
      procedure SetActive(Value:Boolean);
      procedure Loaded; override;
      constructor Create (AOwner: TComponent); override;
      destructor Destroy; override;
    published
      property Adapter:String read FAdapter write FAdapter;
      property Active:Boolean read FActive write SetActive;
      property OnPacketSniffed:TOnPacketSniffed read FOnPacket write FOnPacket;
    end;



    //ip helper interface
    TIPHelperInfo = class (TObject) //make that component if you like
      //After construction, these strings will be created and filled
      //system wide settings:
      HostName         : String;
      DomainName       : String;
      CurrentDNSServer : String;
      DNSServerList    : TStrings;
      NodeType         : Integer;
      ScopeId          : String;
      EnableRouting    : Boolean;
      EnableProxy      : Boolean;
      EnableDNS        : Boolean;
      //Filled per adapter:
      DNSServers:TStrings;
      AdapterIPs:TStrings;
      AdapterNames:TStrings;
      AdapterDescriptions:TStrings;
      AdapterMACs:TStrings;
      DHCPServers:TStrings;
      GateWays:TStrings;
      CurrentIPs:TStrings;
      CurrentMasks:TStrings;
//      PrimaryIPs:TStrings;
//      PrimaryMasks:TStrings;
      //LeaseObtained:TList
      //LeaseExpired:TList
      //multiples filled per adapter
      AllIPS:TStrings;
      AllMasks:TStrings;
      constructor Create;
      destructor Destroy; override;
    end;


//externals:
function GetNetworkParams(FI : PFixedInfo; Var BufLen : Integer) : Integer;
         StdCall; External 'iphlpapi.dll' Name 'GetNetworkParams';

function GetAdaptersInfo(AI : PIPAdapterInfo; Var BufLen : Integer) : Integer;
         StdCall; External 'iphlpapi.dll' Name 'GetAdaptersInfo';

procedure Register;

//////////////////////////////////////////////////////////////////

implementation

//support functions:
function IPChecksum(Data:Pointer; Size:Integer):Word;
var Checksum:DWord;
    D:String;
    i,l:Integer;
begin
  Checksum := 0;
  if size=0 then
    exit;
  l:=Size;
  if l mod 2<>0 then
    inc(l,1);
  SetLength(D,l);
  D[l] := #0;
  move (Data, D[1], Size);
  for i:=1 to (l div 2) do
    begin
      Checksum := Checksum + Word(@D[l*2-1]);
    end;
  Checksum := (Checksum shr 16) + (Checksum and $FFFF);
  Checksum := Checksum + (Checksum shr 16);
  Result := Word(-Checksum-1);
end;


function getAdapters;
var Data:String;
    l:Integer;
    PInfo:PIPAdapterInfo;
    PIP : PIPAddrString;
begin
  //Fill Strings with an array of adapters
  Result := False;
  if (Strings=nil) or not (Strings is TStrings) then
    exit;
  Strings.Clear;
  SetLength (Data, 8192); //arbritrary, increase if you expect loads of adapters.
  PInfo := @Data[1];
  l:=length(Data);
  if 0 <> GetAdaptersInfo (PInfo, l) then
    exit;
  //now PInfo contains list of adapters:
  while (PInfo<>nil) and
        (Integer(PInfo)<=Integer(@Data[Length(Data)])-SizeOf(TIPAdapterInfo)) do
    begin
      PIP := @PInfo^.IPAddressList;
      while PIP<>nil do
        begin
          Strings.Add (PIP^.IPAddress);
          PIP := PIP^.Next;
          Result := True;
        end;
      PInfo := PInfo^.Next;
    end;
end;


constructor TIPHelperInfo.Create;
var Data:String;
    l:Integer;
    PInfo:PIPAdapterInfo;
    PIP : PIPAddrString;
    NWInfo:PFixedInfo;
    M:String;
    i:Integer;

  procedure AddrToStrings (P:PIPAddrString; IP:TStrings; Mask:TStrings);
  begin
    while P<>nil do
      begin
        if Assigned (IP) then IP.Add(P^.IPAddress);
        if Assigned (Mask) then Mask.Add(P^.IPMask);
        P := P^.next;
      end;
  end;

begin
  inherited;
  DNSServerList:=TStringList.Create;
  DNSServers:=TStringList.Create;
  AdapterIPs:=TStringList.Create;
  AdapterNames:=TStringList.Create;
  AdapterDescriptions:=TStringList.Create;
  AdapterMACs:=TStringList.Create;
  DHCPServers:=TStringList.Create;
  GateWays:=TStringList.Create;
  CurrentIPs:=TStringList.Create;
  CurrentMasks:=TStringList.Create;
//  PrimaryIPs:=TStringList.Create;
//  PrimaryMasks:=TStringList.Create;
  //LeaseObtained:TList
  //LeaseExpired:TList
  //multiples filled per adapter
  AllIPS:=TStringList.Create;
  AllMasks:=TStringList.Create;
  //Now fill structures

  //Fill Strings with an array of adapters
  SetLength (Data, 8192); //arbritrary, increase if you expect loads of adapters.
  PInfo := @Data[1];
  l:=length(Data);
  if 0 = GetAdaptersInfo (PInfo, l) then
    //now PInfo contains list of adapters:
    while (PInfo<>nil) and
          (Integer(PInfo)<=Integer(@Data[Length(Data)])-SizeOf(TIPAdapterInfo)) do
      begin
        AdapterNames.Add (PInfo^.AdapterName);
        AdapterDescriptions.Add (PInfo^.Description);
        M:='';
        for i:= 1 to PInfo^.AddressLength do
          M:=M+IntToHex (byte(PInfo^.Address[i]), 2);
        AdapterMacs.Add (M);
        if Assigned (PInfo^.CurrentIPAddress) then
          begin
            CurrentIPs.Add(String(PInfo^.CurrentIPAddress^.IPAddress));
            CurrentMasks.Add(PInfo^.CurrentIPAddress^.IPMask);
          end;
        AddrToStrings (@PInfo^.GatewayList, GateWays, nil);
        AddrToStrings (@PInfo^.DHCPServer, DHCPServers, nil);
        AddrToStrings (@PInfo^.IPAddressList, AllIPs, AllMasks);
        PInfo := PInfo^.Next;
      end;
  //Now fill system-wide settigs:
  NWInfo := @Data[1];
  if 0=GetNetworkParams(NWInfo, l) then
    begin
      Hostname := NWInfo^.HostName;
      DomainName := NWInfo^.DomainName;
      if Assigned (NWInfo^.CurrentDNSServer) then
        CurrentDNSServer := NWInfo^.CurrentDNSServer^.IPAddress;
      AddrToStrings (@NWINfo^.DNSServerList, DNSServers, nil);
      EnableRouting := boolean (NWInfo^.EnableRouting);
      EnableProxy := boolean (NWInfo^.EnableProxy);
      EnableDNS := boolean(NWInfo^.EnableDNS);
      ScopeID := NWInfo^.ScopeId;
      NodeType := NWInfo^.NodeType;
    end;
end;

destructor TIPHelperInfo.Destroy;
begin
  DNSServerList.Free;
  DNSServers.Free;
  AdapterIPs.Free;
  AdapterNames.Free;
  AdapterDescriptions.Free;
  AdapterMACs.Free;
  DHCPServers.Free;
  GateWays.Free;
  CurrentIPs.Free;
  CurrentMasks.Free;
//  PrimaryIPs.Free;
//  PrimaryMasks.Free;
  //LeaseObtained.Free
  //LeaseExpired.Free
  AllIPS.Free;
  AllMasks.Free;
  inherited;
end;

procedure TRawIPSocket.CreateSocket;
var c:Integer;
    Sin:TVarSin;
    i:Integer;
begin
  FSocket := synsock.Socket(AF_INET, SOCK_RAW, IPPROTO_IP);

  c:=1;
  i:=setsockopt(FSocket, 0{SOL_SOCKET}, IP_HDRINCL, @c, sizeof(c));
//  showmessage(inttostr(i));
  inherited CreateSocket;
//  Bind ('0.0.0.0', '0'); //Any
//  FProtocol:=IPPROTO_RAW;
//  SetSin(Sin, '192.168.0.77','0');
//  SockCheck(synsock.Bind(FSocket, @Sin, SizeOfVarSin(Sin)));
end;

function TRawIPSocket.SendBuffer;
var P:PIPTCPHeader;
    l:Integer;
    S:TVarSin;
    Port:String;
    Host:String;
    sai:TVarSin;
begin
  P:=Buffer;
  Port := IntToStr(ntohs(P^.TCP.DestPort));
  Host := PChar(synsock.inet_ntoa(TInAddr(P^.IP.DestIp)));
//  inherited Connect (Host, Port);
  SetSin (sai, Host, Port);
  sai.sin_addr.S_addr := inet_addr(PChar(Host));
//  inherited connect (Host, Port);
//  GetSins;
  l:=Length;
  Result :=
    sendto (FSocket,
            Buffer,
            l,
            0, //flags
            Sai);//, //we need this filled for the kernel to send.
//            SizeOfVarSin(Sai));
end;

procedure TRawUDPBlockSocket.CreateSocket;
var c:Integer;
    Sin:TVarSin;
begin
  FSocket := synsock.Socket(PF_INET, SOCK_RAW, IPPROTO_IP);
  c:=1;
  inherited CreateSocket;
  setsockopt(FSocket, 0{IPPROTO_IP{}{SOL_SOCKET}, IP_HDRINCL, @c, sizeof(c));
  //fill header info
  with IPHeader do
    begin
      Protocol := 17; //UDP
      TTL := 128;
      VerLen := (4 shl 4) or 5;
    end;
end;

procedure TRawUDPBlockSocket.CalcUDPChecksum;
//calc UDP checksum
var checksum:Integer;
    i,l,m:Integer;
begin
  //  see rfc 768;
  //  http://www.faqs.org/rfcs/rfc768.html
  checksum := 0;
  l := ntohs(UDPHeader.Length) - SizeOf(TUDPHeader);  //data length
  m := l div 2; //see if padding is needed
  if (l mod 2)<>0 then
    begin
      Data[l] := 0; //add padding zero
      inc (m);
    end;
  //checksum the data:
  for i:=0 to m-1 do
    Checksum := Checksum - ((Data[i*2] shl 8) + Data[i*2+1])-2;
  //pseudo headers, source+dest:
  for i:= 8 to 9 do
    Checksum := Checksum - IPHeader.Raw[i] -1;
  //pseudo headers: proto + udplength
  Checksum := Checksum - IPHeader.Protocol - UDPHeader.Length -2;
  //take the one's complement:
  Checksum := - Checksum - 1;

  //now make 16 bits from 32 bits:
  while (Checksum shr 16)>0 do
    Checksum := ((Checksum shr 16) and $FFFF) or (Checksum and $FFFF);
  UDPHeader.Checksum := 0; //Checksum; it aint working yet.
end;

procedure TRawUDPBlockSocket.Connect;
type
  pu_long = ^u_long;
var HostEnt:PHostEnt;
begin
  //inherited connect is of no use here, since we deal with raw sockets.
  //fill the IP header structure
  inherited Connect (IP, Port); //fill sins
  if IP = cBroadCast then
    IPHeader.DestIP := INADDR_BROADCAST
  else
    begin
      IPHeader.DestIP := synsock.inet_addr(PChar(IP));
      if IPHeader.DestIP = INADDR_NONE then
        begin
          HostEnt := synsock.GetHostByName(PChar(IP));
          if HostEnt <> nil then
            IPHeader.DestIP := u_long(Pu_long(HostEnt^.h_addr_list^)^);
        end;
    end;
  UDPHeader.DestPort := htons (StrToIntDef (Port, 0));
end;

procedure TRawUDPBlockSocket.SetFrom;
type pu_long = ^ulong;
var HostEnt:PHostEnt;
begin
  if IP = cBroadCast then
    IPHeader.SourceIP := INADDR_BROADCAST
  else
    begin
      IPHeader.SourceIP := synsock.inet_addr(PChar(IP));
      if IPHeader.SourceIP = INADDR_NONE then
        begin
          HostEnt := synsock.GetHostByName(PChar(IP));
          if HostEnt <> nil then
            IPHeader.SourceIP := u_long(Pu_long(HostEnt^.h_addr_list^)^);
        end;
    end;
  UDPHeader.SourcePort := htons(StrToIntDef (Port, 0));
end;


function TRawUDPBlockSocket.SendBuffer;
var P:String; //the actual packet
    d:TSockAddr;
    l:Integer;
begin
  if Length>=high(Data) then
    begin
      Result := -1;
      exit;
    end;
  //set header checksum
  IPHeader.TotalLen := htons(SizeOf(TIPHeader)+SizeOf(TUDPHeader)+Length);
  IPHeader.Identifier := gettickcount mod $FFFF; //0 also allowed, then kernel fills it.
  IPHeader.FragOffsets := $00; //htons(FlagDontFragment);

//  CalcHeaderChecksum; //don't, kernel does this!
  //move data
  move (Buffer^, Data[0], Length);
  //set udp checksum
  UDPHeader.Length := htons(SizeOf(TUDPHeader)+Length);
  CalcUDPChecksum; //you can leave it zero if you like: UDPHeader.Checksum := 0;

  //move to buffer,
  //setlength of total IP packet:
  SetLength (P, SizeOf(TIPHeader)+SizeOf(TUDPHeader)+Length);
  //move IP header:
  move (IPHeader.Raw[0], P[1]{Pointer(P)^}, SizeOf (TIPHeader));
  //move IP data, in this case: UDP header:
  move (UDPHeader.Raw[0], P[1+SizeOf(TIPHeader)], SizeOf (TUDPHeader));
  //move UDP data:
  move (Data[0], P[1+SizeOf(TIPHeader)+SizeOf(TUDPHeader)], Length);
  //send data
  l:=system.Length(P);
//  Connect (IPHeader.DestIP, IPHeader.Port);

  Result :=
    sendto (FSocket,
            @P[1],
            l,
            0, //flags
            FRemoteSin
            );
//            PSockAddr(@FRemoteSin), //we need this filled for the kernel to send.
//            SizeOf(FRemoteSin));
end;


procedure TSniffingSocket.CreateSocket;
var c,d,l:Integer;
    F:TStrings;
    Sin: TVarSin;
begin
  //take your pig:
  FSocket := synsock.Socket (AF_INET, SOCK_RAW, IPPROTO_RAW{IP});
  //FSocket := synsock.Socket(AF_UNSPEC{INET}, SOCK_RAW, IPPROTO_RAW{IP});
// no inherited CreateSocket here.
  c:=1;
  if FAdapterIP = '' then
    begin
      //fetch adapterIP
      //get default (first listed) adapter:
      F:=TStringList.Create;
      if (not GetAdapters(F)) or (F.Count=0) then
        exit; //don't try further, no use without IP.
      FAdapterIP := F[0];
    end;
  SetSin(Sin, FAdapterIP, '0');
//  Sin.sin_family := IPPROTO_RAW; //AF_UNSPEC;
  SockCheck(synsock.Bind(FSocket, Sin{, SizeOfVarSin(Sin)}));
  c := 1;
  setsockopt(FSocket, 0{SOL_SOCKET}, IP_HDRINCL, @c, sizeof(c)); //not necessary
  c := 500000;
  setsockopt(FSocket, SOL_SOCKET, SO_RCVBUF, @c, sizeof(c)); //not necessary
  c:=1;
  d:=0;
  FLastError := WSAIoctl (FSocket, SIO_RCVALL, @c, SizeOf(c), @d, SizeOf(d),@l , nil, nil);
end;

procedure TSnifferThread.SyncPacket;
begin
  try
  if Assigned (TSniffer(FOwner).FOnPacket) then
    TSniffer(FOwner).FOnPacket (FOwner, FData);
  except //build-in safety, stop sniffing if anything fails:
    FOwner := nil;
    Terminate;
  end;
end;

procedure TSnifferThread.Execute;
begin
  FSocket.CreateSocket;
  while not Terminated do
    begin
      if (FSocket.WaitingData>0) and (FSocket.WaitingData<1000000) then
        begin
          SetLength (FData, FSocket.WaitingData);
          SetLength (FData,
                     FSocket.RecvBuffer (@FData[1], length(FData)) );
          if FData<>'' then
            Synchronize (SyncPacket);
        end
      else
        sleep(2);
    end;

end;

constructor TSniffer.Create;
begin
  inherited Create (AOwner);
end;

destructor TSniffer.Destroy;
begin
  Active := False;
  inherited;
end;

procedure TSniffer.Loaded;
begin
  //component loaded, test active
  if FActive then
    begin
      FActive := False;
      SetActive (True);
    end;
end;

procedure TSniffer.SetActive;
var s: TStrings;
    i: Integer;
begin
  if Value = FActive then
    exit;
  if Value and ((FAdapter='') or (FAdapter='0.0.0.0')) then
    begin
      s := TStringList.Create;
      GetAdapters (s);
      for i:=0 to s.count - 1 do
        begin
          if (s[i]<>'') and (s[i]<>'0.0.0.0') then
            begin
              FAdapter := s[i];
              break;
            end;
        end;
      s.Free;
    end;
  if (FAdapter = '') or (FAdapter='0.0.0.0') then
    FActive := False;
  if not ((csDesigning in ComponentState) or
          (csReading in ComponentState)) then
    begin
      if Value then
        begin
          FSniffer := TSnifferThread.Create (True);
          FSniffer.FSocket := TSniffingSocket.Create;
          FSniffer.FSocket.FAdapterIP := FAdapter;
          FSniffer.FOwner := Self;
          FSniffer.Resume;
        end
      else
        begin
          FSniffer.Terminate;
          FSniffer.WaitFor;
          FSniffer.Free;
        end;
    end;
  FActive := Value;
end;


procedure register;
begin
  RegisterComponents('VisualSynapse', [TSniffer]);
end;


end.


{
procedure TRawBlockSocket.CalcHeaderChecksum;
//funny, we don't need it. the kernel does.
var i:Integer;
    checksum:DWord;
begin
  //calc the IP header checksum:
  IPHeader.CheckSum := htons(0); //fill with network zero, since it gets included in packet as well.
  checksum := 0;
  for i:=0 to 9 do
    checksum := checksum + IPHeader.Raw[i];
  //shift and add high bytes:
  checksum := (checksum shr 16) + (checksum and $FFFF);
  //and add optional carry bit:
  inc (checksum, checksum shr 16);
//  checksum := 1+ (not checksum); //complement
  checksum:=DWord(-Integer(checksum));
  IPHeader.CheckSum := htons(Checksum and $FFFF);
end;
}


