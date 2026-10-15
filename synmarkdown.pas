unit SynMarkdown;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, Graphics, SynEditHighlighter;

type
  TtkMdKind = (tkNull, tkText, tkHeader, tkBold, tkItalic, tkStrike,
    tkCode, tkQuote, tkList, tkLink, tkHR, tkTable);

  { TSynMarkdownSyn }

  TSynMarkdownSyn = class(TSynCustomHighlighter)
  private
    fLineStr: string;
    fLineNumber: Integer;
    fRun: Integer;      // 1-based: primer char tras el token actual
    fTokenPos: Integer; // 0-based: inicio del token actual
    FTokenID: TtkMdKind;
    fInCode: Boolean;   // dentro de bloque ``` (viene de Range)
    FTitleAttr: TSynHighlighterAttributes;
    FBoldAttr: TSynHighlighterAttributes;
    FItalicAttr: TSynHighlighterAttributes;
    FStrikeAttr: TSynHighlighterAttributes;
    FCodeAttr: TSynHighlighterAttributes;
    FQuoteAttr: TSynHighlighterAttributes;
    FListAttr: TSynHighlighterAttributes;
    FLinkAttr: TSynHighlighterAttributes;
    FHRAttr: TSynHighlighterAttributes;
    FTableAttr: TSynHighlighterAttributes;
    function IsWordChar(C: Char): Boolean;
    function FindClosing(const Seq: string; FromPos: Integer): Integer;
    function FindClosingChar(C: Char; FromPos: Integer): Integer;
    function TryParseLink(FromPos: Integer; out EndPos: Integer): Boolean;
    function TryParseAutolink(FromPos: Integer; out EndPos: Integer): Boolean;
    function IsDelimLine(const S: string): Boolean;
    function IsHrLine(const S: string): Boolean;
    function HeadingLen(const S: string): Integer;
    function WholeLineToken(AKind: TtkMdKind): Boolean;
    function TryLineStart: Boolean;
    procedure InlineToken;
  protected
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
  public
    constructor Create(AOwner: TComponent); override;
    class function GetLanguageName: string; override;
    function GetEol: Boolean; override;
    function GetRange: Pointer; override;
    function GetToken: string; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
  published
    property TitleAttr: TSynHighlighterAttributes read FTitleAttr write FTitleAttr;
    property BoldAttr: TSynHighlighterAttributes read FBoldAttr write FBoldAttr;
    property ItalicAttr: TSynHighlighterAttributes read FItalicAttr write FItalicAttr;
    property StrikeAttr: TSynHighlighterAttributes read FStrikeAttr write FStrikeAttr;
    property CodeAttr: TSynHighlighterAttributes read FCodeAttr write FCodeAttr;
    property QuoteAttr: TSynHighlighterAttributes read FQuoteAttr write FQuoteAttr;
    property ListAttr: TSynHighlighterAttributes read FListAttr write FListAttr;
    property LinkAttr: TSynHighlighterAttributes read FLinkAttr write FLinkAttr;
    property HRAttr: TSynHighlighterAttributes read FHRAttr write FHRAttr;
    property TableAttr: TSynHighlighterAttributes read FTableAttr write FTableAttr;
  end;

implementation

uses
  SysUtils;

{ TSynMarkdownSyn }

constructor TSynMarkdownSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FTitleAttr := TSynHighlighterAttributes.Create('Title', 'Title');
  FTitleAttr.Foreground := clNavy;
  FTitleAttr.Style := [fsBold];
  AddAttribute(FTitleAttr);

  FBoldAttr := TSynHighlighterAttributes.Create('Bold', 'Bold');
  FBoldAttr.Style := [fsBold];
  AddAttribute(FBoldAttr);

  FItalicAttr := TSynHighlighterAttributes.Create('Italic', 'Italic');
  FItalicAttr.Style := [fsItalic];
  AddAttribute(FItalicAttr);

  FStrikeAttr := TSynHighlighterAttributes.Create('Strike', 'Strike');
  FStrikeAttr.Foreground := clGray;
  FStrikeAttr.Style := [fsStrikeOut];
  AddAttribute(FStrikeAttr);

  FCodeAttr := TSynHighlighterAttributes.Create('Code', 'Code');
  FCodeAttr.Foreground := clMaroon;
  FCodeAttr.Background := TColor($F0F0F0);
  AddAttribute(FCodeAttr);

  FQuoteAttr := TSynHighlighterAttributes.Create('Quote', 'Quote');
  FQuoteAttr.Foreground := TColor($808080);
  FQuoteAttr.Style := [fsItalic];
  AddAttribute(FQuoteAttr);

  FListAttr := TSynHighlighterAttributes.Create('List', 'List');
  FListAttr.Foreground := clBlue;
  FListAttr.Style := [fsBold];
  AddAttribute(FListAttr);

  FLinkAttr := TSynHighlighterAttributes.Create('Link', 'Link');
  FLinkAttr.Foreground := clBlue;
  FLinkAttr.Style := [fsUnderline];
  AddAttribute(FLinkAttr);

  FHRAttr := TSynHighlighterAttributes.Create('HR', 'HR');
  FHRAttr.Foreground := clGray;
  AddAttribute(FHRAttr);

  FTableAttr := TSynHighlighterAttributes.Create('Table', 'Table');
  FTableAttr.Foreground := clTeal;
  AddAttribute(FTableAttr);

  fInCode := False;
  SetDefaultFilter('Markdown files (*.md;*.markdown)');
