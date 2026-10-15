unit MainForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls,
  ExtCtrls, StdCtrls, IniFiles, LCLType, htmlview, SynEdit, SynMarkdown;

type

  { TFrmMain }

  TFrmMain = class(TForm)
    MainMenu1: TMainMenu;
    mnuArchivo: TMenuItem;
    mnuNuevo: TMenuItem;
    mnuAbrir: TMenuItem;
    mnuGuardar: TMenuItem;
    mnuGuardarComo: TMenuItem;
    mnuExportarHtml: TMenuItem;
    mnuSep1: TMenuItem;
    mnuSalir: TMenuItem;
    mnuEditar: TMenuItem;
    mnuDeshacer: TMenuItem;
    mnuRehacer: TMenuItem;
    mnuSepEd1: TMenuItem;
    mnuCortar: TMenuItem;
    mnuCopiar: TMenuItem;
    mnuPegar: TMenuItem;
    mnuSelTodo: TMenuItem;
    mnuSepEd2: TMenuItem;
    mnuFormato: TMenuItem;
    mnuTitulo1: TMenuItem;
    mnuTitulo2: TMenuItem;
    mnuTitulo3: TMenuItem;
    mnuSepEd3: TMenuItem;
    mnuNegrita: TMenuItem;
    mnuCursiva: TMenuItem;
    mnuTachado: TMenuItem;
    mnuCodigo: TMenuItem;
    mnuEnlace: TMenuItem;
    mnuSepEd4: TMenuItem;
    mnuCita: TMenuItem;
    mnuLista: TMenuItem;
    EditPopup: TPopupMenu;
    popDeshacer: TMenuItem;
    popRehacer: TMenuItem;
    popSepP1: TMenuItem;
    popCortar: TMenuItem;
    popCopiar: TMenuItem;
    popPegar: TMenuItem;
    popSepP2: TMenuItem;
    popFormato: TMenuItem;
    popTitulo1: TMenuItem;
    popTitulo2: TMenuItem;
    popTitulo3: TMenuItem;
    popSepP3: TMenuItem;
    popNegrita: TMenuItem;
    popCursiva: TMenuItem;
    popTachado: TMenuItem;
    popCodigo: TMenuItem;
    popEnlace: TMenuItem;
    popSepP4: TMenuItem;
    popCita: TMenuItem;
    popLista: TMenuItem;
    mnuVer: TMenuItem;
    mnuActualizar: TMenuItem;
    mnuAutoActualizar: TMenuItem;
    mnuSepVer1: TMenuItem;
    mnuFuenteEditor: TMenuItem;
    mnuSepVer2: TMenuItem;
    mnuZoomMas: TMenuItem;
    mnuZoomMenos: TMenuItem;
    mnuZoomReset: TMenuItem;
    mnuAyuda: TMenuItem;
    mnuAcercaDe: TMenuItem;
    pnlEditor: TPanel;
    SynEditor: TSynEdit;
    Splitter1: TSplitter;
    pnlPreview: TPanel;
    HtmlPreview: THtmlViewer;
    StatusBar1: TStatusBar;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    SaveHtmlDialog: TSaveDialog;
    FontDialog1: TFontDialog;
    PreviewTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SynEditorChange(Sender: TObject);
    procedure SynEditorStatusChange(Sender: TObject;
      Changes: TSynStatusChanges);
    procedure PreviewTimerTimer(Sender: TObject);
    procedure mnuNuevoClick(Sender: TObject);
    procedure mnuAbrirClick(Sender: TObject);
    procedure mnuGuardarClick(Sender: TObject);
    procedure mnuGuardarComoClick(Sender: TObject);
    procedure mnuExportarHtmlClick(Sender: TObject);
    procedure mnuSalirClick(Sender: TObject);
    procedure mnuDeshacerClick(Sender: TObject);
    procedure mnuRehacerClick(Sender: TObject);
    procedure mnuCortarClick(Sender: TObject);
    procedure mnuCopiarClick(Sender: TObject);
    procedure mnuPegarClick(Sender: TObject);
    procedure mnuSelTodoClick(Sender: TObject);
    procedure mnuTituloClick(Sender: TObject);
    procedure mnuNegritaClick(Sender: TObject);
    procedure mnuCursivaClick(Sender: TObject);
    procedure mnuTachadoClick(Sender: TObject);
    procedure mnuCodigoClick(Sender: TObject);
    procedure mnuEnlaceClick(Sender: TObject);
    procedure mnuCitaClick(Sender: TObject);
    procedure mnuListaClick(Sender: TObject);
    procedure mnuActualizarClick(Sender: TObject);
    procedure mnuAutoActualizarClick(Sender: TObject);
    procedure mnuFuenteEditorClick(Sender: TObject);
    procedure mnuZoomMasClick(Sender: TObject);
    procedure mnuZoomMenosClick(Sender: TObject);
    procedure mnuZoomResetClick(Sender: TObject);
    procedure mnuAcercaDeClick(Sender: TObject);
  private
    FFileName: string;
    FModified: Boolean;
    FLoading: Boolean;
    FViewerFontSize: Integer;
    FMdHighlighter: TSynMarkdownSyn;
    procedure SetFileName(const AValue: string);
    procedure SetModified(AValue: Boolean);
    function CheckSaveChanges: Boolean;
    procedure LoadMdFile(const AFile: string);
    procedure SaveMdFile(const AFile: string);
    procedure UpdatePreview;
    procedure UpdateCaption;
    procedure UpdateStatus;
    procedure ApplyEditorFont;
    procedure ApplyViewerZoom;
    procedure LoadPrefs;
    procedure SavePrefs;
    function ConfigFile: string;
    procedure WrapSelection(const APrefix, ASuffix: string);
    procedure PrefixLines(const APrefix: string; AHeadingLevel: Integer = 0);
    procedure ApplyHeading(ALevel: Integer);
  public
    property FileName: string read FFileName;
  end;

