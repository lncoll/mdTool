unit MainForm;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ComCtrls,
  ExtCtrls, StdCtrls, IniFiles, LCLType, htmlview, SynEdit, SynEditTypes,
  SynMarkdown;

type

  { TDocInfo }

  TDocInfo = class
    Editor: TSynEdit;
    FileName: string;
    Modified: Boolean;
  end;

  { TFrmMain }

  TFrmMain = class(TForm)
    MainMenu1: TMainMenu;
    mnuArchivo: TMenuItem;
    mnuNuevo: TMenuItem;
    mnuAbrir: TMenuItem;
    mnuCerrarTab: TMenuItem;
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
    mnuSepEdFind: TMenuItem;
    mnuBuscar: TMenuItem;
    mnuReemplazar: TMenuItem;
    mnuBuscarSig: TMenuItem;
    mnuBuscarAnt: TMenuItem;
    mnuVolverEdicion: TMenuItem;
    mnuSepEdMax: TMenuItem;
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
    ViewPopup: TPopupMenu;
    popCopiarVer: TMenuItem;
    mnuVer: TMenuItem;
    mnuActualizar: TMenuItem;
    mnuAutoActualizar: TMenuItem;
    mnuSepVer1: TMenuItem;
    mnuFuenteEditor: TMenuItem;
    mnuSepVer2: TMenuItem;
    mnuZoomMas: TMenuItem;
    mnuZoomMenos: TMenuItem;
    mnuZoomReset: TMenuItem;
    mnuSepVer3: TMenuItem;
    mnuMaxVisor: TMenuItem;
    mnuAyuda: TMenuItem;
    mnuAcercaDe: TMenuItem;
    pnlEditor: TPanel;
    PageControl1: TPageControl;
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
    procedure AppDropFiles(Sender: TObject; const FileNames: array of string);
    procedure PageControl1Change(Sender: TObject);
    procedure PageControl1CloseTabClicked(Sender: TObject);
    procedure ViewPopupPopup(Sender: TObject);
    procedure popCopiarVerClick(Sender: TObject);
    procedure SynEditorChange(Sender: TObject);
    procedure SynEditorStatusChange(Sender: TObject;
      Changes: TSynStatusChanges);
    procedure PreviewTimerTimer(Sender: TObject);
    procedure mnuNuevoClick(Sender: TObject);
    procedure mnuAbrirClick(Sender: TObject);
    procedure mnuCerrarTabClick(Sender: TObject);
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
    procedure mnuBuscarClick(Sender: TObject);
    procedure mnuReemplazarClick(Sender: TObject);
    procedure mnuBuscarSigClick(Sender: TObject);
    procedure mnuBuscarAntClick(Sender: TObject);
    procedure mnuVolverEdicionClick(Sender: TObject);
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
    procedure mnuMaxVisorClick(Sender: TObject);
    procedure mnuAcercaDeClick(Sender: TObject);
  private
    FLoading: Boolean;
    FViewerFontSize: Integer;
    FViewerMax: Boolean;
    FEditorFontName: string;
    FEditorFontSize: Integer;
    FMdHighlighter: TSynMarkdownSyn;
    FFindText: string;
    FFindOpts: TSynSearchOptions;
    FReplaceText: string;
    procedure SetDocFileName(Doc: TDocInfo; const AValue: string);
    procedure SetDocModified(Doc: TDocInfo; AValue: Boolean);
    procedure RefreshDocTitle(Doc: TDocInfo);
    procedure RefreshForActiveDoc;
    function CheckDocSave(Doc: TDocInfo): Boolean;
    function SaveDocFile(Doc: TDocInfo): Boolean;
    function NewDocTab(const AFileName, AContent: string): TDocInfo;
    procedure CloseDocTab(APage: TTabSheet);
    function GetFileName: string;
    procedure OpenFilesFromParams;
    procedure UpdatePreview;
    procedure UpdateCaption;
    procedure UpdateStatus;
    procedure SyncPreviewScroll;
    procedure ApplyEditorFont;
    procedure ApplyViewerZoom;
    procedure SetViewerMax(AValue: Boolean);
    procedure ApplyEditMenuMode;
    procedure LoadPrefs;
    procedure SavePrefs;
    function ConfigFile: string;
    procedure WrapSelection(const APrefix, ASuffix: string);
    procedure PrefixLines(const APrefix: string; AHeadingLevel: Integer = 0);
    procedure ApplyHeading(ALevel: Integer);
    function MatchSelected: Boolean;
  public
    property FileName: string read GetFileName;
    function ActiveDoc: TDocInfo;
    function ActiveEditor: TSynEdit;
    procedure OpenFile(const AFile: string);
    procedure SetFind(const AText: string; AOptions: TSynSearchOptions;
      const AReplace: string);
    function SelectedOrEmpty: string;
    function FindNext(ABackwards: Boolean): Boolean;
    function ReplaceCurrent: Boolean;
    function ReplaceAll: Integer;
    procedure ShowStatus(const S: string);
  end;

