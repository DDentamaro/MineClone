#!/usr/bin/env bash
# Prepara un ambiente Linux x86_64 per test ed export (usato nella sessione M0).
# Installa Godot 4.7.2-stable in $GODOT_DIR, i template di export necessari e,
# su Debian/Ubuntu, l'Android SDK di distribuzione (build-tools 29.0.3) e lavapipe.
set -euo pipefail
VER=4.7.2
GODOT_DIR=${GODOT_DIR:-/opt/godot}
BASE=https://github.com/godotengine/godot/releases/download/${VER}-stable
TPL=~/.local/share/godot/export_templates/${VER}.stable

mkdir -p "$GODOT_DIR" "$TPL"
if [ ! -x "$GODOT_DIR/Godot_v${VER}-stable_linux.x86_64" ]; then
  curl -fsSL -o "$GODOT_DIR/godot.zip" "$BASE/Godot_v${VER}-stable_linux.x86_64.zip"
  unzip -oq "$GODOT_DIR/godot.zip" -d "$GODOT_DIR"
fi
if [ ! -f "$TPL/android_debug.apk" ]; then
  curl -fsSL -o "$GODOT_DIR/templates.tpz" "$BASE/Godot_v${VER}-stable_export_templates.tpz"
  unzip -oqj "$GODOT_DIR/templates.tpz" templates/version.txt templates/android_debug.apk \
    templates/android_release.apk templates/android_source.zip \
    templates/linux_debug.x86_64 templates/linux_release.x86_64 -d "$TPL"
fi
if command -v apt-get >/dev/null; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq android-sdk apksigner zipalign \
    mesa-vulkan-drivers xvfb >/dev/null
fi
echo "Godot: $GODOT_DIR/Godot_v${VER}-stable_linux.x86_64"
echo "Imposta export/android/android_sdk_path = /usr/lib/android-sdk nelle Editor Settings."