var
  FrmMain: TFrmMain;

implementation

uses
  Markdown;

{$R *.lfm}

procedure TFrmMain.FormCreate(Sender: TObject);
begin
  FFileName := '';
  FModified := False;
  FLoading := False;
  FViewerFontSize := 12;
  // StatusBar con 4 paneles (fichero / estado / cursor / zoom visor).
  // Va primero: cualquier cambio en el editor dispara UpdateStatus.
  StatusBar1.Panels.Clear;
  with StatusBar1.Panels.Add do
  begin
    Width := 500;
  end;
  with StatusBar1.Panels.Add do
  begin
    Width := 110;
  end;
  with StatusBar1.Panels.Add do
  begin
    Width := 130;
  end;
  with StatusBar1.Panels.Add do
  begin
    Width := 110;
  end;
  // El constructor de TSynEdit omite los bindings de teclado cuando el
  // componente se crea por streaming (csLoading); hay que restaurarlos.
  SynEditor.SetDefaultKeystrokes;
  FMdHighlighter := TSynMarkdownSyn.Create(Self);
  SynEditor.Highlighter := FMdHighlighter;
  OpenDialog1.Filter := 'Markdown (*.md;*.markdown)|*.md;*.markdown|Todos (*.*)|*.*';
  SaveDialog1.Filter := OpenDialog1.Filter;
  SaveDialog1.DefaultExt := 'md';
  SaveHtmlDialog.Filter := 'HTML (*.html)|*.html|Todos (*.*)|*.*';
  SaveHtmlDialog.DefaultExt := 'html';
  LoadPrefs;
  ApplyEditorFont;
  ApplyViewerZoom;
  // Atajos visibles en el menú. Los de zoom se dibujan en el Caption
  // (tras tab) porque '+' no existe como tecla LCL y mostraría NumPlus.
  // El manejo real está en FormKeyDown con KeyPreview=True,
  // porque TSynEdit consume las teclas con foco.
  mnuFuenteEditor.ShortCut := ShortCut(Ord('E'), [ssCtrl]);
  mnuZoomMas.ShortCut := 0;
  mnuZoomMenos.ShortCut := 0;
  mnuZoomReset.ShortCut := ShortCut(Ord('0'), [ssCtrl]);
  mnuAutoActualizar.Checked := True;
  PreviewTimer.Interval := 400;
  PreviewTimer.Enabled := False;
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then
    LoadMdFile(ParamStr(1))
  else
  begin
    SynEditor.Lines.Text :=
      '# mdTool' + LineEnding + LineEnding +
      'Editor / visor de Markdown.' + LineEnding + LineEnding +
      '- Edita a la izquierda' + LineEnding +
      '- Vista previa a la derecha' + LineEnding + LineEnding +
      '**Abrir**, **Guardar** y **Exportar a HTML** desde el menú Archivo.';
    SetModified(False);
  end;
  UpdatePreview;
  UpdateCaption;
  UpdateStatus;
