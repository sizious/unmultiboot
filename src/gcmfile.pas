unit gcmfile;

interface

uses
  SysUtils, Types, Classes, StrUtils, Math;

const
  DISC_HEADER_SIZE : DWord = $0440;
  DISC_HEADER_INFO_SIZE : DWord = $2000;
  MULTIBOOT_ID : string = 'COBRAMB1';

type
  TFstStruct = packed record
    Files       : Integer;
    Folders     : Integer;
    HeaderSize  : DWord;
    TotalSize   : DWord;
  end;
  
  PGcmInfo = ^TGcmInfo;
  TGcmInfo = packed record
    ID              : Integer;
    StartOfGcm      : DWord;
    Title           : string;
    DolSize         : DWord;
    Contents        : TFstStruct;
    AppLoaderSize   : DWord;
    FstSize         : DWord;
    HeaderTotalSize : DWord;
    TotalGcmSize    : Int64;
  end;


  TGcmFile = class
  private
    fGcmFileName : file;
    fGcmInfo : TList;
    fFileName : string;
    function BigEndian(LittleIndian: DWord): DWord;
    function ReadTitle(StartOfGcm : DWord) : string;
    function GetBootDolSize(StartOfGcm : DWord) : Integer;
    function GetRealSizeFromFst(StartOfGcm: DWord): TFstStruct;
    function GetFstSize(StartOfGcm: DWord): DWord;
    function GetApploaderSize(StartOfGcm : DWord) : DWord;
    procedure ReadHeaderSeek(StartOfGcm, HeaderLocation: DWord);
    function GetGcmHeaderSize(StartOfGcm : DWord) : DWord;
    function GetFileNameStr(FstFileOffset : DWord) : string;
    function NameStrOffsetToDWord(var NameStrOffset: array of Byte): DWord;
    function GetAsciiTableStart(StartOfGcm, FstOffsetStart: DWord): DWord;
    function AlignSize(Size: DWord): DWord;
  public
    constructor Create(FileName : string);
    destructor Destroy; override;
    function GetToc : TList;
    function IsValidMultiBootImage : boolean;
    procedure CreateDump(GcmInfo : TGcmInfo ; OutputFile: TFileName);
    procedure PrintInfos(GCMInfo : TGCMInfo);
  end;

implementation

uses
  Utils;
  
{ TGcmFile }

//------------------------------------------------------------------------------

constructor TGcmFile.Create(FileName: string);
begin
  fFileName := FileName;
  fGcmInfo := TList.Create;

  AssignFile(fGcmFileName, fFileName);
  FileMode := fmOpenRead;
  Reset(fGcmFileName, 1);
end;

//------------------------------------------------------------------------------

function TGcmFile.BigEndian(LittleIndian : DWord) : DWord;
var
  Buf, CurrByte : string;
  tmp : array[1..8] of string;
  i : integer;

begin
  Buf := IntToHex(LittleIndian, 8);

  //11248000 <- ce que je dois obtenir
  //00802411 <- ce que je dois traduire
  i := 1;
  while i <= 8 do
  begin
    CurrByte := Buf[i] + Buf[i+1];
    tmp[8 - i] := CurrByte;
    Inc(i, 2);
  end;

  Buf := '';
  for i := low(tmp) to high(tmp) do
    Buf := Buf + tmp[i];

  Result := StrToInt('$' + Buf);
end;

//------------------------------------------------------------------------------

function TGcmFile.GetToc : TList;
var
  EndToc : Boolean;
  Ptr : Integer;
  BufRead : DWord;
  Struct : PGcmInfo;
  _fst_struct : TFstStruct;
  StartOfGcm : DWord;

begin
  EndToc := False;

  Ptr := $40;
  while not EndToc do
  begin
    Seek(fGcmFileName, Ptr);
    BlockRead(fGcmFileName, BufRead, SizeOf(BufRead));

    if BufRead = 0 then
      EndToc := True
    else begin
      New(Struct);

      StartOfGcm := BigEndian(BufRead);
      _fst_struct := GetRealSizeFromFst(StartOfGcm);

      Struct^.ID := fGcmInfo.Count + 1; //elimine le 0
      Struct^.Title := ReadTitle(StartOfGcm);
      Struct^.StartOfGcm := StartOfGcm;
      Struct^.DolSize := GetBootDolSize(StartOfGcm);
      Struct^.Contents.Files := _fst_struct.Files;
      Struct^.Contents.Folders := _fst_struct.Folders;
      Struct^.Contents.HeaderSize := _fst_struct.HeaderSize;
      Struct^.AppLoaderSize := GetApploaderSize(StartOfGcm);
      Struct^.FstSize := GetFstSize(StartOfGcm);
      Struct^.HeaderTotalSize := GetGcmHeaderSize(StartOfGcm);
      Struct^.TotalGcmSize := _fst_struct.TotalSize;

      fGcmInfo.Add(Pointer(Struct));
    end;

    Ptr := Ptr + 4;
  end;

  Result := fGcmInfo;
