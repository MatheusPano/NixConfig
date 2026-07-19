#!/usr/bin/env bash
# Wrapper para rodar AGS com os paths corretos no NixOS

SYSTEM_PATH=$(readlink -f /run/current-system/sw)
USER_PATH=$(readlink -f "/etc/profiles/per-user/$USER")

export GI_TYPELIB_PATH="$SYSTEM_PATH/lib/girepository-1.0:$USER_PATH/lib/girepository-1.0:${GI_TYPELIB_PATH}"

# Fallback pro AstalTray enquanto astal.tray não entra via rebuild do sistema
# (symlink criado com: nix build nixpkgs#astal.tray -o ~/.config/ags/.astal-tray)
TRAY_PKG="$HOME/.config/ags/.astal-tray"
if [ -d "$TRAY_PKG/lib/girepository-1.0" ] && [ ! -e "$USER_PATH/lib/girepository-1.0/AstalTray-0.1.typelib" ]; then
    export GI_TYPELIB_PATH="$TRAY_PKG/lib/girepository-1.0:$GI_TYPELIB_PATH"
    export LD_LIBRARY_PATH="$TRAY_PKG/lib:${LD_LIBRARY_PATH}"
fi

# Encontrar schema do notifd
for dir in /nix/store/*astal-notifd*/share/gsettings-schemas/*/glib-2.0/schemas; do
    if [ -d "$dir" ]; then
        export GSETTINGS_SCHEMA_DIR="$dir:${GSETTINGS_SCHEMA_DIR}"
        break
    fi
done

ags run -d ~/.config/ags "$@" &
AGS_PID=$!

# Aguarda a barra ficar pronta e força o Hyprland a recalcular o layout
(sleep 1 && hyprctl reload) &

wait $AGS_PID
