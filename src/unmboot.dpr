program unmboot;

{$APPTYPE CONSOLE}
{$R version.res}

uses
  Types,
  Classes,
  SysUtils,
  GcmFile in 'gcmfile.pas',
  Utils in 'utils.pas';

const
  VERSION : string = '1.0';
  VALID_SWITCHES : array[0..4] of string = ('l', 'a', 'e', 'help', 'h');
  
type
  TAction = (acListAll, acExtractAll, acExtract, acHelp, acError);
  
var
  MultiGcm : TGcmFile;
  toc : TList;
  GcmInfo : TGCMInfo;
  GcmMultiFile, Directory : string;
  Action : TAction;
  GcmID : Integer;
  OK : boolean;

//------------------------------------------------------------------------------

procedure WriteColor(Text : string ; ForeClr, BackClr : Byte);
begin
  SetColor(ForeClr, BackClr);
  Write(Text);
  SetColor(GRIS_PALE, NOIR);
end;

//------------------------------------------------------------------------------

procedure ShowUsage;
var
  PrgName : string;

begin
  PrgName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');

  WriteLn('A Nintendo Game Cube tool for extracting ViperGC MultiBoot GCM images.');
  WriteLn;
  WriteColor('Usage:', CYAN_PALE, NOIR);
  WriteLn('     ', PrgName, ' <command> [X] <multi.gcm> [dir]');
  WriteLn;
  WriteColor('Commands:', CYAN_PALE, NOIR);
  WriteLn('  -l          List all the contents of <multi.gcm>');
  WriteLn('           -a          Extract all contained into <multi.gcm> to [dir]');
  WriteLn('           -e [X]      Extract from <multi.gcm> the [X]th image to [dir]');
  WriteLn;
  WriteLn('           -help or -h Show this help');
  WriteLn;
  WriteColor('Examples:', CYAN_PALE, NOIR);
  WriteLn('  ', PrgName, ' -e 1 c:\temp\yo.gcm .');
  WriteLn('           This''ll extract the 1st GCM from yo.gcm to the current directory.');
  WriteLn;

  WriteColor('Greetings: ', CYAN_PALE, NOIR);
  WriteColor('Ghoom', BLEU_PALE, NOIR);
  Write(', ');
  WriteColor('groepaz/HiTMEN', BLEU_PALE, NOIR);
  Write(' and ');
  WriteColor('CRAZY NATiON', BLEU_PALE, NOIR);
  WriteLn('.');

  SetColor(ROUGE_PALE, NOIR);
  WriteLn;
  WriteLn('This''s my first Game Cube program, HELLO WORLD!');
  WriteLn('Allez manu, courage pour www.zoneo.fr !');
  SetColor(GRIS_PALE, NOIR);
end;

//------------------------------------------------------------------------------

procedure PrintHeader;
begin
  SetColor(ROUGE_PALE, NOIR);
  Write('UnMultiBoot');
  SetColor(BLANC, NOIR);
  Write(' - '); 
  SetColor(JAUNE, NOIR);
  Write('v', VERSION);
  SetColor(BLANC, NOIR);
  WriteLn(' - (C)reated by [big_fury]SiZiOUS');
  WriteLn('http://sbibuilder.shorturl.com/');
  WriteLn;
  SetColor(GRIS_PALE, NOIR);
end;

//------------------------------------------------------------------------------

function CorrectFileName(SingleFileName : TFileName) : TFileName;
const
  INVALID_CHARS : array[0..8] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|');

var
  i : integer;

begin
  for i := Low(INVALID_CHARS) to High(INVALID_CHARS) do
  begin
    SingleFileName := StringReplace(SingleFileName, INVALID_CHARS[i], '_', [rfReplaceAll, rfIgnoreCase]);
  end;

  //replacer les espaces
  SingleFileName := StringReplace(SingleFileName, ' ', '_', [rfReplaceAll, rfIgnoreCase]);

  Result := LowerCase(SingleFileName) + '.gcm';
end;

//------------------------------------------------------------------------------

