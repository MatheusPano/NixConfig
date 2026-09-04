import { Variable, execAsync } from "astal"
import { readState, writeState } from "./utils"

// Clima via wttr.in no formato JSON (?format=j1): traz atual + 3 dias com
// blocos de 3 em 3 horas. O formato `%c|%t|...` antigo só dava a condição
// atual — este entrega sensação térmica, mín/máx, chuva e previsão.

export type WeatherNow = {
    code: number; temp: number; feels: number; desc: string; city: string
    humidity: number; wind: number; uv: number; isDay: boolean
}
export type WeatherHour = { hour: string; temp: number; code: number; rain: number }
export type WeatherDay = { name: string; min: number; max: number; code: number; rain: number }

type Cache = { now: WeatherNow | null; hours: WeatherHour[]; days: WeatherDay[]; at: number }

const cached = readState<Cache>("weather-cache", { now: null, hours: [], days: [], at: 0 })

export const weatherNow = Variable<WeatherNow | null>(cached.now)
export const weatherHours = Variable<WeatherHour[]>(cached.hours)
export const weatherDays = Variable<WeatherDay[]>(cached.days)
export const weatherLoading = Variable(false)
export const weatherError = Variable("")

// "" = detecção automática por IP
export const weatherCity = Variable(readState("weather", { city: "" }).city)

let fetchedAt = cached.at
const TTL = 15 * 60 * 1000

// ── Códigos WWO → ícone nerd font ────────────────────────────
// (o wttr devolve weatherCode da World Weather Online)
export function weatherIcon(code: number, isDay = true): string {
    if (code === 113) return isDay ? "󰖙" : "󰖔"
    if (code === 116) return isDay ? "󰖕" : "󰼱"
    if (code === 119 || code === 122) return "󰖐"
    if (code === 143 || code === 248 || code === 260) return "󰖑"
    if (code === 200 || code === 386 || code === 389) return "󰙾"
    if ([392, 395].includes(code)) return "󰼶"
    if ([227, 230, 179, 323, 326, 329, 332, 335, 338, 368, 371].includes(code)) return "󰖘"
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].includes(code)) return "󰖒"
    if ([302, 308, 305, 356, 359].includes(code)) return "󰖖"
    if (code >= 176) return "󰖗"
    return "󰖐"
}

// ── Descrições em pt-BR (o wttr traduz mal com lang=pt) ──────
const DESCS: Record<number, string> = {
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
}

const WEEKDAYS = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

function dayName(iso: string, index: number): string {
    if (index === 0) return "Hoje"
    if (index === 1) return "Amanhã"
    const d = new Date(`${iso}T12:00:00`)
    return WEEKDAYS[d.getDay()] ?? iso.slice(8)
}

export function fetchWeather(force = false) {
    if (!force && Date.now() - fetchedAt < TTL) return
    fetchedAt = Date.now()
    weatherLoading.set(true)

    const custom = weatherCity.get()
    const url = custom ? `wttr.in/${encodeURIComponent(custom)}?format=j1` : "wttr.in/?format=j1"

    execAsync(["curl", "-s", "--max-time", "8", url])
        .then(out => {
            const data = JSON.parse(out)
            const cur = data.current_condition?.[0]
            if (!cur) throw new Error("sem dados")

            const code = Number(cur.weatherCode)
            const hour = new Date().getHours()
            const isDay = hour >= 6 && hour < 18

            const now: WeatherNow = {
                code,
                temp: Math.round(Number(cur.temp_C)),
                feels: Math.round(Number(cur.FeelsLikeC)),
                desc: DESCS[code] ?? cur.weatherDesc?.[0]?.value ?? "",
                city: custom || data.nearest_area?.[0]?.areaName?.[0]?.value || "",
                humidity: Number(cur.humidity),
                wind: Number(cur.windspeedKmph),
                uv: Number(cur.uvIndex ?? 0),
                isDay,
            }

            // próximos blocos de 3h: os do dia de hoje que ainda não passaram,
            // completados com os de amanhã até fechar 5
            const slots: WeatherHour[] = []
            for (const day of (data.weather ?? []).slice(0, 2)) {
                const isToday = day === data.weather[0]
                for (const h of day.hourly ?? []) {
                    const hh = Math.floor(Number(h.time) / 100)
                    if (isToday && hh <= hour) continue
                    slots.push({
                        hour: `${String(hh).padStart(2, "0")}h`,
                        temp: Math.round(Number(h.tempC)),
                        code: Number(h.weatherCode),
                        rain: Number(h.chanceofrain ?? 0),
                    })
                    if (slots.length >= 5) break
                }
                if (slots.length >= 5) break
            }

            const days: WeatherDay[] = (data.weather ?? []).slice(0, 3).map((d: any, i: number) => ({
                name: dayName(d.date, i),
                min: Math.round(Number(d.mintempC)),
                max: Math.round(Number(d.maxtempC)),
                // condição do meio do dia representa melhor o dia que a das 0h
                code: Number(d.hourly?.[4]?.weatherCode ?? d.hourly?.[0]?.weatherCode ?? 113),
                rain: Math.max(...(d.hourly ?? []).map((h: any) => Number(h.chanceofrain ?? 0)), 0),
            }))

            weatherNow.set(now)
            weatherHours.set(slots)
            weatherDays.set(days)
            weatherError.set("")
            writeState("weather-cache", { now, hours: slots, days, at: fetchedAt })
        })
        .catch(() => {
            // mantém o cache na tela; só sinaliza que a atualização falhou
            fetchedAt = 0
            weatherError.set(weatherNow.get() ? "Sem atualização" : "Clima indisponível")
        })
        .finally(() => weatherLoading.set(false))
}

export function setWeatherCity(city: string) {
    weatherCity.set(city.trim())
    writeState("weather", { city: weatherCity.get() })
    fetchWeather(true)
}
