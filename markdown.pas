unit Markdown;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

type
  TMarkdownLineInfo = record
    HtmlPos: Integer; { offset 0-based en el fragmento HTML }
    MdLine: Integer;  { línea 1-based en el Markdown origen }
  end;
  TMarkdownLineMap = array of TMarkdownLineInfo;

  { Nivel de lista abierta (para anidado por indentación). }
  TListLevel = record
    Indent: Integer;  { indentación del marcador que abrió el nivel }
    Ordered: Boolean;
    Numb: Integer;    { contador para <ol> }
    LiOpen: Boolean;  { hay un <li> sin cerrar en este nivel }
    QDepth: Integer;  { profundidad de cita en la que se abrió }
  end;

{ Convierte Markdown a fragmento HTML (para THtmlViewer). }
function MarkdownToHtml(const Md: string): string;

{ Como MarkdownToHtml, pero además devuelve el mapa
  (offset HTML -> línea Markdown) para sincronizar el cursor. }
function MarkdownToHtmlWithMap(const Md: string;
  out LineMap: TMarkdownLineMap): string;

{ Traduce LineMap de bytes UTF-8 a unidades UTF-16 (las que usa el visor).
  Un solo pase lineal; las entradas deben estar en orden ascendente. }
procedure TranslateLineMapToUtf16(const FragUtf8: string;
  var LineMap: TMarkdownLineMap);

{ Línea Markdown (1-based) del bloque que contiene el offset FragPos
  (unidades de visor). 0 si no hay correspondencia. }
function MarkdownLineAt(const LineMap: TMarkdownLineMap;
  FragPos: Integer): Integer;

{ Hoja de estilos compartida por el visor y la exportación. }
function MarkdownCss: string;

{ Envuelve el fragmento en una página HTML completa (para Exportar). }
function MarkdownToHtmlPage(const Md, Title: string): string;

{ Escapa caracteres especiales HTML. }
function EscapeHtml(const S: string): string;

implementation

function EscapeHtml(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ ¿Parece una dirección de correo (para autolinks <a@b.c>)? }
function IsEmailAddr(const S: string): Boolean;
var
  At, k: Integer;
  Dom: string;
