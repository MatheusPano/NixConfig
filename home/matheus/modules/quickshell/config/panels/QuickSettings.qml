import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../services"
import "../components"

// Sidebar de ajustes rápidos (Super+N): header, utilidades, toggles estilo
// Control Center, sliders, abas (notif/wifi/bt/som) e a fileira de energia.
PopupPanel {
    id: root

    open: Panels.qsOpen
    onDismissed: Panels.qsOpen = false
    slide: "right"

    // painel flutuante: descolado da moldura e abaixo da barra, cantos
    // redondos por inteiro (estilo illogical-impulse). A janela encosta na
    // borda da tela e o vão de 14px fica DENTRO dela — se a margem fosse da
    // janela, o slide aparecia cortado reto no meio do ar.
    anchors {
        top: true
        bottom: true
        right: true
    }

    margins {
        top: Panels.barHeight + 10
        bottom: 14
    }

    implicitWidth: 484 + 14

    readonly property var tabIds: ["notif", "wifi", "bluetooth", "sound"]

    function cycleTab(dir) {
        const cur = tabIds.indexOf(Panels.qsTab);
        Panels.qsTab = tabIds[(cur + dir + tabIds.length) % tabIds.length];
    }

    onKeyPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right || event.key === Qt.Key_L)
            cycleTab(1);
        else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left || event.key === Qt.Key_H)
            cycleTab(-1);
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_4)
            Panels.qsTab = tabIds[event.key - Qt.Key_1];
        else
            return;
        event.accepted = true;
    }

    onOpenChanged: {
        if (open) {
            Toggles.refresh();
            Net.refresh();
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: 14
        color: Theme.surface
        radius: 20
        border.width: 1
        border.color: Theme.separator

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 16
            spacing: 8

            // ── header: data/hora + pílula de bateria ──
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4

                ColumnLayout {
                    id: headerClock

                    Layout.fillWidth: true
                    spacing: 0

                    property date now: new Date()

                    Timer {
                        running: root.open
                        interval: 10000
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: headerClock.now = new Date()
                    }

                    UiText {
                        text: Fmt.longDate(headerClock.now)
                        font.pixelSize: 13
                        color: Theme.fgDim
                    }

                    UiText {
                        text: `${Fmt.pad(headerClock.now.getHours())}:${Fmt.pad(headerClock.now.getMinutes())}`
                        font.pixelSize: 28
                        font.bold: true
                    }
                }

                Rectangle {
                    visible: Batt.present
                    radius: 999
                    color: Batt.level === "charging" ? Theme.alpha(Theme.green, 0.18)
                        : Batt.level === "critical" ? Theme.alpha(Theme.red, 0.16)
                        : Batt.level === "low" ? Theme.alpha(Theme.yellow, 0.18)
                        : Theme.card
                    implicitWidth: batRow.implicitWidth + 20
                    implicitHeight: 30

                    Row {
                        id: batRow
                        anchors.centerIn: parent
                        spacing: 5

                        IconLabel {
                            text: Batt.icon
                            font.pixelSize: 14
                            color: Batt.level === "charging" ? Theme.green
                                : Batt.level === "critical" ? Theme.red
                                : Batt.level === "low" ? Theme.yellow : Theme.fgMid
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        UiText {
                            text: `${Batt.percent}%`
                            font.pixelSize: 12
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // ── utilidades: capturas + perfil de energia ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                component ShotButton: Clickable {
                    property alias icon: shotIcon.text
                    property bool warn: false

                    baseColor: Theme.card
                    radius: 9
                    implicitWidth: 34
                    implicitHeight: 28

                    IconLabel {
                        id: shotIcon
                        anchors.centerIn: parent
                        font.pixelSize: 14
                        color: parent.warn ? Theme.red : Theme.fgMid
                    }
                }

                ShotButton {
                    icon: "\u{F0A6D}"
                    onClicked: Toggles.screenshot(true)
                }

                ShotButton {
                    icon: "\u{F0E51}"
                    onClicked: Toggles.screenshot(false)
                }

                ShotButton {
                    visible: Toggles.hasRecorder
                    icon: Toggles.recording ? "\u{F0666}" : "\u{F044B}"
                    warn: Toggles.recording
                    onClicked: Toggles.toggleRecord()
                }

                ShotButton {
                    visible: Toggles.hasPicker
                    icon: "\u{F020B}"
                    onClicked: Toggles.pickColor()
                }

                Item {
                    Layout.fillWidth: true
                }

                Segmented {
                    visible: Toggles.powerProfile !== ""
                    segPaddingH: 9
                    value: Toggles.powerProfile
                    options: Toggles.powerProfiles.map(p => ({ id: p.id, icon: p.icon, label: "" }))
                    onSelect: id => Toggles.setPowerProfile(id)
                }
            }

            // ── toggles rápidos ──
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                component QuickToggle: Clickable {
                    id: qt_

                    property string icon: ""
                    property string label: ""
                    property bool active: false
                    property string jumpTo: ""

                    signal toggle()

                    Layout.fillWidth: true
                    baseColor: Theme.card
                    radius: 14
                    implicitHeight: 54

                    onClicked: toggle()
                    onRightClicked: {
                        if (jumpTo !== "")
                            Panels.qsTab = jumpTo;
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: qt_.active ? Theme.primary
                                : (Theme.cream ? Qt.rgba(69 / 255, 53 / 255, 39 / 255, 0.15) : Qt.rgba(1, 1, 1, 0.1))

                            Behavior on color {
                                ColorAnimation {
                                    duration: 250
                                }
                            }

                            IconLabel {
                                anchors.centerIn: parent
                                text: qt_.icon
                                font.pixelSize: 16
                                color: qt_.active ? "#ffffff" : Theme.fgMid
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            UiText {
                                Layout.fillWidth: true
                                text: qt_.label
                                font.pixelSize: 13
                                font.weight: 500
                            }

                            UiText {
                                Layout.fillWidth: true
                                text: qt_.active ? "Ativado" : "Desativado"
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }

                        IconLabel {
                            visible: qt_.jumpTo !== ""
                            text: "\u{F0142}"
                            font.pixelSize: 12
                            color: Theme.fgFaint
                        }
                    }
                }

                QuickToggle {
                    icon: "\u{F0928}"
                    label: "Wi-Fi"
                    jumpTo: "wifi"
                    active: Net.wifiEnabled
                    onToggle: Net.setWifiEnabled(!Net.wifiEnabled)
                }

                QuickToggle {
                    icon: "\u{F00AF}"
                    label: "Bluetooth"
                    jumpTo: "bluetooth"
                    active: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled
                    onToggle: Quickshell.execDetached(["bluetoothctl", "power",
                        (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? "off" : "on"])
                }

                QuickToggle {
                    icon: "\u{F009B}"
                    label: "Silêncio"
                    jumpTo: "notif"
                    active: NotifStore.dontDisturb
                    onToggle: NotifStore.setDnd(!NotifStore.dontDisturb)
                }

                QuickToggle {
                    visible: Toggles.hasNightLight
                    icon: "\u{F0594}"
                    label: "Luz noturna"
                    active: Toggles.nightLightOn
                    onToggle: Toggles.toggleNightLight()
                }

                QuickToggle {
                    icon: "\u{F001D}"
                    label: "Avião"
                    active: Toggles.airplaneOn
                    onToggle: Toggles.toggleAirplane()
                }

                QuickToggle {
                    icon: "\u{F036D}"
                    label: "Mudo do mic"
                    jumpTo: "sound"
                    active: Panels.source !== null && Panels.source.audio.muted
                    onToggle: {
                        if (Panels.source)
                            Panels.source.audio.muted = !Panels.source.audio.muted;
                    }
                }

                QuickToggle {
                    visible: Toggles.hasIdleDaemon
                    icon: "\u{F0176}"
                    label: "Café"
                    active: Toggles.caffeineOn
                    onToggle: Toggles.toggleCaffeine()
                }

                QuickToggle {
                    icon: "\u{F0450}"
                    label: "Tema claro"
                    active: Theme.cream
                    onToggle: Theme.set("main", Theme.cream ? "dark" : "cream")
                }
            }

            // ── sliders: volume + brilho ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4

                component SliderRow: RowLayout {
                    id: sliderRow

                    property alias icon: rowIcon.text
                    property real value: 0

                    signal moved(real v)
                    signal iconClicked()

                    Layout.fillWidth: true
                    spacing: 8

                    Clickable {
                        implicitWidth: 28
                        implicitHeight: 24
                        radius: 8

                        IconLabel {
                            id: rowIcon
                            anchors.centerIn: parent
                            font.pixelSize: 16
                            color: Theme.fgMid
                        }

                        onClicked: sliderRow.iconClicked()
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        value: sliderRow.value
                        onMoved: v => sliderRow.moved(v)
                    }

                    UiText {
                        text: `${Math.round(sliderRow.value * 100)}%`
                        font.pixelSize: 11
                        color: Theme.fgDim
                        Layout.preferredWidth: 36
                        horizontalAlignment: Text.AlignRight
                    }
                }

                SliderRow {
                    readonly property var audio: Panels.sink ? Panels.sink.audio : null
                    icon: audio ? Fmt.volumeIcon(audio.volume, audio.muted) : "\u{F057F}"
                    value: audio ? audio.volume : 0
                    onMoved: v => {
                        if (audio)
                            audio.volume = v;
                    }
                    onIconClicked: {
                        if (audio)
                            audio.muted = !audio.muted;
                    }
                }

                SliderRow {
                    visible: Bright.available
                    icon: Fmt.brightnessIcon(Bright.value)
                    value: Bright.value
                    onMoved: v => Bright.set(v)
                }
            }

            // ── abas ──
            Segmented {
                Layout.fillWidth: true
                Layout.topMargin: 4
                segPaddingH: 8
                value: Panels.qsTab
                options: [
                    { id: "notif", label: "Notificações", badge: NotifStore.list.length > 0 ? String(NotifStore.list.length) : "" },
                    { id: "wifi", label: "Wi-Fi" },
                    { id: "bluetooth", label: "Bluetooth" },
                    { id: "sound", label: "Som" },
                ]
                onSelect: id => Panels.qsTab = id
            }

            // ── conteúdo da aba ──
            SmoothFlick {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: tabStack.height

                Item {
                    id: tabStack
                    width: parent.width
                    height: {
                        if (Panels.qsTab === "notif")
                            return notifTab.implicitHeight;
                        if (Panels.qsTab === "wifi")
                            return wifiTab.implicitHeight;
                        if (Panels.qsTab === "bluetooth")
                            return btTab.implicitHeight;
                        return soundTab.implicitHeight;
                    }

                    component TabPage: Item {
                        property bool active: false

                        width: parent.width
                        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
                        visible: opacity > 0
                        opacity: active ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                            }
                        }
                    }

                    TabPage {
                        active: Panels.qsTab === "notif"

                        QsNotifTab {
                            id: notifTab
                            width: parent.width
                        }
                    }

                    TabPage {
                        active: Panels.qsTab === "wifi"

                        QsWifiTab {
                            id: wifiTab
                            width: parent.width
                        }
                    }

                    TabPage {
                        active: Panels.qsTab === "bluetooth"

                        QsBtTab {
                            id: btTab
                            width: parent.width
                        }
                    }

                    TabPage {
                        active: Panels.qsTab === "sound"

                        QsSoundTab {
                            id: soundTab
                            width: parent.width
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                implicitHeight: 1
                color: Theme.separator
            }

            // ── energia (reboot/desligar pedem 2 cliques) ──
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                property string armed: ""

                Timer {
                    id: disarm
                    interval: 3000
                    onTriggered: parent.armed = ""
                }

                component PowerButton: Clickable {
                    property alias icon: pIcon.text
                    property alias iconColor: pIcon.color

                    implicitWidth: 40
                    implicitHeight: 32
                    radius: 10
                    hoverColor: Theme.cardHover

                    IconLabel {
                        id: pIcon
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        color: Theme.fgDim
                    }
                }

                PowerButton {
                    icon: "\u{F033E}"
                    onClicked: Quickshell.execDetached(["hyprlock"])
                }

                PowerButton {
                    icon: "\u{F0904}"
                    onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                }

                PowerButton {
                    icon: "\u{F05FD}"
                    onClicked: Quickshell.execDetached(["uwsm", "stop"])
                }

                PowerButton {
                    icon: parent.armed === "reboot" ? "\u{F0026}" : "\u{F0709}"
                    iconColor: parent.armed === "reboot" ? Theme.yellow : Theme.fgDim
                    onClicked: {
                        if (parent.armed === "reboot") {
                            parent.armed = "";
                            Quickshell.execDetached(["systemctl", "reboot"]);
                        } else {
                            parent.armed = "reboot";
                            disarm.restart();
                        }
                    }
                }

                PowerButton {
                    icon: parent.armed === "poweroff" ? "\u{F0026}" : "⏻"
                    iconColor: parent.armed === "poweroff" ? Theme.red : Theme.fgDim
                    onClicked: {
                        if (parent.armed === "poweroff") {
                            parent.armed = "";
                            Quickshell.execDetached(["systemctl", "poweroff"]);
                        } else {
                            parent.armed = "poweroff";
                            disarm.restart();
                        }
                    }
                }
            }
        }
    }
}