var
  FrmMain: TFrmMain;

implementation

uses
  Markdown, FindDlg;

{$R *.lfm}

const
  SAMPLE_TEXT = '# mdTool' + LineEnding + LineEnding +
    'Editor / visor de Markdown.' + LineEnding + LineEnding +
    '- Edita a la izquierda' + LineEnding +
    '- Vista previa a la derecha' + LineEnding + LineEnding +
    '**Abrir**, **Guardar** y **Exportar a HTML** desde el menú Archivo.';

procedure TFrmMain.FormCreate(Sender: TObject);
begin
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
  // (Se aplica por editor al crearlo en NewDocTab.)
  FMdHighlighter := TSynMarkdownSyn.Create(Self);
  OpenDialog1.Filter := 'Markdown (*.md;*.markdown)|*.md;*.markdown|Todos (*.*)|*.*';
  SaveDialog1.Filter := OpenDialog1.Filter;
  SaveDialog1.DefaultExt := 'md';
  SaveHtmlDialog.Filter := 'HTML (*.html)|*.html|Todos (*.*)|*.*';
  SaveHtmlDialog.DefaultExt := 'html';
  OpenDialog1.Options := OpenDialog1.Options + [ofAllowMultiSelect];
  // X de cierre en cada pestaña (lo pinta el widgetset)
  PageControl1.Options := PageControl1.Options + [nboShowCloseButtons];
  LoadPrefs; // fuente del editor + zoom del visor
  ApplyViewerZoom;
  // Atajos visibles en el menú. Los de zoom se dibujan en el Caption
  // (tras tab) porque '+' no existe como tecla LCL y mostraría NumPlus.
  // El manejo real está en FormKeyDown con KeyPreview=True,
  // porque TSynEdit consume las teclas con foco.
  mnuFuenteEditor.ShortCut := ShortCut(Ord('E'), [ssCtrl]);
  mnuBuscar.ShortCut := ShortCut(Ord('F'), [ssCtrl]);
  mnuReemplazar.ShortCut := ShortCut(Ord('H'), [ssCtrl]);
  mnuBuscarSig.ShortCut := ShortCut(VK_F3, []);
  mnuBuscarAnt.ShortCut := ShortCut(VK_F3, [ssShift]);
  mnuZoomMas.ShortCut := 0;
  mnuZoomMenos.ShortCut := 0;
  mnuZoomReset.ShortCut := ShortCut(Ord('0'), [ssCtrl]);
  mnuMaxVisor.ShortCut := ShortCut(VK_F11, []);
  mnuCerrarTab.ShortCut := ShortCut(Ord('W'), [ssCtrl]);
  mnuCerrarTab.ShortCut := ShortCut(Ord('W'), [ssCtrl]);
  mnuAutoActualizar.Checked := True;
  PreviewTimer.Interval := 400;
  PreviewTimer.Enabled := False;
  Application.OnDropFiles := @AppDropFiles;
  if (ParamCount >= 1) and FileExists(ParamStr(1)) then
  begin
    OpenFilesFromParams;
    // Con fichero como parámetro se arranca con el visor maximizado
    SetViewerMax(True);
  end
  else
  begin
    NewDocTab('', SAMPLE_TEXT);
    SetViewerMax(False);
  end;
  RefreshForActiveDoc;
end;

procedure TFrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  i: Integer;
  Doc: TDocInfo;
begin
  CanClose := True;
  for i := 0 to PageControl1.PageCount - 1 do
  begin
    Doc := TDocInfo(PageControl1.Pages[i].Tag);
    if (Doc <> nil) and Doc.Modified then
      if not CheckDocSave(Doc) then
      begin
        CanClose := False;
        Exit;
      end;
  end;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  Application.OnDropFiles := nil;
  for i := 0 to PageControl1.PageCount - 1 do
    TDocInfo(PageControl1.Pages[i].Tag).Free;
  SavePrefs;
end;

