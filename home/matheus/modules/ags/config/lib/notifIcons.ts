import { Gtk } from "astal/gtk3"
import GLib from "gi://GLib"

const appIcons: Record<string, string> = {
    "firefox": "󰈹",
    "zen": "󰈹",
    "chromium": "󰊯",
    "google-chrome": "󰊯",
    "chrome": "󰊯",
    "brave": "󰖟",
    "telegram": "󰔁",
    "whatsapp": "󰖣",
    "discord": "󰙯",
    "spotify": "󰓇",
    "slack": "󰒱",
    "thunderbird": "󰇮",
    "steam": "󰓓",
    "obs": "󰑋",
    "vlc": "󰕼",
    "nautilus": "󰉋",
    "thunar": "󰉋",
    "dolphin": "󰉋",
    "terminal": "󰆍",
    "kitty": "󰆍",
    "alacritty": "󰆍",
    "foot": "󰆍",
    "ghostty": "󰆍",
    "code": "󰨞",
    "vscode": "󰨞",
    "notify-send": "󰂚",
}

export function getNerdIcon(n: any): string | null {
    const appName = (n.get_app_name() || "").toLowerCase()
    for (const [key, icon] of Object.entries(appIcons)) {
        if (appName.includes(key)) return icon
    }
    return null
}

export function getFileIcon(n: any): string | null {
    // ícones de notificação web (Chrome) são temporários e podem já ter
    // sumido — sem o teste o <icon> renderiza um quadrado vazio e o
    // fallback nerd nunca age
    const exists = (p: string) => GLib.file_test(p, GLib.FileTest.EXISTS)
    const appIcon = n.get_app_icon?.() || ""
    if (appIcon.startsWith("/") && exists(appIcon)) return appIcon
    const image = n.get_image?.() || ""
    if (image.startsWith("/") && exists(image)) return image
    return null
}

export function getThemeIconName(n: any): string | null {
    const appIcon = n.get_app_icon?.() || ""
    if (appIcon && !appIcon.startsWith("/")) {
        const theme = Gtk.IconTheme.get_default()
        if (theme.has_icon(appIcon)) return appIcon
    }
    return null
}

export function cleanAppName(n: any): string {
    const name = n.get_app_name() || ""
    if (!name) return "Notificação"
    return name.replace(/https?:\/\/\S+/g, "").trim() || "Notificação"
}
