unit unMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,
  IdHTTP, xmldom, XMLIntf, msxmldom, XMLDoc, HTTPApp, HTTPProd, pngimage,
  ExtCtrls, ShellApi, IdAntiFreezeBase, IdAntiFreeze;

type
  TfmMain = class(TForm)
    IdHTTP1: TIdHTTP;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    ControlPanel: TPanel;
    bGetAlbums: TButton;
    Edit1: TEdit;
    Bevel1: TBevel;
    L1: TLabel;
    bStartDownloading: TButton;
    bGetSongs: TButton;
    Label1: TLabel;
    StatusLabel: TLabel;
    IdAntiFreeze1: TIdAntiFreeze;
    procedure bGetAlbumsClick(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure bGetSongsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure bStartDownloadingClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure RL(s: string);
  end;

  TCitePage = class
    Name: string;
    HTMLFile, Hrefs, Titles: TStrings;
    CheckBoxes: array of TCheckBox;
    bSelectAll, bSelectNone: TButton;
    lName: TLabel;
    procedure GetHTMLText(address: string);
    function GetList: boolean; virtual; abstract;
    function PlaceCheckBoxes(sb: TScrollBox; top: integer): integer;
    procedure DeleteCheckboxes;
    constructor Create;
    destructor Destroy;
    procedure bSelectAllClick(Sender: TObject);
    procedure bSelectNoneClick(Sender: TObject);
  end;

  TArtist = class(TCitePage)
    function GetList: boolean; override;
  end;

  TAlbum = class(TCitePage)
    SongsLinks: TStrings;
    function GetList: boolean; override;
    procedure GetSongsLinks;
    procedure DownloadSongs;
    procedure DownloadSong(n: integer);
    constructor Create;
    destructor Destroy;
  end;

var
  Artist: TArtist;
  fmMain: TfmMain;
  Albums: array of TAlbum;

function GetHref(href,s: string): string;
procedure Sort(var sl: TStrings);
function IntToStrEx(int: integer): string;
function GetAlbumPos(a: array of TAlbum; alb: TAlbum): integer;
function ValidateName(n: string): string;
function WrapArtistName(s: string): string;

implementation

{$R *.dfm}

constructor TCitePage.Create;
begin
  inherited;
  HTMLFile:= TStringList.Create;
  Hrefs:= TStringList.Create;
  Titles:= TStringList.Create;
end;

destructor TCitePage.Destroy;
begin
  inherited;
  HTMLFile.Free;
  Hrefs.Free;
  Titles.Free;
end;

procedure TCitePage.GetHTMLText(address: string);
begin
  try
    HTMLFile.Text:= fmMain.IdHTTP1.Get(address);
  except
    Artist.Free;
    ShowMessage('Connection error');
    fmMain.Close;
  end;
end;

function TArtist.GetList: boolean;
var t: string; i,List_pos: integer;
begin
  Result:= true;
  List_pos:= -1;

  Hrefs.Clear;
  Titles.Clear;

  for i:= 0 to HTMLFile.Count - 1 do begin
    t:= WrapArtistName(HTMLFile.Strings[i]);
    if t<>'' then name:= t;

    if Pos('<div class="cntAlbumList">',HTMLFile.Strings[i])<>0 then begin
      List_pos:= i;
      Break;
    end;
  end;

  if List_pos=-1 then begin
    ShowMessage('Parsing error: cant find list of albums');
    Result:= false;
    Exit;
  end else begin
    i:= List_pos;
    repeat begin
      inc(i);
      t:= GetHref('href',HTMLFile.Strings[i]);
      if t<>'' then Hrefs.Add('http://musicmp3.spb.ru'+t);
      t:= GetHref('alt',HTMLFile.Strings[i]);
      Delete(t,1,6);
      if t<>'' then  Titles.Add(t);
    end;
    until (HTMLFile.Strings[i]='</div>');
  end;

  Sort(Hrefs);
  Sort(Titles);
end;

function TAlbum.GetList: boolean;
var t: string; i,List_pos: integer;
begin
  Result:= true;
  List_pos:= -1;

  Hrefs.Clear;
  Titles.Clear;

  for i:= 0 to HTMLFile.Count - 1 do
    if Pos('<div class="albSong">',HTMLFile.Strings[i])<>0 then begin
      List_pos:= i;
      Break;
    end;

  if List_pos=-1 then begin
    ShowMessage('Parsing error: cant find songs list');
    Result:= false;
    Exit;
  end else begin
    i:= List_pos;
    repeat begin
      inc(i);
      t:= GetHref('href',HTMLFile.Strings[i]);

      if t<>'' then if t[2]='d' then Hrefs.Add('http://musicmp3.spb.ru'+t);
      t:= GetHref('alt',HTMLFile.Strings[i]);
      t:= Copy(t,7,Length(t)-17);
      //Delete(t,1,5);
      if t<>'' then Titles.Add(IntToStrEx(Titles.Count+1)+'-'+t);
    end;
    until (HTMLFile.Strings[i]='</div>');
  end;

end;

function TCitePage.PlaceCheckBoxes(sb: TScrollBox; top: integer): integer;
var i,t: integer;
begin
  t:= top;
  lName:= TLabel.Create(sb);
  with lName do begin
    Parent:= sb;
    Left:= 10;
    Top:= t;
    Caption:= self.Name;
    Font.Style:= [fsBold];
    Font.Size:= 10;
  end;

  t:= t + lName.Height + 10;

  bSelectAll:= TButton.Create(sb);
  with bSelectAll do begin
    Parent:= sb;
    Left:= 10;
    Top:= t;
    Caption:= 'Select all';
    OnClick:= bSelectAllClick;
    Font.Size:= 10;
  end;

  bSelectNone:= TButton.Create(sb);
  with bSelectNone do begin
    Parent:= sb;
    Top:= t;
    Left:= bselectAll.Left + bselectAll.Width + 10;
    Caption:= 'Select none';
    OnClick:= bSelectNoneClick;
    Font.Size:= 10;
  end;

  t:= t + bSelectAll.Height + 10;

  SetLength(CheckBoxes,Titles.Count);
  for i:= 0 to Length(CheckBoxes)-1 do begin
    CheckBoxes[i]:= TCheckBox.Create(sb);
    with CheckBoxes[i] do begin
      Parent:= sb;
      Caption:= Titles[i];
      Font.Size:= 10;
      Width:= sb.ClientWidth - 10;
      Height:= 15;
      Left:= 10;
      Checked:= true;
      Top:= t;
      t:= t + Height + 10;
    end;
  end;
  Result:= t;
end;

procedure TCitePage.DeleteCheckboxes;
var i: integer;
begin
  for i:= 0 to Length(CheckBoxes)-1 do CheckBoxes[i].Free;
  lName.Free;
  bSelectAll.Free;
  bSelectNone.Free;
end;

procedure TCitePage.bSelectAllClick(Sender: TObject);
var i: integer;
begin
  for i:= 0 to Length(CheckBoxes)-1 do CheckBoxes[i].Checked:= true;
end;

procedure TCitePage.bSelectNoneClick(Sender: TObject);
var i: integer;
begin
  for i:= 0 to Length(CheckBoxes)-1 do CheckBoxes[i].Checked:= false;
end;

constructor TAlbum.Create;
begin
  inherited;
  SongsLinks:= TStringList.Create;
end;

destructor TAlbum.Destroy;
begin
  inherited;
  SongsLinks.Free;
end;

procedure TAlbum.GetSongsLinks;
var k,i: integer; address,robotcode: string; Params: TStrings;
begin
  SongsLinks.Clear;
  for k:= 0 to hrefs.Count-1 do begin
    fmMain.RL('Getting songs links of album '+IntToStr(GetAlbumPos(Albums,self)+1)+' of '+IntToStr(Length(Albums))+
      ', song '+IntToStr(k+1)+' of '+IntToStr(hrefs.Count)+'...');
    address:= '';
    HTMLFile.Text:= fmMain.IdHTTP1.Get(Hrefs[k]);
    with HTMLFile do
      for i:= 0 to Count do
        if (Strings[i]='</table>') and (Strings[i+1][2]='f') then begin
          address:= 'http://tempfile.ru' + GetHref('action',Strings[i+1]);
          robotcode:= GetHref('name',Strings[i+3]) + '=' + GetHref('value',Strings[i+3]);
          Break;
    end;
    Params:= TStringList.Create;
    Params.Clear;
    Params.Add(RobotCode);
    HTMLFile.Clear;
    HTMLFile.Text:= fmMain.IdHTTP1.Post(address,Params);
    with HTMLFile do
      for i:= 0 to Count do
        if (Strings[i]='<h2>Скачать файл можно по этой ссылке:</h2>') then begin
          SongsLinks.Add(GetHref('href',Strings[i+1]));
          Break;
    end;
    Params.Free;
  end;
end;

procedure TAlbum.DownloadSongs;
var i: integer; nonechecked: boolean; dirname: string;
begin
  nonechecked:= true;
  for i:= 0 to Length(CheckBoxes)-1 do
    if Checkboxes[i].checked then nonechecked:= false;

  if not nonechecked then begin
    dirname:= ValidateName(Artist.Name)+'-'+ValidateName(name);
    if not DirectoryExists(dirname) then
      if not CreateDir(dirname) then begin
        ShowMessage('Can''t create directory'+dirname);
        Exit;
      end;
    for i:= 0 to Length(CheckBoxes)-1 do
      if Checkboxes[i].checked then DownloadSong(i);
  end;
end;

procedure TAlbum.DownloadSong(n: integer);
var FileStream :TFileStream; filename: string;
begin
  fmMain.RL('Downloading '+ Titles[n] + '...');
  filename:= ValidateName(Artist.Name)+'-'+ValidateName(Name)+'\'+ValidateName(Titles[n])+'.mp3';
  FileStream := TFileStream.Create(filename, fmCreate);
  fmMain.IdHTTP1.Get(SongsLinks[n], FileStream);
  FileStream.Free;
end;

procedure TfmMain.bGetAlbumsClick(Sender: TObject);
var success: boolean;
begin
  if Artist<>nil then begin
    if Length(Artist.CheckBoxes)<>0 then Artist.DeleteCheckboxes;
    Artist.Free;
  end;

  RL('Getting albums list...');
  Cursor:= crHourGlass;
  Enabled:= false;

  Artist:= TArtist.Create;

  with Artist do begin
    GetHTMLText(Edit1.Text);
    success:= GetList;
    if success then PlaceCheckBoxes(ScrollBox1,10);
  end;

  RL('Albums list recieved.');
  Enabled:= true;
  Cursor:= crDefault;

  if success then begin
    RL('Albums list recieved.');
    bGetSongs.Enabled:= true;
  end else begin
    RL('Albums list not recieved.');
    Artist.Free;
    Artist:= nil;
  end;
end;

procedure TfmMain.bGetSongsClick(Sender: TObject);
var i: integer; checkedcount,t: integer;
begin
  checkedcount:= 0;
  for i:= 0 to Length(Artist.CheckBoxes)-1 do
    if Artist.CheckBoxes[i].Checked then inc(checkedcount);
  if checkedcount=0 then begin
    ShowMessage('You must select at least one album!');
    Exit;
  end;

  bGetAlbums.Enabled:= false;
  bGetSongs.Enabled:= false;

  RL('Getting songs list...');
  Cursor:= crHourGlass;
  Enabled:= false;

  SetLength(Albums,Checkedcount);

  checkedcount:= 0;
  for i:= 0 to Length(Artist.CheckBoxes)-1 do begin
    if Artist.CheckBoxes[i].Checked then begin
      Albums[checkedcount]:= TAlbum.Create;
      Albums[checkedcount].Name:= Trim(Artist.Titles[i]);
      Albums[checkedcount].GetHTMLText(Artist.Hrefs[i]);
      Albums[checkedcount].GetList;
      inc(checkedcount);
    end;
  end;

  Artist.DeleteCheckboxes;

  t:= 10;
  for i:= 0 to Length(Albums)-1 do begin
    t:= Albums[i].PlaceCheckBoxes(ScrollBox1,t) + 20;
    Albums[i].GetSongsLinks;
  end;

  RL('Songs list recieved.');
  Enabled:= true;
  Cursor:= crDefault;
  bStartDownLoading.Enabled:= true;
end;

procedure TfmMain.bStartDownloadingClick(Sender: TObject);
var i: integer;
begin
  bStartDownloading.Enabled:= false;
  for i:= 0 to Length(Albums) - 1 do Albums[i].DownloadSongs;
  RL('Downloading finished.');
end;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  try
    IdHTTP1.Get('http://musicmp3.spb.ru');
  except
    ShowMessage('Connection error');
    Close;
  end;

  ShowMessage('HOW TO WORK WITH THIS PROGRAM:'+#13#10+
    '1. Сopy the link to the artist page in the input field below'+#13#10+
    '2. Press "Get Albums List"'+#13#10+
    '3. Select desired albums and press "Get Songs List"'+#13#10+
    '4. Select desired songs and press "Start Downloading"'+#13#10+
    '5. Music will be downloaded in the same folder with the exe file'+#13#10+
    'NOTE: Watch the status label at the bottom.');

  Artist:= nil;
  RL('');
end;

procedure TfmMain.Label1Click(Sender: TObject);
begin
  ShellExecute(Handle,'open', 'http://musicmp3.spb.ru', nil, nil, SW_SHOWNORMAL);
end;

procedure TfmMain.RL(s: string);
begin
  StatusLabel.Caption:= s;
end;

function GetHref(href,s: string): string;
var p: integer;
begin
  p:= pos(href,s);
  if (p=0) or (s[Length(href)+p]<>'=') then begin Result:=''; Exit; end else
  begin
    Delete(s,1,p+Length(href)+1);
    p:= pos('"',s);
    Delete(s,p,Length(s)-p+1);
  end;
  Result:= s;    
end;

procedure Sort(var sl: TStrings);
var sl2: TStrings; i: integer;
begin
  sl2:= TStringList.Create;

  i:= sl.Count - 1;
  while (i<>-1) do begin
    if sl[i]<>'' then sl2.Add(sl[i]);
    dec(i);
  end;
  sl.Assign(sl2);

  sl2.Free;
end;

function IntToStrEx(int: integer): string;
var zerostring: string;
begin
  if int div 10 = 0 then zerostring:='0' else zerostring:='';
  Result:= zerostring+IntToStr(int);
end;

function GetAlbumPos(a: array of TAlbum; alb: TAlbum): integer;
var i: integer;
begin
  Result:= -1;
  for i:= 0 to Length(a) - 1 do if a[i]=alb then begin Result:= i; Break end;
end;

function ValidateName(n: string): string;
var banned, res: string; i,j: integer;
begin
  res:= n;
  banned:= '\/:*?"<>|';
  for i:= 1 to Length(res) do
    for j:= 1 to Length(banned) do
      if res[i]=banned[j] then res[i]:=' ';
  Result:= res;
end;

function WrapArtistName(s: string): string;
var pos_start, pos_end: integer;
begin
  pos_start:= Pos('<title>',s);
  Pos_end:= Pos('mp3.',s);
  if (pos_start=0) or (Pos_end=0) or (pos_start>=pos_end)
    then begin Result:= ''; Exit; end;
  Result:= Trim(Copy(s,pos_start+7,pos_end-pos_start-7));
end;

end.
