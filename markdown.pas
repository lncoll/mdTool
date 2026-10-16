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

function ProcessInline(const S: string): string;
var
  i, Len: Integer;
  Res: string;

  function FindClosing(const Src: string; StartPos: Integer;
    const Delim: string): Integer;
  begin
    Result := PosEx(Delim, Src, StartPos);
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
    // Código inline `...`
    if S[i] = '`' then
    begin
      p1 := PosEx('`', S, i + 1);
      if p1 > 0 then
      begin
        Res += '<code>' + EscapeHtml(Copy(S, i + 1, p1 - (i + 1))) +
          '</code>';
        i := p1 + 1;
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
    // URL autolink <http...>
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
  InCode, InPara, InQuote: Boolean;
  InList: Boolean;
  HLevel: Integer;
  IsOrd: Boolean;
  ItemContent: string;
  ItemIndent: Integer;
  ItemStart: Integer;
  ListStack: array of TListLevel;
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

  procedure CloseQuote;
  begin
    if InQuote then
    begin
      ClosePara;
      Result += '</blockquote>' + LineEnding;
      InQuote := False;
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
    InList := True;
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
      SplitTableRow(Trim(Lines[i]), HC);
      SplitTableRow(Trim(Lines[i + 1]), DC);
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
      while (i < Lines.Count) and (Trim(Lines[i]) <> '') and
        (Pos('|', Lines[i]) > 0) and not IsTableDelim(Lines[i]) do
      begin
        RLine := Trim(Lines[i]);
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
    InQuote := False;
    InList := False;
    ParaFirst := -1;
    ParaStart := 0;
    i := 0;
    while i < Lines.Count do
    begin
      Line := Lines[i];
      Trimmed := Trim(Line);

      // Bloque de código cercado ```
      if (Copy(Trimmed, 1, 3) = '```') then
      begin
        if InCode then
        begin
          Result += '</pre>' + LineEnding;
          InCode := False;
        end
        else
        begin
          ClosePara;
          CloseQuote;
          // Si está indentado al contenido del ítem abierto, va anidado
          // en el <li> (sin cerrar la lista).
          if not (InList and (LineIndentOf(Line) >=
            ListStack[High(ListStack)].Indent + 2)) then
            CloseList;
          MarkMap;
          Result += '<pre>' + LineEnding;
          InCode := True;
        end;
        Inc(i);
        Continue;
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
      // Solo a nivel superior (en citas se deja como estaba).
      HLevel := SetextLevel(Trimmed);
      if (HLevel > 0) and InPara and (ParaFirst >= 0) and not InQuote then
      begin
        // Rebobina el <p> abierto y reemite como heading
        SetLength(Result, ParaStart);
        Content := '';
        for k := ParaFirst to i - 1 do
        begin
          if Content <> '' then
            Content += ' ';
          Content += ProcessInline(Trim(Lines[k]));
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
        CloseQuote;
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
         (InList and (LineIndentOf(Line) >=
           ListStack[High(ListStack)].Indent + 2))) and
        (i + 1 < Lines.Count) and IsTableDelim(Lines[i + 1]) then
      begin
        ClosePara;
        CloseQuote;
        if not (InList and (LineIndentOf(Line) >=
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
        CloseQuote;
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

      // Blockquote
      if (Trimmed <> '') and (Trimmed[1] = '>') then
      begin
        Content := Trim(Copy(Trimmed, 2, MaxInt));
        if not InQuote then
        begin
          ClosePara;
          // Cita indentada al contenido del ítem: anidada en el <li>.
          if not (InList and (LineIndentOf(Line) >=
            ListStack[High(ListStack)].Indent + 2)) then
            CloseList;
          MarkMap;
          Result += '<blockquote>' + LineEnding;
          InQuote := True;
        end;;
        if Content = '' then
          ClosePara
        else
        begin
          // Dentro de cita permitimos párrafo simple
          if not InPara then
          begin
            ParaStart := Length(Result);
            ParaFirst := i;
            Result += '<p>' + ProcessInline(Content);
            InPara := True;
          end
          else
            Result += ' ' + ProcessInline(Content);
        end;
        Inc(i);
        // Si la siguiente no es cita, se cerrará al procesarla
        if (i >= Lines.Count) or (Trim(Copy(Trim(Lines[i]), 1, 1)) <> '>') then
        begin
          // peek: Trimmed de la siguiente
          if (i < Lines.Count) and (Trim(Lines[i]) <> '') and
            (Trim(Lines[i])[1] = '>') then
          begin
            // sigue cita, no cerrar
          end
          else
          begin
            ClosePara;
            CloseQuote;
          end;
        end;
        Continue;
      end
      else if InQuote then
      begin
        ClosePara;
        CloseQuote;
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
        if LineIndentOf(Line) < ListStack[High(ListStack)].Indent + 2 then
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