end;

procedure TFrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := CheckSaveChanges;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  SavePrefs;
end;

procedure TFrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // KeyPreview=True: esto corre antes que TSynEdit, que consume
  // Ctrl+E / Ctrl+ +/- /0 cuando el editor tiene el foco.
  if not (ssCtrl in Shift) then
    Exit;
  if (ssAlt in Shift) or (ssMeta in Shift) then
    Exit;
  case Key of
    Ord('E'):
      begin
        mnuFuenteEditorClick(Self);
        Key := 0;
      end;
    Ord('0'), VK_NUMPAD0:
      begin
        mnuZoomResetClick(Self);
        Key := 0;
      end;
    VK_ADD, VK_OEM_PLUS, Ord('='), Ord('+'):
      begin
        mnuZoomMasClick(Self);
        Key := 0;
      end;
    VK_SUBTRACT, VK_OEM_MINUS, Ord('-'), Ord('_'):
      begin
        mnuZoomMenosClick(Self);
        Key := 0;
      end;
    // --- Editar: portapapeles e historial ---
    Ord('Z'):
      begin
        if ssShift in Shift then
          mnuRehacerClick(Self)
        else
          mnuDeshacerClick(Self);
        Key := 0;
      end;
    Ord('Y'):
      begin
        mnuRehacerClick(Self);
        Key := 0;
      end;
    Ord('X'):
      begin
        mnuCortarClick(Self);
        Key := 0;
      end;
    Ord('C'):
      begin
        mnuCopiarClick(Self);
        Key := 0;
      end;
    Ord('V'):
      begin
        mnuPegarClick(Self);
        Key := 0;
      end;
    Ord('A'):
      begin
        mnuSelTodoClick(Self);
        Key := 0;
      end;
    // --- Editar: formato Markdown ---
    Ord('B'):
      begin
        mnuNegritaClick(Self);
        Key := 0;
      end;
    Ord('I'):
      begin
        mnuCursivaClick(Self);
        Key := 0;
      end;
    Ord('D'):
      begin
        mnuTachadoClick(Self);
        Key := 0;
      end;
    Ord('K'):
      begin
        mnuEnlaceClick(Self);
        Key := 0;
      end;
    Ord('Q'):
      begin
        mnuCitaClick(Self);
        Key := 0;
      end;
    Ord('L'):
      begin
        mnuListaClick(Self);
        Key := 0;
      end;
    Ord('1')..Ord('3'):
      begin
        ApplyHeading(Key - Ord('0'));
        Key := 0;
      end;
    VK_OEM_3:
      begin
        mnuCodigoClick(Self);
        Key := 0;
      end;
  end;
end;

procedure TFrmMain.SynEditorChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  SetModified(True);
  if mnuAutoActualizar.Checked then
  begin
    PreviewTimer.Enabled := False;
    PreviewTimer.Enabled := True;
  end;
end;

procedure TFrmMain.SynEditorStatusChange(Sender: TObject;
  Changes: TSynStatusChanges);
begin
  UpdateStatus;
end;

procedure TFrmMain.PreviewTimerTimer(Sender: TObject);
begin
  PreviewTimer.Enabled := False;
  UpdatePreview;
end;

procedure TFrmMain.mnuNuevoClick(Sender: TObject);
begin
  if not CheckSaveChanges then
    Exit;
  FLoading := True;
  try
    SynEditor.Lines.Clear;
  finally
    FLoading := False;
  end;
  SetFileName('');
  SetModified(False);
  UpdatePreview;
end;

procedure TFrmMain.mnuAbrirClick(Sender: TObject);
begin
  if not CheckSaveChanges then
    Exit;
  if OpenDialog1.Execute then
    LoadMdFile(OpenDialog1.FileName);
end;

procedure TFrmMain.mnuGuardarClick(Sender: TObject);
begin
  if FFileName = '' then
    mnuGuardarComoClick(Sender)
  else
    SaveMdFile(FFileName);
end;

procedure TFrmMain.mnuGuardarComoClick(Sender: TObject);
begin
  if SaveDialog1.Execute then
    SaveMdFile(SaveDialog1.FileName);
end;

procedure TFrmMain.mnuExportarHtmlClick(Sender: TObject);
var
  Html: string;
  SL: TStringList;
  Title: string;
