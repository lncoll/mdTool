#!/bin/bash
# Construye dist/mdtool_X.Y.Z_amd64.deb desde el binario ya compilado.
# Uso: packaging/make-deb.sh [versión]
set -e
VERSION="${1:-0.1.2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/dist/pkgroot"
OUT="$ROOT/dist/mdtool_${VERSION}_amd64.deb"
if [ ! -x "$ROOT/mdtool" ]; then
  echo "error: compila primero con: lazbuild mdtool.lpi" >&2
  exit 1
fi
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK/DEBIAN" "$WORK/usr/bin" \
  "$WORK/usr/share/applications" \
  "$WORK/usr/share/icons/hicolor/64x64/apps"
cp "$ROOT/mdtool" "$WORK/usr/bin/mdtool"
strip --strip-all "$WORK/usr/bin/mdtool"
chmod 755 "$WORK/usr/bin/mdtool"
cp "$ROOT/packaging/mdtool.desktop" "$WORK/usr/share/applications/"
cp "$ROOT/packaging/mdtool.png" "$WORK/usr/share/icons/hicolor/64x64/apps/"
cat > "$WORK/DEBIAN/control" <<EOF
Package: mdtool
Version: $VERSION
Section: editors
Priority: optional
Architecture: amd64
Depends: libgtk2.0-0t64 | libgtk2.0-0
Maintainer: lncoll
Description: Editor y visor de Markdown
 Visor y editor de ficheros Markdown con vista dividida,
 resaltado, pestañas y exportación a HTML.
EOF
mkdir -p "$ROOT/dist"
dpkg-deb --build "$WORK" "$OUT"
echo "OK: $OUT"
ls -la "$OUT"
