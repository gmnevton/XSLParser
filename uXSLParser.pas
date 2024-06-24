{ XSLParser v1.0 - a lightweight, one-unit XSL reader
  for Delphi 10+ by Grzegorz Molenda
  https://github.com/gmnevton/XSLParser

  (c) Copyrights 2024 Grzegorz Molenda aka NevTon <gmnevton@gmail.com>
  This unit is free and can be used for any needs. The introduction of
  any changes and the use of those changed library is permitted without
  limitations. Only requirement:
  This text comment must be present without changes in all modifications of library.

  * The contents of this file are used with permission, subject to    *
  * the Mozilla Public License Version 1.1 (the "License"); you may   *
  * not use this file except in compliance with the License. You may  *
  * obtain a copy of the License at                                   *
  * http:  www.mozilla.org/MPL/MPL-1.1.html                           *
  *                                                                   *
  * Software distributed under the License is distributed on an       *
  * "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or    *
  * implied. See the License for the specific language governing      *
  * rights and limitations under the License.                         *
}
unit uXSLParser;

interface

uses
  SysUtils,
  Classes,
  RTLConsts,
  XML.VerySimple;

type
  TXMLTextReader = class
  public
    procedure Close; virtual; abstract;
    function Peek: Integer; virtual; abstract;
    function Read: Integer; overload; virtual; abstract;
    function Read(var Buffer: TCharArray; Index, Count: Integer): Integer; overload; virtual; abstract;
    function ReadBlock(var Buffer: TCharArray; Index, Count: Integer): Integer; virtual; abstract;
    function ReadLine: string; virtual; abstract;
    function ReadToEnd: string; virtual; abstract;
    procedure Rewind; virtual; abstract;
  end;

  TXMLStreamReader = class(TXMLTextReader)
  private
    FBufferSize: Integer;
    FDetectBOM: Boolean;
    FEncoding: TEncoding;
    FOwnsStream: Boolean;
    FSkipPreamble: Boolean;
    FStream: TStream;
    function DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
    function GetEndOfStream: Boolean;
    function SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
  protected
    FBufferedData: TStringBuilder;
    FNoDataInStream: Boolean;
    procedure FillBuffer(var Encoding: TEncoding);
  public
    constructor Create(Stream: TStream); overload;
    constructor Create(Stream: TStream; DetectBOM: Boolean); overload;
    constructor Create(Stream: TStream; Encoding: TEncoding; DetectBOM: Boolean = False; BufferSize: Integer = 4096); overload;
    constructor Create(const Filename: string); overload;
    constructor Create(const Filename: string; DetectBOM: Boolean); overload;
    constructor Create(const Filename: string; Encoding: TEncoding; DetectBOM: Boolean = False; BufferSize: Integer = 4096); overload;
    destructor Destroy; override;
    procedure Close; override;
    procedure DiscardBufferedData;
    procedure OwnStream; inline;
    function Peek: Integer; override;
    function Read: Integer; overload; override;
    function Read(var Buffer: TCharArray; Index, Count: Integer): Integer; overload; override;
    function ReadBlock(var Buffer: TCharArray; Index, Count: Integer): Integer; override;
    function ReadLine: string; override;
    function ReadToEnd: string; override;
    procedure Rewind; override;
    property BaseStream: TStream read FStream;
    property CurrentEncoding: TEncoding read FEncoding;
    property EndOfStream: Boolean read GetEndOfStream;
  end;