begin
  if SaveHtmlDialog.Execute then
  begin
    if FFileName <> '' then
      Title := ChangeFileExt(ExtractFileName(FFileName), '')
    else
      Title := 'mdTool';
    Html := MarkdownToHtmlPage(SynEditor.Lines.Text, Title);
    SL := TStringList.Create;
    try
      SL.Text := Html;
      SL.SaveToFile(SaveHtmlDialog.FileName);
    finally
      SL.Free;
    end;
    StatusBar1.Panels[0].Text := 'Exportado: ' + SaveHtmlDialog.FileName;
  end;
end;

procedure TFrmMain.mnuSalirClick(Sender: TObject);
begin
  Close;
end;

procedure TFrmMain.mnuDeshacerClick(Sender: TObject);
begin
  SynEditor.Undo;
end;

procedure TFrmMain.mnuRehacerClick(Sender: TObject);
begin
  SynEditor.Redo;
end;

procedure TFrmMain.mnuCortarClick(Sender: TObject);
begin
  SynEditor.CutToClipboard;
end;

procedure TFrmMain.mnuCopiarClick(Sender: TObject);
begin
  SynEditor.CopyToClipboard;
end;

procedure TFrmMain.mnuPegarClick(Sender: TObject);
begin
  SynEditor.PasteFromClipboard;
end;

procedure TFrmMain.mnuSelTodoClick(Sender: TObject);
begin
  SynEditor.SelectAll;
end;

procedure TFrmMain.mnuTituloClick(Sender: TObject);
begin
  ApplyHeading((Sender as TMenuItem).Tag);
end;

procedure TFrmMain.mnuNegritaClick(Sender: TObject);
begin
  WrapSelection('**', '**');
end;

procedure TFrmMain.mnuCursivaClick(Sender: TObject);
begin
  WrapSelection('*', '*');
end;

procedure TFrmMain.mnuTachadoClick(Sender: TObject);
begin
  WrapSelection('~~', '~~');
end;

procedure TFrmMain.mnuCodigoClick(Sender: TObject);
begin
  WrapSelection('`', '`');
end;

procedure TFrmMain.mnuEnlaceClick(Sender: TObject);
var
  P: TPoint;
  S: string;
begin
  if SynEditor.SelAvail then
  begin
    S := SynEditor.SelText;
    SynEditor.SelText := '[' + S + '](url)';
    // Deja el caret tras el enlace
  end
  else
  begin
    P := SynEditor.CaretXY;
    SynEditor.InsertTextAtCaret('[texto](url)');
    // Selecciona "texto" para sustituirlo directamente
    SynEditor.BlockBegin := Point(P.X + 1, P.Y);
    SynEditor.BlockEnd := Point(P.X + 6, P.Y);
  end;
end;

procedure TFrmMain.mnuCitaClick(Sender: TObject);
begin
  PrefixLines('> ');
end;

procedure TFrmMain.mnuListaClick(Sender: TObject);
begin
  PrefixLines('- ');
end;

procedure TFrmMain.ApplyHeading(ALevel: Integer);
begin
  if (ALevel >= 1) and (ALevel <= 3) then
    PrefixLines('', ALevel);
end;

procedure TFrmMain.WrapSelection(const APrefix, ASuffix: string);
var
  S: string;
  P: TPoint;
