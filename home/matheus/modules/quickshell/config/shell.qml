import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "bar"
import "panels"

ShellRoot {
    id: root

    // Frame primeiro: mesma camada da barra, criado antes = fica embaixo
    // (os pills ficam por cima da sombra da moldura)
    Frame {}

    Bar {}

    NotificationPopups {}

    QuickSettings {}

    CenterPanel {}

    CalendarPopup {}

    MediaPopup {}

    ClipboardPopup {}

    WallpaperPicker {}

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p",
            Quickshell.env("HOME") + "/.local/state/quickshell"]);
    }

    // ── IPC: qs ipc call panel <fn> (substitui o ags request) ──
    IpcHandler {
        target: "panel"

        function zen(): void {
            Theme.toggleZen();
        }
        function sidebar(): void {
            Panels.qsOpen = !Panels.qsOpen;
        }
        function center(): void {
            Panels.centerOpen = !Panels.centerOpen;
        }
        function wallpaper(): void {
            Panels.wpOpen = !Panels.wpOpen;
        }
        function clipboard(): void {
            Panels.clipOpen = !Panels.clipOpen;
        }
        function tray(): void {
            Panels.trayRevealed = !Panels.trayRevealed;
        }
        function tab(name: string): void {
            if (["home", "sistema", "media", "wallpaper"].includes(name))
                Panels.openCenterTab(name);
        }
    }

    // O hyprland.conf ativo vem da nix store e ainda aponta pro `ags request`.
    // Rebind em runtime (mesmo padrão do initZen/initClipboard do AGS):
    // voltar pro AGS = trocar o desktop.bar, o serviço dele refaz os binds.
    // Gated pelo Theme.managed: instância de teste não rouba os binds.
    Timer {
        running: Theme.managed
        interval: 3000
        onTriggered: {
            const binds = [
                "keyword unbind SUPER,B",
                "keyword unbind SUPER,N",
                "keyword unbind SUPER,A",
                "keyword unbind SUPER SHIFT,W",
                "keyword unbind SUPER,V",
                "keyword bind 'SUPER,B,exec,qs ipc call panel zen'",
                "keyword bind 'SUPER,N,exec,qs ipc call panel sidebar'",
                "keyword bind 'SUPER,A,exec,qs ipc call panel center'",
                "keyword bind 'SUPER SHIFT,W,exec,qs ipc call panel wallpaper'",
                "keyword bind 'SUPER,V,exec,qs ipc call panel clipboard'",
                `keyword general:gaps_out ${Theme.gapsOutFor(Theme.zen)}`,
            ].join(" ; ");
            Quickshell.execDetached(["hyprctl", "--batch", binds]);
        }
    }
}
