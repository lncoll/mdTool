# mdTool

Visor y editor de ficheros Markdown (`.md`) con entorno gráfico, hecho en
Lazarus / Free Pascal.

Vista dividida: editas a la izquierda en `TSynEdit` y ves el resultado a la
derecha en `THtmlViewer`, con actualización automática.

## Características

- Nuevo / Abrir / Guardar / Guardar como / Exportar a HTML
- Vista previa con retardo anti-rebote (400 ms), botón y tecla `F5`, con
  auto-actualización conmutable
- Menú **Editar**: Deshacer / Rehacer, Cortar / Copiar / Pegar /
  Seleccionar todo, y submenú **Formato** (Títulos 1–3, Negrita, Cursiva,
  Tachado, Código, Enlace, Cita, Lista). Negrita/cursiva/tachado/código
  conmutan si el texto ya está marcado
- Menú contextual con botón derecho en el editor
- Fuente del editor configurable (persiste entre sesiones)
- Tamaño del visor ajustable (persiste entre sesiones)
- Parser Markdown propio (`markdown.pas`): headings, énfasis, código
  (cercado e indentado), listas, citas, enlaces, imágenes, líneas
  horizontales y **tablas GFM** con alineación (`:--`, `:-:`, `--:`)
- Estilos del visor y la exportación en una sola hoja (`MarkdownCss`):
  bloques de código y citas con fondo propio, tablas con rejilla simple y
  filas alternadas
- Barra de estado: fichero, modificado, línea/columna, zoom del visor
- Apertura desde línea de comandos: `mdtool documento.md`

## Atajos

| Acción                   | Atajo                |
|--------------------------|----------------------|
| Nuevo / Abrir / Guardar  | `Ctrl+N` `Ctrl+O` `Ctrl+S` |
| Deshacer / Rehacer       | `Ctrl+Z` / `Ctrl+Y`  |
| Cortar / Copiar / Pegar  | `Ctrl+X` `Ctrl+C` `Ctrl+V` |
| Seleccionar todo         | `Ctrl+A`             |
| Negrita / Cursiva        | `Ctrl+B` / `Ctrl+I`  |
| Tachado / Código / Enlace| `Ctrl+D` / `` Ctrl+` `` / `Ctrl+K` |
| Título 1 / 2 / 3         | `Ctrl+1` / `Ctrl+2` / `Ctrl+3` |
| Cita / Lista             | `Ctrl+Q` / `Ctrl+L`  |
| Fuente del editor        | `Ctrl+E`             |
| Agrandar / achicar visor | `Ctrl++` / `Ctrl+-`  |
| Restablecer zoom         | `Ctrl+0`             |
| Actualizar vista previa  | `F5`                 |

## Requisitos

- Free Pascal 3.2.x
- Lazarus 4.x (`lazbuild`)
- Widgetset GTK2 en Linux (por defecto)
- Paquetes LCL: `LCL`, `SynEdit`
- Fuentes de [HtmlViewer](https://github.com/BerndGabriel/HtmlViewer)
  (rama `HtmlViewer-11.10`) clonadas **al lado** del proyecto; se usan por
  ruta de unidades, sin instalar nada en el IDE:

```bash
git clone --branch HtmlViewer-11.10 \
  https://github.com/BerndGabriel/HtmlViewer ../htmlviewer
```

## Compilar y ejecutar

```bash
lazbuild mdtool.lpi
./mdtool [fichero.md]
```

> Si el enlazado GTK2 falla por falta de `libgtk2.0-dev`
> (`cannot find -lgdk-x11-2.0`), instálalo con
> `sudo apt install libgtk2.0-dev`.

## Estructura

```
mdtool.lpr    programa principal
mdtool.lpi    proyecto Lazarus
mainform.pas  formulario principal (editor + preview + menús)
mainform.lfm  diseño del formulario
markdown.pas  parser Markdown → HTML + hoja de estilos
synmarkdown.pas highlighter Markdown para SynEdit
```

## Notas técnicas

- Los atajos se gestionan en `FormKeyDown` con `KeyPreview` porque
  `TSynEdit` consume las teclas cuando tiene el foco; `Ctrl++` no existe
  como tecla LCL y se muestra en el caption del menú.
- El `TSynEdit` creado por streaming no trae bindings de teclado (el
  constructor los omite con `csLoading`); se restauran con
  `SetDefaultKeystrokes` en `FormCreate`.
- Tras modificar solo el `.lfm`, compilar con `lazbuild -B`, ya que el
  recurso no invalida la caché de unidades.
- `border-radius` está en el CSS (se ve en el HTML exportado), pero el
  motor HtmlViewer no lo implementa: en el visor las cajas son cuadradas.

## Roadmap

- [x] Resaltado Markdown en SynEdit (`TSynMarkdownSyn`)
- [ ] Task-lists y footnotes GFM
- [ ] Buscar / reemplazar
- [ ] Pestañas multi-documento
- [ ] Arrastrar y soltar `.md`
- [ ] Tema oscuro
- [ ] Exportar a PDF
