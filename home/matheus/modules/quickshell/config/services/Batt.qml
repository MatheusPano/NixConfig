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

    // ── avisos ───────────────────────────────────────────────
    // O level acima só pintava ícone; ninguém avisava nada. Aqui cada
    // patamar dispara uma vez na descida e rearma quando volta a carregar.
    readonly property var warnSteps: [20, 10, 5]

    // menor patamar já avisado nesta descarga (101 = nenhum)
    property int _warned: 101

    // desligar antes do corte seco: abaixo disso o kernel pode desligar no
    // meio de uma escrita. É o mesmo 3% que o GNOME usa.
    readonly property int suspendAt: 3
    property bool _suspending: false

    function _notify(urgency, title, body) {
        // sem -i: "battery-low" não existe no tema de ícones daqui e o Qt
        // reclamava "Could not load icon" a cada aviso. O NotifIcon já cai
        // no glifo nerd pelo nome do app.
        Quickshell.execDetached(["notify-send", "-a", "Bateria", "-u", urgency,
            title, body]);
    }

    function _check() {
        if (!present || !Panels.ready)
            return;

        if (charging) {
            _warned = 101;
            _suspending = false;
            return;
        }

        for (const step of warnSteps) {
            if (percent <= step && _warned > step) {
                _warned = step;
                const rest = eta !== "" ? eta : "sem estimativa";
                _notify(step <= 10 ? "critical" : "normal",
                    `Bateria em ${percent}%`,
                    step <= 5 ? `Vou suspender em ${suspendAt}%. ${rest}.` : `${rest}. Melhor plugar.`);
                Panels.trigger("battery", Fmt.batIcon(percent, false),
                    `Bateria ${percent}%`, Math.max(0, percent / 100), 4000);
                break;
            }
        }

        if (percent <= suspendAt && !_suspending) {
            _suspending = true;
            _notify("critical", "Bateria crítica", "Suspendendo agora.");
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    onPercentChanged: _check()
    onChargingChanged: _check()
}
