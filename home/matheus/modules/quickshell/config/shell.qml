import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "services"
import "bar"
import "panels"
import "components"

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

    SessionMenu {}

    WindowSwitcher {}

    // agente polkit: dorme registrado até alguém pedir autorização
    PolkitDialog {}

    // segura a tela acesa no café / modo jogo
    IdleGuard {}

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

    GlobalShortcut {
        appid: "quickshell"
        name: "session"
        onPressed: Panels.sessionOpen = !Panels.sessionOpen
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "game"
        onPressed: Toggles.toggleGameMode()
    }

    // Alt+Tab: repetir o atalho anda na lista em vez de reabrir — o
    // Hyprland consome a tecla no bind e ela nunca chega no painel
    GlobalShortcut {
        appid: "quickshell"
        name: "switcher"
        onPressed: Panels.switcherAdvance(1)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "switcherPrev"
        onPressed: Panels.switcherAdvance(-1)
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
        function calendar(): void {
            Panels.calendarOpen = !Panels.calendarOpen;
        }
        function media(): void {
            Panels.mediaOpen = !Panels.mediaOpen;
        }
        function tray(): void {
            Panels.trayRevealed = !Panels.trayRevealed;
        }
        function tab(name: string): void {
            if (["home", "sistema", "media", "wallpaper"].includes(name))
                Panels.openCenterTab(name);
        }
        function session(): void {
            Panels.sessionOpen = !Panels.sessionOpen;
        }
        function switcher(): void {
            Panels.switcherAdvance(1);
        }
        function game(): void {
            Toggles.toggleGameMode();
        }
    }

    // Os binds das teclas moram no hyprland.conf (bind = ..., global,
    // quickshell:*) e apontam direto pros GlobalShortcut acima — não há mais
    // rebind em runtime. O que sobrou aqui é estado global do Hyprland que
    // depende do tema, então só pode ser aplicado depois da shell subir.
    // Gated pelo Theme.managed: instância de teste não mexe na sessão real.
    Timer {
        running: Theme.managed
        interval: 3000
        onTriggered: {
            const rules = [
                // a shell anima os próprios painéis; a animação de layers do
                // Hyprland por cima só deixava o início do slide mole
                // (sintaxe de rules do Hyprland 0.56+: campo + match:)
                "keyword layerrule animation none, match:namespace quickshell.*",
                `keyword general:gaps_out ${Theme.gapsOutFor(Theme.zen)}`,
            ].join(" ; ");
            Quickshell.execDetached(["hyprctl", "--batch", rules]);
        }
    }
}
