unit FindDlg;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, MainForm;

type

  { TFrmFind }

  TFrmFind = class(TForm)
    lblFind: TLabel;
    edtFind: TEdit;
    lblReplace: TLabel;
    edtReplace: TEdit;
    chkCase: TCheckBox;
    chkWords: TCheckBox;
    chkRegex: TCheckBox;
    btnNext: TButton;
    btnReplace: TButton;
    btnAll: TButton;
    btnClose: TButton;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnReplaceClick(Sender: TObject);
    procedure btnAllClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    function Main: TFrmMain;
    procedure ApplyToMain;
  public
    procedure ShowFor(AReplace: Boolean);
  end;

var
  FindDialog: TFrmFind;

procedure ShowFindDialog(AOwner: TComponent; AReplace: Boolean);

implementation

uses
  SynEditTypes;

{$R *.lfm}

procedure ShowFindDialog(AOwner: TComponent; AReplace: Boolean);
begin
  if FindDialog = nil then
    FindDialog := TFrmFind.Create(AOwner);
  FindDialog.ShowFor(AReplace);
end;

function TFrmFind.Main: TFrmMain;
begin
  Result := TFrmMain(Owner);
end;

procedure TFrmFind.ApplyToMain;
var
  Opts: TSynSearchOptions;
begin
  Opts := [];
  if chkCase.Checked then
    Include(Opts, ssoMatchCase);
  if chkWords.Checked then
    Include(Opts, ssoWholeWord);
  if chkRegex.Checked then
    Include(Opts, ssoRegExpr);
  Main.SetFind(edtFind.Text, Opts, edtReplace.Text);
end;

procedure TFrmFind.ShowFor(AReplace: Boolean);
var
  Sel: string;
begin
  // Prefill con la selección actual (una línea, corta)
  Sel := Main.SelectedOrEmpty;
  if Sel <> '' then
    edtFind.Text := Sel;
  if AReplace then
  begin
    Caption := 'Reemplazar';
    edtReplace.SetFocus;
  end
  else
  begin
    Caption := 'Buscar';
    edtFind.SetFocus;
  end;
  edtFind.SelectAll;
  if not Visible then
    Show
  else
    BringToFront;
end;

procedure TFrmFind.FormShow(Sender: TObject);
begin
  // nada pendiente: el foco se pone en ShowFor
end;

procedure TFrmFind.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
  FindDialog := nil;
end;

procedure TFrmFind.btnNextClick(Sender: TObject);
begin
  ApplyToMain;
  Main.FindNext(False);
end;

procedure TFrmFind.btnReplaceClick(Sender: TObject);
begin
  ApplyToMain;
  Main.ReplaceCurrent;
end;

procedure TFrmFind.btnAllClick(Sender: TObject);
begin
  ApplyToMain;
  Main.ReplaceAll;
end;

procedure TFrmFind.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
