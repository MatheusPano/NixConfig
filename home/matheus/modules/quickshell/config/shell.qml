import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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

    // ── atalhos globais do Hyprland: o compositor entrega a tecla direto
    // pro processo da shell — sem spawnar o CLI qs a cada aperto (que era
    // o ~meio segundo de atraso pra abrir os painéis) ──
    GlobalShortcut {
        appid: "quickshell"
        name: "zen"
        onPressed: Theme.toggleZen()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "sidebar"
        onPressed: Panels.qsOpen = !Panels.qsOpen
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "center"
        onPressed: Panels.centerOpen = !Panels.centerOpen
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "wallpaper"
        onPressed: Panels.wpOpen = !Panels.wpOpen
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "clipboard"
        onPressed: Panels.clipOpen = !Panels.clipOpen
    }

    // ── IPC: qs ipc call panel <fn> (uso manual / scripts) ──
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
            // dispatcher `global`: aciona os GlobalShortcut declarados acima.
            // Sem aspas nos binds: o execDetached não passa por shell, então
            // aspas iriam literais pro hyprctl (bind morto).
            const binds = [
                "keyword unbind SUPER,B",
                "keyword unbind SUPER,N",
                "keyword unbind SUPER,A",
                "keyword unbind SUPER SHIFT,W",
                "keyword unbind SUPER,V",
                "keyword bind SUPER,B,global,quickshell:zen",
                "keyword bind SUPER,N,global,quickshell:sidebar",
                "keyword bind SUPER,A,global,quickshell:center",
                "keyword bind SUPER SHIFT,W,global,quickshell:wallpaper",
                "keyword bind SUPER,V,global,quickshell:clipboard",
                // a shell anima os próprios painéis; a animação de layers do
                // Hyprland por cima só deixava o início do slide mole
                // (sintaxe de rules do Hyprland 0.56+: campo + match:)
                "keyword layerrule animation none, match:namespace quickshell.*",
                `keyword general:gaps_out ${Theme.gapsOutFor(Theme.zen)}`,
            ].join(" ; ");
            Quickshell.execDetached(["hyprctl", "--batch", binds]);
        }
    }
}