end;

//------------------------------------------------------------------------------

destructor TGcmFile.Destroy;
var
  i : Integer;

begin
  for i := 0 to fGcmInfo.Count - 1 do
    Dispose(fGcmInfo[i]);
    
  fGcmInfo.Free;

  CloseFile(fGcmFileName);
  
  inherited;
end;

//------------------------------------------------------------------------------

function TGcmFile.IsValidMultiBootImage: boolean;
var
  Buf : array[1..8] of Byte;
  i : integer;
  
begin
  Result := True;
  
  Seek(fGcmFileName, 0);

  BlockRead(fGcmFileName, Buf, SizeOf(Buf));

  for i := Low(Buf) to High(Buf) do
    if MULTIBOOT_ID[i] <> Chr(Buf[i]) then
    begin
      Result := False;
      Break;
    end;
end;

//------------------------------------------------------------------------------

function TGcmFile.ReadTitle(StartOfGcm: DWord): string;
var
  title : array[0..64] of Byte;
  i : Integer;
  
begin
  Seek(fGcmFileName, StartOfGcm + 32);

  BlockRead(fGcmFileName, title, SizeOf(title));

  i := 0;
  Result := '';
  while not (title[i] = $0) do
  begin
    Result := Result + Chr(title[i]);
    //write('|', chr(title[i]));
    Inc(i);
  end;
end;

//------------------------------------------------------------------------------

procedure TGcmFile.CreateDump(GcmInfo : TGcmInfo ; OutputFile: TFileName);
var
  fDest : file;
  NumRead, NumWritten : Integer;
  Buf : array[1..65536] of Byte;
  Current : Int64;
  CX, CY : Integer;
  output : string;

begin
  Seek(fGcmFileName, GcmInfo.StartOfGcm);
  
  AssignFile(fDest, OutputFile);
  ReWrite(fDest, 1);

  Current := 0;
  GetCursorPosition(CX, CY);
  output := ExtractFileName(OutputFile);

  repeat
    BlockRead(fGcmFileName, Buf, SizeOf(Buf), NumRead);
    BlockWrite(fDest, Buf, NumRead, NumWritten);

    Current := Current + NumWritten;
    GotoXY(CX, CY);
    Write('Dumping to "');
    SetColor(VERT_PALE, NOIR);
    Write(output);
    SetColor(GRIS_PALE, NOIR);
    Write('"... [');
    SetColor(ROUGE_PALE, NOIR);
    Write(Current, '/', GcmInfo.TotalGcmSize);
    SetColor(GRIS_PALE, NOIR);
    Write('] - ');
    SetColor(MAGENTA_PALE, NOIR);
    WriteLn((Current * 100) div GcmInfo.TotalGcmSize, '%');
    SetColor(GRIS_PALE, NOIR);

  until (NumRead = 0) or (NumWritten <> NumRead) or (FilePos(fDest) >= GcmInfo.TotalGcmSize);

  Seek(fDest, GcmInfo.TotalGcmSize);
  Truncate(fDest); //corriger la taille

  Write('Dumping to "');
  SetColor(VERT_PALE, NOIR);
  Write(output);
  SetColor(GRIS_PALE, NOIR);
  WriteLn('" done !');

  CloseFile(fDest);
end;

//------------------------------------------------------------------------------

procedure TGcmFile.ReadHeaderSeek(StartOfGcm, HeaderLocation : DWord);
var
  Offset : DWord;

begin
  Seek(fGcmFileName, StartOfGcm + HeaderLocation); //location du DOL.
  BlockRead(fGcmFileName, Offset, SizeOf(Offset));
  Offset := StartOfGcm + BigEndian(Offset); //tenir du compte du fait qu'il faut partir du début du GCM !!!
  Seek(fGcmFileName, Offset);
end;

//------------------------------------------------------------------------------

