import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../services"
import "../components"

// System tray recolhido atrás da setinha.
Row {
    id: root

    spacing: 2

    Clickable {
        anchors.verticalCenter: parent.verticalCenter
        hoverColor: Theme.alpha(Theme.primary, 0.15)
        implicitWidth: arrow.implicitWidth + 12
        implicitHeight: arrow.implicitHeight + 4
        tooltip: Panels.trayRevealed ? "Recolher a bandeja"
            : SystemTray.items.values.length === 1 ? "1 ícone na bandeja"
            : `${SystemTray.items.values.length} ícones na bandeja`

        MonoText {
            id: arrow
            anchors.centerIn: parent
            text: Panels.trayRevealed ? "\u{F0142}" : "\u{F0141}"
            color: Theme.fgDim
        }

        onClicked: Panels.trayRevealed = !Panels.trayRevealed
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: Panels.trayRevealed ? items.implicitWidth : 0
        height: items.implicitHeight
        clip: true

        Behavior on width {
            Anim { curve: "fast" }
        }

        Row {
            id: items
            spacing: 2

            Repeater {
                model: SystemTray.items

                delegate: Clickable {
                    id: trayItem

                    required property SystemTrayItem modelData

                    hoverColor: Theme.alpha(Theme.primary, 0.15)
                    implicitWidth: 26
                    implicitHeight: 24
                    tooltip: modelData.tooltipTitle || modelData.title || modelData.id
                    // muitos apps de bandeja tratam scroll (volume, brilho…)
                    scrollable: true

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: trayItem.modelData.icon
                    }

                    QsMenuAnchor {
                        id: menuAnchor
                        menu: trayItem.modelData.menu
                        anchor.window: trayItem.QsWindow.window

                        anchor.onAnchoring: {
                            const win = trayItem.QsWindow.window;
                            const pos = win.contentItem.mapFromItem(trayItem, 0, trayItem.height + 4);
                            menuAnchor.anchor.rect.x = pos.x;
                            menuAnchor.anchor.rect.y = pos.y;
                        }
                    }

                    onClicked: {
                        if (trayItem.modelData.onlyMenu)
                            menuAnchor.open();
                        else
                            trayItem.modelData.activate();
                    }

                    onRightClicked: menuAnchor.open()

                    onScrolled: dir => trayItem.modelData.scroll(dir * 120, false)
                }
            }
        }
    }
}