//  TXmlStreamReader = class(TXMLStreamReader)
//  protected
//    FFillBuffer: TStreamReaderFillBuffer;
//    ///	<summary> Call to FillBuffer method of TStreamReader </summary>
//    procedure FillBuffer;
//  public
//    ///	<summary> Extend the TStreamReader with RTTI pointers </summary>
//    constructor Create(Stream: TStream; Encoding: TEncoding; DetectBOM: Boolean = False; BufferSize: Integer = 4096);
//    ///	<summary> Assures the read buffer holds at least Value characters </summary>
//    function PrepareBuffer(Value: Integer): Boolean;
//    ///	<summary> Extract text until chars found in StopChars </summary>
//    function ReadText(const StopChars: String; Options: TExtractTextOptions): String; virtual;
//    ///	<summary> Returns fist char but does not removes it from the buffer </summary>
//    function FirstChar: Char;
//    ///	<summary> Proceed with the next character(s) (value optional, default 1) </summary>
//    procedure IncCharPos(Value: Integer = 1); virtual;
//    ///	<summary> Returns True if the first uppercased characters at the current position match Value </summary>
//    function IsUppercaseText(const Value: String): Boolean; virtual;
//  end;

  TXMLReader = TXMLStreamReader;

  TXSLParser = class
  private
    XSL: TXmlVerySimple;
    FEncoding: String;
  protected
    procedure SetEncoding(const Value: String); virtual;
    function GetEncoding: String; virtual;
    //
    procedure Parse(Reader: TXMLReader); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    //
    function LoadFromFile(const FileName: String; BufferSize: Integer = 4096): TXSLParser; virtual;
    function LoadFromStream(const Stream: TStream; BufferSize: Integer = 4096): TXSLParser; virtual;
    //
    property Encoding: String read GetEncoding write SetEncoding;
  end;

implementation

{ TXMLStreamReader }

constructor TXMLStreamReader.Create(Stream: TStream);
begin
  Create(Stream, TEncoding.UTF8, True);
end;

constructor TXMLStreamReader.Create(Stream: TStream; DetectBOM: Boolean);
begin
  Create(Stream, TEncoding.UTF8, DetectBOM);
end;

constructor TXMLStreamReader.Create(Stream: TStream; Encoding: TEncoding; DetectBOM: Boolean; BufferSize: Integer);
begin
  inherited Create;

  if not Assigned(Stream) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Stream']); // DO NOT LOCALIZE
  if not Assigned(Encoding) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Encoding']); // DO NOT LOCALIZE

  FBufferedData := TStringBuilder.Create;
  FEncoding := Encoding;
  FBufferSize := BufferSize;
  if FBufferSize < 128 then
    FBufferSize := 128;
  FNoDataInStream := False;
  FStream := Stream;
  FOwnsStream := False;
  FDetectBOM := DetectBOM;
  FSkipPreamble := not FDetectBOM;
end;

constructor TXMLStreamReader.Create(const Filename: string);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite));
  FOwnsStream := True;
end;

constructor TXMLStreamReader.Create(const Filename: string; DetectBOM: Boolean);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite), DetectBOM);
  FOwnsStream := True;
end;

constructor TXMLStreamReader.Create(const Filename: string; Encoding: TEncoding; DetectBOM: Boolean; BufferSize: Integer);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite), Encoding, DetectBOM, BufferSize);
  FOwnsStream := True;
end;

destructor TXMLStreamReader.Destroy;
begin
  Close;
  inherited;
end;

procedure TXMLStreamReader.Close;
begin
  if (FStream <> Nil) and FOwnsStream then begin
    FStream.Free;
    FStream := Nil;
  end;

  if FBufferedData <> Nil then begin
    FBufferedData.Free;
    FBufferedData := Nil;
  end;
end;

function TXMLStreamReader.DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
var
  LEncoding: TEncoding;
begin
  // try to automatically detect the buffer encoding
  LEncoding := Nil;
  Result := TEncoding.GetBufferEncoding(Buffer, LEncoding, Nil);
  if LEncoding <> Nil then
    Encoding := LEncoding
  else if Encoding = Nil then
    Encoding := TEncoding.Default;

  FDetectBOM := False;
end;

procedure TXMLStreamReader.DiscardBufferedData;
begin
  if FBufferedData <> nil then begin
    FBufferedData.Remove(0, FBufferedData.Length);
    FNoDataInStream := False;
  end;
end;

procedure TXMLStreamReader.FillBuffer(var Encoding: TEncoding);
const
  BufferPadding = 4;
var
  LString: string;
  LBuffer: TBytes;
  BytesRead: Integer;
  StartIndex: Integer;
  ByteCount: Integer;
  ByteBufLen: Integer;
  ExtraByteCount: Integer;

  procedure AdjustEndOfBuffer(const LBuffer: TBytes; Offset: Integer);
  var
    Pos, Size: Integer;
    Rewind: Integer;
  begin
    Dec(Offset);
    for Pos := Offset downto 0 do
    begin
      for Size := Offset - Pos + 1 downto 1 do
      begin
        if Encoding.GetCharCount(LBuffer, Pos, Size) > 0 then
        begin
          Rewind := Offset - (Pos + Size - 1);
          FStream.Position := FStream.Position - Rewind;
          BytesRead := BytesRead - Rewind;
          Exit;
        end;
      end;
    end;
  end;