function TGcmFile.GetBootDolSize(StartOfGcm: DWord): Integer;
const
  header = $100;

type
  TDolHeader = record
    t_sections_file_pos : array[0..6] of DWord;
    d_sections_file_pos : array[0..10] of DWord;
    t_sections_mem_addr : array[0..6] of DWord;
    d_sections_mem_addr : array[0..10] of DWord;
    t_sections_size     : array[0..6] of DWord;
    d_sections_size     : array[0..10] of DWord;
  end;

var
  i, t_size, d_size : DWord;
  Buf : TDolHeader;

begin
  ReadHeaderSeek(StartOfGcm, $0420);
  
  BlockRead(fGcmFileName, Buf, SizeOf(Buf));

  t_size := 0;
  d_size := 0;
  
  for i := 0 to 6 do
    t_size := t_size + BigEndian(buf.t_sections_size[i]);

  for i := 0 to 10 do
    d_size := d_size + BigEndian(buf.d_sections_size[i]);

  Result := t_size + d_size + header;
end;

//------------------------------------------------------------------------------

function TGcmFile.GetFstSize(StartOfGcm : DWord) : DWord;
begin
  //ReadHeaderSeek(StartOfGcm, $0428);
  Seek(fGcmFileName, StartOfGcm + $0428);
  BlockRead(fGcmFileName, Result, SizeOf(Result));
  Result := BigEndian(Result);
end;

//------------------------------------------------------------------------------

function TGcmFile.GetFileNameStr(FstFileOffset : DWord) : string;
var
  c : Char;
  _old_pos : DWord;

