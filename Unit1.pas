unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, winsock2, StdCtrls, ComCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    ProgressBar1: TProgressBar;
    GroupBox1: TGroupBox;
    AddressEdit: TEdit;
    GroupBox2: TGroupBox;
    StartPortEdit: TEdit;
    GroupBox3: TGroupBox;
    EndPortEdit: TEdit;
    GroupBox4: TGroupBox;
    DisplayMemo: TRichEdit;
    procedure Button1Click(Sender: TObject);
    function LookupName: TInAddr;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function GetLocalIP: String;
var
WSAData: TWSAData;
HostEnt: PHostEnt;
Buf: array [0..127] of Char;
begin
Result := '';
if WSAStartup(WINSOCK_VERSION, WSAData) = 0 then
  begin
  if GetHostName(@Buf, SizeOf(Buf)) = 0 then
    begin
    HostEnt := GetHostByName(@Buf);
    if HostEnt <> nil then Result := inet_ntoa(PInAddr(HostEnt^.h_addr_list^)^);
    end;
  WSACleanup;
  end;
end;

function TForm1.LookupName: TInAddr;
var
  HostEnt: PHostEnt;
  InAddr: TInAddr;
begin
  if Pos('.', AddressEdit.Text) > 0 then
    InAddr.s_addr := inet_addr(PChar(AddressEdit.Text))
  else
  begin
    HostEnt := gethostbyname(PChar(AddressEdit.Text));
    FillChar(InAddr, SizeOf(InAddr), 0);
    if HostEnt <> nil then
    begin
      with InAddr, HostEnt^ do
      begin
        S_un_b.s_b1 := Byte(h_addr^[0]);
        S_un_b.s_b2 := Byte(h_addr^[1]);
        S_un_b.s_b3 := Byte(h_addr^[2]);
        S_un_b.s_b4 := Byte(h_addr^[3]);
      end;
    end
  end;
  Result := InAddr;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  i, j, s, opt, index: Integer;
  FSocket: array[0..41] of TSOCKET; //������ �������
  busy: array[0..41] of boolean; //������, � ������� ����� ��������� ���������� � ������ ����������� ������
  port: array[0..41] of integer; //������ ����������� ������
  addr: TSockAddr;
  hEvent: THandle; //������ ��� ��������� ������� �������
  fset: TFDset;
  tv: TTimeval;
  tec: PServEnt;
  PName: string;
  GInitData: TWSADATA;
begin
// ������������ ������������ � ����������� �������� ������� ��������� ������������
//� ������������ � ������� ��������� ���� ������������, � � �������� - �������� ����
  ProgressBar1.Max := StrToInt(EndPortEdit.Text);
  ProgressBar1.Min := StrToInt(StartPortEdit.Text);

//������������� WinSock
  WSAStartup(MAKEWORD(2, 0), GInitData);

//��������� � ���������� i �������� ���������� �����
  i := StrToInt(StartPortEdit.Text);

//�������� �������� ���� ��������� addr, ������� ����� ��������������
//��� ������ ������� connect
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := INADDR_ANY;

//������ ��������� � ���, ��� ����� ����� ��������� �����
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('����� �����');

//LookupName - ��� ������� �������� ���� � ��� ���������� ����� � ���� ������� ���������� �������
//��������� ���� ������� � ��������� � ���� ������ ������� ��������� addr
  addr.sin_addr := LookupName;

//������ ��������� � ���, ��� ������ ������������
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('������������...');

//� index ���������� ���������� ������� ����������� �� ���� ���
  index := 40;