begin
  SetLength(LBuffer, FBufferSize + BufferPadding);

  // Read data from stream
  BytesRead := FStream.Read(LBuffer[0], FBufferSize);
  FNoDataInStream := BytesRead = 0;

  // Check for byte order mark and calc start index for character data
  if FDetectBOM then
    StartIndex := DetectBOM(Encoding, LBuffer)
  else if FSkipPreamble then
    StartIndex := SkipPreamble(Encoding, LBuffer)
  else
    StartIndex := 0;

  // Adjust the end of the buffer to be sure we have a valid encoding
  if not FNoDataInStream then
    AdjustEndOfBuffer(LBuffer, BytesRead);

  // Convert to string and calc byte count for the string
  ByteBufLen := BytesRead - StartIndex;
  LString := FEncoding.GetString(LBuffer, StartIndex, ByteBufLen);
  ByteCount := FEncoding.GetByteCount(LString);

  // If byte count <> number of bytes read from the stream
  // the buffer boundary is mid-character and additional bytes
  // need to be read from the stream to complete the character
  ExtraByteCount := 0;
  while (ByteCount <> ByteBufLen) and (ExtraByteCount < FEncoding.GetMaxByteCount(1)) do
  begin
    // Expand buffer if padding is used
    if (StartIndex + ByteBufLen) = Length(LBuffer) then
      SetLength(LBuffer, Length(LBuffer) + BufferPadding);

    // Read one more byte from the stream into the
    // buffer padding and convert to string again
    BytesRead := FStream.Read(LBuffer[StartIndex + ByteBufLen], 1);
    if BytesRead = 0 then
      // End of stream, append what's been read and discard remaining bytes
      Break;

    Inc(ExtraByteCount);

    Inc(ByteBufLen);
    LString := FEncoding.GetString(LBuffer, StartIndex, ByteBufLen);
    ByteCount := FEncoding.GetByteCount(LString);
  end;

  // Add string to character data buffer
  FBufferedData.Append(LString);
end;

function TXMLStreamReader.GetEndOfStream: Boolean;
begin
  if not FNoDataInStream and (FBufferedData <> nil) and (FBufferedData.Length < 1) then
    FillBuffer(FEncoding);
  Result := FNoDataInStream and ((FBufferedData = nil) or (FBufferedData.Length = 0));
end;

procedure TXMLStreamReader.OwnStream;
begin
  FOwnsStream := True;
end;

function TXMLStreamReader.Peek: Integer;
begin
  Result := -1;
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    if FBufferedData.Length < 1 then
      FillBuffer(FEncoding);
    Result := Integer(FBufferedData.Chars[0]);
  end;
end;

function TXMLStreamReader.Read: Integer;
begin
  Result := -1;
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    if FBufferedData.Length < 1 then
      FillBuffer(FEncoding);
    Result := Integer(FBufferedData.Chars[0]);
    FBufferedData.Remove(0, 1);
  end;
end;

function TXMLStreamReader.Read(var Buffer: TCharArray; Index, Count: Integer): Integer;
begin
  Result := -1;
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    while (FBufferedData.Length < Count) and (not EndOfStream) and (not FNoDataInStream) do
      FillBuffer(FEncoding);

    if FBufferedData.Length > Count then
      Result := Count
    else
      Result := FBufferedData.Length;

    FBufferedData.CopyTo(0, Buffer, Index, Result);
    FBufferedData.Remove(0, Result);
  end;
end;

function TXMLStreamReader.ReadBlock(var Buffer: TCharArray; Index, Count: Integer): Integer;
begin
  Result := Read(Buffer, Index, Count);
end;

function TXMLStreamReader.ReadLine: string;
var
  NewLineIndex: Integer;
  PostNewLineIndex: Integer;
  LChar: Char;
