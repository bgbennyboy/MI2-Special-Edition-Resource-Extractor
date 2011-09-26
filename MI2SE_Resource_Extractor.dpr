{
******************************************************
  Monkey Island 2 Special Edition Resource Extractor
  Copyright (c) 2011 Bgbennyboy
  Http://quick.mixnmojo.com
******************************************************
}

program MI2SE_Resource_Extractor;

{$APPTYPE CONSOLE}

uses
  SysUtils, Classes, Windows, JCLRegistry;

const
  NewLine       = #13#10;
  NewLineBreak  = #13#10#13#10;
  strAppName    = 'MI2 Original Resource Extractor';
  strAppVersion = '0.1';
  strAuthor     = 'By bgbennyboy';
  strWebsite    = 'Http://quick.mixnmojo.com';
  strArguments  = 'Extracts Monkey.000 and Monkey.001 from the resource.pak file found in MI2:SE' + NewLine +
                  'Usage:' + NewLineBreak +
                  'MI2_ResExtract [Path to Monkey2.pak] [Output directory]' + NewLine +
                  'OR' + NewLine +
                  'MI2_ResExtract [Output directory]   -will attempt to autodetect the location of Monkey2.pak using the registry';

  sizeOfFileRecord: integer = 20;

  //Error codes
  intErrorBadArguments      = 1;
  intErrorBadInDir          = 2;
  intErrorBadOutDir         = 3;
  intErrorAutodetectFailed  = 4;
  intErrorInvalidPakFile    = 5;
  intErrorFindingFileInPak  = 6;



function GetMI2SEPath: string;
const
  ExtraPath: string = 'steamapps\common\monkey2\';
var
  Temp: string;