function GenerateGcmFileName(GcmInfo : TGcmInfo ; OutputDir : string) : TFileName;
begin
  Result := GetRealPath(OutputDir + '\') + CorrectFileName(GcmInfo.Title);
end;

//------------------------------------------------------------------------------

function PerformAction(ac : TAction) : boolean;
var
  i : integer;
  target : string;

begin
  Result := True;
  
  Write('Selected file: "');
  WriteColor(GcmMultiFile, VERT_PALE, NOIR);
  WriteLn('".');
  if ac <> acListAll then
  begin
    Write('Output dir: "');
    WriteColor(Directory, VERT_PALE, NOIR);
    WriteLn('"');
  end;
  
  WriteLn;
  
  case ac of
    acListAll     :   for i := 0 to toc.Count - 1 do
                      begin
                        GcmInfo := PGcmInfo(toc[i])^;
                        MultiGcm.PrintInfos(GcmInfo);
                        WriteLn;
                      end;
                      
    acExtractAll  :   for i := 0 to toc.Count - 1 do
                      begin
                        GcmInfo := PGcmInfo(toc[i])^;
                        MultiGcm.PrintInfos(GcmInfo);
                        target := GenerateGcmFileName(GcmInfo, Directory);
                        MultiGcm.CreateDump(GcmInfo, target);
                        WriteLn;
                      end;

    acExtract :       begin
                        if (GcmID < 1) or (GcmID > toc.Count) then
                        begin
                          WriteColor('Error: ', ROUGE_PALE, NOIR);
                          WriteLn('GCM #', GcmID, ' doesn''t exists. Stop.');
                          Result := False;
                          Exit;
                        end;

                        GcmInfo := PGcmInfo(toc[GcmID - 1])^;
                        MultiGcm.PrintInfos(GcmInfo);
                        target := GenerateGcmFileName(GcmInfo, Directory);
                        MultiGcm.CreateDump(GcmInfo, target);
                        WriteLn;
                      end;
  end;
end;

//------------------------------------------------------------------------------

function ParseCmdLine : TAction;
var
  sw : string;
  j, decal : Integer;
  currswitch : string;

begin  
  Result := acError;
  decal := 0;
  
  //Récuperer le switch
  sw := ParamStr(1);
  if Length(sw) = 0 then
  begin
    ShowUsage;
    Exit;
  end;

  if (Result = acError) and (LowerCase(sw) = '-h') then
  begin
    Result := acHelp;
    Exit;
  end;
  
  for j := Low(VALID_SWITCHES) to High(VALID_SWITCHES) do
  begin
    { si c'est un switch valide on va le convertir dans son type correspondant.
      par exemple si le switch c'est "L" (position = 0) alors il sera converti
      vers TAction(0) c'est à dire : acListAll. }
    currswitch := Copy(sw, 2, Length(sw) - 1);
    if LowerCase(currswitch) = VALID_SWITCHES[j] then
    begin
      Result := TAction(j);
      Break;
    end;
  end;

  if Result = acError then
  begin
    //Le switch n'a pas été détecté.
    WriteColor('Error: ', ROUGE_PALE, NOIR);
    WriteLn('Invalid switch (', ParamStr(1), '). Stop.');
    WriteLn('Please use the -help switch to get help.');
    WriteLn;
    //ShowUsage;
    Exit;
  end else begin
    if Result = acExtract then //on a détecté que le switch c'est "e".
    begin
      decal := 1;
      GcmID := StrToIntDef(ParamStr(2), -1); //on récupere le numéro du GCM voulu.

      if GcmID = -1 then
      begin
        WriteColor('Error: ', ROUGE_PALE, NOIR);
        WriteLn('Invalid GCM number. (', ParamStr(2), ').');
        Result := acError; //si c'est = -1 il y'a un problème.
        Exit;
      end;
    end;
  end;

  if (Result = acHelp) then Exit;

  GcmMultiFile := ParamStr(2 + decal);
  if not FileExists(GcmMultiFile) then
  begin
    WriteColor('Error: ', ROUGE_PALE, NOIR);
    WriteLn('File "', GcmMultiFile, '" not found. Stop.');
    Result := acError;
    Exit;
  end;

  if (Result = acExtractAll) or (Result = acExtract) then
  begin
    Directory := ParamStr(3 + decal);
    if Directory = '' then Directory := '.'; //dossier courant
    Directory := ExpandFileName(Directory);
    if not DirectoryExists(Directory) then
    begin
      WriteColor('Error: ', ROUGE_PALE, NOIR);
      WriteLn('Directory "', Directory, '" not found. Stop.');
      Result := acError; 
      Exit;
    end;
  end;
end;

//------------------------------------------------------------------------------

begin
  PrintHeader;

  Action := ParseCmdLine;
  if Action = acError then Halt(255);
  if Action = acHelp then
  begin
    ShowUsage;
    Exit;
  end;

  MultiGcm := TGcmFile.Create(GcmMultiFile);
  try

   if MultiGcm.IsValidMultiBootImage then
   begin
     toc := MultiGcm.GetToc;
     Write('This image file contains ');
     WriteColor(IntToStr(toc.Count), VERT_PALE, NOIR);
     WriteLn(' GCM image(s).');
     WriteLn;

     //Faire ce qu'il faut faire ici !
     OK := PerformAction(Action);

     if OK and (Action <> acError) then
      WriteLn('Woohoo... Everything''s done !');
   end else
   begin
    WriteColor('Error: ', ROUGE_PALE, NOIR);
    WriteLn('This isn''t a valid multiboot image.');
   end;

  finally
    MultiGcm.Free;
  end;

end.
