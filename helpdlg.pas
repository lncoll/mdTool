unit HelpDlg;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TFrmHelp }

  TFrmHelp = class(TForm)
    memHelp: TMemo;
    btnClose: TButton;
    procedure btnCloseClick(Sender: TObject);
  end;

procedure ShowHelpDialog(AOwner: TComponent);

const
  HELP_TEXT =
    'mdTool 0.1.2 — Editor y visor de Markdown' + LineEnding +
    'Autor: lncoll' + LineEnding +
    LineEnding +
    'USO' + LineEnding +
    '- Escribe Markdown en el editor (izquierda o arriba); la vista' + LineEnding +
    '  previa se actualiza sola. F5 la actualiza a mano.' + LineEnding +
    '- Clic en el visor: el cursor del editor salta a esa línea.' + LineEnding +
    '- Botón derecho en el visor: Copiar (solo con texto seleccionado).' + LineEnding +
    '- Pestañas: Ctrl+Tab cambia de documento, Ctrl+W cierra la' + LineEnding +
    '  pestaña. El asterisco (*) delante del nombre indica cambios' + LineEnding +
    '  sin guardar; la X de la solapa la cierra.' + LineEnding +
    '- F11 maximiza el visor; Ver > Disposición alterna lado a lado' + LineEnding +
    '  y uno encima de otro.' + LineEnding +
    '- Arrastra ficheros .md a la ventana o ábrelos con Archivo.' + LineEnding +
    '- Archivo > Exportar a HTML genera una página completa.' + LineEnding +
    LineEnding +
    'ATAJOS' + LineEnding +
    'Archivo: Ctrl+N nuevo, Ctrl+O abrir, Ctrl+S guardar,' + LineEnding +
    '  Ctrl+W cerrar pestaña, Ctrl+Tab / Ctrl+Mayús+Tab cambiar.' + LineEnding +
    'Editar: Ctrl+Z deshacer, Ctrl+Y rehacer, Ctrl+X/C/V/A' + LineEnding +
    '  cortar, copiar, pegar, seleccionar todo.' + LineEnding +
    'Buscar: Ctrl+F buscar, Ctrl+H reemplazar, F3 y Mayús+F3' + LineEnding +
    '  siguiente y anterior.' + LineEnding +
    'Formato: Ctrl+1/2/3 títulos, Ctrl+B negrita, Ctrl+I cursiva,' + LineEnding +
    '  Ctrl+D tachado, Ctrl+J código, Ctrl+K enlace, Ctrl+Q cita,' + LineEnding +
    '  Ctrl+L lista.' + LineEnding +
    'Ver: F5 actualizar, Ctrl+0/+/− zoom,' + LineEnding +
    '  F11 maximizar, Ctrl+E fuente del editor.' + LineEnding;

implementation

{$R *.lfm}

procedure ShowHelpDialog(AOwner: TComponent);
begin
  with TFrmHelp.Create(AOwner) do
  try
    memHelp.Lines.Text := HELP_TEXT;
    memHelp.SelStart := 0;
    ShowModal;
  finally
    Free;
  end;
end;

procedure TFrmHelp.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