begin
  if SynEditor.SelAvail then
  begin
    S := SynEditor.SelText;
    // Toggle: si ya está envuelto, lo desenvuelve
    if (Length(S) >= Length(APrefix) + Length(ASuffix)) and
      (Copy(S, 1, Length(APrefix)) = APrefix) and
      (Copy(S, Length(S) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
      SynEditor.SelText :=
        Copy(S, Length(APrefix) + 1, Length(S) - Length(APrefix) - Length(ASuffix))
    else
      SynEditor.SelText := APrefix + S + ASuffix;
  end
  else
  begin
    SynEditor.InsertTextAtCaret(APrefix + ASuffix);
    // Caret entre marca de apertura y cierre
    P := SynEditor.CaretXY;
    P.X := P.X - Length(ASuffix);
    if P.X < 1 then
      P.X := 1;
    SynEditor.CaretXY := P;
  end;
end;

procedure TFrmMain.PrefixLines(const APrefix: string; AHeadingLevel: Integer);
var
  Y1, Y2, Y: Integer;
  L, Rest: string;
  i: Integer;
begin
  if SynEditor.SelAvail then
  begin
    Y1 := SynEditor.BlockBegin.Y;
    Y2 := SynEditor.BlockEnd.Y;
    if (Y2 > Y1) and (SynEditor.BlockEnd.X = 1) then
      Dec(Y2); // la selección termina al inicio de línea: no tocarla
  end
  else
  begin
    Y1 := SynEditor.CaretXY.Y;
    Y2 := Y1;
  end;
  SynEditor.BeginUndoBlock;
  try
    for Y := Y1 to Y2 do
    begin
      if (Y < 1) or (Y > SynEditor.Lines.Count) then
        Continue;
      L := SynEditor.Lines[Y - 1];
      if AHeadingLevel > 0 then
      begin
        // Quita '#' previos y aplica el nivel pedido
        i := 1;
        while (i <= Length(L)) and (L[i] = '#') do
          Inc(i);
        while (i <= Length(L)) and (L[i] = ' ') do
          Inc(i);
        Rest := Copy(L, i, MaxInt);
        SynEditor.Lines[Y - 1] := StringOfChar('#', AHeadingLevel) + ' ' + Rest;
      end
      else if (TrimLeft(L) = '') or (Copy(TrimLeft(L), 1, Length(APrefix)) = APrefix) then
      begin
        // Línea vacía o ya prefijada: no duplicar
      end
      else
        SynEditor.Lines[Y - 1] := APrefix + L;
    end;
  finally
    SynEditor.EndUndoBlock;
  end;
end;

procedure TFrmMain.mnuActualizarClick(Sender: TObject);
begin
  UpdatePreview;
end;

procedure TFrmMain.mnuAutoActualizarClick(Sender: TObject);
begin
  mnuAutoActualizar.Checked := not mnuAutoActualizar.Checked;
  if mnuAutoActualizar.Checked then
    UpdatePreview;
end;

procedure TFrmMain.mnuFuenteEditorClick(Sender: TObject);
begin
  FontDialog1.Font.Assign(SynEditor.Font);
  if FontDialog1.Execute then
  begin
    SynEditor.Font.Assign(FontDialog1.Font);
    ApplyEditorFont;
    SavePrefs;
    UpdateStatus;
  end;
end;

procedure TFrmMain.mnuZoomMasClick(Sender: TObject);
begin
  if FViewerFontSize < 32 then
    Inc(FViewerFontSize, 2);
  ApplyViewerZoom;
  SavePrefs;
end;

procedure TFrmMain.mnuZoomMenosClick(Sender: TObject);
begin
  if FViewerFontSize > 8 then
    Dec(FViewerFontSize, 2);
  if FViewerFontSize < 8 then
    FViewerFontSize := 8;
  ApplyViewerZoom;
  SavePrefs;
end;

procedure TFrmMain.mnuZoomResetClick(Sender: TObject);
begin
  FViewerFontSize := 12;
  ApplyViewerZoom;
  SavePrefs;
end;

procedure TFrmMain.mnuAcercaDeClick(Sender: TObject);
begin
  ShowMessage('mdTool 0.1' + LineEnding +
    'Visor/editor de Markdown en Lazarus/Free Pascal.' + LineEnding +
    'Editor: SynEdit · Preview: TIpHtmlPanel.');
end;

procedure TFrmMain.SetFileName(const AValue: string);
begin
  FFileName := AValue;
  UpdateCaption;
  UpdateStatus;
end;

procedure TFrmMain.SetModified(AValue: Boolean);
begin
  FModified := AValue;
  UpdateCaption;
  UpdateStatus;
end;

function TFrmMain.CheckSaveChanges: Boolean;
var
  R: Integer;
begin
  Result := True;
  if not FModified then
    Exit;
  R := MessageDlg('Guardar cambios',
    'El documento ha cambiado. ¿Guardar antes de continuar?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if R = mrYes then
  begin
    mnuGuardarClick(Self);
    Result := not FModified; // si sigue modificado, canceló el diálogo
  end
  else if R = mrCancel then
    Result := False;
end;

procedure TFrmMain.LoadMdFile(const AFile: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(AFile);
    FLoading := True;
    try
      SynEditor.Lines.Assign(SL);
    finally
      FLoading := False;
    end;
  finally
    SL.Free;
  end;
  SetFileName(AFile);
  SetModified(False);
  UpdatePreview;
end;

procedure TFrmMain.SaveMdFile(const AFile: string);
begin
  SynEditor.Lines.SaveToFile(AFile);
  SetFileName(AFile);
  SetModified(False);
end;

procedure TFrmMain.UpdatePreview;
var
  Html: string;
begin
  Html := '<!DOCTYPE html>' + LineEnding +
    '<html><head><meta charset="utf-8"><style>' + MarkdownCss +
    '</style></head><body>' + LineEnding +
    MarkdownToHtml(SynEditor.Lines.Text) +
    LineEnding + '</body></html>';
  try
    HtmlPreview.LoadFromString(Html);
  except
    on E: Exception do
      StatusBar1.Panels[0].Text := 'Error preview: ' + E.Message;
  end;
end;

procedure TFrmMain.UpdateCaption;
var
  DocName: string;
begin
  if FFileName = '' then
    DocName := 'sin título'
  else
    DocName := ExtractFileName(FFileName);
  if FModified then
    Caption := 'mdTool — ' + DocName + ' *'
  else
    Caption := 'mdTool — ' + DocName;
end;

procedure TFrmMain.UpdateStatus;
var
  Pos: TPoint;
begin
  if StatusBar1.Panels.Count < 4 then
    Exit; // FormCreate aún no ha creado los paneles
  if FFileName = '' then
    StatusBar1.Panels[0].Text := 'sin título'
  else
    StatusBar1.Panels[0].Text := FFileName;
  if FModified then
    StatusBar1.Panels[1].Text := 'Modificado'
  else
    StatusBar1.Panels[1].Text := '';
  Pos := SynEditor.CaretXY;
  StatusBar1.Panels[2].Text := Format('Ln %d, Col %d', [Pos.Y, Pos.X]);
  if StatusBar1.Panels.Count > 3 then
    StatusBar1.Panels[3].Text := Format('Visor %dpt (%d%%)',
      [FViewerFontSize, Round(FViewerFontSize / 12 * 100)]);
end;

procedure TFrmMain.ApplyEditorFont;
begin
  // SynEdit usa Font para todo el texto; fijamos pitch fijo si es mono
  // pero respetamos la elección del usuario.
  SynEditor.Font.Pitch := fpFixed;
  UpdateStatus;
end;

procedure TFrmMain.ApplyViewerZoom;
begin
  HtmlPreview.DefFontSize := FViewerFontSize;
  UpdatePreview;
  UpdateStatus;
end;

function TFrmMain.ConfigFile: string;
begin
  Result := GetAppConfigDir(False) + 'mdtool.ini';
end;

procedure TFrmMain.LoadPrefs;
var
  Ini: TIniFile;
  Cfg: string;
begin
  // Valores por defecto
  SynEditor.Font.Name := 'Monospace';
  SynEditor.Font.Size := 10;
  FViewerFontSize := 12;
  Cfg := ConfigFile;
  if not FileExists(Cfg) then
    Exit;
  Ini := TIniFile.Create(Cfg);
  try
    SynEditor.Font.Name := Ini.ReadString('Editor', 'FontName', SynEditor.Font.Name);
    SynEditor.Font.Size := Ini.ReadInteger('Editor', 'FontSize', SynEditor.Font.Size);
    FViewerFontSize := Ini.ReadInteger('Viewer', 'FontSize', FViewerFontSize);
    if FViewerFontSize < 8 then
      FViewerFontSize := 8;
    if FViewerFontSize > 32 then
      FViewerFontSize := 32;
  finally
    Ini.Free;
  end;
end;

procedure TFrmMain.SavePrefs;
var
  Ini: TIniFile;
  Cfg: string;
begin
  Cfg := ConfigFile;
  try
    ForceDirectories(ExtractFileDir(Cfg));
    Ini := TIniFile.Create(Cfg);
    try
      Ini.WriteString('Editor', 'FontName', SynEditor.Font.Name);
      Ini.WriteInteger('Editor', 'FontSize', SynEditor.Font.Size);
      Ini.WriteInteger('Viewer', 'FontSize', FViewerFontSize);
      Ini.UpdateFile;
    finally
      Ini.Free;
    end;
  except
    // No bloquear la app si no se puede guardar la config
  end;
end;

initialization
  // Streaming del LFM sin instalar el paquete de diseño
  RegisterClass(THtmlViewer);

end.