procedure TFrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // F3/F11 funcionan con y sin Ctrl (el editor no los consume)
  if (Key = VK_F3) and not (ssAlt in Shift) and not (ssMeta in Shift) then
  begin
    if ssCtrl in Shift then
      Exit; // reservado, no hacer nada
    if ssShift in Shift then
      mnuBuscarAntClick(Self)
    else
      mnuBuscarSigClick(Self);
    Key := 0;
    Exit;
  end;
  if (Key = VK_TAB) and (ssCtrl in Shift) and not (ssAlt in Shift) and
    not (ssMeta in Shift) then
  begin
    // Ctrl+Tab / Ctrl+Mayús+Tab: siguiente/anterior pestaña
    if ssShift in Shift then
      PageControl1.SelectNextPage(False)
    else
      PageControl1.SelectNextPage(True);
    Key := 0;
    Exit;
  end;
  if (Key = VK_F11) and not (ssCtrl in Shift) and not (ssAlt in Shift) and
    not (ssMeta in Shift) then
  begin
    mnuMaxVisorClick(Self);
    Key := 0;
    Exit;
  end;
  // KeyPreview=True: esto corre antes que TSynEdit, que consume
  // Ctrl+E / Ctrl+ +/- /0 cuando el editor tiene el foco.
  if not (ssCtrl in Shift) then
    Exit;
  if (ssAlt in Shift) or (ssMeta in Shift) then
    Exit;
  // En visor maximizado solo: buscar, copiar, zoom y F11.
  // El resto se traga sin efecto (el editor está oculto).
  if FViewerMax then
    case Key of
      Ord('C'), Ord('F'),
      Ord('0'), VK_NUMPAD0,
      VK_ADD, VK_OEM_PLUS, Ord('='), Ord('+'),
      VK_SUBTRACT, VK_OEM_MINUS, Ord('-'), Ord('_'): ;
    else
      begin
        Key := 0;
        Exit;
      end;
    end;
  case Key of
    Ord('E'):
      begin
        mnuFuenteEditorClick(Self);
        Key := 0;
      end;
    Ord('F'):
      begin
        mnuBuscarClick(Self);
        Key := 0;
      end;
    Ord('H'):
      begin
        mnuReemplazarClick(Self);
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
var
  Doc: TDocInfo;
begin
  if FLoading then
    Exit;
  if not (Sender is TSynEdit) then
    Exit;
  Doc := TDocInfo((Sender as TSynEdit).Tag);
  if Doc = nil then
    Exit;
  SetDocModified(Doc, True);
  if (Sender = ActiveEditor) and mnuAutoActualizar.Checked then
  begin
    PreviewTimer.Enabled := False;
    PreviewTimer.Enabled := True;
  end;
end;

procedure TFrmMain.SynEditorStatusChange(Sender: TObject;
  Changes: TSynStatusChanges);
begin
  if Sender <> ActiveEditor then
    Exit;
  UpdateStatus;
  if [scCaretY, scTopLine] * Changes <> [] then
    SyncPreviewScroll;
end;

procedure TFrmMain.PreviewTimerTimer(Sender: TObject);
begin
  PreviewTimer.Enabled := False;
  UpdatePreview;
end;

procedure TFrmMain.mnuNuevoClick(Sender: TObject);
begin
  NewDocTab('', '');
end;

procedure TFrmMain.mnuAbrirClick(Sender: TObject);
var
  i: Integer;
begin
  if OpenDialog1.Execute then
    for i := 0 to OpenDialog1.Files.Count - 1 do
      OpenFile(OpenDialog1.Files[i]);
end;

procedure TFrmMain.mnuCerrarTabClick(Sender: TObject);
begin
  CloseDocTab(PageControl1.ActivePage);
end;

