import { Gtk } from "astal/gtk3"

const appIcons: Record<string, string> = {
    "firefox": "󰈹",
    "zen": "󰈹",
    "chromium": "󰊯",
    "google-chrome": "󰊯",
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
    const appIcon = n.get_app_icon?.() || ""
    if (appIcon.startsWith("/")) return appIcon
    const image = n.get_image?.() || ""
    if (image.startsWith("/")) return image
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
    if (!name) return "Notificacao"
    return name.replace(/https?:\/\/\S+/g, "").trim() || "Notificacao"
}