begin
  Result := '';
  try
    Temp:= IncludeTrailingPathDelimiter(RegReadString(HKEY_CURRENT_USER, 'SOFTWARE\Valve\Steam', 'SteamPath'));
    result:=Temp + ExtraPath;
    Result := StringReplace(Result, '/', '\', [rfReplaceAll, rfIgnoreCase ]);
  except on EJCLRegistryError do
    result:='';
  end;
end;

function SanitiseFileName(FileName: string): string;
var
  DelimiterPos: integer;
begin
  DelimiterPos := LastDelimiter('/', FileName );
  if DelimiterPos = 0 then
    result := FileName
  else
    Result := Copy( FileName, DelimiterPos + 1, Length(FileName) - DelimiterPos + 1);
end;

function ReadString(TheStream: TStream; Length: integer): string;
var
  n: longword;
  t: byte;
begin
  SetLength(result,length);
  for n:=1 to length do
  begin
    TheStream.Read(t, 1);
    result[n]:=Chr(t);
  end;
end;


var
  PakFilePath, TempFileName, OutDir, TempStr: string;
  PakFile: TFileStream;
  TempDWord: DWord;
  startOfFileEntries : DWord;
  startOfFileNames   : DWord;
  startOfData        : DWord;
  sizeOfIndex        : DWord;
  sizeOfFileEntries  : DWord;
  sizeOfFileNames    : DWord;
  sizeOfData         : DWord;
  i, currNameOffset, File000Index, File001Index, File000Size, File000Offset, File001Size, File001Offset: integer;
  TempStream: TMemoryStream;
begin
  try
    Write( strAppName + ' ' + strAppVersion + ' ' + strAuthor + NewLineBreak + strWebsite + NewLineBreak);

{**************First check command line arguments**************}
    if (ParamCount < 1) or (ParamCount > 2) or (ParamStr(1) = '/?') then
    begin
      Write( strArguments );
      Halt(0);
    end;

    if ParamCount = 1 then //Autodetect monkey2.pak
    begin
      //Try and autodetect
      if FileExists( GetMI2SEPath + 'Monkey2.pak') = false then
        Halt(intErrorAutodetectFailed);

      //Check outdir is valid
      if DirectoryExists( IncludeTrailingPathDelimiter( ParamStr(1) ) ) = false then
        Halt( intErrorBadOutDir );
    end;

    if ParamCount = 2 then
    begin
      //Check in path is valid
      if FileExists( IncludeTrailingPathDelimiter( ParamStr(1) ) + 'Monkey2.pak') = false then
        Halt(intErrorBadInDir);

      //Check outdir is valid
      if DirectoryExists( ParamStr(2) ) = false then
        Halt( intErrorBadOutDir );
    end;

{**************************************************************}


    if ParamCount = 1 then //Autodetect monkey2.pak
    begin
      PakFilePath := GetMI2SEPath + 'Monkey2.pak';
      OutDir := IncludeTrailingPathDelimiter( ParamStr(1) );
    end
    else
    begin
      PakFilePath := IncludeTrailingPathDelimiter( ParamStr(1) ) + 'Monkey2.pak';
      OutDir := IncludeTrailingPathDelimiter( ParamStr(2) );
    end;

    PakFile := TFileStream.Create(PakFilePath, fmOpenRead);
    try
      //Check header
      PakFile.Read(TempDWord, 4);
      if TempDWord <> 1280328011 then //KAPL
        Halt( intErrorInvalidPakFile );

      PakFile.Position := 12;
      PakFile.read( startOfFileEntries, 4 );
      PakFile.read( startOfFileNames, 4 );
      PakFile.read( startOfData, 4 );
      PakFile.read( sizeOfIndex, 4 );
      PakFile.read( sizeOfFileEntries, 4 );
      PakFile.read( sizeOfFileNames, 4 );
      PakFile.read( sizeOfData, 4 );

      //In MI2 NameOffs is broken - luckily filenames are stored in the same order as the entries in the file records
      //Parse the filenames and find the index of monkey1.000 and monkey1.001



      //Read FileNames and see if any match
      CurrNameOffset := 0;
      File000Index := -1;
      File001Index := -1;
      for I := 0 to sizeOfFileEntries div sizeOfFileRecord - 1 do
      begin
        PakFile.Position  := startOfFileNames + currNameOffset;
        TempStr :=  PChar( ReadString(PakFile, 255) );
        inc(currNameOffset, length(TempStr) + 1); //+1 because each filename is null terminated

        if (File000Index <> -1) and (File001Index <> -1) then
            break;

        if  SanitiseFileName( TempStr  ) = 'monkey2.000' then
          File000Index := i
        else
        if  SanitiseFileName( TempStr  ) = 'monkey2.001' then
          File001Index := i
      end;


      if (File000Index = -1) or (File001Index = -1) then //one of files not found
        Halt( intErrorFindingFileInPak );

      //Get offset + size of files
      PakFile.Position  := startOfFileEntries + (sizeOfFileRecord * File000Index);
      PakFile.Read(File000Offset, 4);
      Inc(File000Offset, startOfData);
      PakFile.Seek(4, soFromCurrent);
      PakFile.Read(File000Size, 4);

      PakFile.Position  := startOfFileEntries + (sizeOfFileRecord * File001Index);
      PakFile.Read(File001Offset, 4);
      Inc(File001Offset, startOfData);
      PakFile.Seek(4, soFromCurrent);
      PakFile.Read(File001Size, 4);

      //Dump the files
      PakFile.Position := File000Offset;
      TempStream:= TMemoryStream.Create;
      try
        TempStream.CopyFrom(PakFile, File000Size);
        TempStream.SaveToFile(OutDir + 'Monkey2.000');
      finally
        TempStream.Free;
      end;

      PakFile.Position := File001Offset;
      TempStream:= TMemoryStream.Create;
      try
        TempStream.CopyFrom(PakFile, File001Size);
        TempStream.SaveToFile(OutDir + 'Monkey2.001');
      finally
        TempStream.Free;
      end;

    finally
      PakFile.Free;
    end;


    //ReadLn;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
