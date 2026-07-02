import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import { Variable, bind } from "astal"
import Mpris from "gi://AstalMpris"

export const mediaVisible = Variable(false)

function formatTime(secs: number): string {
    if (secs <= 0) return "0:00"
    const m = Math.floor(secs / 60)
    const s = Math.floor(secs % 60)
    return `${m}:${String(s).padStart(2, "0")}`
}

function getPlayerIcon(identity: string): string {
    const id = identity.toLowerCase()
    if (id.includes("spotify")) return "󰓇"
    if (id.includes("firefox") || id.includes("mozilla")) return "󰈹"
    if (id.includes("chrome") || id.includes("chromium")) return "󰊯"
    if (id.includes("vlc")) return "󰕼"
    if (id.includes("mpv")) return "󰐹"
    return "󰎆"
}

function PlayerCard({ player }: { player: any }) {
    const positionPoll = Variable(0).poll(1000, () => player.get_position())

    return <box vertical className="media-card">
        {/* Backdrop art */}
        <box
            className="media-backdrop"
            css={bind(player, "coverArt").as(art =>
                art
                    ? `background-image: url("${art}"); background-size: cover; background-position: center;`
                    : ""
            )}
        />

        {/* Content overlay */}
        <box vertical className="media-overlay">
            {/* Player identity */}
            <box className="media-source">
                <label
                    className="media-source-icon"
                    label={bind(player, "identity").as(i => getPlayerIcon(i || ""))}
                />
                <label
                    className="media-source-name"
                    label={bind(player, "identity").as(i => i || "Media")}
                />
            </box>

            {/* Art + Info */}
            <box className="media-main">
                <box
                    className="media-art"
                    css={bind(player, "coverArt").as(art =>
                        art
                            ? `background-image: url("${art}"); background-size: cover; background-position: center;`
                            : ""
                    )}
                />
                <box vertical className="media-info" valign={Gtk.Align.CENTER}>
                    <label
                        className="media-title"
                        label={bind(player, "title").as(t => t || "Desconhecido")}
                        truncate
                        maxWidthChars={22}
                        halign={Gtk.Align.START}
                    />
                    <label
                        className="media-artist"
                        label={bind(player, "artist").as(a => a || "Artista desconhecido")}
                        truncate
                        maxWidthChars={26}
                        halign={Gtk.Align.START}
                    />
                    <label
                        className="media-album"
                        label={bind(player, "album").as(a => a || "")}
                        truncate
                        maxWidthChars={26}
                        halign={Gtk.Align.START}
                        visible={bind(player, "album").as(a => !!a)}
                    />
                </box>
            </box>

            {/* Progress */}
            <box vertical className="media-progress">
                <slider
                    className="media-progress-bar"
                    hexpand
                    value={positionPoll().as(() => {
                        const len = player.get_length()
                        return len > 0 ? player.get_position() / len : 0
                    })}
                    onDragged={(self: any) => {
                        const len = player.get_length()
                        if (len > 0) player.set_position(self.value * len)
                    }}
                />
                <box className="media-time">
                    <label
                        className="media-time-label"
                        label={positionPoll().as(() => formatTime(player.get_position()))}
                        halign={Gtk.Align.START}
                        hexpand
                    />
                    <label
                        className="media-time-label"
                        label={bind(player, "length").as(l => formatTime(l))}
                        halign={Gtk.Align.END}
                    />
                </box>
            </box>

            {/* Controls */}
            <box className="media-controls" halign={Gtk.Align.CENTER}>
                <button
                    className={bind(player, "shuffleStatus").as(s =>
                        s === Mpris.Shuffle.ON ? "media-ctrl-btn media-ctrl-active" : "media-ctrl-btn media-ctrl-secondary"
                    )}
                    onClicked={() => player.shuffle()}
                    visible={bind(player, "canGoNext")}
                >
                    <label label="󰒝" />
                </button>
                <button className="media-ctrl-btn" onClicked={() => player.previous()}>
                    <label label="󰒮" />
                </button>
                <button className="media-ctrl-btn media-play-btn" onClicked={() => player.play_pause()}>
                    <label label={bind(player, "playbackStatus").as(s =>
                        s === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"
                    )} />
                </button>
                <button className="media-ctrl-btn" onClicked={() => player.next()}>
                    <label label="󰒭" />
                </button>
                <button
                    className={bind(player, "loopStatus").as(l =>
                        l === Mpris.Loop.NONE ? "media-ctrl-btn media-ctrl-secondary" : "media-ctrl-btn media-ctrl-active"
                    )}
                    onClicked={() => player.loop()}
                    visible={bind(player, "canGoNext")}
                >
                    <label label={bind(player, "loopStatus").as(l =>
                        l === Mpris.Loop.TRACK ? "󰑘" : "󰑖"
                    )} />
                </button>
            </box>
        </box>
    </box>
}

function PlayerControls() {
    const mpris = Mpris.get_default()
    const activeIdx = Variable(0)

    return <box className="media-popup-content" vertical>
        {bind(mpris, "players").as(players => {
            if (players.length === 0)
                return <box vertical className="media-empty">
                    <label className="media-empty-icon" label="󰎊" />
                    <label className="media-empty-text" label="Nenhuma midia tocando" />
                </box>

            // Clamp index
            const idx = Math.min(activeIdx.get(), players.length - 1)

            return <box vertical>
                <PlayerCard player={players[idx]} />

                {/* Multi-player indicator */}
                {players.length > 1 && <box className="media-player-dots" halign={Gtk.Align.CENTER}>
                    {players.map((_: any, i: number) =>
                        <button
                            className={activeIdx().as(a => i === a ? "media-dot active" : "media-dot")}
                            onClicked={() => activeIdx.set(i)}
                        >
                            <box className="media-dot-inner" />
                        </button>
                    )}
                </box>}
            </box>
        })}
    </box>
}

export default function MediaPopup(gdkmonitor: Gdk.Monitor) {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

    return <window
        name="media-popup"
        className="MediaPopup"
        gdkmonitor={gdkmonitor}
        anchor={TOP | BOTTOM | LEFT | RIGHT}
        application={App}
        visible={mediaVisible()}
        keymode={Astal.Keymode.ON_DEMAND}
        onKeyPressEvent={(_: any, event: any) => {
            if (event.get_keyval()[1] === Gdk.KEY_Escape)
                mediaVisible.set(false)
        }}
    >
        <eventbox onClick={() => mediaVisible.set(false)}>
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.START}
                css="margin-top: 38px;"
            >
                <eventbox onClick={(_: any, event: any) => {
                    event.stop_propagation?.()
                    return true
                }}>
                    <PlayerControls />
                </eventbox>
            </box>
        </eventbox>
    </window>
}
