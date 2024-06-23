{ XSLParser v1.0 - a lightweight, one-unit, (cross-)platform XSL reader
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

{ TXSLParser }

constructor TXSLParser.Create;
begin
  XSL := TXmlVerySimple.Create;
end;

destructor TXSLParser.Destroy;
begin
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