end;

class function TSynMarkdownSyn.GetLanguageName: string;
begin
  Result := 'Markdown';
end;

function TSynMarkdownSyn.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  Result := nil;
end;

function TSynMarkdownSyn.GetEol: Boolean;
begin
  // Contrato SynEdit: hay token válido mientras no sea tkNull.
  // (Un GetEol posicional saltaría la última token de cada línea
  // en todos los consumidores, y dejaba i=0 en IsContextBracket.)
  Result := FTokenID = tkNull;
end;

function TSynMarkdownSyn.GetRange: Pointer;
begin
  Result := Pointer(PtrInt(Ord(fInCode)));
end;

procedure TSynMarkdownSyn.SetRange(Value: Pointer);
begin
  fInCode := Value <> nil;
end;

procedure TSynMarkdownSyn.ResetRange;
begin
  fInCode := False;
end;

procedure TSynMarkdownSyn.SetLine(const NewValue: string; LineNumber: Integer);
begin
  inherited;
  fLineStr := NewValue;
  fLineNumber := LineNumber;
  fRun := 1;
  Next;
end;

function TSynMarkdownSyn.GetToken: string;
begin
  if fRun - 1 > fTokenPos then
    Result := Copy(fLineStr, fTokenPos + 1, fRun - 1 - fTokenPos)
  else
    Result := '';
end;

procedure TSynMarkdownSyn.GetTokenEx(out TokenStart: PChar; out TokenLength: Integer);
begin
  TokenLength := fRun - 1 - fTokenPos;
  if (TokenLength > 0) and (fTokenPos < Length(fLineStr)) then
    TokenStart := PChar(@fLineStr[fTokenPos + 1])
  else
  begin
    TokenStart := nil;
    TokenLength := 0;
  end;
end;

function TSynMarkdownSyn.GetTokenPos: Integer;
begin
  Result := fTokenPos;
end;

function TSynMarkdownSyn.GetTokenKind: Integer;
begin
  Result := Ord(FTokenID);
end;

function TSynMarkdownSyn.GetTokenAttribute: TSynHighlighterAttributes;
begin
  case FTokenID of
    tkHeader: Result := FTitleAttr;
    tkBold: Result := FBoldAttr;
    tkItalic: Result := FItalicAttr;
    tkStrike: Result := FStrikeAttr;
    tkCode: Result := FCodeAttr;
    tkQuote: Result := FQuoteAttr;
    tkList: Result := FListAttr;
    tkLink: Result := FLinkAttr;
    tkHR: Result := FHRAttr;
    tkTable: Result := FTableAttr;
  else
    Result := nil;
  end;
end;

function TSynMarkdownSyn.IsWordChar(C: Char): Boolean;
begin
  Result := (C in ['A'..'Z', 'a'..'z', '0'..'9', '_']) or (Ord(C) > 127);
end;

function TSynMarkdownSyn.FindClosing(const Seq: string; FromPos: Integer): Integer;
var
  p: Integer;
begin
  Result := 0;
  p := FromPos;
  while p <= Length(fLineStr) - Length(Seq) + 1 do
  begin
    if Copy(fLineStr, p, Length(Seq)) = Seq then
      Exit(p);
    Inc(p);
  end;
end;

function TSynMarkdownSyn.FindClosingChar(C: Char; FromPos: Integer): Integer;
var
  p: Integer;
begin
  Result := 0;
  for p := FromPos to Length(fLineStr) do
    if fLineStr[p] = C then
      Exit(p);
end;

function TSynMarkdownSyn.TryParseLink(FromPos: Integer; out EndPos: Integer): Boolean;
var
  p, q: Integer;
begin
  // FromPos apunta a '['. Acepta [texto](url).
  Result := False;
  EndPos := 0;
  p := FindClosingChar(']', FromPos + 1);
  if (p = 0) or (p + 1 > Length(fLineStr)) or (fLineStr[p + 1] <> '(') then
    Exit;
  q := FindClosingChar(')', p + 2);
  if q = 0 then
    Exit;
  EndPos := q;
  Result := True;
