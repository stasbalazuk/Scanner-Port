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
  FSocket: array[0..41] of TSOCKET; //Массив сокетов
  busy: array[0..41] of boolean; //Массив, в котором будет храниться информация о каждом сканируемом сокете
  port: array[0..41] of integer; //Массив сканируемых портов
  addr: TSockAddr;
  hEvent: THandle; //Объект для обработки сетевых событий
  fset: TFDset;
  tv: TTimeval;
  tec: PServEnt;
  PName: string;
  GInitData: TWSADATA;
begin
// Устанавливаю максимальное и минимальное значение полоски состояния сканирования
//Я устанавливаю в минимум начальный порт сканирования, а в максимум - конечный порт
  ProgressBar1.Max := StrToInt(EndPortEdit.Text);
  ProgressBar1.Min := StrToInt(StartPortEdit.Text);

//Инициализирую WinSock
  WSAStartup(MAKEWORD(2, 0), GInitData);

//Записываю в переменную i значение начального порта
  i := StrToInt(StartPortEdit.Text);

//Заполняю основные поля структуры addr, которая будет использоваться
//при вызове функции connect
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := INADDR_ANY;

//Вывожу сообщение о том, что начат поиск введённого хоста
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('Поиск хоста');

//LookupName - эта функция написана выше и она возвращяет адрес в спец формате указанного сервера
//Результат этой функции я записываю в поле адреса сервера структуры addr
  addr.sin_addr := LookupName;

//Вывожу сообщение о том, что начато сканирование
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('Сканирование...');

//В index находиться количество сокетов проверяемых за один раз
  index := 40;

//Создаю объект для обработки сетевых событий
  hEvent := WSACreateEvent();
  while i < StrToInt(EndPortEdit.Text) do
  begin
    Application.ProcessMessages;
  ///Всем элементам массива busy присваиваю значение false
    for j := 0 to index do
      busy[j] := false;

  //В этом цикле будут асинхронно посылаться запросы на моединение
  //переменная j будет изменяться от 0 до максимального количества
  //элементов в массиве
    for j := 0 to index do
    begin
    //Если j-й порт превысил значение указанного максимального
    //порта, то прервать цикл
      if i > StrToInt(EndPortEdit.Text) then
      begin
        index := j - 1;
        break;
      end;

    //Инициализирую очередной j-й сокет из массива FSocket
      FSocket[j] := socket(AF_INET, SOCK_STREAM, IPPROTO_IP);

    //Добавляю j-й сокет к объекту событий с помощью WSAEventSelect
    //1-й параметр - Добавляемый сокет
    //2-й параметр - объект событий, который был создан с помощью WSACreateEvent
    //3-й параметр - какие события ожидать. Тут я указываю FD_WRITE - события записи и FD_CONNECT - события о заключении соединения
      WSAEventSelect(FSocket[j], hEvent, FD_WRITE + FD_CONNECT);

    //Указываем порт, на который надо произвести попытку соединения
      addr.sin_port := htons(i);

    //Попытка коннекта на очередной порт
      connect(FSocket[j], @addr, sizeof(addr));

    //Даём ОС поработать и обработать накопившиеся события.
    //Если этого не делать, то вовремя сканирования будет
    //происходить эффект зависания
      Application.ProcessMessages;

    //Проверяю, были ли ошибки.
      if WSAGetLastError() = WSAEINPROGRESS then
      begin
      //Если ошибка произошла, то закрываю этот порт
        closesocket(FSocket[j]);
      //Устанавливаю соответствующий элемент в массиве busy в true
      //чтобы потом не проверять этот порт, потому что он всё равно
      //уже закрыт
        busy[j] := true;
      end;

    //Указываю в массиве port, на какой именно порт мы сейчас послали запрос
      port[j] := i;

    //Увеличиваю счётчик i в котором я отслеживаю, какой порт сейчас сканируеться
    //чтобы на следующем этапе цикла for запустить сканирование следующего порта
      i := i + 1;
    end;

  //Обнуляю переменную fset
    FD_Zero(fset);

  //Заполняю сканируемый массив сокетов в переменную fset
    for j := 0 to index do
    begin
      if busy[j] <> true then
        FD_SET(FSocket[j], fset);
    end;

  //Даём ОС поработать и обработать накопившиеся события.
    Application.ProcessMessages;

  //Заполняю структуру, в которой указано время ожидания события от сокета
    tv.tv_sec := 1; //Мы будем ждать 1 секунду
    tv.tv_usec := 0;

  //Ожидаем пока произойдёт хотя бы одно событие от любого из сокетов
    s := select(1, nil, @fset, nil, @tv);

  //Даём ОС поработать и обработать накопившиеся события.
    Application.ProcessMessages;

  //Запускаю массив, в котором будет проверятся, какие из сокетов в массиве FSocket
  //прошли коннект успешно, а какие нет.
    for j := 0 to index do
    begin
    //Проверяем, был ли закрыт соответствующий порт из-за ошибки
    //Если да, то нет смысла его проверять
      if busy[j] then continue;

      if FD_ISSET(FSocket[j], fset) then
      begin
      //В переменную s записываеться размер перменной Opt
        s := Sizeof(Opt);
        opt := 1;
      //Получаю состояние текущего j-го сокета
      //результат состояния будет в переменной opt
        getsockopt(FSocket[j], SOL_SOCKET, SO_ERROR, @opt, s);

      //Если opt равно 0 то порт открыт и к нему можно подключится
        if opt = 0 then
        begin
         //Пытаюсь узнать символьное имя порта
          tec := getservbyport(htons(Port[j]), 'TCP');
          if tec = nil then
            PName := 'Unknown'
          else
          begin
            PName := tec.s_name;
          end;
         //Вывожу сообщение об открытом порте
          DisplayMemo.Lines.Add('Хост:' + AddressEdit.Text + ': порт :' + IntToStr(Port[j]) + ' (' + Pname + ') ' + ' открыт ');
        end;
      end;
    //Закрыть j-й сокет, потому что он больше уже не нужен
      closesocket(FSocket[j]);
    end;
  //Увеличивею позицию в ProgressBar1
    ProgressBar1.Position := i;
    Application.ProcessMessages;
  end;
//Закрываю объект событий
  WSACloseEvent(hEvent);

//Вывожу сообщение о конце сканирования
  DisplayMemo.SelAttributes.Color := clTeal;
  DisplayMemo.SelAttributes.Style := DisplayMemo.SelAttributes.Style + [fsBold];
  DisplayMemo.Lines.Add('Сканирование закончено...');
  ProgressBar1.Position := 0;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  AddressEdit.Text:=GetLocalIP;
end;

end.