begin
  _old_pos := FilePos(fGcmFileName);
  Seek(fGcmFileName, FstFileOffset); //StartOfGcm a déjà été pris en compte !!!

  Result := '';
  repeat
    BlockRead(fGcmFileName, c, SizeOf(Char));
    if (c <> #0) then
      Result := Result + c;
  until c = #0;

  Seek(fGcmFileName, _old_pos);
end;

//------------------------------------------------------------------------------

function TGcmFile.NameStrOffsetToDWord(var NameStrOffset : array of Byte) : DWord;
var
  i   : integer;
  s : string;

begin
  for i := Low(NameStrOffset) to High(NameStrOffset) do
    s := s + IntToHex(NameStrOffset[i], 2);

  Result := DWord(StrToInt('$' + s));
end;

//------------------------------------------------------------------------------

function TGcmFile.GetAsciiTableStart(StartOfGcm, FstOffsetStart : DWord) : DWord;
var
  AsciiStart : DWord;

begin
  Seek(fGcmFileName, (StartOfGcm + FstOffsetStart) + $08); //num_entries (root)
  BlockRead(fGcmFileName, AsciiStart, SizeOf(AsciiStart));
  Result := (StartOfGcm + FstOffsetStart) + (BigEndian(AsciiStart) * $0C); //C = 12
  //ici on va calculer combien prend de place num_entries * 12 octets, pour trouver le début
  //de la taille ASCII.
end;

//------------------------------------------------------------------------------

function TGcmFile.AlignSize(Size : DWord) : DWord;
begin
  Result := Size;
  
  //on aligne sur 4 octets (pour avoir un multiple de 4)
  if (Size mod 4) <> 0 then
    Result := ((Size div 4)+1)*4;
end;

//------------------------------------------------------------------------------

function TGcmFile.GetRealSizeFromFst(StartOfGcm : DWord) : TFstStruct;
type
  TFileEntry = record
    EntryType : Byte;
    NameStrOffset : array[0..2] of Byte;
    FileOffset : DWord;
    FileSize : DWord;
  end;

var
  Entry : TFileEntry;
  Files, Dirs : Integer;
  Cursor, Size, CurrSize, CurrSizeAsciiOffset, _swap : DWord;
  FstStart,
  FstSize,
  FstAsciiStart : DWord;
  CurrFileName : string;

begin
//  Size := 0;
  Files := 0;
  Dirs := 0;
  Cursor := 0;
  FstSize := GetFstSize(StartOfGcm);  //fait un seek !!

  //ReadHeaderSeek(StartOfGcm, $0424);  //attention cette fonction fait un seek !!
  Seek(fGcmFileName, StartOfGcm + $0424);
  BlockRead(fGcmFileName, FstStart, SizeOf(FstStart));
  FstStart := BigEndian(FstStart);
  FstAsciiStart := GetAsciiTableStart(StartOfGcm, FstStart);
  //FstStart := FstStart + StartOfGcm;

  ReadHeaderSeek(StartOfGcm, $0424);

  Size := FstStart + FstSize;

  while (Cursor < FstSize) do begin
    try
      BlockRead(fGcmFileName, Entry, SizeOf(Entry));

      case entry.EntryType of
        0 : begin
              Inc(Files);

              CurrSize := Entry.FileSize;
              CurrSizeAsciiOffset := NameStrOffsetToDWord(Entry.NameStrOffset);
              CurrSizeAsciiOffset := CurrSizeAsciiOffset + FstAsciiStart;
              CurrFileName := GetFileNameStr(CurrSizeAsciiOffset);
              //WriteLn(CurrFileName);

              //if (UpperCase(RightStr(CurrFileName,4))='.ADP') then
              //begin  writeln('ok'); readln;
              //end;

              { On prend en compte que la taille des fichiers. Il semblerait que ça soit normal.
                pourtant, les dossiers ont vraiment une taille. Mais dans GCMUtility c'est comme ça
                alors je fais pareil. }

              _swap := Size;

              //on aligne sur 4 octets (pour avoir un multiple de 4)
              _swap := AlignSize(_swap);
              
              //traitement spécial si le fichier en cours est un ADP ou un PCM
              if (UpperCase(RightStr(CurrFileName,4))='.ADP') or (UpperCase(RightStr(CurrFileName,4))='.PCM') then
                if (_swap mod 32768) <> 0 then
                  _swap := ((_swap div 32768)+1)*32768;

              Size := _swap;
              Size := Size + BigEndian(CurrSize);
            end;
            
        1 : Inc(Dirs);
        else break; //on est dans la table des strings
      end;

      Inc(Cursor, SizeOf(Entry));
    except
      //rien
    end;
  end;

  Result.TotalSize := Size;
  Result.Files := Files;
  Result.Folders := Dirs;
end;

//------------------------------------------------------------------------------

function TGcmFile.GetApploaderSize(StartOfGcm: DWord): DWord;
var
  Buf : DWord;

begin
  Seek(fGcmFileName, StartOfGcm + $2440 + $14);   //positionnement Apploader (size of the apploader)
  BlockRead(fGcmFileName, Result, SizeOf(Result)); //lecture valeur "size of the apploader"
  BlockRead(fGcmFileName, Buf, SizeOf(Buf));  //4 octets plus loin : "trailer size"
  Result := BigEndian(Result + Buf);  //on fait la somme en BigEndian
end;

//------------------------------------------------------------------------------

function TGcmFile.GetGcmHeaderSize(StartOfGcm: DWord): DWord;
var
  FstSize : DWord;
  
begin
  FstSize := GetFstSize(StartOfGcm);  //fait un seek !!
  ReadHeaderSeek(StartOfGcm, $0424);  //attention cette fonction fait un seek !!
  Result := (FstSize + DWord(FilePos(fGcmFileName))) - StartOfGcm;
end;

//------------------------------------------------------------------------------

procedure TGcmFile.PrintInfos(GCMInfo: TGCMInfo);
const
  FORE_KEY_CLR   = GRIS_PALE;
  BACK_KEY_CLR   = NOIR;
  FORE_VALUE_CLR = BLANC;
  BACK_VALUE_CLR = NOIR;

begin
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('ID.....................: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn('#', GCMInfo.ID);

  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Game Title.............: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.Title);
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Start Offset...........: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn('0x', IntToHex(GCMInfo.StartOfGcm, 8));
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Main DOL size..........: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.DolSize, ' byte(s)');
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Files count............: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.Contents.Files, ' file(s)');
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Folders count..........: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.Contents.Folders - 1, ' folder(s)');
                                  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Files size.............: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.Contents.TotalSize, ' byte(s)');

  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Apploader size.........: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.AppLoaderSize, ' byte(s)');
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('File system table size.: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.FstSize, ' byte(s)');

  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Header total size......: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.HeaderTotalSize, ' byte(s)');
  
  SetColor(FORE_KEY_CLR, BACK_KEY_CLR);
  Write('Total GCM size.........: ');
  SetColor(FORE_VALUE_CLR, BACK_VALUE_CLR);
  WriteLn(GCMInfo.TotalGcmSize, ' byte(s)');

  SetColor(GRIS_PALE, NOIR);
end;

//------------------------------------------------------------------------------

end.