end;

function TSynMarkdownSyn.TryParseAutolink(FromPos: Integer; out EndPos: Integer): Boolean;
var
  p, q: Integer;
  Inner: string;
begin
  // FromPos apunta a '<'. Acepta <esquema:...> o <a@b>.
  Result := False;
  EndPos := 0;
  q := FindClosingChar('>', FromPos + 1);
  if q = 0 then
    Exit;
  Inner := Copy(fLineStr, FromPos + 1, q - FromPos - 1);
  if (Inner = '') or (Pos(' ', Inner) > 0) then
    Exit;
  p := Pos(':', Inner);
  if ((p > 1) and (p < Length(Inner))) or (Pos('@', Inner) > 1) then
  begin
    EndPos := q;
    Result := True;
  end;
end;

function TSynMarkdownSyn.IsDelimLine(const S: string): Boolean;
var
  Cells: TStringList;
  k, m: Integer;
  C: string;
  OK: Boolean;
begin
  Result := False;
  if Pos('|', S) = 0 then
    Exit;
  Cells := TStringList.Create;
  try
    Cells.Delimiter := '|';
    Cells.StrictDelimiter := True;
    Cells.DelimitedText := S;
    if (Cells.Count > 0) and (Trim(Cells[0]) = '') then
      Cells.Delete(0);
    if (Cells.Count > 0) and (Trim(Cells[Cells.Count - 1]) = '') then
      Cells.Delete(Cells.Count - 1);
    if Cells.Count = 0 then
      Exit;
    for k := 0 to Cells.Count - 1 do
    begin
      C := Trim(Cells[k]);
      if (C <> '') and (C[1] = ':') then
        Delete(C, 1, 1);
      if (C <> '') and (C[Length(C)] = ':') then
        Delete(C, Length(C), 1);
      OK := C <> '';
      m := 1;
      while OK and (m <= Length(C)) do
      begin
        if C[m] <> '-' then
          OK := False;
        Inc(m);
      end;
      if not OK then
        Exit;
    end;
    Result := True;
  finally
    Cells.Free;
  end;
end;

function TSynMarkdownSyn.IsHrLine(const S: string): Boolean;
var
  T: string;
  i, Count: Integer;
  C: Char;
begin
  Result := False;
  T := Trim(S);
  if Length(T) < 3 then
    Exit;
  C := T[1];
  if not (C in ['-', '*', '_']) then
    Exit;
  Count := 0;
  for i := 1 to Length(T) do
  begin
    if T[i] = C then
      Inc(Count)
    else if T[i] <> ' ' then
      Exit;
  end;
  Result := Count >= 3;
end;

