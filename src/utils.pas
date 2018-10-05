unit utils;

interface

uses
  Windows;

const
    NOIR = 0;
    BLEU_FONCE = 1;
    VERT_FONCE = 2;
    CYAN_FONCE = 3;
    ROUGE_FONCE = 4;
    MAGENTA_FONCE = 5;
    MARRON = 6;
    GRIS_PALE = 7;
    GRIS_FONCE = 8;
    BLEU_PALE = 9;
    VERT_PALE = 10;
    CYAN_PALE = 11;
    ROUGE_PALE = 12;
    MAGENTA_PALE = 13;
    JAUNE = 14;
    BLANC = 15;
    //CLIGNOTER = 128;  //win98 seulement
      
procedure GotoXY(X: integer; Y: integer);
procedure GetCursorPosition(var X, Y : Integer);
function GetRealPath(Path : string) : string;
procedure SetColor(caractere: byte; fond: byte);

implementation

//------------------------------------------------------------------------------

procedure SetColor(caractere: byte; fond: byte);

begin

SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), 
                        caractere + (fond * 16));

end;

//------------------------------------------------------------------------------

procedure GotoXY(X: integer; Y: integer);

var
  pos: TCoord;   { Variable pour l'appel de SetConsoleCursorPosition() }

begin
  { Placer nos valeurs dans la variable pos }
  pos.x := x;
  pos.y := y;
  
  { Positionner le curseur dans l'écran }
  SetConsoleCursorPosition(GetStdHandle(STD_OUTPUT_HANDLE), pos);
end;

//------------------------------------------------------------------------------

procedure GetCursorPosition(var X, Y : Integer);
var
  info : CONSOLE_SCREEN_BUFFER_INFO;
  
begin
  GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), info);
  X := info.dwCursorPosition.X;
  Y := info.dwCursorPosition.Y;
end;

//------------------------------------------------------------------------------

function GetRealPath(Path : string) : string;
var
  i : integer;
  LastCharWasSeparator : Boolean;

begin
  Result := '';
  LastCharWasSeparator := False;

  Path := Path + '\';

  for i := 1 to Length(Path) do
  begin
    if Path[i] = '\' then
    begin
      if not LastCharWasSeparator then
      begin
        Result := Result + Path[i];
        LastCharWasSeparator := True;
      end
    end
    else
    begin
       LastCharWasSeparator := False;
       Result := Result + Path[i];
    end;
  end;
end;

//------------------------------------------------------------------------------

end.