procedure TFrmMain.OpenFile(const AFile: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(AFile);
    except
      on E: Exception do
      begin
        ShowStatus('No se pudo abrir: ' + AFile);
        Exit;
      end;
    end;
    NewDocTab(AFile, SL.Text);
  finally
    SL.Free;
  end;
end;

procedure TFrmMain.OpenFilesFromParams;
var
  i: Integer;
begin
  for i := 1 to ParamCount do
    if FileExists(ParamStr(i)) then
      OpenFile(ParamStr(i));
end;

procedure TFrmMain.AppDropFiles(Sender: TObject; const FileNames: array of string);
var
  i: Integer;
  Ext: string;
begin
  for i := 0 to High(FileNames) do
  begin
    if not FileExists(FileNames[i]) then
      Continue;
    Ext := LowerCase(ExtractFileExt(FileNames[i]));
    if (Ext = '.md') or (Ext = '.markdown') or (Ext = '.mdown') or
      (Ext = '.txt') then
      OpenFile(FileNames[i]);
  end;
  BringToFront;
  // Sin ficheros válidos: se ignora el drop en silencio
end;

procedure TFrmMain.mnuGuardarClick(Sender: TObject);
begin
  SaveDocFile(ActiveDoc);
end;

procedure TFrmMain.mnuGuardarComoClick(Sender: TObject);
var
  Doc: TDocInfo;
begin
  Doc := ActiveDoc;
  if Doc = nil then
    Exit;
  SaveDialog1.FileName := Doc.FileName;
  if SaveDialog1.Execute then
  begin
    SetDocFileName(Doc, SaveDialog1.FileName);
    Doc.Editor.Lines.SaveToFile(Doc.FileName);
    SetDocModified(Doc, False);
  end;
end;

function TFrmMain.ActiveDoc: TDocInfo;
begin
  if (PageControl1.ActivePage <> nil) and
    (PageControl1.ActivePage.Tag <> 0) then
    Result := TDocInfo(PageControl1.ActivePage.Tag)
  else
    Result := nil;
end;

function TFrmMain.ActiveEditor: TSynEdit;
var
  Doc: TDocInfo;
begin
  Doc := ActiveDoc;
  if Doc = nil then
    Result := nil
  else
    Result := Doc.Editor;
end;

function TFrmMain.GetFileName: string;
var
  Doc: TDocInfo;
begin
  Doc := ActiveDoc;
  if Doc = nil then
    Result := ''
  else
    Result := Doc.FileName;
end;

function TFrmMain.NewDocTab(const AFileName, AContent: string): TDocInfo;
var
  Sheet: TTabSheet;
  Ed: TSynEdit;
begin
  Sheet := TTabSheet.Create(Self);
  Sheet.PageControl := PageControl1;
  Ed := TSynEdit.Create(Sheet);
  Ed.Parent := Sheet;
  Ed.Align := alClient;
  Ed.Font.Name := FEditorFontName;
  Ed.Font.Size := FEditorFontSize;
  Ed.Font.Pitch := fpFixed;
  Ed.PopupMenu := EditPopup;
  Ed.Highlighter := FMdHighlighter;
  Ed.SetDefaultKeystrokes;
  Ed.OnChange := @SynEditorChange;
  Ed.OnStatusChange := @SynEditorStatusChange;
  Ed.TabOrder := 0;
  Result := TDocInfo.Create;
  Result.Editor := Ed;
  Result.FileName := '';
  Result.Modified := False;
  Ed.Tag := PtrInt(Result);
  Sheet.Tag := PtrInt(Result);
  FLoading := True;
  try
    Ed.Lines.Text := AContent;
  finally
    FLoading := False;
  end;
  SetDocFileName(Result, AFileName);
  PageControl1.ActivePage := Sheet;
  // Refresco explícito: el OnChange no siempre salta al activar
  // programáticamente (según widgetset llega diferido o nunca).
  RefreshForActiveDoc;
  // Solo si es enfocable (ni en FormCreate ni en visor maximizado)
  if Ed.CanSetFocus then
    Ed.SetFocus;
end;

procedure TFrmMain.CloseDocTab(APage: TTabSheet);
var
  Doc: TDocInfo;
  Ed: TSynEdit;
begin
  if APage = nil then
    Exit;
  Doc := TDocInfo(APage.Tag);
  if (Doc <> nil) and Doc.Modified then
    if not CheckDocSave(Doc) then
      Exit; // el usuario canceló
  if PageControl1.PageCount <= 1 then
  begin
    // Siempre queda ≥1 pestaña: vaciar en lugar de cerrar
    if Doc <> nil then
    begin
      Ed := Doc.Editor;
      FLoading := True;
      try
        Ed.Lines.Clear;
      finally
        FLoading := False;
      end;
      SetDocFileName(Doc, '');
      SetDocModified(Doc, False);
      RefreshForActiveDoc;
    end;
    Exit;
  end;
  APage.Tag := 0;
  if Doc <> nil then
  begin
    Doc.Editor.Tag := 0;
    Doc.Free;
  end;
  APage.Free;
  RefreshForActiveDoc;
end;

procedure TFrmMain.PageControl1Change(Sender: TObject);
begin
  RefreshForActiveDoc;
  if (ActiveEditor <> nil) and ActiveEditor.CanSetFocus then
    ActiveEditor.SetFocus;
end;

procedure TFrmMain.ViewPopupPopup(Sender: TObject);
begin
  // Copiar solo con selección en el visor
  popCopiarVer.Enabled := HtmlPreview.SelLength > 0;
end;

procedure TFrmMain.popCopiarVerClick(Sender: TObject);
begin
  HtmlPreview.CopyToClipboard;
end;

procedure TFrmMain.PageControl1CloseTabClicked(Sender: TObject);
begin
  // Sender es la pestaña cuya X se pulsó
  if Sender is TTabSheet then
    CloseDocTab(Sender as TTabSheet);
end;

procedure TFrmMain.RefreshForActiveDoc;
begin
  UpdateCaption;
  UpdateStatus;
  UpdatePreview;
end;

procedure TFrmMain.SetDocFileName(Doc: TDocInfo; const AValue: string);
begin
  if Doc = nil then
    Exit;
  Doc.FileName := AValue;
  RefreshDocTitle(Doc);
  if Doc = ActiveDoc then
    UpdateCaption;
end;

procedure TFrmMain.SetDocModified(Doc: TDocInfo; AValue: Boolean);
begin
  if Doc = nil then
    Exit;
  if Doc.Modified = AValue then
    Exit;
  Doc.Modified := AValue;
  RefreshDocTitle(Doc);
  if Doc = ActiveDoc then
  begin
    UpdateCaption;
    UpdateStatus;
  end;
end;

procedure TFrmMain.RefreshDocTitle(Doc: TDocInfo);
var
  i: Integer;
  T: string;
begin
  if Doc = nil then
    Exit;
  if Doc.FileName = '' then
    T := 'sin título'
  else
    T := ExtractFileName(Doc.FileName);
  if Doc.Modified then
    T := '* ' + T;
  for i := 0 to PageControl1.PageCount - 1 do
    if PageControl1.Pages[i].Tag = PtrInt(Doc) then
    begin
      PageControl1.Pages[i].Caption := T;
      Exit;
    end;
end;

function TFrmMain.CheckDocSave(Doc: TDocInfo): Boolean;
var
  R: Integer;
  T: string;
begin
  Result := True;
  if (Doc = nil) or not Doc.Modified then
    Exit;
  if Doc.FileName = '' then
    T := 'sin título'
  else
    T := ExtractFileName(Doc.FileName);
  // Traer al frente la pestaña afectada para contexto
  R := MessageDlg('Guardar cambios',
    'El documento "' + T + '" ha cambiado. ¿Guardar antes de continuar?',
    mtConfirmation, [mbYes, mbNo, mbCancel], 0);
  if R = mrYes then
    Result := SaveDocFile(Doc)
  else if R = mrCancel then
    Result := False;
end;

function TFrmMain.SaveDocFile(Doc: TDocInfo): Boolean;
begin
  Result := False;
  if Doc = nil then
    Exit;
  if Doc.FileName = '' then
  begin
    SaveDialog1.FileName := '';
    if not SaveDialog1.Execute then
      Exit;
    SetDocFileName(Doc, SaveDialog1.FileName);
  end;
  Doc.Editor.Lines.SaveToFile(Doc.FileName);
  SetDocModified(Doc, False);
  Result := True;
end;

procedure TFrmMain.mnuExportarHtmlClick(Sender: TObject);
var
  Html: string;
  SL: TStringList;
  Title: string;
begin
  if SaveHtmlDialog.Execute then
  begin
    if (ActiveDoc <> nil) and (ActiveDoc.FileName <> '') then
      Title := ChangeFileExt(ExtractFileName(ActiveDoc.FileName), '')
    else
      Title := 'mdTool';
    Html := MarkdownToHtmlPage(ActiveEditor.Lines.Text, Title);
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
  if ActiveEditor <> nil then
    ActiveEditor.Undo;
end;

procedure TFrmMain.mnuRehacerClick(Sender: TObject);
begin
  if ActiveEditor <> nil then
    ActiveEditor.Redo;
end;

procedure TFrmMain.mnuCortarClick(Sender: TObject);
begin
  if ActiveEditor <> nil then
    ActiveEditor.CutToClipboard;
end;

procedure TFrmMain.mnuCopiarClick(Sender: TObject);
begin
  if FViewerMax then
    HtmlPreview.CopyToClipboard
  else if ActiveEditor <> nil then
    ActiveEditor.CopyToClipboard;
end;

procedure TFrmMain.mnuPegarClick(Sender: TObject);
begin
  if ActiveEditor <> nil then
    ActiveEditor.PasteFromClipboard;
end;

procedure TFrmMain.mnuSelTodoClick(Sender: TObject);
begin
  if ActiveEditor <> nil then
    ActiveEditor.SelectAll;
end;

procedure TFrmMain.mnuBuscarClick(Sender: TObject);
begin
  ShowFindDialog(Self, False);
end;

procedure TFrmMain.mnuReemplazarClick(Sender: TObject);
begin
  ShowFindDialog(Self, True);
end;

procedure TFrmMain.mnuBuscarSigClick(Sender: TObject);
begin
  if FFindText = '' then
    mnuBuscarClick(Sender)
  else
    FindNext(False);
end;

procedure TFrmMain.mnuBuscarAntClick(Sender: TObject);
begin
  if FFindText = '' then
    mnuBuscarClick(Sender)
  else
    FindNext(True);
end;

procedure TFrmMain.SetFind(const AText: string; AOptions: TSynSearchOptions;
  const AReplace: string);
begin
  FFindText := AText;
  FFindOpts := AOptions;
  FReplaceText := AReplace;
end;

function TFrmMain.SelectedOrEmpty: string;
begin
  Result := '';
  if ActiveEditor = nil then
    Exit;
  if ActiveEditor.SelAvail then
  begin
    Result := ActiveEditor.SelText;
    if (Pos(#10, Result) > 0) or (Pos(#13, Result) > 0) or
      (Length(Result) > 80) then
      Result := '';
  end;
end;

procedure TFrmMain.ShowStatus(const S: string);
begin
  if StatusBar1.Panels.Count > 0 then
    StatusBar1.Panels[0].Text := S;
end;

function TFrmMain.FindNext(ABackwards: Boolean): Boolean;
var
  Opts: TSynSearchOptions;
  Saved: TPoint;
begin
  Result := False;
  if (FFindText = '') or (ActiveEditor = nil) then
    Exit;
  Opts := FFindOpts - [ssoReplace, ssoReplaceAll, ssoEntireScope, ssoPrompt];
  if ABackwards then
    Include(Opts, ssoBackwards)
  else
    Exclude(Opts, ssoBackwards);
  try
    Result := ActiveEditor.SearchReplace(FFindText, '', Opts) > 0;
    if not Result then
    begin
      // Segunda pasada con wrap desde el otro extremo
      Saved := ActiveEditor.CaretXY;
      if ABackwards then
        ActiveEditor.CaretXY :=
          Point(Length(ActiveEditor.Lines[ActiveEditor.Lines.Count - 1]) + 1,
          ActiveEditor.Lines.Count)
      else
        ActiveEditor.CaretXY := Point(1, 1);
      Result := ActiveEditor.SearchReplace(FFindText, '', Opts) > 0;
      if Result then
      begin
        if ABackwards then
          ShowStatus('Búsqueda reiniciada desde el final')
        else
          ShowStatus('Búsqueda reiniciada desde el inicio');
      end
      else
      begin
        ActiveEditor.CaretXY := Saved;
        ShowStatus('No encontrado: ' + FFindText);
      end;
    end;
  except
    on E: Exception do
      ShowStatus('Error al buscar: ' + E.Message);
  end;
end;

function TFrmMain.MatchSelected: Boolean;
var
  S: string;
begin
  Result := False;
  if ActiveEditor = nil then
    Exit;
  if (FFindText = '') or not ActiveEditor.SelAvail then
    Exit;
  S := ActiveEditor.SelText;
  if ssoMatchCase in FFindOpts then
    Result := S = FFindText
  else
    Result := AnsiSameText(S, FFindText);
end;

function TFrmMain.ReplaceCurrent: Boolean;
begin
  Result := False;
  if (FFindText = '') or (ActiveEditor = nil) then
    Exit;
  try
    if MatchSelected then
    begin
      ActiveEditor.BeginUndoBlock;
      try
        ActiveEditor.SelText := FReplaceText;
      finally
        ActiveEditor.EndUndoBlock;
      end;
      ShowStatus('Reemplazado');
    end;
    Result := FindNext(False);
  except
    on E: Exception do
      ShowStatus('Error al reemplazar: ' + E.Message);
  end;
end;

function TFrmMain.ReplaceAll: Integer;
var
  Opts: TSynSearchOptions;
begin
  Result := 0;
  if (FFindText = '') or (ActiveEditor = nil) then
    Exit;
  Opts := FFindOpts + [ssoReplace, ssoReplaceAll, ssoEntireScope] -
    [ssoBackwards, ssoPrompt];
  try
    ActiveEditor.BeginUndoBlock;
    try
      Result := ActiveEditor.SearchReplace(FFindText, FReplaceText, Opts);
    finally
      ActiveEditor.EndUndoBlock;
    end;
    if Result = 0 then
      ShowStatus('No encontrado: ' + FFindText)
    else if Result = 1 then
      ShowStatus('1 reemplazo')
    else
      ShowStatus(Format('%d reemplazos', [Result]));
  except
    on E: Exception do
      ShowStatus('Error al reemplazar: ' + E.Message);
  end;
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
  if ActiveEditor = nil then
    Exit;
  if ActiveEditor.SelAvail then
  begin
    S := ActiveEditor.SelText;
    ActiveEditor.SelText := '[' + S + '](url)';
    // Deja el caret tras el enlace
  end
  else
  begin
    P := ActiveEditor.CaretXY;
    ActiveEditor.InsertTextAtCaret('[texto](url)');
    // Selecciona "texto" para sustituirlo directamente
    ActiveEditor.BlockBegin := Point(P.X + 1, P.Y);
    ActiveEditor.BlockEnd := Point(P.X + 6, P.Y);
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
  if ActiveEditor = nil then
    Exit;
  if (ALevel >= 1) and (ALevel <= 3) then
    PrefixLines('', ALevel);
end;

procedure TFrmMain.WrapSelection(const APrefix, ASuffix: string);
var
  S: string;
  P: TPoint;
begin
  if ActiveEditor = nil then
    Exit;
  if ActiveEditor.SelAvail then
  begin
    S := ActiveEditor.SelText;
    // Toggle: si ya está envuelto, lo desenvuelve
    if (Length(S) >= Length(APrefix) + Length(ASuffix)) and
      (Copy(S, 1, Length(APrefix)) = APrefix) and
      (Copy(S, Length(S) - Length(ASuffix) + 1, Length(ASuffix)) = ASuffix) then
      ActiveEditor.SelText :=
        Copy(S, Length(APrefix) + 1, Length(S) - Length(APrefix) - Length(ASuffix))
    else
      ActiveEditor.SelText := APrefix + S + ASuffix;
  end
  else
  begin
    ActiveEditor.InsertTextAtCaret(APrefix + ASuffix);
    // Caret entre marca de apertura y cierre
    P := ActiveEditor.CaretXY;
    P.X := P.X - Length(ASuffix);
    if P.X < 1 then
      P.X := 1;
    ActiveEditor.CaretXY := P;
  end;
end;

procedure TFrmMain.PrefixLines(const APrefix: string; AHeadingLevel: Integer);
var
  Y1, Y2, Y: Integer;
  L, Rest: string;
  i: Integer;
begin
  if ActiveEditor = nil then
    Exit;
  if ActiveEditor.SelAvail then
  begin
    Y1 := ActiveEditor.BlockBegin.Y;
    Y2 := ActiveEditor.BlockEnd.Y;
    if (Y2 > Y1) and (ActiveEditor.BlockEnd.X = 1) then
      Dec(Y2); // la selección termina al inicio de línea: no tocarla
  end
  else
  begin
    Y1 := ActiveEditor.CaretXY.Y;
    Y2 := Y1;
  end;
  ActiveEditor.BeginUndoBlock;
  try
    for Y := Y1 to Y2 do
    begin
      if (Y < 1) or (Y > ActiveEditor.Lines.Count) then
        Continue;
      L := ActiveEditor.Lines[Y - 1];
      if AHeadingLevel > 0 then
      begin
        // Quita '#' previos y aplica el nivel pedido
        i := 1;
        while (i <= Length(L)) and (L[i] = '#') do
          Inc(i);
        while (i <= Length(L)) and (L[i] = ' ') do
          Inc(i);
        Rest := Copy(L, i, MaxInt);
        ActiveEditor.Lines[Y - 1] := StringOfChar('#', AHeadingLevel) + ' ' + Rest;
      end
      else if (TrimLeft(L) = '') or (Copy(TrimLeft(L), 1, Length(APrefix)) = APrefix) then
      begin
        // Línea vacía o ya prefijada: no duplicar
      end
      else
        ActiveEditor.Lines[Y - 1] := APrefix + L;
    end;
  finally
    ActiveEditor.EndUndoBlock;
  end;
  // La asignación directa a Lines[] no dispara OnChange: marcar y
  // refrescar a mano.
  SetDocModified(ActiveDoc, True);
  if mnuAutoActualizar.Checked then
    UpdatePreview;
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
  if ActiveEditor = nil then
    Exit;
  FontDialog1.Font.Assign(ActiveEditor.Font);
  if FontDialog1.Execute then
  begin
    FEditorFontName := FontDialog1.Font.Name;
    FEditorFontSize := FontDialog1.Font.Size;
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

procedure TFrmMain.mnuMaxVisorClick(Sender: TObject);
begin
  SetViewerMax(not FViewerMax);
end;

procedure TFrmMain.SetViewerMax(AValue: Boolean);
begin
  FViewerMax := AValue;
  pnlEditor.Visible := not FViewerMax;
  Splitter1.Visible := not FViewerMax;
  mnuMaxVisor.Checked := FViewerMax;
  ApplyEditMenuMode;
end;

procedure TFrmMain.ApplyEditMenuMode;
var
  E: Boolean; // True = split, edición completa
begin
  E := not FViewerMax;
  // Solo en maximizado: vuelta a edición
  mnuVolverEdicion.Visible := FViewerMax;
  mnuSepEdMax.Visible := FViewerMax;
  // Solo en split: resto de edición
  mnuDeshacer.Visible := E;
  mnuRehacer.Visible := E;
  mnuSepEd1.Visible := E;
  mnuCortar.Visible := E;
  mnuPegar.Visible := E;
  mnuSelTodo.Visible := E;
  mnuSepEdFind.Visible := E;
  mnuReemplazar.Visible := E;
  mnuSepEd2.Visible := E;
  mnuFormato.Visible := E;
  // Siempre visibles: mnuBuscar, mnuBuscarSig, mnuBuscarAnt, mnuCopiar
end;

procedure TFrmMain.mnuVolverEdicionClick(Sender: TObject);
begin
  SetViewerMax(False);
end;

procedure TFrmMain.mnuAcercaDeClick(Sender: TObject);
begin
  ShowMessage('mdTool 0.1' + LineEnding +
    'Visor/editor de Markdown en Lazarus/Free Pascal.' + LineEnding +
    'Editor: SynEdit · Preview: TIpHtmlPanel.');
end;

procedure TFrmMain.UpdatePreview;
var
  Html: string;
  Ed: TSynEdit;
begin
  Ed := ActiveEditor;
  if Ed = nil then
    Exit;
  Html := '<!DOCTYPE html>' + LineEnding +
    '<html><head><meta charset="utf-8"><style>' + MarkdownCss +
    '</style></head><body>' + LineEnding +
    MarkdownToHtml(Ed.Lines.Text) +
    LineEnding + '</body></html>';
  try
    HtmlPreview.LoadFromString(Html);
    // Mantiene la posición tras recargar el documento
    SyncPreviewScroll;
  except
    on E: Exception do
      StatusBar1.Panels[0].Text := 'Error preview: ' + E.Message;
  end;
end;

procedure TFrmMain.UpdateCaption;
var
  Doc: TDocInfo;
  DocName: string;
begin
  Doc := ActiveDoc;
  if (Doc = nil) or (Doc.FileName = '') then
    DocName := 'sin título'
  else
    DocName := ExtractFileName(Doc.FileName);
  if (Doc <> nil) and Doc.Modified then
    Caption := 'mdTool — ' + DocName + ' *'
  else
    Caption := 'mdTool — ' + DocName;
end;

procedure TFrmMain.UpdateStatus;
var
  Pos: TPoint;
  Doc: TDocInfo;
  Ed: TSynEdit;
begin  if StatusBar1.Panels.Count < 4 then
    Exit; // FormCreate aún no ha creado los paneles
  Doc := ActiveDoc;
  Ed := ActiveEditor;
  if (Doc = nil) or (Doc.FileName = '') then
    StatusBar1.Panels[0].Text := 'sin título'
  else
    StatusBar1.Panels[0].Text := Doc.FileName;
  if (Doc <> nil) and Doc.Modified then
    StatusBar1.Panels[1].Text := 'Modificado'
  else
    StatusBar1.Panels[1].Text := '';
  if Ed <> nil then
  begin
    Pos := Ed.CaretXY;
    StatusBar1.Panels[2].Text := Format('Ln %d, Col %d', [Pos.Y, Pos.X]);
  end
  else
    StatusBar1.Panels[2].Text := '';
  if StatusBar1.Panels.Count > 3 then
    StatusBar1.Panels[3].Text := Format('Visor %dpt (%d%%)',
      [FViewerFontSize, Round(FViewerFontSize / 12 * 100)]);
end;

procedure TFrmMain.SyncPreviewScroll;
var
  Frac: Double;
  Count: Integer;
  Ed: TSynEdit;
begin
  // Sincronía proporcional: la posición del caret en el editor
  // se refleja en el scroll vertical del visor (solo editor→visor,
  // sin bucles de realimentación).
  Ed := ActiveEditor;
  if Ed = nil then
    Exit;
  Count := Ed.Lines.Count;
  if Count <= 1 then
    Frac := 0
  else
    Frac := (Ed.CaretXY.Y - 1) / (Count - 1);
  if Frac < 0 then
    Frac := 0;
  if Frac > 1 then
    Frac := 1;
  HtmlPreview.VScrollBarPosition :=
    Round(Frac * HtmlPreview.VScrollBarRange);
end;

procedure TFrmMain.ApplyEditorFont;
var
  i: Integer;
  Doc: TDocInfo;
begin
  // La fuente se aplica a todos los editores abiertos
  for i := 0 to PageControl1.PageCount - 1 do
  begin
    Doc := TDocInfo(PageControl1.Pages[i].Tag);
    if (Doc <> nil) and (Doc.Editor <> nil) then
    begin
      Doc.Editor.Font.Name := FEditorFontName;
      Doc.Editor.Font.Size := FEditorFontSize;
      Doc.Editor.Font.Pitch := fpFixed;
    end;
  end;
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
  FEditorFontName := 'Monospace';
  FEditorFontSize := 10;
  FViewerFontSize := 12;
  Cfg := ConfigFile;
  if not FileExists(Cfg) then
    Exit;
  Ini := TIniFile.Create(Cfg);
  try
    FEditorFontName := Ini.ReadString('Editor', 'FontName', FEditorFontName);
    FEditorFontSize := Ini.ReadInteger('Editor', 'FontSize', FEditorFontSize);
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
      Ini.WriteString('Editor', 'FontName', FEditorFontName);
      Ini.WriteInteger('Editor', 'FontSize', FEditorFontSize);
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