function TSynMarkdownSyn.HeadingLen(const S: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  i := 1;
  while (i <= Length(S)) and (S[i] = ' ') and (i <= 3) do
    Inc(i);
  while (i <= Length(S)) and (S[i] = '#') do
  begin
    Inc(Result);
    Inc(i);
  end;
  if (Result < 1) or (Result > 6) then
    Exit(0);
  if (i <= Length(S)) and (S[i] <> ' ') then
    Exit(0);
end;

function TSynMarkdownSyn.WholeLineToken(AKind: TtkMdKind): Boolean;
begin
  FTokenID := AKind;
  fRun := Length(fLineStr) + 1;
  Result := True;
end;

function TSynMarkdownSyn.TryLineStart: Boolean;
var
  Trimmed, T: string;
  i, Indent: Integer;
begin
  Result := False;
  if fInCode then
  begin
    // Dentro de cerca: solo la valla de cierre cambia el estado
    if Copy(Trim(fLineStr), 1, 3) = '```' then
    begin
      fInCode := False;
      WholeLineToken(tkCode);
    end
    else
      WholeLineToken(tkCode);
    Exit(True);
  end;
  Trimmed := Trim(fLineStr);
  if Trimmed = '' then
    Exit(False);
  // Valla de apertura (hasta 3 espacios de indentación)
  Indent := 1;
  while (Indent <= Length(fLineStr)) and (fLineStr[Indent] = ' ') and
    (Indent <= 3) do
    Inc(Indent);
  if Copy(fLineStr, Indent, 3) = '```' then
  begin
    fInCode := True;
    WholeLineToken(tkCode);
    Exit(True);
  end;
  // Código indentado
  if ((Copy(fLineStr, 1, 4) = '    ') or
    ((fLineStr <> '') and (fLineStr[1] = #9))) then
  begin
    WholeLineToken(tkCode);
    Exit(True);
  end;
  // Heading ATX
  if HeadingLen(fLineStr) > 0 then
  begin
    WholeLineToken(tkHeader);
    Exit(True);
  end;
  // HR
  if IsHrLine(fLineStr) then
  begin
    WholeLineToken(tkHR);
    Exit(True);
  end;
  // Fila delimitadora de tabla
  if IsDelimLine(fLineStr) then
  begin
    WholeLineToken(tkTable);
    Exit(True);
  end;
  // Cita: token '>' y el resto va inline
  T := TrimLeft(fLineStr);
  if (T <> '') and (T[1] = '>') then
  begin
    i := Length(fLineStr) - Length(T) + 1; // pos 1-based de '>'
    FTokenID := tkQuote;
    fRun := i + 1;
    Exit(True);
  end;
  // Lista: marcador + resto inline
  if (T <> '') and (T[1] in ['-', '*', '+']) and (Length(T) >= 2) and
    (T[2] = ' ') then
  begin
    i := Length(fLineStr) - Length(T) + 1;
    FTokenID := tkList;
    fRun := i + 1;
    Exit(True);
  end;
  i := 1;
  while (i <= Length(T)) and (T[i] in ['0'..'9']) do
    Inc(i);
  if (i > 1) and (i + 1 <= Length(T)) and (T[i] = '.') and (T[i + 1] = ' ') then
  begin
    i := Length(fLineStr) - Length(T) + 1;
    FTokenID := tkList;
    // marcador completo "N.": avanzar dígitos + punto
    fRun := i + 1;
    while (fRun <= Length(fLineStr)) and
      (fLineStr[fRun] in ['0'..'9', '.']) do
      Inc(fRun);
    Exit(True);
  end;
end;

procedure TSynMarkdownSyn.InlineToken;
var
  C: Char;
  p, Len: Integer;
begin
  C := fLineStr[fRun];
  Len := Length(fLineStr);
  // Escape
  if (C = '\') and (fRun < Len) then
  begin
    FTokenID := tkText;
    fRun := fRun + 2;
    Exit;
  end;
  // Negrita ** **
  if ((C = '*') or (C = '_')) and (fRun < Len) and (fLineStr[fRun + 1] = C) then
  begin
    if (C = '_') and (fRun > 1) and IsWordChar(fLineStr[fRun - 1]) then
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
      Exit;
    end;
    p := FindClosing(C + C, fRun + 2);
    if p > 0 then
    begin
      FTokenID := tkBold;
      fRun := p + 2;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Tachado ~~
  if (C = '~') and (fRun < Len) and (fLineStr[fRun + 1] = '~') then
  begin
    p := FindClosing('~~', fRun + 2);
    if p > 0 then
    begin
      FTokenID := tkStrike;
      fRun := p + 2;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Cursiva * *
  if C = '*' then
  begin
    p := FindClosingChar('*', fRun + 1);
    if p > 0 then
    begin
      FTokenID := tkItalic;
      fRun := p + 1;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Cursiva _ _ (con bordes de palabra)
  if C = '_' then
  begin
    if (fRun > 1) and IsWordChar(fLineStr[fRun - 1]) then
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
      Exit;
    end;
    p := FindClosingChar('_', fRun + 1);
    if (p > 0) and ((p = Len) or not IsWordChar(fLineStr[p + 1])) then
    begin
      FTokenID := tkItalic;
      fRun := p + 1;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Código ` `
  if C = '`' then
  begin
    p := FindClosingChar('`', fRun + 1);
    if p > 0 then
    begin
      FTokenID := tkCode;
      fRun := p + 1;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Enlaces [t](u) y ![a](u)
  if (C = '[') or ((C = '!') and (fRun < Len) and (fLineStr[fRun + 1] = '[')) then
  begin
    if C = '!' then
      p := fRun + 1
    else
      p := fRun;
    if TryParseLink(p, p) then
    begin
      FTokenID := tkLink;
      fRun := p + 1;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Autolink <...>
  if C = '<' then
  begin
    if TryParseAutolink(fRun, p) then
    begin
      FTokenID := tkLink;
      fRun := p + 1;
    end
    else
    begin
      FTokenID := tkText;
      fRun := fRun + 1;
    end;
    Exit;
  end;
  // Texto plano hasta el próximo char especial
  FTokenID := tkText;
  p := fRun;
  while (p <= Len) and not (fLineStr[p] in ['*', '_', '`', '[', '!', '<', '\']) do
    Inc(p);
  if p = fRun then
    Inc(p);
  fRun := p;
end;

procedure TSynMarkdownSyn.Next;
begin
  fTokenPos := fRun - 1;
  if fRun > Length(fLineStr) then
  begin
    FTokenID := tkNull;
    Exit;
  end;
  if fRun = 1 then
    if TryLineStart then
      Exit;
  InlineToken;
end;

end.
