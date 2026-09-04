pragma Singleton
import QtQuick
import Quickshell

// Formatação e ícones utilitários (port de lib/utils.ts + pedaços dos widgets).
// Nomes de dia/mês fixos em pt-BR: independem do locale da sessão.
Singleton {
    id: root

    readonly property var weekdays: ["Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"]
    readonly property var months: ["janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]

    function pad(n) {
        return String(n).padStart(2, "0");
    }

    // "Quarta, 3 de setembro - 14:03" (estado ocioso da ilha)
    function idleClock(now) {
        return `${weekdays[now.getDay()]}, ${now.getDate()} de ${months[now.getMonth()]} - ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    }

    // "Quarta, 3 de setembro"
    function longDate(now) {
        return `${weekdays[now.getDay()]}, ${now.getDate()} de ${months[now.getMonth()]}`;
    }

    // 205s → "3:25"; 8887s → "2:28:07" (vira relógio a partir de 1h)
    function mmss(secs) {
        if (secs <= 0 || isNaN(secs))
            return "0:00";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = Math.floor(secs % 60);
        return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
    }

    function timeAgo(unixSecs) {
        const diff = Math.floor(Date.now() / 1000) - unixSecs;
        if (diff < 60)
            return "agora";
        if (diff < 3600)
            return `há ${Math.floor(diff / 60)} min`;
        if (diff < 86400)
            return `há ${Math.floor(diff / 3600)} h`;
        const d = new Date(unixSecs * 1000);
        return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
    }

    function stripHtml(text) {
        return (text || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .replace(/&#39;/g, "'")
            .replace(/&nbsp;/g, " ");
    }

    // Notificações web (Chrome) vêm com o domínio na primeira linha do corpo
    // ("web.whatsapp.com\n\nVou dormir") — separa pra dar ênfase à mensagem
    function splitNotifBody(raw) {
        const lines = (raw || "").split("\n").map(l => l.trim()).filter(l => l.length > 0);
        if (lines.length > 1 && /^[a-z0-9.-]+\.[a-z]{2,}$/i.test(lines[0]))
            return { origin: lines[0], body: lines.slice(1).join("\n") };
        return { origin: null, body: lines.join("\n") };
    }

    function playerIcon(identity) {
        const id = (identity || "").toLowerCase();
        if (id.includes("spotify"))
            return "\u{F04C7}";
        if (id.includes("firefox") || id.includes("mozilla") || id.includes("zen"))
            return "\u{F0239}";
        if (id.includes("chrome") || id.includes("chromium"))
            return "\u{F02AF}";
        if (id.includes("vlc"))
            return "\u{F057C}";
        if (id.includes("mpv"))
            return "\u{F0439}";
        return "\u{F0386}";
    }

    function volumeIcon(v, muted) {
        if (muted)
            return "\u{F0581}";
        if (v > 0.66)
            return "\u{F057E}";
        if (v > 0.33)
            return "\u{F0580}";
        return "\u{F057F}";
    }

    function wifiIcon(strength) {
        return strength > 75 ? "\u{F0928}" : strength > 50 ? "\u{F0925}" : strength > 25 ? "\u{F0922}" : "\u{F091F}";
    }

    function brightnessIcon(v) {
        return v > 0.66 ? "\u{F00E0}" : v > 0.33 ? "\u{F00DF}" : "\u{F00DE}";
    }

    readonly property var batIcons: ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]
    readonly property var batIconsCharging: ["\u{F089C}", "\u{F0086}", "\u{F0087}", "\u{F0088}", "\u{F089D}", "\u{F0089}", "\u{F089E}", "\u{F008A}", "\u{F008B}", "\u{F0085}"]

    function batIcon(percent, charging) {
        const i = Math.min(9, Math.max(0, Math.floor(percent / 10)));
        return charging ? batIconsCharging[i] : batIcons[i];
    }

    // "3h 20min restantes" / "1h 05min para carregar"
    function batteryEta(percent, charging, seconds) {
        if (seconds <= 0)
            return charging ? "Carregando" : "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const t = h > 0 ? `${h}h ${pad(m)}min` : `${m}min`;
        return charging ? `${t} para carregar` : `${t} restantes`;
    }

    function fmtRate(bytesPerSec) {
        if (bytesPerSec < 1024)
            return "0 KB/s";
        if (bytesPerSec < 1048576)
            return `${(bytesPerSec / 1024).toFixed(0)} KB/s`;
        return `${(bytesPerSec / 1048576).toFixed(1)} MB/s`;
    }

    // ── ícones nerd por app (notificações) ───────────────────
    readonly property var appIcons: ({
        "firefox": "\u{F0239}",
        "zen": "\u{F0239}",
        "chromium": "\u{F02AF}",
        "google-chrome": "\u{F02AF}",
        "chrome": "\u{F02AF}",
        "brave": "\u{F059F}",
        "telegram": "\u{F0501}",
        "whatsapp": "\u{F05A3}",
        "discord": "\u{F066F}",
        "spotify": "\u{F04C7}",
        "slack": "\u{F04B1}",
        "thunderbird": "\u{F01EE}",
        "steam": "\u{F04D3}",
        "obs": "\u{F044B}",
        "vlc": "\u{F057C}",
        "nautilus": "\u{F024B}",
        "thunar": "\u{F024B}",
        "dolphin": "\u{F024B}",
        "terminal": "\u{F018D}",
        "kitty": "\u{F018D}",
        "alacritty": "\u{F018D}",
        "foot": "\u{F018D}",
        "ghostty": "\u{F018D}",
        "code": "\u{F0A1E}",
        "vscode": "\u{F0A1E}",
        "notify-send": "\u{F009A}",
    })

    function nerdIcon(appName) {
        const name = (appName || "").toLowerCase();
        for (const key in appIcons) {
            if (name.includes(key))
                return appIcons[key];
        }
        return "";
    }

    function cleanAppName(name) {
        if (!name)
            return "Notificação";
        return name.replace(/https?:\/\/\S+/g, "").trim() || "Notificação";
    }
}