begin
  Result := False;
  At := Pos('@', S);
  // Un solo @, ni al inicio ni al final
  if (At <= 1) or (At <> LastDelimiter('@', S)) or (At = Length(S)) then
    Exit;
  // Sin espacios ni <>
  for k := 1 to Length(S) do
    if S[k] in [' ', #9, '<', '>'] then
      Exit;
  // Dominio con punto interior (no al inicio/fin, sin "..")
  Dom := Copy(S, At + 1, MaxInt);
  if (Pos('.', Dom) < 2) or (Dom[Length(Dom)] = '.') then
    Exit;
  if Pos('..', Dom) > 0 then
    Exit;
  Result := True;
end;

function ProcessInline(const S: string): string;
var
  i, Len, RunLen: Integer;
  Res: string;

  function FindClosing(const Src: string; StartPos: Integer;
    const Delim: string): Integer;
  begin
    Result := PosEx(Delim, Src, StartPos);
  end;

  { Cierre de racha: busca una racha de Delim de longitud EXACTA Need
    (para código inline `..` los cierres de distinta longitud no valen). }
  function FindClosingRun(const Src: string; StartPos: Integer;
    Delim: Char; Need: Integer): Integer;
  var
    p, k: Integer;
  begin
    Result := 0;
    p := StartPos;
    while p <= Length(Src) do
    begin
      p := PosEx(Delim, Src, p);
      if p = 0 then
        Exit;
      k := p;
      while (k <= Length(Src)) and (Src[k] = Delim) do
        Inc(k);
      if k - p = Need then
      begin
        Result := p;
        Exit;
      end;
      p := k; // saltar la racha (un cierre no puede empezar dentro)
    end;
  end;

  { Cierre de marca simple (* o _): salta los pares (** / __), que
    pertenecen al otro nivel de anidado (p. ej. la negrita dentro
    de *cursiva con **negrita** dentro*). }
  function FindClosingSingle(const Src: string; StartPos: Integer;
    Delim: Char): Integer;
  var
    p: Integer;
  begin
    Result := 0;
    p := StartPos;
    while True do
    begin
      p := PosEx(Delim, Src, p);
      if p = 0 then
        Exit;
      if ((p > 1) and (Src[p - 1] = Delim)) or
        ((p < Length(Src)) and (Src[p + 1] = Delim)) then
      begin
        Inc(p);
        Continue;
      end;
      Result := p;
      Exit;
    end;
  end;

  { URL pelada http://..., https://... o www.... Añade el enlace a Res,
    avanza i y devuelve True si había URL válida (extensión GFM). }
  function TryBareLink: Boolean;
  var
    j, k, m, OpenP, CloseP, ContentStart: Integer;
    Pfx, Url, Dom: string;
  begin
    Result := False;
    j := i;
    Pfx := '';
    if (j + 6 <= Len) and (LowerCase(Copy(S, j, 7)) = 'http://') then
      Inc(j, 7)
    else if (j + 7 <= Len) and (LowerCase(Copy(S, j, 8)) = 'https://') then
      Inc(j, 8)
    else if (j + 3 <= Len) and (LowerCase(Copy(S, j, 4)) = 'www.') then
    begin
      Pfx := 'https://';
      Inc(j, 4);
      // Para www. exigir dominio con punto (y que empiece en alfanumérico)
      if (j > Len) or not (S[j] in ['A'..'Z', 'a'..'z', '0'..'9']) then
        Exit;
      k := j;
      while (k <= Len) and
        (S[k] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '.']) do
        Inc(k);
      Dom := Copy(S, j, k - j);
      // Sin el punto final (es puntuación, no parte del dominio)
      while (Dom <> '') and (Dom[Length(Dom)] = '.') do
        Delete(Dom, Length(Dom), 1);
      if (Dom = '') or (Pos('.', Dom) < 2) or
        not (Dom[Length(Dom)] in ['A'..'Z', 'a'..'z', '0'..'9']) then
        Exit;
      if Pos('..', Dom) > 0 then
        Exit;
    end
    else
      Exit;
    ContentStart := j;
    while (j <= Len) and not (S[j] in [' ', #9, #10, #13, '<', '>',
      '"', '''', '`']) do
      Inc(j);
    k := j - 1;
    if k < ContentStart then
      Exit;
    // Recorta puntuación final (.,;:!?) y ')' sin abrir
    while (k >= ContentStart) and (S[k] in ['.', ',', ';', ':', '!', '?']) do
      Dec(k);
    if k < ContentStart then
      Exit;
    OpenP := 0;
    CloseP := 0;
    for m := i to k do
    begin
      if S[m] = '(' then
        Inc(OpenP)
      else if S[m] = ')' then
        Inc(CloseP);
    end;
    while (k >= ContentStart) and (S[k] = ')') and (CloseP > OpenP) do
    begin
      Dec(k);
      Dec(CloseP);
    end;
    if k < ContentStart then
      Exit;
    Url := Copy(S, i, k - i + 1);
    Res += '<a href="' + EscapeHtml(Pfx + Url) + '">' + EscapeHtml(Url) +
      '</a>';
    i := k + 1;
    Result := True;
  end;

var
  CloseP: Integer;
  Alt, Url: string;
  p1, p2: Integer;
begin
  Res := '';
  i := 1;
  Len := Length(S);
  while i <= Len do
  begin
    // Imagen: ![alt](src)
    if (S[i] = '!') and (i + 1 <= Len) and (S[i + 1] = '[') then
    begin
      p1 := PosEx(']', S, i + 2);
      if (p1 > 0) and (p1 + 1 <= Len) and (S[p1 + 1] = '(') then
      begin
        p2 := PosEx(')', S, p1 + 2);
        if p2 > 0 then
        begin
          Alt := Copy(S, i + 2, p1 - (i + 2));
          Url := Copy(S, p1 + 2, p2 - (p1 + 2));
          Res += '<img src="' + EscapeHtml(Url) + '" alt="' +
            EscapeHtml(Alt) + '">';
          i := p2 + 1;
          Continue;
        end;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // Enlace: [texto](url)
    if S[i] = '[' then
    begin
      p1 := PosEx(']', S, i + 1);
      if (p1 > 0) and (p1 + 1 <= Len) and (S[p1 + 1] = '(') then
      begin
        p2 := PosEx(')', S, p1 + 2);
        if p2 > 0 then
        begin
          Alt := Copy(S, i + 1, p1 - (i + 1));
          Url := Copy(S, p1 + 2, p2 - (p1 + 2));
          Res += '<a href="' + EscapeHtml(Url) + '">' +
            ProcessInline(Alt) + '</a>';
          i := p2 + 1;
          Continue;
        end;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // Código inline `...` (el cierre exige la misma racha de la apertura,
    // así ``code `x` here`` no se corta en el primer backtick suelto)
    if S[i] = '`' then
    begin
      RunLen := 1;
      while (i + RunLen <= Len) and (S[i + RunLen] = '`') do
        Inc(RunLen);
      p1 := FindClosingRun(S, i + RunLen, '`', RunLen);
      if p1 > 0 then
      begin
        Res += '<code>' + EscapeHtml(Copy(S, i + RunLen, p1 - (i + RunLen))) +
          '</code>';
        i := p1 + RunLen;
        Continue;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // Negrita **..** o __..__
    if (i + 1 <= Len) and (((S[i] = '*') and (S[i + 1] = '*')) or
      ((S[i] = '_') and (S[i + 1] = '_'))) then
    begin
      // ***x*** o ___x___: negrita y cursiva a la vez (cierre triple).
      // Sin esto, el cierre doble "muerde" una marca y deja sueltos *x*.
      if (i + 2 <= Len) and (S[i + 2] = S[i]) then
      begin
        CloseP := FindClosing(S, i + 3, Copy(S, i, 3));
        if CloseP > 0 then
        begin
          Res += '<b><i>' + ProcessInline(Copy(S, i + 3, CloseP - (i + 3))) +
            '</i></b>';
          i := CloseP + 3;
          Continue;
        end;
        // Sin cierre triple: se intenta la vía normal de negrita
      end;
      CloseP := FindClosing(S, i + 2, Copy(S, i, 2));
      if CloseP > 0 then
      begin
        Res += '<b>' + ProcessInline(Copy(S, i + 2, CloseP - (i + 2))) +
          '</b>';
        i := CloseP + 2;
        Continue;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // Cursiva *..* o _.._
    if (S[i] = '*') or (S[i] = '_') then
    begin
      CloseP := FindClosingSingle(S, i + 1, S[i]);
      if CloseP > 0 then
      begin
        Res += '<i>' + ProcessInline(Copy(S, i + 1, CloseP - (i + 1))) +
          '</i>';
        i := CloseP + 1;
        Continue;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // Tachado ~~..~~
    if (i + 1 <= Len) and (S[i] = '~') and (S[i + 1] = '~') then
    begin
      CloseP := FindClosing(S, i + 2, '~~');
      if CloseP > 0 then
      begin
        Res += '<strike>' + ProcessInline(Copy(S, i + 2, CloseP - (i + 2))) +
          '</strike>';
        i := CloseP + 2;
        Continue;
      end;
      Res += EscapeHtml(S[i]);
      Inc(i);
      Continue;
    end;
    // URL pelada http://..., https://... o www.... (extensión GFM)
    if TryBareLink then
      Continue;
    // URL autolink <http...> y email <a@b.c>
    if S[i] = '<' then
    begin
      p1 := PosEx('>', S, i + 1);
      if p1 > 0 then
      begin
        Alt := Copy(S, i + 1, p1 - (i + 1));
        if (Pos('://', Alt) > 0) or (Pos('mailto:', Alt) = 1) then
        begin
          Res += '<a href="' + EscapeHtml(Alt) + '">' + EscapeHtml(Alt) +
            '</a>';
          i := p1 + 1;
          Continue;
        end;
        if IsEmailAddr(Alt) then
        begin
          Res += '<a href="mailto:' + EscapeHtml(Alt) + '">' +
            EscapeHtml(Alt) + '</a>';
          i := p1 + 1;
          Continue;
        end;
      end;
      Res += '&lt;';
      Inc(i);
      Continue;
    end;
    if S[i] = '&' then
    begin
      Res += '&amp;';
      Inc(i);
      Continue;
    end;
    if S[i] = '<' then
    begin
      Res += '&lt;';
      Inc(i);
      Continue;
    end;
    if S[i] = '>' then
    begin
      Res += '&gt;';
      Inc(i);
      Continue;
    end;
    if S[i] = '"' then
    begin
      Res += '&quot;';
      Inc(i);
      Continue;
    end;
    Res += S[i];
    Inc(i);
  end;
  Result := Res;
end;

function IsHr(const Line: string): Boolean;
var
  T: string;
  i, Count: Integer;
  C: Char;
begin
  T := Trim(Line);
  if Length(T) < 3 then
    Exit(False);
  C := T[1];
  if not (C in ['-', '*', '_']) then
    Exit(False);
  Count := 0;
  for i := 1 to Length(T) do
  begin
    if T[i] = C then
      Inc(Count)
    else if T[i] <> ' ' then
      Exit(False);
  end;
  Result := Count >= 3;
end;

{ Línea de subrayado setext: solo '=' (h1) o solo '-' (h2). }
function SetextLevel(const TrimmedLine: string): Integer;
var
  k: Integer;
begin
  Result := 0;
  if TrimmedLine = '' then
    Exit;
  if TrimmedLine[1] = '=' then
    Result := 1
  else if TrimmedLine[1] = '-' then
    Result := 2
  else
    Exit;
  for k := 2 to Length(TrimmedLine) do
    if TrimmedLine[k] <> TrimmedLine[1] then
      Exit(0);
end;

function HeadingLevel(const Line: string; out Content: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  i := 1;
  while (i <= Length(Line)) and (Line[i] = '#') do
    Inc(i);
  Result := i - 1;
  if (Result >= 1) and (Result <= 6) then
  begin
    if (i <= Length(Line)) and (Line[i] = ' ') then
      Content := Trim(Copy(Line, i + 1, MaxInt))
    else
      Result := 0; // "#texto" sin espacio no es heading
  end
  else
    Result := 0;
end;

{ Indentación en columnas (tabulador = 4). Devuelve también cuántos
  caracteres del inicio ocupa. }
procedure MeasureIndent(const Line: string; out Indent, CharCount: Integer);
var
  k: Integer;
begin
  Indent := 0;
  k := 1;
  while (k <= Length(Line)) and (Line[k] in [' ', #9]) do
  begin
    if Line[k] = #9 then
      Inc(Indent, 4)
    else
      Inc(Indent);
    Inc(k);
  end;
  CharCount := k - 1;
end;

{ Solo la indentación en columnas. }
function LineIndentOf(const Line: string): Integer;
var
  Dummy: Integer;
begin
  MeasureIndent(Line, Result, Dummy);
end;

function ListItem(const Line: string; out Ordered: Boolean;
  out Content: string; out Indent: Integer; out StartNumb: Integer): Boolean;
var
  T: string;
  i, CharCount: Integer;
begin
  Result := False;
  Ordered := False;
  StartNumb := 1;
  MeasureIndent(Line, Indent, CharCount);
  T := TrimLeft(Copy(Line, CharCount + 1, MaxInt));
  if T = '' then
    Exit;
  if (T[1] = '-') or (T[1] = '*') or (T[1] = '+') then
  begin
    if (Length(T) >= 2) and (T[2] = ' ') then
    begin
      Content := Trim(Copy(T, 3, MaxInt));
      Result := True;
      Ordered := False;
      Exit;
    end;
  end;
  // Lista ordenada: "1. texto" (vale cualquier número inicial)
  i := 1;
  while (i <= Length(T)) and (T[i] in ['0'..'9']) do
    Inc(i);
  if (i > 1) and (i + 1 <= Length(T)) and (T[i] = '.') and (T[i + 1] = ' ') then
  begin
    Content := Trim(Copy(T, i + 2, MaxInt));
    StartNumb := StrToIntDef(Copy(T, 1, i - 1), 1);
    if StartNumb < 1 then
      StartNumb := 1;
    Result := True;
    Ordered := True;
  end;
end;

{ --- Tablas GFM --- }

procedure SplitTableRow(const Line: string; Cells: TStrings);
var
  Work: string;
  i, Start: Integer;
begin
  Cells.Clear;
  // Protege \| para no partir la celda por ahí
  Work := StringReplace(Line, '\|', #1, [rfReplaceAll]);
  Start := 1;
  for i := 1 to Length(Work) do
    if Work[i] = '|' then
    begin
      Cells.Add(Copy(Work, Start, i - Start));
      Start := i + 1;
    end;
  Cells.Add(Copy(Work, Start, MaxInt));
  for i := 0 to Cells.Count - 1 do
    Cells[i] := StringReplace(Trim(Cells[i]), #1, '|', [rfReplaceAll]);
  // Pipes exteriores opcionales generan celdas vacías: se descartan
  if (Cells.Count > 0) and (Cells[0] = '') then
    Cells.Delete(0);
  if (Cells.Count > 0) and (Cells[Cells.Count - 1] = '') then
    Cells.Delete(Cells.Count - 1);
end;

function IsDelimCell(const C: string): Boolean;
var
  T: string;
  k: Integer;
begin
  Result := False;
  T := Trim(C);
  if (T <> '') and (T[1] = ':') then
    Delete(T, 1, 1);
  if (T <> '') and (T[Length(T)] = ':') then
    Delete(T, Length(T), 1);
  if T = '' then
    Exit;
  for k := 1 to Length(T) do
    if T[k] <> '-' then
      Exit;
  Result := True;
end;

function ColAlign(const C: string): string;
var
  T: string;
  L, R: Boolean;
begin
  T := Trim(C);
  L := (T <> '') and (T[1] = ':');
  R := (T <> '') and (T[Length(T)] = ':');
  if L and R then
    Result := 'center'
  else if R then
    Result := 'right'
  else if L then
    Result := 'left'
  else
    Result := '';
end;

function AlignAttr(const A: string): string;
begin
  if A = '' then
    Result := ''
  else
    Result := ' align="' + A + '"';
end;

function IsTableDelim(const Line: string): Boolean;
var
  Cells: TStringList;
  k: Integer;
begin
  Result := False;
  if Pos('|', Line) = 0 then
    Exit;
  Cells := TStringList.Create;
  try
    SplitTableRow(Line, Cells);
    if Cells.Count = 0 then
      Exit;
    for k := 0 to Cells.Count - 1 do
      if not IsDelimCell(Cells[k]) then
        Exit;
    Result := True;
  finally
    Cells.Free;
  end;
end;

{ CSS compartido visor + exportación (HtmlViewer soporta style sheets). }
function MarkdownCss: string;
begin
  Result :=
    'body{font-family:sans-serif;line-height:1.5;margin:1em}' +
    'h1,h2,h3{line-height:1.25}' +
    'pre{background-color:#D8E6F9;font-family:monospace;padding:1em;' +
    'overflow:auto;border-radius:8px}' +
    'code{background-color:#D8E6F9;font-family:monospace;' +
    'padding-left:0.2em;padding-right:0.2em}' +
    'blockquote{background-color:#EDF2FA;border-left:4px solid #9DB8D9;' +
    'margin-left:0;margin-right:0;padding:0.5em 1em;color:#333333;' +
    'border-radius:8px}' +
    'table{border-collapse:collapse;margin-top:1em;margin-bottom:1em}' +
    'ol,ul{margin-top:0;margin-bottom:1em;padding-left:2.5em}' +
    'li{margin:0;padding:0}' +
    'ol{list-style-type:none}' +
    'th,td{border:1px solid #B0B8C4;padding:4px 10px}' +
    'thead tr{background-color:#E3E9F2}' +
    'tbody tr.alt{background-color:#F2F5F9}' +
    'a{color:#0B5CAD}';
end;

function MarkdownToHtmlWithMap(const Md: string;
  out LineMap: TMarkdownLineMap): string;
var
  Lines: TStringList;
  i: Integer;
  Line, Trimmed, Content: string;
  InCode, InPara: Boolean;
  InList: Boolean;
  HLevel: Integer;
  IsOrd: Boolean;
  ItemContent: string;
  ItemIndent: Integer;
  ItemStart: Integer;
  ListStack: array of TListLevel;
  QuoteBase: array of Integer; { niveles de lista al abrir cada nivel de cita }
  QDepth: Integer;     { niveles de cita de la línea actual }
  QRest: string;       { la línea sin los marcadores '>' pelados }
  QRIndent: Integer;   { indentación de la línea antes del '>' }
  FenceQDepth: Integer; { profundidad de cita donde se abrió la valla }
  FenceLen: Integer; { longitud de la valla de apertura (`..) o 0 }
  ParaFirst: Integer; { línea 0-based donde empezó el <p> abierto }
  ParaStart: Integer; { offset HTML donde empieza el <p> abierto }
  k: Integer;

  { Registra el bloque que empieza en la línea ALine (0-based, i si < 0):
    offset actual del HTML (0-based) -> línea Markdown (1-based). }
  procedure MarkMap(ALine: Integer = -1);
  begin
    SetLength(LineMap, Length(LineMap) + 1);
    LineMap[High(LineMap)].HtmlPos := Length(Result);
    if ALine >= 0 then
      LineMap[High(LineMap)].MdLine := ALine + 1
    else
      LineMap[High(LineMap)].MdLine := i + 1;
  end;

  { Números romanos (vale para cualquier N >= 1). }
  function RomanNumeral(N: Integer; Upper: Boolean): string;
  const
    Vals: array[0..12] of Integer =
      (1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1);
    Syms: array[0..12] of string =
      ('M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I');
  var
    k: Integer;
  begin
    Result := '';
    if N < 1 then
      N := 1;
    for k := 0 to High(Vals) do
      while N >= Vals[k] do
      begin
        Result += Syms[k];
        Dec(N, Vals[k]);
      end;
    if not Upper then
      Result := LowerCase(Result);
  end;

  { Letras estilo planilla: 1=a .. 26=z, 27=aa, 28=ab ... }
  function AlphaNumeral(N: Integer; Upper: Boolean): string;
  begin
    Result := '';
    if N < 1 then
      N := 1;
    while N > 0 do
    begin
      Dec(N);
      Result := Chr(Ord('a') + (N mod 26)) + Result;
      N := N div 26;
    end;
    if Upper then
      Result := UpperCase(Result);
  end;

  { Marcador según profundidad (1-based): 1,2,3... / i,ii... / a,b... /
    I,II... / A,B... (cíclico a partir del nivel 6). }
  function OrderedMarker(Depth, N: Integer): string;
  begin
    case ((Depth - 1) mod 5) of
      0: Result := IntToStr(N);
      1: Result := RomanNumeral(N, False);
      2: Result := AlphaNumeral(N, False);
      3: Result := RomanNumeral(N, True);
    else
      Result := AlphaNumeral(N, True);
    end;
  end;

  procedure ClosePara;
  begin
    if InPara then
    begin
      Result += '</p>' + LineEnding;
      InPara := False;
      ParaFirst := -1;
    end;
  end;

  procedure CloseList;
  var
    L: Integer;
  begin
    ClosePara;
    // Cierra todos los niveles (con sus <li> pendientes)
    for L := High(ListStack) downto 0 do
    begin
      if ListStack[L].LiOpen then
        Result += '</li>' + LineEnding;
      if ListStack[L].Ordered then
        Result += '</ol>' + LineEnding
      else
        Result += '</ul>' + LineEnding;
    end;
    SetLength(ListStack, 0);
    InList := False;
  end;

  { Cierra el nivel superior (con su <li> pendiente). }
  procedure CloseListLevel;
  var
    T: Integer;
  begin
    T := High(ListStack);
    if T < 0 then
      Exit;
    if ListStack[T].LiOpen then
      Result += '</li>' + LineEnding;
    if ListStack[T].Ordered then
      Result += '</ol>' + LineEnding
    else
      Result += '</ul>' + LineEnding;
    SetLength(ListStack, T);
    InList := Length(ListStack) > 0;
  end;

  { Abre un (sub)nivel de lista. StartNumb es el número del primer
    ítem si es ordenada (las listas que no empiezan en 1 lo respetan). }
  procedure OpenListLevel(IsOrd: Boolean; Indent, StartNumb: Integer);
  var
    T: Integer;
  begin
    if IsOrd then
      Result += '<ol>' + LineEnding
    else
      Result += '<ul>' + LineEnding;
    T := Length(ListStack);
    SetLength(ListStack, T + 1);
    ListStack[T].Indent := Indent;
    ListStack[T].Ordered := IsOrd;
    if StartNumb < 1 then
      StartNumb := 1;
    ListStack[T].Numb := StartNumb - 1;
    ListStack[T].LiOpen := False;
    ListStack[T].QDepth := Length(QuoteBase);
    InList := True;
  end;

  { Pela niveles de cita '>' al inicio (tras espacios), hasta MaxDepth:
    devuelve cuántos hay y el resto de la línea (sin el '>' ni un
    espacio posterior). }
  procedure PeelQuote(const S: string; MaxDepth: Integer;
    out Depth: Integer; out Rest: string);
  var
    T: string;
  begin
    Depth := 0;
    T := TrimLeft(S);
    while (Depth < MaxDepth) and (T <> '') and (T[1] = '>') do
    begin
      Inc(Depth);
      Delete(T, 1, 1);
      if (T <> '') and (T[1] = ' ') then
        Delete(T, 1, 1);
    end;
    Rest := T;
  end;

  { Contenido de una línea del documento ya sin los '>' de cita:
    necesario para tablas/setext, que leen líneas posteriores o
    anteriores que aún no ha pelado el bucle principal. }
  function PeeledAt(Index: Integer): string;
  var
    D: Integer;
  begin
    PeelQuote(Lines[Index], Length(QuoteBase), D, Result);
  end;

  { Cierra UN nivel de cita (con sus listas internas). }
  procedure CloseQuoteLevel;
  begin
    ClosePara;
    while (Length(ListStack) > QuoteBase[High(QuoteBase)]) do
      CloseListLevel;
    Result += '</blockquote>' + LineEnding;
    SetLength(QuoteBase, Length(QuoteBase) - 1);
  end;

  { Cierra todos los niveles de cita. }
  procedure CloseQuote;
  begin
    while Length(QuoteBase) > 0 do
      CloseQuoteLevel;
  end;

  { Abre un nivel de cita (RawIndent = indentación de la línea original,
    para decidir si va anidada en un <li> abierto). }
  procedure OpenQuoteLevel(RawIndent: Integer);
  begin
    ClosePara;
    // Solo se cierra la lista si la cita NO va anidada en el ítem
    if (Length(QuoteBase) = 0) and InList and
      (RawIndent < ListStack[High(ListStack)].Indent + 2) then
      CloseList;
    MarkMap;
    Result += '<blockquote>' + LineEnding;
    SetLength(QuoteBase, Length(QuoteBase) + 1);
    QuoteBase[High(QuoteBase)] := Length(ListStack);
  end;

  procedure EmitTable;
  var
    HC, DC, RC, Aligns: TStringList;
    c, N, RowIdx: Integer;
    RLine: string;
  begin
    MarkMap; // la tabla empieza en Lines[i]
    HC := TStringList.Create;
    DC := TStringList.Create;
    RC := TStringList.Create;
    Aligns := TStringList.Create;
    try
      SplitTableRow(Trim(PeeledAt(i)), HC);
      SplitTableRow(Trim(PeeledAt(i + 1)), DC);
      N := HC.Count;
      for c := 0 to N - 1 do
        if c < DC.Count then
          Aligns.Add(ColAlign(DC[c]))
        else
          Aligns.Add('');
      Result += '<table>' + LineEnding +
        '<thead>' + LineEnding + '<tr>' + LineEnding;
      for c := 0 to N - 1 do
        Result += '<th' + AlignAttr(Aligns[c]) + '>' +
          ProcessInline(HC[c]) + '</th>' + LineEnding;
      Result += '</tr>' + LineEnding + '</thead>' + LineEnding +
        '<tbody>' + LineEnding;
      Inc(i, 2);
      RowIdx := 0;
      while (i < Lines.Count) and (Trim(PeeledAt(i)) <> '') and
        (Pos('|', PeeledAt(i)) > 0) and not IsTableDelim(PeeledAt(i)) do
      begin
        RLine := Trim(PeeledAt(i));
        SplitTableRow(RLine, RC);
        if Odd(RowIdx) then
          Result += '<tr class="alt">' + LineEnding
        else
          Result += '<tr>' + LineEnding;
        for c := 0 to N - 1 do
        begin
          if c < RC.Count then
            RLine := RC[c]
          else
            RLine := '';
          Result += '<td' + AlignAttr(Aligns[c]) + '>' +
            ProcessInline(RLine) + '</td>' + LineEnding;
        end;
        Result += '</tr>' + LineEnding;
        Inc(RowIdx);
        Inc(i);
      end;
      Result += '</tbody></table>' + LineEnding;
    finally
      HC.Free;
      DC.Free;
      RC.Free;
      Aligns.Free;
    end;
  end;

begin
  Result := '';
  LineMap := nil;
  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(Md, #13#10, #10, [rfReplaceAll]);
    Lines.Text := StringReplace(Lines.Text, #13, #10, [rfReplaceAll]);
    InCode := False;
    InPara := False;
    InList := False;
    FenceLen := 0;
    FenceQDepth := 0;
    ParaFirst := -1;
    ParaStart := 0;
    i := 0;
    while i < Lines.Count do
    begin
      Line := Lines[i];

      // Dentro de un cercado, la línea vacía no cierra nada (ni el
      // bloque ni la cita en la que se abrió).
      if InCode and (Trim(Line) = '') then
      begin
        Result += EscapeHtml(Line) + LineEnding;
        Inc(i);
        Continue;
      end;

      // Fase de citas: pela los marcadores '>' iniciales y ajusta la
      // pila de <blockquote> a la profundidad de la línea. Dentro de un
      // cercado solo se pela la profundidad donde se abrió la valla.
      QRIndent := 0;
      while (QRIndent < Length(Line)) and (Line[QRIndent + 1] = ' ') do
        Inc(QRIndent);
      if InCode then
        PeelQuote(Line, FenceQDepth, QDepth, QRest)
      else
        PeelQuote(Line, MaxInt, QDepth, QRest);
      if InCode and (QDepth < FenceQDepth) then
      begin
        // La línea sale de la cita donde se abrió la valla: cierra el
        // bloque y la reprocesa como línea normal.
        Result += '</pre>' + LineEnding;
        InCode := False;
        FenceLen := 0;
        QDepth := 0;
        QRest := Line;
      end;
      if QDepth > 0 then
        Line := QRest;
      Trimmed := Trim(Line);

      // Ajusta la pila de citas a la profundidad de la línea (abre o
      // cierra <blockquote> según haga falta; el contenido de la línea
      // se procesa después con todos los elementos normales).
      while Length(QuoteBase) > QDepth do
        CloseQuoteLevel;
      while Length(QuoteBase) < QDepth do
        OpenQuoteLevel(QRIndent);

      // Bloque de código cercado ``` (la valla de cierre debe ser
      // al menos tan larga como la de apertura y sin texto detrás)
      if (Copy(Trimmed, 1, 3) = '```') then
      begin
        k := 1;
        while (k <= Length(Trimmed)) and (Trimmed[k] = '`') do
          Inc(k);
        if InCode and ((k - 1 < 3) or (k - 1 < FenceLen) or
          (Trim(Copy(Trimmed, k, MaxInt)) <> '')) then
        begin
          // No es cierre válido: es contenido del bloque
        end
        else if InCode then
        begin
          Result += '</pre>' + LineEnding;
          InCode := False;
          FenceLen := 0;
          Inc(i);
          Continue;
        end
        else
        begin
          ClosePara;
          // Si está indentado al contenido del ítem abierto, va anidado
          // en el <li> (sin cerrar la lista). La indentación relevante
          // es la de la línea original (antes del '>' pelado).
          if not (InList and (QRIndent >=
            ListStack[High(ListStack)].Indent + 2)) then
            CloseList;
          MarkMap;
          Result += '<pre>' + LineEnding;
          InCode := True;
          FenceLen := k - 1;
          FenceQDepth := QDepth; // recuerda la cita en la que se abrió
          Inc(i);
          Continue;
        end;
      end;

      if InCode then
      begin
        Result += EscapeHtml(Line) + LineEnding;
        Inc(i);
        Continue;
      end;

      // Línea vacía: cierra párrafo (pero no lista/cita aún)
      if Trimmed = '' then
      begin
        ClosePara;
        Inc(i);
        Continue;
      end;

      // Headings setext: === / --- bajo un párrafo lo convierten en h1/h2.
      // Va antes que HR: '---' tras párrafo es subrayado, no línea.
      HLevel := SetextLevel(Trimmed);
      if (HLevel > 0) and InPara and (ParaFirst >= 0) then
      begin
        // Rebobina el <p> abierto y reemite como heading
        SetLength(Result, ParaStart);
        Content := '';
        for k := ParaFirst to i - 1 do
        begin
          if Content <> '' then
            Content += ' ';
          Content += ProcessInline(PeeledAt(k));
        end;
        Result += '<h' + IntToStr(HLevel) + '>' + Content +
          '</h' + IntToStr(HLevel) + '>' + LineEnding;
        MarkMap(ParaFirst);
        InPara := False;
        ParaFirst := -1;
        Inc(i);
        Continue;
      end;

      // HR
      if IsHr(Line) then
      begin
        ClosePara;
        CloseList;
        MarkMap;
        Result += '<hr>' + LineEnding;
        Inc(i);
        Continue;
      end;

      // Tabla GFM: cabecera con '|' + fila delimitadora.
      // Indentada al contenido del ítem va anidada en el <li>.
      if (Pos('|', Line) > 0) and (Copy(Trimmed, 1, 1) <> #9) and
        ((Copy(Line, 1, 4) <> '    ') or
         (InList and (QRIndent >=
           ListStack[High(ListStack)].Indent + 2))) and
        (i + 1 < Lines.Count) and IsTableDelim(PeeledAt(i + 1)) then
      begin
        ClosePara;
        if not (InList and (QRIndent >=
          ListStack[High(ListStack)].Indent + 2)) then
          CloseList;
        EmitTable; // avanza i hasta la primera línea tras la tabla
        Continue;
      end;

      // Headings
      HLevel := HeadingLevel(Trimmed, Content);
      if HLevel > 0 then
      begin
        ClosePara;
        CloseList;
        MarkMap;
        // Quita cierre opcional ### al final
        while (Content <> '') and (Content[Length(Content)] = '#') do
          Content := TrimRight(Copy(Content, 1, Length(Content) - 1));
        Result += '<h' + IntToStr(HLevel) + '>' + ProcessInline(Content) +
          '</h' + IntToStr(HLevel) + '>' + LineEnding;
        Inc(i);
        Continue;
      end;

      // Listas. Los números de las ordenadas se emiten como texto
      // ("1. ", "2. ", ...): el motor ignora TA_BASELINE al dibujar sus
      // marcadores y los deja una línea bajos. Con list-style-type:none
      // no dibuja marcador y el número fluye con el texto, alineado.
      // La indentación define el nivel (listas anidadas); el </li> se
      // difiere para que las sublistas queden dentro del ítem padre.
      // Una marca con indentación 4+ sin lista abierta es código (como antes).
      if ListItem(Line, IsOrd, ItemContent, ItemIndent, ItemStart) then
      begin
        ClosePara;
        if (Length(ListStack) = 0) and (ItemIndent >= 4) then
        begin
          // Sangrado de código sin lista abierta: no es lista.
          // (cae al tratamiento de código indentado de abajo)
        end
        else
        begin
          // Cierra niveles menos indentados que el ítem
          while (Length(ListStack) > 0) and
            (ItemIndent < ListStack[High(ListStack)].Indent) do
            CloseListLevel;
          if (Length(ListStack) = 0) or
            (ItemIndent >= ListStack[High(ListStack)].Indent + 2) then
            OpenListLevel(IsOrd, ItemIndent, ItemStart) // nueva o sublista
          else if IsOrd <> ListStack[High(ListStack)].Ordered then
          begin
            // Mismo nivel, otro tipo: cierra y reabre
            CloseListLevel;
            OpenListLevel(IsOrd, ItemIndent, ItemStart);
          end;
          // Si el nivel tenía un <li> abierto, ciérralo antes del nuevo
          if ListStack[High(ListStack)].LiOpen then
            Result += '</li>' + LineEnding;
          MarkMap; // cada ítem apunta a su línea
          if ListStack[High(ListStack)].Ordered then
          begin
            Inc(ListStack[High(ListStack)].Numb);
            Result += '<li>' + OrderedMarker(Length(ListStack),
              ListStack[High(ListStack)].Numb) + '. ' +
              ProcessInline(ItemContent);
          end
          else
            Result += '<li>' + ProcessInline(ItemContent);
          Result += LineEnding;
          ListStack[High(ListStack)].LiOpen := True;
          Inc(i);
          Continue;
        end;
      end
      else if InList then
      begin
        // Fin de lista... salvo contenido indentado al ítem abierto
        // (párrafo, cita o código anidados: se emiten dentro del <li>).
        // La indentación relevante es la de la línea original (antes
        // del '>' pelado): así una cita dentro de un ítem no cierra la
        // lista.
        if QRIndent < ListStack[High(ListStack)].Indent + 2 then
          CloseList;
        // Si no: sigue dentro del <li> abierto (lo gestionan los
        // tratamientos de párrafo/cita/código de abajo).
      end;

      // Código indentado (4 espacios)
      if (Copy(Line, 1, 4) = '    ') and (Trimmed <> '') then
      begin
        ClosePara;
        MarkMap;
        Result += '<pre>' + EscapeHtml(Copy(Line, 5, MaxInt)) + '</pre>' +
          LineEnding;
        Inc(i);
        Continue;
      end;

      // Párrafo normal. "<br>" si termina en dos espacios
      if not InPara then
      begin
        MarkMap;
        ParaStart := Length(Result);
        ParaFirst := i;
        Result += '<p>' + ProcessInline(Trimmed);
        InPara := True;
      end
      else
      begin
        if (Length(Line) >= 2) and
          (Copy(Line, Length(Line) - 1, 2) = '  ') then
          Result += '<br>' + LineEnding + ProcessInline(Trimmed)
        else
          Result += ' ' + ProcessInline(Trimmed);
      end;
      Inc(i);
    end;
    ClosePara;
    CloseQuote;
    CloseList;
    if InCode then
      Result += '</pre>' + LineEnding;
  finally
    Lines.Free;
  end;
end;

function MarkdownToHtml(const Md: string): string;
var
  Dummy: TMarkdownLineMap;
begin
  Result := MarkdownToHtmlWithMap(Md, Dummy);
end;

procedure TranslateLineMapToUtf16(const FragUtf8: string;
  var LineMap: TMarkdownLineMap);
var
  i, u, k: Integer;
  B: Byte;
begin
  // Las entradas se generan en orden ascendente: basta un pase lineal.
  // Solo los bytes líderes UTF-8 suman unidades UTF-16 (los de
  // continuación $80..$BF no; los de 4 bytes suman 2 por el subrogado).
  u := 0;
  k := 0;
  i := 1;
  while (k <= High(LineMap)) and (i <= Length(FragUtf8) + 1) do
  begin
    while (k <= High(LineMap)) and (LineMap[k].HtmlPos <= i - 1) do
    begin
      LineMap[k].HtmlPos := u;
      Inc(k);
    end;
    if i > Length(FragUtf8) then
      Break;
    B := Byte(FragUtf8[i]);
    if B < $80 then
      Inc(u)
    else if B >= $C0 then
      if B >= $F0 then
        Inc(u, 2)
      else
        Inc(u);
    Inc(i);
  end;
  // Entradas residuales (más allá del final): al final del fragmento.
  while k <= High(LineMap) do
  begin
    LineMap[k].HtmlPos := u;
    Inc(k);
  end;
end;

function MarkdownLineAt(const LineMap: TMarkdownLineMap;
  FragPos: Integer): Integer;
var
  k: Integer;
begin
  // Entradas ascendentes: la última con HtmlPos <= FragPos manda.
  Result := 0;
  for k := 0 to High(LineMap) do
    if LineMap[k].HtmlPos <= FragPos then
      Result := LineMap[k].MdLine
    else
      Break;
end;

function MarkdownToHtmlPage(const Md, Title: string): string;
begin
  Result :=
    '<!DOCTYPE html>' + LineEnding +
    '<html><head><meta charset="utf-8">' +
    '<title>' + EscapeHtml(Title) + '</title>' +
    '<style>' + MarkdownCss +
    'body{max-width:800px;margin:2em auto;padding:0 1em}' +
    '</style>' +
    '</head><body>' + LineEnding +
    MarkdownToHtml(Md) +
    LineEnding + '</body></html>' + LineEnding;
end;

end.
