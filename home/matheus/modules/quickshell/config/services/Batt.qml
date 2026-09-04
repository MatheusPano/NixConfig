pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Bateria via UPower (port de lib/battery.ts — o fallback sysfs morreu junto
// com o motivo dele: o upower já está habilitado no sistema).
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isLaptopBattery
    readonly property int percent: dev ? Math.round(dev.percentage * 100) : 0
    readonly property bool charging: dev
        ? dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged
        : false
    // segundos até esvaziar (ou encher, quando carregando); 0 = desconhecido
    readonly property int seconds: dev
        ? Math.round(root.charging ? dev.timeToFull : dev.timeToEmpty)
        : 0

    readonly property string eta: Fmt.batteryEta(percent, charging, seconds)
    readonly property string icon: Fmt.batIcon(percent, charging)

    // "battery" | "charging" | "low" | "critical" — pros badges coloridos
    readonly property string level: charging ? "charging"
        : percent <= 15 ? "critical"
        : percent <= 30 ? "low" : "normal"
}
