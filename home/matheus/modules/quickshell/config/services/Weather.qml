pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clima via wttr.in ?format=j1 (port de lib/weather.ts): atual + blocos de
// 3h + 3 dias, cache persistido com TTL de 15 min, cidade configurável
// ("" = detecção por IP).
Singleton {
    id: root

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell"

    property var now: cacheAdapter.now
    property var hours: cacheAdapter.hours
    property var days: cacheAdapter.days
    property string error: ""
    readonly property string city: cityAdapter.city

    readonly property int ttlMs: 15 * 60 * 1000

    FileView {
        id: cityFile
        path: root.stateDir + "/weather.json"
        blockLoading: true

        adapter: JsonAdapter {
            id: cityAdapter
            property string city: ""
        }
    }

    FileView {
        id: cacheFile
        path: root.stateDir + "/weather-cache.json"
        blockLoading: true

        adapter: JsonAdapter {
            id: cacheAdapter
            property var now: null
            property var hours: []
            property var days: []
            property real at: 0
        }
    }

    function setCity(c) {
        cityAdapter.city = (c || "").trim();
        cityFile.writeAdapter();
        fetch(true);
    }

    function fetch(force) {
        if (!force && Date.now() - cacheAdapter.at < ttlMs)
            return;
        if (fetchProc.running)
            return;
        cacheAdapter.at = Date.now();
        const url = city ? `wttr.in/${encodeURIComponent(city)}?format=j1` : "wttr.in/?format=j1";
        fetchProc.command = ["curl", "-s", "--max-time", "8", url];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.fail();
        }
    }

    function fail() {
        cacheAdapter.at = 0;
        error = now ? "Sem atualização" : "Clima indisponível";
    }

    // ── códigos WWO → ícone nerd ─────────────────────────────
    function icon(code, isDay) {
        if (code === 113)
            return isDay ? "\u{F0599}" : "\u{F0594}";
        if (code === 116)
            return isDay ? "\u{F0595}" : "\u{F0F31}";
        if (code === 119 || code === 122)
            return "\u{F0590}";
        if (code === 143 || code === 248 || code === 260)
            return "\u{F0591}";
        if (code === 200 || code === 386 || code === 389)
            return "\u{F067E}";
        if (code === 392 || code === 395)
            return "\u{F0F36}";
        if ([227, 230, 179, 323, 326, 329, 332, 335, 338, 368, 371].includes(code))
            return "\u{F0598}";
        if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(code))
            return "\u{F0592}";
        if ([302, 308, 305, 356, 359].includes(code))
            return "\u{F0596}";
        if (code >= 176)
            return "\u{F0597}";
        return "\u{F0590}";
    }

    // descrições pt-BR (o wttr traduz mal com lang=pt)
    readonly property var descs: ({
        113: "Céu limpo", 116: "Parcialmente nublado", 119: "Nublado", 122: "Encoberto",
        143: "Neblina", 176: "Chuva isolada", 179: "Neve isolada", 182: "Aguaceiro isolado",
        185: "Garoa congelante", 200: "Trovoadas isoladas", 227: "Ventania com neve",
        230: "Nevasca", 248: "Nevoeiro", 260: "Nevoeiro congelante", 263: "Garoa fraca",
        266: "Garoa", 281: "Garoa congelante", 284: "Garoa congelante forte",
        293: "Chuva fraca isolada", 296: "Chuva fraca", 299: "Chuva moderada",
        302: "Chuva moderada", 305: "Chuva forte", 308: "Chuva forte", 311: "Chuva congelante",
        314: "Chuva congelante", 317: "Aguaceiro fraco", 320: "Aguaceiro",
        323: "Neve fraca", 326: "Neve fraca", 329: "Neve moderada", 332: "Neve moderada",
        335: "Neve forte", 338: "Neve forte", 350: "Granizo", 353: "Pancada de chuva fraca",
        356: "Pancada de chuva", 359: "Chuva torrencial", 362: "Aguaceiro fraco",
        365: "Aguaceiro", 368: "Pancada de neve", 371: "Pancada de neve forte",
        374: "Granizo fraco", 377: "Granizo", 386: "Chuva com trovoada",
        389: "Tempestade", 392: "Neve com trovoada", 395: "Tempestade de neve",
    })

    readonly property var shortDays: ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    function dayName(iso, index) {
        if (index === 0)
            return "Hoje";
        if (index === 1)
            return "Amanhã";
        const d = new Date(`${iso}T12:00:00`);
        return shortDays[d.getDay()] ?? iso.slice(8);
    }

    function parse(out) {
        let data;
        try {
            data = JSON.parse(out);
        } catch (e) {
            return fail();
        }
        const cur = data.current_condition ? data.current_condition[0] : null;
        if (!cur)
            return fail();

        const code = Number(cur.weatherCode);
        const hour = new Date().getHours();
        const isDay = hour >= 6 && hour < 18;

        const nowData = {
            code: code,
            temp: Math.round(Number(cur.temp_C)),
            feels: Math.round(Number(cur.FeelsLikeC)),
            desc: descs[code] ?? (cur.weatherDesc && cur.weatherDesc[0] ? cur.weatherDesc[0].value : ""),
            city: city || (data.nearest_area && data.nearest_area[0] ? data.nearest_area[0].areaName[0].value : ""),
            humidity: Number(cur.humidity),
            wind: Number(cur.windspeedKmph),
            uv: Number(cur.uvIndex ?? 0),
            isDay: isDay,
        };

        // Próximos blocos de 3h: os de hoje que ainda não passaram,
        // completados com os de amanhã. São 8 = 24h à frente; o wttr entrega
        // de 3 em 3 horas (00,03,…,21), não existe granularidade de 1h nessa
        // API — 8 é tudo que dá pra mostrar sem repetir o dia seguinte.
        const slots = [];
        const weather = data.weather ?? [];
        for (const day of weather.slice(0, 2)) {
            const isToday = day === weather[0];
            for (const h of (day.hourly ?? [])) {
                const hh = Math.floor(Number(h.time) / 100);
                if (isToday && hh <= hour)
                    continue;
                slots.push({
                    hour: `${Fmt.pad(hh)}h`,
                    temp: Math.round(Number(h.tempC)),
                    code: Number(h.weatherCode),
                    rain: Number(h.chanceofrain ?? 0),
                });
                if (slots.length >= 8)
                    break;
            }
            if (slots.length >= 8)
                break;
        }

        const daysData = weather.slice(0, 3).map((d, i) => ({
            name: dayName(d.date, i),
            min: Math.round(Number(d.mintempC)),
            max: Math.round(Number(d.maxtempC)),
            // condição do meio do dia representa melhor o dia que a das 0h
            code: Number(d.hourly && d.hourly[4] ? d.hourly[4].weatherCode : (d.hourly && d.hourly[0] ? d.hourly[0].weatherCode : 113)),
            rain: Math.max(0, ...(d.hourly ?? []).map(h => Number(h.chanceofrain ?? 0))),
        }));

        cacheAdapter.now = nowData;
        cacheAdapter.hours = slots;
        cacheAdapter.days = daysData;
        error = "";
        cacheFile.writeAdapter();
    }
}
