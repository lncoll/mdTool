unit Markdown;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

{ Convierte Markdown a fragmento HTML (para THtmlViewer). }
function MarkdownToHtml(const Md: string): string;

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
      CloseP := FindClosing(S, i + 1, S[i]);
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

function ListItem(const Line: string; out Ordered: Boolean;
  out Content: string): Boolean;
var
  T: string;
  i: Integer;
begin
  Result := False;
  Ordered := False;
  T := TrimLeft(Line);
  if T = '' then
    Exit;
  // No lista: línea indentada 4+ espacios se trata como código (se gestiona fuera)
  if (Length(Line) > 0) and (Line[1] = ' ') and
    (Length(Line) - Length(T) >= 4) then
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
  // Lista ordenada: "1. texto"
  i := 1;
  while (i <= Length(T)) and (T[i] in ['0'..'9']) do
    Inc(i);
  if (i > 1) and (i + 1 <= Length(T)) and (T[i] = '.') and (T[i + 1] = ' ') then
  begin
    Content := Trim(Copy(T, i + 2, MaxInt));
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
    'th,td{border:1px solid #B0B8C4;padding:4px 10px}' +
    'thead tr{background-color:#E3E9F2}' +
    'tbody tr.alt{background-color:#F2F5F9}' +
    'a{color:#0B5CAD}';
end;

function MarkdownToHtml(const Md: string): string;
var
  Lines: TStringList;
  i: Integer;
  Line, Trimmed, Content: string;
  InCode, InPara, InQuote: Boolean;
  InList: Boolean;
  ListOrdered: Boolean;
  CodeLang: string;
  HLevel: Integer;
  IsOrd: Boolean;
  ItemContent: string;

  procedure ClosePara;
  begin
    if InPara then
    begin
      Result += '</p>' + LineEnding;
      InPara := False;
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
  begin
    if InList then
    begin
      ClosePara;
      if ListOrdered then
        Result += '</ol>' + LineEnding
      else
        Result += '</ul>' + LineEnding;
      InList := False;
    end;
  end;

  procedure EmitTable;
  var
    HC, DC, RC: TStringList;
    Aligns: array of string;
    c, N, RowIdx: Integer;
    RLine: string;
  begin
    HC := TStringList.Create;
    DC := TStringList.Create;
    RC := TStringList.Create;
    try
      SplitTableRow(Trim(Lines[i]), HC);
      SplitTableRow(Trim(Lines[i + 1]), DC);
      N := HC.Count;
      SetLength(Aligns, N);
      for c := 0 to N - 1 do
        if c < DC.Count then
          Aligns[c] := ColAlign(DC[c])
        else
          Aligns[c] := '';
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
    end;
  end;

begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(Md, #13#10, #10, [rfReplaceAll]);
    Lines.Text := StringReplace(Lines.Text, #13, #10, [rfReplaceAll]);
    InCode := False;
    InPara := False;
    InQuote := False;
    InList := False;
    CodeLang := '';
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
          CloseList;
          CodeLang := Trim(Copy(Trimmed, 4, MaxInt));
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

      // HR
      if IsHr(Line) then
      begin
        ClosePara;
        CloseQuote;
        CloseList;
        Result += '<hr>' + LineEnding;
        Inc(i);
        Continue;
      end;

      // Tabla GFM: cabecera con '|' + fila delimitadora
      if (Pos('|', Line) > 0) and (Copy(Line, 1, 4) <> '    ') and
        (Copy(Trimmed, 1, 1) <> #9) and (i + 1 < Lines.Count) and
        IsTableDelim(Lines[i + 1]) then
      begin
        ClosePara;
        CloseQuote;
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
          CloseList;
          Result += '<blockquote>' + LineEnding;
          InQuote := True;
        end;
        if Content = '' then
          ClosePara
        else
        begin
          // Dentro de cita permitimos párrafo simple
          if not InPara then
          begin
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

      // Listas
      if ListItem(Line, IsOrd, ItemContent) then
      begin
        ClosePara;
        if not InList then
        begin
          if IsOrd then
            Result += '<ol>' + LineEnding
          else
            Result += '<ul>' + LineEnding;
          InList := True;
          ListOrdered := IsOrd;
        end
        else if IsOrd <> ListOrdered then
        begin
          // Cambio de tipo de lista: cierra y abre
          if ListOrdered then
            Result += '</ol>' + LineEnding
          else
            Result += '</ul>' + LineEnding;
          if IsOrd then
            Result += '<ol>' + LineEnding
          else
            Result += '<ul>' + LineEnding;
          ListOrdered := IsOrd;
        end;
        Result += '<li>' + ProcessInline(ItemContent) + '</li>' + LineEnding;
        Inc(i);
        Continue;
      end
      else if InList then
      begin
        // Fin de lista (línea no-item y no vacía -> cerrar)
        CloseList;
      end;

      // Código indentado (4 espacios)
      if (Copy(Line, 1, 4) = '    ') and (Trimmed <> '') then
      begin
        ClosePara;
        Result += '<pre>' + EscapeHtml(Copy(Line, 5, MaxInt)) + '</pre>' +
          LineEnding;
        Inc(i);
        Continue;
      end;

      // Párrafo normal. "<br>" si termina en dos espacios
      if not InPara then
      begin
        Result += '<p>' + ProcessInline(Line);
        InPara := True;
      end
      else
      begin
        if (Length(Line) >= 2) and
          (Copy(Line, Length(Line) - 1, 2) = '  ') then
          Result += '<br>' + LineEnding + ProcessInline(Line)
        else
          Result += ' ' + ProcessInline(Line);
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