//������ ������ ��� ��������� ������� �������
  hEvent := WSACreateEvent();
  while i < StrToInt(EndPortEdit.Text) do
  begin
    Application.ProcessMessages;
  ///���� ��������� ������� busy ���������� �������� false
    for j := 0 to index do
      busy[j] := false;

  //� ���� ����� ����� ���������� ���������� ������� �� ����������
  //���������� j ����� ���������� �� 0 �� ������������� ����������
  //��������� � �������
    for j := 0 to index do
    begin
    //���� j-� ���� �������� �������� ���������� �������������
    //�����, �� �������� ����
      if i > StrToInt(EndPortEdit.Text) then
      begin
        index := j - 1;
        break;
      end;

    //������������� ��������� j-� ����� �� ������� FSocket
      FSocket[j] := socket(AF_INET, SOCK_STREAM, IPPROTO_IP);

    //�������� j-� ����� � ������� ������� � ������� WSAEventSelect
    //1-� �������� - ����������� �����
    //2-� �������� - ������ �������, ������� ��� ������ � ������� WSACreateEvent
    //3-� �������� - ����� ������� �������. ��� � �������� FD_WRITE - ������� ������ � FD_CONNECT - ������� � ���������� ����������
      WSAEventSelect(FSocket[j], hEvent, FD_WRITE + FD_CONNECT);

    //��������� ����, �� ������� ���� ���������� ������� ����������
      addr.sin_port := htons(i);

    //������� �������� �� ��������� ����
      connect(FSocket[j], @addr, sizeof(addr));

    //��� �� ���������� � ���������� ������������ �������.
    //���� ����� �� ������, �� ������� ������������ �����
    //����������� ������ ���������
      Application.ProcessMessages;

    //��������, ���� �� ������.
      if WSAGetLastError() = WSAEINPROGRESS then
      begin
      //���� ������ ���������, �� �������� ���� ����
        closesocket(FSocket[j]);
      //������������ ��������������� ������� � ������� busy � true
      //����� ����� �� ��������� ���� ����, ������ ��� �� �� �����
      //��� ������
        busy[j] := true;
      end;

    //�������� � ������� port, �� ����� ������ ���� �� ������ ������� ������
      port[j] := i;

    //���������� ������� i � ������� � ����������, ����� ���� ������ ������������
    //����� �� ��������� ����� ����� for ��������� ������������ ���������� �����
      i := i + 1;
    end;

  //������� ���������� fset
    FD_Zero(fset);

  //�������� ����������� ������ ������� � ���������� fset
    for j := 0 to index do
    begin
      if busy[j] <> true then
        FD_SET(FSocket[j], fset);
    end;

  //��� �� ���������� � ���������� ������������ �������.
    Application.ProcessMessages;

  //�������� ���������, � ������� ������� ����� �������� ������� �� ������
    tv.tv_sec := 1; //�� ����� ����� 1 �������
    tv.tv_usec := 0;

  //������� ���� ��������� ���� �� ���� ������� �� ������ �� �������
    s := select(1, nil, @fset, nil, @tv);

  //��� �� ���������� � ���������� ������������ �������.
    Application.ProcessMessages;

  //�������� ������, � ������� ����� ����������, ����� �� ������� � ������� FSocket
  //������ ������� �������, � ����� ���.
    for j := 0 to index do
    begin
    //���������, ��� �� ������ ��������������� ���� ��-�� ������
    //���� ��, �� ��� ������ ��� ���������
      if busy[j] then continue;

      if FD_ISSET(FSocket[j], fset) then
      begin
      //� ���������� s ������������� ������ ��������� Opt
        s := Sizeof(Opt);
        opt := 1;
      //������� ��������� �������� j-�� ������
      //��������� ��������� ����� � ���������� opt
        getsockopt(FSocket[j], SOL_SOCKET, SO_ERROR, @opt, s);

      //���� opt ����� 0 �� ���� ������ � � ���� ����� �����������
        if opt = 0 then
        begin
         //������� ������ ���������� ��� �����
          tec := getservbyport(htons(Port[j]), 'TCP');
          if tec = nil then
            PName := 'Unknown'
          else
          begin
            PName := tec.s_name;
          end;
         //������ ��������� �� �������� �����
          DisplayMemo.Lines.Add('����:' + AddressEdit.Text + ': ���� :' + IntToStr(Port[j]) + ' (' + Pname + ') ' + ' ������ ');
        end;
      end;
    //������� j-� �����, ������ ��� �� ������ ��� �� �����
      closesocket(FSocket[j]);
    end;
  //���������� ������� � ProgressBar1
    ProgressBar1.Position := i;
    Application.ProcessMessages;
  end;
//�������� ������ �������
  WSACloseEvent(hEvent);

//������ ��������� � ����� ������������
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('������������ ���������...');
  ProgressBar1.Position := 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  AddressEdit.Text:=GetLocalIP;
end;

end.