begin
  Result := '';
  if FBufferedData = nil then
    Exit;
  NewLineIndex := 0;
  PostNewLineIndex := 0;

  while True do
  begin
    if (NewLineIndex + 2 > FBufferedData.Length) and (not FNoDataInStream) then
      FillBuffer(FEncoding);

    if NewLineIndex >= FBufferedData.Length then
    begin
      if FNoDataInStream then
      begin
        PostNewLineIndex := NewLineIndex;
        Break;
      end
      else
      begin
        FillBuffer(FEncoding);
        if FBufferedData.Length = 0 then
          Break;
      end;
    end;
    LChar := FBufferedData[NewLineIndex];
    if LChar = #10 then
    begin
      PostNewLineIndex := NewLineIndex + 1;
      Break;
    end
    else
    if (LChar = #13) and (NewLineIndex + 1 < FBufferedData.Length) and (FBufferedData[NewLineIndex + 1] = #10) then
    begin
      PostNewLineIndex := NewLineIndex + 2;
      Break;
    end
    else
    if LChar = #13 then
    begin
      PostNewLineIndex := NewLineIndex + 1;
      Break;
    end;

    Inc(NewLineIndex);
  end;

  Result := FBufferedData.ToString;
  SetLength(Result, NewLineIndex);
  FBufferedData.Remove(0, PostNewLineIndex);
end;

function TXMLStreamReader.ReadToEnd: string;
begin
  Result := '';
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    repeat
      FillBuffer(FEncoding);
    until FNoDataInStream;
    Result := FBufferedData.ToString;
    FBufferedData.Remove(0, FBufferedData.Length);
  end;
end;

procedure TXMLStreamReader.Rewind;
begin
  DiscardBufferedData;
  FSkipPreamble := not FDetectBOM;
  FStream.Position := 0;
end;

function TXMLStreamReader.SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
var
  I: Integer;
  LPreamble: TBytes;
  BOMPresent: Boolean;
begin
  Result := 0;
  LPreamble := Encoding.GetPreamble;
  if (Length(LPreamble) > 0) then
  begin
    if Length(Buffer) >= Length(LPreamble) then
    begin
      BOMPresent := True;
      for I := 0 to Length(LPreamble) - 1 do
        if LPreamble[I] <> Buffer[I] then
        begin
          BOMPresent := False;
          Break;
        end;
      if BOMPresent then
        Result := Length(LPreamble);
    end;
  end;
  FSkipPreamble := False;
end;

{ TXSLParser }

constructor TXSLParser.Create;
begin
  XSL := TXmlVerySimple.Create;
  FEncoding := 'utf-8';
end;

destructor TXSLParser.Destroy;
begin
  FEncoding := '';
  XSL.Free;
  inherited;
end;

procedure TXSLParser.SetEncoding(const Value: String);
begin
  FEncoding := Value;
end;

function TXSLParser.GetEncoding: String;
begin
  Result := FEncoding;
end;

procedure TXSLParser.Parse(Reader: TXMLReader);
begin

end;

function TXSLParser.LoadFromFile(const FileName: String; BufferSize: Integer): TXSLParser;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead + fmShareDenyWrite);
  try
    LoadFromStream(Stream, BufferSize);
  finally
    Stream.Free;
  end;
  Result := Self;
end;

function TXSLParser.LoadFromStream(const Stream: TStream; BufferSize: Integer): TXSLParser;
var
  Reader: TXmlReader;
begin
  if Encoding = '' then // none specified then use UTF8 with DetectBom
    Reader := TXmlReader.Create(Stream, TEncoding.UTF8, True, BufferSize)
  else if CompareText(Encoding, 'utf-8') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.UTF8, False, BufferSize)
  else if CompareText(Encoding, 'windows-1250') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.GetEncoding(1250), False, BufferSize)
  else if CompareText(Encoding, 'iso-8859-2') = 0 then
    Reader := TXmlReader.Create(Stream, TEncoding.GetEncoding(28592), False, BufferSize)
  else
    Reader := TXmlReader.Create(Stream, TEncoding.ANSI, False, BufferSize);
  try
    Parse(Reader);
  finally
    Reader.Free;
  end;
  Result := Self;
end;

end.
